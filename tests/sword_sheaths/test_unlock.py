"""Sword sheath recipes unlock with the swords they hold and stay craftable while swords are forged."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RECIPES = ROOT / 'config/crafting/material_recipes_global.txt'
NODES = ROOT / 'code/modules/research_tree/research_node.dm'
SMITHING = ROOT / 'code/game/objects/structures/blacksmithing/blacksmithing_recipes.dm'
SHEATHS = ('/obj/item/clothing/accessory/storage/sheath', '/obj/item/clothing/accessory/storage/sheath/longer',
           '/obj/item/clothing/accessory/storage/sheath/longsword', '/obj/item/clothing/accessory/storage/sheath/katana',
           '/obj/item/clothing/accessory/storage/sheath/daisho')


def node_of(path):
    found = re.findall(r'"%s"\s*=\s*"(\w+)"' % re.escape(path), NODES.read_text(encoding='utf-8-sig'))
    return found[-1] if found else None


class SwordSheathUnlock(unittest.TestCase):
    def test_short_sheath_unlocks_with_bronze_swords(self):
        self.assertEqual(node_of('/obj/item/weapon/material/sword/gladius'), 'bronze_weapons')
        self.assertEqual(node_of('/obj/item/clothing/accessory/storage/sheath'), 'bronze_weapons')

    def test_sheaths_craftable_in_every_sword_era(self):
        sword_max = max(int(m) for m in re.findall(r'"swords",\d+,(\d+),', SMITHING.read_text(encoding='utf-8-sig')))
        rows = {}
        for line in RECIPES.read_text(encoding='utf-8-sig').splitlines():
            if line.startswith('RECIPE: /material/leather/,'):
                parts = line[len('RECIPE: '):].split(',')
                rows[parts[2]] = int(parts[11])
        for path in SHEATHS:
            with self.subTest(path=path):
                self.assertIn(path, rows)
                self.assertGreaterEqual(rows[path], sword_max)


if __name__ == '__main__':
    unittest.main()
