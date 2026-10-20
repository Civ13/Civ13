"""Offline declaration checks; native CI remains the compilation oracle."""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("idle_runner_contract", ROOT / "tests/idle_metabolism/run.py")
idle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(idle)


class IdleWaitContract(unittest.TestCase):
    def test_null_context_fixture_declares_production_wait_interface(self):
        helper = (ROOT / "code/_helpers/mobs.dm").read_text(encoding="utf-8")
        wait = idle.procedure(idle.project(helper, set())[0], "/proc/do_after")
        fixture = (ROOT / "tests/idle_metabolism/probe.dm").read_text(encoding="utf-8")
        generated, _ = idle.production(None)
        self.assertIn(wait, generated)
        self.assertIn("/datum/pickaxe_mining_action\n", fixture)
        methods = set(re.findall(r"mining_context\.(\w+)\(", wait))
        fields = set(re.findall(r"mining_context\.(\w+)\s*=", wait))
        self.assertEqual(methods, {"claim", "valid"})
        self.assertEqual(fields, {"wait_started", "progressbar"})
        for name in methods:
            body = idle.procedure(fixture, "/datum/pickaxe_mining_action/proc/" + name)
            self.assertIn('check(FALSE, "unexpected mining context in metabolism fixture")', body)
            self.assertIn("return FALSE", body)
        for name in fields:
            self.assertRegex(fixture, r"(?m)^\tvar/(?:[\w]+/)*" + name + r"(?:\s*=|$)")
        self.assertNotIn("mining_context =", fixture)

    def test_ci_runs_and_retains_dependent_fixture_for_bump_suite(self):
        workflow = (ROOT / ".github/workflows/test.yml").read_text(encoding="utf-8")
        for title in ("Verify idle metabolism and mutation controls", "Upload idle metabolism evidence"):
            section = workflow.split("- name: " + title, 1)[1].split("- name:", 1)[0]
            condition = next(line for line in section.splitlines() if line.lstrip().startswith("if:"))
            self.assertIn("tests/bump_mining", condition)
            self.assertIn("tests/idle_metabolism", condition)


if __name__ == "__main__":
    unittest.main()
