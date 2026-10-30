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
