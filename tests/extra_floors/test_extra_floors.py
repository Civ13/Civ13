"""Offline checks: the extra floors and pelt rugs are buildable, gated and drawn."""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/art_ports'))
from pocket_stronghold_food import state_names  # noqa: E402

SOURCE = (ROOT / 'code/modules/1713/extra_floors.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
SHEETS = (ROOT / 'code/modules/materials/material_sheets.dm').read_text(encoding='utf-8')

# path: (icon state, recipe material, build stack, research node, burns)
FLOORS = {
    '/obj/covers/flagstone': ('flagstone', 'stone', 'stone', 'stone_masonry', False),
    '/obj/covers/copper_plate': ('copper_plate', 'copper', 'copper', 'bronze_working', False),
    '/obj/covers/bronze_plate': ('bronze_plate', 'bronze', 'bronze', 'bronze_working', False),
    '/obj/covers/lead_sheet': ('lead_sheet', 'lead', 'lead', 'bronze_working', False),
    '/obj/covers/glass_block': ('glass_block', 'glass', 'glass', 'glassworking', False),
    '/obj/covers/rush_matting': ('rush_matting', 'leaf', 'leaf', 'primitive_construction', True),
    '/obj/covers/obsidian_tile': ('obsidian_tile', 'obsidian', 'obsidian', 'imperial_architecture', False),
    '/obj/covers/steel_tread': ('steel_tread', 'steel', 'steel', 'reinforced_concrete', False),
}
# path: (icon state, recipe material, pelt stack)
RUGS = {
    '/obj/structure/pelt_rug': ('bear_brown', 'bearpelt/brown', 'pelt/bearpelt/brown'),
    '/obj/structure/pelt_rug/black': ('bear_black', 'bearpelt/black', 'pelt/bearpelt/black'),
    '/obj/structure/pelt_rug/white': ('bear_white', 'bearpelt/white', 'pelt/bearpelt/white'),
    '/obj/structure/pelt_rug/wolf': ('wolf', 'wolfpelt', 'pelt/wolfpelt'),
    '/obj/structure/pelt_rug/wolf/white': ('wolf_white', 'whitewolfpelt', 'pelt/wolfpelt/white'),
}


def body(head):
    match = re.search(r'^' + re.escape(head) + r'\n((?:^[ \t].*\n)+)', SOURCE, re.M)
    assert match, head
    return match[1]


def recipe(path):
    rows = [r for r in RECIPES.splitlines() if r.startswith('RECIPE: ') and r.split(',')[2] == path]
    assert len(rows) == 1, (path, rows)
    return rows[0].split(',')


class ExtraFloorTest(unittest.TestCase):
    def test_each_floor_is_laid_from_its_own_material(self):
        for path, (_, material, stack, node, _) in FLOORS.items():
            with self.subTest(path=path):
                row = recipe(path)
                self.assertEqual(row[0], f'RECIPE: /material/{material}/')
                self.assertEqual(row[3], '1')
                self.assertIn(f'buildstack = /obj/item/stack/material/{stack}\n', body(path))
                self.assertIn(f'\n/obj/item/stack/material/{stack}\n', SHEETS)
                self.assertIn(f'"{path}" = "{node}"', NODES)

    def test_floors_are_walkable_floor_covers(self):
        for path, (state, _, _, _, burns) in FLOORS.items():
            with self.subTest(path=path):
                text = body(path)
                for line in (f'icon_state = "{state}"', 'wood = FALSE', 'layer = 1.99', 'amount = 0',
                             'passable = TRUE', f'flammable = {"TRUE" if burns else "FALSE"}'):
                    self.assertIn(line, text)
                self.assertNotRegex(text, r'\bdensity\s*=')
                health = int(re.search(r'\bhealth = (\d+)', text)[1])
                self.assertEqual(health, int(re.search(r'maxhealth = (\d+)', text)[1]))

    def test_toughness_follows_the_material(self):
        health = {path: int(re.search(r'\bhealth = (\d+)', body(path))[1]) for path in FLOORS}
        order = ('/obj/covers/rush_matting', '/obj/covers/glass_block', '/obj/covers/lead_sheet',
                 '/obj/covers/obsidian_tile', '/obj/covers/copper_plate', '/obj/covers/flagstone',
                 '/obj/covers/bronze_plate', '/obj/covers/steel_tread')
        self.assertEqual(sorted(FLOORS, key=health.get), list(order))

    def test_rugs_lie_on_the_floor_and_return_their_pelts(self):
        for path, (state, material, stack) in RUGS.items():
            with self.subTest(path=path):
                row = recipe(path)
                self.assertEqual(row[0], f'RECIPE: /material/{material}/')
                self.assertEqual(row[3], '2')
                text = body(path)
                self.assertIn(f'icon_state = "{state}"', text)
                self.assertIn(f'pelt = /obj/item/stack/material/{stack}\n', text)
                self.assertIn(f'\n/obj/item/stack/material/{stack}\n', SHEETS)
                self.assertIn(f'"{path}" = "weaving"', NODES)
        base = body('/obj/structure/pelt_rug')
        for line in ('density = FALSE', 'anchored = TRUE', 'layer = 2.05', 'flammable = TRUE', 'pelts = 2'):
            self.assertIn(line, base)
        take = body('/obj/structure/pelt_rug/verb/take_up_rug()')
        self.assertLess(take.index('do_after(H, 20, src)'), take.index('new pelt(get_turf(src), pelts)'))
        self.assertLess(take.index('new pelt(get_turf(src), pelts)'), take.index('qdel(src)'))
        self.assertNotIn('/obj/covers/pelt', SOURCE)

    def test_a_pelt_rug_counts_as_a_covered_floor_at_home(self):
        comfort = (ROOT / 'code/game/mob/living/carbon/human/home_comfort.dm').read_text(encoding='utf-8')
        self.assertIn('pelt_rug_covers(T)', comfort)
        self.assertIn('/proc/pelt_rug_covers(turf/T)', SOURCE)

    def test_art_and_include_exist(self):
        floors = state_names(ROOT / 'icons/turf/flooring/extra_floors.dmi')
        for state, *_ in FLOORS.values():
            self.assertIn(state, floors)
        rugs = state_names(ROOT / 'icons/obj/pelt_rugs.dmi')
        for state, *_ in RUGS.values():
            self.assertIn(state, rugs)
        self.assertIn('#include "code\\modules\\1713\\extra_floors.dm"', (ROOT / 'civ13.dme').read_text())


if __name__ == '__main__':
    unittest.main()
