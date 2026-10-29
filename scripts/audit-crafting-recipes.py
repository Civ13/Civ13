"""Inventory explicit material rows; no implied recipe or map reachability claims."""
import argparse
from collections import Counter
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def inventory(root=ROOT):
    categories, catalogs, furniture = Counter(), Counter(), []
    for path in sorted((root / 'config/crafting').glob('material_recipes_*.txt')):
        for line, raw in enumerate(path.read_text().splitlines(), 1):
            if 'RECIPE: ' not in raw or '//' in raw:
                continue
            fields = raw.split('RECIPE: ', 1)[1].split(',')
            if len(fields) != 13:
                raise ValueError(f'{path.name}:{line}: expected 13 fields')
            categories[fields[7]] += 1
            catalogs[path.name] += 1
            output = fields[2]
            if fields[7] == 'furniture' or output.startswith(('/obj/structure/bed', '/obj/structure/table', '/obj/structure/bookcase', '/obj/structure/closet', '/obj/structure/filingcabinet', '/obj/item/weapon/stool', '/obj/item/weapon/barstool', '/obj/item/weapon/bedroll')):
                furniture.append(dict(file=path.relative_to(root).as_posix(), line=line, row=raw,
                                      material=fields[0], name=fields[1], output=output,
                                      category=fields[7], cost=fields[3], maximum_era=fields[11]))
    return dict(scope='Active 13-field material catalogs only. Categories are author labels; counts include repeated map/faction rows. Bespoke handlers and constructors require separate review.',
                catalogs=dict(catalogs), categories=dict(sorted(categories.items())), furniture=furniture)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--summary', action='store_true', help='Write compact counts and preserve existing hand-reviewed metadata')
    args = parser.parse_args()
    data = inventory()
    if args.summary:
        previous = json.loads(args.output.read_text()) if args.output.exists() else {}
        previous.pop('furniture', None)
        previous.update({key: data[key] for key in ('scope', 'catalogs', 'categories')})
        previous['current_furniture_candidates'] = len(data['furniture'])
        data = previous
    args.output.write_text(json.dumps(data, indent=2) + '\n')
