#!/usr/bin/env python3
"""Temporarily block the managed LM Studio stack while GameMode is active."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys

UNITS = ("lmstudio.service", "qwen-model.service", "ralph-orchestrator-worker.service")


def systemctl(*args):
    return subprocess.run(["systemctl", "--user", *args], check=True,
                          capture_output=True, text=True, timeout=45)


def switch(action, directory, control=systemctl):
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    marker = directory / "active"
    saved = directory / "restore.json"
    with (directory / "lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if action == "on":
            if not marker.exists():
                active = []
                for unit in UNITS:
                    state = control("show", unit, "--property=ActiveState", "--value").stdout.strip()
                    if state in ("active", "activating", "reloading"):
                        active.append(unit)
                temporary = saved.with_suffix(".tmp")
                temporary.write_text(json.dumps(active))
                temporary.replace(saved)
                marker.touch(mode=0o600)
            # Set the gate before stopping services, so neither restarts nor CLI
            # automatic startup can race with shutdown. systemd stops descendants.
            control("stop", *reversed(UNITS))
            print("Gaming: LM Studio stopped; model loading is blocked.")
        elif action == "off":
            restore = json.loads(saved.read_text()) if saved.exists() else []
            if not isinstance(restore, list) or any(unit not in UNITS for unit in restore):
                raise ValueError("Invalid saved service list")
            marker.unlink(missing_ok=True)
            if restore:
                # Do not wait for model loading in GameMode's exit hook.
                control("--no-block", "start", *restore)
            saved.unlink(missing_ok=True)
            print("Gaming ended: previously running AI services are starting.")
        else:
            raise ValueError("Expected on or off")


def main():
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    directory = runtime / "lmstudio-gaming"
    args = sys.argv[1:]
    if args and args[0] == "check":
        # The server's ExecStop must remain usable after the gate is set.
        if (directory / "active").exists() and args[1:3] != ["daemon", "down"]:
            print("LM Studio is disabled while gaming. Exit the game to restore it.", file=sys.stderr)
            return 1
        return 0
    if args not in (["on"], ["off"]):
        print("Usage: ai-gaming-mode on|off", file=sys.stderr)
        return 2
    try:
        switch(args[0], directory)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"ai-gaming-mode: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
