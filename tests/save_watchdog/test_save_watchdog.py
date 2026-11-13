"""Save stall watchdog wiring (code/modules/persistence/save_watchdog.dm). Offline.

On Gaia (2026-11-13) a save logged its backup phase, then never advanced or
finished; its operation held save admission until a restart loaded the last
completed save. These checks keep the watchdog wired into the persistence loop,
the save's progress signal and every failure path. The native probe is
python3 tests/save_watchdog/run.py.
"""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, read  # noqa: E402

SAVING = 'code/modules/persistence/saving.dm'
FUNCTIONS = 'code/modules/persistence/functions.dm'
WATCHDOG = 'code/modules/persistence/save_watchdog.dm'


class SaveWatchdogWiring(unittest.TestCase):
    def test_compiled_and_run_by_the_persistence_loop(self):
        self.assertIn('#include "code\\modules\\persistence\\save_watchdog.dm"', read('civ13.dme'))
        loop = extract(read('code/world.dm'), '/proc/start_persistence_loop')
        # Before the round checks, so it also runs while the save holds admission.
        self.assertLess(loop.index('persistence_save_watchdog()'), loop.index('if (map && map.persistence'))

    def test_work_checks_and_phases_record_progress(self):
        saving = read(SAVING)
        check = extract(saving, '/map_storage/proc/save_work_check')
        self.assertLess(check.index('operation.progress_at = world.time'), check.index('if(moving_save_chunk)'))
        self.assertLess(check.index('moving_save_chunk.check()'), check.index('if(operation && operation.abort_reason)'))
        phase = extract(saving, '/proc/persistence_save_phase_log')
        self.assertIn('operation.phase_at = world.time', phase)
        self.assertIn('operation.last_phase = phase', phase)
        created = extract(read(FUNCTIONS), '/datum/persistence_world_operation/New')
        self.assertIn('progress_at = world.time', created)

    def test_an_abandoned_save_stops_without_touching_a_later_one(self):
        saving = read(SAVING)
        contents = extract(saving, '/map_storage/proc/save_world_contents')
        self.assertGreaterEqual(contents.count('if(operation.abandoned) throw EXCEPTION('), 2)
        self.assertLess(contents.index('if(!operation.current(src, "save")) throw EXCEPTION('), contents.index('operation.diagnostic_phase = "write_marker"'))
        functions = read(FUNCTIONS)
        savemap = extract(functions, '/datum/controller/gameticker/proc/savemap')
        self.assertLess(savemap.index('if(operation.abandoned)'), savemap.index('map_storage.cleanup_world_operation()'))

    def test_release_runs_the_failure_path_and_alarms(self):
        release = extract(read(WATCHDOG), '/proc/persistence_save_watchdog_release')
        for step in ('operation.abandoned = TRUE', 'storage.cleanup_world_operation()', 'storage.record_save_outcome(FALSE)',
                     'notify_world_save("finished", operation, FALSE)', 'operation.finish(FALSE)', 'persistence_save_watchdog_alert(message)'):
            self.assertIn(step, release)
        self.assertLess(release.index('operation.abandoned = TRUE'), release.index('operation.finish(FALSE)'))


if __name__ == '__main__':
    unittest.main()
