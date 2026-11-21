"""Regenerate the registry fixtures: python3 tests/mine_floor_registry/make_fixtures.py

valid.json is a schema 1 registry with its records deliberately out of canonical order.
negative.json lists registries the validator must refuse, each with the reason it must give.
The probe (probe.dm) reads both through the production decoder.
"""
import copy, json
from pathlib import Path

HERE = Path(__file__).resolve().parent / 'fixtures'

VALID = {
    'schema': 1,
    'lineage': 'gaia-probe_1',
    'generation': 7,
    'next_mine_id': 4,
    'limits': {'mines': 8, 'depth': 4, 'floors': 8, 'side': 64, 'border': 2},
    'mines': [
        {'id': 3, 'deepest': 1, 'created': 6},
        {'id': 1, 'deepest': 2, 'created': 2},
        {'id': 2, 'deepest': 0, 'created': 5},
    ],
    'floors': [
        {'mine': 3, 'depth': 1, 'width': 20, 'height': 10, 'generator': 1, 'seed': 99, 'created': 6},
        {'mine': 1, 'depth': 2, 'width': 32, 'height': 32, 'generator': 1, 'seed': 16777215, 'created': 4},
        {'mine': 1, 'depth': 1, 'width': 32, 'height': 32, 'generator': 1, 'seed': 0, 'created': 2},
    ],
    'placements': [
        {'mine': 1, 'depth': 1, 'z': 3, 'x1': 1, 'y1': 1, 'x2': 36, 'y2': 36, 'border': 2, 'generation': 1},
        {'mine': 3, 'depth': 1, 'z': 3, 'x1': 37, 'y1': 1, 'x2': 58, 'y2': 12, 'border': 1, 'generation': 3},
        {'mine': 1, 'depth': 2, 'z': 4, 'x1': 65, 'y1': 65, 'x2': 100, 'y2': 100, 'border': 2, 'generation': 1},
    ],
}


def case(name, expect, mutate):
    data = copy.deepcopy(VALID)
    result = mutate(data)
    return {'name': name, 'expect': expect, 'registry': data if result is None else result}


def floor(data, mine, depth):
    return next(f for f in data['floors'] if f['mine'] == mine and f['depth'] == depth)


def placement(data, mine, depth):
    return next(p for p in data['placements'] if p['mine'] == mine and p['depth'] == depth)


def drop(data, key, mine, depth):
    data[key] = [r for r in data[key] if not (r['mine'] == mine and r['depth'] == depth)]


def remove_key(d, k):
    del d[k]


NEGATIVE = [
    case('newer schema', 'unsupported registry schema 2', lambda d: d.update(schema=2)),
    case('no schema', 'registry has no schema version', lambda d: remove_key(d, 'schema')),
    case('array registry', 'registry has no schema version', lambda d: [1]),
    case('other world', 'registry belongs to another world', lambda d: d.update(lineage='gaia-other')),
    case('malformed lineage', 'registry lineage is malformed', lambda d: d.update(lineage='gaia probe!')),
    case('unknown top field', 'registry has an unknown field', lambda d: d.update(shafts=[])),
    case('missing placements', 'registry is missing a field', lambda d: remove_key(d, 'placements')),
    case('negative generation', 'registry generation is invalid', lambda d: d.update(generation=-1)),
    case('limit above hard cap', 'limits exceed the hard caps', lambda d: d['limits'].update(depth=9)),
    case('unknown limit', 'limits has an unknown field', lambda d: d['limits'].update(gutter=1)),
    case('duplicate mine', 'duplicate mine 1', lambda d: d['mines'].append({'id': 1, 'deepest': 0, 'created': 2})),
    case('unissued mine id', 'mine id is invalid or not yet issued', lambda d: d['mines'].append({'id': 4, 'deepest': 0, 'created': 7})),
    case('mine created after save', 'mine 2 creation receipt is invalid', lambda d: d['mines'][2].update(created=8)),
    case('duplicate floor', 'duplicate floor 1/1', lambda d: (d['floors'].append(copy.deepcopy(floor(d, 1, 1))), d['placements'].append(copy.deepcopy(placement(d, 1, 1))))[-1] and None),
    case('missing committed floor', 'floor 1/2 is missing', lambda d: (drop(d, 'floors', 1, 2), drop(d, 'placements', 1, 2))[-1]),
    case('floor below deepest', 'floor 3/2 is below its mine\'s deepest floor', lambda d: floor(d, 3, 1).update(depth=2)),
    case('floor of no mine', 'floor 2/1 belongs to no mine', lambda d: (d['mines'].pop(2), floor(d, 3, 1).update(mine=2))[-1]),
    case('fractional width', 'floor 3/1 size is invalid', lambda d: floor(d, 3, 1).update(width=20.5)),
    case('text width', 'floor 3/1 size is invalid', lambda d: floor(d, 3, 1).update(width='20')),
    case('width above limit', 'floor 3/1 size is invalid', lambda d: floor(d, 3, 1).update(width=65)),
    case('negative seed', 'floor 3/1 generator is invalid', lambda d: floor(d, 3, 1).update(seed=-1)),
    case('seed beyond exact range', 'floor 3/1 generator is invalid', lambda d: floor(d, 3, 1).update(seed=16777216)),
    case('floor created after save', 'floor 3/1 creation receipt is invalid', lambda d: floor(d, 3, 1).update(created=8)),
    case('floor created before mine', 'floor 3/1 creation receipt is invalid', lambda d: floor(d, 3, 1).update(created=5)),
    case('too many floors', 'too many floors', lambda d: d['limits'].update(floors=2)),
    case('too many mines', 'too many mines', lambda d: d['limits'].update(mines=2)),
    case('placement count mismatch', 'placement count does not match floor count', lambda d: d['placements'].pop() and None),
    case('orphan placement', 'placement 2/1 has no floor', lambda d: placement(d, 3, 1).update(mine=2)),
    case('duplicate placement', 'duplicate placement 1/1', lambda d: d['placements'].__setitem__(1, copy.deepcopy(placement(d, 1, 1)))),
    case('border above limit', 'placement 3/1 border or generation is invalid', lambda d: placement(d, 3, 1).update(border=3)),
    case('outside the planes', 'placement 1/2 is outside the planes', lambda d: placement(d, 1, 2).update(x1=66, x2=101)),
    case('no such plane', 'placement 1/2 is outside the planes', lambda d: placement(d, 1, 2).update(z=5)),
    case('size mismatch', 'placement 3/1 does not match its floor size', lambda d: placement(d, 3, 1).update(x2=57)),
    case('overlap', 'placements 1/1 and 3/1 overlap', lambda d: placement(d, 3, 1).update(x1=36, x2=57)),
    case('unknown placement field', 'placement has an unknown field', lambda d: placement(d, 3, 1).update(occupants=[])),
]


def main():
    HERE.mkdir(exist_ok=True)
    (HERE / 'valid.json').write_text(json.dumps(VALID, indent='\t') + '\n', encoding='utf-8')
    (HERE / 'negative.json').write_text(json.dumps(NEGATIVE, indent='\t') + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
