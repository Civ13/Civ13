"""Offline source-backed pulse arithmetic/contracts, NOT native collision/UI QA."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE = (ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm').read_text()
MOVE = (ROOT / 'code/game/mob/mob_movement.dm').read_text()
SKIN = (ROOT / 'interface/skin.dmf').read_text()


def normalize_from_source(sx, sy, dx, dy, source=MODULE):
    """Execute the production normalization block (only its integer grammar)."""
    block = source.split('\t\tvar/tx = actor.x\n', 1)[1].split('\t\tvar/turf/destination', 1)[0]
    lines = ['tx = 50']
    for line in block.splitlines():
        line = line[2:].replace('var/', '').replace('actor.x', '50').replace('actor.y', '50')
        line = line.replace('actor.step_x', 'initial_sx').replace('actor.step_y', 'initial_sy')
        line = re.sub(r'if \((.*)\)', r'if \1:', line)
        line = line.replace('tx--', 'tx -= 1').replace('tx++', 'tx += 1')
        line = line.replace('ty--', 'ty -= 1').replace('ty++', 'ty += 1')
        lines.append(line)
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
        self.assertNotRegex(MODULE, r'\b(?:step_x|step_y|pixel_x|pixel_y|loc)\s*=(?!=)')

    def test_costs_cooldown_and_no_stomp_acceleration(self):
        self.assertIn('var/distance_fraction = fine_step ? (2 / 32) : 1', MOVE)
        for cost in ('0.005', '0.002', '0.004', '0.0015'):
            for resource in ('nutrition', 'water'):
                self.assertIn(f'H.{resource} -= {cost} * distance_fraction', MOVE)
        self.assertIn('H.stats["stamina"][1] -= 2 * distance_fraction', MOVE)
        self.assertIn('H.stats["stamina"][1] -= distance_fraction', MOVE)
        self.assertIn('max(world.tick_lag, (subtile_deadline - world.time) * distance_fraction)', MOVE)
        self.assertIn('if (!fine_step)\n\t\t\t\t\tmob.velocity = min(mob.velocity+1, 15)', MOVE)
        self.assertIn('if ((!fine_step) && t1', MOVE)
        for duration in (.1, 1, 4, 16, 100):
            for tick in (.1, .5, 1):
                self.assertGreaterEqual(16 * max(tick, duration / 16), duration)

    def test_chords_live_in_macro_sets_not_menu_and_have_no_latch(self):
        for name, expected in (('macro', 8), ('hotkeymode', 12)):
            section = SKIN.split(f'macro "{name}"', 1)[1]
            section = re.split(r'\n(?:macro|menu|window) ', section, 1)[0]
            self.assertEqual(section.count('command = ".fine-offset-step '), expected)
        menu = SKIN.split('menu "menu"', 1)[1].split('window ', 1)[0]
        self.assertNotIn('fine-offset-step', menu)
        self.assertIn('name = "ALT+L"\n\t\tcommand = "looc"', SKIN)
        command = MOVE.split('/client/verb/fine_offset_step', 1)[1]
        for release in ('stopmovingup()', 'stopmovingdown()', 'stopmovingright()', 'stopmovingleft()'):
            self.assertIn(release, command)
        self.assertNotIn('mob.movement_northsouth = null', command)
        self.assertNotIn('mob.movement_eastwest = null', command)
        self.assertNotIn('spawn', command)
        self.assertNotIn('sleep', command)
        self.assertNotRegex(MODULE + MOVE, r'var/[^\n]*alt_held')

    def test_precision_release_preserves_control_stop_lifecycle(self):
        command = MOVE.split('/client/verb/fine_offset_step', 1)[1]
        release_calls = re.findall(r'^\t(stopmoving(?:up|down|right|left))\(\)$', command, re.M)
        self.assertEqual(release_calls, ['stopmovingup', 'stopmovingdown', 'stopmovingright', 'stopmovingleft'])
        self.assertLess(command.index('stopmovingleft()'), command.index('return Move('))
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

    def test_owned_position_save_and_completion_are_reused(self):
        self.assertIn('human_subtile_offset_owned = TRUE', MODULE)
        self.assertIn('human_subtile_position = human_subtile_snapshot()', MODULE)
        self.assertIn('human_subtile_same(S, human_subtile_snapshot())', MODULE)
        self.assertIn('actor.living_movement_completed()', MODULE)
        self.assertIn('actor.human_movement_completed()', MODULE)
        self.assertIn('should_save = FALSE\n\tvar/mob/living/human/actor', MODULE)


if __name__ == '__main__':
    unittest.main(verbosity=2)
