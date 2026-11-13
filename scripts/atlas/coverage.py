"""Describe catalog and reference coverage, not gameplay reachability.

Usage: python scripts/atlas/coverage.py [UI/crafting-atlas.json]
       python scripts/atlas/coverage.py --since origin/master [UI/crafting-atlas.json]

`--since REV` lists only what code added after REV: new item, structure and
animal types whose atlas page has no recipe or route, and new reagents with no
page at all. Use it after merging content to see what still needs a route in
`scripts/atlas/interactions.py` or `resource-sources.json`.
"""
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path


def reference(resources, annotated, produced):
    """How much of the examinable reference is described; every page is an examine-link target."""
    pages = {key: value for key, value in resources.items() if not value.get('category')}
    entities = {key: value for key, value in pages.items() if value.get('entity')}
    kinds = Counter(value.get('kind', 'unknown') for value in entities.values())
    return {
        'pages': len(pages),
        'reference_only_entries': len(entities),
        'reference_only_by_kind': dict(sorted(kinds.items())),
        'pages_with_description': sum(bool(value.get('desc')) for value in pages.values()),
        'pages_with_stats': sum(bool(value.get('stats')) for value in pages.values()),
        'pages_with_habitat': sum(any(row[0] == 'Habitat' for row in value.get('stats', ())) for value in pages.values()),
        'pages_with_hazard': sum(any(row[0] == 'Hazard' for row in value.get('stats', ())) for value in pages.values()),
        'pages_with_recipe_or_route': len(set(pages) & (annotated | produced)),
        'examine_linkable_types': sum(key.startswith(('/obj/', '/mob/', '/turf/', '/material/')) for key in pages),
        'note': 'Eligibility is decided by scripts/atlas/entities.py. A reference entry is a static type page, '
                'not a claim that the thing is on the current map.',
    }


def report(catalog):
    resources = catalog['resources']
    produced = {entry['id'] for recipe in catalog['recipes'] for entry in recipe['outputs']}
    annotated = set(catalog.get('acquisition', {}))
    categories = {key for key, value in resources.items() if value.get('category')}
    entities = {key for key, value in resources.items() if value.get('entity')}
    unresolved = set(resources) - produced - annotated - categories - entities
    linked = set(resources) - entities
    families = Counter()
    for key in linked:
        parts = key.strip('/').split('/')
        families['/'.join(parts[:2]) if key.startswith('/') else 'symbolic'] += 1
    return {
        'scope': 'Recipe-linked resources plus reference entries for other named player-facing types',
        'recipes': len(catalog['recipes']),
        'resources': len(linked),
        'resource_families': dict(sorted(families.items())),
        'abstract_input_categories': sorted(categories),
        'resources_with_acquisition_annotations': len(linked & annotated),
        'acquisition_routes': sum(len(routes) for routes in catalog.get('acquisition', {}).values()),
        'resources_without_producer_or_acquisition_annotation': sorted(unresolved),
        'reference': reference(resources, annotated, produced),
        'limitation': 'Missing routes require source review; they do not prove unobtainability. Counts do not prove native behavior or map availability.',
    }


def added_without_route(catalog, diff):
    """New types and reagents in a unified diff (-U0) that the atlas cannot explain yet."""
    resources = catalog['resources']
    explained = {entry['id'] for recipe in catalog['recipes'] for entry in recipe['outputs']} | set(catalog.get('acquisition', {}))
    found, path, current = {}, None, ''
    for line in diff.splitlines():
        if line.startswith('+++ '):
            path = line[6:] if line.startswith('+++ b/') else None
            continue
        if not path or not path.startswith('code/') or not line.startswith('+') or line.startswith('+++'):
            continue
        text = line[1:]
        header = re.match(r'^(/(?:obj/item|obj/structure|obj/machinery|mob/living/simple_animal|datum/reagent)/[\w/]+)[ \t]*$', text)
        if header:
            current = header[1]
            if not current.startswith('/datum/') and current in resources and current not in explained:
                found.setdefault(current, dict(file=path, name=resources[current].get('name', ''), problem='page has no recipe or route'))
            continue
        reagent = re.match(r'^\tid = "(\w+)"', text)
        if reagent and current.startswith('/datum/reagent/'):
            rid = reagent[1]
            if rid not in resources:
                found.setdefault(rid, dict(file=path, name=rid, problem='reagent has no atlas page (nothing makes or uses it)'))
            elif rid not in explained:
                found.setdefault(rid, dict(file=path, name=rid, problem='page has no recipe or route'))
    return found


if __name__ == '__main__':
    args = sys.argv[1:]
    since = None
    if args[:1] == ['--since']:
        since, args = args[1], args[2:]
    default = Path(__file__).resolve().parents[2] / 'UI/crafting-atlas.json'
    path = Path(args[0]) if args else default
    catalog = json.loads(path.read_text())
    if since:
        diff = subprocess.run(['git', 'diff', '-U0', since, '--', 'code'], capture_output=True, text=True, check=True).stdout
        print(json.dumps(added_without_route(catalog, diff), indent=2))
    else:
        print(json.dumps(report(catalog), indent=2))
