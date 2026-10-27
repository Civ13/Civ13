import unittest
from check_map import ROOT, MAP, validate
from compile_map import accepted


class ArtOfTheDealMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (ROOT / MAP).read_text(encoding='utf-8')

    def test_complete_authored_map(self):
        self.assertEqual(validate(self.source)['cells'], 96800)

    def test_conflict_marker_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'conflict marker'):
            validate('<<<<<<< historical-merge\n' + self.source)

    def test_crash_trigger_is_rejected_before_native_compilation(self):
        changed = self.source.replace('speedlist = list(', 'speedlist = alist(', 1)
        self.assertNotEqual(changed, self.source)
        with self.assertRaisesRegex(ValueError, 'alist initializer'):
            validate(changed)

    def test_duplicate_definition_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'duplicate palette key'):
            validate(self.source.splitlines()[0] + '\n' + self.source)

    def test_undefined_grid_key_is_rejected(self):
        self.assertNotIn('"zzz" =', self.source)
        head, grid = self.source.split('(1,1,1) = {"\n', 1)
        with self.assertRaisesRegex(ValueError, 'undefined grid key'):
            validate(head + '(1,1,1) = {"\nzzz' + grid[3:])

    def test_incomplete_row_is_rejected(self):
        head, grid = self.source.split('(1,1,1) = {"\n', 1)
        with self.assertRaisesRegex(ValueError, '220 by 220'):
            validate(head + '(1,1,1) = {"\n' + grid[3:])

    def test_legacy_vendor_path_is_rejected(self):
        changed = self.source.replace('/mob/living/simple_animal/npc_vendor/cartel', '/obj/structure/npc_vendor/cartel')
        with self.assertRaisesRegex(ValueError, 'migrated mob type'):
            validate(changed)

    def test_obsolete_ambience_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'obsolete forced_ambience'):
            validate(self.source.replace('ambience = list(', 'forced_ambience = list(', 1))

    def test_native_crash_after_zero_summary_is_not_accepted(self):
        log = 'DM compiler version 516.1688\nmap.dmb - 0 errors, 0 warnings\n'
        self.assertTrue(accepted(log, 0, '516.1688', True))
        for code in (3221226356, 3221225477, -1073741819):
            with self.subTest(code=code):
                self.assertFalse(accepted(log, code, '516.1688', True))

    def test_missing_artifact_and_wrong_compiler_are_not_accepted(self):
        log = 'DM compiler version 516.1688\nmap.dmb - 0 errors, 0 warnings\n'
        self.assertFalse(accepted(log, 0, '516.1688', False))
        self.assertFalse(accepted(log, 0, '516.1681', True))


if __name__ == '__main__':
    unittest.main()
