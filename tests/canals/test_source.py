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
    meta = Image.open(ROOT / path).info['Description']
    return {line.split('"')[1] for line in meta.splitlines() if line.startswith('state = ')}


class CanalSource(unittest.TestCase):
    def test_trench_flooding_keeps_to_gravity(self):
        trench = read('code/modules/1713/trench.dm')
        self.assertIn("canal_can_flood(src, TF)", trench)
        self.assertIn("canal_can_flood(TF, src)", trench)

    def test_every_boat_checks_the_step(self):
        self.assertEqual(read('code/game/objects/structures/transports.dm').count('canal_step_blocked(get_turf(src), '), 2)
        self.assertIn('canal_step_blocked(get_turf(FR), T)', read('code/modules/1713/machinery/modular_vehicles/axis.dm'))
        self.assertIn('canal_step_blocked(get_turf(src), get_turf(get_step(src,dir)))',
                      read('code/modules/1713/machinery/modular_vehicles/ships/axis.dm'))

    def test_aqueduct_feeds_a_cut(self):
        self.assertIn('P.wet_level >= terrain_height_at(A)', read('code/modules/1713/aqueducts.dm'))

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
