"""Ship's draughts (code/modules/naval/ship_draught.dm) reckon a ship's cost
from the same hand recipes players build her with, and her burden and
ballast from the same figures her ledger uses afloat. Stdlib only.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/naval/ship_draught.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8', errors='replace')
LOAD = (ROOT / 'code/modules/naval/hull_load.dm').read_text(encoding='utf-8')

# What the draught calls a material, as the recipe file names it.
MATERIALS = {'wood': ('/material/wood/soft/', '/material/wood/'), 'steel': ('/material/steel/',), 'iron': ('/material/iron/',)}
# A floor or piece whose recipe makes something else first: the floor cover
# item lays the plank floor, and a plank wall is a wall frame and 4 planks.
RECIPE_PATH = {
    '/obj/covers/repairedfloor': '/obj/item/weapon/covers',
    '/obj/covers/wood_wall/adjustable': '/obj/structure/wallframe',
}


def recipe_costs():
    out = {}
    for line in RECIPES.splitlines():
        if not line.startswith('RECIPE: '):
            continue
        fields = line[len('RECIPE: '):].split(',')
        if len(fields) == 13:
            out.setdefault(fields[2].strip(), []).append((fields[0].strip(), float(fields[3])))
    return out


def table(name):
    block = SOURCE.split('var/global/list/%s = list(' % name, 1)[1].split('\n)\n', 1)[0]
    rows = {}
    for key, path, cost in re.findall(r'"(\w)" = list\("name" = "[^"]+", "path" = (/[\w/]+), "cost" = list\(([^)]*)\)', block):
        rows[key] = (path, dict((m, int(n)) for m, n in re.findall(r'"(\w+)" = (\d+)', cost)))
    return rows


class DraughtSources(unittest.TestCase):
    def test_costs_match_hand_recipes(self):
        recipes = recipe_costs()
        rows = {**table('ship_draught_floors'), **table('ship_draught_pieces')}
        self.assertGreaterEqual(len(rows), 14)
        for key, (path, cost) in rows.items():
            with self.subTest(piece=key, path=path):
                rows_for = recipes.get(RECIPE_PATH.get(path, path))
                self.assertTrue(rows_for, 'no hand recipe for %s' % path)
                bought = {m: n for m, n in cost.items() if m != 'planks'}
                self.assertEqual(len(bought), 1)
                (name, number), = bought.items()
                self.assertIn((number), [amount for material, amount in rows_for if material in MATERIALS[name]], rows_for)

    def test_plank_wall_takes_the_frame_boards(self):
        boards = re.search(r'#define WALLFRAME_PLANK_BOARDS (\d+)', (ROOT / 'code/modules/1713/structures.dm').read_text(encoding='utf-8')).group(1)
        self.assertEqual(table('ship_draught_pieces')['W'][1]['planks'], int(boards))

    def test_burden_and_ballast_follow_the_ledger(self):
        for mine, theirs in (('DRAUGHT_BURDEN_PER_TILE', 'HULL_BURDEN_PER_TILE'), ('DRAUGHT_BALLAST_PER_MAST', 'HULL_BALLAST_PER_MAST')):
            a = re.search(r'#define %s ([\d.]+)' % mine, SOURCE).group(1)
            b = re.search(r'#define %s ([\d.]+)' % theirs, LOAD).group(1)
            self.assertEqual(float(a), float(b), mine)


if __name__ == '__main__':
    unittest.main()
