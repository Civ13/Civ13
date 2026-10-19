"""Offline source closure and native-command prevention for key-release port."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('turret_release_runner', Path(__file__).with_name('run.py'))
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class SourceTests(unittest.TestCase):
    def test_actual_candidate_and_original_release_closure(self):
        candidate, evidence = runner.generate(ROOT)
        baseline, original = runner.generate(ROOT, True)
        self.assertEqual(candidate.count('C.stop_rotation()'), 2)
        self.assertNotIn('C.stop_rotation()', baseline)
        self.assertEqual(evidence['wheel_callbacks_sha256'], original['wheel_callbacks_sha256'])
        for source in (candidate, baseline):
            self.assertIn('mob.movement_eastwest == EAST', source)
            self.assertIn('mob.movement_eastwest == WEST', source)
            self.assertEqual(source.count('RC.stop_move_drone()'), 2)
            self.assertIn('spawn(0.1)\n\t\trotate()', source)
        self.assertTrue(evidence['unchanged_movement_outside_release'])

    def test_proc_extraction_refuses_missing_or_duplicate_headers(self):
        for source in ('/other()\n\treturn\n', '/one()\n\treturn\n/one()\n\treturn\n'):
            with self.assertRaises(ValueError):
                runner.proc(source, '/one()')

    def test_prepare_only_cannot_run_compiler_or_daemon(self):
        original = runner.subprocess.run
        def offline_only(arguments, *args, **kwargs):
            if arguments[0] != 'git':
                raise AssertionError('native forbidden')
            return original(arguments, *args, **kwargs)
        with tempfile.TemporaryDirectory() as temporary, \
                patch.object(runner.subprocess, 'run', side_effect=offline_only), \
                patch('sys.argv', ['run.py', '--prepare-only', '--output', str(Path(temporary) / 'fresh')]):
            runner.main()
            self.assertTrue((Path(temporary) / 'fresh/evidence.json').is_file())


if __name__ == '__main__':
    unittest.main()
