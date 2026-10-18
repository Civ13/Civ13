"""Receipt comparison checks, not production lighting evidence."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from compare import LABELS, compare, coordinates


class SnapshotComparison(unittest.TestCase):
    def test_rejects_missing_rows_and_changed_channels_or_membership(self):
        states = [{'label': label, 'rows': [[x, y, [1, 2, 3], ['source']] for x, y in sorted(coordinates(label))]} for label in LABELS]
        with tempfile.TemporaryDirectory() as tmp:
            baseline, candidate = Path(tmp)/'baseline', Path(tmp)/'candidate'
            baseline.write_text('\n'.join(json.dumps(s) for s in states), encoding='utf-8')
            candidate.write_bytes(baseline.read_bytes())
            self.assertTrue(compare(baseline, candidate)['equal'])
            reordered = copy.deepcopy(states)
            for state in reordered:
                state['rows'].reverse()
            candidate.write_text('\n'.join(json.dumps(s) for s in reordered), encoding='utf-8')
            self.assertTrue(compare(baseline, candidate)['equal'])
            for mutation in ('row', 'channel', 'membership', 'label', 'out-of-bounds', 'wrong-interior'):
                changed = copy.deepcopy(states)
                if mutation == 'row':
                    changed[-1]['rows'].pop()
                elif mutation == 'channel':
                    changed[0]['rows'][0][2][0] += 1
                elif mutation == 'membership':
                    changed[0]['rows'][0][3] = []
                elif mutation == 'label':
                    changed.pop()
                elif mutation == 'out-of-bounds':
                    changed[0]['rows'][0][0] = 17
                else:
                    changed[-1]['rows'][0][:2] = [11, 8]
                candidate.write_text('\n'.join(json.dumps(s) for s in changed), encoding='utf-8')
                with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                    compare(baseline, candidate)
            # Matching corruption in both files must never validate a wrong set.
            baseline.write_bytes(candidate.read_bytes())
            with self.assertRaises(ValueError):
                compare(baseline, candidate)
