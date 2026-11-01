"""Offline admission-prefix contracts. These do not execute DM or timers."""
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
BRANCH = 'code/game/objects/items/weapons/material/ooga_booga_weapons.dm'
ROCK = 'code/game/objects/structures/rocks.dm'
# Each slice starts at the owning proc or timed branch, before its first effect.
CASES = (
    ('code/game/objects/structures/wild.dm', '/obj/structure/wild/proc/gather_grass_cuttings(', 'var/turf/site', 'user'),
    ('code/game/turfs/floor_attackby.dm', '\tif (has_snow_cover() || busy', '\tbusy = TRUE', 'user'),
    (BRANCH, '\tif (H.a_intent == I_GRAB && leaves)', '\t\tto_chat', 'H'),
    (BRANCH, '\telse if (H.a_intent == I_HARM && !leaves && branched)', '\t\tto_chat', 'H'),
    (BRANCH, '/obj/item/weapon/branch/proc/assemble_flint_axe(', '\tif (assembling_axe', 'user'),
    (BRANCH, '\tif (ants)', '\t\tto_chat', 'user'),
    (BRANCH, '\tif (W.edge && !sharpened)', '\t\tto_chat', 'user'),
    (ROCK, '\tif (H.a_intent == I_GRAB)', '\t\tto_chat', 'H'),
    (ROCK, '/obj/item/weapon/flint/attackby(', '\t\tvisible_message', 'user'),
    ('code/game/objects/structures/repairing.dm', '/obj/structure/repair/attackby(', '\t\tvisible_message', 'user'),
)


def admission_guard(text, case):
    _, anchor, effect, actor = case
    start = text.index(anchor)
    # The floor has conditional signatures: its shared body begins after #endif.
    if anchor.startswith('\tif (has_snow_cover'):
        start = text.rfind('#endif', 0, start) + len('#endif')
    end = text.index(effect, start)
    prefix = text[start:end]
    guard = re.search(r'(?m)^(\t+)if \(([^\n]+)\)\n\1\treturn(?: FALSE)?\n', prefix)
    if not guard or guard[2] not in (f'!{actor}.may_do_after', f'!{actor} || !{actor}.may_do_after'):
        raise AssertionError(f'Busy refusal missing before first effect: {anchor}')
    # Execute only the production early-return expression with an inert actor.
    condition = guard[2].replace('||', 'or').replace('!', 'not ')
    namespace = {}
    exec(f'def admitted({actor}):\n    if {condition}:\n        return False\n    return True\n', namespace)
    return namespace['admitted'], guard[0]


class ActionAdmissionSources(unittest.TestCase):
    def test_busy_refuses_before_messages_claims_cooldown_and_waits(self):
        for case in CASES:
            with self.subTest(action=case[1]):
                admitted, _ = admission_guard((ROOT/case[0]).read_text(), case)
                actor = SimpleNamespace(may_do_after=False)
                self.assertFalse(admitted(actor))
                self.assertFalse(actor.may_do_after, 'Rejection released the original wait')
                actor.may_do_after = True
                self.assertTrue(admitted(actor), 'Idle action was suppressed')

    def test_direct_helpers_refuse_a_missing_actor(self):
        for case in (CASES[0], CASES[1], CASES[4]):
            admitted, _ = admission_guard((ROOT/case[0]).read_text(), case)
            self.assertFalse(admitted(None))

    def test_each_omitted_guard_is_detected(self):
        for case in CASES:
            with self.subTest(action=case[1]):
                text = (ROOT/case[0]).read_text()
                _, guard = admission_guard(text, case)
                start = text.index(case[1])
                if case[1].startswith('\tif (has_snow_cover'):
                    start = text.rfind('#endif', 0, start)
                at = text.index(guard, start)
                with self.assertRaisesRegex(AssertionError, 'Busy refusal missing'):
                    admission_guard(text[:at] + text[at+len(guard):], case)

    def test_late_grass_guard_is_detected(self):
        case = CASES[0]
        text = (ROOT/case[0]).read_text()
        _, guard = admission_guard(text, case)
        text = text.replace(guard, '', 1)
        at = text.index('\tvar/completed = grass_cutting_wait(user)', text.index(case[1]))
        with self.assertRaisesRegex(AssertionError, 'Busy refusal missing'):
            admission_guard(text[:at] + guard + text[at:], case)

    def test_prepared_native_case_is_wired_into_existing_isolated_runner(self):
        probe = (ROOT/'tests/animal_harvest/probe.dm').read_text()
        self.assertIn('#include "action_admission_probe.dm"', probe)
        self.assertIn('harvest_action_admission_regressions(site, U)', probe)
        fixture = (ROOT/'tests/animal_harvest/action_admission_probe.dm').read_text()
        self.assertIn('spawn(1)', fixture)
        self.assertIn('original.attackby(tool, U)', fixture)
        self.assertIn('original.sharpened && U.may_do_after && !other.sharpened', fixture)


if __name__ == '__main__':
    unittest.main()
