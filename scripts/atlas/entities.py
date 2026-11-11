"""Reference entries for player-facing things that no recipe mentions.

The recipe catalog only knows recipe inputs and outputs. This adds a page for
every other item, structure, machine, floor or wall cover, animal and terrain
type that declares its own plain name in a file the build includes. Nothing is
compiled or instantiated: names, descriptions and stats are literal
declarations read by `facts.py`, so runtime-built text is left out.

A type without its own name is a variant of its parent, not a separate entry.
Admin, test, map-plumbing, effect, projectile and hidden-discovery paths are
never listed, and neither is a type whose own name or description mentions them.
"""
import re

from .entity_inventory import include_graph
from .facts import declared, prose, resource_facts

ROOTS = ('/obj/item', '/obj/structure', '/obj/machinery', '/obj/covers', '/mob/living/simple_animal', '/turf')
INTERNAL = re.compile(r'/(admin\w*|debug\w*|test\w*|fluff|landmark\w*|spawner\w*|abstract|effect\w*|hud|dummy|holder'
                      r'|internal|placeholder|secret\w*|easter\w*|fake\w*|invisible|unsimulated|template|base|generic'
                      r'|proc|verb|\w*spawn\w*|liminal\w*|\w*portal\w*|\w*teleport\w*|hidden\w*'
                      r'|cursed\w*|\w*ritual\w*)(/|$)', re.I)
# Examine text that itself talks about hidden or staff-only things keeps the type out of the reference.
GUARDED = re.compile(r'\b(secret|hidden|admins?\b|debug|cheat|do not use|should not exist|shouldn.t be here|unused|placeholder|test(ing)?\b)', re.I)


def eligible(types, typepath):
    return (typepath.startswith(ROOTS) and typepath not in ROOTS and not INTERNAL.search(typepath)
            and not typepath.startswith('/obj/item/projectile')
            and bool(prose(types[typepath].get('name'))))


def entity_resources(files, resources):
    """{type path: resource entry} for eligible types the catalog does not already cover."""
    reachable = include_graph(files)
    built = {path: text for path, text in files.items() if path in reachable and path.startswith('code/')}
    types = declared(built)
    covered = set(resources) | {entry.get('type') for entry in resources.values()}
    chosen = sorted(typepath for typepath in types if typepath not in covered and eligible(types, typepath))
    details = resource_facts(built, {typepath: typepath for typepath in chosen})
    chosen = [typepath for typepath in chosen
              if not GUARDED.search(prose(types[typepath]['name']) + ' ' + details[typepath].get('desc', ''))]
    return {typepath: dict(name=prose(types[typepath]['name']), type=typepath,
                           label='Initial sprite; runtime appearance may differ', entity=True) | details[typepath]
            for typepath in chosen}
