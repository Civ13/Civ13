"""Offline source-backed pulse arithmetic/contracts, NOT native collision/UI QA."""
from pathlib import Path
import re
import unittest
from tile_restore_contract import validate_tile_restore

ROOT = Path(__file__).resolve().parents[2]
MODULE = (ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm').read_text()
MOVE = (ROOT / 'code/game/mob/mob_movement.dm').read_text()
SKIN = (ROOT / 'interface/skin.dmf').read_text()


def normalize_from_source(sx, sy, dx, dy, source=MODULE):
    """Execute the production normalization block (only its integer grammar)."""
    block = source.split('var/tx = actor.x\n', 1)[1].split('var/turf/destination', 1)[0]
    lines = ['tx = 50']
    rows = [line for line in block.splitlines() if line.strip()]
    base = min(len(line) - len(line.lstrip('\t')) for line in rows)
    for line in rows:
        depth = len(line) - len(line.lstrip('\t')) - base
        line = line.strip().replace('var/', '').replace('actor.x', '50').replace('actor.y', '50')
        line = line.replace('actor.step_x', 'initial_sx').replace('actor.step_y', 'initial_sy')
        line = re.sub(r'if \((.*)\)', r'if \1:', line)
        line = line.replace('tx--', 'tx -= 1').replace('tx++', 'tx += 1')
        line = line.replace('ty--', 'ty -= 1').replace('ty++', 'ty += 1')
        lines.append('    ' * depth + line)
    scope = dict(initial_sx=sx, initial_sy=sy, dx=dx, dy=dy)
    exec('\n'.join(lines), {'__builtins__': {}}, scope)
    return tuple(scope[k] for k in ('tx', 'ty', 'sx', 'sy'))


class FineOffsetContracts(unittest.TestCase):
    def test_all_offsets_cardinal_diagonal_wrap_and_reverse(self):
        for sx in range(32):
            for sy in range(32):
                for dx, dy in ((0, 2), (0, -2), (2, 0), (-2, 0), (2, 2), (-2, 2), (2, -2), (-2, -2)):
                    tx, ty, ax, ay = normalize_from_source(sx, sy, dx, dy)
                    self.assertTrue(0 <= ax < 32 and 0 <= ay < 32)
                    self.assertEqual((tx*32+ax, ty*32+ay), (50*32+sx+dx, 50*32+sy+dy))
                    rx, ry, rsx, rsy = normalize_from_source(ax, ay, -dx, -dy)
                    self.assertEqual(((tx+rx-50)*32+rsx, (ty+ry-50)*32+rsy), (50*32+sx, 50*32+sy))

    def test_wrap_negative_control_is_detected(self):
        broken = MODULE.replace('sx += 32', 'sx += 31')
        self.assertNotEqual(normalize_from_source(0, 0, -2, 0, broken), (49, 50, 30, 0))

    def test_one_pulse_not_tile_alignment_and_native_authority(self):
        self.assertIn('remaining_x = (direction & (EAST | WEST)) ? 2 : 0', MODULE)
        self.assertIn('remaining_y = (direction & (NORTH | SOUTH)) ? 2 : 0', MODULE)
        self.assertIn('if (!remaining_x && !remaining_y)\n\t\t\tbreak', MODULE)
        self.assertIn('actor.Move(destination, direction)', MODULE)
        self.assertIn('actual_x != dx || actual_y != dy', MODULE)
        self.assertIn('if (fine_step && !actor.human_subtile_fine_ready(direction))', MODULE)
        self.assertIn('!pulling && !driver && !confused', MODULE)
        self.assertIn('else if (!fine_step)\n\t\t\t\t\t. = mob.SelfMove(n, direct)', MOVE)
        validate_tile_restore(MODULE)

    def test_costs_cooldown_and_no_stomp_acceleration(self):
        self.assertIn('var/distance_fraction = (fine_step == FINE_STEP_NUDGE) ? (2 / 32) : 1', MOVE)
        for cost in ('0.005', '0.002', '0.004', '0.0015'):
            for resource in ('nutrition', 'water'):
                self.assertIn(f'H.{resource} -= {cost} * distance_fraction', MOVE)
        self.assertIn('H.stats["stamina"][1] -= 2 * distance_fraction', MOVE)
        self.assertIn('\t\t\t\t\t\telse\n\t\t\t\t\t\t\tH.stats["stamina"][1] -= distance_fraction', MOVE)
        self.assertIn('max(world.tick_lag, (subtile_deadline - world.time) * distance_fraction)', MOVE)
        self.assertIn('if (fine_step != FINE_STEP_NUDGE)\n\t\t\t\t\tmob.velocity = min(mob.velocity+1, 15)', MOVE)
        self.assertIn('if ((fine_step != FINE_STEP_NUDGE) && t1', MOVE)
        for duration in (.1, 1, 4, 16, 100):
            for tick in (.1, .5, 1):
                self.assertGreaterEqual(16 * max(tick, duration / 16), duration)

    def test_chords_press_nudge_and_release_stop(self):
        for name, expected in (('macro', 8), ('hotkeymode', 12)):
            section = SKIN.split(f'macro "{name}"', 1)[1]
            section = re.split(r'\n(?:macro|menu|window) ', section, 1)[0]
            starts = re.findall(r'name = "ALT\+(\w+)"\n\t\tcommand = "\.fine-offset-start (\d+)"', section)
            stops = re.findall(r'name = "ALT\+(\w+)\+UP"\n\t\tcommand = "\.fine-offset-stop (\d+)"', section)
            self.assertEqual(len(starts), expected)
            self.assertEqual(sorted(starts), sorted(stops))
            # Key repeat no longer drives precision movement; held keys do.
            self.assertNotIn('fine-offset-step', section)
        menu = SKIN.split('menu "menu"', 1)[1].split('window ', 1)[0]
        self.assertNotIn('fine-offset', menu)
        self.assertIn('name = "ALT+L"\n\t\tcommand = "looc"', SKIN)
        command = MOVE.split('/client/verb/fine_offset_start', 1)[1].split('/client/verb/', 1)[0]
        self.assertIn('mob.movement_fine = TRUE', command)
        self.assertIn('FINE_STEP_NUDGE)', command)
        self.assertNotIn('spawn', command)
        self.assertNotIn('sleep', command)
        self.assertNotRegex(MODULE + MOVE, r'var/[^\n]*alt_held')

    def test_precision_release_preserves_control_stop_lifecycle(self):
        start = MOVE.split('/client/verb/fine_offset_start', 1)[1].split('/client/verb/', 1)[0]
        release_calls = re.findall(r'^\t\t(stopmoving(?:up|down|right|left))\(\)$', start, re.M)
        self.assertEqual(release_calls, ['stopmovingup', 'stopmovingdown', 'stopmovingright', 'stopmovingleft'])
        self.assertLess(start.index('stopmovingleft()'), start.index('return Move('))
        stop = MOVE.split('/client/verb/fine_offset_stop', 1)[1]
        for name in ('stopmovingup()', 'stopmovingdown()', 'stopmovingright()', 'stopmovingleft()'):
            self.assertIn(name, stop)
        self.assertIn('mob.movement_fine = FALSE', stop)
        for name, axis, direction in (
            ('stopmovingup', 'northsouth', 'NORTH'),
            ('stopmovingdown', 'northsouth', 'SOUTH'),
            ('stopmovingright', 'eastwest', 'EAST'),
            ('stopmovingleft', 'eastwest', 'WEST'),
        ):
            release = MOVE.split(f'/client/verb/{name}()', 1)[1].split('/client/verb/', 1)[0]
            self.assertIn(f'if (mob && mob.movement_{axis} == {direction})', release)
            self.assertIn('RC.stop_move_drone()', release)
            if axis == 'eastwest':
                self.assertIn('C.stop_rotation()', release)
        # Ordinary direction keys and logout leave precision mode.
        for name in ('startmovingup', 'startmovingdown', 'startmovingright', 'startmovingleft'):
            body = MOVE.split(f'/client/verb/{name}()', 1)[1].split('/client/verb/', 1)[0]
            self.assertIn('mob.movement_fine = FALSE', body)
        self.assertIn('movement_fine = FALSE\n\t..()', MOVE.split('/mob/Logout()', 1)[1])

    def test_held_slide_runs_at_the_ordinary_pace_and_stops_on_release(self):
        machine = (ROOT / 'code/movementMachine.dm').read_text()
        self.assertIn('M.client.Move(get_step(M, movedir), movedir, diag, M.held_fine_step())', machine)
        self.assertIn('(!M.movement_fine || world.time >= M.client.fine_offset_glide_at)', machine)
        self.assertIn('return ishuman(src) ? FINE_STEP_FREE : FALSE', MOVE)
        # A held slide covers a whole tile's distance in 16 pulses on the
        # ordinary interval, exactly like walking, and is not tick-floored.
        self.assertIn('remaining_x = (direction & (EAST | WEST)) ? 32 : 0', MODULE)
        self.assertIn('remaining_y = (direction & (NORTH | SOUTH)) ? 32 : 0', MODULE)
        self.assertIn('. = H.SelfMove(n, direct, subtile_deadline, FINE_STEP_HELD)', MOVE)
        self.assertIn("fine_step != FINE_STEP_NUDGE && isnum(human_subtile_chain_start)", MODULE)
        self.assertIn('(fine_step == FINE_STEP_NUDGE) ? 2 : 32', MODULE)
        # Release is seen before the next pulse and refunds the unused interval.
        self.assertIn('if (fine_step == FINE_STEP_HELD && actor.held_movement_direction() != direction)', MODULE)
        self.assertIn('actor.human_subtile_fine_released_at = world.time', MODULE)
        self.assertIn('if (H.human_subtile_fine_released_at == world.time)\n\t\t\t\t\t\t\t\tsubtile_deadline = world.time', MOVE)
        # Speed model at TICKLAG 0.4 with an unloaded walk (2.85 ds per tile):
        # the old repeat-driven nudges were floored to one 2px pulse per tick.
        tick, walk = 0.4, 1.9 * 1.5
        old_px_per_ds = 2 / max(tick, walk * 2 / 32)
        new_px_per_ds = 32 / walk
        self.assertLess(old_px_per_ds, 5.1)
        self.assertGreater(new_px_per_ds, 2 * old_px_per_ds)

    def test_partial_step_from_an_offset_costs_its_share(self):
        self.assertIn('var/remaining_fraction = H.human_subtile_remaining_fraction(direct)', MOVE)
        self.assertIn('(subtile_deadline - world.time) * remaining_fraction', MOVE)
        body = MODULE.split('/mob/living/human/proc/human_subtile_remaining_fraction(direction)', 1)[1].split('\n/', 1)[0]
        self.assertIn('return max(remaining_x, remaining_y) / 32', body)
        self.assertIn('var/due = start_time + (i - 1) * duration / pulse_count', MODULE)

    def test_plain_keys_slide_freely_with_tile_fallback(self):
        for d in ('NORTH', 'SOUTH', 'EAST', 'WEST'):
            self.assertIn(f'Move(get_step(mob, {d}), {d}, FALSE, mob.held_fine_step())', MOVE)
        body = MOVE.split('/client/Move(', 1)[1].split('if (ishuman(mob))\n\t\tvar/mob/living/human/subtile_input_actor', 1)[0]
        self.assertIn('if (fine_step == FINE_STEP_FREE)\n\t\tfine_step = FALSE', body)
        self.assertIn('human_subtile_fine_ready(direct) && !free_actor.human_subtile_trench_near(direct)', body)
        self.assertIn('fine_step = FINE_STEP_HELD', body)

    def test_blocked_slides_slip_round_corners_and_along_walls(self):
        self.assertIn('attempts += actor.human_subtile_slide_attempts(direction)', MODULE)
        body = MODULE.split('/mob/living/human/proc/human_subtile_slide_attempts(direction)', 1)[1].split('\n/', 1)[0]
        self.assertIn('. += list(list((direction & EAST) ? 2 : -2, 0))', body)
        self.assertIn('. += list(list(0, (direction & NORTH) ? 2 : -2))', body)
        self.assertIn('if (open_near && !open_far)', body)
        self.assertIn('if (offset <= 12)', body)
        # Native collision still judges every attempt, and a sideways slide
        # never counts as travel along the step.
        self.assertIn('if (direction & (EAST | WEST))\n\t\t\t\t\tremaining_x -= abs(actual_x)', MODULE)
        probe = (ROOT / 'tests/human_subtile/probe.dm').read_text()
        for label in ('corner_slide_into_opening', 'diagonal_wall_slide'):
            self.assertIn(label, probe)

    def test_owned_position_save_and_completion_are_reused(self):
        self.assertIn('human_subtile_offset_owned = TRUE', MODULE)
        self.assertIn('human_subtile_position = human_subtile_snapshot()', MODULE)
        self.assertIn('human_subtile_same(S, human_subtile_snapshot())', MODULE)
        self.assertIn('actor.living_movement_completed()', MODULE)
        self.assertIn('actor.human_movement_completed()', MODULE)
        self.assertIn('should_save = FALSE\n\tvar/mob/living/human/actor', MODULE)


if __name__ == '__main__':
    unittest.main(verbosity=2)
