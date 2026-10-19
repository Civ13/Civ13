"""Current-source instrumentation checks; does not compile or launch native DM."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('progress', Path(__file__).with_name('build-progress-probe.py'))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

class ProgressInstrumentationTests(unittest.TestCase):
    def test_current_bounded_saver_preserves_wait_policy(self):
        original = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        functions = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        generated, generated_functions = MODULE.instrument(original, functions)
        self.assertEqual(generated_functions, functions)
        start = '/map_storage/proc/save_work_check()'
        end = '/map_storage/proc/Save_World()'
        body = generated[generated.index(start):generated.index(end)]
        self.assertEqual(body.replace('world_save_progress_sleep(', 'sleep('),
                         original[original.index(start):original.index(end)])
        self.assertEqual(generated.count('world_save_progress_sleep('), 3)
        self.assertEqual(generated.count('progress_completed_turfs++'), 1)
        self.assertIn('savefile["/map/[A]/[y]/[x]"] << ref', generated)
        self.assertIn('WORLD_SAVE_PROGRESS_TICK_CHECK\n', generated)

    def test_missing_checkpoint_fails_closed(self):
        saving = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        with self.assertRaisesRegex(ValueError, 'three bounded serializer sleep sites'):
            MODULE.instrument(saving.replace('sleep(0)', 'sleep(1)'), '')

    def test_explicit_wait_metrics_do_not_relabel_stoplag(self):
        helper = Path(__file__).with_name('progress-probe.dm').read_text()
        self.assertIn('"sleep_calls" = world_save_progress_sleeps', helper)
        self.assertIn('"stoplag_calls" = world_save_progress_yields', helper)
        self.assertIn('\t\tsleep(delay)\n\t\treturn', helper)
        self.assertIn('world_save_progress_sleeps++\n\tsleep(delay)', helper)
        self.assertNotIn('return sleep(', helper)
        self.assertNotIn('. = sleep(', helper)
        self.assertIn('. = stoplag()', helper)

if __name__ == '__main__':
    unittest.main()
