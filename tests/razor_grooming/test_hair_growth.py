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


class HairTieIntegration(unittest.TestCase):
    def test_dusty_actions_use_the_same_adjusted_timer_as_the_animation(self):
        calls = (
            ('code/game/turfs/floor_attackby.dm', 'duration', 'wall', 'actor'),
            ('code/modules/1713/mountain_seams.dm', 'time', 'T', 'H'),
            ('code/modules/provinces/province_rich.dm', 'time', 'T', 'H'),
        )
        for path, timer, target, actor in calls:
            with self.subTest(path=path):
                source = (ROOT / path).read_text(encoding='utf-8-sig')
                start = source.index(f'var/{timer} = {actor}.hair_dusty_work_delay')
                action = source[start:].split('\n\n', 1)[0]
                self.assertRegex(action, rf'prepare_resource_work_animation\([^\n]+, {target}, {timer}\)')
                self.assertIn(f'do_after({actor}, {timer}, {target}', action)
        ice = (ROOT / 'code/modules/1713/ice_breaking.dm').read_text()
        self.assertNotIn('hair_dusty_work_delay', ice)

    def test_changing_only_the_beard_does_not_untie_scalp_hair(self):
        src = (ROOT / 'code/game/objects/items/weapons/material/kitchen.dm').read_text()
        cut = src[src.index('if (new_hstyle != old_hstyle)\n'):]
        cut = cut[:cut.index('M.update_hair()')]
        self.assertRegex(cut, r'if \(new_hstyle != old_hstyle\)\n(?:\t{2}[^\n]+\n)*?\t{2}M.hair_tied_back = FALSE')
        self.assertNotIn('hair_tied_back', cut.split('if (new_fstyle != old_fstyle)', 1)[1])


if __name__ == '__main__':
    unittest.main()
