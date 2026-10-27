"""Offline pair-ownership contracts and source-derived displacement arithmetic.

No native movement, fake clients or Python simulation of DM authority is used.
"""
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE = ROOT / 'code/game/mob/living/carbon/human/pull_pair_ownership.dm'
BASE = '10d264e5896221b34949ee4b67c0fd2b94bde249'
DIRS = dict(NORTH=1, SOUTH=2, EAST=4, WEST=8)


def source():
    return MODULE.read_text(encoding='utf-8')


def block(start, end):
    text = source()
    return text[text.index(start):text.index(end, text.index(start))]


def projected_shift():
    """Translate only the actual known shift body; unknown syntax fails closed."""
    text = block('/proc/subtile_pull_shift', '/datum/subtile_pull_pair\n')
    body = text[text.index('\tvar/list/after'):].rstrip()
    exact = {
        'var/list/after = before.Copy()': 'after = before.copy()',
        'after["sx"] += (direction == EAST) ? amount : (direction == WEST) ? -amount : 0':
            'after["sx"] += amount if direction == EAST else -amount if direction == WEST else 0',
        'after["sy"] += (direction == NORTH) ? amount : (direction == SOUTH) ? -amount : 0':
            'after["sy"] += amount if direction == NORTH else -amount if direction == SOUTH else 0',
        'return after': 'return after',
    }
    lines = ['def shift(before, direction, amount):']
    for line in body.splitlines():
        indent = len(line) - len(line.lstrip('\t'))
        value = line.strip()
        if value in exact:
            value = exact[value]
        elif re.fullmatch(r'if \(after\["s[xy]"\] (?:< 0|>= 32)\)', value):
            value = 'if ' + value[4:-1] + ':'
        elif re.fullmatch(r'after\["[xy]"\](?:\+\+|--)', value):
            value = value[:-2] + (' += 1' if value.endswith('++') else ' -= 1')
        elif re.fullmatch(r'after\["s[xy]"\] [+-]= 32', value):
            pass
        else:
            raise ValueError('Unprojected shift statement: ' + value)
        lines.append('    ' * indent + value)
    namespace = dict(DIRS)
    exec(compile('\n'.join(lines), '<actual-DM-shift-projection>', 'exec'), {'__builtins__': {}, **DIRS}, namespace)
    return namespace['shift']


class PullOwnershipContracts(unittest.TestCase):
    def test_arithmetic_matches_independent_world_coordinate_oracle(self):
        shift = projected_shift()
        for sx in range(32):
            for sy in range(32):
                for direction in DIRS.values():
                    for amount in (1, 2):
                        before = dict(x=5, y=7, z=1, sx=sx, sy=sy)
                        after = shift(before, direction, amount)
                        dx = amount if direction == 4 else -amount if direction == 8 else 0
                        dy = amount if direction == 1 else -amount if direction == 2 else 0
                        tx, ox = divmod(5 * 32 + sx + dx, 32)
                        ty, oy = divmod(7 * 32 + sy + dy, 32)
                        self.assertEqual(after, dict(x=tx, y=ty, z=1, sx=ox, sy=oy))
                        self.assertEqual(before, dict(x=5, y=7, z=1, sx=sx, sy=sy))

    def test_straight_paired_paths_keep_separation_and_reach_exactly_one_tile(self):
        shift = projected_shift()
        for direction in DIRS.values():
            dx = 1 if direction == 4 else -1 if direction == 8 else 0
            dy = 1 if direction == 1 else -1 if direction == 2 else 0
            leader = dict(x=6, y=6, z=1, sx=0, sy=0)
            follower = dict(x=6-dx, y=6-dy, z=1, sx=0, sy=0)
            for ordinal in range(16):
                leader = shift(leader, direction, 2)
                # Leader-first native ordering permits only a2px transient gap.
                self.assertEqual((leader['x']*32+leader['sx'])-(follower['x']*32+follower['sx']), (32+2)*dx)
                self.assertEqual((leader['y']*32+leader['sy'])-(follower['y']*32+follower['sy']), (32+2)*dy)
                follower = shift(follower, direction, 2)
            self.assertEqual((leader['x'],leader['y'],leader['sx'],leader['sy']), (6+dx,6+dy,0,0))
            self.assertEqual((follower['x'],follower['y'],follower['sx'],follower['sy']), (6,6,0,0))

    def test_no_producer_or_native_collision_path_is_wired(self):
        for path in ('code/game/mob/mob_movement.dm', 'code/game/mob/living/living.dm',
                     'code/game/mob/living/carbon/human/subtile_movement.dm',
                     'code/_onclick/click.dm', 'code/pathfinding.dm', 'code/_helpers/mobs.dm'):
            old = subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT).decode().replace('\r\n','\n')
            self.assertEqual((ROOT/path).read_text(encoding='utf-8'), old, path)
        text = source()
        for forbidden in ('.Move(', 'forceMove(', 'pixel_x =', 'pixel_y =',
                          'living_movement_completed(', 'human_movement_completed(', 'sleep(', 'spawn(',
                          'get_path(', 'cirrAstar(', 'rand(', 'prob('):
            self.assertNotIn(forbidden, text)
        self.assertNotRegex(text, r'(?<![A-Za-z_])step\(')

    def test_real_controller_and_reciprocal_ownership_are_revalidated(self):
        text = source()
        for guard in ('leader.client == controller', 'controller.mob == leader',
                      'controller.canmove && controller.moving', 'leader.pulling == follower',
                      'follower.pulledby == leader', 'registry.owners[leader] == src',
                      'registry.owners[follower] == src', '!persistence_save_in_progress'):
            self.assertIn(guard, text)
        self.assertNotIn('new /client', text)
        self.assertNotRegex(text, r'\bclient\s*=(?!=)')

    def test_atomic_reservation_has_bounded_registry_and_no_wait(self):
        text = block('/datum/subtile_pull_ownership/proc/claim', '/proc/subtile_pull_snapshot')
        self.assertIn('owners[leader] || owners[follower] || owners.len > 126', text)
        self.assertLess(text.index('P.prepare('), text.index('owners[leader] = P'))
        self.assertLess(text.index('owners[follower] = P'), text.index('P.claimed = TRUE'))
        self.assertNotIn('sleep(', text)
        self.assertNotIn('spawn(', text)

    def test_first_profile_refuses_unsafe_geometry_and_special_targets(self):
        text = source()
        for guard in ('subtile_pull_shape(L, TRUE)', 'subtile_pull_shape(F, TRUE)',
                      'get_step(L, turn(direct, 180)) != F.loc',
                      'follower.anchored || follower.throwing || follower.contents.len',
                      '/obj/item/vehicleparts', '/obj/item/football',
                      '/obj/item/weapon/gun/projectile/automatic/stationary',
                      '!(direct in list(NORTH, SOUTH, EAST, WEST))'):
            self.assertIn(guard, text)
        self.assertIn('leader.can_pull_size >= follower.w_class', text)
        self.assertIn('end_time >= world.time + world.tick_lag && end_time <= world.time + 100', text)

    def test_capabilities_bind_member_position_destination_direction_and_clock(self):
        text = source()[source().index('/datum/subtile_pull_capability/proc/consume'):]
        for guard in ('!armed', 'pair.issued != src', 'member != actor', 'direct != direction',
                      'ordinal != pair.ordinal', '!pair.valid()',
                      'human_subtile_same(before, subtile_pull_snapshot(actor))',
                      'destination != locate(after["x"], after["y"], after["z"])',
                      'sx != after["sx"] || sy != after["sy"]', 'armed = FALSE'):
            self.assertIn(guard, text)
        self.assertIn('(ordinal - 1) * (pair.deadline - pair.start_time) / 16', text)

    def test_member_phase_requires_observed_leader_before_follower(self):
        issue = block('/datum/subtile_pull_pair/proc/issue', '/datum/subtile_pull_pair/proc/observe')
        self.assertIn('!valid() || issued || distance >= 32', issue)
        self.assertIn('phase == "idle" && member == leader', issue)
        self.assertIn('phase == "leader_observed" && member == follower', issue)
        self.assertIn('ordinal >= 16', issue)
        observe = block('/datum/subtile_pull_pair/proc/observe', '/datum/subtile_pull_pair/proc/cancel')
        self.assertIn('P.armed || P.pair != src || !authority_valid()', observe)
        self.assertIn('human_subtile_same(follower_expected, actual_follower)', observe)
        self.assertIn('human_subtile_same(leader_expected, actual_leader)', observe)
        self.assertEqual(observe.count('distance += 2'), 1)
        self.assertIn('cancel("participant_position_changed")', observe)

    def test_cancel_revokes_issued_capability_and_release_cannot_drop_offsets(self):
        text = block('/datum/subtile_pull_pair/proc/cancel', '/datum/subtile_pull_capability\n')
        self.assertIn('issued.armed = FALSE', text)
        self.assertIn('issued.pair = null', text)
        self.assertIn('recovery_required = TRUE', text)
        self.assertIn('cancel("release_requires_recovery")\n\t\trecovery_required = TRUE', text)
        self.assertLess(text.index('recovery_required = TRUE'), text.index('registry.owners -= leader'))
        self.assertIn('if (registry.owners[leader] == src)', text)
        self.assertIn('if (registry.owners[follower] == src)', text)
        self.assertEqual(source().count('should_save = FALSE'), 3)
        self.assertNotIn('before_save()', source())
        self.assertNotIn('after_load()', source())


if __name__ == '__main__':
    unittest.main(verbosity=2)
