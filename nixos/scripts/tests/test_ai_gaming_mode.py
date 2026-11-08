import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

source = Path(os.environ.get("AI_GAMING_SOURCE", Path(__file__).parents[1] / "ai-gaming-mode.py"))
spec = importlib.util.spec_from_file_location("ai_gaming", source)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class GamingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.runtime = Path(self.temp.name)
        self.directory = self.runtime / "lmstudio-gaming"
        self.calls = []
        self.active = set(module.UNITS)
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()
        self.addCleanup(self.output.__exit__, None, None, None)

    def control(self, *args):
        self.calls.append(args)
        if args[0] == "show":
            return SimpleNamespace(stdout="active" if args[1] in self.active else "inactive")
        if args[0] == "stop":
            self.assertTrue((self.directory / "active").exists())
            self.active.difference_update(args[1:])
        if args[:2] == ("--no-block", "start"):
            self.assertFalse((self.directory / "active").exists())
            self.active.update(args[2:])
        return SimpleNamespace(stdout="")

    def test_gate_precedes_stop_and_all_active_services_are_restored(self):
        module.switch("on", self.directory, self.control)
        self.assertEqual(self.active, set())
        self.assertTrue((self.directory / "active").exists())
        module.switch("off", self.directory, self.control)
        self.assertEqual(self.active, set(module.UNITS))
        self.assertFalse((self.directory / "active").exists())
        self.assertFalse((self.directory / "restore.json").exists())

    def test_previously_inactive_services_stay_inactive(self):
        self.active = {"lmstudio.service"}
        module.switch("on", self.directory, self.control)
        module.switch("off", self.directory, self.control)
        self.assertEqual(self.active, {"lmstudio.service"})

    def test_repeated_start_preserves_original_restore_set(self):
        module.switch("on", self.directory, self.control)
        module.switch("on", self.directory, self.control)
        module.switch("off", self.directory, self.control)
        self.assertEqual(self.active, set(module.UNITS))

    def test_stop_failure_leaves_loading_blocked(self):
        def failing(*args):
            if args[0] == "stop":
                raise subprocess.CalledProcessError(1, "systemctl")
            return self.control(*args)
        with self.assertRaises(subprocess.CalledProcessError):
            module.switch("on", self.directory, failing)
        self.assertTrue((self.directory / "active").exists())
        self.assertTrue((self.directory / "restore.json").exists())

    def test_end_without_start_does_not_start_services(self):
        module.switch("off", self.directory, self.control)
        self.assertEqual(self.calls, [])

    def test_restore_rejects_unexpected_service_names(self):
        self.directory.mkdir()
        (self.directory / "active").touch()
        (self.directory / "restore.json").write_text(json.dumps(["other.service"]))
        with self.assertRaises(ValueError):
            module.switch("off", self.directory, self.control)
        self.assertTrue((self.directory / "active").exists())
        self.assertEqual(self.calls, [])

    def test_cli_gate_blocks_loads_and_allows_server_shutdown(self):
        self.directory.mkdir()
        (self.directory / "active").touch()
        env = dict(os.environ, XDG_RUNTIME_DIR=str(self.runtime))
        blocked = subprocess.run([sys.executable, str(source), "check", "load", "model"],
                                 env=env, capture_output=True, text=True)
        self.assertEqual(blocked.returncode, 1)
        allowed = subprocess.run([sys.executable, str(source), "check", "daemon", "down"],
                                 env=env, capture_output=True, text=True)
        self.assertEqual(allowed.returncode, 0)
        (self.directory / "active").unlink()
        allowed = subprocess.run([sys.executable, str(source), "check", "load", "model"],
                                 env=env, capture_output=True, text=True)
        self.assertEqual(allowed.returncode, 0)


if __name__ == "__main__":
    unittest.main()
