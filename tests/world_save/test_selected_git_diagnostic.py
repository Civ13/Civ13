"""Mocked diagnostic contracts; never launch Git, BYOND or a network process."""
from contextlib import redirect_stdout
import importlib.util
import io
import itertools
import json
from pathlib import Path
import subprocess
from types import SimpleNamespace
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SPEC = importlib.util.spec_from_file_location("selected_git_diagnostic", HERE / "selected_git_diagnostic.py")
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


class SelectedGitDiagnostic(unittest.TestCase):
    def test_collection_records_resolution_without_exposing_config_or_stderr(self):
        commands = []
        secret = "PRIVATE_CONFIG_VALUE"
        def run(argv, *, cwd, env, timeout, stdout, stderr, text):
            self.assertEqual(cwd, M.ROOT)
            self.assertEqual(env["GIT_NO_LAZY_FETCH"], "1")
            self.assertLessEqual(timeout, 2)
            self.assertIs(stderr, subprocess.PIPE)
            self.assertTrue(text)
            commands.append(argv)
            args = argv[1:]
            if args[:2] == ["config", "--local"]:
                return SimpleNamespace(returncode=0, stdout=secret, stderr="")
            if args[0] == "for-each-ref":
                return SimpleNamespace(returncode=0, stdout="refs/replace/" + "a"*40 + " " + "b"*40 + "\n", stderr="")
            if args[-1] == "--is-shallow-repository":
                return SimpleNamespace(returncode=0, stdout="false\n", stderr="")
            if args[-1] in ("--absolute-git-dir", "--show-toplevel"):
                return SimpleNamespace(returncode=0, stdout="/fixture/path\n", stderr="")
            if args[0] == "show":
                return SimpleNamespace(returncode=128, stdout=None,
                                       stderr="fatal: path x exists on disk, but not in commit " + secret)
            if args[0] == "cat-file":
                return SimpleNamespace(returncode=0, stdout=None, stderr="")
            return SimpleNamespace(returncode=0, stdout="c"*40 + "\n", stderr="")

        result = M.collect(run=run, monotonic=lambda: 1, environ={"GIT_CONFIG_GLOBAL": secret})
        encoded = json.dumps(result)
        self.assertNotIn(secret, encoded)
        self.assertTrue(result["env_overrides_present_only"]["GIT_CONFIG_GLOBAL"])
        self.assertFalse(result["env_overrides_present_only"]["GIT_DIR"])
        self.assertTrue(result["partial_clone"]["configured"])
        self.assertEqual(result["replace_refs"]["refs"], [{"original": "a"*40, "replacement": "b"*40}])
        self.assertEqual(result["shallow"]["value"], "false")
        first = result["historical"][next(iter(M.REFS))]["paths"][".github/workflows/test.yml"]
        self.assertEqual(first["show"]["reason"], "path_not_in_commit")
        self.assertEqual(first["blob"]["value"], "c"*40)
        self.assertEqual(sum(argv[1] == "show" for argv in commands), 11)
        self.assertTrue(any(argv[1:3] == ["--no-replace-objects", "rev-parse"] for argv in commands))

    def test_deadline_stops_git_work_without_suppressing_receipt(self):
        ticks = itertools.count()
        calls = []
        def run(argv, **kwargs):
            calls.append(argv)
            return SimpleNamespace(returncode=0, stdout="", stderr="")
        result = M.collect(run=run, monotonic=lambda: next(ticks)*3, environ={})
        self.assertLess(len(calls), 10)
        self.assertFalse(result["complete"])
        rows = result["historical"][next(iter(M.REFS))]["paths"][".github/workflows/test.yml"]
        self.assertEqual(rows["show"]["status"], "deadline")

    def test_timeout_and_exception_outputs_do_not_include_details(self):
        self.assertEqual(M.reason("fatal: invalid object name SECRET"), "invalid_object")
        self.assertEqual(M.reason("SECRET arbitrary private error"), "other_or_empty")
        with patch.object(M, "collect", side_effect=RuntimeError("SECRET")), redirect_stdout(io.StringIO()) as out:
            self.assertEqual(M.main(), 1)
        self.assertNotIn("SECRET", out.getvalue())
        self.assertIn('"diagnostic_error":"collection_failed"', out.getvalue())

    def test_diagnostic_is_immediately_before_the_existing_source_test(self):
        text = (ROOT / ".github/workflows/test.yml").read_text(encoding="utf-8")
        step = text.split("      - name: Test protected sleep source and fixture contracts\n", 1)[1]
        step = step.split("      - name:", 1)[0]
        expected = ("          python3 -B tests/world_save/selected_git_diagnostic.py || diagnostic_status=$?\n"
                    "          python3 -B -m unittest discover -s tests/world_save -p test_selected_toolchains.py -v\n")
        self.assertEqual(step.count(expected), 1)
        self.assertIn("test_selected_git_diagnostic.py -v || diagnostic_status=$?", step)
        self.assertIn("diagnostic_status=0", step)
        self.assertIn('test "$diagnostic_status" -eq 0', step)
        self.assertLess(step.index("test_selected_toolchains.py -v"),
                        step.index('test "$diagnostic_status" -eq 0'))
        self.assertEqual(len(M.REFS["f05659dd5d117302b7ab494ad6e226f2b3f50ab1"]), 7)
        self.assertEqual(sum(map(len, M.REFS.values())), 11)


if __name__ == "__main__":
    unittest.main()
