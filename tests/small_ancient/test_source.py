"""Clay tablets, board games and the ice house: source contracts. Behaviour is in probe.dm:

    python3 tests/small_ancient/test_source.py
    python3 tests/ecology_spawning/run_linux.py . tests/small_ancient/probe.dm
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


class SmallAncientSource(unittest.TestCase):
    def test_states(self):
        self.assertTrue({'clay_tablet', 'clay_tablet_words', 'clay_tablet_fired', 'clay_tablet_fired_words',
                         'stylus', 'senet', 'chess', 'ice_house', 'ice_house_open', 'ice_block'} <= dmi_states('icons/obj/small_ancient.dmi'))

    def test_kiln_and_ice_house_hooks(self):
        self.assertIn('CT.fire_tablet()', read('code/game/objects/structures/kitchen/oven.dm'))
        self.assertIn('decaytimer += IH.is_cold() ? 50 : 300', read('code/modules/reagents/reagent_containers/food.dm'))

    def test_recipes_are_researched(self):
        recipes = read('config/crafting/material_recipes_global.txt')
        research = read('code/modules/research_tree/research_node.dm')
        for path in ('/obj/item/weapon/paper/clay_tablet', '/obj/item/weapon/pen/stylus', '/obj/item/game_board/senet',
                     '/obj/item/game_board/chess', '/obj/structure/closet/ice_house'):
            self.assertIn(f',{path},', recipes)
            self.assertIn(f'"{path}" = "', research)


if __name__ == '__main__':
    unittest.main()
