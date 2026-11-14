"""Source-contract checks, not native DM runtime or sorttext parity tests."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def duration_contract(source):
    body = source.split('/proc/roundduration2text_days()', 1)[1].split('//Returns', 1)[0]
    assert re.search(r'var/days = round\(hours\s*/\s*24\)', body)
    assert re.search(r'hours -= days\s*\*\s*24', body)
    assert body.index('var/days') < body.index('hours -=')
    assert re.search(r'if \(days >= 1\)', body)


def sort_contract(source):
    body = source.split('/proc/mergeAtoms(', 1)[1].split('//Mergesort:', 1)[0]
    assert 'if (rL.name && rR.name)' not in body
    assert 'sorttext("[rL.name]", "[rR.name]")' in body
    assert 'result += L[Li++]' in body
    assert 'result += R[Ri++]' in body


class HelperContracts(unittest.TestCase):
    def test_duration_contract(self):
        duration_contract((ROOT / 'code/_helpers/time.dm').read_text())

    def test_duration_old_and_incomplete_fix_rejected(self):
        source = (ROOT / 'code/_helpers/time.dm').read_text()
        with self.assertRaises(AssertionError):
            duration_contract(source.replace('if (days >= 1)', 'if (hours >=1 && days >= 1)'))
        with self.assertRaises(AssertionError):
            duration_contract(source.replace('hours -= days * 24', 'hours %= 24'))

    def test_sort_progress_contract(self):
        sort_contract((ROOT / 'code/_helpers/lists.dm').read_text())

    def test_sort_old_gate_rejected(self):
        source = (ROOT / 'code/_helpers/lists.dm').read_text()
        with self.assertRaises(AssertionError):
            sort_contract(source.replace('if (sorttext("[rL.name]", "[rR.name]")',
                                         'if (rL.name && rR.name)\n\t\t\t\tif (sorttext("[rL.name]", "[rR.name]")'))

if __name__ == '__main__':
    unittest.main()
