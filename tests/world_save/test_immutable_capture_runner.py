"""Source preparation only. No compiler, daemon, client or game is launched."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('capture_runner', Path(__file__).with_name('run-immutable-capture.py'))
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


class CaptureControlTests(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / 'code/modules/persistence/immutable_capture.dm').read_text(encoding='utf-8')

    def test_isolated_environment_includes_real_player_restore_dependencies(self):
        source = (ROOT / 'tests/world_save/immutable_capture.dme').read_text()
        player = '#include "../../code/modules/persistence/player_reclaim.dm"'
        self.assertEqual(source.count(player), 1)
        self.assertLess(source.index('persistence/functions.dm'), source.index(player))
        self.assertLess(source.index(player), source.index('persistence/saving.dm'))
        self.assertLess(source.index(player), source.index('persistence/loading.dm'))
        self.assertNotIn('player_reclaim_probe.dm', source)

    def test_positive_preserves_production_source(self):
        self.assertEqual(RUNNER.prepare_source(self.source), (self.source, 'PASS'))

    def test_callbacks_are_independent_and_have_distinct_oracles(self):
        getter, getter_oracle = RUNNER.prepare_source(self.source, 'callback')
        runtime, runtime_oracle = RUNNER.prepare_source(self.source, 'runtime-callback')
        self.assertIn('saved = source.get_saved_vars()', getter)
        self.assertNotIn('source.persistence_runtime_var(key)', getter)
        self.assertIn('source.persistence_runtime_var(key)', runtime)
        self.assertNotIn('saved = source.get_saved_vars()', runtime)
        self.assertEqual(getter_oracle, 'FAIL: capture invoked mutating projection')
        self.assertEqual(runtime_oracle, 'FAIL: capture invoked runtime exclusion callback')

    def test_controls_reject_ambiguous_or_missing_source_anchors(self):
        for control in ('callback', 'runtime-callback', 'admission', 'hook'):
            with self.subTest(control=control):
                with self.assertRaisesRegex(RuntimeError, 'unique production guard'):
                    RUNNER.prepare_source(self.source + self.source, control)
                with self.assertRaisesRegex(RuntimeError, 'unique production guard'):
                    RUNNER.prepare_source('', control)


if __name__ == '__main__':
    unittest.main()
