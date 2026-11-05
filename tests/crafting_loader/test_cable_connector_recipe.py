"""Crossing and corner cables join only through a secured cable connector, so
every catalogue that sells cable must also sell the connector. Source text only."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
CONNECTOR = '/obj/item/connector'


def recipe_paths(text):
    return {line[len('RECIPE: '):].split(',')[2] for line in text.splitlines()
            if line.startswith('RECIPE: ') and '//' not in line}


class CableConnectorRecipe(unittest.TestCase):
    def test_every_catalogue_with_cable_also_crafts_the_connector(self):
        catalogues = sorted((ROOT / 'config/crafting').glob('material_recipes_*.txt'))
        with_cable = [p for p in catalogues
                      if any(path.startswith('/obj/item/stack/cable_coil/')
                             for path in recipe_paths(p.read_text(encoding='utf-8')))]
        self.assertTrue(with_cable)
        for path in with_cable:
            with self.subTest(catalogue=path.name):
                self.assertIn(CONNECTOR, recipe_paths(path.read_text(encoding='utf-8')))

    def test_connector_unlocks_with_electricity(self):
        source = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertRegex(source, re.compile(r'^\t\t"' + re.escape(CONNECTOR) + r'" = "electricity",$', re.M))


if __name__ == '__main__':
    unittest.main()
