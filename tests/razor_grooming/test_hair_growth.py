"""Source checks for hair and beard regrowth pace; no native world."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
LIFE = ROOT / 'code/game/mob/living/carbon/human/human_life.dm'
TRAVEL = ROOT / 'code/modules/persistence/region_travel.dm'
MOB_PROCESS = ROOT / 'code/processes/mob.dm'


def define(source, name):
    match = re.search(r'#define %s \(?([\d.]+)' % name, source)
    return float(match.group(1))


class HairGrowthPace(unittest.TestCase):
    def setUp(self):
        self.source = LIFE.read_text(encoding='utf-8-sig')
        start = self.source.index('/mob/living/human/proc/handle_hair_growth()')
        self.body = self.source[start:self.source.index('/mob/living/human/proc/handle_some_updates()')]

    def test_growth_follows_elapsed_time_not_ticks(self):
        # A flat per-tick increment regrew a shaved beard in minutes.
        self.assertNotRegex(self.body, r'_growth \+= [\d.]+')
        self.assertIn('world.time - last_hair_growth_time', self.body)
        self.assertIn('HAIR_GROWTH_MAX_GAP', self.body)

    def test_a_shaved_face_takes_hours_to_grow_stubble_back(self):
        facial = define(self.source, 'FACIAL_HAIR_HOURS_PER_STEP')
        head = define(self.source, 'HEAD_HAIR_HOURS_PER_STEP')
        self.assertGreaterEqual(facial, 2)
        self.assertGreaterEqual(head, 2)
        # One step is hours * 36000 deciseconds of world time.
        self.assertIn('hours * 36000', self.source)

    def test_gap_cap_stays_small(self):
        self.assertIn('#define HAIR_GROWTH_MAX_GAP (10 SECONDS)', self.source)

    def test_last_growth_time_is_not_saved(self):
        self.assertIn('/mob/living/human/var/tmp/last_hair_growth_time', self.source)


class HairGrowthTravels(unittest.TestCase):
    def test_growth_crosses_regions_with_the_style(self):
        # Without it a shaved traveller kept the old body's long-beard growth
        # and snapped back to a beard at the next step.
        line = next(l for l in TRAVEL.read_text(encoding='utf-8-sig').splitlines()
                    if l.startswith('var/global/list/region_travel_look_vars'))
        for name in ('"h_growth"', '"f_growth"', '"h_style"', '"f_style"'):
            self.assertIn(name, line)


if __name__ == '__main__':
    unittest.main()
