"""Execution devices hold one victim even when two placements overlap (issue #6499).

Each MouseDrop_T waits in do_after, and the repeat guard is per actor, so two
hangmen can wait at once. The block after the wait must recheck occupancy and
only then move, record and anchor the target. This interprets the indentation
of the production block; it is source evidence, not a DM runtime.
"""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract

SOURCE = (ROOT / 'code/modules/1713/punishment.dm').read_text(encoding='utf-8')
FAMILIES = ('noose', 'gallows', 'cross', 'pillory', 'post_execution')
GUARD = 'if (!QDELETED(src) && !hanging)'
EFFECTS = ('target.persistence_set_loc(', 'hanging = target')


def depth(line):
    return len(line) - len(line.lstrip('\t'))


def after_wait(body):
    lines = body.splitlines()
    waits = [i for i, line in enumerate(lines) if re.search(r'if \(do_after\(hangman, \d+, target\)\)', line)]
    if len(waits) != 1:
        raise AssertionError('Expected one placement wait')
    start = waits[0]
    block = []
    for line in lines[start + 1:]:
        if line.strip() and depth(line) <= depth(lines[start]):
            break
        block.append(line)
    return [line for line in block if line.split('//', 1)[0].strip()]


def placements(block, hanging):
    """Which effects run, given occupancy at the end of the wait."""
    ran, gates = [], []
    for line in block:
        code = line.strip()
        while gates and depth(line) <= gates[-1][0]:
            gates.pop()
        if code.startswith('if ('):
            open_ = all(g[1] for g in gates)
            if code == GUARD:
                gates.append((depth(line), not hanging))
            elif code.startswith('if (!target.persistence_set_loc('):
                gates.append((depth(line), True))  # admission granted; its effect is recorded below
                if open_:
                    ran.append('target.persistence_set_loc(')
            else:
                gates.append((depth(line), True))  # cosmetic branches (skin tone etc.) do not gate occupancy
            continue
        if all(g[1] for g in gates):
            ran.extend(effect for effect in EFFECTS if code.startswith(effect))
    return ran


class OccupancyRecheck(unittest.TestCase):
    def test_every_family_rechecks_before_placing(self):
        for family in FAMILIES:
            with self.subTest(family=family):
                block = after_wait(extract(SOURCE, '/obj/structure/' + family + '/MouseDrop_T'))
                self.assertEqual(block[0].strip(), GUARD)
                self.assertEqual(placements(block, hanging=None), list(EFFECTS))

    def test_a_filled_device_keeps_its_first_victim(self):
        for family in FAMILIES:
            with self.subTest(family=family):
                block = after_wait(extract(SOURCE, '/obj/structure/' + family + '/MouseDrop_T'))
                self.assertEqual(placements(block, hanging='first victim'), [])


if __name__ == '__main__':
    unittest.main()
