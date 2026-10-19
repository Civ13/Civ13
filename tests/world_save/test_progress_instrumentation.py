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

    def test_phase_profile_preserves_bounded_policy_and_traversal_argument(self):
        original = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        generated, _ = MODULE.instrument(original, '', phase_profile=True)
        start = '/map_storage/proc/save_work_check()'
        end = '/map_storage/proc/Save_World()'
        self.assertEqual(generated[generated.index(start):generated.index(end)]
                         .replace('world_save_progress_sleep(', 'sleep('),
                         original[original.index(start):original.index(end)])
        self.assertIn('for(var/y = 1, y <= world.maxy, y++)', generated)
        self.assertNotIn('for(var/turf/turf in world)', generated)
        self.assertIn('var/turf/T = locate(x, y, A)\n'
                      '\t\t\t\tworld_save_profile_visited++\n'
                      '\t\t\t\tworld_save_profile_selected++\n', generated)
        call = 'world_save_profile_original_BuildVarDirectory(savefile, A, contents, traversal)'
        self.assertEqual(generated.count(call), 2)
        self.assertIn('BuildVarDirectory(savefile, content, 1, TRUE)', generated)
        self.assertIn('world_save_profile_phase("index")\n'
                      '\t\t\t\tsavefile["/map/[A]/[y]/[x]"] << ref', generated)
        self.assertIn('save_work_check()\n\t\t\t\tworld_save_profile_phase("traversal")', generated)
        self.assertIn('world_save_profile_values++', generated)

    def test_phase_helper_attributes_both_wait_kinds_and_preserves_inactive_sleep(self):
        original = Path(__file__).with_name('progress-probe.dm').read_text()
        generated = MODULE.profile_helper(original)
        self.assertEqual(generated.count('var/previous_phase = world_save_profile_phase("yield")'), 2)
        for wait in ('. = stoplag()', 'sleep(delay)'):
            self.assertIn('var/previous_phase = world_save_profile_phase("yield")\n\t' + wait +
                          '\n\tworld_save_profile_phase(previous_phase)', generated)
        self.assertIn('if(!world_save_progress_active)\n\t\tsleep(delay)\n\t\treturn', generated)
        self.assertIn('world_save_progress_sleeps++', generated)
        self.assertIn('world_save_progress_yields++', generated)
        self.assertIn('world_save_profile_begin(world_save_progress_started)', generated)
        self.assertIn('world_save_profile_row(row)', generated)
        with self.assertRaisesRegex(ValueError, 'Expected'):
            MODULE.profile_helper(original.replace('\tworld_save_progress_sleeps++\n', ''))

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
