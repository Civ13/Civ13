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
MOVEMENT = ROOT / 'code/game/mob/mob_movement.dm'


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

    def test_drag_targets_the_tile_the_step_vacated(self):
        # West/south steps change loc on the first pulse, so loc is the
        # destination by the aligned pulse; the drag must aim behind it.
        body = living_move()
        target = body.index('T = get_step(pull_pulse.destination, turn(pull_pulse.direction, 180))')
        self.assertLess(body.index('var/turf/T = loc'), target)
        self.assertLess(target, body.index('moved = ..()'))

    def test_next_input_keeps_a_touching_pull_after_an_interrupted_step(self):
        source = MOVEMENT.read_text(encoding='utf-8')
        touching = source.index('var/pull_touching = (mob.step_x || mob.step_y) && isturf(mob.pulling.loc) && mob.pulling.z == mob.z && bounds_dist(mob, mob.pulling) < 32')
        drop = source.index('if (!mob.pulling.Adjacent(mob) && !pull_touching)')
        self.assertLess(touching, drop)
        self.assertNotIn('if (!mob.pulling.Adjacent(mob))\n', source)

    def test_downed_body_with_owned_offset_can_be_dragged(self):
        source = MOVEMENT.read_text(encoding='utf-8')
        move = source[source.index('/atom/movable/Move(newloc, direct)'):]
        refuse = move.index('else if (subtile_actor.human_subtile_offset_owned && (step_x || step_y))')
        branch = move[refuse:move.index('if (!subtile_pulse && (direct & (direct - 1)))')]
        self.assertIn('if (subtile_actor.client && !subtile_actor.stat && !subtile_actor.lying && !subtile_actor.pulledby)\n\t\t\t\treturn FALSE', branch)
        self.assertIn('subtile_realign = TRUE', branch)
        self.assertIn('if (subtile_realign && subtile_actor && !isDeleted(subtile_actor) && !step_x && !step_y)\n\t\tsubtile_actor.human_subtile_offset_owned = FALSE', move)

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
