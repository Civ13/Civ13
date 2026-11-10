"""In-game display titles for atlas resources.

Catalog names are the last path segment ("brown", "emptyclip"). Players know
these things by their DM name ("brown bear pelt", "empty clip"), so the game
atlas shows a title where the source declares one. Names and canonical IDs are
unchanged; a title is presentation only and never a grouping or search key in
the generator.
"""
import re

DECLARATION = re.compile(r'^(/(?:obj|mob|turf)[\w/]*)[ \t]*(?://[^\n]*)?\n((?:[ \t]+[^\n]*\n|\n)*)', re.M)
NAME = re.compile(r'^\t(?:var/)?name\s*=\s*"([^"\[\]\\]+)"', re.M)


def declared_names(files):
    names = {}
    for path in sorted(files):
        if not path.endswith('.dm'):
            continue
        for match in DECLARATION.finditer(files[path]):
            name = NAME.search(match[2])
            if name and match[1] not in names:
                names[match[1]] = ' '.join(name[1].split())
    return names


# Stack names set at runtime from the material; the declared default misleads.
KEEP_CATALOG_NAME = {'/material/wood'}


def plain(path):
    return path.rstrip('/').split('/')[-1].replace('_', ' ')


def display_titles(files, types, catalog_names):
    """Return {resource id: title} for resources whose catalog name is the plain
    path label and whose type, or nearest named ancestor, declares a DM name."""
    names = declared_names(files)
    titles = {}
    for resource, typepath in types.items():
        if (not typepath.startswith('/') or '/proc/' in typepath or resource in KEEP_CATALOG_NAME
                or catalog_names[resource] != plain(resource)):
            continue  # reagents and reviewed names keep their catalog name
        title = names.get(typepath)
        if not title:
            parent = typepath.rsplit('/', 1)[0]
            while parent.count('/') > 2 and parent not in names:
                parent = parent.rsplit('/', 1)[0]
            if parent in names:
                title = names[parent] + ' (' + plain(typepath) + ')'
        if title and title.lower() != catalog_names[resource].lower():
            titles[resource] = title
    return titles
