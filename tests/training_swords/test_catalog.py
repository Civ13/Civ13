"""Training sword availability in the global crafting catalog (#6270).

The softwood training sword must stay craftable wherever the bamboo one is,
so a region past the softwood row's last age still has a plank route.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / 'config/crafting/material_recipes_global.txt'


def training_rows():
    rows = {}
    for line in CATALOG.read_text(encoding='utf-8-sig').splitlines():
        if not line.startswith('RECIPE: '):
            continue
        fields = line[len('RECIPE: '):].split(',')
        if fields[1] == 'training sword':
            rows[fields[0]] = fields
    return rows


class TrainingSwords(unittest.TestCase):
    def test_both_routes_exist(self):
        rows = training_rows()
        self.assertIn('/material/wood/soft/', rows)
        self.assertIn('/material/bamboo/', rows)

    def test_softwood_lasts_as_long_as_bamboo(self):
        rows = training_rows()
        soft, bamboo = rows['/material/wood/soft/'], rows['/material/bamboo/']
        self.assertGreaterEqual(int(soft[11]), int(bamboo[11]))

    def test_types_costs_and_gate_are_unchanged(self):
        rows = training_rows()
        soft, bamboo = rows['/material/wood/soft/'], rows['/material/bamboo/']
        self.assertEqual(soft[2], '/obj/item/weapon/material/sword/training')
        self.assertEqual(bamboo[2], '/obj/item/weapon/material/sword/training/bamboo')
        self.assertEqual((soft[3], bamboo[3]), ('8', '8'))
        self.assertEqual(soft[7], 'weapons')


if __name__ == '__main__':
    unittest.main()
