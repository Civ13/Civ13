import importlib.util
from pathlib import Path
import subprocess
import unittest
from types import SimpleNamespace

spec = importlib.util.spec_from_file_location("control", Path(__file__).resolve().parents[2] / "scripts/bot-service/control.py")
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)

class ControlTests(unittest.TestCase):
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
