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
# enabled sizes are rolled. Medium is Gaia's size; the largest massive land was
# measured as a one-level land (docs/expedition-lands.md).
SIZES = ('TINY', 'SMALL', 'MEDIUM', 'LARGE', 'MASSIVE')
SIZE_TILES = {'TINY': (200, 200), 'SMALL': (300, 300), 'MEDIUM': (500, 350), 'LARGE': (500, 500), 'MASSIVE': (600, 600)}
SIZE_WEIGHTS = {'TINY': 4, 'SMALL': 6, 'MEDIUM': 8, 'LARGE': 4, 'MASSIVE': 2}
SIZES_ENABLED = SIZES
# Smaller lands are richer per tile; larger ones feed a settlement better.
SIZE_ORE = {'TINY': 'rich', 'SMALL': 'good', 'MEDIUM': 'fair', 'LARGE': 'thin', 'MASSIVE': 'poor'}
SIZE_FERTILITY = {'TINY': 'poor', 'SMALL': 'thin', 'MEDIUM': 'fair', 'LARGE': 'good', 'MASSIVE': 'rich'}

# Every name below is one the slot world places (code/modules/naval/land_resources.dm):
# ores are extra lodes when mining, game names are ecology species.
ORES = ('iron', 'copper', 'tin', 'coal', 'flint', 'gold', 'silver', 'zinc', 'lead', 'saltpeter', 'sulphur')
RARE_FINDS = ('gems', 'rich gold vein', 'rich silver vein', 'diamonds')
GAME = {
    'ICE_SHEET': ('polar bear', 'penguin', 'white wolf'),
    'TUNDRA': ('reindeer', 'arctic fox', 'white wolf', 'polar bear'),
    'BOREAL': ('elk', 'brown bear', 'wolf', 'reindeer', 'deer'),
    'TEMPERATE_FOREST': ('deer', 'wild boar', 'black bear', 'wolf', 'turkey'),
    'GRASSLAND': ('bison', 'horse', 'rabbit', 'cattle', 'wolf'),
    'DESERT': ('camel', 'lizard', 'cobra', 'goat'),
    'SAVANNA': ('dik-dik', 'lion', 'buffalo', 'monkey'),
    'RAINFOREST': ('monkey', 'parrot', 'jaguar', 'gorilla', 'constrictor'),
    'SWAMP': ('alligator', 'frog', 'wild boar', 'leech', 'constrictor'),
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
# Who may claim a land: a faction (its colony's parent, civ:<land>:<name>) or one
# player for themself (crew:<ckey>). Each claims one land, so a player may hold
# a land of their own and their faction another.
# Who may land on a faction's claimed island (island_access.dm): anyone
# (OPEN), its members and the people and pass holders it names (GUESTS, the
# default), or its members alone (MEMBERS: the border is closed).
ACCESS_MODES = ('OPEN', 'GUESTS', 'MEMBERS')
ACCESS_DEFAULT = 'GUESTS'
ACCESS_PEOPLE_MAX = 50
ACCESS_PASSES_MAX = 100
ACCESS_PASS_HOURS_MAX = 168

_CLAIMANT = re.compile(r'^(civ:[a-z0-9_\-]{1,40}:[^\x00-\x1f]{1,60}|crew:[a-z0-9_\-]{1,40})$')
NO_SLOT = 'every harbour master is busy: no new land can be opened for a crew right now. Try a land that is already open, or wait.'
# Crews open lands by themselves (no admin decides), so the chart keeps them in
# bounds (docs/world-chart.md#opening-new-lands). An owner, or the account at
# the tiller, opens one new land in this long, and none while a land it opened
# still stands undecided.
OPEN_COOLDOWN_SECONDS = 3 * 3600
# Slots are the lands awake at once, not the lands there are. With every slot
# taken, the land nobody has been on longest, and at least this long, is parked:
# the host moves its save aside (expedition_slots.park) and frees the slot. A
# parked land keeps its state and is restored into any free slot when a ship
# sets course for it or somebody who lives there comes back.
PARK_IDLE_SECONDS = 3600
PARK_GIVE_UP_SECONDS = 3600  # a parking the host never carried out is forgotten
COURSE_UNDER_WAY_SECONDS = 2 * 3600  # a land with a course this fresh has a ship coming
SLOT_PARK = 'park'
SLOT_DISCARD = 'discard'
CLEARING = 'a harbour is being cleared for a new land. Set out for it again in about ten minutes.'
# Val (2026-11-22): how many lands, faction islands among them, can exist or run
# at once is never capped for the host. With every slot taken and no idle land to
# lay up, the coordinator asks the host for one more slot (<expeditions>/grow/).
SLOT_GROW = 'grow'
GROW_WISH = 'request.json'
GROWING = 'a new harbour is being built for that land. Set out for it again in a few minutes.'

_VOYAGE = re.compile(r'^[a-z0-9_\-]{1,80}$')
_OWNER = re.compile(r'^(admin|faction:[a-z0-9_\-]{1,40}|crew:[a-z0-9_\-]{1,40})$')


def land_home(x, y):
    """The home of an account whose character is on the parked land of tile
    (x, y): no region, until the land has a slot again."""
    return 'land:%d,%d' % (x, y)


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
        # Who opened the land of a tile, and when: one undecided land an owner, and the wait between new lands.
        db.execute('''CREATE TABLE IF NOT EXISTS chart_opened(
            x INTEGER NOT NULL, y INTEGER NOT NULL, slot TEXT NOT NULL, owner TEXT NOT NULL, by TEXT,
            at INTEGER NOT NULL, PRIMARY KEY(x, y))''')
        # A parked land: when, when anyone was last there, and what the coordinator keeps for it (its land stage).
        db.execute('''CREATE TABLE IF NOT EXISTS chart_parked(
            x INTEGER NOT NULL, y INTEGER NOT NULL, at INTEGER NOT NULL, visited INTEGER NOT NULL, kept TEXT,
            PRIMARY KEY(x, y))''')
        # A parking asked of the host and not yet carried out.
        db.execute('''CREATE TABLE IF NOT EXISTS chart_parking(
            slot TEXT PRIMARY KEY, x INTEGER NOT NULL, y INTEGER NOT NULL, at INTEGER NOT NULL)''')
        # For the coordinator (Coordinator.chart_moves): lands parked, (slot, x, y), and
        # lands given a slot again, (slot, x, y, kept), since it last asked.
        self.parked_now, self.restored_now = [], []
        # One claim per faction, one faction per land.
        db.execute('''CREATE TABLE IF NOT EXISTS chart_claim(
            faction TEXT PRIMARY KEY, x INTEGER NOT NULL, y INTEGER NOT NULL, by TEXT, at INTEGER NOT NULL)''')
        # Who a faction lets land on its claimed island: a mode, the accounts it
        # names and visitor passes (account -> when it runs out, unix seconds).
        db.execute('''CREATE TABLE IF NOT EXISTS chart_access(
            faction TEXT PRIMARY KEY, mode TEXT NOT NULL, people TEXT NOT NULL, passes TEXT NOT NULL,
            by TEXT, at INTEGER NOT NULL)''')
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
        tile = {'template': json.loads(row[0]), 'reroll': row[1], 'state': row[2], 'region': row[3],
                'by': row[4], 'at': row[5]}
        if not row[3] and self.parked(x, y):
            tile['parked'] = True
        return tile

    def parked(self, x, y):
        """(at, visited, kept) of a parked land, or None."""
        return self.db.execute('SELECT at, visited, kept FROM chart_parked WHERE x = ? AND y = ?', (x, y)).fetchone()

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
            answer['access'] = self.access()
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
                       for folder in (SLOT_WANTED, SLOT_FAILED, SLOT_ABANDONED, SLOT_PARK))

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

    def open_refusal(self, owner, by, now):
        """Why owner (the account by at the tiller) may not open a new land now, or None."""
        who = (owner, by or '')
        row = self.db.execute(
            "SELECT o.x, o.y FROM chart_opened o JOIN chart_tile t ON t.x = o.x AND t.y = o.y "
            "WHERE t.state = 'LANDED' AND (o.owner = ? OR o.by = ?) ORDER BY o.at LIMIT 1",
            who).fetchone()
        if row:
            return ('your crew still has the land at %d,%d undecided: settle it, or give it up as you leave it, '
                    'before opening another' % row)
        last = self.db.execute('SELECT MAX(at) FROM chart_opened WHERE owner = ? OR by = ?', who).fetchone()[0]
        if last is not None and 0 <= now - last < OPEN_COOLDOWN_SECONDS:
            return ('your crew opened a new land not long ago. Another can be opened in about %d minutes; '
                    'lands already open can be sailed for now' % max(1, (last + OPEN_COOLDOWN_SECONDS - now + 59) // 60))
        return None

    def make_room(self, now):
        """With no slot free: asks the host to park the land nobody has been on
        longest, at least PARK_IDLE_SECONDS, with no ship on her way to it.
        Returns its slot or None. The slot is free once the host has parked it
        (refresh_parks)."""
        coming = {slot for (slot,) in self.db.execute(
            "SELECT DISTINCT slot FROM chart_course WHERE state IN ('ASSIGNED', 'READY') AND at > ?",
            (now - COURSE_UNDER_WAY_SECONDS,))}
        for slot, x, y, visited in self.db.execute('SELECT slot, x, y, visited FROM chart_landed ORDER BY visited, slot').fetchall():
            tile = self.template(x, y)
            if not tile or tile['region'] != slot or tile['state'] not in ('LANDED', 'SETTLED', 'CLAIMED'):
                continue
            if now - visited < PARK_IDLE_SECONDS or slot in coming or not self.slot_ready(slot, x, y):
                continue
            if self.db.execute('SELECT 1 FROM chart_parking WHERE slot = ?', (slot,)).fetchone():
                continue
            _write_json(self.expeditions / SLOT_PARK / (slot + '.json'),
                        {'region': slot, 'key': '%d,%d' % (x, y), 'at': now})
            self.db.execute('INSERT INTO chart_parking VALUES (?, ?, ?, ?)', (slot, x, y, now))
            return slot
        return None

    def request_slot(self, now):
        """Asks the host for one more slot (<expeditions>/grow/request.json):
        every slot is taken and no land is idle enough to lay up. The host adds
        it, set up and stopped, and the coordinator is restarted with it. True
        when the wish stands (now or already)."""
        if not self.expeditions:
            return False
        wish = self.expeditions / SLOT_GROW / GROW_WISH
        if not wish.exists():
            _write_json(wish, {'at': now, 'slots': len(self.slots)})
        return True

    def refresh_parks(self, now):
        """A parking the host carried out takes the land off its slot; one it
        called off (somebody was there) or never did is forgotten. True when
        the chart changed."""
        changed = False
        for slot, x, y, at in self.db.execute('SELECT slot, x, y, at FROM chart_parking').fetchall():
            wish = self.expeditions / SLOT_PARK / (slot + '.json') if self.expeditions else None
            if wish is not None and wish.exists():
                if now - at > PARK_GIVE_UP_SECONDS:
                    wish.unlink(missing_ok=True)
                    self.db.execute('DELETE FROM chart_parking WHERE slot = ?', (slot,))
                continue
            self.db.execute('DELETE FROM chart_parking WHERE slot = ?', (slot,))
            record = self._slot_record(slot)
            tile = self.template(x, y)
            if not tile or tile['region'] != slot:
                continue
            if record is not None and record.get('state') == 'LAND' and record.get('key') == '%d,%d' % (x, y):
                continue  # called off: the land is still in its slot
            self._park(slot, x, y, now)
            changed = True
        return changed

    def _park(self, slot, x, y, now, kept=None):
        """The land of tile (x, y) is off slot and in the parked folder."""
        row = self.db.execute('SELECT visited FROM chart_landed WHERE slot = ?', (slot,)).fetchone()
        self.db.execute('UPDATE chart_tile SET region = NULL WHERE x = ? AND y = ?', (x, y))
        self.db.execute('DELETE FROM chart_landed WHERE slot = ?', (slot,))
        self.db.execute('INSERT OR REPLACE INTO chart_parked VALUES (?, ?, ?, ?, ?)', (x, y, now, row[0] if row else now, kept))
        self.db.execute("UPDATE chart_course SET state = 'REFUSED', reason = ? WHERE slot = ? AND state != 'REFUSED'",
                        ('that land was laid up while nobody was there. Set out for it again and its harbour is made ready', slot))
        self.parked_now.append((slot, x, y))
        self._bump()

    def keep(self, x, y, kept):
        """What the coordinator wants back when the parked land of (x, y) is restored."""
        self.db.execute('UPDATE chart_parked SET kept = ? WHERE x = ? AND y = ?', (kept, x, y))

    def clearing(self):
        """True while the host still has a land to archive or park."""
        if not self.expeditions:
            return False
        if self.db.execute('SELECT 1 FROM chart_parking LIMIT 1').fetchone():
            return True
        return any((self.expeditions / SLOT_ABANDONED / (slot + '.json')).exists() for slot in self.slots)

    def place(self, x, y, voyage=None, now=None):
        """Gives the land of tile (x, y), which has no world, a slot: a new land
        is generated there, a parked one restored. Returns (slot, None) or
        (None, why not)."""
        now = int(time.time() if now is None else now)
        tile = self.template(x, y)
        slot = next((s for s in self.slots if self.slot_free(s)), None)
        if not slot:
            # A land being archived or parked frees its slot soon; else the stalest empty land is parked.
            # With nothing to lay up, the host is asked for one more slot: lands are never capped.
            if self.clearing() or self.make_room(now):
                return None, CLEARING
            return None, (GROWING if self.request_slot(now) else NO_SLOT)
        parked = self.parked(x, y)
        _write_json(self.expeditions / SLOT_WANTED / (slot + '.json'),
                    {'region': slot, 'key': '%d,%d' % (x, y), 'template': tile['template'], 'voyage': voyage, 'at': now,
                     'parked': bool(parked)})
        self.db.execute('INSERT OR REPLACE INTO chart_landed VALUES (?, ?, ?, ?, ?)', (slot, x, y, now, now))
        if parked:
            # It keeps its state; its 7 days and its hour start again as it wakes.
            self.db.execute('UPDATE chart_tile SET region = ? WHERE x = ? AND y = ?', (slot, x, y))
            self.db.execute('DELETE FROM chart_parked WHERE x = ? AND y = ?', (x, y))
            self.restored_now.append((slot, x, y, parked[2]))
        else:
            self.db.execute("UPDATE chart_tile SET region = ?, state = 'LANDED' WHERE x = ? AND y = ?", (slot, x, y))
        self._bump()
        return slot, None

    def summon(self, x, y, now=None):
        """Somebody who lives on the parked land of (x, y) came back: it is
        given a slot again. True when it has one (now or already)."""
        tile = self.template(x, y) if tile_valid(x, y) else None
        if not tile or tile['state'] not in ('LANDED', 'SETTLED', 'CLAIMED'):
            return False
        if tile['region']:
            return True
        return bool(self.parked(x, y)) and self.place(x, y, None, now)[0] is not None

    def set_course(self, voyage, owner, x, y, origin=None, now=None, by=None):
        """A ship of owner sets course for land tile (x, y); by is the account
        at her tiller. Returns the course ({'state': 'ASSIGNED' | 'READY' |
        'REFUSED', 'region', 'reason'...}), the same one again for a voyage
        already decided, or None for a bad request."""
        if not voyage_valid(voyage) or not owner_valid(owner) or not tile_valid(x, y):
            return None
        found = self.course(voyage)
        if found:
            return found
        now = int(time.time() if now is None else now)
        origin = origin if isinstance(origin, str) and origin else None
        by = by if isinstance(by, str) and by else None
        tile = self.template(x, y)
        if self.terrain(x, y) in ('OCEAN', 'MAINLAND') or not tile:
            return self._refuse(voyage, owner, x, y, origin, 'there is no charted land there', now)
        if (x, y) not in self.seen(owner) and tile['state'] not in ('SETTLED', 'CLAIMED'):
            return self._refuse(voyage, owner, x, y, origin, 'your chart does not show that land', now)
        if tile['state'] == 'LOST':
            return self._refuse(voyage, owner, x, y, origin, 'that land was abandoned for good', now)
        if not tile['template'].get('coast'):
            return self._refuse(voyage, owner, x, y, origin, 'that land has no coast a ship can reach', now)
        slot = tile['region']
        if not slot:
            new = not self.parked(x, y)
            reason = self.open_refusal(owner, by, now) if new else None
            if reason:
                return self._refuse(voyage, owner, x, y, origin, reason, now)
            slot, reason = self.place(x, y, voyage, now)
            if not slot:
                return self._refuse(voyage, owner, x, y, origin, reason, now)
            if new:
                self.db.execute('INSERT OR REPLACE INTO chart_opened VALUES (?, ?, ?, ?, ?, ?)', (x, y, slot, owner, by, now))
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
        if self.expeditions and self.refresh_parks(now):
            changed = True
        for slot, record in failed.items():
            key = str(record.get('key') or '')
            if record.get('parked'):
                # A parked land that could not be restored is parked still: nothing of it is lost.
                for voyage, x, y in self.db.execute(
                        "SELECT voyage, x, y FROM chart_course WHERE slot = ? AND state = 'ASSIGNED'", (slot,)).fetchall():
                    if '%d,%d' % (x, y) == key:
                        self.db.execute("UPDATE chart_course SET state = 'REFUSED', reason = ? WHERE voyage = ?",
                                        ('its harbour could not be made ready: %s' % str(record.get('reason') or 'unknown')[:200], voyage))
                row = self.db.execute('SELECT x, y FROM chart_tile WHERE region = ?', (slot,)).fetchone()
                if row and '%d,%d' % row == key:
                    self._park(slot, row[0], row[1], now)
                (self.expeditions / SLOT_FAILED / (slot + '.json')).unlink(missing_ok=True)
                changed = True
                continue
            reason = 'the land could not be made ready: %s' % str(record.get('reason') or 'unknown')[:200]
            for voyage, x, y in self.db.execute(
                    "SELECT voyage, x, y FROM chart_course WHERE slot = ? AND state = 'ASSIGNED'", (slot,)).fetchall():
                if '%d,%d' % (x, y) == key:
                    self.db.execute("UPDATE chart_course SET state = 'REFUSED', reason = ? WHERE voyage = ?", (reason, voyage))
            # A land that never opened costs its crew no wait.
            self.db.execute("DELETE FROM chart_opened WHERE slot = ? AND EXISTS (SELECT 1 FROM chart_tile t WHERE "
                            "t.x = chart_opened.x AND t.y = chart_opened.y AND t.region = ? AND t.state = 'LANDED')", (slot, slot))
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

    # -- island access (island_access.dm) --------------------------------------
    # A faction's claimed island takes only those its leader or officers let
    # land. Worlds check the rows before anyone sets out for the island, and
    # the island turns away whoever is ashore without leave.

    def _access_row(self, faction):
        row = self.db.execute('SELECT mode, people, passes FROM chart_access WHERE faction = ?', (faction,)).fetchone()
        if not row:
            return {'mode': ACCESS_DEFAULT, 'people': [], 'passes': {}}
        try:
            people, passes = json.loads(row[1]), json.loads(row[2])
        except ValueError:
            people, passes = [], {}
        return {'mode': row[0] if row[0] in ACCESS_MODES else ACCESS_DEFAULT,
                'people': [p for p in people if account_key_valid(p)] if type(people) is list else [],
                'passes': {a: t for a, t in passes.items() if account_key_valid(a) and type(t) is int}
                if type(passes) is dict else {}}

    def _access_claimed(self, faction):
        """True when faction (a civ: id, never a player) holds a claim."""
        return isinstance(faction, str) and faction.startswith('civ:') and claimant_valid(faction) \
            and faction in self.claims()

    def _access_write(self, faction, row, by, now):
        self.db.execute('INSERT OR REPLACE INTO chart_access VALUES (?, ?, ?, ?, ?, ?)',
                        (faction, row['mode'], json.dumps(sorted(set(row['people']))),
                         json.dumps(row['passes'], sort_keys=True), by, now))
        self._bump()

    def access(self, now=None):
        """Every claimed island's access: faction -> mode, people and the
        passes still running (account -> unix seconds they run out)."""
        now = int(time.time() if now is None else now)
        answer = {}
        for faction in self.claims():
            if not faction.startswith('civ:'):
                continue
            row = self._access_row(faction)
            row['passes'] = {a: t for a, t in row['passes'].items() if t > now}
            answer[faction] = row
        return answer

    def set_access(self, faction, mode, people, by=None, now=None):
        """faction's leader or officers set who may land on its island. True when taken."""
        if mode not in ACCESS_MODES or type(people) is not list or len(people) > ACCESS_PEOPLE_MAX \
                or not all(account_key_valid(p) for p in people) or not self._access_claimed(faction):
            return False
        now = int(time.time() if now is None else now)
        row = self._access_row(faction)
        row['mode'], row['people'] = mode, people
        row['passes'] = {a: t for a, t in row['passes'].items() if t > now}
        self._access_write(faction, row, by, now)
        return True

    def grant_pass(self, faction, account, hours, by=None, now=None):
        """A visitor pass to faction's island for account, for hours (0 takes it back). True when taken."""
        if not account_key_valid(account) or type(hours) is not int or not 0 <= hours <= ACCESS_PASS_HOURS_MAX \
                or not self._access_claimed(faction):
            return False
        now = int(time.time() if now is None else now)
        row = self._access_row(faction)
        passes = {a: t for a, t in row['passes'].items() if t > now and a != account}
        if hours:
            if len(passes) >= ACCESS_PASSES_MAX:
                return False
            passes[account] = now + hours * 3600
        row['passes'] = passes
        self._access_write(faction, row, by, now)
        return True

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
        """faction planted its colony charter on the land in region, or a
        player (crew:<ckey>) claimed it for themself. One claim per claimant
        and one claimant per land. True when it changed."""
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

    def unclaim(self, region, faction, by=None, now=None):
        """faction gives up its claim on the land in region: the land drops back
        to SETTLED and stays, and the faction may claim another. True when it changed."""
        found = self.land_in(region)
        if not found or not claimant_valid(faction) or found[2]['state'] != 'CLAIMED':
            return False
        x, y, _ = found
        if not self.db.execute('DELETE FROM chart_claim WHERE faction = ? AND x = ? AND y = ?', (faction, x, y)).rowcount:
            return False
        # A land given up or lapsed is open to every ship again.
        self.db.execute('DELETE FROM chart_access WHERE faction = ?', (faction,))
        self.db.execute("UPDATE chart_tile SET state = 'SETTLED', by = ? WHERE region = ?", (by, region))
        self._bump()
        return True

    def abandon(self, region, by=None, now=None):
        """The land in region is given up for good: its tile is LOST and the
        host asked to archive the slot (<expeditions>/abandon/<slot>.json).
        Only a land nobody settled or claimed. True when it changed."""
        found = self.land_in(region)
        if not found or found[2]['state'] != 'LANDED':
            return False
        return self._lose(region, by, now)

    def _lose(self, region, by=None, now=None):
        """The land in region, whatever its state, is lost for good."""
        found = self.land_in(region)
        if not found or found[2]['state'] not in ('LANDED', 'SETTLED', 'CLAIMED'):
            return False
        x, y, _ = found
        now = int(time.time() if now is None else now)
        if self.expeditions:
            _write_json(self.expeditions / SLOT_ABANDONED / (region + '.json'),
                        {'region': region, 'key': '%d,%d' % (x, y), 'by': by, 'at': now})
        self.db.execute("UPDATE chart_tile SET state = 'LOST', region = NULL, by = ? WHERE x = ? AND y = ?", (by, x, y))
        self.db.execute('DELETE FROM chart_landed WHERE slot = ?', (region,))
        self.db.execute('DELETE FROM chart_access WHERE faction IN (SELECT faction FROM chart_claim WHERE x = ? AND y = ?)', (x, y))
        self.db.execute('DELETE FROM chart_claim WHERE x = ? AND y = ?', (x, y))
        self.db.execute("UPDATE chart_course SET state = 'REFUSED', reason = 'that land was abandoned for good' "
                        "WHERE slot = ? AND state != 'REFUSED'", (region,))
        self._bump()
        return True

    def expire(self, now=None):
        """Lands nobody settled or claimed and nobody visited for 7 days are
        abandoned, parked ones too. Returns what the coordinator must forget:
        their regions, or 'land:x,y' for a parked one."""
        now = int(time.time() if now is None else now)
        gone = []
        # Forget who opened what once the wait is over and the land is decided or gone.
        self.db.execute("DELETE FROM chart_opened WHERE at < ? AND NOT EXISTS (SELECT 1 FROM chart_tile t WHERE "
                        "t.x = chart_opened.x AND t.y = chart_opened.y AND t.state = 'LANDED')",
                        (now - OPEN_COOLDOWN_SECONDS,))
        for slot, x, y in self.db.execute('SELECT slot, x, y FROM chart_landed WHERE visited < ?',
                                          (now - UNVISITED_SECONDS,)).fetchall():
            tile = self.template(x, y)
            if tile and tile['state'] == 'LANDED' and tile['region'] == slot and self.abandon(slot, 'timeout', now):
                gone.append(slot)
        for x, y in self.db.execute('SELECT x, y FROM chart_parked WHERE visited < ?', (now - UNVISITED_SECONDS,)).fetchall():
            tile = self.template(x, y)
            if not tile or tile['state'] != 'LANDED':
                continue
            if self.expeditions:
                _write_json(self.expeditions / SLOT_DISCARD / ('%d-%d.json' % (x, y)), {'key': '%d,%d' % (x, y), 'at': now})
            self.db.execute("UPDATE chart_tile SET state = 'LOST', region = NULL, by = 'timeout' WHERE x = ? AND y = ?", (x, y))
            self.db.execute('DELETE FROM chart_parked WHERE x = ? AND y = ?', (x, y))
            self._bump()
            gone.append(land_home(x, y))
        return gone
