#!/usr/bin/env python3
"""Execute the Rust API's pending tasks without writing its task database."""
import argparse
import fcntl
import hashlib
import json
import logging
import os
from pathlib import Path
import signal
import subprocess
import time
import urllib.error
import urllib.request
import uuid

LOG = logging.getLogger("ralph-task-worker")


class RpcClient:
    def __init__(self, url):
        self.url = url
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    def call(self, method, params, key=None):
        payload = {"apiVersion": "v1", "id": str(uuid.uuid4()),
                   "method": method, "params": params}
        if key:
            payload["meta"] = {"idempotencyKey": key}
        request = urllib.request.Request(
            self.url, data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"})
        try:
            with self.opener.open(request, timeout=10) as response:
                body = json.load(response)
        except urllib.error.HTTPError as error:
            raise RuntimeError(f"{method}: {error.read().decode()}") from error
        if "error" in body:
            raise RuntimeError(f"{method}: {body['error']}")
        return body["result"]

    def tasks(self):
        return self.call("task.list", {"includeArchived": True})["tasks"]

    def status(self, task_id, queue_id, status):
        # Retrying an update after an HTTP timeout must not apply it twice.
        key = hashlib.sha256(f"{task_id}:{queue_id}:{status}".encode()).hexdigest()
        self.call("task.update", {"id": task_id, "status": status}, key)


def atomic_json(path, value):
    temporary = path.with_suffix(".tmp")
    with temporary.open("w") as handle:
        json.dump(value, handle, indent=2)
        handle.flush()
        os.fsync(handle.fileno())
    temporary.replace(path)


class Worker:
    def __init__(self, api, workspace, state, command, default_config):
        self.api = api
        self.workspace = Path(workspace)
        self.state = Path(state)
        self.state.mkdir(parents=True, exist_ok=True)
        self.marker = self.state / "active.json"
        self.command = command
        self.default_config = default_config
        self.process = None
        self.active = json.loads(self.marker.read_text()) if self.marker.exists() else None
        if self.active and self.active["phase"] != "finished":
            # systemd kills the entire service cgroup on restart. Never rerun
            # a possibly partially executed task after interruption.
            self.active.update(phase="finished", exit_code=-1,
                               error="Worker interrupted; retry this task explicitly")
            self.save()

    def save(self):
        atomic_json(self.marker, self.active)
        atomic_json(Path(self.active["log"]).with_suffix(".json"), self.active)

    def matches(self, task):
        return (task and task.get("queuedTaskId") == self.active["queue_id"]
                and task["status"] in ("pending", "running"))

    def stop_process(self):
        if not self.process:
            return
        # Stop descendants as well as Ralph (OpenCode may have its own children).
        try:
            os.killpg(self.process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(self.process.pid, signal.SIGKILL)
            self.process.wait()
        # A child can outlive its parent even after the parent exits cleanly.
        try:
            os.killpg(self.process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        self.process = None

    def start(self, task):
        run_id = uuid.uuid4().hex
        log = self.state / f"{run_id}.log"
        self.active = {"id": task["id"], "queue_id": task["queuedTaskId"],
                       "phase": "starting", "log": str(log)}
        self.save()
        self.api.status(task["id"], task["queuedTaskId"], "running")
        # Honour cancellation/retry that happened during the claim.
        latest = next((t for t in self.api.tasks() if t["id"] == task["id"]), None)
        if not self.matches(latest):
            self.active.update(phase="finished", exit_code=-1, error="Task cancelled")
            self.save()
            return
        args = [self.command, "run", "--autonomous", "--exclusive",
                "--no-auto-merge"]
        if not (self.workspace / "ralph.yml").exists():
            args += ["--config", self.default_config]
        # A prompt file preserves arbitrary text and avoids argument-length limits.
        prompt = self.state / f"{run_id}.prompt.txt"
        prompt.write_text(task["title"])
        args += ["--prompt-file", str(prompt)]
        LOG.info("Starting task %s; output: %s", task["id"], log)
        try:
            with log.open("ab", buffering=0) as output:
                self.process = subprocess.Popen(
                    args, cwd=self.workspace, stdin=subprocess.DEVNULL,
                    stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
            self.active.update(phase="running", pid=self.process.pid)
        except OSError as error:
            self.active.update(phase="finished", exit_code=-1, error=str(error))
            log.write_text(str(error) + "\n")
            LOG.exception("Could not launch task %s", task["id"])
        self.save()

    def tick(self):
        tasks = self.api.tasks()
        if self.active:
            current = next((t for t in tasks if t["id"] == self.active["id"]), None)
            if self.process:
                if not self.matches(current):
                    self.stop_process()
                    self.active.update(phase="finished", exit_code=-1, error="Task cancelled or replaced")
                    self.save()
                else:
                    code = self.process.poll()
                    if code is None:
                        return
                    self.stop_process()
                    self.active.update(phase="finished", exit_code=code)
                    self.save()
            if self.active["phase"] != "finished":
                # An RPC failure during claim leaves a durable marker. Fail safely,
                # rather than leaving a task indefinitely running or executing twice.
                self.active.update(phase="finished", exit_code=-1, error="Task claim interrupted; retry explicitly")
                self.save()
            if self.matches(current):
                status = "closed" if self.active["exit_code"] == 0 else "failed"
                self.api.status(self.active["id"], self.active["queue_id"], status)
                LOG.info("Task %s %s (exit %s); output: %s", self.active["id"], status,
                         self.active["exit_code"], self.active["log"])
            self.marker.unlink()
            self.active = None
            return
        pending = [t for t in tasks if t["status"] == "pending" and t.get("queuedTaskId")
                   and not t.get("archivedAt")]
        pending.sort(key=lambda t: (t.get("createdAt", ""), t["id"]))
        if pending:
            self.start(pending[0])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--api", default="http://127.0.0.1:4000/rpc/v1")
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--state", required=True)
    parser.add_argument("--command", required=True)
    parser.add_argument("--default-config", required=True)
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    state = Path(args.state)
    state.mkdir(parents=True, exist_ok=True)
    os.chmod(state, 0o700)
    # Serialise worker instances; never launch the same queued task twice.
    with (state / "worker.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        worker = Worker(RpcClient(args.api), args.workspace, state,
                        args.command, args.default_config)
        stopping = False

        def stop(_signum, _frame):
            nonlocal stopping
            stopping = True

        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        try:
            while not stopping:
                try:
                    worker.tick()
                except (OSError, ValueError, RuntimeError) as error:
                    LOG.error("Task worker: %s", error)
                time.sleep(1)
        finally:
            worker.stop_process()


if __name__ == "__main__":
    main()
