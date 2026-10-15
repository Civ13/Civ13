import copy
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('player_migration', Path(__file__).with_name('build-player-migration.py'))
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)


class PlayerMigrationSelection(unittest.TestCase):
    def setUp(self):
        value = lambda v: {'kind': 'value', 'value': v}
        self.row = {'z': 2, 'entry': '13', 'position': [4, 5, 2], 'serialized_snapshot': 'exact-native-encoding',
                    'snapshot': {'fields': {'type': '/mob/living/human', 'name': value('Current'), 'lastKnownCkey': value('account')},
                                 'contents': [{'fields': {'type': '/obj/item/weapon/flint', 'name': value('flint')}}]}}
        self.report = {'validated': 1, 'humans': [self.row]}
        self.observation = {'humans': [{'client': 1, 'name': 'Current', 'stat': 0, 'x': 4, 'y': 5, 'z': 2,
                                       'inventory': [{'type': '/obj/item/weapon/flint', 'name': 'flint'}]}]}

    def test_unique_inventory_match_with_same_account_alternative(self):
        old = copy.deepcopy(self.row)
        old['entry'] = '99'
        old['snapshot']['contents'] = []
        self.report['humans'].append(old)
        self.assertIs(migration.select_body(self.report, self.observation, 'account'), self.row)

    def test_duplicate_full_observed_match_rejected(self):
        duplicate = copy.deepcopy(self.row)
        duplicate['entry'] = '99'
        self.report['humans'].append(duplicate)
        with self.assertRaisesRegex(ValueError, '2 matches'):
            migration.select_body(self.report, self.observation, 'account')

    def test_account_or_inventory_mismatch_rejected(self):
        with self.assertRaisesRegex(ValueError, '0 matches'):
            migration.select_body(self.report, self.observation, 'otheraccount')
        self.observation['humans'][0]['inventory'] = []
        with self.assertRaisesRegex(ValueError, '0 matches'):
            migration.select_body(self.report, self.observation, 'account')

    def test_invalid_census_or_missing_exact_fingerprint_rejected(self):
        self.report['validated'] = 0
        with self.assertRaisesRegex(ValueError, 'not production-validator'):
            migration.select_body(self.report, self.observation, 'account')
        self.report['validated'] = 1
        del self.row['serialized_snapshot']
        with self.assertRaisesRegex(ValueError, 'snapshot missing'):
            migration.select_body(self.report, self.observation, 'account')


if __name__ == '__main__':
    unittest.main()
