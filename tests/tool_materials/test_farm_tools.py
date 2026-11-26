"""The metal sickle and the hoe (docs/material-roles.md, "Sickle and hoe").

- A sickle is a knife, so it harvests; a harder blade reaps more neighbours:
  copper 2 (the flint sickle's reach), bronze and iron 3, steel 4.
- The metal sickle is not a flint sickle, so a cut is never reaped twice, and
  it shares the flint sickle's guard against reaping neighbours' neighbours.
- A hoe is a plough, so it breaks ground wherever a plough does, and its
  speed is its material's.
- Both have recipes, a research subject and a sprite the script reproduces.
"""
from pathlib import Path
import json
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/materials/farm_tools.dm').read_text(encoding='utf-8')
PROPERTIES = (ROOT / 'code/modules/materials/material_properties.dm').read_text(encoding='utf-8')
RESEARCH = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8', errors='ignore')
CATALOG = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8', errors='ignore')
NEEDS = json.loads((ROOT / 'config/craft_needs.json').read_text(encoding='utf-8'))
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8', errors='ignore')
SICKLE = '/obj/item/weapon/material/kitchen/utensil/knife/sickle'
HOE = '/obj/item/weapon/plough/hoe'


def firmness(material):
    body = re.search(r'^/material/%s\n((?:\t[^\n]*\n)+)' % material, PROPERTIES, re.M)[1]
    return float(re.search(r'\tfirmness = (\S+)', body)[1])


def reach(material):
    low = int(re.search(r'#define SICKLE_REACH_MIN (\d+)', SOURCE)[1])
    step = float(re.search(r'#define SICKLE_REACH_FIRMNESS (\d+)', SOURCE)[1])
    return low + int(firmness(material) / step)


class FarmTools(unittest.TestCase):
    def test_included(self):
        # Either sickle's wrapper may run first: both call ..() and share one guard.
        self.assertIn('code\\modules\\materials\\farm_tools.dm', DME)

    def test_reach_by_material(self):
        self.assertIn('SICKLE_REACH_MIN + round(M.firmness / SICKLE_REACH_FIRMNESS)', SOURCE)
        self.assertEqual([reach(m) for m in ('copper', 'bronze', 'iron', 'steel')], [2, 3, 3, 4])

    def test_one_reaping_per_cut(self):
        self.assertNotIn('knife/flint_sickle', SOURCE)
        body = SOURCE[SOURCE.index('/obj/structure/farming/plant/attackby('):SOURCE.index('// A hoe breaks ground')]
        self.assertIn('if (!sickle_reaping && istype(S) && S.material && stage >= readyStageMin && readyHarvest())', body)
        self.assertLess(body.index('. = ..()'), body.index('sickle_reaping = TRUE'))
        self.assertLess(body.index('sickle_reaping = TRUE'), body.index('sickle_reaping = FALSE'))

    def test_hoe_is_a_plough_at_its_materials_speed(self):
        block = re.search(r'^' + re.escape(HOE) + r'\n((?:\t[^\n]*\n)+)', SOURCE, re.M)[1]
        for line in ('tool_material = "wood"', 'tool_noun = "hoe"', 'tool_role = ROLE_WORK_HEAD', 'usespeed = 1'):
            self.assertIn(line, block)
        init = SOURCE.split(HOE + '/set_tool_material(', 1)[1].split('\n/', 1)[0]
        self.assertIn('usespeed = initial(usespeed) * tool_speed(src)', init)

    def test_hoe_load_keeps_the_saved_head_and_handle_speed(self):
        match = re.search(r'^' + re.escape(HOE) + r'/after_load\(\)\n((?:\t[^\n]*\n)+)', SOURCE, re.M)
        if match:
            self.assertNotRegex(match[1], r'\busespeed\s*[-+*/]?=')
        material = (ROOT / 'code/game/objects/items/weapons/material/material_weapons.dm').read_text()
        self.assertIn(HOE + '/apply_handle_speed(multiplier, head_name)\n\tusespeed *= multiplier', material)

    def test_recipes_and_research(self):
        for name in ('copper', 'bronze', 'iron', 'steel'):
            self.assertIn('RECIPE: /material/%s/,%s sickle,%s,2,80,0,1,tools,0,0,0,8,%s\n' % (name, name, SICKLE, name), CATALOG)
            self.assertIn('RECIPE: /material/%s/,%s hoe,%s,2,60,0,1,tools,0,0,0,8,%s\n' % (name, name, HOE, name), CATALOG)
        self.assertIn('RECIPE: /material/wood/,hoe,%s,2,60,0,1,tools,0,0,0,8,null\n' % HOE, CATALOG)
        self.assertEqual(NEEDS[SICKLE], {'tools': ['hammer'], 'inputs': {'/obj/item/stack/material/wood': 1}})
        for path in (SICKLE, HOE):
            self.assertIn('"%s" = "basic_agriculture"' % path, RESEARCH)

    def test_sprite_sheet_is_current(self):
        done = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_farm_tools.py'), '--check'],
                              capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
        for state in ('sickle', 'hoe'):
            self.assertIn('icon_state = "%s"' % state, SOURCE)


if __name__ == '__main__':
    unittest.main()
