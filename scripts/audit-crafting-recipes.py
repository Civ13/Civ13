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
            if fields[7] == 'furniture' or output.startswith(('/obj/structure/bed', '/obj/structure/table', '/obj/structure/bookcase', '/obj/structure/closet', '/obj/structure/filingcabinet', '/obj/item/weapon/stool', '/obj/item/weapon/barstool')):
                furniture.append(dict(file=path.relative_to(root).as_posix(), line=line, row=raw,
                                      material=fields[0], name=fields[1], output=output,
                                      category=fields[7], cost=fields[3], maximum_era=fields[11]))
    return dict(scope='Active 13-field material catalogs only. Categories are author labels; counts include repeated map/faction rows. Bespoke handlers and constructors require separate review.',
                catalogs=dict(catalogs), categories=dict(sorted(categories.items())), furniture=furniture)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.write_text(json.dumps(inventory(), indent=2) + '\n')
