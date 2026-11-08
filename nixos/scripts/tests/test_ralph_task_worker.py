import io
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest

source = Path(os.environ.get("RALPH_WORKER_SOURCE", Path(__file__).parents[1] / "ralph-task-worker.py"))
spec = importlib.util.spec_from_file_location("worker", source)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Api:
    def __init__(self):
        self.records = [{"id": "task-1", "queuedTaskId": "queue-1", "status": "pending",
                         "title": "Plan only; literal $(touch unexpected)\nSecond line"}]
        self.transitions = []
        self.fail_finish = False

    def tasks(self):
        return [dict(t) for t in self.records]

    def status(self, task_id, queue_id, status):
        if self.fail_finish and status in ("closed", "failed"):
            raise OSError("API temporarily unavailable")
        task = next(t for t in self.records if t["id"] == task_id)
        task["status"] = status
        if status in ("closed", "failed"):
            task.pop("queuedTaskId", None)
        self.transitions.append(status)


class WorkerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.api = Api()
        self.command = self.root / "ralph"
        self.make_command()
        self.worker = module.Worker(self.api, self.root, self.root / "state",
                                    str(self.command), "/default.yml")
        self.addCleanup(self.worker.stop_process)

    def make_command(self, code=0, sleep=False):
        self.command.write_text(
            f"#!{sys.executable}\n"
            "import json, pathlib, sys, time\n"
            "p = pathlib.Path('launches.txt')\n"
            "with p.open('a') as f: f.write('launch\\n')\n"
            "pathlib.Path('args.json').write_text(json.dumps(sys.argv[1:]))\n"
            "print('agent output', flush=True)\n"
            + ("time.sleep(60)\n" if sleep else "")
            + f"sys.exit({code})\n")
        self.command.chmod(0o700)

    def finish(self):
        deadline = time.monotonic() + 5
        while self.worker.active and time.monotonic() < deadline:
            self.worker.tick()
            time.sleep(0.01)
        self.assertIsNone(self.worker.active)

    def test_runs_real_process_preserves_prompt_and_completes(self):
        title = self.api.records[0]["title"]
        self.worker.tick()
        self.assertEqual(self.api.records[0]["status"], "running")
        self.finish()
        self.assertEqual(self.api.transitions, ["running", "closed"])
        args = json.loads((self.root / "args.json").read_text())
        self.assertEqual(Path(args[args.index("--prompt-file") + 1]).read_text(), title)
        self.assertIn("--autonomous", args)
        self.assertIn("--exclusive", args)
        self.assertEqual(args[args.index("--config") + 1], "/default.yml")
        self.assertFalse((self.root / "unexpected").exists())
        self.assertIn("agent output", next((self.root / "state").glob("*.log")).read_text())

    def test_nonzero_exit_is_failed(self):
        self.make_command(code=7)
        self.worker.tick()
        self.finish()
        self.assertEqual(self.api.records[0]["status"], "failed")
        result = json.loads(next((self.root / "state").glob("*.json")).read_text())
        self.assertEqual(result["exit_code"], 7)

    def test_cancel_stops_running_process_without_overwriting_status(self):
        self.make_command(sleep=True)
        self.worker.tick()
        process = self.worker.process
        self.assertEqual(os.getpgid(process.pid), process.pid)
        self.api.records[0].update(status="failed")
        self.api.records[0].pop("queuedTaskId")
        self.worker.tick()
        self.assertIsNotNone(process.poll())
        self.assertEqual(self.api.transitions, ["running"])
        self.assertIsNone(self.worker.active)

    def test_retry_does_not_complete_the_replacement_task(self):
        self.make_command(sleep=True)
        self.worker.tick()
        self.api.records[0].update(status="pending", queuedTaskId="queue-2")
        self.worker.tick()
        self.assertEqual(self.api.records[0]["status"], "pending")
        self.assertEqual(self.api.records[0]["queuedTaskId"], "queue-2")
        self.assertEqual(self.api.transitions, ["running"])

    def test_api_outage_after_exit_retries_status_without_rerunning(self):
        self.worker.tick()
        self.worker.process.wait(timeout=5)
        self.api.fail_finish = True
        with self.assertRaises(OSError):
            self.worker.tick()
        self.assertTrue(self.worker.marker.exists())
        self.api.fail_finish = False
        self.worker.tick()
        self.assertEqual((self.root / "launches.txt").read_text(), "launch\n")
        self.assertEqual(self.api.records[0]["status"], "closed")

    def test_restart_marks_interrupted_task_failed_without_rerunning(self):
        self.make_command(sleep=True)
        self.worker.tick()
        self.worker.stop_process()
        recovered = module.Worker(self.api, self.root, self.root / "state",
                                  str(self.command), "/default.yml")
        recovered.tick()
        self.assertEqual(self.api.records[0]["status"], "failed")
        self.assertIsNone(recovered.active)
        self.assertEqual(self.api.transitions, ["running", "failed"])

    def test_one_task_at_a_time(self):
        self.make_command(sleep=True)
        self.api.records.append({"id": "task-2", "queuedTaskId": "queue-2", "status": "pending", "title": "second"})
        self.worker.tick()
        self.worker.tick()
        self.assertEqual(self.api.records[1]["status"], "pending")
        self.assertEqual(self.api.transitions, ["running"])

    def test_existing_project_configuration_is_honoured(self):
        (self.root / "ralph.yml").write_text("cli:\n  backend: custom\n")
        self.worker.tick()
        self.finish()
        self.assertNotIn("--config", json.loads((self.root / "args.json").read_text()))

    def test_rpc_envelope_matches_api_contract(self):
        client = module.RpcClient("http://127.0.0.1:4000/rpc/v1")
        requests = []

        class Opener:
            def open(self, request, timeout):
                requests.append(json.loads(request.data))
                return io.BytesIO(b'{"result":{"task":{"status":"running"}}}')

        client.opener = Opener()
        client.status("task-1", "queue-1", "running")
        client.status("task-1", "queue-1", "running")
        self.assertEqual(requests[0]["apiVersion"], "v1")
        self.assertEqual(requests[0]["method"], "task.update")
        self.assertEqual(requests[0]["params"], {"id": "task-1", "status": "running"})
        self.assertEqual(requests[0]["meta"], requests[1]["meta"])
        self.assertNotEqual(requests[0]["id"], requests[1]["id"])

    def test_spawn_failure_becomes_failed(self):
        self.command.unlink()
        with self.assertLogs("ralph-task-worker", level="ERROR"):
            self.worker.tick()
        self.worker.tick()
        self.assertEqual(self.api.records[0]["status"], "failed")
        self.assertIn("No such file", next((self.root / "state").glob("*.log")).read_text())


if __name__ == "__main__":
    unittest.main()
