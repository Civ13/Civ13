"""A handover's standby prepares the map while the old world saves: source wiring.

The native probe is developer evidence, outside the offline suite (about 25 s):
python3 tests/standby_prepare/run.py
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(relative):
    return (ROOT / relative).read_text(encoding='utf-8')


class StandbyPrepareSources(unittest.TestCase):
    def test_module_is_compiled(self):
        self.assertIn('#include "code\\modules\\persistence\\standby_prepare.dm"', read('civ13.dme'))

    def test_record_is_read_before_the_world_can_answer(self):
        # The old world's save removes validated.json once the host sees the standby answer.
        world = read('code/world.dm')
        start = world.index('/world/New()')
        hint = world.index('map_storage.read_standby_prepare_hint()', start)
        self.assertLess(hint, world.index('..()', start))
        self.assertNotIn('sleep(', world[start:hint])
        self.assertLess(world.index('if (persistence_restart.standby)', start), hint)

    def test_standby_prepares_while_it_waits_and_the_load_stops_it_first(self):
        setup = read('code/setup.dm')
        self.assertIn('if(persistence_restart.standby)\n\t\t\tmap_storage.prepare_standby_world()', setup)
        lifecycle = read('code/modules/persistence/nomads_lifecycle.dm')
        run = lifecycle[lifecycle.index('/datum/nomads_lifecycle_control/proc/standby_run()'):]
        # The lifecycle fixture compiles without standby_prepare.dm.
        self.assertLess(run.index('call(map_storage, "stop_standby_prepare")()'), run.index('persistence_restart.resume_startup()'))

    def test_load_clear_keeps_what_prepared_turfs_made(self):
        functions = read('code/modules/persistence/functions.dm')
        clear = functions[functions.index('/map_storage/proc/ClearMap()'):functions.index('/datum/data/record')]
        self.assertIn('standby_kept_objects = null', clear)
        self.assertIn('!(kept && kept[mob])', clear)
        self.assertIn('if(kept && kept[object])', clear)

    def test_preparation_never_runs_beside_a_load_or_outside_a_standby(self):
        prepare = read('code/modules/persistence/standby_prepare.dm')
        self.assertIn('return !standby_prepare_stop && persistence_restart && persistence_restart.standby && persistence_restart.startup_hold && !persistence_restart.busy && !persistence_active_operation', prepare)
        self.assertIn('if(TICK_CHECK && !standby_prepare_allowed()) return cleared', prepare)


if __name__ == '__main__':
    unittest.main()
