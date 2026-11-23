"""Source checks for issue 6979: clamped incisions stay clamped after their wound expires."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ORGAN = ROOT / 'code/modules/organs/organ_external.dm'


def body(text, header):
    return text.split(header, 1)[1].split('\n/', 1)[0]


class IncisionClampTest(unittest.TestCase):
    def setUp(self):
        self.text = ORGAN.read_text(encoding='utf-8')

    def test_clamping_marks_the_open_incision(self):
        clamp = body(self.text, '/obj/item/organ/external/proc/clamping()')
        self.assertIn('if (open)', clamp)
        self.assertIn('incision_clamped = TRUE', clamp)

    def test_update_damages_keeps_incision_clamp_until_closed(self):
        damages = body(self.text, '/obj/item/organ/external/proc/update_damages()')
        reset = damages.index('if (!open)\n\t\tincision_clamped = FALSE')
        keep = damages.index('clamped |= incision_clamped')
        bleed = damages.index('if (open && !clamped')
        self.assertLess(reset, keep)
        self.assertLess(keep, bleed)


if __name__ == '__main__':
    unittest.main()
