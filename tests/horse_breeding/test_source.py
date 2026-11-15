"""Horse breaking, breeding and shoeing: source contracts. Behaviour is in probe.dm:

    python3 tests/horse_breeding/test_source.py
    python3 tests/ecology_spawning/run_linux.py . tests/horse_breeding/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = (ROOT / 'code/modules/1713/horse_breeding.dm').read_text(encoding='utf-8')


def dmi_states(path):
    from PIL import Image
    meta = Image.open(ROOT / path).info['Description']
    return {line.split('"')[1] for line in meta.splitlines() if line.startswith('state = ')}


class HorseSource(unittest.TestCase):
    def test_states(self):
        states = dmi_states('icons/mob/animal_64.dmi')
        for n in ('', '2', '3', '4'):
            self.assertIn(f'foal{n}', states)
            self.assertIn(f'foal{n}_dead', states)
        self.assertTrue({'horseshoe', 'horseshoe_worn'} <= dmi_states('icons/obj/horseshoes.dmi'))

    def test_ride_delay_is_used_by_players_and_agents(self):
        move = (ROOT / 'code/game/mob/mob_movement.dm').read_text(encoding='utf-8')
        agent = (ROOT / 'code/modules/agent_control/agent_movement.dm').read_text(encoding='utf-8')
        self.assertIn('move_delay = HH.riding_mob.ride_delay() + HH.riding_mob.hitch_drag()', move)
        self.assertIn('delay = H.riding_mob.ride_delay() + H.riding_mob.hitch_drag()', agent)

    def test_recipe_and_battle_maps(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn('RECIPE: /material/iron/,horseshoes,/obj/item/horseshoes,', recipes)
        self.assertIn('"/obj/item/horseshoes" = "iron_smithing",', research)
        self.assertIn('if (!map || !map.persistence)\n\t\treturn FALSE', SRC)


if __name__ == '__main__':
    unittest.main()
