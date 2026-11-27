"""Canals and pound locks: source contracts. Behaviour is in probe.dm:

    python3 tests/canals/test_source.py
    python3 tests/ecology_spawning/run_linux.py . tests/canals/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def dmi_states(path):
    from PIL import Image
    with Image.open(ROOT / path) as icon:
        meta = icon.info['Description']
    return {line.split('"')[1] for line in meta.splitlines() if line.startswith('state = ')}


class CanalSource(unittest.TestCase):
    def test_trench_flooding_keeps_to_gravity(self):
        trench = read('code/modules/1713/trench.dm')
        canals = read('code/modules/1713/canals.dm')
        self.assertIn("level >= (istype(cut) ? cut.trench_bed_level() : terrain_height_at(T))", canals)
        self.assertIn("terrain_height_at(src) - trench_cut + trench_filling", trench)
        self.assertIn("canal_can_flood(water, src)", trench)
        inlet = trench.split('/proc/trench_best_inlet(', 1)[1].split('\n/turf/', 1)[0]
        self.assertIn("for (var/direction in cardinal)", inlet)

    def test_surface_is_independent_of_bed_and_lock(self):
        canals = read('code/modules/1713/canals.dm')
        self.assertIn("return F.trench_water_level", canals)
        self.assertIn("return canal_level(from) != canal_level(to_turf)", canals)
        self.assertIn("var/level = canal_level(W)", canals)
        source = canals.split('/proc/canal_flood_source_level(', 1)[1].split('/proc/', 1)[0]
        self.assertIn("!is_open_water(T)", source)
        self.assertIn("if (locate(/obj/structure/canal_lock) in T)\n\t\treturn null", source)

    def test_trench_edits_recheck_and_keep_durable_state(self):
        trench = read('code/modules/1713/trench.dm')
        fields = "trench_cut;trench_lining;trench_water_level"
        self.assertIn('map_storage_saved_vars = "icon_state;name;trench_filling;' + fields + '"', trench)
        self.assertIn("restoring || (persistence_active_operation && persistence_active_operation.kind == \"load\")", trench)
        for proc, change in (('trench_deepen', 'trench_cut++'), ('trench_line', 'S.use(cost)')):
            body = trench.split('/proc/' + proc + '(', 1)[1].split('attackby(' if proc == 'trench_line' else '/proc/trench_line(', 1)[0]
            before, after = body.split('if (!do_after(', 1)
            self.assertIn('trench_can_work', before)
            self.assertLess(after.index('trench_can_work'), after.index(change))
        self.assertIn("excavation_spoil(get_turf(H), 1)", trench)
        self.assertIn("if (trench_try_flood())", trench)
        self.assertIn("if (flooded && trench_bed_level() > canal_level(src))", trench)
        for target in ("trench_cut", "trench_lining", "trench_filling", "trench_water_level"):
            self.assertIn("next." + target + " = ", trench)

    def test_drydock_does_not_discard_the_bed_or_reflood_itself(self):
        dock = read('code/modules/naval/drydock.dm')
        self.assertIn('T.trench_change_water(/turf/floor/trench, null)', dock)
        self.assertIn('T.trench_bed_level() > surface', dock)
        self.assertIn('/turf/floor/trench/flooded, surface)', dock)
        self.assertIn('gate.drained', read('code/modules/1713/trench.dm'))

    def test_every_boat_checks_the_step(self):
        self.assertEqual(read('code/game/objects/structures/transports.dm').count('canal_step_blocked(get_turf(src), '), 2)
        self.assertIn('canal_step_blocked(get_turf(FR), T)', read('code/modules/1713/machinery/modular_vehicles/axis.dm'))
        self.assertIn('canal_step_blocked(get_turf(src), get_turf(get_step(src,dir)))',
                      read('code/modules/1713/machinery/modular_vehicles/ships/axis.dm'))

    def test_aqueduct_feeds_a_cut(self):
        self.assertIn('TR.trench_take_water(P.wet_level)', read('code/modules/1713/aqueducts.dm'))

    def test_shovel_never_reinitializes_an_existing_channel(self):
        shovel = read('code/modules/1713/tools.dm')
        channel = shovel.split('else if (input == "Irrigation Channel")', 1)[1]
        channel = channel.split('else if  (input == "Grave")', 1)[0]
        before, after = channel.split('if (do_after(', 1)
        self.assertIn('if (TB.irrigation)', before)
        self.assertLess(after.index('if (TB.irrigation)'), after.index('TB.irrigate("empty")'))
        self.assertIn('return', after[after.index('if (TB.irrigation)'):after.index('TB.irrigate("empty")')])

    def test_states_and_recipe(self):
        states = dmi_states('icons/obj/canal_lock.dmi')
        self.assertTrue({'lock_low', 'lock_high', 'lock_filling', 'lock_emptying'} <= states)
        self.assertIn(',/obj/structure/canal_lock,', read('config/crafting/material_recipes_global.txt'))
        self.assertIn('"/obj/structure/canal_lock" = "wagons_ships",', read('code/modules/research_tree/research_node.dm'))


if __name__ == '__main__':
    unittest.main()
