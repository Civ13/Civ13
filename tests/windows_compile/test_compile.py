"""Windows batch behavior checks with a local console executable, never BYOND.

Run: python -m unittest discover -s tests/windows_compile -v
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[2]


def cleanup_temp(directory):
    # Windows virus scanners can briefly retain a just-executed batch file.
    for attempt in range(20):
        try:
            directory.cleanup()
            return
        except PermissionError:
            if attempt == 19:
                raise
            time.sleep(0.1)


@unittest.skipUnless(os.name == "nt", "requires Windows cmd and PowerShell")
class CompileBatchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tools = tempfile.TemporaryDirectory(prefix="civ13-compiler-stubs-")
        cls.powershell = Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe"
        for version in ("516.1688", "516.1687"):
            source = Path(cls.tools.name) / (version + ".cs")
            target = source.with_suffix(".exe")
            source.write_text('''using System;
using System.IO;
using System.Reflection;
[assembly: AssemblyFileVersion("5.0.VERSION")]
class Compiler {
    static int Main(string[] args) {
        File.WriteAllLines(Environment.GetEnvironmentVariable("CIV13_TEST_LOG"),
            new string[] { Environment.CurrentDirectory, String.Join("|", args) });
        int result = Int32.Parse(Environment.GetEnvironmentVariable("CIV13_TEST_EXIT"));
        if (result == 0) {
            File.WriteAllText("civ13.dmb", "compiled");
            File.WriteAllText("civ13.rsc", "compiled");
        }
        return result;
    }
}
'''.replace("VERSION", version), encoding="utf-8")
            env = dict(os.environ, CIV13_TEST_SOURCE=str(source), CIV13_TEST_TARGET=str(target))
            subprocess.run([str(cls.powershell), "-NoLogo", "-NoProfile", "-NonInteractive",
                            "-Command", "Add-Type -Path $env:CIV13_TEST_SOURCE -OutputAssembly "
                            "$env:CIV13_TEST_TARGET -OutputType ConsoleApplication"],
                           env=env, check=True, capture_output=True, text=True)

    @classmethod
    def tearDownClass(cls):
        cleanup_temp(cls.tools)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="civ13-batch-")
        self.addCleanup(cleanup_temp, self.temp)
        self.base = Path(self.temp.name)
        self.repo = self.base / "checkout with spaces & (brackets) !"
        self.repo.mkdir()
        self.batch = self.repo / "compile.bat"
        shutil.copyfile(ROOT / "compile.bat", self.batch)
        (self.repo / "civ13.dme").write_text("// sentinel source\n", encoding="utf-8")
        self.manifest = self.repo / "tools/byond/version.json"
        self.manifest.parent.mkdir(parents=True)
        self.manifest.write_text(json.dumps({"version": "516.1688"}), encoding="utf-8")
        self.caller = self.base / "caller"
        self.caller.mkdir()
        self.log = self.base / "invocation.txt"
        self.env = {key.upper(): value for key, value in os.environ.items()}
        for name in ("BYOND_BIN", "CIV13_COMPILER", "CIV13_ROOT"):
            self.env.pop(name, None)
        self.env.update({"PATH": str(self.base / "empty-path"),
                         "PROGRAMFILES(X86)": str(self.base / "programs x86"),
                         "PROGRAMFILES": str(self.base / "programs x64"),
                         "CIV13_TEST_PROGRAMFILES": str(self.base / "programs x64"),
                         "CIV13_TEST_BATCH": str(self.batch),
                         "CIV13_TEST_LOG": str(self.log), "CIV13_TEST_EXIT": "0"})

    def compiler(self, directory, version="516.1688"):
        directory.mkdir(parents=True, exist_ok=True)
        # with_suffix replaces the final numeric suffix, matching setUpClass.
        shutil.copyfile((Path(self.tools.name) / (version + ".cs")).with_suffix(".exe"),
                        directory / "dm.exe")
        return directory

    def run_batch(self, arguments="", source_exists=True):
        runner = self.base / ("run-" + str(time.monotonic_ns()) + ".bat")
        # Windows resets ProgramFiles when creating cmd; override it inside cmd.
        runner.write_text('@echo off\nset "ProgramFiles=%CIV13_TEST_PROGRAMFILES%"\n'
                          'call "%CIV13_TEST_BATCH%" ' + arguments +
                          '\nset "RESULT=%ERRORLEVEL%"\necho CALLER=%CD%\nexit /b %RESULT%\n',
                          encoding="ascii")
        result = subprocess.run([os.environ["COMSPEC"], "/d", "/c", str(runner)],
                                cwd=self.caller, env=self.env, capture_output=True,
                                text=True, timeout=30)
        self.assertIn("CALLER=" + str(self.caller), result.stdout)
        if source_exists:
            self.assertEqual((self.repo / "civ13.dme").read_text(), "// sentinel source\n")
        return result

    def assert_compiled(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.log.read_text().splitlines(),
                         [str(self.repo), "-max_errors|0|civ13.dme"])
        self.assertEqual((self.repo / "civ13.dmb").read_text(), "compiled")

    def test_explicit_bin_handles_spaces_and_metacharacters_from_other_directory(self):
        self.env["BYOND_BIN"] = str(self.compiler(self.base / "BYOND & (bin) !"))
        self.assert_compiled(self.run_batch())

    def test_path_discovery(self):
        self.env["PATH"] = str(self.compiler(self.base / "PATH compiler"))
        self.assert_compiled(self.run_batch())

    def test_standard_install_directories(self):
        for name in ("PROGRAMFILES(X86)", "PROGRAMFILES"):
            with self.subTest(name=name):
                directory = self.compiler(Path(self.env[name]) / "BYOND/bin")
                self.assert_compiled(self.run_batch())
                (directory / "dm.exe").unlink()

    def test_compiler_failure_propagates_even_with_stale_outputs(self):
        self.env["BYOND_BIN"] = str(self.compiler(self.base / "BYOND"))
        self.env["CIV13_TEST_EXIT"] = "23"
        (self.repo / "civ13.dmb").write_text("stale")
        result = self.run_batch()
        self.assertEqual(result.returncode, 23, result.stdout + result.stderr)
        self.assertNotIn("Compilation completed", result.stdout)
        self.assertEqual((self.repo / "civ13.dmb").read_text(), "stale")

    def test_missing_compiler(self):
        result = self.run_batch()
        self.assertEqual(result.returncode, 1)
        self.assertIn("was not found", result.stderr)
        self.assertFalse(self.log.exists())

    def test_invalid_explicit_bin_does_not_fall_back(self):
        self.env["BYOND_BIN"] = str(self.base / "missing")
        self.env["PATH"] = str(self.compiler(self.base / "PATH compiler"))
        self.assertEqual(self.run_batch().returncode, 1)
        self.assertFalse(self.log.exists())

    def test_wrong_version_rejected_before_execution(self):
        self.env["BYOND_BIN"] = str(self.compiler(self.base / "old BYOND", "516.1687"))
        result = self.run_batch()
        self.assertEqual(result.returncode, 1)
        self.assertIn("Expected BYOND 516.1688, found 516.1687", result.stderr)
        self.assertFalse(self.log.exists())

    def test_invalid_manifest_rejected_before_execution(self):
        self.env["BYOND_BIN"] = str(self.compiler(self.base / "BYOND"))
        self.manifest.write_text('{"version":""}')
        result = self.run_batch()
        self.assertEqual(result.returncode, 1)
        self.assertIn("Invalid BYOND version manifest", result.stderr)
        self.assertFalse(self.log.exists())

    def test_missing_entry_point(self):
        (self.repo / "civ13.dme").unlink()
        result = self.run_batch(source_exists=False)
        self.assertEqual(result.returncode, 1)
        self.assertIn("civ13.dme is missing", result.stderr)
        self.assertFalse(self.log.exists())

    def test_unsupported_arguments(self):
        self.assertEqual(self.run_batch("unexpected").returncode, 2)
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
