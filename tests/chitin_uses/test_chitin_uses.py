"""Offline checks: chitin has a source, player recipes and research gates.

Run: python3 -m unittest tests/chitin_uses/test_chitin_uses.py
"""
import os
import re
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CATALOGS = ('config/crafting/material_recipes_global.txt', 'config/crafting/material_recipes_crustacean.txt')
PRODUCTS = ('/obj/item/clothing/mask/chitinmask', '/obj/item/clothing/head/helmet/chitin',
            '/obj/item/clothing/suit/armor/chitin', '/obj/item/weapon/shield/chitin',
            '/obj/item/weapon/shield/chitin/large', '/obj/item/weapon/material/harpoon/chitin',
            '/obj/item/stack/barter_beads/chitin', '/obj/item/stack/crushed_shell')


def read(rel):
    with open(os.path.join(ROOT, rel), encoding='utf-8', errors='replace') as f:
        return f.read()


def chitin_rows(rel):
    out = {}
    for line in read(rel).splitlines():
        if line.startswith('RECIPE: /material/chitin/,') and '//' not in line:
            row = line[len('RECIPE: '):].split(',')
            out[row[2]] = row
    return out


class ChitinUses(unittest.TestCase):
    def test_catalogs_craft_every_chitin_product(self):
        for catalog in CATALOGS:
            rows = chitin_rows(catalog)
            for path in PRODUCTS:
                with self.subTest(catalog=catalog, path=path):
                    self.assertIn(path, rows)
                    self.assertEqual(len(rows[path]), 13)
            self.assertEqual(rows['/obj/item/weapon/material/harpoon/chitin'][12], 'chitin')

    def test_every_product_has_a_research_node(self):
        nodes = read('code/modules/research_tree/research_node.dm')
        for path in PRODUCTS:
            with self.subTest(path=path):
                self.assertIn(f'"{path}" = "', nodes)

    def test_butchering_drops_chitin_scaled_by_hunting(self):
        harvest = read('code/modules/1713/animal_harvest.dm')
        self.assertIn('proc/harvest_chitin_pieces()', harvest)
        self.assertIn('harvest_skill_amount(harvest_chitin_pieces(), harvest_bonus)', harvest)
        self.assertIn('new /obj/item/stack/material/chitin(site, chitin_pieces)', harvest)
        for species in ('crab/small/trilobite', 'crab)', 'hostile/phosphor_beetle'):
            self.assertIn('/mob/living/simple_animal/' + species, harvest)

    def test_lime_kiln_burns_crushed_shell(self):
        kiln = read('code/modules/1713/clay_lime_fire.dm')
        self.assertIn('return stone_charge + marble_charge + shell_charge', kiln)
        self.assertIn('istype(S, /obj/item/stack/crushed_shell)', kiln)
        self.assertIn('new /obj/item/stack/crushed_shell(get_turf(src), shell_charge)', kiln)

    def test_crushed_shell_fertilises_one_handful_at_a_time(self):
        shell = read('code/modules/1713/chitin_uses.dm')
        self.assertRegex(shell, r'/obj/item/stack/crushed_shell\n(\t.*\n)*?\tfertilizer_value = [1-9]\d*')
        self.assertIn('FS.use(1)', read('code/game/turfs/floor_attackby.dm'))
        self.assertIn('#include "code\\modules\\1713\\chitin_uses.dm"', read('civ13.dme'))


if __name__ == '__main__':
    unittest.main()
