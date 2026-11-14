"""Admin-only atlas entries: kept out of every public atlas output.

`code/game/mob/crafting_atlas_admin.dm` holds the deliberate list. The game
builds those entries at runtime for admins only, so the generated
UI/crafting-atlas.json and the published web atlas must never mention a listed
type or any subtype of one, a covered reagent's id, or a covered reaction.
`check_public` is the build's last gate.

Val's rule: anything not available on Nomads stays out of the public atlas.
Magic is Wizard Boy (and a few other maps) only, so every named type declared
under MAGIC_SOURCES must be covered by the list; `check_magic` enforces it.
"""
import json
import re

from .facts import declared, prose

SOURCE = 'code/game/mob/crafting_atlas_admin.dm'
MAGIC_SOURCES = ('code/modules/magic/',)
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
        if not line.strip() or line.strip().startswith('//'):
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


def without_mentions(hidden, rows, reagent_ids=()):
    """Rows that name no covered type or reagent id in any field; the raw source
    indexes (spawn sites, unresolved records, source audit) are public, so a row
    about an admin-only thing, or from a magic source file, is left out of them."""
    kept = []
    for row in rows:
        text = json.dumps(row)
        if any(source in text for source in MAGIC_SOURCES) or leaks(hidden, text) or any(re.search(r'(?<![\w])' + re.escape(rid) + r'(?![\w])', text) for rid in reagent_ids):
            continue
        kept.append(row)
    return kept


def check_public(hidden, text, where, reagent_ids=()):
    found = leaks(hidden, text) + sorted(rid for rid in reagent_ids if '"' + rid + '"' in text)
    if found:
        raise SystemExit('Admin-only atlas types reached ' + where + ': ' + ', '.join(found)
                         + '. Remove their recipe or route from the public atlas, or take them off the list in ' + SOURCE + '.')


def hidden_reagent_ids(files, hidden):
    """Catalog ids of covered reagents (the catalog names reagents by id, not path)."""
    types = declared({path: text for path, text in files.items() if path.startswith('code/')})
    return sorted(prose(fields['id']) for path, fields in types.items()
                  if path.startswith('/datum/reagent/') and covers(hidden, path) and prose(fields.get('id')))


def hidden_reactions(files, hidden):
    """(file, line) of every covered chemistry reaction's declaration, as recipe records cite them."""
    found = set()
    for path, text in files.items():
        if not path.startswith('code/'):
            continue
        for match in re.finditer(r'^(/datum/chemical_reaction/[\w/]+)\s*$', text, re.M):
            if covers(hidden, match.group(1)):
                found.add((path, text.count('\n', 0, match.start()) + 1))
    return found


def check_magic(files, text, where):
    """No named magic type may reach a public output: list it so it stays admin-only."""
    magic = declared({path: source for path, source in files.items() if path.startswith(MAGIC_SOURCES)})
    named = {path for path, fields in magic.items() if prose(fields.get('name'))}
    found = sorted(path for path in named if re.search(re.escape(path) + r'(?![\w/])', text))
    found += sorted(source for source in MAGIC_SOURCES if source in text)
    # The catalog names reagents by id, so an unlisted magic reagent shows up by id, not path.
    ids = {prose(magic[path].get('id')) for path in named if path.startswith('/datum/reagent/')} - {None, ''}
    found += sorted(rid for rid in ids if '"' + rid + '"' in text)
    if found:
        raise SystemExit('Magic is not available on Nomads, so magic types must be admin-only, but these reached '
                         + where + ': ' + ', '.join(found) + '. Add them to ' + SOURCE + '.')
