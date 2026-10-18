"""Compare actual paired native snapshots; never simulate lighting behavior."""
import argparse
import json
from pathlib import Path

LABELS = ('torch', 'night', 'carried', 'moved', 'opacity', 'activated')


def read(path):
    states = [json.loads(line) for line in Path(path).read_text(encoding='utf-8').splitlines() if line.strip()]
    if tuple(state['label'] for state in states) != LABELS:
        raise ValueError('Missing, duplicate or reordered snapshot labels')
    for state in states:
        rows = state['rows']
        expected = 250 if state['label'] == 'activated' else 220
        if len(rows) != expected or len({(row[0], row[1]) for row in rows}) != expected:
            raise ValueError('Incomplete or duplicate snapshot coordinates')
    return states


def compare(baseline, candidate):
    left, right = read(baseline), read(candidate)
    for a, b in zip(left, right):
        if a != b:
            raise ValueError('Native snapshot mismatch: ' + a['label'])
    return {'snapshots': len(left), 'rows': sum(len(state['rows']) for state in left), 'equal': True}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('baseline', type=Path)
    parser.add_argument('candidate', type=Path)
    args = parser.parse_args()
    print(json.dumps(compare(args.baseline, args.candidate)))
