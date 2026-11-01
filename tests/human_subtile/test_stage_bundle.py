"""Source overlay reconstruction controls, using the actual local Git blobs."""
import copy
from pathlib import Path
import unittest
import build_guard
import source_binding
import stage_bundle


class BundleControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs = source_binding.read_inputs(['git', '-C', str(Path(__file__).resolve().parents[2])], source_binding.BASE)
        cls.guard = build_guard.OLD.read_bytes()
        cls.observer = Path(__file__).with_name('bump_fixture_observer.dm').read_bytes()
        cls.scenario = Path(__file__).with_name('bump_fixture_probe.dm').read_bytes()

    def build(self, inputs, candidate):
        return stage_bundle.reconstruct(inputs, self.guard, self.observer, self.scenario, candidate)

    def test_exact_baseline_and_candidate_overlays(self):
        old, new = self.build(self.inputs, False), self.build(self.inputs, True)
        self.assertEqual(set(old), set(new))
        self.assertNotEqual(old[stage_bundle.LIVING], new[stage_bundle.LIVING])
        self.assertNotEqual(old[stage_bundle.PROBE], new[stage_bundle.PROBE])
        self.assertEqual(old[stage_bundle.OBSERVER], new[stage_bundle.OBSERVER])
        self.assertEqual(old[stage_bundle.SCENARIO], new[stage_bundle.SCENARIO])
        self.assertIn(b'bump_fixture_observer.dm', old['human_subtile.dme'])
        self.assertIn(b'bump_fixture_probe.dm', old['human_subtile.dme'])

    def test_missing_or_changed_source_is_rejected(self):
        missing = copy.copy(self.inputs)
        del missing['civ13.dme']
        with self.assertRaises(ValueError):
            self.build(missing, False)
        changed = copy.copy(self.inputs)
        changed[stage_bundle.PROBE] += b'\n// unexpected'
        with self.assertRaises(ValueError):
            self.build(changed, True)
        with self.assertRaises(ValueError):
            stage_bundle.reconstruct(self.inputs, self.guard, self.observer + b'\n// unexpected', self.scenario, True)


if __name__ == '__main__':
    unittest.main()
