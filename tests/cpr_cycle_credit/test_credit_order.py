"""A finished CPR round is credited before the post-wait recheck (#6383)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "code/game/mob/living/carbon/human/resuscitation.dm").read_text(encoding="utf-8-sig")


def block(header):
    start = SOURCE.index(header)
    nxt = re.search(r"\n(?=\S)", SOURCE[start + len(header):])
    return SOURCE[start:start + len(header) + nxt.start()] if nxt else SOURCE[start:]


class CprCycleCreditTest(unittest.TestCase):
    def test_credit_needs_a_running_clock(self):
        credit = block("/mob/living/human/proc/credit_cpr_cycle()")
        self.assertIn("if (revival_clock)", credit)
        self.assertIn("revival_clock = min(world.time, revival_clock + CPR_REVIVAL_CYCLE)", credit)

    def test_completed_round_is_credited_before_the_recheck(self):
        cpr = block("/mob/living/human/proc/try_cpr_revival(mob/living/human/rescuer)")
        wait = cpr.index("do_after(rescuer, CPR_REVIVAL_CYCLE, src)")
        interrupted = cpr.index("if (!finished || stat != DEAD)", wait)
        credit = cpr.index("credit_cpr_cycle()", wait)
        recheck = cpr.index("reason = resuscitation_blocker()", wait)
        self.assertLess(interrupted, credit)
        self.assertLess(credit, recheck)
        self.assertEqual(cpr.count("credit_cpr_cycle()"), 1)
        self.assertNotIn("revival_clock = ", cpr)


if __name__ == "__main__":
    unittest.main()
