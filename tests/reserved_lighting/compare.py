"""Compare actual paired native snapshots; never simulate lighting behavior."""
import argparse
import json
import math
from pathlib import Path

LABELS = ('torch', 'night', 'carried', 'moved', 'opacity', 'activated')
ACTIVATED = frozenset((int(x), int(y)) for x, y in (
    part.split(',') for part in
    '6,6 6,7 6,8 6,9 6,10 6,11 7,6 7,7 7,8 7,9 7,10 7,11 '
    '8,6 8,7 8,8 8,9 8,10 8,11 9,7 9,8 9,9 9,10 9,11 '
    '10,8 10,9 10,10 10,11 11,9 11,10 11,11'.split()))
NORMAL = frozenset((x, y) for x in range(1, 17) for y in range(1, 17)
                   if not (6 <= x <= 11 and 6 <= y <= 11))
ALL_CELLS = frozenset((x, y) for x in range(1, 17) for y in range(1, 17))
STILL_OMITTED = frozenset(((9, 6), (10, 6), (10, 7), (11, 6), (11, 7), (11, 8)))


def coordinates(label):
    return NORMAL | ACTIVATED if label == 'activated' else NORMAL


def read(path):
    states = [json.loads(line) for line in Path(path).read_text(encoding='utf-8').splitlines() if line.strip()]
    if tuple(state['label'] for state in states) != LABELS:
        raise ValueError('Missing, duplicate or reordered snapshot labels')
    for state in states:
        rows = state['rows']
        expected = coordinates(state['label'])
        if (any(type(row[0]) is not int or type(row[1]) is not int for row in rows)
                or len(rows) != len(expected)
                or {(row[0], row[1]) for row in rows} != expected):
            raise ValueError('Incorrect, missing or duplicate snapshot coordinates')
        # Creation order is not a lighting contract. Preserve all nested corner,
        # master and source ordering, while comparing the exact turf set.
        state['rows'] = sorted(rows, key=lambda row: (row[0], row[1]))
        lumcounts = state.get('lumcounts', [])
        if (type(lumcounts) is not list or len(lumcounts) != len(ALL_CELLS)
                or any(type(row) is not list or len(row) != 4
                       or type(row[0]) is not int or type(row[1]) is not int
                       or any(type(value) not in (int, float) or not math.isfinite(value)
                              or not 0 <= value <= 1 for value in row[2:])
                       for row in lumcounts)
                or {(row[0], row[1]) for row in lumcounts} != ALL_CELLS):
            raise ValueError('Incorrect, missing or duplicate lumcount coordinates/values')
        state['lumcounts'] = sorted(lumcounts, key=lambda row: (row[0], row[1]))
    return states


def compare(baseline, candidate):
    left, right = read(baseline), read(candidate)
    for a, b in zip(left, right):
        if a['rows'] != b['rows']:
            raise ValueError('Native snapshot mismatch: ' + a['label'])
        if a['lumcounts'] != b['lumcounts']:
            raise ValueError('Native lumcount mismatch: ' + a['label'])
        if a != b:
            raise ValueError('Native snapshot mismatch: ' + a['label'])
    return {'snapshots': len(left), 'rows': sum(len(state['rows']) for state in left),
            'lumcount_rows': sum(len(state['lumcounts']) for state in left),
            'still_omitted_lumcount_rows': len(STILL_OMITTED) * len(left), 'equal': True}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('baseline', type=Path)
    parser.add_argument('candidate', type=Path)
    args = parser.parse_args()
    print(json.dumps(compare(args.baseline, args.candidate)))
