"""Habitat and hazard rows for atlas reference pages (#4460).

Habitats come from the tables the game itself spawns from, read as source text:
the wildlife species table in `ecology_default_species()`, the wild herb
climates in `wild_herb_climates()` and each sea animal's depth zones. Hazards
are a reviewed list in `hazards.json`; every entry names the source lines it
was checked against, and the test fails when those lines change.

A habitat row says where the game places the thing when it spawns wildlife or
herbs on an open-world map. It is not a claim about any particular map.
"""
import json
import re
from pathlib import Path

ECOLOGY = 'code/modules/ecology/ecology_spawning.dm'
HERBS = 'code/modules/ecology/wild_herbs.dm'
HAZARDS = Path(__file__).with_name('hazards.json')

BIOMES = {'temperate': 'temperate', 'taiga': 'taiga', 'tundra': 'tundra', 'semiarid': 'semi-arid',
          'desert': 'desert', 'savanna': 'savanna', 'jungle': 'jungle', 'sea': 'coastal'}
# Ground letters as ecology_default_species() binds them to the ECO_* classes.
GROUNDS = {'G': 'grass', 'D': 'dirt', 'S': 'snow', 'B': 'beaches', 'A': 'desert sand', 'W': 'shallow fresh water'}
ZONES = {'SEA_ZONE_SHELF': 1, 'SEA_ZONE_OPEN': 2, 'SEA_ZONE_DEEP': 3, 'SEA_ZONE_ABYSS': 4}
ZONE_NAMES = {1: 'the shallow shelf', 2: 'open water', 3: 'deep water', 4: 'the abyss'}
ZONE_ALONE = {1: 'over the shallow shelf', 2: 'in open water', 3: 'in deep water', 4: 'in the abyss'}
SPECIES = re.compile(r'^\t\teco_species\("([^"]+)",\s*list\(([^)]*)\),\s*list\(([^)]*)\),\s*([A-Z|]+)\s*,'
                     r'\s*[\d.]+\s*,\s*\d+(?:\s*,\s*\d+\s*,\s*\d+)?(?:\s*,\s*(null|list\(([^)]*)\)))?', re.M)


def joined(words):
    words = list(dict.fromkeys(words))
    return words[0] if len(words) == 1 else ', '.join(words[:-1]) + ' and ' + words[-1]


def either(words):
    words = list(dict.fromkeys(words))
    return words[0] if len(words) == 1 else ', '.join(words[:-1]) + ' or ' + words[-1]


def paths(text):
    return re.findall(r'/[\w/]+', text or '')


def wildlife(files):
    """{type path: habitat text} from the ecology species table."""
    found = {}
    for name, spawned, biomes, grounds, _, covers in SPECIES.findall(files.get(ECOLOGY, '')):
        lands = [BIOMES[b] for b in re.findall(r'"(\w+)"', biomes) if b in BIOMES]
        ground = [GROUNDS[g] for g in grounds.split('|') if g in GROUNDS]
        if not lands or not ground:
            continue
        text = f'Wild in {joined(lands)} lands, on {either(ground)}'
        for typepath in paths(spawned) + paths(covers):
            found.setdefault(typepath, text)
    return found


def herbs(files):
    """{type path: habitat text} from wild_herb_climates()."""
    found = {}
    body = files.get(HERBS, '')
    for typepath, climates in re.findall(r'if \((/obj/structure/wild/flowers/wild_herb/\w+)\)\s*\n\s*return list\(([^)]*)\)', body):
        lands = [BIOMES[c] for c in re.findall(r'"(\w+)"', climates) if c in BIOMES]
        if lands:
            found[typepath] = f'Grows wild on grass in {joined(lands)} lands'
    return found


def sea(types):
    """{type path: habitat text} from each sea animal's declared depth zones."""
    from .facts import inherited
    found = {}
    for typepath in types:
        if not typepath.startswith('/mob/living/simple_animal/sea/'):
            continue
        low, high = (ZONES.get(inherited(types, typepath, name)) for name in ('zone_min', 'zone_max'))
        if not low or not high:
            continue
        found[typepath] = (f'The sea, {ZONE_ALONE[low]}' if low == high
                           else f'The sea, from {ZONE_NAMES[low]} to {ZONE_NAMES[high]}')
    return found


def load_hazards(path=HAZARDS):
    return {entry['type']: entry['hazard'] for entry in json.loads(Path(path).read_text())['hazards']}


def nearest(table, typepath):
    """The entry for the type or its closest listed ancestor."""
    while typepath:
        if typepath in table:
            return table[typepath]
        typepath = typepath.rsplit('/', 1)[0]
    return None


def place_rows(files, types):
    """{type path: [[label, text], ...]} for every declared type with a habitat or hazard."""
    habitat = wildlife(files) | herbs(files) | sea(types)
    hazards = load_hazards()
    rows = {}
    for typepath in types:
        if not typepath.startswith(('/mob/', '/obj/', '/turf/')):
            continue
        found = []
        # Wildlife and herbs are listed by exact spawn type; sea zones inherit like any var.
        if typepath in habitat:
            found.append(['Habitat', habitat[typepath]])
        hazard = nearest(hazards, typepath)
        if hazard:
            found.append(['Hazard', hazard])
        if found:
            rows[typepath] = found
    return rows
