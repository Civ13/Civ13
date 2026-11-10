"""Execute the table climb's movement tail with isolated turf adapters.

The projection uses the checked-in DM statements, but does not run BYOND,
do_after, collision checks, or real gameplay.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/structures/table.dm').read_text()


def project_tail(source):
    body = source.split('/obj/structure/table/do_climb(', 1)[1].split('\n/obj/', 1)[0]
    tail = body.split('\t// Move the user', 1)[1] if '\t// Move the user' in body else body.split('\t// A flipped table', 1)[1]
    tail = tail.split('\n\tclimbers -= user', 1)[0]
    lines = ['def climb():']
    for raw in tail.splitlines()[1:]:
        raw = raw.split('//', 1)[0].rstrip()
        if not raw.strip():
            continue
        indent = len(raw) - len(raw.lstrip('\t'))
        line = raw.strip()
        if line.startswith('if'):
            condition = re.fullmatch(r'if\s*\((.*)\)', line).group(1)
            condition = condition.replace('&&', ' and ').replace('istype(src, /obj/structure/table/glass)', 'isglass(src)')
            line = 'if ' + condition + ':'
        elif line == 'else':
            line = 'else:'
        elif line.startswith('var/'):
            variable, value = line.split(' = ', 1)
            line = variable.rsplit('/', 1)[-1] + ' = ' + value
        elif line.startswith('user.visible_message('):
            line = 'user.announced = True'
        elif re.fullmatch(r'\w+ = get_step\(src, dir\)', line):
            pass
        elif not (line.startswith('user.forceMove(') or line == 'G.shatter()'):
            raise AssertionError('Unreviewed table climb statement: ' + line)
        lines.append('    ' * indent + line)
    return '\n'.join(lines) + '\n'


class Table:
    turf = 'table'

    def __init__(self, glass):
        self.glass = glass
        self.shattered = False

    def shatter(self):
        self.shattered = True


class Climber:
    def __init__(self, turf, move_allowed):
        self.turf = turf
        self.move_allowed = move_allowed
        self.announced = False

    def forceMove(self, turf):
        if self.move_allowed:
            self.turf = turf


def simulate(flipped, origin, glass=True, move_allowed=True):
    table = Table(glass)
    user = Climber(origin, move_allowed)
    env = dict(src=table, user=user, flipped=flipped, dir='north', T='forward',
               get_turf=lambda obj: obj.turf, get_step=lambda obj, direction: 'forward',
               isglass=lambda obj: obj.glass)
    exec(compile(project_tail(SOURCE), '<projected table climb>', 'exec'), env)
    env['climb']()
    return user.turf, user.announced, table.shattered


class TableClimb(unittest.TestCase):
    def test_upright_glass_shatters_on_a_completed_climb(self):
        self.assertEqual(simulate(False, 'front'), ('table', True, True))

    def test_both_flipped_approaches_shatter_at_the_actual_destination(self):
        self.assertEqual(simulate(True, 'forward'), ('table', True, True))
        self.assertEqual(simulate(True, 'table'), ('forward', True, True))

    def test_failed_or_non_glass_climbs_do_not_shatter_glass(self):
        self.assertEqual(simulate(False, 'front', move_allowed=False), ('front', False, False))
        self.assertEqual(simulate(False, 'front', glass=False), ('table', True, False))
        self.assertEqual(simulate(False, 'table'), ('table', False, False))


if __name__ == '__main__':
    unittest.main()
