"""Presentation-only recipe families; canonical recipes remain independent."""
import hashlib
import json
import re


def declared_parents(files):
    """Read explicit absolute type declarations and literal parent_type overrides.

    Unknown, conflicting, cyclic or incompletely declared ancestry is not proof
    of a family. This is a conservative source projection, not a DM compiler.
    """
    declared, overrides, blocked = set(), {}, set()
    for path, raw in sorted(files.items()):
        if not path.endswith('.dm') or not path.startswith('code/'):
            continue
        source = re.sub(r'/\*.*?\*/', '', raw, flags=re.S)
        current = None
        for line in source.splitlines():
            if line and not line[0].isspace():
                match = re.fullmatch(r'(/[A-Za-z0-9_/]+)\s*(?://.*)?', line)
                current = match[1].rstrip('/') if match else None
                if current:
                    declared.add(current)
            elif current and re.match(r'\s+parent_type\s*=', line):
                match = re.fullmatch(r'\s+parent_type\s*=\s*(/[A-Za-z0-9_/]+)\s*(?://.*)?', line)
                if not match or (current in overrides and overrides[current] != match[1]):
                    blocked.add(current)
                else:
                    overrides[current] = match[1].rstrip('/')
    return {path: (None if path in blocked else overrides.get(path, path.rsplit('/', 1)[0] or None))
            for path in declared}


def descendant(child, ancestor, parents):
    if child == ancestor:
        return True  # Exact output identity needs no ancestry inference.
    if ancestor not in parents:
        return False
    seen, found = set(), False
    while child in parents:
        if child in seen:
            return False
        seen.add(child)
        found = found or child == ancestor
        child = parents[child]
    # Continue past the candidate: it may itself participate in a cycle.
    return found


def annotate_families(records, files):
    """Annotate; never merge records, aliases, costs, requirements or sources.

    One exact recipe name and canonical single-output identity is a family.
    A same-name recipe producing an explicitly declared ancestor can anchor
    subtype variants. Multiple outputs and unknown relationships stay separate.
    """
    parents = declared_parents(files)
    anchors = {}
    for recipe in records:
        outputs = recipe.get('outputs', [])
        if len(outputs) == 1 and outputs[0].get('id'):
            anchors.setdefault(recipe['name'], set()).add(outputs[0]['id'])
    for recipe in records:
        outputs = recipe.get('outputs', [])
        if len(outputs) != 1 or not outputs[0].get('id'):
            recipe['family_id'] = 'recipe_' + recipe['id']
            continue
        output = root = outputs[0]['id']
        for candidate in sorted(anchors[recipe['name']]):
            if descendant(output, candidate, parents) and descendant(root, candidate, parents):
                root = candidate
        identity = json.dumps([recipe['name'], root], ensure_ascii=True, separators=(',', ':'))
        recipe['family_id'] = 'family_' + hashlib.sha256(identity.encode()).hexdigest()[:24]
