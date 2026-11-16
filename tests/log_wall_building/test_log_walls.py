"""Offline contracts for log walls built in steps. Behaviour is covered by the
native probe: python3 tests/ecology_spawning/run_linux.py . tests/log_wall_building/probe.dm 300
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/covers_types/log_wall_building.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
WALLS = (ROOT / 'code/game/objects/covers_types/cover_walltypes.dm').read_text(encoding='utf-8')


def define(name):
    return int(re.search(r'#define ' + name + r' (\d+)', SOURCE)[1])


def recipe(name):
    for line in RECIPES.splitlines():
        cols = line.split(',')
        if line.startswith('RECIPE: ') and cols[1] == name:
            return cols
    return None


class LogWallTests(unittest.TestCase):
    def test_included_after_wall_types(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        self.assertLess(dme.index('#include "code\\game\\objects\\covers_types\\cover_walltypes.dm"'),
                        dme.index('#include "code\\game\\objects\\covers_types\\log_wall_building.dm"'))

    def test_menu_lays_only_the_sill(self):
        for name, path in (('log wall', '/obj/covers/wood_wall/log_build'),
                           ('log wall corner', '/obj/covers/wood_wall/log_build/corner')):
            with self.subTest(name=name):
                cols = recipe(name)
                self.assertEqual((cols[2], cols[3]), (path, '1'))

    def test_cabin_totals_land_in_the_asked_ranges(self):
        logs = define('LOG_WALL_LOGS')
        self.assertEqual(logs, 4)
        support = int(recipe('roof support')[3])
        # Walls on the outer ring of tiles, one door, two roof supports.
        def cabin(w, h):
            return (2 * (w + h) - 4 - 1) * logs + 2 * support
        self.assertTrue(60 <= cabin(5, 5) <= 100)
        self.assertTrue(67 <= cabin(6, 7) <= 99)

    def test_carved_styles_need_no_recipe_of_their_own(self):
        self.assertIsNone(recipe('nordic wall'))
        self.assertIsNone(recipe('aztec wall'))
        for style in ('nordic', 'aztec'):
            self.assertIn('/obj/covers/wood_wall/' + style, SOURCE)

    def test_finished_wall_is_the_strongest_timber_wall(self):
        block = WALLS[WALLS.index('/obj/covers/wood_wall/log\n'):]
        self.assertRegex(block[:400], r'health = 450')
        self.assertEqual(define('LOG_WALL_UNFITTED_HEALTH') + define('LOG_WALL_NOTCH_BONUS'), 450)

    def test_map_walls_load_finished(self):
        self.assertIn('var/notched = TRUE', SOURCE)
        self.assertIn('var/chinked = TRUE', SOURCE)

    def test_insulation_reads_chinking(self):
        text = (ROOT / 'code/game/objects/building_insulation.dm').read_text(encoding='utf-8')
        self.assertIn('L.chinked ? 0.8 : 0.5', text)


if __name__ == '__main__':
    unittest.main()
