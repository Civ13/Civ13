"""Offline checks: mined marble is rough blocks; bricks are a crafting step."""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/art_ports'))
from pocket_stronghold_food import state_names  # noqa: E402


class MarbleBrickTest(unittest.TestCase):
    def test_mining_still_gives_rough_blocks(self):
        mining = (ROOT / 'code/game/turfs/floor_attackby.dm').read_text(encoding='utf-8')
        self.assertIn('new/obj/item/stack/material/marble(src)', mining)
        self.assertNotIn('marblebrick', mining)

    def test_brick_recipes_are_mapped(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertRegex(recipes, r'RECIPE: /material/marble/,marble bricks,/obj/item/stack/material/marblebrick,')
        self.assertRegex(recipes, r'RECIPE: /material/marblebrick/,marble brick wall,/obj/covers/marble_wall/plain/brick,')
        for path in ('/obj/item/stack/material/marblebrick', '/obj/covers/marble_wall/plain/brick'):
            self.assertIn(f'"{path}" = "brickmaking"', nodes)

    def test_sprites_exist(self):
        self.assertIn('sheet-marble-brick', state_names(ROOT / 'icons/obj/materials.dmi'))
        self.assertIn('b_brick_marble_wall', state_names(ROOT / 'icons/turf/walls.dmi'))
        source = (ROOT / 'code/modules/1713/marble_bricks.dm').read_text(encoding='utf-8')
        self.assertIn('icon_state = "sheet-marble-brick"', source)


if __name__ == '__main__':
    unittest.main()
