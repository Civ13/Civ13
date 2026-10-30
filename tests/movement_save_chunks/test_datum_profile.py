"""Offline source contracts for opt-in copied-packet timing, not native proof."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SPEC = importlib.util.spec_from_file_location('datum_profile_tested', HERE / 'datum_profile.py')
profile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(profile)


class DatumProfileTests(unittest.TestCase):
    def test_existing_reference_calls_are_wrapped_once_without_new_checks_or_yields(self):
        for name, original, replacement in (
            ('code/modules/persistence/saving.dm', '"\\ref[A]"', 'profile_native_identity(A)'),
            ('code/modules/persistence/functions.dm', '"\\ref[frame.source]"', 'profile_native_identity(frame.source)'),
        ):
            source = (ROOT / name).read_text()
            instrumented = profile.instrument_datum_references(name, source)
            self.assertEqual(instrumented.count(replacement), source.count(original))
            self.assertNotIn(original, instrumented)
            for unchanged in ('sleep(', 'world.log', 'check()'):
                self.assertEqual(instrumented.count(unchanged), source.count(unchanged))
            self.assertEqual((ROOT / name).read_text(), source)
        self.assertIn('native_ref_type=[profile_native_ref_type]', profile.instrument_datum_references('code/modules/persistence/saving.dm', (ROOT / 'code/modules/persistence/saving.dm').read_text()))

    def test_saver_reference_count_drift_is_rejected(self):
        name = 'code/modules/persistence/saving.dm'
        source = (ROOT / name).read_text()
        self.assertEqual(source.count('"\\ref[A]"'), profile.EXPECTED_SAVER_REF_SITES)
        with self.assertRaisesRegex(ValueError, 'Native datum'):
            profile.instrument_datum_references(name, source.replace('"\\ref[A]"', '"changed"', 1))

    def test_changed_frame_anchor_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Frame source'):
            profile.instrument_datum_references('code/modules/persistence/functions.dm', 'no native frame reference')

if __name__ == '__main__': unittest.main()
