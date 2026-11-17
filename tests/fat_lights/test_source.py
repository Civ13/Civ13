"""Animal fat as light fuel: source contracts. Behaviour is in probe.dm:

    python3 tests/fat_lights/test_source.py
    python3 tests/ecology_spawning/run_linux.py . tests/fat_lights/probe.dm
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def dmi_states(path):
    from PIL import Image
    meta = Image.open(ROOT / path).info['Description']
    return {line.split('"')[1] for line in meta.splitlines() if line.startswith('state = ')}


def rates(block_owner, text):
    block = re.search(r'^' + re.escape(block_owner) + r'\n((?:\t[^\n]*\n|\n)*)', text, re.M)[1]
    listed = re.search(r'refuel_reagents = list\(([^)]*)\)', block)[1]
    return {name: int(value) for name, value in re.findall(r'"(\w+)" = (\d+)', listed)}


class FatLightsSource(unittest.TestCase):
    def test_states(self):
        self.assertEqual({'grease_horn', 'grease_horn_open', 'fat_lamp', 'fat_lamp-on'},
                         dmi_states('icons/obj/fat_lights.dmi'))

    def test_rendered_oil_is_worth_the_fat_it_came_from(self):
        # A piece of fat is 10 lard and renders to 5 fat oil, so oil burns twice as long a unit.
        self.assertIn('reagents.add_reagent("lard", 10)', read('code/modules/reagents/reagent_containers/food/snacks/meat.dm'))
        self.assertIn('I.reagents.add_reagent("fat_oil", lard_amnt/2)', read('code/game/objects/structures/kitchen/oven.dm'))
        lantern = read('code/modules/1713/lantern.dm')
        lamp = read('code/modules/1713/fat_lights.dm')
        seconds = {}
        for owner, text in (('/obj/item/flashlight/torch', lantern), ('/obj/item/flashlight/tiki_torch', lantern),
                            ('/obj/item/flashlight/lantern', lantern), ('/obj/item/flashlight/lantern/fat_lamp', lamp)):
            listed = rates(owner, text)
            self.assertEqual(listed['fat_oil'], 2 * listed['lard'], owner)
            seconds[owner] = 10 * listed['lard']
        # Seconds of light from one piece: torch 10 min, lantern 20, the wick lamp 30.
        self.assertEqual(seconds, {'/obj/item/flashlight/torch': 600, '/obj/item/flashlight/tiki_torch': 600,
                                   '/obj/item/flashlight/lantern': 1200, '/obj/item/flashlight/lantern/fat_lamp': 1800})

    def test_a_piece_of_fat_is_used_in_part(self):
        fuel = read('code/modules/1713/light_fuel.dm')
        self.assertIn('light_fuel_fat_used(C)', fuel)
        self.assertNotIn('TORCH_FAT_FUEL', fuel)
        body = fuel.split('/obj/item/flashlight/torch/attackby(', 1)[1].split('\n/', 1)[0]
        self.assertIn('refuel_from_container(W, user)', body)
        self.assertNotIn('qdel(W)', body)

    def test_fat_by_species_is_not_capped_at_two(self):
        harvest = read('code/modules/1713/animal_harvest.dm')
        self.assertIn('harvest_skill_amount(harvest_fat_pieces(size), harvest_bonus)', harvest)
        body = harvest.split('/mob/living/simple_animal/proc/harvest_fat_pieces(size)\n', 1)[1].split('\n/', 1)[0]
        self.assertIn('/mob/living/simple_animal/hostile/mammoth))\n\t\treturn 8', body)
        self.assertIn('if (!has_fat)\n\t\treturn 0', body)

    def test_recipes_are_researched(self):
        recipes = read('config/crafting/material_recipes_global.txt')
        research = read('code/modules/research_tree/research_node.dm')
        for path, node in (('/obj/item/weapon/reagent_containers/glass/grease_horn', 'basic_tools'),
                           ('/obj/item/flashlight/lantern/fat_lamp', 'primitive_construction')):
            self.assertIn(f',{path},', recipes)
            self.assertIn(f'"{path}" = "{node}"', research)


if __name__ == '__main__':
    unittest.main()
