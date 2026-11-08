"""Legacy pull-follow during smooth (2px) steps.

Moving west or south, the walker's loc changes on the first 2px pulse while its
body still covers the old tile. The pulled object is then two tiles away by loc
and, before this fix, the next pulse dropped the pull (or slid the object 2px
into the walker). The follow must keep the pull while the bodies still touch and
drag only once the step lands on a tile.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
LIVING = ROOT / 'code/game/mob/living/living.dm'


def living_move():
    source = LIVING.read_text(encoding='utf-8')
    start = source.index('/mob/living/Move(a, b, flag)')
    return source[start:source.index('/mob/living/proc/living_movement_completed()')]


class LegacyPullFollowContracts(unittest.TestCase):
    def test_pull_is_kept_while_a_smooth_step_still_touches_the_object(self):
        body = living_move()
        self.assertIn('subtile_pull_step = !!pull_walker.human_subtile_pulse', body)
        keep = body[body.index('if ((t7 && (pulling'):]
        keep = keep[:keep.index('\n')]
        self.assertIn('get_dist(src, pulling) <= 1', keep)
        self.assertIn('subtile_pull_step && isturf(pulling.loc) && bounds_dist(src, pulling) < 32', keep)

    def test_drag_waits_until_the_step_is_aligned(self):
        body = living_move()
        moved = body.index('moved = ..()')
        guard = body.index('if (subtile_pull_step && (step_x || step_y))')
        drag = body.index('step(pulling, get_dir(pulling.loc, T))')
        self.assertLess(moved, guard)
        self.assertLess(guard, drag)
        self.assertEqual(body[guard:].split('\n')[1].strip(), 'return moved')

    def test_pixel_oracle_follows_in_every_direction(self):
        # Independent world-pixel model of 16 2px pulses with the follower
        # directly behind; checks the touching rule and the aligned drag.
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            wx, wy = 0, 0
            fx, fy = -dx * 32, -dy * 32
            for _ in range(16):
                # The keep check runs before each pulse moves the walker.
                gap = max(abs(wx - fx), abs(wy - fy)) - 32
                self.assertLess(gap, 32)
                wx += dx * 2
                wy += dy * 2
                aligned = wx % 32 == 0 and wy % 32 == 0
                if aligned:
                    fx, fy = wx - dx * 32, wy - dy * 32
                else:
                    self.assertEqual((fx, fy), (-dx * 32, -dy * 32))
            self.assertEqual((fx, fy), (0, 0))


if __name__ == '__main__':
    unittest.main()
