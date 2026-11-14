"""Admin-only atlas entries: kept out of every public atlas output.

`code/game/mob/crafting_atlas_admin.dm` holds the deliberate list. The game
builds those entries at runtime for admins only, so the generated
UI/crafting-atlas.json and the published web atlas must never mention a listed
type or any subtype of one. `check_public` is the build's last gate.
"""
import re

SOURCE = 'code/game/mob/crafting_atlas_admin.dm'
_LIST = re.compile(r'^var/global/list/crafting_atlas_admin_only = list\((.*?)\)\s*$', re.M | re.S)
_ENTRY = re.compile(r'^\s*(/[\w/]+)\s*=\s*"((?:[^"\\]|\\.)*)"\s*,?\s*$')


def admin_only_types(files):
    """{type path: staff note} in source order; raises if the list cannot be read."""
    text = files.get(SOURCE)
    match = _LIST.search(text or '')
    if not match:
        raise SystemExit('Admin-only atlas list not found in ' + SOURCE)
    entries = {}
    for line in match.group(1).splitlines():
        if not line.strip():
            continue
        entry = _ENTRY.match(line)
        if not entry:
            raise SystemExit('Unreadable admin-only atlas entry in ' + SOURCE + ': ' + line.strip())
        entries[entry.group(1)] = entry.group(2)
    if not entries:
        raise SystemExit('Admin-only atlas list in ' + SOURCE + ' is empty')
    return entries


def covers(hidden, typepath):
    """True for a listed type or any subtype of one."""
    return any(typepath == path or typepath.startswith(path + '/') for path in hidden)


def leaks(hidden, text):
    """Listed types (or their subtypes) that a public output still mentions."""
    return sorted(path for path in hidden if re.search(re.escape(path) + r'(?![\w])', text))


def without_mentions(hidden, rows, field):
    """Rows whose `field` text names no listed type; the raw source-site index
    is public, so a site that spawns admin-only loot is left out of it."""
    return [row for row in rows if not leaks(hidden, row.get(field, ''))]


def check_public(hidden, text, where):
    found = leaks(hidden, text)
    if found:
        raise SystemExit('Admin-only atlas types reached ' + where + ': ' + ', '.join(found)
                         + '. Remove their recipe or route from the public atlas, or take them off the list in ' + SOURCE + '.')
