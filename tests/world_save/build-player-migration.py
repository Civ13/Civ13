"""Bind one uniquely observed legacy body to an authenticated account for review."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path


def scalar(fields, key, default=None):
    value = fields.get(key)
    if value is None:
        return default
    if not isinstance(value, dict) or value.get('kind') != 'value':
        raise ValueError(f'Unexpected scalar encoding: {key}')
    return value.get('value')


def select_body(report, observation, account):
    if not report.get('validated') or report.get('error'):
        raise ValueError('Census is not production-validator accepted')
    live = [body for body in observation['humans'] if body.get('client')]
    if len(live) != 1:
        raise ValueError('Expected exactly one recorded live player')
    live = live[0]
    expected_inventory = Counter((item['type'], item['name']) for item in live['inventory'])
    matches = []
    for row in report['humans']:
        fields = row['snapshot']['fields']
        # Omitted stat has initial CONSCIOUS value for this exact human type.
        if fields.get('type') != '/mob/living/human':
            continue
        inventory = Counter((item['fields']['type'], scalar(item['fields'], 'name'))
                            for item in row['snapshot']['contents'])
        if (scalar(fields, 'lastKnownCkey') == account
                and scalar(fields, 'name') == live['name']
                and scalar(fields, 'stat', 0) == live['stat']
                and row['position'] == [live['x'], live['y'], live['z']]
                and inventory == expected_inventory):
            matches.append(row)
    if len(matches) != 1:
        raise ValueError(f'Recorded body mapping is ambiguous or absent: {len(matches)} matches')
    selected = matches[0]
    if not selected.get('serialized_snapshot'):
        raise ValueError('Exact native serialized snapshot missing')
    return selected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--census', type=Path, required=True)
    parser.add_argument('--inspection-inputs', type=Path, required=True)
    parser.add_argument('--observation', type=Path, required=True)
    parser.add_argument('--save-directory', type=Path, required=True)
    parser.add_argument('--account', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not args.account or not args.account.isalnum() or args.account.lower() != args.account:
        raise ValueError('Expected canonical authenticated account')
    if args.output.exists():
        raise ValueError('Preserve existing reviewed manifest')
    inputs = json.loads(args.inspection_inputs.read_text(encoding='utf-8'))
    expected = inputs['generation_sha256']
    actual = {name: hashlib.sha256((args.save_directory / name).read_bytes()).hexdigest()
              for name in ('1.sav', '2.sav', 'map.txt', 'save_complete.txt')}
    if expected != actual:
        raise ValueError('Generation changed since census')
    report = json.loads(args.census.read_text(encoding='utf-8'))
    observation = json.loads(args.observation.read_text(encoding='utf-8'))
    row = select_body(report, observation, args.account)
    manifest = {'schema': 1, 'generation_sha256': actual, 'account': args.account,
                'z': row['z'], 'entry': row['entry'], 'serialized_snapshot': row['serialized_snapshot'],
                'observation_sha256': hashlib.sha256(args.observation.read_bytes()).hexdigest(),
                'census_sha256': hashlib.sha256(args.census.read_bytes()).hexdigest(),
                'matching_fields': 'authenticated audit, exact human type, name, position, state, all direct physical inventory types and names',
                'limits': 'Live snapshot has no health, mind or durable item properties. Native migration must match all saved fields and nested contents exactly; real client control still requires acceptance.'}
    args.output.write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(f'Unique candidate for review z={row["z"]} entry={row["entry"]}; manifest {args.output}')


if __name__ == '__main__':
    main()
