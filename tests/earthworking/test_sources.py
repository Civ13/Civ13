"""Offline wiring checks for heavy earthwork (code/modules/1713/earthworking_heavy.dm).

The native probe (probe.dm, run with tests/ecology_spawning/run_linux.py)
checks the scraper swath, tipping, the steam shovel's cut job and the
blasting charge against real terrain heights.
"""
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class Wiring(unittest.TestCase):
    def test_included(self):
        dme = read('civ13.dme')
        self.assertIn('#include "code\\modules\\1713\\earthworking_heavy.dm"', dme)

    def test_recipes_and_research(self):
        recipes = read('config/crafting/material_recipes_global.txt')
        self.assertIn('RECIPE: /material/iron/,slip scraper,/obj/structure/closet/crate/cart/slip_scraper,6,150,1,1,logistics,', recipes)
        self.assertIn('RECIPE: /material/wood/,empty blasting charge,/obj/item/weapon/grenade/blasting_charge,1,40,0,1,tools,', recipes)
        nodes = read('code/modules/research_tree/research_node.dm')
        self.assertIn('"/obj/structure/closet/crate/cart/slip_scraper" = "wagons_ships"', nodes)
        self.assertIn('"/obj/item/weapon/grenade/blasting_charge" = "gunpowder"', nodes)

    def test_scraper_needs_a_draft_animal_and_respects_grading_rules(self):
        module = read('code/modules/1713/earthworking_heavy.dm')
        scrape = module[module.index('/obj/structure/closet/crate/cart/slip_scraper/proc/scrape(d)'):]
        scrape = scrape[:scrape.index('\n// ')]
        self.assertIn('is_draft_animal(A)', scrape)
        self.assertIn('grade_problem(T, -1)', scrape)
        self.assertIn('#define SCRAPER_LOADS 9', module)

    def test_blasting_charge_is_light_and_needs_a_flame(self):
        module = read('code/modules/1713/earthworking_heavy.dm')
        self.assertIn('explosion(O, -1, 0, 2, 1, sound = explosion_sound)', module)
        self.assertIn('is_hot(W)', module)
        self.assertIn('#define BLASTING_POWDER 15', module)

    def test_steam_shovel_offers_a_cut_job(self):
        works = read('code/modules/1713/earthworks.dm')
        self.assertIn('/obj/structure/workshop_machine/steam_site/steam_shovel/proc/cuttings()', works)
        self.assertIn('"Cut the ground down a level"', works)
        self.assertIn('terrain_grade_problem(T, -1)', works)



class Sprites(unittest.TestCase):
    def test_sprite_sheets_are_current(self):
        done = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_earthworking_tools.py'), '--check'],
                              capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)


if __name__ == '__main__':
    unittest.main()
