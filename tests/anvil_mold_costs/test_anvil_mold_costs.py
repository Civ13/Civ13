"""Anvil mold costs come from one table instead of per-branch material ladders.

The knives, axes, swords and keys mold branches each repeated the same
material ladder (bronze column 7, copper 7 x1.2, tin 7 x1.4, gold/silver/lead/
steel column 5, iron column 6). FROZEN_LADDER is that old ladder; the test
reads anvil_mold_costs from blacksmithing_recipes.dm and checks every row
costs the same for every metal. Swords also kept their narrower metal list.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
RECIPES = ROOT / 'code/game/objects/structures/blacksmithing/blacksmithing_recipes.dm'
ANVIL = ROOT / 'code/game/objects/structures/blacksmithing/blacksmithing.dm'

FROZEN_LADDER = {'bronze': (7, 1), 'copper': (7, 1.2), 'tin': (7, 1.4), 'gold': (5, 1),
                 'silver': (5, 1), 'lead': (5, 1), 'iron': (6, 1), 'steel': (5, 1)}
FROZEN_SWORD_METALS = ('bronze', 'copper', 'iron', 'steel')


def table():
    text = RECIPES.read_text(encoding='utf-8')
    body = text[text.index('var/global/list/anvil_mold_costs = list('):]
    body = body[:body.index('\n)')]
    return {m: (int(c), float(s)) for m, c, s in re.findall(r'"(\w+)" = list\((\d+), ([\d.]+)\)', body)}


def rows():
    text = RECIPES.read_text(encoding='utf-8')
    found = {}
    for line in text.splitlines():
        line = line.split('//')[0]
        match = re.match(r'\s*"([^"]+)" = list\((.*)\),?\s*$', line)
        if not match:
            continue
        args = [a.strip() for a in match.group(2).split(',')]
        if len(args) == 9 and args[-1].startswith('/obj/'):
            found[match.group(1)] = [None] + args
    return found


class AnvilMoldCosts(unittest.TestCase):
    def test_table_matches_the_old_ladder(self):
        self.assertEqual(table(), {m: (c, float(s)) for m, (c, s) in FROZEN_LADDER.items()})

    def test_every_row_costs_what_it_did(self):
        current = table()
        recipes = rows()
        self.assertGreater(len(recipes), 100)
        for name, row in recipes.items():
            for metal, (column, scale) in FROZEN_LADDER.items():
                new_column, new_scale = current[metal]
                self.assertEqual(float(row[new_column]) * new_scale, float(row[column]) * scale, (name, metal))

    def test_branches_use_the_shared_proc(self):
        source = ANVIL.read_text(encoding='utf-8')
        self.assertEqual(source.count('/obj/structure/anvil/proc/forge_mold_recipe('), 1)
        for category in ('"knives"', '"axes"', '"keys"'):
            self.assertIn(f'return forge_mold_recipe(ML, user, H, {category})', source)
        metals = ', '.join(f'"{m}"' for m in FROZEN_SWORD_METALS)
        self.assertIn(f'return forge_mold_recipe(ML, user, H, choice, list({metals}))', source)
        # No per-branch material ladders come back.
        self.assertNotIn('current_material == "', source)

    def test_zero_cost_rows_cannot_be_forged_for_free(self):
        source = ANVIL.read_text(encoding='utf-8')
        proc = source[source.index('/obj/structure/anvil/proc/forge_mold_recipe('):source.index('/obj/structure/anvil/attackby(')]
        self.assertIn('if (mat <= 0 || ML.capacity < mat)', proc)
        self.assertLess(proc.index('if (mat <= 0'), proc.index('do_after('))
        self.assertIn('ML.current_material == material && ML.capacity >= mat', proc)


if __name__ == '__main__':
    unittest.main()
