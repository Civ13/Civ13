"""Gas skin burns reach bare limbs and skip covered ones (#5472).

Projects /datum/reagent/proc/external_damage: the initial exposed list, the
clothing removals and the damage branches must all use the same keys.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GASES = ROOT / "code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Gases.dm"

FLAGS = {"HEAD": "head", "UPPER_TORSO": "chest", "LOWER_TORSO": "groin", "LEGS": "legs",
         "FEET": "feet", "ARMS": "arms", "HANDS": "hands"}


def body():
    text = GASES.read_text()
    start = text.index("/datum/reagent/proc/external_damage(")
    end = text.index("\n/datum/reagent/proc/", start + 1)
    return text[start:end]


def simulate(covered):
    src = body()
    burnlist = re.search(r'var/burnlist = "([^"]*)"', src).group(1)
    for flag, key in re.findall(r'body_parts_covered & (\w+)\)\s*\n\s*burnlist = replacetext\(burnlist,"(\w+),",""\)', src):
        if flag in covered:
            burnlist = burnlist.replace(key + ",", "")
    burned = []
    branches = re.findall(r'if \(pts == "(\w+)"\)((?:\n\t\t\t\t[^\n]*)+)', src)
    for part in burnlist.split(","):
        for key, code in branches:
            if key == part:
                burned += re.findall(r'adjustBurnLossByPart\(base, "(\w+)"\)', code)
    return burned


class GasSkinBurnTests(unittest.TestCase):
    def test_bare_body_burns_every_limb(self):
        burned = simulate(set())
        for organ in ("l_arm", "r_arm", "l_leg", "r_leg", "l_hand", "r_hand", "l_foot", "r_foot", "chest", "groin"):
            self.assertIn(organ, burned)

    def test_covered_regions_are_spared(self):
        burned = simulate({"ARMS", "LEGS", "HANDS"})
        for organ in ("l_arm", "r_arm", "l_leg", "r_leg", "l_hand", "r_hand"):
            self.assertNotIn(organ, burned)
        self.assertIn("chest", burned)
        self.assertEqual(simulate(set(FLAGS)), [])

    def test_every_listed_key_has_a_removal_and_a_branch(self):
        src = body()
        keys = [k for k in re.search(r'var/burnlist = "([^"]*)"', src).group(1).split(",") if k]
        self.assertEqual(sorted(keys), sorted(FLAGS.values()))
        for key in keys:
            self.assertIn('replacetext(burnlist,"%s,","")' % key, src)
            self.assertIn('pts == "%s"' % key, src)


if __name__ == "__main__":
    unittest.main()
