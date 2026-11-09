"""Offline execution of the complete stacked-yield branch with fake stack constructors.

The constructor models immediate merging, retirement and per-stack capacity.
Native material dispatch is covered separately by probe.dm, not this adapter.
"""
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/farming.dm').read_text(encoding='utf-8')
SPEC = importlib.util.spec_from_file_location('harvest_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(adapter)


def run_harvest(base, soil, roll, bonus, existing_amount, limit=50):
    body = adapter.extract(SOURCE, '/obj/structure/farming/plant/proc/spawn_produce')
    branch = body.split('if (stack <> "product_name")', 1)[1].split('\n\telse\n', 1)[0]
    branch = '\n'.join(line[1:] for line in branch.splitlines()[1:])
    # Only engine boundaries and DM-only syntax are adapted. All yield math,
    # ordering, capacity decisions and loop progress come from production.
    branch = branch.replace('text2path("/obj/item/stack/[stack]")', '"material"')
    branch = branch.replace('initial(fruitpath:max_amount)', 'stack_limit_value')
    branch = branch.replace('stack_limit ? min(total, stack_limit) : total',
                            '(min(total, stack_limit) if stack_limit else total)')
    branch = branch.replace('new fruitpath(', 'construct(')
    branch = re.sub(r'while \((.*)\)', r'while \1:', branch)
    piles = []
    if existing_amount is not None:
        piles.append(SimpleNamespace(amount=existing_amount, radiation=0, retired=False))

    def construct(location, amount):
        stack = SimpleNamespace(amount=amount, radiation=0, retired=False)
        for pile in piles:
            if pile.amount == limit or stack.amount == limit:
                continue
            transfer = min(stack.amount, limit - pile.amount)
            stack.amount -= transfer
            pile.amount += transfer
            if stack.amount <= 0:
                stack.retired = True
                break
        if not stack.retired:
            piles.append(stack)
        return stack

    env = dict(stack_amount=base, plant_nutrition=soil, bonus=bonus, radiation=8, loc=piles,
               stack_limit_value=limit, min=min, rand=lambda low, high: roll,
               harvest_skill_amount=lambda amount, fraction: amount * (1 + fraction),
               QDELETED=lambda item: item.retired, construct=construct)
    proc = adapter.project('/proc/harvest()\n' + branch + '\n', '/proc/harvest', '', env)
    proc()
    return piles


class StackedCropTests(unittest.TestCase):
    def test_yield_survives_merging(self):
        for existing in (None, 1, 49, 50):
            for base in (1, 3, 30, 75):
                for soil, roll in ((0, 1), (100, 1), (100, 2), (100, 3)):
                    for bonus in (0, 1):
                        with self.subTest(existing=existing, base=base, soil=soil, roll=roll, bonus=bonus):
                            piles = run_harvest(base, soil, roll, bonus, existing)
                            expected = (existing or 0) + base * roll * (1 + bonus)
                            self.assertEqual(sum(p.amount for p in piles), expected)
                            self.assertTrue(all(0 < p.amount <= 50 for p in piles))

    def test_existing_pile_is_still_filled(self):
        piles = run_harvest(1, 0, 1, 1, 1)
        self.assertEqual([p.amount for p in piles], [3])
        piles = run_harvest(1, 0, 1, 1, 49)
        self.assertEqual([p.amount for p in piles], [50, 1])

    def test_unmerged_output_keeps_radiation(self):
        piles = run_harvest(1, 0, 1, 1, None)
        self.assertEqual(piles[0].radiation, 4)

    def test_empty_yield_creates_no_stack(self):
        self.assertEqual(run_harvest(0, 0, 1, 1, None), [])

    def test_windows_runner_admits_the_probe(self):
        runner = (ROOT / 'tests/resource_extraction/run.ps1').read_text(encoding='utf-8')
        self.assertIn("'tests/harvest_skills/probe.dm'", runner.split('ValidateSet(', 1)[1].split(')]', 1)[0])


if __name__ == '__main__':
    unittest.main()
