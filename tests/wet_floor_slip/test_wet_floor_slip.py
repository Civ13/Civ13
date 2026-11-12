"""Check that a human's slip() result reaches the wet-floor slide, from source, not BYOND."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HUMAN = ROOT / 'code/game/mob/living/carbon/human/human.dm'
CARBON = ROOT / 'code/game/mob/living/carbon/carbon.dm'
TURF = ROOT / 'code/game/turfs/turf.dm'

HEADER = '/mob/living/human/slip(var/slipped_on, stun_duration=8)\n'

# The pre-fix wrapper, frozen as a negative control.
OLD_WRAPPER = HEADER + '''	if ((species.flags & NO_SLIP) || (shoes && (shoes.item_flags & NOSLIP)))
		return FALSE
	..(slipped_on,stun_duration)
'''


def wrapper_body(source):
    start = source.index(HEADER) + len(HEADER)
    end = source.find('\n/', start)
    return source[start:end if end != -1 else None]


def wrapper_result(body, immune, parent_result=True):
    """Return what the wrapper hands back to its caller: True, False or None (null)."""
    lines = [l.strip() for l in body.splitlines() if l.strip()]
    if immune:
        return False if lines[1] == 'return FALSE' else None
    for line in lines[2:]:
        if line.startswith('return ..(') or line.startswith('. = ..('):
            return parent_result
    return None


def slide_steps(body, immune, wet):
    """Steps the turf takes after Entered() calls M.slip() (turf.dm wet branch)."""
    distance = 4 if wet == 2 else 1
    return distance if wrapper_result(body, immune) else 0


class WetFloorSlipTest(unittest.TestCase):
    def setUp(self):
        self.body = wrapper_body(HUMAN.read_text(encoding='utf-8'))

    def test_human_slides_on_wet_floor(self):
        self.assertEqual(slide_steps(self.body, False, 1), 1)

    def test_human_slides_four_tiles_on_lube(self):
        self.assertEqual(slide_steps(self.body, False, 2), 4)

    def test_no_slip_human_does_not_slide(self):
        self.assertIs(wrapper_result(self.body, True), False)
        self.assertEqual(slide_steps(self.body, True, 2), 0)

    def test_parent_failure_still_fails(self):
        self.assertFalse(wrapper_result(self.body, False, parent_result=False))

    def test_parent_handler_returns_true_and_turf_uses_result(self):
        carbon = CARBON.read_text(encoding='utf-8')
        parent = carbon[carbon.index('/mob/living/human/slip(var/slipped_on,stun_duration=8)'):]
        self.assertIn('return TRUE', parent.split('\n/', 1)[0])
        self.assertRegex(TURF.read_text(encoding='utf-8'), r'if \(M\.slip\("the \[floor_type\] floor",slip_stun\)\)\n\t+for ')

    def test_negative_control_old_wrapper_drops_slide(self):
        self.assertIsNone(wrapper_result(wrapper_body(OLD_WRAPPER), False))
        self.assertEqual(slide_steps(wrapper_body(OLD_WRAPPER), False, 2), 0)


if __name__ == '__main__':
    unittest.main()
