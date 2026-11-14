"""Unfastened automatic tablet presses stop pressing and release power (#5303).

Projects the production can_press()/press_step() bodies with stub helpers.
"""
from pathlib import Path
import sys
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/primitive_woodworking'))
from source_adapter import compile_body

SOURCE = (ROOT / 'code/modules/1713/factory_packaging.dm').read_text(encoding='utf-8')
PRESS = '/obj/structure/fluid_tablet_press'
# Pre-fix guard, frozen as a negative control.
OLD_CAN_PRESS = PRESS + '''/proc/can_press()
	if (!isturf(loc) || !tablet_press_year_allowed())
		return FALSE
	for (var/id in fluid_tablet_cost)
		if (reagents.get_reagent_amount(id) < fluid_tablet_cost[id])
			return FALSE
	return factory_loose_items(loc) < FLUID_PRESS_OUTPUT_LIMIT
'''
FIELDS = ('anchored', 'loc', 'reagents', 'fluid_tablet_cost', 'powered', 'can_press',
          'press_release_power', 'draw_cable_power')


def project(text, signature, args, env):
    body = text[text.index(signature):]
    body = body.replace('for (var/id in fluid_tablet_cost)', 'for id in fluid_tablet_cost:')
    body = body.replace('= new(loc)', '= construct(loc)')
    return compile_body(body, signature, args, env, FIELDS)[0]


class Press:
    def __init__(self, text, anchored):
        self.anchored = anchored
        self.loc = NS(type='/turf')
        stock = {'calcium_carbonate': 10, 'aspirin': 10}
        self.reagents = NS(get_reagent_amount=lambda i: stock.get(i, 0), get_data=lambda i: None,
                           remove_reagent=lambda i, n: stock.__setitem__(i, stock[i] - n))
        self.fluid_tablet_cost = {'calcium_carbonate': 2, 'aspirin': 3}
        self.powered = True
        self.released = 0
        self.drawn = 0
        env = dict(isturf=lambda t: getattr(t, 'type', '') == '/turf', tablet_press_year_allowed=lambda: True,
                   factory_loose_items=lambda t: 0, FLUID_PRESS_OUTPUT_LIMIT=10,
                   construct=lambda *a: NS(name='', reagents=NS(add_reagent=lambda *b: None)))
        can = project(text, PRESS + '/proc/can_press()', 'self', env)
        self.can_press = lambda: can(self)
        step_source = text if PRESS + '/proc/press_step()' in text else SOURCE
        step = project(step_source, PRESS + '/proc/press_step()', 'self', env)
        self.press_step = lambda: step(self)

    def press_release_power(self):
        self.released += 1
        self.powered = False

    def draw_cable_power(self):
        self.drawn += 1
        return True


class PressAnchoringTest(unittest.TestCase):
    def test_unfastened_press_does_no_work_and_releases_power(self):
        press = Press(SOURCE, anchored=False)
        self.assertFalse(press.can_press())
        self.assertFalse(press.press_step())
        self.assertEqual((press.released, press.drawn, press.powered), (1, 0, False))

    def test_refastened_press_resumes(self):
        press = Press(SOURCE, anchored=True)
        self.assertTrue(press.can_press())
        press.powered = False
        press.anchored = True
        self.assertTrue(press.press_step())
        self.assertEqual(press.drawn, 1)

    def test_negative_control_old_guard_ignores_anchoring(self):
        press = Press(OLD_CAN_PRESS, anchored=False)
        self.assertTrue(press.can_press())


if __name__ == '__main__':
    unittest.main()
