"""Source contracts for the five wrestling action buttons (not native gameplay)."""
from pathlib import Path
import re
import unittest

SOURCE = Path(__file__).resolve().parents[2] / 'code/modules/1713/martial_arts/wrestling.dm'
MOVES = {
    'slam': ('BODY SLAM', 'slam'),
    'throw_wrassle': ('THROW', 'throw'),
    'kick': ('KICK', 'kick'),
    'strike': ('STRIKE', 'strike'),
    'drop': ('LEG DROP', 'drop'),
}


def assert_actions(test, source):
    helper = source.split('/datum/action/proc/prepare_wrestling_move(', 1)[1].split('\n/', 1)[0]
    guard = "if(owner.incapacitated())\n\t\tto_chat(owner, \"<span class='warning'>You can't WRESTLE while you're OUT FOR THE COUNT.</span>\")\n\t\treturn"
    message = "owner.visible_message(\"<span class='danger'>[owner] prepares to [move_label]!</span>\", \"<b><i>Your next attack will be a [move_label].</i></b>\")"
    update = 'owner.mind.martial_art.streak = move_streak'
    test.assertIn(guard, helper)
    test.assertIn(message, helper)
    test.assertLess(helper.index(guard), helper.index(message))
    test.assertLess(helper.index(message), helper.index(update))
    for action, (label, streak) in MOVES.items():
        body = source.split(f'/datum/action/{action}/Trigger()\n', 1)[1].split('\n/', 1)[0]
        test.assertEqual(body.strip(), f'prepare_wrestling_move("{label}", "{streak}")')


class WrestlingActionsTest(unittest.TestCase):
    def test_all_buttons_preserve_guard_messages_and_move_mapping(self):
        assert_actions(self, SOURCE.read_text(encoding='utf-8'))

    def test_missing_guard_and_wrong_move_are_rejected(self):
        source = SOURCE.read_text(encoding='utf-8')
        for changed in (
            source.replace('if(owner.incapacitated())', 'if(FALSE)', 1),
            source.replace('prepare_wrestling_move("LEG DROP", "drop")',
                           'prepare_wrestling_move("LEG DROP", "kick")', 1),
        ):
            self.assertNotEqual(changed, source)
            with self.assertRaises((AssertionError, ValueError)):
                assert_actions(self, changed)


if __name__ == '__main__':
    unittest.main()
