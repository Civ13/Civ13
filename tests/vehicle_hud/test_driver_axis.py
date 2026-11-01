"""Offline pre/post characterization; no engine, mouse, sound or network launch."""
from pathlib import Path
import re
import sys
from types import SimpleNamespace as N
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project

SOURCE = ROOT / 'code/_onclick/hud/hud_vehicles.dm'
BEFORE = Path(__file__).with_name('fixtures') / 'axis_handlers_before.dm'
BASE = '/obj/screen/vehicle'
CHAIR = '/obj/structure/bed/chair/drivers'
AXIS = '/obj/structure/vehicleparts/axis'


class DriverChair:
    def __init__(self, axis):
        self.axis = axis


class DerivedChair(DriverChair):
    pass


class Axis:
    def __init__(self, trace, reverse=False, speed=1, engine=True, label='axis'):
        self.__dict__.update(trace=trace, reverse=reverse, currentspeed=speed,
                             engine=None if engine is None else N(on=engine), label=label)

    def __setattr__(self, name, value):
        if name == 'reverse':
            self.trace.append(('reverse', self.label, value))
        object.__setattr__(self, name, value)


class DerivedAxis(Axis):
    pass


class Screen:
    def __init__(self, trace, parentmob):
        self.__dict__.update(trace=trace, parentmob=parentmob, icon_state='unchanged')

    def __setattr__(self, name, value):
        if name == 'icon_state':
            self.trace.append(('icon', value))
        object.__setattr__(self, name, value)


class Harness:
    def __init__(self, text, kind='direction', chain='valid', reverse=False,
                 speed=1, engine=True, parent_effect=None):
        self.trace = []
        axis_type = DerivedAxis if chain == 'derived-axis' else Axis
        self.axis = axis_type(self.trace, reverse, speed, engine)
        chair_type = DerivedChair if chain == 'derived-chair' else DriverChair
        chair = chair_type(self.axis)
        if chain == 'unbuckled':
            chair = None
        elif chain == 'wrong-chair':
            chair = N(axis=self.axis)  # Has an axis, but is not a driver chair.
        elif chain == 'missing-axis':
            chair.axis = None
        elif chain == 'wrong-axis':
            chair.axis = N(reverse=reverse, currentspeed=speed, engine=None)
        self.body = N(buckled=chair, loc='driver turf')
        self.screen = Screen(self.trace, None if chain == 'missing-parent' else self.body)
        self.parent_effect = parent_effect
        self.env = dict(screen=self.screen, DRIVER_CHAIR=DriverChair, AXIS=Axis,
                        istype=isinstance, parent=self.parent,
                        to_chat=lambda owner, message: self.trace.append(('chat', owner.loc, message)),
                        playsound=lambda *args: self.trace.append(('sound',) + args))
        resolver = BASE + '/proc/resolve_driver_axis'
        if resolver + '(' in text:
            self.env['resolve_driver_axis'] = self.bind(text, resolver)
        self.update = self.bind(text, BASE + '/' + kind + '/update_icon')
        self.env['update_icon'] = self.update
        self.click = self.bind(text, BASE + '/direction/Click') if kind == 'direction' else None

    def parent(self):
        self.trace.append(('parent', self.screen.icon_state))
        if self.parent_effect:
            self.parent_effect(self)

    def bind(self, text, declaration):
        body = extract(text, declaration)
        # Lower only syntax/engine boundaries in the complete selected body.
        # Unknown instructions remain and fail projection rather than being skipped.
        body = re.sub(r'\bvar/(?:\w+/)*(\w+)\b', r'\1', body)
        body = body.replace(CHAIR, 'DRIVER_CHAIR').replace(AXIS, 'AXIS')
        body = body.replace('..()', 'parent()')
        body = body.replace('"speed_[this_axis.currentspeed]"', 'f"speed_{this_axis.currentspeed}"')
        for field in ('parentmob', 'icon_state'):
            body = re.sub(r'(?<![\w.])' + field + r'\b', 'screen.' + field, body)
        return project(declaration + '()\n' + body + '\n', declaration, '', self.env)

    def observe(self, operation):
        error = None
        try:
            result = getattr(self, operation)()
        except (AttributeError, TypeError) as caught:
            result, error = None, type(caught).__name__
        return dict(result=result, error=error, icon=self.screen.icon_state,
                    reverse=self.axis.reverse, trace=list(self.trace))


def unbuckle_in_parent(harness):
    harness.body.buckled = None


def rebind_in_parent(harness):
    harness.replacement = Axis(harness.trace, reverse=False, speed=3, label='replacement')
    harness.body.buckled = DriverChair(harness.replacement)


class VehicleAxisCharacterization(unittest.TestCase):
    def setUp(self):
        self.before = BEFORE.read_text(encoding='utf-8-sig')
        self.after = SOURCE.read_text(encoding='utf-8-sig')

    def assert_parity(self, text):
        cases = [dict(chain=chain) for chain in (
            'missing-parent', 'unbuckled', 'wrong-chair', 'missing-axis', 'wrong-axis',
            'derived-chair', 'derived-axis')]
        cases += [dict(reverse=reverse, speed=speed, engine=engine)
                  for reverse in (False, True) for speed in (-1, 0, 1, 3, 6)
                  for engine in (None, False, True)]
        cases += [dict(parent_effect=effect) for effect in (unbuckle_in_parent, rebind_in_parent)]
        for case in cases:
            for kind, operation in (('direction', 'update'), ('direction', 'click'), ('current_gear', 'update')):
                before = Harness(self.before, kind, **case).observe(operation)
                after = Harness(text, kind, **case).observe(operation)
                self.assertEqual(after, before, (kind, operation, case))
                self.assertIsNone(after['error'])

    def test_complete_handlers_match_frozen_preimage_across_admission_and_state_matrix(self):
        self.assert_parity(self.after)

    def test_invalid_chain_preserves_icon_and_has_no_click_effects(self):
        for chain in ('missing-parent', 'unbuckled', 'wrong-chair', 'missing-axis', 'wrong-axis'):
            for kind in ('direction', 'current_gear'):
                with self.subTest(chain=chain, kind=kind):
                    h = Harness(self.after, kind, chain=chain)
                    self.assertEqual(h.observe('update')['trace'], [('parent', 'unchanged')])
                    self.assertEqual(h.screen.icon_state, 'unchanged')
            h = Harness(self.after, chain=chain)
            self.assertEqual(h.observe('click')['trace'], [])
            self.assertEqual(h.screen.icon_state, 'unchanged')

    def test_click_effects_occur_once_in_original_order_and_toggle_back(self):
        for reverse in (False, True):
            with self.subTest(reverse=reverse):
                h = Harness(self.after, reverse=reverse, engine=False, speed=0)
                for desired in (not reverse, reverse):
                    start = len(h.trace)
                    h.click()
                    state = 'reverse' if desired else 'forward'
                    self.assertEqual(h.trace[start:], [
                        ('chat', 'driver turf', 'You switch into ' + state + '.'),
                        ('sound', 'driver turf', 'sound/effects/lever.ogg', 65, True),
                        ('reverse', 'axis', desired), ('icon', state),
                        ('parent', state), ('icon', state)])
                    self.assertEqual(h.axis.reverse, desired)

    def test_gear_priority_engine_off_then_neutral_then_reverse_then_speed(self):
        for engine in (None, False, True):
            for speed in (-1, 0, 1, 3, 6):
                for reverse in (False, True):
                    h = Harness(self.after, 'current_gear', engine=engine, speed=speed, reverse=reverse)
                    expected = ('speed_off' if engine is False else 'speed_n' if speed == 0 else
                                'speed_r' if reverse else 'speed_' + str(speed))
                    self.assertEqual(h.observe('update')['trace'], [('parent', 'unchanged'), ('icon', expected)])

    def test_parent_update_precedes_axis_resolution(self):
        for kind in ('direction', 'current_gear'):
            h = Harness(self.after, kind, parent_effect=unbuckle_in_parent)
            self.assertEqual(h.observe('update')['trace'], [('parent', 'unchanged')])
            self.assertEqual(h.screen.icon_state, 'unchanged')
            h = Harness(self.after, kind, chain='unbuckled', parent_effect=rebind_in_parent)
            h.update()
            self.assertEqual(h.screen.icon_state, 'forward' if kind == 'direction' else 'speed_3')

    def test_click_keeps_admitted_axis_but_nested_update_resolves_current_axis(self):
        h = Harness(self.after, parent_effect=rebind_in_parent)
        h.click()
        self.assertTrue(h.axis.reverse)
        self.assertFalse(h.replacement.reverse)
        self.assertEqual(h.screen.icon_state, 'forward')
        self.assertEqual([event for event in h.trace if event[0] == 'reverse'], [('reverse', 'axis', True)])

    def test_resolver_is_read_only_and_does_not_cache_an_axis_or_add_human_gate(self):
        h = Harness(self.after)
        resolve = h.env['resolve_driver_axis']
        self.assertIs(resolve(), h.axis)  # Parent is an ordinary non-human fake mob.
        self.assertEqual(h.trace, [])
        rebind_in_parent(h)
        self.assertIs(resolve(), h.replacement)
        unbuckle_in_parent(h)
        self.assertIsNone(resolve())
        self.assertEqual(h.trace, [])
        self.assertEqual(h.screen.icon_state, 'unchanged')

    def test_wheel_handlers_and_process_delegation_are_unchanged(self):
        for kind in ('turn_left', 'turn_right', 'gear_down', 'gear_up'):
            declaration = BASE + '/' + kind + '/Click'
            body = extract(self.after, declaration)
            self.assertEqual(body, extract(self.before, declaration))
            self.assertIn('ishuman(parentmob)', body)
            self.assertNotIn('resolve_driver_axis', body)
        for kind in ('direction', 'current_gear'):
            declaration = BASE + '/' + kind + '/process'
            self.assertEqual(extract(self.after, declaration), extract(self.before, declaration))

    def test_negative_controls_detect_admission_effect_and_parent_order_regressions(self):
        chair_guard = '\tif (!istype(parentmob.buckled, ' + CHAIR + '))\n\t\treturn\n'
        axis_guard = '\tif (!this_chair.axis || !istype(this_chair.axis, ' + AXIS + '))\n\t\treturn\n'
        binding = '\tvar' + AXIS + '/this_axis = resolve_driver_axis()\n'
        sound = "\t\tplaysound(parentmob.loc, 'sound/effects/lever.ogg',65, TRUE)\n"
        replacements = [
            ('chair-type', chair_guard, ''), ('axis-type', axis_guard, ''),
            ('duplicate-sound', sound, sound + sound),
            ('invalid-icon-reset', binding, '\ticon_state = "forward"\n' + binding),
            ('parent-order', '\t..()\n' + binding, binding + '\t..()\n')]
        for name, original, changed in replacements:
            with self.subTest(mutation=name):
                self.assertIn(original, self.after)
                mutant = self.after.replace(original, changed, 1)
                with self.assertRaises(AssertionError):
                    self.assert_parity(mutant)


if __name__ == '__main__':
    unittest.main()
