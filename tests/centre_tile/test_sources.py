"""A free-moving human is filed under the tile beneath its centre.

BYOND files a pixel-moving atom under the tile holding its bounding box's
lower-left corner, so walking east or north kept the old tile for the whole
32px and walking west or south switched after 2px. After each native move the
body is filed again under its centre tile. The native probe (probe.dm, run.py)
checks the behaviour in a real build; these checks keep the seams in place.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SUBTILE = (ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm').read_text(encoding='utf-8')
MOVE = (ROOT / 'code/game/mob/mob_movement.dm').read_text(encoding='utf-8')
RIDING = (ROOT / 'code/game/mob/living/simple_animal/riding.dm').read_text(encoding='utf-8')
LIVING = (ROOT / 'code/game/mob/living/living.dm').read_text(encoding='utf-8')
TRENCH = (ROOT / 'code/modules/1713/trench.dm').read_text(encoding='utf-8')
PROBE = (ROOT / 'tests/centre_tile/probe.dm').read_text(encoding='utf-8')


def proc(text, name):
    start = text.index(name)
    end = re.search(r'\n(?=/|#define|\Z)', text[start + 1:])
    return text[start:start + 1 + end.start()] if end else text[start:]


class CentreTileSources(unittest.TestCase):
    def test_anchor_files_under_centre_tile(self):
        body = proc(SUBTILE, '/mob/living/human/proc/human_subtile_anchor()')
        self.assertIn('round((px + 16) / 32)', body)
        self.assertIn('round((py + 16) / 32)', body)
        # A silent re-file: loc assignment, never a Move or forceMove.
        self.assertIn('loc = T', body)
        self.assertNotIn('Move(', body)

    def test_shape_accepts_centre_offsets(self):
        body = proc(SUBTILE, '/mob/living/human/proc/human_subtile_shape()')
        self.assertIn('step_x >= -16', body)
        self.assertIn('step_y >= -16', body)

    def test_every_native_human_move_refiles(self):
        body = proc(MOVE, '/atom/movable/Move(newloc, direct)')
        pulse = body.index('. = ..(newloc, direct, subtile_pulse.sx, subtile_pulse.sy)')
        self.assertLess(pulse, body.index('subtile_actor.human_subtile_anchor()', pulse))
        self.assertIn('if (!subtile_pulse.restoring)', body)
        self.assertEqual(body.count('human_subtile_anchor()'), 2)

    def test_alignment_maths_uses_lower_left_form(self):
        for name in ('/mob/living/human/proc/human_subtile_remaining_fraction(direction)',
                     '/mob/living/human/proc/human_subtile_slide_attempts(direction)',
                     '/mob/living/human/proc/human_subtile_pulse_climbs(dx, dy)',
                     '/mob/living/human/proc/human_subtile_climb_target(direction)',
                     '/mob/living/human/proc/human_subtile_trench_climb(direction)'):
            self.assertIn('human_subtile_ll()', proc(SUBTILE, name), name)
        perform = proc(SUBTILE, '/datum/human_subtile_transaction/proc/perform(direction)')
        self.assertIn('actor.human_subtile_ll()', perform)
        self.assertNotIn('32 - actor.step_x', perform)
        # Grace walls check the tiles a pulse newly overlaps, not get_step(loc).
        self.assertIn('map.check_caribbean_block(actor, front)', perform)
        self.assertNotIn('get_step(actor, front_direction)', perform)

    def test_mounts_and_swapped_mobs_keep_lower_left_filing(self):
        mount = proc(RIDING, '/mob/living/human/proc/human_subtile_mount_follow()')
        self.assertIn('human_subtile_ll()', mount)
        swap = proc(LIVING, '/proc/swap_exact_offset_owner(var/mob/living/M)')
        self.assertIn('H.human_subtile_anchor()', swap)
        self.assertIn('subtile_refile_lower_left(M)', swap)

    def test_trench_climb_lands_when_already_filed_on_destination(self):
        body = proc(TRENCH, '/proc/trench_climb_place_offset(')
        self.assertIn('H.loc != destination && !H.forceMove(destination)', body)
        self.assertIn('H.human_subtile_anchor()', body)

    def test_native_probe_walks_every_direction(self):
        for direction in ('EAST', 'WEST', 'NORTH', 'SOUTH'):
            self.assertIn(f'centre_tile_probe_walk(', PROBE)
            self.assertRegex(PROBE, rf'centre_tile_probe_walk\(\d+, \d+, {direction}, ')
        self.assertIn('refiling_fires_no_extra_enter', PROBE)


if __name__ == '__main__':
    unittest.main()
