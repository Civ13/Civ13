"""Bounded declaration gate for the #3407 audit, not a DM type checker.

Includes tmp and inherited declarations. Untyped vars, collections, dynamic
assignments and files outside SCOPE still need separate review. Retained means
fail closed, not a claim of cross-level safety or a durable codec.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
SCOPE = (
    'code/game/mob/living/simple_animal/simple_animal.dm',
    'code/game/mob/living/simple_animal/hostile/hostile.dm',
    'code/game/mob/living/simple_animal/subtile_movement.dm',
    'code/game/mob/grab.dm',
    'code/game/objects/structures/optable.dm',
    'code/game/objects/items/weapons/explosives.dm',
    'code/modules/multiz/structures.dm',
    'code/game/mob/living/carbon/human/pull_pair_ownership.dm',
    'code/game/mob/observer/ghost/ghost.dm',
    'code/_onclick/hud/action.dm',
)


def declarations(source, path):
    owner = None
    in_proc = False
    rows = []
    for number, raw in enumerate(source.splitlines(), 1):
        line = raw.split('//', 1)[0].rstrip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('/'):
            owner = line.strip().split('(')[0]
            in_proc = '(' in line
            if '/var/' in owner:
                owner, field = owner.split('/var/', 1)
                line = '\tvar/' + field
                in_proc = False
            else:
                continue
        if not owner or in_proc:
            continue
        # Audited files use one-tab var declarations. Never include proc locals.
        match = re.match(r'^\tvar/((?:\w+/)*)(\w+)(?:\s|=|$)', line)
        if not match:
            continue
        tokens = [token for token in match[1].strip('/').split('/') if token not in ('tmp', 'static', 'global')]
        if tokens and tokens[0] in ('atom', 'mob', 'obj', 'turf', 'area'):
            rows.append({'owner': owner, 'field': match[2], 'type': '/' + '/'.join(tokens),
                         'path': path, 'line': number})
    return rows


def inventory(root=ROOT):
    return [row for path in SCOPE for row in declarations((root / path).read_text(encoding='utf-8-sig'), path)]


if __name__ == '__main__':
    import json
    print(json.dumps(inventory(), indent=2))
