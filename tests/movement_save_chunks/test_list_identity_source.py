"""Offline source checks only; native identity assertions require real BYOND."""
from pathlib import Path
import unittest

SOURCE = Path(__file__).with_name('list_identity.dm').read_text()


class NativeIdentitySourceTests(unittest.TestCase):
    def test_explicit_entry_no_automatic_runtime_or_unbounded_work(self):
        self.assertIn('/proc/check_native_list_identity()', SOURCE)
        self.assertIn('\treturn TRUE', SOURCE)
        for forbidden in ('/world/New', 'sleep(', 'spawn(', 'OpenPort(', 'while(', 'world.params'):
            self.assertNotIn(forbidden, SOURCE)
        self.assertIn('i <= 32', SOURCE)
        self.assertIn('i <= 7', SOURCE)

    def test_direct_native_key_queries_not_reference_strings(self):
        self.assertNotIn('\\ref[', SOURCE)
        for key, number in [('empty_a', 1), ('empty_b', 2), ('equal_a', 3), ('equal_b', 4), ('self_cycle', 5), ('cycle_a', 6), ('cycle_b', 7)]:
            self.assertIn(f'identity_map[{key}] = {number}', SOURCE)
            self.assertIn(f'identity_map[{key}] != {number}', SOURCE)
        self.assertIn('identity_map[alias_a] != 3', SOURCE)
        self.assertIn('identity_map[retained] != i', SOURCE)

    def test_native_atom_lists_and_cleanup_are_asserted(self):
        for name, number in [('overlays', 8), ('underlays', 9), ('filters', 10)]:
            self.assertIn(f'identity_map[native_holder.{name}] != {number}', SOURCE)
            self.assertIn(f'pins[{number}] != native_holder.{name}', SOURCE)
            self.assertIn(f'native_holder.{name} +=', SOURCE)
        self.assertIn('isnull(missing_id)', SOURCE)
        self.assertIn('identity_map.Find(null)', SOURCE)
        self.assertNotIn('identity_map[null] =', SOURCE)
        self.assertIn('identity_map.Cut()', SOURCE)
        self.assertIn('pins-only retained list lost its contents', SOURCE)
        self.assertIn('j <= 16', SOURCE)
        self.assertIn('pins.Cut()', SOURCE)
        self.assertIn('next-pass ID restart failed', SOURCE)
        self.assertIn('del(native_holder)', SOURCE)


if __name__ == '__main__':
    unittest.main()
