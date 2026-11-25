"""Offline execution of the complete stacked-yield branch with fake stack constructors.

The constructor and merge boundaries model retirement and per-stack capacity.
Native material dispatch is covered separately by probe.dm, not this adapter.
"""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
POLLINATION = (ROOT / "code/modules/1713/pollination.dm").read_text(encoding="utf-8")
SOURCE = (ROOT / 'code/game/objects/farming.dm').read_text(encoding='utf-8')
SPEC = importlib.util.spec_from_file_location('harvest_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(adapter)


def run_harvest(base, soil, roll, bonus, existing_amount, limit=50,
                crop_radiation=8, existing_radiation=0, pollinated=False):
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

    class Stack:
        def __init__(self, amount, radiation):
            self.amount = amount
            self.radiation = radiation
            self.type = "material"
            self.retired = False
            self.can_stack = True

        def merge(self, pile):
            if pile.amount == limit or self.amount == limit:
                return
            moved = min(self.amount, limit - pile.amount)
            pile.amount += moved
            self.amount -= moved
            if self.amount <= 0:
                self.retired = True

    if existing_amount is not None:
        piles.append(Stack(existing_amount, existing_radiation))

    def construct(location, amount, merge=True):
        stack = Stack(amount, 0)
        if merge:
            for pile in location:
                stack.merge(pile)
                if stack.retired:
                    break
        if not stack.retired:
            location.append(stack)
        return stack

    env = dict(stack_amount=base, plant_nutrition=soil, bonus=bonus, radiation=crop_radiation, loc=piles,
               stack_limit_value=limit, min=min, rand=lambda low, high: roll,
               harvest_skill_amount=lambda amount, fraction: amount * (1 + fraction),
               QDELETED=lambda item: item.retired, construct=construct,
               typed_iter=lambda location, path: location, istype=lambda item, path: item.type == path)
    helper_signature = '/obj/structure/farming/plant/proc/spawn_crop_stack'
    if helper_signature in SOURCE:
        helper_body = adapter.extract(SOURCE, helper_signature).replace('new stackpath(', 'construct(')
        env["spawn_crop_stack"] = adapter.project(
            "/proc/crop_stack()\n" + helper_body + "\n", "/proc/crop_stack", "stackpath, target, batch", env.copy())
    if pollinated:
        probe = adapter.extract(POLLINATION, '/obj/structure/farming/plant/proc/spawn_pollinated_extra')
        stack_branch = probe.split('if (stack <> "product_name")', 1)[1].split('\n\telse', 1)[0]
        stack_branch = "\n".join(line[1:] for line in stack_branch.splitlines()[1:])
        stack_branch = stack_branch.replace('text2path("/obj/item/stack/[stack]")', '"material"')
        stack_branch = stack_branch.replace('new stackpath(', 'construct(')
        if 'I = construct(' in stack_branch:
            # The pre-fix pollination assigns radiation after its branches.
            stack_branch += "\n\tif (I && !QDELETED(I))\n\t\tI.radiation = radiation/2"
        env.update(T=piles, max=max)
        adapter.project('/proc/pollinated()\n' + stack_branch + '\n', '/proc/pollinated', '', env)()
    else:
        adapter.project('/proc/harvest()\n' + branch + '\n', '/proc/harvest', '', env)()
    return [pile for pile in piles if not pile.retired]


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
        piles = run_harvest(1, 0, 1, 1, 1, existing_radiation=4)
        self.assertEqual([p.amount for p in piles], [3])
        piles = run_harvest(1, 0, 1, 1, 49, existing_radiation=4)
        self.assertEqual([p.amount for p in piles], [50, 1])

    def test_unmerged_output_keeps_radiation(self):
        piles = run_harvest(1, 0, 1, 1, None)
        self.assertEqual(piles[0].radiation, 4)

    def test_harvest_and_pollination_do_not_merge_different_radiation(self):
        for pollination in (False, True):
            for occupied in (1, 49):
                with self.subTest(pollination=pollination, occupied=occupied):
                    piles = run_harvest(3, 0, 1, 0, occupied, pollinated=pollination)
                    self.assertEqual([(pile.amount, pile.radiation) for pile in piles], [(occupied, 0), (3, 4)])

    def test_clean_output_does_not_hide_in_irradiated_stock(self):
        piles = run_harvest(2, 0, 1, 0, 1, crop_radiation=0, existing_radiation=4)
        self.assertEqual([(pile.amount, pile.radiation) for pile in piles], [(1, 4), (2, 0)])

    def test_pollination_keeps_same_radiation_consolidation(self):
        piles = run_harvest(3, 0, 1, 0, 49, existing_radiation=4, pollinated=True)
        self.assertEqual([(pile.amount, pile.radiation) for pile in piles], [(50, 4), (2, 4)])

    def test_empty_yield_creates_no_stack(self):
        self.assertEqual(run_harvest(0, 0, 1, 1, None), [])

    def test_windows_runner_admits_the_probe(self):
        runner = (ROOT / 'tests/resource_extraction/run.ps1').read_text(encoding='utf-8')
        self.assertIn("'tests/harvest_skills/probe.dm'", runner.split('ValidateSet(', 1)[1].split(')]', 1)[0])


if __name__ == '__main__':
    unittest.main()
