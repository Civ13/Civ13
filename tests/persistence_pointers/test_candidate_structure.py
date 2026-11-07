"""Offline contracts for the stream-save candidate check. Never launches BYOND.

A pin the garbage collector force-deleted after capture is null; the in-memory
candidate check (record_candidate_level_structure) must pass it, as the file
read-back did, and must still refuse an entry that is not a placeable datum.
The native cases are tests/persistence_pointers/candidate_structure/run.py.
"""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from inventory import ROOT
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract

SAVING = 'code/modules/persistence/saving.dm'
_spec = importlib.util.spec_from_file_location('candidate_structure_runner', HERE / 'candidate_structure/run.py')
RUNNER = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(RUNNER)


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


class CandidateStructureContracts(unittest.TestCase):
    def test_null_pins_are_skipped_before_the_entry_type_check(self):
        body = extract(read(SAVING), '/map_storage/proc/record_candidate_level_structure')
        self.assertLess(body.index('if(isnull(A))'), body.index('Unsupported saved entry'))
        self.assertIn('if(!isnull(child_entry) && !istype(child_entry, /atom/movable))', body)

    def test_native_packet_stages_unchanged_production_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            receipt = RUNNER.prepare(output)
            for path in RUNNER.CROSS.PRODUCTION:
                self.assertEqual((output / Path(path).name).read_text(), read(path))
            self.assertIn('#include "candidate_structure_probe.dm"', (output / 'probe.dme').read_text())
            self.assertFalse((output / 'cross_level_probe.dm').exists())
            self.assertFalse(receipt['native_verified'])

    def test_control_mutates_only_the_null_pin_guard(self):
        for control, (name, before, after, case, minimum, expected) in RUNNER.CONTROLS.items():
            with self.subTest(control=control), tempfile.TemporaryDirectory() as directory:
                output = Path(directory)
                RUNNER.prepare(output, control)
                staged = (output / name).read_text()
                self.assertNotIn(before, staged)
                self.assertEqual(staged.count(after), 1)
                self.assertIn(case, RUNNER.CASES)


if __name__ == '__main__':
    unittest.main()
