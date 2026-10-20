import importlib.util
from pathlib import Path
import subprocess
import unittest
import tempfile
import fcntl
from unittest.mock import patch
from types import SimpleNamespace

spec = importlib.util.spec_from_file_location("control", Path(__file__).resolve().parents[2] / "scripts/bot-service/control.py")
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)

class ControlTests(unittest.TestCase):
    def test_contended_lock_returns_busy_without_effects_or_state_change(self):
        with tempfile.TemporaryDirectory() as state:
            lock_path = Path(state) / "lock"
            lock_path.write_text("100")
            with lock_path.open("r+") as held:
                fcntl.flock(held, fcntl.LOCK_EX | fcntl.LOCK_NB)
                with patch.object(control, "STATE", state), \
                     patch.object(control.sys, "argv", ["control.py", "restart"]), \
                     patch.object(control.os, "geteuid", return_value=0), \
                     patch.object(control.subprocess, "run", side_effect=AssertionError("executed")), \
                     patch.object(fcntl, "flock", wraps=fcntl.flock) as acquire:
                    self.assertEqual(control.main(), 75)
                    self.assertEqual(acquire.call_args.args[1], fcntl.LOCK_EX | fcntl.LOCK_NB)
                self.assertEqual(lock_path.read_text(), "100")
            with patch.object(control, "STATE", state), \
                 patch.object(control.sys, "argv", ["control.py", "restart"]), \
                 patch.object(control.os, "geteuid", return_value=0), \
                 patch.object(control.time, "monotonic", return_value=160), \
                 patch.object(control.subprocess, "run", return_value=SimpleNamespace(returncode=0)) as run:
                self.assertEqual(control.main(), 0)
                run.assert_called_once()
            self.assertEqual(float(lock_path.read_text()), 160)

    def test_deployment_stays_disabled_and_documents_independent_supervision(self):
        root = Path(__file__).resolve().parents[2]
        self.assertIn("BOT_SERVICE_CONTROL 0", (root / "config/config.txt").read_text())
        self.assertIn("KillMode=control-group", (root / "scripts/bot-service/civilizationbot.service").read_text())
        readme = (root / "scripts/bot-service/README.md").read_text()
        self.assertIn("Do not install or enable this draft unit yet", readme)
        self.assertIn("independently supervised units/scopes", readme)

    def test_fixed_commands(self):
        for action in control.ACTIONS:
            calls = []
            code, stamp = control.perform(action, None, 100, lambda args, **kw: calls.append((args, kw)) or SimpleNamespace(returncode=0))
            self.assertEqual(code, 0)
            self.assertEqual(calls[0][0][-1], "civilizationbot.service")
            self.assertEqual(calls[0][0][0], "/usr/bin/systemctl")
            self.assertEqual(calls[0][1]["timeout"], 3)
            self.assertEqual(stamp, None if action == "status" else 100)
    def test_untrusted_action_never_executes(self):
        for action in ["stop", "restart other.service", "; reboot", "", "../"]:
            code, stamp = control.perform(action, None, 100, lambda *a, **k: self.fail("executed"))
            self.assertEqual(code, 64)
    def test_cross_server_budget_and_boundary(self):
        code, stamp = control.perform("start", 100, 159.9, lambda *a, **k: self.fail("executed"))
        self.assertEqual((code, stamp), (75, 100))
        self.assertEqual(control.perform("restart", stamp, 160, lambda *a, **k: SimpleNamespace(returncode=0)), (0, 160))
    def test_status_and_failures(self):
        self.assertEqual(control.perform("status", 100, 101, lambda *a, **k: SimpleNamespace(returncode=3)), (3, 100))
        self.assertEqual(control.perform("start", None, 101, lambda *a, **k: SimpleNamespace(returncode=1)), (1, 101))
        def timeout(*a, **k):
            raise subprocess.TimeoutExpired("systemctl", 30)
        self.assertEqual(control.perform("restart", None, 100, timeout), (124, 100))

if __name__ == "__main__":
    unittest.main()
