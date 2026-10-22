"""Receipt comparison checks, not production lighting evidence."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from compare import ALL_CELLS, LABELS, STILL_OMITTED, compare, coordinates


def fixture_states():
    # Comparator tests only. These numbers are not production lighting output.
    return [{'label': label,
             'rows': [[x, y, [1, 2, 3], ['source']]
                      for x, y in sorted(coordinates(label))],
             'lumcounts': [[x, y, 0.2, 0.0] for x, y in sorted(ALL_CELLS)]}
            for label in LABELS]


def write_states(path, states):
    path.write_text('\n'.join(json.dumps(state) for state in states), encoding='utf-8')


class SnapshotComparison(unittest.TestCase):
    def test_rejects_missing_rows_and_changed_channels_or_membership(self):
        states = fixture_states()
        with tempfile.TemporaryDirectory() as tmp:
            baseline, candidate = Path(tmp)/'baseline', Path(tmp)/'candidate'
            baseline.write_text('\n'.join(json.dumps(s) for s in states), encoding='utf-8')
            candidate.write_bytes(baseline.read_bytes())
            self.assertTrue(compare(baseline, candidate)['equal'])
            reordered = copy.deepcopy(states)
            for state in reordered:
                state['rows'].reverse()
                state['lumcounts'].reverse()
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

    def test_each_still_omitted_cell_in_each_state_rejects_old_fallback(self):
        states = fixture_states()
        with tempfile.TemporaryDirectory() as tmp:
            baseline, candidate = Path(tmp)/'baseline', Path(tmp)/'candidate'
            write_states(baseline, states)
            write_states(candidate, states)
            result = compare(baseline, candidate)
            self.assertEqual(result['rows'], 1350)
            self.assertEqual(result['lumcount_rows'], 1536)
            self.assertEqual(result['still_omitted_lumcount_rows'], 36)
            self.assertEqual(ALL_CELLS - coordinates('activated'), STILL_OMITTED)
            for index, state in enumerate(states):
                for cell in sorted(STILL_OMITTED):
                    for channel in (2, 3):
                        changed = copy.deepcopy(states)
                        row = next(row for row in changed[index]['lumcounts']
                                   if tuple(row[:2]) == cell)
                        row[channel] = 0.5
                        write_states(candidate, changed)
                        with self.subTest(label=state['label'], cell=cell, channel=channel):
                            with self.assertRaisesRegex(ValueError, 'Native lumcount mismatch:'):
                                compare(baseline, candidate)

    def test_requires_all_cells_even_for_matching_corrupt_receipts(self):
        with tempfile.TemporaryDirectory() as tmp:
            baseline, candidate = Path(tmp)/'baseline', Path(tmp)/'candidate'
            for mutation in ('missing-field', 'null-field', 'object-row', 'missing-cell', 'duplicate', 'outside',
                             'bool-coordinate', 'missing-channel', 'nan', 'infinity',
                             'out-of-range', 'bool-value'):
                states = fixture_states()
                rows = states[-1]['lumcounts']
                if mutation == 'missing-field':
                    del states[-1]['lumcounts']
                elif mutation == 'null-field':
                    states[-1]['lumcounts'] = None
                elif mutation == 'object-row':
                    rows[0] = {'x': 1, 'y': 1, 'default': 0.2, 'scaled': 0.0}
                elif mutation == 'missing-cell':
                    rows.pop()
                elif mutation == 'duplicate':
                    rows[-1] = rows[0].copy()
                elif mutation == 'outside':
                    rows[-1][0] = 17
                elif mutation == 'bool-coordinate':
                    rows[0][0] = True
                elif mutation == 'missing-channel':
                    rows[0].pop()
                elif mutation == 'nan':
                    rows[0][2] = float('nan')
                elif mutation == 'infinity':
                    rows[0][2] = float('inf')
                elif mutation == 'out-of-range':
                    rows[0][2] = 1.01
                else:
                    rows[0][2] = True
                write_states(baseline, states)
                candidate.write_bytes(baseline.read_bytes())
                with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                    compare(baseline, candidate)
