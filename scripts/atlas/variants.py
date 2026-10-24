"""Conservative presentation grouping for identical material catalog rows."""
import json


def consolidate_variants(records):
    """Share semantic fields while retaining each catalog row's identity/source.

    Only the material loader's explicit 13-field rows are eligible. Compare the
    original fields too: canonical resource aliases and extraction omissions must
    never make different gameplay definitions appear equivalent. Unknown/new
    metadata participates in equality automatically. Non-material routes retain
    their independent callback/context identity.
    """
    groups = {}
    result = []
    provenance = ('id', 'kind', 'file', 'line', 'raw')
    for recipe in records:
        raw = recipe.get('raw', '')
        fields = raw.split('RECIPE: ', 1)[-1].strip().split(',')
        eligible = (recipe['kind'].startswith('Material / ')
                    and recipe['file'].startswith('config/crafting/')
                    and 'RECIPE: ' in raw and len(fields) == 13)
        if not eligible:
            result.append(recipe)
            continue
        semantic = {k: v for k, v in recipe.items() if k not in provenance}
        key = json.dumps([fields, semantic], sort_keys=True, ensure_ascii=True)
        variant = {k: recipe[k] for k in provenance}
        if key not in groups:
            group = recipe.copy()
            group['variants'] = [variant]
            groups[key] = group
            result.append(group)
        else:
            groups[key]['variants'].append(variant)
    for recipe in result:
        if len(recipe.get('variants', [])) == 1:
            del recipe['variants']
    return result


def game_recipes(records):
    """Keep the compact in-game catalog's existing omission of raw source text."""
    return [{k: ([{a: b for a, b in v.items() if a != 'raw'} for v in value]
                  if k == 'variants' else value)
             for k, value in recipe.items() if k != 'raw'} for recipe in records]
