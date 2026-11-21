"""The staff account lookup (tools/transfer_storage/records.py account_summary,
shard_group.py accounts) reads points and slots the way the game does."""
import sqlite3
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.transfer_storage import records  # noqa: E402

NOW = 1_800_000_000


def rec(n, kind, body, at=NOW, ckey='ivy', author='ivy'):
    return {'id': '%032x' % n, 'ckey': ckey, 'kind': kind, 'author': author, 'rank': '', 'region': 'x', 'at': at, 'body': body}


class AccountSummary(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        records.init_group(self.db)

    def store(self, *rows):
        records.store_records(self.db, 'alpha', list(rows), NOW)

    def test_points_slots_and_names(self):
        self.store(
            rec(1, 'accolade', {'accolade': 'sailor', 'points': 10}),
            rec(2, 'accolade', {'accolade': 'sailor', 'points': 10, 'grant': 1}, author='staff'),  # pays once
            rec(3, 'accolade', {'accolade': 'scholar', 'points': 150}),
            rec(4, 'accolade_met', {'accolade': 'farmer'}),
            rec(5, 'character_slot', {'slot': 2, 'points': 100}),
            rec(6, 'character_switch', {'slot': 2, 'from': 1}, at=NOW + 10),
            rec(7, 'character_named', {'slot': 1, 'name': 'Ivy Stone'}),
            rec(8, 'character_named', {'slot': 2, 'name': 'Ash Stone'}),
        )
        account = records.account_summary(self.db, 'ivy')
        self.assertEqual((account['points'], account['spent'], account['balance']), (160, 100, 60))
        slots = {s['slot']: s for s in account['slots']}
        self.assertEqual(slots[2]['state'], 'open')
        self.assertTrue(slots[2]['played'])
        self.assertEqual(slots[1]['name'], 'Ivy Stone')
        self.assertEqual(slots[3]['state'], 'not bought (200 points)')
        self.assertIn('1 ready to claim', account['text'])
        # The ckey lookup in the Player records window shows the same summary.
        self.assertIn('Lifetime points: 160 earned, 100 spent, 60 to spend.', records.report(self.db, NOW, ckey='ivy')['text'])

    def test_a_locked_slot_keeps_its_points_spent(self):
        self.store(rec(1, 'accolade', {'accolade': 'scholar', 'points': 150}),
                   rec(2, 'character_slot', {'slot': 2, 'points': 100}),
                   rec(3, 'revoke', {'target': '%032x' % 2, 'target_kind': 'character_slot'}, author='staff'))
        account = records.account_summary(self.db, 'ivy')
        self.assertEqual(account['balance'], 50)
        self.assertEqual(account['slots'][1]['state'], 'locked by staff')

    def test_shard_group_has_the_accounts_action(self):
        source = (ROOT / 'scripts/shard-group/shard_group.py').read_text()
        self.assertIn("'records', 'accounts', 'add-regions')", source)
        self.assertIn("result = group_account(group, args.ckey)", source)
        self.assertIn("mode=ro", source[source.index('def group_account'):source.index('def group_records')])


if __name__ == '__main__':
    unittest.main()
