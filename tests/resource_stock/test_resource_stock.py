"""Regrowing sources share /datum/resource_stock (code/_helpers/resource_stock.dm).

Ocean fish kept a lazy (left, since) entry, rock flint queued one sleeping
spawn(18000) per flint taken, and obsidian outcrops kept a count and a refill
time. The stock below is a Python mirror of the DM datum; the tests check the
mirror against the source text and play the old behaviours through it.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / 'code/_helpers/resource_stock.dm'


class Stock:
    """Mirror of /datum/resource_stock."""
    def __init__(self, clock, max_, period, regrow_all=False):
        self.clock, self.max, self.period, self.regrow_all = clock, max_, max(1, period), regrow_all
        self.left, self.since = max_, clock[0]

    def available(self):
        now = self.clock[0]
        if self.left < self.max:
            if self.regrow_all:
                if self.left <= 0 and now >= self.since + self.period:
                    self.left = self.max
            else:
                regained = (now - self.since) // self.period
                if regained > 0:
                    self.left = min(self.max, self.left + regained)
                    self.since += regained * self.period
        if self.left >= self.max and not self.regrow_all:
            self.since = now
        return self.left

    def take(self, n=1):
        if self.available() < n:
            return False
        was_full = self.left >= self.max
        self.left -= n
        if (self.left <= 0) if self.regrow_all else was_full:
            self.since = self.clock[0]
        return True


class ResourceStockTest(unittest.TestCase):
    def test_mirror_matches_the_source(self):
        text = HELPER.read_text(encoding='utf-8')
        for line in ('var/regained = round((world.time - since) / period)',
                     'left = min(max, left + regained)', 'since += regained * period',
                     'if (left <= 0 && world.time >= since + period)',
                     'since = world.time // a full stretch does not bank regrowth',
                     'if (available() < n)', 'if (regrow_all ? left <= 0 : was_full)'):
            self.assertIn(line, text)

    def test_one_at_a_time_regrowth(self):
        clock = [0]
        fish = Stock(clock, 3, 6000)
        self.assertTrue(fish.take() and fish.take() and fish.take())
        self.assertFalse(fish.take())
        clock[0] = 5999
        self.assertEqual(fish.available(), 0)
        clock[0] = 6000
        self.assertEqual(fish.available(), 1)
        clock[0] = 6000 * 10
        self.assertEqual(fish.available(), 3)
        # Time spent full is not banked.
        clock[0] += 100000
        fish.take()
        clock[0] += 5999
        self.assertEqual(fish.available(), 2)

    def test_refill_all_after_running_out(self):
        clock = [0]
        outcrop = Stock(clock, 3, 18000, regrow_all=True)
        outcrop.take(); outcrop.take()
        clock[0] = 50000
        self.assertEqual(outcrop.available(), 1)  # not empty yet, so no refill
        outcrop.take()
        clock[0] = 50000 + 17999
        self.assertEqual(outcrop.available(), 0)
        clock[0] += 1
        self.assertEqual(outcrop.available(), 3)

    def test_sources_use_the_stock(self):
        read = lambda p: (ROOT / p).read_text(encoding='utf-8')
        rocks = read('code/game/objects/structures/rocks.dm')
        self.assertIn('new /datum/resource_stock(5, 18000)', rocks)
        self.assertIn('rock_flint_stock().take()', rocks)
        self.assertNotIn('spawn(18000)', rocks)
        self.assertIn('var/tmp/datum/resource_stock/flint_stock', rocks)
        obsidian = read('code/modules/1713/obsidian.dm')
        self.assertIn('new /datum/resource_stock(OBSIDIAN_OUTCROP_NODULES, OBSIDIAN_OUTCROP_REGEN, TRUE)', obsidian)
        self.assertIn('!obsidian_stock.take()', obsidian)
        fishing = read('code/game/objects/structures/ocean_fishing.dm')
        self.assertIn('new /datum/resource_stock(OCEAN_FISH_MAX, OCEAN_FISH_REGEN)', fishing)


if __name__ == '__main__':
    unittest.main()
