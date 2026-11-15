"""Replay the snow freezing-foot branch of cold discomfort from source, not BYOND."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/living/carbon/human/species/species.dm'

# The pre-fix branch, frozen as a negative control.
OLD_BRANCH = '''		if (istype(T) && T.has_snow_cover() && H.shoes)
			if (H.shoes.cold_protection != FEET)
				if (prob(25 - (H.shoes ? 15 : 0)))
					to_chat(H, SPAN_DANGER("Your feet are freezing!"))
'''


def branch(source):
    start = source.index('if (istype(T) && T.has_snow_cover()')
    end = source.index('Your feet are freezing!', start)
    return source[start:end]


def evaluate(cond, shoes):
    """Evaluate a DM condition for shoes: None (barefoot), 'plain', 'insulated' or 'sandals'.

    footwear_feet_bare_to_snow() (weather_footwear.dm) is true for bare feet,
    open-toed sandals and shoes without FEET cold protection."""
    expr = cond.replace('istype(T) && T.has_snow_cover()', 'True')
    expr = expr.replace('footwear_feet_bare_to_snow(H)', '(shoes != "insulated")')
    expr = expr.replace('H.shoes.cold_protection != FEET', '(shoes == "plain")')
    expr = expr.replace('!H.shoes', '(shoes is None)').replace('H.shoes', '(shoes is not None)')
    expr = expr.replace('||', ' or ').replace('&&', ' and ')
    return bool(eval(expr, {}, {'shoes': shoes}))


def freeze_chance(source, shoes):
    """Percent chance per update that bare or unprotected feet take the snow injury."""
    text = branch(source)
    for cond in re.findall(r'if \((.*)\)\n', text):
        if cond.startswith('prob('):
            if re.match(r'prob\(25 - \(H\.shoes \? 15 : 0\)\)', cond):
                return 10 if shoes else 25
            # Closed shoes cut the chance; bare feet and open toes do not.
            assert re.match(r'prob\(25 - \(\(istype\(snow_shoes\) && !snow_shoes\.open_toed\) \? 15 : 0\)\)', cond), cond
            return 10 if shoes in ('plain', 'insulated') else 25
        if not evaluate(cond, shoes):
            return 0
    raise AssertionError('no prob() in branch')


class SnowFeetTest(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_bare_feet_freeze_at_25_percent(self):
        self.assertEqual(freeze_chance(self.source, None), 25)

    def test_plain_shoes_freeze_at_10_percent(self):
        self.assertEqual(freeze_chance(self.source, 'plain'), 10)

    def test_insulated_shoes_never_freeze(self):
        self.assertEqual(freeze_chance(self.source, 'insulated'), 0)

    def test_sandals_freeze_like_bare_feet(self):
        self.assertEqual(freeze_chance(self.source, 'sandals'), 25)

    def test_negative_control_old_branch_skips_bare_feet(self):
        self.assertEqual(freeze_chance(OLD_BRANCH, None), 0)
        self.assertEqual(freeze_chance(OLD_BRANCH, 'plain'), 10)


if __name__ == '__main__':
    unittest.main()
