"""Offline checks: terracotta floors are laid from kiln-fired tiles, not raw clay."""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/art_ports'))
from pocket_stronghold_food import state_names  # noqa: E402

SOURCE = (ROOT / 'code/modules/1713/terracotta_floors.dm').read_text(encoding='utf-8')
COVERS = (ROOT / 'code/game/objects/covers_types/cover_floortypes.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
FAMILY = '/obj/covers/stone/slab/decorative/terracotta'
FLOORS = {
    FAMILY: 'pottery_storage',
    FAMILY + '/edge': 'pottery_storage',
    FAMILY + '/inside': 'pottery_storage',
    FAMILY + '/outside': 'pottery_storage',
    FAMILY + '/inset': 'pottery_storage',
    '/obj/covers/brick_paving': 'brickmaking',
}


def body(head):
    match = re.search(r'^' + re.escape(head) + r'\n((?:^[ \t].*\n)+)', COVERS, re.M)
    assert match, head
    return match[1]


class TerracottaFloorTest(unittest.TestCase):
    def test_tiles_are_shaped_from_clay_then_fired(self):
        self.assertRegex(RECIPES, r'RECIPE: /material/clay/,unfired terracotta tiles,/obj/item/weapon/clay/floortiles,')
        self.assertIn('result = /obj/item/stack/material/terracotta', SOURCE)
        # No recipe hands out fired tiles directly; the kiln is the only source.
        self.assertNotIn(',/obj/item/stack/material/terracotta,', RECIPES)
        self.assertIn('"/obj/item/weapon/clay/floortiles" = "pottery_storage"', NODES)

    def test_every_floor_is_laid_from_fired_tiles_and_gated(self):
        for path, node in FLOORS.items():
            with self.subTest(path=path):
                rows = [r for r in RECIPES.splitlines() if r.startswith('RECIPE: ') and r.split(',')[2] == path]
                self.assertEqual(len(rows), 1)
                self.assertTrue(rows[0].startswith('RECIPE: /material/terracotta/,'))
                self.assertIn(f'"{path}" = "{node}"', NODES)
        for head in (FAMILY, '/obj/covers/brick_paving'):
            self.assertIn('buildstack = /obj/item/stack/material/terracotta', body(head))

    def test_only_border_pieces_turn(self):
        for suffix, turns in (('', False), ('/edge', True), ('/inside', True), ('/outside', True), ('/inset', False)):
            with self.subTest(suffix=suffix):
                self.assertEqual('directional_border = TRUE' in body(FAMILY + suffix), turns)
        self.assertIn('var/directional_border = FALSE', body(FAMILY))
        self.assertIn('verbs -= /obj/covers/stone/slab/decorative/terracotta/verb/rotate_border', SOURCE)
        rotate = SOURCE.split('verb/rotate_border()', 1)[1]
        for guard in ('!directional_border', 'usr.incapacitated()', '!usr.Adjacent(src)', 'persistence_save_in_progress'):
            self.assertLess(rotate.index(guard), rotate.index('set_dir('))

    def test_art_and_include_exist(self):
        self.assertIn('sheet-terracotta-tile', state_names(ROOT / 'icons/obj/materials.dmi'))
        states = state_names(ROOT / 'icons/turf/flooring/terracotta.dmi')
        for state in ('terracotta', 'terracotta_edge', 'terracotta_inner', 'terracotta_outer',
                      'terracotta_inset', 'brick_paving'):
            self.assertIn(state, states)
        self.assertIn('#include "code\\modules\\1713\\terracotta_floors.dm"', (ROOT / 'civ13.dme').read_text())


if __name__ == '__main__':
    unittest.main()
