"""Rolling stock by material (docs/material-roles.md, "Rolling stock").

- The wheel is a machine part in the wheel role; the iron-shod wooden wheel
  lasts twice as long and is not tinted.
- A pedal bicycle is a frame, two wheels and a chain or belt; a steel one is
  exactly the bicycle it always was.
- An aluminium frame is lighter and so quicker; the wooden running bike has
  no chain, comes with Carts and is slower than any pedal bicycle.
"""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/materials/rolling_stock.dm').read_text(encoding='utf-8')
PARTS = (ROOT / 'code/modules/materials/machine_parts.dm').read_text(encoding='utf-8')
BICYCLE = (ROOT / 'code/game/objects/structures/bicycle.dm').read_text(encoding='utf-8', errors='ignore')
PROPERTIES = (ROOT / 'code/modules/materials/material_properties.dm').read_text(encoding='utf-8')
RESEARCH = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8', errors='ignore')
CATALOG = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8', errors='ignore')
NEEDS = json.loads((ROOT / 'config/craft_needs.json').read_text(encoding='utf-8'))
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8', errors='ignore')


def density(material):
    body = re.search(r'^/material/%s\n((?:\t[^\n]*\n)+)' % material, PROPERTIES, re.M)[1]
    return float(re.search(r'\tdensity = (\S+)', body)[1])


def factor(material):
    share = float(re.search(r'#define BICYCLE_FRAME_SHARE (\S+)', SOURCE)[1])
    raw = max(0.75, min(1.25, 1 - share + share * density(material) / density('steel')))
    return round(round(raw / 0.05) * 0.05, 2)


def block(source, path):
    return re.search(r'^' + re.escape(path) + r'\n((?:\t[^\n]*\n)+)', source, re.M)[1]


class RollingStock(unittest.TestCase):
    def test_compiled_after_the_bicycle(self):
        self.assertLess(DME.index('code\\game\\objects\\structures\\bicycle.dm'),
                        DME.index('code\\modules\\materials\\rolling_stock.dm'))
        self.assertNotIn('frame_material', BICYCLE)

    def test_wheel_part_and_shod_wheel(self):
        wheel = block(PARTS, '/obj/item/machine_part/wheel')
        self.assertIn('part_role = ROLE_WHEEL', wheel)
        shod = block(PARTS, '/obj/item/machine_part/wheel/shod')
        self.assertIn('part_material = "wood"', shod)
        self.assertIn('castable = FALSE', shod)
        self.assertIn('rated[2] *= 2', PARTS)
        self.assertIn('rated = rated.Copy()', PARTS)
        self.assertIn('/obj/item/machine_part/wheel/shod/apply_part_material()\n\t..()\n\tcolor = null', PARTS)
        self.assertEqual(NEEDS['/obj/item/machine_part/wheel/shod'],
                         {'tools': ['hammer'], 'inputs': {'/obj/item/machine_part/wheel': 1}})
        self.assertIn('RECIPE: /material/iron/,iron-shod wheel,/obj/item/machine_part/wheel/shod,2,', CATALOG)
        self.assertIn('"/obj/item/machine_part/wheel/shod" = "basic_tools"', RESEARCH)

    def test_bicycle_is_frame_wheels_and_chain(self):
        self.assertEqual(NEEDS['/obj/structure/vehicle/bicycle'],
                         {'tools': ['wrench'],
                          'inputs': {'/obj/item/machine_part/wheel': 2, '/obj/item/machine_part/belt': 1}})
        self.assertNotIn('/obj/structure/vehicle/bicycle/airship', NEEDS)
        for name in ('steel', 'aluminium'):
            self.assertRegex(CATALOG, r'RECIPE: /material/%s/,[\w ]*pedal bicycle,/obj/structure/vehicle/bicycle,8,200,' % name)

    def test_a_steel_bicycle_is_untouched(self):
        body = SOURCE[SOURCE.index('/obj/structure/vehicle/bicycle/proc/apply_frame_material('):]
        self.assertIn('if (!M || frame_material == initial(frame_material))\n\t\treturn', body)
        self.assertIn('var/frame_material = "steel"', SOURCE)
        self.assertIn('/obj/structure/vehicle/bicycle/airship/apply_frame_material()\n\treturn', SOURCE)
        self.assertEqual(factor('steel'), 1.0)

    def test_aluminium_is_quicker_and_the_running_bike_slower(self):
        self.assertEqual(factor('aluminium'), 0.85)
        usual = float(re.search(r'var/pedal_fastest = ([\d.]+)', BICYCLE)[1])
        running = block(SOURCE, '/obj/structure/vehicle/bicycle/running')
        slow = float(re.search(r'pedal_fastest = ([\d.]+)', running)[1])
        self.assertGreater(slow, usual)
        self.assertLess(usual * factor('aluminium'), usual)
        self.assertIn('frame_material = "wood"', running)
        self.assertEqual(NEEDS['/obj/structure/vehicle/bicycle/running']['inputs'], {'/obj/item/machine_part/wheel': 2})
        self.assertIn('"/obj/structure/vehicle/bicycle/running" = "carts"', RESEARCH)
        self.assertIn(',running bike,/obj/structure/vehicle/bicycle/running,6,200,', CATALOG)


if __name__ == '__main__':
    unittest.main()
