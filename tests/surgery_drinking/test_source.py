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

    def test_drinking_credits_half_the_amount_actually_swallowed(self):
        containers = (ROOT / 'code/modules/reagents/reagent_containers.dm').read_text(encoding='utf-8')
        feed = containers.split('/proc/standard_feed_mob(', 1)[1].split('\n/', 1)[0]
        self.assertIn('var/swallowed = reagents.trans_to_mob(target', feed)
        self.assertIn('if (swallowed > 0)\n\t\ttarget.bladder += swallowed / 2', feed)
        self.assertNotIn('target.bladder += amount_per_transfer_from_this', feed)
        taste = (ROOT / 'code/game/mob/living/carbon/taste.dm').read_text(encoding='utf-8')
        self.assertIn('var/swallowed = from.trans_to_holder(target,amount,multiplier,copy)', taste)
        self.assertIn('return swallowed', taste)
        holder = (ROOT / 'code/modules/reagents/Chemistry-Holder.dm').read_text(encoding='utf-8')
        self.assertIn('return C.ingest(src,R, amount, multiplier, copy, smoked)', holder)


if __name__ == "__main__":
    unittest.main()
