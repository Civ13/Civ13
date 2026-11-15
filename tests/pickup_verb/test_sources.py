"""Offline check: the right-click Pick up verb does not refuse seated players.

Sitting in a chair turns canmove off but clicking an item still picks it up,
so the verb must use the same gate as ClickOn. tests/pickup_verb/run.py is the
native probe for the same behaviour.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/items.dm'
DECL = '/obj/item/verb/verb_pickup()'

# The pre-fix gate, frozen as a negative control.
OLD_GATE = '\tif (!usr.canmove || usr.stat || usr.restrained() || !Adjacent(usr))\n\t\treturn\n'


def verb_body(source):
    start = source.index(DECL)
    return source[start:source.find('\n/', start + 1)]


def refuses_seated(body):
    """True when the verb would return before picking up for a buckled player."""
    return 'usr.canmove' in body


class PickupVerbTest(unittest.TestCase):
    def setUp(self):
        self.body = verb_body(SOURCE.read_text(encoding='utf-8'))

    def test_seated_player_is_not_refused(self):
        self.assertFalse(refuses_seated(self.body))

    def test_matches_click_incapacitation_gate(self):
        self.assertIn('if (usr.stat || usr.paralysis || usr.stunned || usr.weakened)', self.body)

    def test_out_of_reach_says_so(self):
        self.assertIn("if (!Adjacent(usr))\n\t\tto_chat(usr, \"<span class='warning'>You can't reach that.</span>\")", self.body)

    def test_still_refuses_restrained_and_still_picks_up_by_hand(self):
        self.assertIn('usr.restrained()', self.body)
        self.assertIn('usr.UnarmedAttack(src)', self.body)

    def test_negative_control_old_gate_refuses_seated(self):
        self.assertTrue(refuses_seated(DECL + '\n' + OLD_GATE))


if __name__ == '__main__':
    unittest.main()
