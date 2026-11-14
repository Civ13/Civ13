"""Offline source contract for account scans; not native DM execution."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/extraction'


class AccountDirectoryTests(unittest.TestCase):
    def test_retirement_journal_is_excluded_from_each_account_scan(self):
        writer = (SOURCE / 'home_replica.dm').read_text()
        directory = re.search(r'J.root = "\[metadata.accounts.store.root\]([^/]+)/"', writer)[1]
        expected = {'_settlement', '_insurance', '_bot', '_mail', directory}
        counts = {'account_store.dm': 1, 'insurance.dm': 2,
                  'settlement.dm': 1, 'surface_loot.dm': 1}
        for filename, count in counts.items():
            with self.subTest(filename=filename):
                lines = (SOURCE / filename).read_text().splitlines()
                skips = [i for i, line in enumerate(lines)
                         if '"_settlement"' in line and 'continue' in line]
                self.assertEqual(count, len(skips))
                for index in skips:
                    # Exact reserved names, never a broad underscore-prefix bypass.
                    names = set(re.findall(r'"([^"\n]+)"', lines[index]))
                    self.assertEqual(expected, names)
                    self.assertNotIn('unknown_account', names)
                    self.assertNotIn('_unknown_journal', names)
                    following = '\n'.join(lines[index + 1:index + 4])
                    self.assertTrue('valid_owner(' in following or 'revisions[owner]' in following)


if __name__ == '__main__':
    unittest.main()
