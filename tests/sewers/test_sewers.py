"""Sewers phase S1: source contract checks. The behaviour is in probe.dm:

    python3 tests/sewers/test_sewers.py
    python3 tests/ecology_spawning/run_linux.py . tests/sewers/probe.dm
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SEWERS = (ROOT / 'code/modules/1713/sewers.dm').read_text(encoding='utf-8')


class SewersSource(unittest.TestCase):
    def test_states_exist_in_the_sheet(self):
        from PIL import Image
        meta = Image.open(ROOT / 'icons/obj/sewers.dmi').info['Description']
        states = {line.split('"')[1] for line in meta.splitlines() if line.startswith('state = ')}
        for j in range(16):
            self.assertIn(f'ditch{j}', states)
            self.assertIn(f'stone_drain{j}', states)
        for fill in range(4):
            self.assertIn(f'cesspit{fill}', states)
        self.assertIn('outfall', states)
        for j in range(16):
            self.assertIn(f'brick_drain{j}', states)
        self.assertIn('flap_gate', states)
        self.assertIn('clog', states)
        for kind in ('steam', 'electric'):
            self.assertIn(f'pump_{kind}', states)
            self.assertIn(f'pump_{kind}_on', states)
        for fill in range(4):
            self.assertIn(f'septic{fill}', states)
            self.assertIn(f'settling{fill}', states)
        self.assertIn('image(icon, "clog")', SEWERS)
        self.assertIn('icon_state = "[junction_prefix][junction]"', SEWERS)
        self.assertIn('image(icon, "outfall", dir = d)', SEWERS)

    def test_toilets_flush_through_the_sewer(self):
        poo = (ROOT / 'code/game/mob/living/carbon/human/shit_piss.dm').read_text(encoding='utf-8')
        self.assertIn('T.flush_waste(V)', poo)
        closet = (ROOT / 'code/game/objects/structures/watercloset.dm').read_text(encoding='utf-8')
        self.assertIn('return (sewers && sewer_fouls_near(src)) || well_river_seepage()', closet)
        self.assertIn('return map && map.persistence', SEWERS)

    def test_digging_and_recipe(self):
        tools = (ROOT / 'code/modules/1713/tools.dm').read_text(encoding='utf-8')
        self.assertIn('"Drain Ditch", "Cesspit"', tools)
        self.assertIn('shovel_dig_sewer(user, TB, input == "Cesspit")', tools)
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        self.assertIn('RECIPE: /material/stone/,stone drain,/obj/structure/sewer_piece/drain/stone,', recipes)
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn('"/obj/structure/sewer_piece/drain/stone" = "sanitation",', research)
        self.assertIn('RECIPE: /material/wood/,flap gate,/obj/structure/sewer_flap_gate,', recipes)
        self.assertIn('"/obj/structure/sewer_flap_gate" = "sanitation",', research)
        self.assertIn('RECIPE: /material/stonebrick/,brick sewer,/obj/structure/sewer_piece/drain/brick,', recipes)
        self.assertIn('"/obj/structure/sewer_piece/drain/brick" = "imperial_architecture",', research)
        for name, path, node in (
                ('steam sewer pump', '/obj/structure/sewer_pump/steam', 'steam_power'),
                ('electric sewage pump', '/obj/structure/sewer_pump/electric', 'utilities'),
                ('settling tank', '/obj/structure/sewer_settling_tank', 'germ_theory'),
                ('septic tank', '/obj/structure/sewer_piece/cesspit/septic', 'public_health')):
            self.assertRegex(recipes, rf'RECIPE: /material/\w+/,{name},{path},')
            self.assertIn(f'"{path}" = "{node}",', research)

    def test_steam_sewer_pump_examine_identifies_its_placement(self):
        definition = SEWERS.split('/obj/structure/sewer_pump/steam\n', 1)[1].split('\n/', 1)[0]
        self.assertIn('name = "steam sewer pump"', definition)
        examine = SEWERS.split('/obj/structure/sewer_pump/steam/examine(', 1)[1].split('\n/', 1)[0]
        self.assertIn("Use it on a sewer outfall. It does not pump a cellar, mine or ship's bilge.", examine)

    def test_hollows_drain_once_a_minute(self):
        hollows = (ROOT / 'code/modules/1713/flood_hollows.dm').read_text(encoding='utf-8')
        self.assertIn('\t// Drains in hollows and pumping stations (sewers.dm).\n\tdrain_hollows()', hollows)
        self.assertIn('\t\t// Pumping stations still burn fuel (sewers.dm).\n\t\tdrain_hollows()', hollows)
        tick = SEWERS.split('/datum/river_flood/proc/drain_hollow_water()', 1)[1].split('\n/', 1)[0]
        self.assertIn('for (var/obj/structure/sewer_piece/drain/D in sewer_drains)', tick)
        self.assertNotIn('range(', tick)
        self.assertIn('return key == "hollow_id" || key == "outfall_cache"', SEWERS)

    def test_cheap_and_save_safe(self):
        # The network is walked only on a flush, never on a timer or over the world.
        self.assertNotIn('in world', SEWERS)
        self.assertIsNone(re.search(r'(?<![_\w])spawn\(', SEWERS), 'no timers in sewers.dm')
        self.assertIn('#define SEWER_WALK_LIMIT 600', SEWERS)
        self.assertIn('return key == "last_waste" || ..()', SEWERS)
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertLess(dme.index('structures\\watercloset.dm"'), dme.index('1713\\sewers.dm"'))
        self.assertLess(dme.index('1713\\tools.dm"'), dme.index('1713\\sewers.dm"'))


if __name__ == '__main__':
    unittest.main()
