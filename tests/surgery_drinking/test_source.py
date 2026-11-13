"""Source contracts for drinking from containers on help intent."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SURGERY = (ROOT / "code/modules/surgery/surgery.dm").read_text(encoding="utf-8")
GLASS = (ROOT / "code/modules/reagents/reagent_containers/glass.dm").read_text(encoding="utf-8")


def do_surgery():
    match = re.search(r"(?m)^proc/do_surgery\(.*\n(?:(?:\t[^\n]*|)\n)*", SURGERY)
    assert match, "missing do_surgery"
    return match.group()


class DrinkingTests(unittest.TestCase):
    def test_skill_warning_only_after_step_applies(self):
        body = do_surgery()
        applies = body.index("S.can_use(user, M, zone, tool)")
        warning = body.index("not skilled enough")
        self.assertLess(applies, warning)
        self.assertEqual(body.count("not skilled enough"), 1)

    def test_own_mouth_with_open_container_drinks(self):
        body = do_surgery()
        guard = body.index('M == user && zone == "mouth"')
        self.assertLess(guard, body.index("for (var/datum/surgery_step/S in surgery_steps)"))
        self.assertIn("tool.is_open_container()", body[guard:guard + 200])

    def test_self_drink_message_names_the_drinker(self):
        self.assertIn("[user] drinks from \\the [src].", GLASS)
        self.assertNotIn("[src] drinks from \\the [src].", GLASS)


if __name__ == "__main__":
    unittest.main()
