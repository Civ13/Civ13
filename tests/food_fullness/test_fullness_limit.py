"""Eating refusal follows the stomach size, not a fixed fullness number.

Gaia 2026-11-15: after the food pool grew from 400 to 600, the old fixed limit
of 580 (nutrition + 160 + stomach nutriment) turned people away from food at
about 70 % of the hunger bar, so fresh characters could not eat for most of an
hour. The limit must follow max_nutrition.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
CARBON = ROOT / 'code/game/mob/living/carbon/carbon.dm'
DEFINES = ROOT / 'code/game/mob/living/carbon/carbon_defines.dm'
EATERS = [
    ROOT / 'code/modules/reagents/reagent_containers/food/snacks.dm',
    ROOT / 'code/game/objects/items/weapons/material/kitchen.dm',
]


def proc_body(text, signature):
    start = text.index(signature)
    rest = text[start + len(signature):]
    end = re.search(r'\n(?=\S)', rest)
    return rest[: end.start() if end else len(rest)]


class FullnessLimitTest(unittest.TestCase):
    def setUp(self):
        carbon = CARBON.read_text(encoding='utf-8')
        self.fullness = proc_body(carbon, '/mob/living/human/proc/get_fullness()')
        self.limit = proc_body(carbon, '/mob/living/human/proc/food_fullness_limit()')
        self.max_nutrition = float(re.search(r'var/max_nutrition\s*=\s*([\d.]+)',
                                             DEFINES.read_text(encoding='utf-8')).group(1))

    def test_limit_follows_max_nutrition(self):
        self.assertRegex(self.limit, r'return\s+max_nutrition\s*\+\s*\d+')

    def test_hungry_character_can_eat(self):
        offset = float(re.search(r'\)\s*\+\s*(\d+)', self.fullness).group(1))
        extra = float(re.search(r'max_nutrition\s*\+\s*(\d+)', self.limit).group(1))
        # An empty stomach at 95 % of the bar still has room for a bite.
        self.assertLess(self.max_nutrition * 0.95 + offset, self.max_nutrition + extra)
        # A full bar with nothing left to digest is still within the limit,
        # as it was with the old 400 pool and 580 limit.
        self.assertLessEqual(self.max_nutrition + offset, self.max_nutrition + extra)

    def test_no_fixed_limit_left(self):
        for path in EATERS:
            text = path.read_text(encoding='utf-8')
            self.assertNotRegex(text, r'fullness\(?\)?\s*[<>]=?\s*580', path.name)
            self.assertIn('food_fullness_limit()', text, path.name)


if __name__ == '__main__':
    unittest.main()
