"""Offline fixture boundaries only, not native matrix identity proof."""
from pathlib import Path
import unittest
HERE = Path(__file__).resolve().parent
SOURCE = (HERE / 'matrix_identity.dm').read_text()
class MatrixIdentitySourceTests(unittest.TestCase):
    def test_native_differential_and_guards(self):
        for fragment in ('baseline_cache["\\ref[M]"]', 'direct_cache[M]',
                         'baseline_pins[baseline_id] == M', 'direct_pins[direct_id] == M',
                         'baseline_pins += M', 'direct_pins += M',
                         'registration identity partition differs', 'stale_pin',
                         'holder.transform', 'missing_direct', 'retained.c != 13',
                         'equal_values_compare_equal', 'new_pass'):
            self.assertIn(fragment, SOURCE)
        for forbidden in ('/world/New', 'OpenPort(', 'sleep(', 'spawn(', 'fdel('):
            self.assertNotIn(forbidden, SOURCE)
    def test_hashed_and_explicitly_invoked(self):
        self.assertIn("'tests/movement_save_chunks/matrix_identity.dm'", (HERE/'prepare.py').read_text())
        self.assertIn('check_native_matrix_identity()', (HERE/'probe.dm').read_text())

    def test_actual_frame_guards_and_omission_control(self):
        for label in ('equal-source', 'wrong-key', 'wrong-pin', 'wrong-entry', 'inactive', 'deleted-source'):
            self.assertIn('"'+label+'"', SOURCE)
        self.assertIn('exporter.require_export_frame(frame)', SOURCE)
        self.assertIn('matrix identity still uses native reference strings', SOURCE)
        self.assertIn('frame.source_identity)', SOURCE)

    def test_matrix_capture_has_consistent_identity_and_movable_only_side_maps(self):
        root = HERE.parents[1]
        functions = (root/'code/modules/persistence/functions.dm').read_text()
        saving = (root/'code/modules/persistence/saving.dm').read_text()
        helper = functions.split('/map_storage/proc/save_entry_identity(datum/A)')[1].split('/map_storage/proc/require_export_frame')[0]
        self.assertIn('if(istype(A, /matrix)) return A', helper)
        self.assertIn('return "\\ref[A]"', helper)
        self.assertIn('save_entry_identity(frame.source) != frame.source_identity', functions)
        self.assertIn('var/identity = save_entry_identity(A)', saving)
        self.assertIn('var/ind = saving_references[identity]', saving)
        self.assertIn('saving_references[identity] = ref', saving)
        self.assertIn('frame.source_identity = identity', saving)
        self.assertIn('if(!moving_save_chunk && istype(A, /atom/movable) && moving_save_roots', saving)
        self.assertIn('if(durable_export && istype(A, /atom/movable)) durable_export.bind_entry', saving)
