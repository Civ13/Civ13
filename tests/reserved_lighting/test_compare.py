"""Receipt comparison checks, not production lighting evidence."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from compare import LABELS, compare


class SnapshotComparison(unittest.TestCase):
    def test_rejects_missing_rows_and_changed_channels_or_membership(self):
        states = [{'label': label, 'rows': [[i, 1, [1, 2, 3], ['source']] for i in range(250 if label == 'activated' else 220)]} for label in LABELS]
        with tempfile.TemporaryDirectory() as tmp:
            baseline, candidate = Path(tmp)/'baseline', Path(tmp)/'candidate'
            baseline.write_text('\n'.join(json.dumps(s) for s in states), encoding='utf-8')
            candidate.write_bytes(baseline.read_bytes())
            self.assertTrue(compare(baseline, candidate)['equal'])
            for mutation in ('row', 'channel', 'membership', 'label'):
                changed = copy.deepcopy(states)
                if mutation == 'row':
                    changed[-1]['rows'].pop()
                elif mutation == 'channel':
                    changed[0]['rows'][0][2][0] += 1
                elif mutation == 'membership':
                    changed[0]['rows'][0][3] = []
                else:
                    changed.pop()
                candidate.write_text('\n'.join(json.dumps(s) for s in changed), encoding='utf-8')
                with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                    compare(baseline, candidate)
