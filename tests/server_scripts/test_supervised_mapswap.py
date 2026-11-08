"""Offline: supervised map swaps build, install and stop without root or relaunch."""
import importlib.util
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


server_paths = load("server_paths")
mapswap = load("mapswap")

LEGACY = "////comment\nmdir:/home/1713/\ncdir:civ13/\nport:1714"


class ServerPathsTests(unittest.TestCase):
    def test_legacy_file_keeps_historical_layout(self):
        paths = server_paths.parse_paths(LEGACY)
        self.assertEqual(paths["gitpath"], os.path.join("/home/1713/", "civ13-git"))
        self.assertEqual(paths["livepath"], os.path.join("/home/1713/", "civ13/"))
        self.assertEqual((paths["port"], paths["supervisor"]), ("1714", ""))

    def test_optional_keys(self):
        paths = server_paths.parse_paths(LEGACY + "\ngitdir:civ13-tdm-src\nsupervisor:systemd\n")
        self.assertEqual(paths["gitpath"], os.path.join("/home/1713/", "civ13-tdm-src"))
        self.assertEqual(paths["supervisor"], "systemd")
        absolute = server_paths.parse_paths(LEGACY + "\ngitdir:/srv/build\n")
        self.assertEqual(absolute["gitpath"], "/srv/build")

    def test_rejects_bad_values(self):
        for extra in ("\nsupervisor:cron", "\ngitdir:a;rm"):
            with self.assertRaises(ValueError):
                server_paths.parse_paths(LEGACY + extra)
        with self.assertRaises(ValueError):
            server_paths.parse_paths("////\nmdir:/x/\nport:1\ncdir:y/")


class SupervisedSwapTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        root = Path(self.temporary.name)
        self.git = root / "src"
        self.live = root / "live"
        (self.git / "maps" / "1013").mkdir(parents=True)
        (self.live / "scripts").mkdir(parents=True)
        (self.git / "maps" / "1013" / "karak.dmm").write_text("")
        (self.git / "civ13.dme").write_text('// BEGIN_SELECTED_MAP\n#include "maps\\old.dmm"\n// END_SELECTED_MAP\n')
        (self.live / "civ13.dmb").write_text("old")
        self.paths = {"gitpath": str(self.git), "livepath": str(self.live), "port": "1714"}
        self.addCleanup(self.temporary.cleanup)
        self.cwd = os.getcwd()
        self.addCleanup(os.chdir, self.cwd)

    def run_swap(self, build_code):
        calls = []

        def fake_run(command, check=False):
            calls.append(command)
            code = build_code if command[0] == "DreamMaker" else 0
            if command[0] == "DreamMaker" and not code:
                (self.git / "civ13.dmb").write_text("new")
                (self.git / "civ13.rsc").write_text("rsc")
            return mock.Mock(returncode=code)

        with mock.patch.object(mapswap.subprocess, "run", side_effect=fake_run), \
                mock.patch.object(mapswap.time, "sleep"), \
                mock.patch.object(mapswap, "server_pids", return_value=[4242]), \
                mock.patch.object(mapswap.os, "kill") as kill, \
                mock.patch.object(mapswap.os, "system") as system:
            result = mapswap.supervised_swap(self.paths, str(self.git / "maps" / "1013" / "karak.dmm"))
        return result, calls, kill, system

    def test_success_installs_then_stops_for_the_supervisor(self):
        result, calls, kill, system = self.run_swap(0)
        self.assertEqual(result, 0)
        self.assertIn("karak.dmm", (self.git / "civ13.dme").read_text())
        self.assertEqual((self.live / "civ13.dmb").read_text(), "new")
        self.assertEqual((self.live / "civ13.rsc").read_text(), "rsc")
        kill.assert_called_once_with(4242, mapswap.signal.SIGTERM)
        system.assert_not_called()
        self.assertFalse(any("sudo" in part for command in calls for part in command))
        self.assertFalse(any("DreamDaemon" in part for command in calls for part in command))

    def test_failed_build_leaves_the_running_world(self):
        result, calls, kill, system = self.run_swap(1)
        self.assertEqual(result, 1)
        self.assertEqual((self.live / "civ13.dmb").read_text(), "old")
        kill.assert_not_called()
        self.assertFalse(any("copyconfigfiles" in part for command in calls for part in command))


class ScriptRunnerSourceTests(unittest.TestCase):
    def test_unprivileged_scripts_option_is_wired(self):
        python = (ROOT / "code/processes/python.dm").read_text()
        config = (ROOT / "code/datums/configuration.dm").read_text()
        self.assertIn('shell("[unix_runner()] [getScriptDir()]/[command]")', python)
        self.assertIn('config.unprivileged_scripts) ? "python3" : "sudo python3"', python)
        self.assertIn('if ("unprivileged_scripts")\n\t\t\t\t\tunprivileged_scripts = TRUE', config)
        copied = (ROOT / "scripts/copiedconfigpaths.txt").read_text().split()
        self.assertIn("scripts/server_paths.py", copied)
        self.assertIn("scripts/map_environment.py", copied)


if __name__ == "__main__":
    unittest.main()
