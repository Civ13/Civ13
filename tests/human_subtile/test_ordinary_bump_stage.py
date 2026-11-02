"""Offline exact-source staging controls; does not launch BYOND."""
import unittest
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('ordinary_bump_stage', ROOT / 'ordinary_bump_stage.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)


class StagingControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = (ROOT / 'ordinary_inputs/living-base.dm').read_bytes()
        cls.new = (ROOT / 'ordinary_inputs/living-current.dm').read_bytes()
        cls.probe = (ROOT / 'ordinary_inputs/probe-current.dm').read_bytes()
        cls.dme = (ROOT / 'ordinary_inputs/civ13-current.dme').read_bytes()
        cls.fixture = (ROOT / 'ordinary_bump_probe.dm').read_bytes()

    def build(self, candidate):
        return stage.reconstruct(self.new if candidate else self.old, self.probe, self.dme, self.fixture, candidate)

    def test_both_exact_modes_and_named_legs(self):
        old, new = self.build(False), self.build(True)
        self.assertEqual(set(old), set(new))
        self.assertEqual(old['tests/human_subtile/probe.dm'], new['tests/human_subtile/probe.dm'])
        self.assertEqual(old['human_subtile.dme'], new['human_subtile.dme'])
        for row in (old, new):
            living = row['code/game/mob/living/living.dm']
            for name in (b'first_leg_before', b'first_leg_after', b'second_leg_before', b'second_leg_after'):
                self.assertEqual(living.count(name), 2)
            self.assertNotIn(b'.dmm"', row['human_subtile.dme'])
            self.assertIn(b'ordinary_bump_run()', row['tests/human_subtile/probe.dm'])
            self.assertIn(b'ordinary_bump_partial', row['tests/human_subtile/probe.dm'])
        self.assertNotIn(b'ordinary_bump_trace_leg("veto"', old['code/game/mob/living/living.dm'])
        self.assertEqual(new['code/game/mob/living/living.dm'].count(b'ordinary_bump_trace_leg("veto"'), 1)

    def test_instrumentation_removes_to_exact_original_bytes(self):
        for candidate, original in ((False, self.old), (True, self.new)):
            text = self.build(candidate)['code/game/mob/living/living.dm'].decode()
            lines = [line for line in text.splitlines(keepends=True) if 'ordinary_bump_trace_leg(' not in line]
            self.assertEqual(''.join(lines).encode(), original)

    def test_wrong_source_fixture_and_mode_fail_closed(self):
        good = (self.new, self.probe, self.dme, self.fixture, True)
        for i in range(4):
            bad = list(good)
            bad[i] += b'X'
            with self.subTest(part=i), self.assertRaises(ValueError):
                stage.reconstruct(*bad)
        with self.assertRaises(ValueError):
            stage.reconstruct(self.old, self.probe, self.dme, self.fixture, True)
        with self.assertRaises(ValueError):
            stage.reconstruct(self.new, self.probe, self.dme, self.fixture, 1)

    def test_missing_or_duplicated_production_leg_is_rejected(self):
        old = self.old.decode()
        fragment = '\t\t\t\t\t\ttmob.forceMove(oldloc)\n'
        self.assertEqual(old.count(fragment), 1)
        for altered in (old.replace(fragment, '', 1), old.replace(fragment, fragment * 2, 1)):
            with self.subTest(count=altered.count(fragment)), self.assertRaises(ValueError):
                stage.instrument(altered.encode(), False)

    def test_fixture_declares_default_and_explicit_reverse_control(self):
        text = self.fixture.decode()
        for case in ('human_idle', 'goat_idle_default', 'goat_idle_permitted', 'goat_active_permitted'):
            self.assertIn('"' + case + '"', text)
        self.assertIn('A.mob_swap_flags |= HUMAN', text)
        self.assertIn('H.human_subtile_transaction == ordinary_bump_admission', text)
        self.assertIn('H.fixture_rows.Copy()', text)
        self.assertIn('ordinary_bump_event("post_deferred"', text)
        self.assertIn('ordinary_bump_callbacks >= 1', text)


if __name__ == '__main__':
    unittest.main()