"""Execute the shared DM touch guard with fake adjacency/chat boundaries.

This is offline source-flow evidence, not native interaction acceptance.
"""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('touch_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/game/objects/objs.dm').read_text()
HELPER = '/obj/proc/can_physically_interact'
WRAPPERS = (
    ('code/game/objects/structures.dm', '/obj/structure/proc/can_touch'),
    ('code/modules/1713/weapons/guns/mg/_stationary.dm',
     '/obj/item/weapon/gun/projectile/automatic/stationary/proc/can_touch'),
)


def user(**overrides):
    state = dict(buckled=False, stat=0, paralysis=0, sleeping=0, lying=False,
                 weakened=0, restrained=lambda: False)
    state.update(overrides)
    return SimpleNamespace(**state)


class PhysicalInteractionTests(unittest.TestCase):
    def setUp(self):
        self.adjacent = True
        self.events = []
        def adjacency(actor):
            self.events.append('adjacency')
            return self.adjacent
        env = {'Adjacent': adjacency, 'SPAN_NOTICE': lambda text: text,
               'to_chat': lambda actor, text: self.events.append(('message', text))}
        self.check = adapter.project(SOURCE, HELPER, 'user', env)

    def test_null_user_does_not_query_adjacency(self):
        self.assertFalse(self.check(None))
        self.assertEqual(self.events, [])

    def test_nonadjacent_user_rejected_before_restraint_feedback(self):
        self.adjacent = False
        self.assertFalse(self.check(user(restrained=lambda: True)))
        self.assertEqual(self.events, ['adjacency'])

    def test_restrained_or_buckled_user_gets_exact_feedback(self):
        for state in ({'restrained': lambda: True}, {'buckled': object()},
                      {'restrained': lambda: True, 'buckled': object(), 'stat': 2}):
            with self.subTest(state=state):
                self.events.clear()
                self.assertFalse(self.check(user(**state)))
                self.assertEqual(self.events, ['adjacency',
                    ('message', 'You need your hands and legs free for this.')])

    def test_every_incapacitation_flag_silently_rejects(self):
        for flag in ('stat', 'paralysis', 'sleeping', 'lying', 'weakened'):
            for value in (1, 2):
                with self.subTest(flag=flag, value=value):
                    self.events.clear()
                    self.assertFalse(self.check(user(**{flag: value})))
                    self.assertEqual(self.events, ['adjacency'])

    def test_valid_user_is_admitted_without_feedback(self):
        self.assertTrue(self.check(user()))
        self.assertEqual(self.events, ['adjacency'])

    def test_both_existing_wrappers_return_shared_result_unchanged(self):
        for path, declaration in WRAPPERS:
            source = (ROOT / path).read_text()
            body = adapter.extract(source, declaration).strip()
            self.assertEqual(body, 'return can_physically_interact(user)')
            for result in (False, True):
                calls = []
                def helper(actor):
                    calls.append(actor)
                    return result
                wrapper = adapter.project(source, declaration, 'user',
                                          {'can_physically_interact': helper})
                actor = user()
                self.assertEqual(wrapper(actor), result)
                self.assertEqual(calls, [actor])

    def test_removed_lying_gate_negative_control_is_detectable(self):
        mutant = SOURCE.replace(' || user.lying', '', 1)
        self.assertNotEqual(mutant, SOURCE)
        check = adapter.project(mutant, HELPER, 'user', {'Adjacent': lambda actor: True})
        self.assertTrue(check(user(lying=True)))
        self.assertFalse(self.check(user(lying=True)))


if __name__ == '__main__':
    unittest.main()
