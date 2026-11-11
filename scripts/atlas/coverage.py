"""Describe catalog and reference coverage, not gameplay reachability.

Usage: python scripts/atlas/coverage.py [UI/crafting-atlas.json]
"""
import json
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


if __name__ == '__main__':
    default = Path(__file__).resolve().parents[2] / 'UI/crafting-atlas.json'
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else default
    print(json.dumps(report(json.loads(path.read_text())), indent=2))
