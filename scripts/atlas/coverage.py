"""Describe catalog coverage, not gameplay reachability or full entity coverage.

Usage: python scripts/atlas/coverage.py [UI/crafting-atlas.json]
"""
import json
import sys
from collections import Counter
from pathlib import Path


def report(catalog):
    resources = catalog['resources']
    produced = {entry['id'] for recipe in catalog['recipes'] for entry in recipe['outputs']}
    annotated = set(catalog.get('acquisition', {}))
    categories = {key for key, value in resources.items() if value.get('category')}
    unresolved = set(resources) - produced - annotated - categories
    families = Counter()
    for key in resources:
        parts = key.strip('/').split('/')
        families['/'.join(parts[:2]) if key.startswith('/') else 'symbolic'] += 1
    return {
        'scope': 'Recipe-linked catalog only; not an inventory of all playable entities',
        'recipes': len(catalog['recipes']),
        'resources': len(resources),
        'resource_families': dict(sorted(families.items())),
        'abstract_input_categories': sorted(categories),
        'resources_with_acquisition_annotations': len(set(resources) & annotated),
        'acquisition_routes': sum(len(routes) for routes in catalog.get('acquisition', {}).values()),
        'resources_without_producer_or_acquisition_annotation': sorted(unresolved),
        'limitation': 'Missing routes require source review; they do not prove unobtainability. Counts do not prove native behavior or map availability.',
    }


if __name__ == '__main__':
    default = Path(__file__).resolve().parents[2] / 'UI/crafting-atlas.json'
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else default
    print(json.dumps(report(json.loads(path.read_text())), indent=2))
