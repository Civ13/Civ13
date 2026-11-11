"""Offline source projection; does not execute BYOND or measure performance."""
import importlib.util
from itertools import product
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location('life_forms_adapter', ROOT / 'tests/save_movement/source_adapter.py')
A = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(A)
FLAGS = ('werewolf', 'gorillaman', 'orc', 'goblin', 'ant', 'lizard', 'wolfman', 'crab', 'droid')
A.FIELDS += FLAGS + ('body_build', 'handle_animalistic')


def production():
    text = (ROOT / 'code/game/mob/living/carbon/human/human_life.dm').read_text(encoding='utf-8')
    start = text.index('\tif (werewolf || gorillaman ||')
    end = text.index('//\tif (prone)', start)
    return '/life_forms()\n' + text[start:end]


def project(text):
    return A.project(text, '/life_forms', 'src', {}, method=True)


def run(proc, flags, build, callback_flags, reset_build):
    mob = SimpleNamespace(**dict(zip(FLAGS, flags)), body_build=SimpleNamespace(name=build))
    calls = []

    def handle(form):
        calls.append(form)
        # Model a callback that enables a form during the first reset call.
        if len(calls) == 1:
            if reset_build:
                mob.body_build.name = 'Default'
            for flag in callback_flags:
                setattr(mob, flag, True)

    mob.handle_animalistic = handle
    proc(mob)
    return calls, tuple(getattr(mob, flag) for flag in FLAGS), mob.body_build.name


class LifeFormChecks(unittest.TestCase):
    def test_no_second_round_of_form_flags(self):
        def assert_short_condition(text):
            self.assertIn('else if (body_build.name != "Default")', text)
            self.assertNotIn('else if (!gorillaman && !werewolf', text)
        assert_short_condition(production())
        with self.assertRaises(AssertionError):
            assert_short_condition((HERE / 'before.dm.txt').read_text(encoding='utf-8'))

    def test_original_equivalence_and_mutant(self):
        baseline = project((HERE / 'before.dm.txt').read_text(encoding='utf-8'))
        text = production()
        candidate = project(text)
        mutant_text = text.replace('else if (body_build.name != "Default")',
                                   'else if (body_build.name == "Default")', 1)
        self.assertNotEqual(mutant_text, text)
        mutant = project(mutant_text)
        started = (True,) + (False,) * (len(FLAGS) - 1)
        self.assertEqual(run(candidate, started, 'Other', ('orc', 'droid'), True)[0],
                         ['Default', 'Orc'])
        self.assertEqual(run(candidate, started, 'Other', (), False)[0],
                         ['Default', 'Default'])
        detected = False
        for flags in product((False, True), repeat=len(FLAGS)):
            for build in ('Default', 'Other'):
                for callback_flags, reset_build in (((), False), (('werewolf',), False),
                                                    (('droid',), False), (('orc', 'droid'), True),
                                                    ((), True)):
                    expected = run(baseline, flags, build, callback_flags, reset_build)
                    self.assertEqual(run(candidate, flags, build, callback_flags, reset_build), expected)
                    detected |= run(mutant, flags, build, callback_flags, reset_build) != expected
        self.assertTrue(detected, 'inverted default-form condition must be detected')


if __name__ == '__main__':
    unittest.main()
