"""Offline checks for ground pollution: the hooks that feed and read it.

The native probe (run.py) covers the behaviour: spread, decay, registry,
ChangeTurf, saving, growth blocking, fuel and spills.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


MODULE = read('code/modules/ecology/pollution.dm')
PROCESS = read('code/processes/pollution.dm')


class Hooks(unittest.TestCase):
    def test_included(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8-sig')
        self.assertIn('#include "code\\modules\\ecology\\pollution.dm"', dme)
        self.assertIn('#include "code\\processes\\pollution.dm"', dme)
        self.assertTrue((ROOT / 'icons/effects/pollution.dmi').exists())

    def test_stain_states_exist(self):
        from PIL import Image
        desc = Image.open(ROOT / 'icons/effects/pollution.dmi').info['Description']
        states = set(re.findall(r'state = "([^"]*)"', desc))
        self.assertEqual(states, {f'pollution{level}_{variant}' for level in (1, 2, 3) for variant in range(4)})

    def test_saved_only_when_polluted(self):
        self.assertRegex(MODULE, r'/turf/get_saved_vars\(\)\n\t\. = \.\.\(\)\n\tif \(pollution\)\n\t\t\. \|= "pollution"')
        self.assertIn('/turf/var/tmp/pollution_index', MODULE)
        self.assertIn('/turf/var/tmp/pollution_stain', MODULE)

    def test_change_turf_keeps_pollution(self):
        source = read('code/game/turfs/turf_changing.dm')
        self.assertIn('var/old_pollution = pollution', source)
        self.assertIn('W.pollution_take_over(old_pollution, old_pollution_index)', source)

    def test_sources(self):
        self.assertIn('pollution_emit(src, 0.05, 3)', read('code/modules/1713/machinery/engines/heatsource.dm'))
        self.assertIn('pollution_emit(src, fuelconsumption * 0.05, 2)', read('code/modules/1713/machinery/engines/internal_combustion.dm'))
        self.assertIn('/obj/structure/burn_structure_fuel(requested)', MODULE)
        self.assertIn('pollution_spread(T, amount * pollutant, 1)', read('code/modules/reagents/reagent_pollution.dm'))
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8-sig')
        self.assertLess(dme.index('reagents\\Chemistry-Reagents.dm"'), dme.index('reagents\\reagent_pollution.dm"'))

    def test_growth_readers(self):
        for hook in ('/obj/structure/farming/plant/advance_stage_if_allowed(allow_stage)',
                     '/obj/structure/farming/plant/tree/process_interval(',
                     '/datum/flora_regrowth/plant_site_error(turf/T)',
                     '/datum/flora_regrowth/regrow_stump(',
                     '/obj/effect/spawner/objspawner/spawnTarget()'):
            self.assertIn(hook, MODULE)
        # The hooked procs still exist where the overrides expect them.
        self.assertIn('/obj/structure/farming/plant/proc/advance_stage_if_allowed(allow_stage)', read('code/game/objects/farming.dm'))
        self.assertIn('/datum/flora_regrowth/proc/plant_site_error(turf/T)', read('code/modules/ecology/flora_regrowth.dm'))
        self.assertIn('/obj/effect/spawner/objspawner/proc/spawnTarget()', read('code/game/objects/effects/spawner.dm'))
        self.assertIn('/obj/structure/proc/burn_structure_fuel(requested)', read('code/modules/1713/wood_ash_compost.dm'))

    def test_process_is_bounded(self):
        self.assertIn('if (persistence_active_operation)', PROCESS)
        self.assertIn('pollution_flush_pending()', PROCESS)
        self.assertIn('pollution_decay_batch()', PROCESS)
        self.assertIn('#define POLLUTION_DECAY_BATCH 1024', MODULE)
        self.assertIn('#define POLLUTION_EMIT_BATCH 128', MODULE)
        self.assertNotIn('spawn(', MODULE + PROCESS)
        self.assertNotIn(' in world', MODULE + PROCESS)

    def test_admin_verbs(self):
        verbs = read('code/modules/admin/admin_verbs.dm')
        self.assertIn('/client/proc/pollution_status,', verbs)
        self.assertIn('/client/proc/set_local_pollution,', verbs)


if __name__ == '__main__':
    unittest.main()
