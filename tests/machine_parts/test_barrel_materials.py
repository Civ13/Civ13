"""Cannon barrels by material (docs/material-roles.md, "Cannon barrels").

code/modules/materials/barrel_materials.dm lets the smoothbore cannon be made
of bronze, iron or iron-hooped wood as well as steel.

- A steel cannon is untouched: it never wears and is never renamed.
- FROZEN_LIFE pins how many shots each barrel lasts.
- Only iron fails early; bronze and wood give warning first.
- Every barrel has a recipe and a research gate, and the hooped cannon needs
  iron and a hammer.
"""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/materials/barrel_materials.dm').read_text(encoding='utf-8')
PIECE = (ROOT / 'code/modules/1713/siege/piece.dm').read_text(encoding='utf-8', errors='ignore')
PROPERTIES = (ROOT / 'code/modules/materials/material_properties.dm').read_text(encoding='utf-8')
RESEARCH = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8', errors='ignore')
CATALOG = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8', errors='ignore')
NEEDS = json.loads((ROOT / 'config/craft_needs.json').read_text(encoding='utf-8'))
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8', errors='ignore')

FROZEN_LIFE = {'wood': 5, 'bronze': 101, 'iron': 204}


def prop(material, name):
    body = re.search(r'^/material/%s\n((?:\t[^\n]*\n)+)' % material, PROPERTIES, re.M)[1]
    return float(re.search(r'\t%s = (\S+)' % name, body)[1])


def life(material):
    # DM round(x) with one argument floors.
    return max(1, int((prop(material, 'toughness') * prop(material, 'firmness') / 1000) ** 2 * 5))


def proc(name):
    start = SOURCE.index(name)
    end = SOURCE.find('\n/', start + 1)
    return SOURCE[start:end if end > 0 else len(SOURCE)]


class BarrelMaterials(unittest.TestCase):
    def test_compiled_after_the_cannon(self):
        self.assertLess(DME.index('code\\modules\\1713\\siege\\piece.dm'),
                        DME.index('code\\modules\\materials\\barrel_materials.dm'))
        self.assertNotIn('barrel_material', PIECE)

    def test_life_formula_and_frozen_values(self):
        self.assertIn('round((M.toughness * M.firmness / 1000) ** 2 * 5)', proc('/proc/barrel_life('))
        for name, shots in FROZEN_LIFE.items():
            self.assertEqual(life(name), shots, name)

    def test_only_iron_fails_early(self):
        self.assertIn('M.toughness <= M.firmness', proc('/proc/barrel_fails_early('))
        early = [n for n in ('wood', 'copper', 'bronze', 'brass', 'iron') if prop(n, 'toughness') <= prop(n, 'firmness')]
        self.assertEqual(early, ['iron'])

    def test_a_steel_cannon_is_untouched(self):
        self.assertIn('if (barrel_material == "steel")\n\t\treturn FALSE', proc('/obj/structure/cannon/proc/barrel_shot('))
        self.assertIn('if (!M || barrel_material == "steel")\n\t\treturn', proc('/obj/structure/cannon/proc/apply_barrel_material('))
        self.assertIn('var/barrel_material = "steel"', SOURCE)

    def test_a_shot_is_charged_once_after_firing(self):
        body = proc('/obj/structure/cannon/discharge(')
        self.assertIn('var/fired = loaded.len\n\t. = ..()\n\tif (fired && !QDELETED(src))\n\t\tbarrel_shot()', body)

    def test_a_warning_barrel_bursts_only_on_the_shot_after_it_is_spent(self):
        body = proc('/obj/structure/cannon/proc/barrel_shot(')
        self.assertLess(body.index('barrel_fails_early(barrel_material)'), body.index('else if (was >= 100)'))
        self.assertIn('was >= BARREL_EARLY_FROM && prob(BARREL_EARLY_CHANCE)', body)

    def test_recipes_and_gates(self):
        for name in ('bronze', 'iron'):
            self.assertIn('RECIPE: /material/%s/,%s cannon,/obj/structure/cannon,35,600,1,1,siege weapons,71,79,0,4,%s\n'
                          % (name, name, name), CATALOG)
        self.assertIn('/obj/structure/cannon/hooped,12,400,1,1,siege weapons,71,79,0,4,wood\n', CATALOG)
        self.assertIn('"/obj/structure/cannon/hooped" = "cannon"', RESEARCH)
        need = NEEDS['/obj/structure/cannon/hooped']
        self.assertEqual(need['inputs'], {'/obj/item/stack/material/iron': 4})
        self.assertEqual(need['tools'], ['hammer'])


if __name__ == '__main__':
    unittest.main()
