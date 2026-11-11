"""Source-projected double-holster draw effects with fake engine boundaries."""
from pathlib import Path
from types import SimpleNamespace
import re
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'save_movement'))
from source_adapter import extract, project, read

HOLSTER = 'code/game/objects/items/clothing/under/accessories/holster.dm'


class Weapon:
    def __init__(self, size):
        self.w_class = size
        self.fingerprints = []

    def add_fingerprint(self, user):
        self.fingerprints.append(user)


def draw_second(first, second):
    # Select the complete effects block of the capacity-two second-slot branch.
    body = extract(read(HOLSTER), '/obj/item/clothing/accessory/holster/proc/unholster')
    branch = body.split('\telse if (holstered2 && capacity == 2)', 1)[1]
    branch = branch.split('\n\telse if (holstered && capacity == 2)', 1)[0]
    start = branch.index('\t\t\tuser.put_in_hands(holstered2)')
    lines = [line[3:] for line in branch[start:].splitlines() if line.strip()]
    assert lines[-1] == 'holstered2 = null'
    code = '\n'.join('\t' + line for line in lines)
    code = re.sub(r'(?<![\w.])(holstered2|holstered|w_class)\b', r'src.\1', code)
    source = '/proc/draw_second(user)\n' + code + '\n'
    effects = {'initial': lambda _: 2}
    handler = project(source, '/proc/draw_second', 'src, user', effects)
    holster = SimpleNamespace(holstered=first, holstered2=second, w_class=3)
    user = SimpleNamespace(drawn=[])
    def put_in_hands(item):
        user.drawn.append(item)
        item.add_fingerprint(user)  # Human hand placement also fingerprints it.
    user.put_in_hands = put_in_hands
    handler(holster, user)
    return holster, user


class DoubleHolsterDraw(unittest.TestCase):
    def test_draw_fingerprints_the_drawn_weapon(self):
        first, second = Weapon(3), Weapon(3)
        holster, user = draw_second(first, second)
        self.assertEqual(user.drawn, [second])
        self.assertEqual(second.fingerprints, [user, user])
        self.assertEqual(first.fingerprints, [])
        self.assertIs(holster.holstered, first)
        self.assertIsNone(holster.holstered2)

    def test_remaining_normal_weapon_preserves_holster_size(self):
        holster, _ = draw_second(Weapon(3), Weapon(3))
        self.assertEqual(holster.w_class, 3)

    def test_remaining_small_weapon_restores_small_holster_size(self):
        holster, _ = draw_second(Weapon(2), Weapon(3))
        self.assertEqual(holster.w_class, 2)

    def test_draw_works_if_only_second_slot_is_occupied(self):
        holster, user = draw_second(None, Weapon(3))
        self.assertEqual(len(user.drawn), 1)
        self.assertEqual(holster.w_class, 2)
