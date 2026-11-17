"""Source checks: pain only eases while a living body sleeps.

A sleeping Gaia character woke to the all-white near-death view (passage
overlay, health below -95) after a night logged out. Asleep bodies kept
taking new pain, rising shock and slow burns from heat, cold and a warm coat.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def proc(text, header):
    start = text.index(header)
    nxt = re.search(r"^/", text[start + len(header):], re.M)
    return text[start:start + len(header) + (nxt.start() if nxt else len(text))]


class SleepPainHold(unittest.TestCase):
    def setUp(self):
        self.pain = read("code/modules/organs/pain.dm")
        self.organ = read("code/modules/organs/organ_external.dm")
        self.life = read("code/game/mob/living/carbon/human/human_life.dm")

    def test_hold_covers_sleep_and_saved_bed_sleep_but_not_death(self):
        body = proc(self.pain, "/mob/living/human/proc/sleep_pain_hold()")
        self.assertIn("return stat != DEAD && (sleeping > 0 || inducedSSD)", body)

    def test_no_new_limb_pain_while_asleep(self):
        body = proc(self.organ, "/obj/item/organ/external/proc/add_pain(var/amount)")
        hold = body.index("if(owner && owner.sleep_pain_hold())")
        self.assertLess(hold, body.index("pain = max(0,min(max_damage,pain+amount))"))
        # Healing pain stays open.
        heal = proc(self.organ, "/obj/item/organ/external/proc/remove_pain(var/amount)")
        self.assertNotIn("sleep_pain_hold", heal)

    def test_shock_only_recovers_while_asleep(self):
        body = proc(self.life, "/mob/living/human/proc/handle_shock()")
        self.assertIn("if (traumatic_shock >= 80 && shock_stage < 160 && !sleep_pain_hold())", body)
        # Replay: high shock input while asleep must fall, never rise.
        shock_stage, asleep = 100, True
        for _ in range(600):
            traumatic = 200
            if traumatic >= 80 and shock_stage < 160 and not asleep:
                shock_stage += 1
            else:
                shock_stage = min(shock_stage, 160)
                recovery = 1 + (traumatic < 0.5 * shock_stage) + (traumatic < 0.25 * shock_stage)
                shock_stage = max(shock_stage - recovery, 0)
        self.assertEqual(shock_stage, 0)

    def test_heat_cold_and_coat_do_not_wound_a_sleeper(self):
        body = proc(self.life, "/mob/living/human/handle_environment()")
        self.assertIn("var/pain_held = sleep_pain_hold()", body)
        self.assertIn("if (!pain_held && loc_temp > 18 && istype(wear_suit, /obj/item/clothing/suit/storage/coat)", body)
        self.assertRegex(body, r"if \(!pain_held\)\n\t\tspecies\.get_environment_discomfort\(src\)")
        self.assertEqual(len(re.findall(r"species\.get_environment_discomfort\(src\)", body)), 1)


if __name__ == "__main__":
    unittest.main()
