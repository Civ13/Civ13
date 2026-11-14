"""The world chart for boat expeditions (docs/world-chart.md).

A grid of tiles kept in the group coordinator's database. Each tile is ocean
or land; the land's biome follows latitude and a little climate noise, so
neighbouring tiles agree. Nothing about a land is stored until a ship first
sees it: then its template (biome, land type, size, coasts, features,
resources and a seed) is rolled once and kept. Only an admin reroll changes a
kept template, and only while no world has been built from it. The template
is what a later step generates a region map from; the chart itself never
builds a world.

Each faction (or factionless crew) has its own chart: the tiles its ships
have seen. Admins see everything.
"""
import hashlib
import json
import os
from pathlib import Path
import random
import re
import secrets
import time

from tools.transfer_storage.region import account_key_valid

CHART_WIDTH = 48
CHART_HEIGHT = 32
SIGHT = 2  # tiles a ship sees around itself

# Biome codes, the letter each draws with on the text chart, and its name.
BIOMES = {
    'ICE_SHEET': ('I', 'ice sheet'),
    'TUNDRA': ('T', 'tundra'),
    'BOREAL': ('B', 'boreal forest'),
    'TEMPERATE_FOREST': ('F', 'temperate forest'),
    'GRASSLAND': ('G', 'grassland'),
    'DESERT': ('D', 'desert'),
    'SAVANNA': ('S', 'savanna'),
    'RAINFOREST': ('R', 'rainforest'),
    'SWAMP': ('W', 'swamp'),
}
OCEAN = '.'
MAINLAND = '@'
UNSEEN = '?'

# Land types and how likely each is in a biome (0 = never).
LAND_TYPES = ('COASTAL_PLAIN', 'RIVER_DELTA', 'HIGHLANDS', 'ARCHIPELAGO', 'FJORD_COAST', 'MARSH', 'VOLCANIC_ISLE', 'PLATEAU')
LAND_TYPE_WEIGHTS = {
    'ICE_SHEET':        (2, 0, 3, 2, 4, 0, 1, 2),
    'TUNDRA':           (3, 2, 3, 2, 4, 2, 1, 2),
    'BOREAL':           (3, 3, 3, 2, 3, 2, 1, 2),
    'TEMPERATE_FOREST': (4, 3, 3, 2, 1, 2, 1, 2),
    'GRASSLAND':        (4, 3, 2, 1, 0, 1, 1, 3),
    'DESERT':           (3, 1, 2, 2, 0, 0, 2, 4),
    'SAVANNA':          (4, 3, 2, 1, 0, 1, 1, 3),
    'RAINFOREST':       (3, 4, 2, 3, 0, 3, 2, 1),
    'SWAMP':            (2, 4, 0, 2, 0, 5, 1, 0),
}

# Sizes, smallest first: tiles a side (width, height) and roll weight. Only the
# enabled sizes are rolled for now (Val, 2026-11-14): tiny and small. Medium is
# Gaia's size; large and massive wait for a memory measurement.
SIZES = ('TINY', 'SMALL', 'MEDIUM', 'LARGE', 'MASSIVE')
SIZE_TILES = {'TINY': (200, 200), 'SMALL': (300, 300), 'MEDIUM': (500, 350), 'LARGE': (500, 500), 'MASSIVE': (600, 600)}
SIZE_WEIGHTS = {'TINY': 4, 'SMALL': 6, 'MEDIUM': 8, 'LARGE': 4, 'MASSIVE': 2}
SIZES_ENABLED = ('TINY', 'SMALL')
# Smaller lands are richer per tile; larger ones feed a settlement better.
SIZE_ORE = {'TINY': 'rich', 'SMALL': 'good', 'MEDIUM': 'fair', 'LARGE': 'thin', 'MASSIVE': 'poor'}
SIZE_FERTILITY = {'TINY': 'poor', 'SMALL': 'thin', 'MEDIUM': 'fair', 'LARGE': 'good', 'MASSIVE': 'rich'}

ORES = ('iron', 'copper', 'tin', 'coal', 'flint', 'gold', 'silver', 'salt')
RARE_FINDS = ('gems', 'rich gold vein', 'rich silver vein', 'amber', 'pearls')
GAME = {
    'ICE_SHEET': ('seals', 'polar bears', 'walruses'),
    'TUNDRA': ('reindeer', 'arctic foxes', 'wolves'),
    'BOREAL': ('elk', 'bears', 'wolves', 'beavers'),
    'TEMPERATE_FOREST': ('deer', 'boars', 'bears', 'wolves'),
    'GRASSLAND': ('bison', 'horses', 'wolves', 'hares'),
    'DESERT': ('camels', 'lizards', 'jackals'),
    'SAVANNA': ('antelope', 'zebras', 'lions', 'elephants'),
    'RAINFOREST': ('monkeys', 'tapirs', 'jaguars', 'snakes'),
    'SWAMP': ('alligators', 'frogs', 'herons', 'boars'),
}
STATES = ('CHARTED', 'LANDED', 'SETTLED', 'CLAIMED', 'LOST')
SIDES = (('N', 0, 1), ('S', 0, -1), ('E', 1, 0), ('W', -1, 0))

# Courses (docs/world-chart.md#courses): a ship that set course for a land
# asks for a world there. Its answer stays on the chart this long.
COURSE_STATES = ('ASSIGNED', 'READY', 'REFUSED')
COURSE_KEEP_SECONDS = 6 * 3600
# What the host keeps about its expedition slots (scripts/shard-group/expedition_slots.py).
SLOT_RECORDS = 'slots'
SLOT_WANTED = 'wanted'
SLOT_FAILED = 'failed'
SLOT_ABANDONED = 'abandon'
# A land nobody settled or claimed is abandoned after this long with nobody on it.
UNVISITED_SECONDS = 7 * 24 * 3600
_CLAIMANT = re.compile(r'^civ:[a-z0-9_\-]{1,40}:[^\x00-\x1f]{1,60}$')
NO_SLOT = 'every harbour master is busy: no new land can be opened for a crew right now. Try a land that is already open, or wait.'

_VOYAGE = re.compile(r'^[a-z0-9_\-]{1,80}$')
_OWNER = re.compile(r'^(admin|faction:[a-z0-9_\-]{1,40}|crew:[a-z0-9_\-]{1,40})$')


def owner_valid(owner):
    return isinstance(owner, str) and bool(_OWNER.match(owner))


def voyage_valid(voyage):
    return isinstance(voyage, str) and bool(_VOYAGE.match(voyage))


def _write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, indent=1, sort_keys=True) + '\n', encoding='utf-8')
    os.replace(temporary, path)


def _read_json(path):
    try:
        value = json.loads(Path(path).read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return None
    return value if isinstance(value, dict) else None


def claimant_valid(faction):
    """A colony's parent faction id (colony_charter.dm): civ:<land>:<name>."""
    return isinstance(faction, str) and bool(_CLAIMANT.match(faction))


def tile_valid(x, y):
    return type(x) is int and type(y) is int and 0 <= x < CHART_WIDTH and 0 <= y < CHART_HEIGHT


def _hash01(seed, *parts):
    digest = hashlib.sha256(':'.join([seed] + [str(p) for p in parts]).encode('utf-8')).digest()
    return int.from_bytes(digest[:8], 'big') / float(1 << 64)


def _value_noise(seed, salt, x, y, scale):
    """Smooth noise in [0, 1): random values on a lattice every scale tiles,
    blended between lattice points."""
    gx, gy = x / float(scale), y / float(scale)
    x0, y0 = int(gx), int(gy)
    fx, fy = gx - x0, gy - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = _hash01(seed, salt, x0, y0), _hash01(seed, salt, x0 + 1, y0)
    c, d = _hash01(seed, salt, x0, y0 + 1), _hash01(seed, salt, x0 + 1, y0 + 1)
    top, bottom = a + (b - a) * fx, c + (d - c) * fx
    return top + (bottom - top) * fy


def elevation(seed, x, y):
    return 0.65 * _value_noise(seed, 'land', x, y, 8) + 0.35 * _value_noise(seed, 'land2', x, y, 3)


def biome_at(seed, x, y):
    """The biome of a land tile: warm at the middle row, cold at the top and
    bottom, with moisture deciding forest, grass, desert or swamp."""
    half = (CHART_HEIGHT - 1) / 2.0
    temperature = 1.0 - abs(y - half) / half + (_value_noise(seed, 'heat', x, y, 6) - 0.5) * 0.3
    moisture = _value_noise(seed, 'wet', x, y, 5)
    if temperature < 0.15:
        return 'ICE_SHEET'
    if temperature < 0.3:
        return 'TUNDRA'
    if temperature < 0.45:
        return 'BOREAL'
    if temperature < 0.7:
        return 'TEMPERATE_FOREST' if moisture >= 0.5 else 'GRASSLAND'
    if moisture < 0.35:
        return 'DESERT'
    if moisture < 0.55:
        return 'SAVANNA'
    if moisture < 0.78:
        return 'RAINFOREST'
    return 'SWAMP'


def _weighted(rng, weights):
    total = sum(w for _, w in weights)
    pick = rng.random() * total
    for item, weight in weights:
        pick -= weight
        if pick < 0:
            return item
    return weights[-1][0]


def roll_template(chart_seed, x, y, reroll, biome, coast):
    """The template of one land tile. The same inputs always give the same
    template; a reroll count gives a new one."""
    seed = '%s:%d:%d:r%d' % (chart_seed, x, y, reroll)
    rng = random.Random(hashlib.sha256(seed.encode('utf-8')).hexdigest())
    land_type = _weighted(rng, [(t, w) for t, w in zip(LAND_TYPES, LAND_TYPE_WEIGHTS[biome]) if w])
    size = _weighted(rng, [(s, SIZE_WEIGHTS[s]) for s in SIZES if s in SIZES_ENABLED])
    width, height = SIZE_TILES[size]
    # The real land is within about 15% of its size class.
    width = int(width * rng.uniform(0.85, 1.15))
    height = int(height * rng.uniform(0.85, 1.15))
    dry = biome in ('DESERT', 'ICE_SHEET')
    features = {
        'rivers': rng.randint(0, 1) if dry else rng.randint(1, 3) if land_type == 'RIVER_DELTA' else rng.randint(0, 2),
        'lakes': 0 if biome == 'DESERT' else rng.randint(0, 2),
        'ridges': rng.randint(1, 3) if land_type in ('HIGHLANDS', 'PLATEAU', 'FJORD_COAST') else rng.randint(0, 1),
        'caves': rng.random() < (0.8 if land_type in ('HIGHLANDS', 'VOLCANIC_ISLE', 'PLATEAU') else 0.4),
    }
    ores = rng.sample(ORES, rng.randint(2, 3))
    if land_type == 'VOLCANIC_ISLE':
        ores.append('obsidian')
    rare = []
    rare_chance = {'TINY': 0.6, 'SMALL': 0.4, 'MEDIUM': 0.25, 'LARGE': 0.15, 'MASSIVE': 0.1}[size]
    if rng.random() < rare_chance:
        rare.append(rng.choice(RARE_FINDS))
    game = rng.sample(GAME[biome], min(len(GAME[biome]), 2 if size in ('TINY', 'SMALL') else 3))
    return {
        'biome': biome, 'land_type': land_type, 'size': size, 'width': width, 'height': height,
        'coast': list(coast), 'features': features,
        'resources': {'ore': SIZE_ORE[size], 'ores': sorted(ores), 'rare': rare,
                      'fertility': SIZE_FERTILITY[size], 'game': sorted(game)},
        'seed': seed,
    }


class WorldChart:
    """The chart in a coordinator database (an open sqlite3 connection in
    autocommit mode). mainland names the region pinned at the chart's middle
    on a new chart. slots are the group's EXPEDITION regions and expeditions
    the folder where the host keeps them (<group root>/expeditions): without
    both, a course for a land nobody has opened is refused."""

    def __init__(self, db, mainland=None, slots=(), expeditions=None):
        self.db = db
        self.slots = [s for s in slots if isinstance(s, str) and s]
        self.expeditions = Path(expeditions) if expeditions else None
        db.execute('''CREATE TABLE IF NOT EXISTS chart_tile(
            x INTEGER NOT NULL, y INTEGER NOT NULL, template TEXT NOT NULL, reroll INTEGER NOT NULL,
            state TEXT NOT NULL, region TEXT, by TEXT, at INTEGER NOT NULL, PRIMARY KEY(x, y))''')
        db.execute('''CREATE TABLE IF NOT EXISTS chart_seen(
            owner TEXT NOT NULL, x INTEGER NOT NULL, y INTEGER NOT NULL, PRIMARY KEY(owner, x, y))''')
        db.execute('CREATE TABLE IF NOT EXISTS chart_pin(region TEXT PRIMARY KEY, x INTEGER NOT NULL, y INTEGER NOT NULL)')
        db.execute('CREATE TABLE IF NOT EXISTS chart_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)')
        db.execute('''CREATE TABLE IF NOT EXISTS chart_course(
            voyage TEXT PRIMARY KEY, owner TEXT NOT NULL, x INTEGER NOT NULL, y INTEGER NOT NULL, origin TEXT,
            slot TEXT, state TEXT NOT NULL, reason TEXT, at INTEGER NOT NULL)''')
        # A land opened in a slot: when, and when anyone was last there (for the 7 days).
        db.execute('''CREATE TABLE IF NOT EXISTS chart_landed(
            slot TEXT PRIMARY KEY, x INTEGER NOT NULL, y INTEGER NOT NULL, at INTEGER NOT NULL, visited INTEGER NOT NULL)''')
        # One claim per faction, one faction per land.
        db.execute('''CREATE TABLE IF NOT EXISTS chart_claim(
            faction TEXT PRIMARY KEY, x INTEGER NOT NULL, y INTEGER NOT NULL, by TEXT, at INTEGER NOT NULL)''')
        db.execute("INSERT OR IGNORE INTO chart_meta VALUES ('seed', ?)", (secrets.token_hex(8),))
        db.execute("INSERT OR IGNORE INTO chart_meta VALUES ('rev', '0')")
        if mainland and not db.execute('SELECT 1 FROM chart_pin LIMIT 1').fetchone():
            db.execute('INSERT INTO chart_pin VALUES (?, ?, ?)', (mainland, CHART_WIDTH // 2, CHART_HEIGHT // 2))

    def _meta(self, key):
        return self.db.execute('SELECT value FROM chart_meta WHERE key = ?', (key,)).fetchone()[0]

    def _bump(self):
        self.db.execute("UPDATE chart_meta SET value = ? WHERE key = 'rev'", (str(self.rev() + 1),))

    @property
    def seed(self):
        return self._meta('seed')

    def rev(self):
        return int(self._meta('rev'))

    def key(self):
        """Names this chart's version: a replaced chart never matches an old copy."""
        return '%s:%d' % (self.seed, self.rev())

    def pins(self):
        return {r: (x, y) for r, x, y in self.db.execute('SELECT region, x, y FROM chart_pin ORDER BY region')}

    def pin(self, region, x, y):
        """Puts a region (a mainland land) on a fixed tile. False for a bad
        tile or one that already holds a template or another pin."""
        if not tile_valid(x, y) or not isinstance(region, str) or not region:
            return False
        taken = {xy: r for r, xy in self.pins().items()}
        if taken.get((x, y), region) != region or self.db.execute(
                'SELECT 1 FROM chart_tile WHERE x = ? AND y = ?', (x, y)).fetchone():
            return False
        self.db.execute('INSERT OR REPLACE INTO chart_pin VALUES (?, ?, ?)', (region, x, y))
        self._bump()
        return True

    def terrain(self, x, y):
        """MAINLAND for a pinned tile, OCEAN, or the biome of a land tile. The
        chart's border and the ring round a pinned tile are always ocean, so
        every pinned land has open water to sail from."""
        pins = set(self.pins().values())
        if (x, y) in pins:
            return 'MAINLAND'
        if x in (0, CHART_WIDTH - 1) or y in (0, CHART_HEIGHT - 1):
            return 'OCEAN'
        if any(abs(px - x) <= 1 and abs(py - y) <= 1 for px, py in pins):
            return 'OCEAN'
        if elevation(self.seed, x, y) < 0.55:
            return 'OCEAN'
        return biome_at(self.seed, x, y)

    def coast(self, x, y):
        """The sides of a land tile that face open water: where a ship can
        land and leave. An inland tile has none and cannot be reached by sea."""
        return [side for side, dx, dy in SIDES
                if tile_valid(x + dx, y + dy) and self.terrain(x + dx, y + dy) == 'OCEAN']

    def template(self, x, y):
        row = self.db.execute('SELECT template, reroll, state, region, by, at FROM chart_tile WHERE x = ? AND y = ?',
                              (x, y)).fetchone()
        if not row:
            return None
        return {'template': json.loads(row[0]), 'reroll': row[1], 'state': row[2], 'region': row[3],
                'by': row[4], 'at': row[5]}

    def _roll(self, x, y, reroll, by, now):
        biome = self.terrain(x, y)
        template = roll_template(self.seed, x, y, reroll, biome, self.coast(x, y))
        self.db.execute('INSERT OR REPLACE INTO chart_tile VALUES (?, ?, ?, ?, ?, NULL, ?, ?)',
                        (x, y, json.dumps(template, sort_keys=True), reroll, 'CHARTED', by, now))
        return template

    def reveal(self, owner, x, y, radius=SIGHT, now=None):
        """A ship of owner sees the tiles within radius of (x, y). Each land
        tile nobody had seen gets its template now, once. Returns the newly
        charted tiles as {"x,y": template}; None for a bad request."""
        if not owner_valid(owner) or not tile_valid(x, y) or type(radius) is not int or not 0 <= radius <= 8:
            return None
        now = int(time.time() if now is None else now)
        rolled = {}
        changed = False
        for ty in range(max(0, y - radius), min(CHART_HEIGHT, y + radius + 1)):
            for tx in range(max(0, x - radius), min(CHART_WIDTH, x + radius + 1)):
                if self.db.execute('INSERT OR IGNORE INTO chart_seen VALUES (?, ?, ?)', (owner, tx, ty)).rowcount:
                    changed = True
                kind = self.terrain(tx, ty)
                if kind in ('OCEAN', 'MAINLAND') or self.template(tx, ty):
                    continue
                rolled['%d,%d' % (tx, ty)] = self._roll(tx, ty, 0, owner, now)
        if changed or rolled:
            self._bump()
        return rolled

    def reroll(self, x, y, by, now=None):
        """An admin's reroll: a new template for a charted tile that has no
        world yet. Returns the new template, or None when not allowed."""
        found = self.template(x, y) if tile_valid(x, y) else None
        if not found or found['state'] != 'CHARTED' or found['region'] or not account_key_valid(by):
            return None
        template = self._roll(x, y, found['reroll'] + 1, 'admin:' + by, int(time.time() if now is None else now))
        self._bump()
        return template

    def seen(self, owner):
        return {(x, y) for x, y in self.db.execute('SELECT x, y FROM chart_seen WHERE owner = ?', (owner,))}

    def text_rows(self, owner=None):
        """The chart as text, north at the top: '.' ocean, '@' mainland, a
        biome letter for land, '?' for tiles owner has not seen (owner None
        shows everything)."""
        seen = None if owner is None else self.seen(owner)
        rows = []
        for y in reversed(range(CHART_HEIGHT)):
            line = []
            for x in range(CHART_WIDTH):
                if seen is not None and (x, y) not in seen:
                    line.append(UNSEEN)
                    continue
                kind = self.terrain(x, y)
                line.append(OCEAN if kind == 'OCEAN' else MAINLAND if kind == 'MAINLAND' else BIOMES[kind][0])
            rows.append(''.join(line))
        return rows

    def snapshot(self, owner=None):
        """Everything a world shows on its chart: the text rows, every pinned
        land and every charted tile's template (owner's tiles only when an
        owner is given)."""
        seen = None if owner is None else self.seen(owner)
        tiles = {}
        for x, y in self.db.execute('SELECT x, y FROM chart_tile ORDER BY y, x'):
            if seen is None or (x, y) in seen:
                tiles['%d,%d' % (x, y)] = self.template(x, y)
        answer = {'key': self.key(), 'rev': self.rev(), 'width': CHART_WIDTH, 'height': CHART_HEIGHT, 'rows': self.text_rows(owner),
                  'pins': {r: list(xy) for r, xy in self.pins().items()}, 'tiles': tiles,
                  'sizes_enabled': list(SIZES_ENABLED)}
        if owner is None:
            # What each owner has seen, as a bitmap in hex (bit x of row y, row by
            # row from y = 0), and every course still kept: worlds show a crew its
            # own chart and wait on their ships' courses.
            answer['seen'] = {o: self.seen_mask(o) for (o,) in self.db.execute(
                'SELECT DISTINCT owner FROM chart_seen ORDER BY owner')}
            answer['courses'] = self.courses()
            answer['claims'] = self.claims()
        return answer

    def seen_mask(self, owner):
        bits = 0
        for x, y in self.seen(owner):
            bits |= 1 << (y * CHART_WIDTH + x)
        return '%0*x' % (CHART_WIDTH * CHART_HEIGHT // 4, bits)

    # -- courses -------------------------------------------------------------
    # A ship sets course for a land tile. The land needs a world: one already
    # opened for the tile, or a free expedition slot the host fills from the
    # tile's template while she sails (expedition_slots.py: the coordinator
    # writes <expeditions>/wanted/<slot>.json, the host builds and starts the
    # slot and records it in <expeditions>/slots/<slot>.json).

    def courses(self):
        return {v: {'owner': o, 'x': x, 'y': y, 'origin': origin, 'region': slot, 'state': state, 'reason': reason, 'at': at}
                for v, o, x, y, origin, slot, state, reason, at in self.db.execute(
                    'SELECT voyage, owner, x, y, origin, slot, state, reason, at FROM chart_course ORDER BY at, voyage')}

    def course(self, voyage):
        return self.courses().get(voyage)

    def _slot_record(self, slot):
        return _read_json(self.expeditions / SLOT_RECORDS / (slot + '.json')) if self.expeditions else None

    def slot_free(self, slot):
        """A slot the coordinator may give a land: no tile names it, the host
        holds it FREE and nothing waits for it or failed in it."""
        if not self.expeditions or slot not in self.slots:
            return False
        if self.db.execute('SELECT 1 FROM chart_tile WHERE region = ?', (slot,)).fetchone():
            return False
        record = self._slot_record(slot)
        if record is not None and record.get('state') != 'FREE':
            return False
        return not any((self.expeditions / folder / (slot + '.json')).exists()
                       for folder in (SLOT_WANTED, SLOT_FAILED, SLOT_ABANDONED))

    def slot_ready(self, slot, x, y):
        """True when the host has started slot on the land of tile (x, y)."""
        record = self._slot_record(slot)
        return bool(record) and record.get('state') == 'LAND' and record.get('key') == '%d,%d' % (x, y) \
            and record.get('phase') == 'started'

    def _refuse(self, voyage, owner, x, y, origin, reason, now):
        self.db.execute('INSERT INTO chart_course VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?)',
                        (voyage, owner, x, y, origin, 'REFUSED', reason, now))
        self._bump()
        return self.course(voyage)

    def set_course(self, voyage, owner, x, y, origin=None, now=None):
        """A ship of owner sets course for land tile (x, y). Returns the course
        ({'state': 'ASSIGNED' | 'READY' | 'REFUSED', 'region', 'reason'...}),
        the same one again for a voyage already decided, or None for a bad
        request."""
        if not voyage_valid(voyage) or not owner_valid(owner) or not tile_valid(x, y):
            return None
        found = self.course(voyage)
        if found:
            return found
        now = int(time.time() if now is None else now)
        origin = origin if isinstance(origin, str) and origin else None
        tile = self.template(x, y)
        if self.terrain(x, y) in ('OCEAN', 'MAINLAND') or not tile:
            return self._refuse(voyage, owner, x, y, origin, 'there is no charted land there', now)
        if (x, y) not in self.seen(owner):
            return self._refuse(voyage, owner, x, y, origin, 'your chart does not show that land', now)
        if tile['state'] == 'LOST':
            return self._refuse(voyage, owner, x, y, origin, 'that land was abandoned for good', now)
        if not tile['template'].get('coast'):
            return self._refuse(voyage, owner, x, y, origin, 'that land has no coast a ship can reach', now)
        slot = tile['region']
        if not slot:
            slot = next((s for s in self.slots if self.slot_free(s)), None)
            if not slot:
                return self._refuse(voyage, owner, x, y, origin, NO_SLOT, now)
            _write_json(self.expeditions / SLOT_WANTED / (slot + '.json'),
                        {'region': slot, 'key': '%d,%d' % (x, y), 'template': tile['template'], 'voyage': voyage, 'at': now})
            self.db.execute("UPDATE chart_tile SET region = ?, state = 'LANDED' WHERE x = ? AND y = ?", (slot, x, y))
            self.db.execute('INSERT OR REPLACE INTO chart_landed VALUES (?, ?, ?, ?, ?)', (slot, x, y, now, now))
        state = 'READY' if self.slot_ready(slot, x, y) else 'ASSIGNED'
        self.db.execute('INSERT INTO chart_course VALUES (?, ?, ?, ?, ?, ?, ?, NULL, ?)',
                        (voyage, owner, x, y, origin, slot, state, now))
        self._bump()
        return self.course(voyage)

    def refresh_courses(self, now=None):
        """Each coordinator pass: a course whose land the host has started is
        READY; one whose land could not be made is REFUSED and its tile is
        free for the next try (the template stays, so it gives the same land).
        Old courses are forgotten. True when anything changed."""
        now = int(time.time() if now is None else now)
        changed = False
        failed = {}
        for slot in self.slots:
            record = _read_json(self.expeditions / SLOT_FAILED / (slot + '.json')) if self.expeditions else None
            if record is not None:
                failed[slot] = record
        for slot, record in failed.items():
            key = str(record.get('key') or '')
            reason = 'the land could not be made ready: %s' % str(record.get('reason') or 'unknown')[:200]
            for voyage, x, y in self.db.execute(
                    "SELECT voyage, x, y FROM chart_course WHERE slot = ? AND state = 'ASSIGNED'", (slot,)).fetchall():
                if '%d,%d' % (x, y) == key:
                    self.db.execute("UPDATE chart_course SET state = 'REFUSED', reason = ? WHERE voyage = ?", (reason, voyage))
            self.db.execute("UPDATE chart_tile SET region = NULL, state = 'CHARTED' WHERE region = ? AND state = 'LANDED'",
                            (slot,))
            self.db.execute('DELETE FROM chart_landed WHERE slot = ?', (slot,))
            (self.expeditions / SLOT_FAILED / (slot + '.json')).unlink(missing_ok=True)
            changed = True
        for voyage, x, y, slot in self.db.execute(
                "SELECT voyage, x, y, slot FROM chart_course WHERE state = 'ASSIGNED'").fetchall():
            if self.slot_ready(slot, x, y):
                self.db.execute("UPDATE chart_course SET state = 'READY' WHERE voyage = ?", (voyage,))
                changed = True
        if self.db.execute('DELETE FROM chart_course WHERE at < ?', (now - COURSE_KEEP_SECONDS,)).rowcount:
            changed = True
        if changed:
            self._bump()
        return changed

    # -- settle, claim, abandon ----------------------------------------------
    # The world of a land asks on its crew's behalf (docs/expedition-lands.md
    # has the land; docs/ship-voyage.md the choices). origin is that world's
    # region: the land is the tile opened in it.

    def land_in(self, region):
        """(x, y, tile) of the land opened in region, or None."""
        row = self.db.execute('SELECT x, y FROM chart_tile WHERE region = ?', (region,)).fetchone() if region else None
        return (row[0], row[1], self.template(row[0], row[1])) if row else None

    def claims(self):
        return {f: '%d,%d' % (x, y) for f, x, y in self.db.execute('SELECT faction, x, y FROM chart_claim ORDER BY faction')}

    def visit(self, region, now=None):
        """Someone is on the land in region now: its 7 days start again."""
        now = int(time.time() if now is None else now)
        return self.db.execute('UPDATE chart_landed SET visited = ? WHERE slot = ? AND visited < ?',
                               (now, region, now)).rowcount > 0

    def settle(self, region, by=None, now=None):
        """A crew settled the land in region: it stays, on everyone's chart. True when it changed."""
        found = self.land_in(region)
        if not found or found[2]['state'] != 'LANDED':
            return False
        self.db.execute("UPDATE chart_tile SET state = 'SETTLED', by = ? WHERE region = ?", (by, region))
        self._bump()
        return True

    def claim(self, region, faction, by=None, now=None):
        """faction planted its colony charter on the land in region. One claim
        per faction and one faction per land. True when it changed."""
        found = self.land_in(region)
        if not found or not claimant_valid(faction) or found[2]['state'] not in ('LANDED', 'SETTLED'):
            return False
        x, y, _ = found
        if self.db.execute('SELECT 1 FROM chart_claim WHERE faction = ? OR (x = ? AND y = ?)', (faction, x, y)).fetchone():
            return False
        now = int(time.time() if now is None else now)
        self.db.execute('INSERT INTO chart_claim VALUES (?, ?, ?, ?, ?)', (faction, x, y, by, now))
        self.db.execute("UPDATE chart_tile SET state = 'CLAIMED', by = ? WHERE region = ?", (by, region))
        self._bump()
        return True

    def abandon(self, region, by=None, now=None):
        """The land in region is given up for good: its tile is LOST and the
        host asked to archive the slot (<expeditions>/abandon/<slot>.json).
        Only a land nobody settled or claimed. True when it changed."""
        found = self.land_in(region)
        if not found or found[2]['state'] != 'LANDED':
            return False
        x, y, _ = found
        now = int(time.time() if now is None else now)
        if self.expeditions:
            _write_json(self.expeditions / SLOT_ABANDONED / (region + '.json'),
                        {'region': region, 'key': '%d,%d' % (x, y), 'by': by, 'at': now})
        self.db.execute("UPDATE chart_tile SET state = 'LOST', region = NULL, by = ? WHERE x = ? AND y = ?", (by, x, y))
        self.db.execute('DELETE FROM chart_landed WHERE slot = ?', (region,))
        self.db.execute("UPDATE chart_course SET state = 'REFUSED', reason = 'that land was abandoned for good' "
                        "WHERE slot = ? AND state != 'REFUSED'", (region,))
        self._bump()
        return True

    def expire(self, now=None):
        """Lands nobody settled or claimed and nobody visited for 7 days are
        abandoned. Returns their regions."""
        now = int(time.time() if now is None else now)
        gone = []
        for slot, x, y in self.db.execute('SELECT slot, x, y FROM chart_landed WHERE visited < ?',
                                          (now - UNVISITED_SECONDS,)).fetchall():
            tile = self.template(x, y)
            if tile and tile['state'] == 'LANDED' and tile['region'] == slot and self.abandon(slot, 'timeout', now):
                gone.append(slot)
        return gone
