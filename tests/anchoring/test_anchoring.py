"""Wrench fastening goes through toggle_anchor()/timed_toggle_anchor().

About 45 objects toggled `anchored` by hand, each with its own copy of the
ratchet sound and the secure/unfasten messages. The two helpers in
code/_helpers/tools.dm keep the messages the common copies used (frozen
below). TOGGLE_CEILING: hand-written `anchored = !anchored` outside the
helpers only goes down; new fixed objects call a helper.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HELPERS = ROOT / 'code/_helpers/tools.dm'
TOGGLE_CEILING = 21

INSTANT_MESSAGES = ('SPAN_NOTICE("You unfasten \\the [src] from the floor.")',
                    'SPAN_NOTICE("You secure \\the [src] to the floor.")')
TIMED_MESSAGES = ('"<span class=\'warning\'>[user] starts to [anchored ? "unsecure" : "secure"] [label] [anchored ? "from" : "to"] the ground.</span>"',
                  '"<span class=\'warning\'>[user] [anchored ? "unsecures" : "secures"] [label] [anchored ? "from" : "to"] the ground.</span>"')


def proc(text, name):
    start = text.index(name)
    match = re.search(r'\n(?=[/\S])', text[start + 1:])
    return text[start:start + 1 + match.start()] if match else text[start:]


class AnchoringTest(unittest.TestCase):
    def setUp(self):
        self.helpers = HELPERS.read_text(encoding='utf-8')

    def test_helpers_keep_the_common_messages(self):
        instant = proc(self.helpers, '/obj/proc/toggle_anchor(')
        for message in INSTANT_MESSAGES:
            self.assertIn(message, instant)
        self.assertIn("playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)", instant)
        timed = proc(self.helpers, '/obj/proc/timed_toggle_anchor(')
        for message in TIMED_MESSAGES:
            self.assertIn(message, timed)
        self.assertIn('label = "\\the [src]"', timed)

    def test_both_toggle_once_and_notify_structures(self):
        for name in ('/obj/proc/toggle_anchor(', '/obj/proc/timed_toggle_anchor('):
            body = proc(self.helpers, name)
            self.assertEqual(body.count('anchored = !anchored'), 1, name)
            self.assertLess(body.index('anchored = !anchored'), body.index('anchor_toggled()'), name)
        self.assertIn('S.anchor_changed()', proc(self.helpers, '/obj/proc/anchor_toggled('))

    def test_timed_toggle_refuses_interrupted_or_raced_waits(self):
        timed = proc(self.helpers, '/obj/proc/timed_toggle_anchor(')
        guard = 'if (!do_after(user, delay, src) || QDELETED(src) || anchored != was_anchored)'
        self.assertIn(guard, timed)
        self.assertLess(timed.index(guard), timed.index('anchored = !anchored'))

    def test_hand_written_toggles_only_go_down(self):
        count = 0
        calls = 0
        for path in (ROOT / 'code').rglob('*.dm'):
            if path == HELPERS:
                continue
            text = path.read_text(encoding='utf-8', errors='replace')
            count += len(re.findall(r'(?<![\w.])anchored = !anchored', text))
            calls += len(re.findall(r'\btoggle_anchor\(|\btimed_toggle_anchor\(', text))
        self.assertLessEqual(count, TOGGLE_CEILING)
        self.assertGreaterEqual(calls, 25)


if __name__ == '__main__':
    unittest.main()
