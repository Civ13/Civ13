#!/usr/bin/env python3
"""Generate recipe rows for plain tools in other materials.

config/recipe_variants.json lists, per product, the existing catalog row to
copy (the template) and the other materials the product may be made of. Each
material gets one ordinary RECIPE row in a marked block at the end of the
catalog, so the game's loaders, the Atlas and every other reader of the
catalog keep working on plain rows. A variant row differs from its template
only in the material, the title ("bronze wrench"), an optional cost and the
last field, which names the material the tool is built in
(code/modules/materials/tool_materials.dm).

  python3 scripts/recipe_variants.py            # check the block is current
  python3 scripts/recipe_variants.py --write    # rewrite it
"""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'config/recipe_variants.json'
BEGIN = '//**| GENERATED TOOL MATERIAL VARIANTS: edit config/recipe_variants.json, then run scripts/recipe_variants.py --write |**'
END = '//**| END GENERATED TOOL MATERIAL VARIANTS |**'


def catalog_rows(text):
    rows = []
    for line in text.splitlines():
        if line.startswith('RECIPE: ') and '//' not in line:
            rows.append(line[len('RECIPE: '):].strip().split(','))
    return rows


def split_block(text):
    """(text before the block, block lines) - the block is always last."""
    if BEGIN not in text:
        return text if text.endswith('\n') else text + '\n', []
    head, rest = text.split(BEGIN, 1)
    body, tail = rest.split(END, 1)
    if tail.strip():
        raise SystemExit('The generated block must be the last thing in the catalog.')
    return head, [line for line in body.splitlines() if line.strip()]


def variant_rows(data, hand_rows):
    rows = []
    for variant in data['variants']:
        wanted = variant['template']
        matches = [row for row in hand_rows if row[2] == variant['result'] and row[1] == wanted['title']
                   and row[0] == '/material/%s/' % wanted['material']]
        if len(matches) != 1:
            raise SystemExit('Template for %s must match exactly one row, found %d.' % (variant['result'], len(matches)))
        for material in variant['materials']:
            row = list(matches[0])
            row[0] = '/material/%s/' % material
            row[1] = '%s %s' % (material, variant['noun'])
            if 'cost' in variant:
                row[3] = str(variant['cost'])
            row[12] = material
            rows.append('RECIPE: ' + ','.join(row))
    return rows


def render(text, data):
    head, _ = split_block(text)
    rows = variant_rows(data, catalog_rows(head))
    return head + BEGIN + '\n' + '\n'.join(rows) + '\n' + END + '\n'


def main():
    data = json.loads(DATA.read_text(encoding='utf-8'))
    catalog = ROOT / data['catalog']
    current = catalog.read_text(encoding='utf-8')
    wanted = render(current, data)
    if '--write' in sys.argv:
        if wanted != current:
            catalog.write_text(wanted, encoding='utf-8', newline='')
        print('%s: %s' % (data['catalog'], 'regenerated' if wanted != current else 'current'))
        return 0
    if wanted != current:
        print('%s: generated tool variants are stale; run python3 scripts/recipe_variants.py --write' % data['catalog'])
        return 1
    print('%s: current' % data['catalog'])
    return 0


if __name__ == '__main__':
    sys.exit(main())
