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
        self.assertNotIn('\\ref[', SOURCE.split('/proc/check_native_list_handle_observation')[0])
        for key, number in [('empty_a', 1), ('empty_b', 2), ('equal_a', 3), ('equal_b', 4), ('self_cycle', 5), ('cycle_a', 6), ('cycle_b', 7)]:
            self.assertIn(f'identity_map[{key}] = {number}', SOURCE)
            self.assertIn(f'identity_map[{key}] != {number}', SOURCE)
        self.assertIn('identity_map[alias_a] != 3', SOURCE)
        self.assertIn('identity_map[retained] != i', SOURCE)

    def test_native_atom_lists_and_cleanup_are_asserted(self):
        for name in ('overlays', 'underlays', 'filters'):
            self.assertIn(f'check_native_list_handle_observation("{name}", native_{name}, native_holder.{name}', SOURCE)
            self.assertIn(f'native_holder.{name} +=', SOURCE)
            for prefix in ('held_', 'get_', 'alias_', 'mutated_held_', 'mutated_get_'):
                self.assertIn(f'check_native_list_registration("{prefix}{name}"', SOURCE)
        self.assertIn('cache[held] != expected_id || pins[expected_id] != held', SOURCE)
        self.assertNotIn('native-list repeated getter/key/pin mismatch', SOURCE)
        self.assertIn('isnull(missing_id)', SOURCE)
        self.assertIn('identity_map.Find(null)', SOURCE)
        self.assertNotIn('identity_map[null] =', SOURCE)
        self.assertIn('identity_map.Cut()', SOURCE)
        self.assertIn('pins-only retained list lost its contents', SOURCE)
        self.assertIn('j <= 16', SOURCE)
        self.assertIn('pins.Cut()', SOURCE)
        self.assertIn('next-pass ID restart failed', SOURCE)
        self.assertIn('del(native_holder)', SOURCE)

    def test_differential_registration_preserves_guard_and_insertion_order(self):
        helper = SOURCE.split('/proc/check_native_list_registration(')[1]
        for prefix, key in [('baseline', '"\\ref[L]"'), ('direct', 'L')]:
            lookup = f'var/{prefix}_id = {prefix}_cache[{key}]'
            guard = f'if(!{prefix}_id || {prefix}_pins[{prefix}_id] != L)'
            allocate = f'{prefix}_id = {prefix}_pins.len + 1'
            pin = f'{prefix}_pins += list(L)'
            insert = f'{prefix}_cache[{key}] = {prefix}_id'
            offsets = [helper.index(line) for line in (lookup, guard, allocate, pin, insert)]
            self.assertEqual(offsets, sorted(offsets))
        self.assertIn('baseline_id != direct_id', helper)
        self.assertIn('baseline_pins[i] != direct_pins[i]', helper)
        self.assertIn('LIST_HANDLE_OBSERVATION', SOURCE)
        self.assertIn('LIST_REGISTRATION_OBSERVATION', SOURCE)


if __name__ == '__main__':
    unittest.main()
