"""SQLite transfer state for one region (one DreamDaemon world).

Implements the design in tools/server-management/TRANSFER-STORAGE-SQLITE.md:
world effects are recorded as tentative before the world applies them, and are
confirmed only by a committed world save that lists them. Envelopes for a step
are written to the outbox only after the effects behind that step are
confirmed. Standard library only.

Character effects may instead be journaled: confirmed at once, with their
payloads kept in the journal until a world save lists them. A load whose save
lacks a journaled effect gets it back to replay, so a trip takes seconds rather
than two world saves.
"""
import hashlib
import re
import secrets
import json
import sqlite3
import time
from tools.transfer_storage.train import validate as validate_train
from tools.transfer_storage.train_lease import TrainLeaseQueue
from tools.transfer_storage import records as player_records

SCHEMA_VERSION = 1

# Directions are from this region's point of view.
OUT, IN = 'out', 'in'

# Source phases (direction OUT).
REQUESTED = 'Requested'            # escrow removal tentative, nothing sent yet
ESCROWED = 'Escrowed'              # removal confirmed, ESCROW in outbox
COMMIT_DECIDED = 'CommitDecided'   # irreversible; COMMIT in outbox
ABORT_DECIDED = 'AbortDecided'     # before commit only; ABORT in outbox
RETURNING = 'Returning'            # tombstone received; return applied or due
# Destination phases (direction IN).
TRAIN_ADMISSION = 'TrainAdmission' # destination must reserve the entire footprint
PREPARED = 'Prepared'              # PREPARE in outbox
COMMIT_RECEIVED = 'CommitReceived' # import may run
IMPORTED = 'Imported'              # credit confirmed, IMPORTED in outbox
DESTINATION_ABORTED = 'DestinationAborted'  # TOMBSTONE in outbox

REMOVE, CREDIT, RETURN = 'remove', 'credit', 'return'
TENTATIVE, CONFIRMED, JOURNALED = 'tentative', 'confirmed', 'journaled'


ACCOUNT_OPS = ('claim', 'arrive', 'depart', 'release', 'colony', 'colony_used', 'start')

# A land's settlement stage (docs/land-stages.md). The mainland is always
# MAINLAND; the coordinator keeps every other land's stage.
LAND_STAGES = ('CLOSED', 'FRONTIER', 'COLONY', 'OPEN')


def land_id_valid(region):
    """A region id as shard_region.json allows: a-z, 0-9, - and _, 1 to 32 characters."""
    return isinstance(region, str) and 0 < len(region) <= 32 and all(
        c.isdigit() or ('a' <= c <= 'z') or c in '-_' for c in region)


def land_stage_valid(entry):
    """One land's stage record as the coordinator sends it."""
    return (type(entry) is dict and entry.get('stage') in LAND_STAGES + ('MAINLAND',)
            and entry.get('paused') in (True, False) and (entry.get('by') is None or account_key_valid(entry.get('by')))
            and isinstance(entry.get('at'), int))



MAX_COLONIES = 50
MAX_NATIONS = 200
MAX_NATION_REQUESTS = 200
NATION_RESULT_SECONDS = 7 * 24 * 3600
FACTION_NAME_MAX = 64


def faction_id_valid(value):
    """A faction named with the land it was founded in: civ:<land>:<name>
    (party_train.dm party_train_faction_party)."""
    if type(value) is not str or len(value) > 100 or not value.startswith('civ:'):
        return False
    land, sep, name = value[4:].partition(':')
    return bool(sep) and land_id_valid(land) and 0 < len(name) <= FACTION_NAME_MAX


def colony_valid(c):
    return (type(c) is dict and faction_id_valid(c.get('parent')) and type(c.get('name')) is str
            and 0 < len(c['name']) <= FACTION_NAME_MAX and type(c.get('age_hours')) is int
            and 0 <= c['age_hours'] <= 1_000_000 and type(c.get('members')) is int and 0 <= c['members'] <= 1000)

def account_key_valid(ckey):
    """A BYOND ckey: lowercase letters, digits and @, 1 to 32 characters. A character
    slot key is "@<slot><ckey>" (docs/character-slots.md), so it may run two longer."""
    limit = 34 if isinstance(ckey, str) and ckey.startswith('@') else 32
    return isinstance(ckey, str) and 0 < len(ckey) <= limit and all(c.isdigit() or ('a' <= c <= 'z') or c == '@' for c in ckey)



def _chart_request_row(row):
    """A queued chart request as the coordinator reads it (data decoded)."""
    request = dict(zip(('id', 'op', 'x', 'y', 'owner', 'admin', 'voyage'), row[:7]))
    if row[7]:
        try:
            request['data'] = json.loads(row[7])
        except ValueError:
            pass
    return request


ISLAND_ACCESS_MODES = ('OPEN', 'GUESTS', 'MEMBERS')


def island_access_change_valid(data):
    """An access edit changes exactly one field or one named guest."""
    if type(data) is not dict or len(data) != 1:
        return False
    field, value = next(iter(data.items()))
    if field == 'mode':
        return value in ISLAND_ACCESS_MODES
    return field in ('add_guest', 'remove_guest') and account_key_valid(value)


def _island_access_data(op, data):
    """The checked fields of an island 'access' or 'pass' request (island_access.dm)."""
    if type(data) is not dict:
        raise TransferError('bad island access')
    if op == 'access':
        if not island_access_change_valid(data):
            raise TransferError('bad island access')
        return data
    account, hours = data.get('account'), data.get('hours')
    if not account_key_valid(account) or type(hours) is not int or not 0 <= hours <= 168:
        raise TransferError('bad visitor pass')
    return {'account': account, 'hours': hours}

class TransferError(Exception):
    """A request that the current state refuses. Nothing was changed."""


class RegionHeld(TransferError):
    """The region is on hold (for example after an older backup was loaded)."""


def transfer_id(group, source, destination, epoch, seq):
    """Identifier of a directional transfer; an ID, not an authentication proof."""
    text = json.dumps(['civ13-transfer/1', group, source, destination, epoch, seq], separators=(',', ':'))
    return hashlib.sha256(text.encode('ascii')).hexdigest()


def payload_kinds(manifest):
    """The sorted payload kinds ("kind" of each JSON object item) of a manifest."""
    kinds = set()
    items = json.loads(manifest).get('items', [])
    for item in (items if isinstance(items, list) else []):
        try:
            value = json.loads(item) if isinstance(item, str) else None
        except ValueError:
            value = None
        kind = value.get('kind') if isinstance(value, dict) else None
        kinds.add(kind if isinstance(kind, str) and len(kind) <= 32 else '')
    return sorted(kinds)


# Payload kinds the world can find and remove again after a reload: a character
# by its owner, an uncrewed freighter's flight or train by its saved id.
FAST_KINDS = ('character', 'freight', 'train')


def character_owners(manifest):
    """The account keys of the character payloads a manifest carries."""
    owners = set()
    items = json.loads(manifest).get('items', [])
    for item in (items if isinstance(items, list) else []):
        try:
            value = json.loads(item) if isinstance(item, str) else None
        except ValueError:
            value = None
        if isinstance(value, dict) and value.get('kind') == 'character' and account_key_valid(value.get('owner')):
            owners.add(value['owner'])
    return owners


def _require_characters(payloads):
    """Only character, freight or validated train payloads can be journaled, one kind per
    transfer: the world can find and remove those again, but not an arbitrary
    stack of goods."""
    kinds = payload_kinds(json.dumps({'items': payloads})) if payloads else []
    if len(kinds) != 1 or kinds[0] not in FAST_KINDS:
        raise TransferError('only character, freight or train payloads can travel fast')
    _train_payload(payloads)


def _train_payload(payloads):
    kinds = payload_kinds(json.dumps({'items': payloads}))
    if 'train' not in kinds:
        return None
    if kinds != ['train'] or len(payloads) != 1:
        raise TransferError('a train must be one indivisible manifest')
    try:
        return validate_train(payloads[0])
    except ValueError as exc:
        raise TransferError(str(exc)) from exc


class RegionStore(TrainLeaseQueue):
    def __init__(self, path, region_id, group_id):
        self.region = region_id
        self.group = group_id
        # One agent thread owns the store; the HTTP agent serves requests one
        # at a time, so the connection is never used concurrently.
        self.db = sqlite3.connect(path, isolation_level=None, check_same_thread=False)
        try:
            self.db.execute('PRAGMA journal_mode=WAL')
            self.db.execute('PRAGMA synchronous=FULL')
            self.db.execute('PRAGMA foreign_keys=ON')
            with self._tx():
                self._migrate()
        except Exception:
            # Do not leave the file open (Windows cannot delete open files).
            self.db.close()
            raise

    def close(self):
        self.db.close()

    # -- plumbing -------------------------------------------------------

    def _tx(self):
        store = self

        class Tx:
            def __enter__(self):
                store.db.execute('BEGIN IMMEDIATE')

            def __exit__(self, kind, value, tb):
                store.db.execute('COMMIT' if kind is None else 'ROLLBACK')
                return False
        return Tx()

    def _migrate(self):
        db = self.db
        db.execute('CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)')
        found = dict(db.execute('SELECT key, value FROM meta'))
        if not found:
            for key, value in [('schema', str(SCHEMA_VERSION)), ('region', self.region), ('group', self.group),
                               ('ledger_seq', '0'), ('confirmed_generation', ''), ('hold_reason', '')]:
                db.execute('INSERT INTO meta VALUES (?, ?)', (key, value))
        elif found['schema'] != str(SCHEMA_VERSION) or found['region'] != self.region or found['group'] != self.group:
            raise TransferError('transfer store belongs to another region, group or schema')
        db.execute('''CREATE TABLE IF NOT EXISTS fence(
            direction TEXT NOT NULL, peer TEXT NOT NULL, epoch INTEGER NOT NULL, settled_seq INTEGER NOT NULL,
            PRIMARY KEY(direction, peer))''')
        db.execute('''CREATE TABLE IF NOT EXISTS active(
            direction TEXT NOT NULL, peer TEXT NOT NULL, seq INTEGER NOT NULL, transfer_id TEXT NOT NULL UNIQUE,
            manifest TEXT NOT NULL, phase TEXT NOT NULL, PRIMARY KEY(direction, peer))''')
        db.execute('''CREATE TABLE IF NOT EXISTS escrow(
            transfer_id TEXT NOT NULL, idx INTEGER NOT NULL, payload TEXT NOT NULL,
            PRIMARY KEY(transfer_id, idx))''')
        db.execute('''CREATE TABLE IF NOT EXISTS effect(
            effect_id TEXT PRIMARY KEY, transfer_id TEXT NOT NULL, kind TEXT NOT NULL, state TEXT NOT NULL)''')
        # Journaled effects not yet listed by a world save, in the order applied.
        db.execute('''CREATE TABLE IF NOT EXISTS journal(
            seq INTEGER PRIMARY KEY AUTOINCREMENT, effect_id TEXT NOT NULL UNIQUE, kind TEXT NOT NULL,
            payloads TEXT NOT NULL)''')
        db.execute('''CREATE TABLE IF NOT EXISTS outbox(
            direction TEXT NOT NULL, peer TEXT NOT NULL, step TEXT NOT NULL, body TEXT NOT NULL,
            PRIMARY KEY(direction, peer))''')
        # Home worlds: this region's copy of the coordinator's account ledger,
        # and the account requests waiting for the coordinator's next pass.
        db.execute('''CREATE TABLE IF NOT EXISTS home(
            ckey TEXT PRIMARY KEY, region TEXT NOT NULL)''')
        db.execute('''CREATE TABLE IF NOT EXISTS account_request(
            id INTEGER PRIMARY KEY AUTOINCREMENT, ckey TEXT NOT NULL, op TEXT NOT NULL, region TEXT NOT NULL)''')
        # The world this store last reconciled (reconcile_load): an expedition slot holds one land after another.
        db.execute("INSERT OR IGNORE INTO meta VALUES ('world', '')")
        db.execute("INSERT OR IGNORE INTO meta VALUES ('homes_epoch', '')")
        # Names this store's request ids, so a replaced store's ids are never
        # mistaken for ones the coordinator already decided.
        db.execute("INSERT OR IGNORE INTO meta VALUES ('store_id', ?)", (secrets.token_hex(8),))
        db.execute("INSERT OR IGNORE INTO meta VALUES ('homes_rev', '0')")
        db.execute("INSERT OR IGNORE INTO meta VALUES ('mainland', '')")
        db.execute("INSERT OR IGNORE INTO meta VALUES ('start_region', '')")
        db.execute("INSERT OR IGNORE INTO meta VALUES ('travelling', '{}')")
        # Land stages: this region's copy of the coordinator's stage list, and
        # admin changes waiting for the coordinator's next pass.
        db.execute("INSERT OR IGNORE INTO meta VALUES ('lands', '{}')")
        # The world's latest population sample, read by the coordinator (land readiness).
        db.execute("INSERT OR IGNORE INTO meta VALUES ('land_sample', '')")
        db.execute('''CREATE TABLE IF NOT EXISTS land_request(
            id INTEGER PRIMARY KEY AUTOINCREMENT, region TEXT NOT NULL, stage TEXT NOT NULL,
            paused INTEGER NOT NULL, admin TEXT NOT NULL)''')
        # The world chart (docs/world-chart.md): this region's copy, and admin
        # chart requests waiting for the coordinator's next pass.
        db.execute("INSERT OR IGNORE INTO meta VALUES ('chart', '{}')")
        db.execute('''CREATE TABLE IF NOT EXISTS chart_request(
            id INTEGER PRIMARY KEY AUTOINCREMENT, op TEXT NOT NULL, x INTEGER NOT NULL, y INTEGER NOT NULL,
            owner TEXT, admin TEXT NOT NULL)''')
        # A ship's course names its voyage (added for boat expeditions' voyages).
        if 'voyage' not in [row[1] for row in db.execute('PRAGMA table_info(chart_request)')]:
            db.execute('ALTER TABLE chart_request ADD COLUMN voyage TEXT')
        # Island access settings and visitor passes carry their fields as JSON (island_access.dm).
        if 'data' not in [row[1] for row in db.execute('PRAGMA table_info(chart_request)')]:
            db.execute('ALTER TABLE chart_request ADD COLUMN data TEXT')
        db.execute("INSERT OR IGNORE INTO meta VALUES ('train_history', '0')")
        self.init_train_leases()
        db.execute('CREATE TABLE IF NOT EXISTS train_home_lock(ckey TEXT PRIMARY KEY)')
        # Colony starts granted to accounts whose home the coordinator moved
        # here for one (colony_charter.dm): ckey -> the colony's parent faction.
        db.execute('CREATE TABLE IF NOT EXISTS colony_grant(ckey TEXT PRIMARY KEY, faction TEXT NOT NULL)')
        # Nations (docs/land-stages.md, "Nations"): the registry as the
        # coordinator last sent it, leaders' requests waiting for its next
        # pass, and outcomes waiting for the world to tell the leader.
        db.execute("INSERT OR IGNORE INTO meta VALUES ('nations', '{}')")
        db.execute('CREATE TABLE IF NOT EXISTS nation_request(id INTEGER PRIMARY KEY AUTOINCREMENT, body TEXT NOT NULL)')
        db.execute('''CREATE TABLE IF NOT EXISTS nation_result(
            id INTEGER PRIMARY KEY, actor TEXT NOT NULL, faction TEXT NOT NULL, text TEXT NOT NULL, at INTEGER NOT NULL)''')
        db.execute('CREATE TABLE IF NOT EXISTS train_home_wait(ckey TEXT PRIMARY KEY, target TEXT NOT NULL, epoch TEXT NOT NULL)')
        db.execute('CREATE TABLE IF NOT EXISTS train_custody_witness(transfer_id TEXT PRIMARY KEY, epoch TEXT NOT NULL)')
        columns = {r[1] for r in db.execute('PRAGMA table_info(account_request)')}
        for column, sql in (('homes_epoch', "TEXT NOT NULL DEFAULT ''"), ('home_rev', 'INTEGER NOT NULL DEFAULT 0'),
                            ('faction', "TEXT NOT NULL DEFAULT ''")):
            if column not in columns:
                db.execute('ALTER TABLE account_request ADD COLUMN ' + column + ' ' + sql)

        if any(_train_payload(json.loads(m).get('items', [])) for (m,) in db.execute('SELECT manifest FROM active')) or any(
                _train_payload(json.loads(p)) for (p,) in db.execute('SELECT payloads FROM journal')) or db.execute(
                'SELECT 1 FROM train_home_wait LIMIT 1').fetchone():
            self._set_meta('train_history', '1')
        # A durable admission witness; reservations must survive world reloads.
        db.execute('''CREATE TABLE IF NOT EXISTS train_admission(
            transfer_id TEXT PRIMARY KEY, manifest_hash TEXT NOT NULL,
            reservation TEXT NOT NULL)''')
        # Shared player records waiting for the coordinator (records.py).
        player_records.init_region(db)

    def _meta(self, key):
        return self.db.execute('SELECT value FROM meta WHERE key = ?', (key,)).fetchone()[0]

    def _set_meta(self, key, value):
        self.db.execute('UPDATE meta SET value = ? WHERE key = ?', (str(value), key))

    def _require_open(self):
        reason = self._meta('hold_reason')
        if reason:
            raise RegionHeld(reason)

    def _fence(self, direction, peer):
        row = self.db.execute('SELECT epoch, settled_seq FROM fence WHERE direction = ? AND peer = ?',
                              (direction, peer)).fetchone()
        if row is None:
            raise TransferError('peer %r is not enrolled for %s transfers' % (peer, direction))
        return row

    def _active(self, direction, peer):
        return self.db.execute('SELECT seq, transfer_id, manifest, phase FROM active WHERE direction = ? AND peer = ?',
                               (direction, peer)).fetchone()

    def _active_by_id(self, tid):
        return self.db.execute('SELECT direction, peer, seq, manifest, phase FROM active WHERE transfer_id = ?',
                               (tid,)).fetchone()

    def _set_phase(self, tid, phase):
        self.db.execute('UPDATE active SET phase = ? WHERE transfer_id = ?', (phase, tid))

    def _send(self, direction, peer, step, body):
        row = self._active_by_id(body.get('transfer_id'))
        if row:
            payloads = json.loads(row[3]).get('items', [])
            if _train_payload(payloads):
                train = _train_payload(payloads)
                lease = self.db.execute('SELECT token FROM train_lease WHERE journey=?', (train['journey'],)).fetchone()
                body = dict(body, train_manifest=payloads[0])
                if lease:
                    body['train_lease'] = lease[0]
        body = dict(body, step=step, group=self.group, sender=self.region, recipient=peer)
        self.db.execute('INSERT OR REPLACE INTO outbox VALUES (?, ?, ?, ?)',
                        (direction, peer, step, json.dumps(body, sort_keys=True)))

    def _settle(self, direction, peer, seq, tid):
        row = self._active_by_id(tid)
        train = _train_payload(json.loads(row[3]).get('items', [])) if row else None
        witness = self.db.execute('SELECT epoch FROM train_custody_witness WHERE transfer_id = ?', (tid,)).fetchone()
        if train and direction == OUT:
            self.db.execute("UPDATE train_lease SET state='settled' WHERE journey=?", (train['journey'],))
        if train and witness and (direction == OUT or row[4] == IMPORTED):
            target = peer if direction == OUT and row[4] == COMMIT_DECIDED else self.region
            for owner in train['accounts']:
                self.db.execute('INSERT OR REPLACE INTO train_home_wait VALUES (?,?,?)', (owner, target, witness[0]))
        self.db.execute('UPDATE fence SET settled_seq = ? WHERE direction = ? AND peer = ?', (seq, direction, peer))
        self.db.execute('DELETE FROM outbox WHERE direction = ? AND peer = ?', (direction, peer))
        for table in ('active', 'escrow', 'effect', 'train_admission', 'train_custody_witness'):
            self.db.execute('DELETE FROM %s WHERE transfer_id = ?' % table, (tid,))

    # -- enrollment -----------------------------------------------------

    def enroll(self, peer, direction, epoch=1):
        """Operator step: permit transfers with peer in one direction."""
        if direction not in (OUT, IN):
            raise TransferError('direction must be out or in')
        with self._tx():
            self.db.execute('INSERT OR IGNORE INTO fence VALUES (?, ?, ?, 0)', (direction, peer, epoch))

    # -- world effects (called by DM before it changes the world) --------

    def begin_escrow(self, peer, payloads, fast=False, train_lease=None):
        """Source: record the tentative removal of items, before DM removes them.

        Returns (transfer_id, effect_id). DM removes the items only after this
        returns, and lists effect_id in the next world save. With fast, the
        removal is journaled and the escrow is sent at once (characters, freight and validated trains only).
        """
        if not payloads or any(type(p) is not str for p in payloads):
            raise TransferError('escrow needs a non-empty list of serialized items')
        train = _train_payload(payloads)
        if train and (train['source'] != self.region or train['destination'] != peer):
            raise TransferError('train route does not match escrow channel')
        if fast:
            _require_characters(payloads)
        with self._tx():
            self._require_open()
            epoch, settled = self._fence(OUT, peer)
            if train:
                try:
                    self.require_train_lease(train, train_lease)
                except ValueError as exc:
                    raise TransferError(str(exc)) from exc
                self._set_meta('train_history', '1')
                for (stored,) in self.db.execute('SELECT manifest FROM active'):
                    other = _train_payload(json.loads(stored).get('items', []))
                    if other and (other['id'] == train['id'] or set(other['accounts']) & set(train['accounts'])):
                        raise TransferError('train or passenger already has an active transfer')
                for owner in train['accounts']:
                    home = self.home_of(owner)
                    if home is not None and home != self.region:
                        raise TransferError('passenger belongs to another region')
            if self._active(OUT, peer):
                raise TransferError('a transfer to %s is already in flight' % peer)
            if self.db.execute('SELECT 1 FROM outbox WHERE direction = ? AND peer = ?', (OUT, peer)).fetchone():
                raise TransferError('the previous transfer to %s is not acknowledged yet' % peer)
            seq = settled + 1
            tid = transfer_id(self.group, self.region, peer, epoch, seq)
            if train:
                self.db.execute("UPDATE train_lease SET state='sealed',transfer_id=? WHERE journey=?", (tid, train['journey']))
            manifest = json.dumps({'epoch': epoch, 'seq': seq, 'items': payloads}, sort_keys=True)
            self.db.execute('INSERT INTO active VALUES (?, ?, ?, ?, ?, ?)', (OUT, peer, seq, tid, manifest, REQUESTED))
            for idx, payload in enumerate(payloads):
                self.db.execute('INSERT INTO escrow VALUES (?, ?, ?)', (tid, idx, payload))
            effect_id = tid + ':' + REMOVE
            self.db.execute('INSERT INTO effect VALUES (?, ?, ?, ?)', (effect_id, tid, REMOVE, TENTATIVE))
            if fast:
                self._journal(effect_id, tid, REMOVE, payloads)
            return tid, effect_id

    def begin_import(self, tid, fast=False):
        """Destination: record the tentative credit, before DM creates the items.

        Returns (effect_id, payloads). With fast, the credit is journaled and the
        receipt is sent at once (characters, freight and validated trains only).
        """
        with self._tx():
            self._require_open()
            row = self._active_by_id(tid)
            if row is None or row[0] != IN or row[4] != COMMIT_RECEIVED:
                raise TransferError('transfer is not ready to import')
            effect_id = tid + ':' + CREDIT
            if self.db.execute('SELECT 1 FROM effect WHERE effect_id = ?', (effect_id,)).fetchone():
                raise TransferError('import is already applied and waiting for a world save')
            payloads = json.loads(row[3])['items']
            if fast:
                _require_characters(payloads)
            self.db.execute('INSERT INTO effect VALUES (?, ?, ?, ?)', (effect_id, tid, CREDIT, TENTATIVE))
            if fast:
                self._journal(effect_id, tid, CREDIT, payloads)
            return effect_id, payloads

    def begin_return(self, tid, fast=False):
        """Source, after a destination tombstone: record the tentative return."""
        with self._tx():
            self._require_open()
            row = self._active_by_id(tid)
            if row is None or row[0] != OUT or row[4] != RETURNING:
                raise TransferError('transfer is not ready to return')
            effect_id = tid + ':' + RETURN
            if self.db.execute('SELECT 1 FROM effect WHERE effect_id = ?', (effect_id,)).fetchone():
                raise TransferError('return is already applied and waiting for a world save')
            payloads = [p for (p,) in self.db.execute('SELECT payload FROM escrow WHERE transfer_id = ? ORDER BY idx',
                                                      (tid,))]
            if fast:
                _require_characters(payloads)
            self.db.execute('INSERT INTO effect VALUES (?, ?, ?, ?)', (effect_id, tid, RETURN, TENTATIVE))
            if fast:
                self._journal(effect_id, tid, RETURN, payloads)
            return effect_id, payloads

    def abort(self, tid):
        """Source: give up before the commit decision."""
        with self._tx():
            self._require_open()
            row = self._active_by_id(tid)
            if row is None or row[0] != OUT or row[4] not in (REQUESTED, ESCROWED):
                raise TransferError('only an uncommitted outgoing transfer can be aborted')
            if row[4] == REQUESTED:
                raise TransferError('wait for the world save that confirms the escrow before aborting')
            self._set_phase(tid, ABORT_DECIDED)
            self._send(OUT, row[1], 'ABORT', {'transfer_id': tid, 'seq': row[2]})

    # -- world save and load ----------------------------------------------

    def ledger_seq(self):
        return int(self._meta('ledger_seq'))

    def report_save(self, generation, effect_ids, ledger_seq):
        """After save_complete.txt: confirm the effects that save contains.

        Returns the new ledger sequence for DM to cache.
        """
        with self._tx():
            current = self.ledger_seq()
            if self._meta('hold_reason'):
                raise RegionHeld(self._meta('hold_reason'))
            if generation == self._meta('confirmed_generation'):
                return current
            if ledger_seq > current:
                raise TransferError('save report is ahead of the store (save ledger %s, store ledger %s)'
                                    % (ledger_seq, current))
            # A running world may report with an older base when an earlier
            # report's reply was lost; its effect list then repeats confirmed
            # effects, which _confirm skips.
            self._confirm(effect_ids)
            self._set_meta('ledger_seq', current + 1)
            self._set_meta('confirmed_generation', generation)
            return current + 1

    def reconcile_load(self, generation, effect_ids, ledger_seq, fresh=False, world=None):
        """At world load: confirm what the loaded save lists, void the rest.

        Returns the ledger sequence DM must cache. Puts the region on hold when
        the loaded save is older than what the store already confirmed.
        Journaled effects the save does not list are kept; replay() returns them.

        With fresh, the world never saves and starts from a new map every time
        (a resetting raid world): it lists nothing and adopts the store's ledger
        instead of being held for a rollback. Journaled arrivals still replay.

        world names the world that loaded (an expedition slot's land and when it
        was placed there, expedition_slots.py). A slot holds one land after
        another, each with its own save history, so a world other than the last
        one reconciled is adopted at the store's ledger: its save is neither
        ahead of nor behind a store that only knew the land before it. The same
        world loading an older save is still held.
        """
        with self._tx():
            current = self.ledger_seq()
            if self._meta('hold_reason'):
                raise RegionHeld(self._meta('hold_reason'))
            if isinstance(world, str) and world and world != self._meta('world'):
                self._set_meta('world', world)
                ledger_seq = current
            if fresh:
                effect_ids, ledger_seq = [], current
            if generation == self._meta('confirmed_generation'):
                pass
            elif ledger_seq == current:
                self._confirm(effect_ids)
                current += 1
                self._set_meta('ledger_seq', current)
                self._set_meta('confirmed_generation', generation)
            else:
                self._set_meta('hold_reason', 'rollback: loaded save ledger %s, store ledger %s' % (ledger_seq, current))
                return None
            listed = set(effect_ids)
            for effect_id in listed:
                self.db.execute('DELETE FROM journal WHERE effect_id = ?', (effect_id,))
            for effect_id, tid, kind in list(self.db.execute(
                    'SELECT effect_id, transfer_id, kind FROM effect WHERE state = ?', (TENTATIVE,))):
                if effect_id in listed:
                    continue
                self._void(effect_id, tid, kind)
            return current

    def replay(self):
        """Journaled effects no world save has listed yet, oldest first.

        After a load, the world applies these again (they happened after the
        save it loaded) and lists them in its next save.
        """
        return [{'effect_id': e, 'kind': k, 'payloads': json.loads(p)} for (e, k, p) in self.db.execute(
            'SELECT effect_id, kind, payloads FROM journal ORDER BY seq')]

    def _journal(self, effect_id, tid, kind, payloads):
        self.db.execute('INSERT INTO journal(effect_id, kind, payloads) VALUES (?, ?, ?)',
                        (effect_id, kind, json.dumps(payloads)))
        self._step_for(tid, kind)
        self.db.execute('UPDATE effect SET state = ? WHERE effect_id = ?', (JOURNALED, effect_id))

    def _confirm(self, effect_ids):
        for effect_id in effect_ids:
            # A save that lists a journaled effect makes the journal entry redundant.
            self.db.execute('DELETE FROM journal WHERE effect_id = ?', (effect_id,))
            row = self.db.execute('SELECT transfer_id, kind, state FROM effect WHERE effect_id = ?',
                                  (effect_id,)).fetchone()
            if row is None or row[2] == CONFIRMED:
                # Already settled, or confirmed by an earlier report of the same save.
                continue
            self.db.execute('UPDATE effect SET state = ? WHERE effect_id = ?', (CONFIRMED, effect_id))
            if row[2] == JOURNALED:
                continue  # its protocol step was taken when it was journaled
            self._step_for(row[0], row[1])

    def _step_for(self, tid, kind):
        """The protocol step that follows a confirmed effect."""
        direction, peer, seq, manifest, phase = self._active_by_id(tid)
        if kind == REMOVE:
            self._set_phase(tid, ESCROWED)
            self._send(OUT, peer, 'ESCROW', {'transfer_id': tid, 'seq': seq, 'manifest': json.loads(manifest)})
        elif kind == CREDIT:
            self._set_phase(tid, IMPORTED)
            self._send(IN, peer, 'IMPORTED', {'transfer_id': tid, 'seq': seq})
        elif kind == RETURN:
            self._settle(OUT, peer, seq, tid)
            self._send(OUT, peer, 'FINALIZE', {'transfer_id': tid, 'seq': seq, 'outcome': 'returned'})

    def _void(self, effect_id, tid, kind):
        self.db.execute('DELETE FROM effect WHERE effect_id = ?', (effect_id,))
        if kind == REMOVE:
            # The reloaded world still holds the items and no envelope left the
            # region, so the transfer never happened; its sequence is reused.
            self.db.execute('DELETE FROM escrow WHERE transfer_id = ?', (tid,))
            self.db.execute('DELETE FROM active WHERE transfer_id = ?', (tid,))
        # A voided credit or return leaves the phase as it was, so DM redoes it.

    # -- messages ---------------------------------------------------------

    def outbox(self):
        """Envelopes waiting for delivery (resent until superseded or acknowledged)."""
        return [json.loads(body) for (body,) in self.db.execute('SELECT body FROM outbox ORDER BY direction, peer')]

    def receive(self, envelope):
        """Apply one envelope from a peer. Duplicates and stale steps are harmless.

        Returns a direct ACK envelope or None. ACKs are never stored: a lost ACK
        is regenerated when the peer resends.
        """
        step, peer, tid, seq = envelope['step'], envelope['sender'], envelope['transfer_id'], envelope['seq']
        if envelope.get('group') != self.group or envelope.get('recipient') != self.region:
            raise TransferError('envelope is for another group or region')
        with self._tx():
            self._require_open()
            row = self._active_by_id(tid)
            if 'train_manifest' in envelope:
                actual = envelope.get('manifest', {}).get('items', []) if step == 'ESCROW' else (
                    json.loads(row[3]).get('items', []) if row else None)
                if actual is not None and actual != [envelope['train_manifest']]:
                    raise TransferError('train envelope marker changed')
            items = [envelope['train_manifest']] if 'train_manifest' in envelope else envelope.get('manifest', {}).get('items', []) if step == 'ESCROW' else (
                json.loads(row[3]).get('items', []) if row else [])
            if _train_payload(items):
                epoch = envelope.get('train_custody_epoch')
                if not isinstance(epoch, str) or not epoch:
                    raise TransferError('train needs coordinator custody witness')
                prior = self.db.execute('SELECT epoch FROM train_custody_witness WHERE transfer_id = ?', (tid,)).fetchone()
                if prior and prior[0] != epoch:
                    raise TransferError('train coordinator epoch changed; recovery required')
                self.db.execute('INSERT OR IGNORE INTO train_custody_witness VALUES (?,?)', (tid, epoch))
            if step in ('ESCROW', 'COMMIT', 'ABORT', 'FINALIZE'):
                return self._receive_as_destination(step, peer, tid, seq, envelope)
            elif step in ('PREPARE', 'IMPORTED', 'TOMBSTONE', 'ACK'):
                return self._receive_as_source(step, peer, tid, seq)
            else:
                raise TransferError('unknown step %r' % step)

    def _receive_as_destination(self, step, peer, tid, seq, envelope):
        epoch, settled = self._fence(IN, peer)
        if seq <= settled:
            # Settled already: answer without looking anything up.
            return self._ack(peer, tid, seq)
        active = self._active(IN, peer)
        if active is None:
            if step not in ('ESCROW', 'ABORT') or seq != settled + 1:
                raise TransferError('unexpected %s for sequence %s' % (step, seq))
            if tid != transfer_id(self.group, peer, self.region, epoch, seq):
                raise TransferError('transfer id does not match the channel')
            if step == 'ABORT':
                # The escrow never arrived: refuse it for good before the source
                # may return its items.
                self.db.execute('INSERT INTO active VALUES (?, ?, ?, ?, ?, ?)',
                                (IN, peer, seq, tid, '{}', DESTINATION_ABORTED))
                self._send(IN, peer, 'TOMBSTONE', {'transfer_id': tid, 'seq': seq})
                return None
            manifest = envelope['manifest']
            if not isinstance(manifest, dict) or manifest.get('epoch') != epoch or manifest.get('seq') != seq:
                raise TransferError('manifest does not match the channel')
            items = manifest.get('items')
            # Same rule as begin_escrow: a peer may not store a manifest that
            # status() or the world cannot read.
            if not isinstance(items, list) or not items or any(type(p) is not str for p in items):
                raise TransferError('manifest needs a non-empty list of serialized items')
            train = _train_payload(items)
            if train and (train['source'] != peer or train['destination'] != self.region):
                raise TransferError('train route does not match incoming channel')
            if train:
                self._set_meta('train_history', '1')
                for (stored,) in self.db.execute('SELECT manifest FROM active'):
                    other = _train_payload(json.loads(stored).get('items', []))
                    if other and (other['id'] == train['id'] or set(other['accounts']) & set(train['accounts'])):
                        raise TransferError('train or passenger already has an active transfer')
            self.db.execute('INSERT INTO active VALUES (?, ?, ?, ?, ?, ?)',
                            (IN, peer, seq, tid, json.dumps(manifest, sort_keys=True),
                             TRAIN_ADMISSION if payload_kinds(json.dumps(manifest)) == ['train'] else PREPARED))
            if payload_kinds(json.dumps(manifest)) != ['train']:
                self._send(IN, peer, 'PREPARE', {'transfer_id': tid, 'seq': seq})
            return
        a_seq, a_tid, _, phase = active
        if a_tid != tid:
            raise TransferError('another transfer is active on this channel')
        if step == 'COMMIT' and phase == PREPARED:
            self._set_phase(tid, COMMIT_RECEIVED)
            self.db.execute('DELETE FROM outbox WHERE direction = ? AND peer = ?', (IN, peer))
        elif step == 'ABORT' and phase in (PREPARED, TRAIN_ADMISSION):
            self._set_phase(tid, DESTINATION_ABORTED)
            self._send(IN, peer, 'TOMBSTONE', {'transfer_id': tid, 'seq': seq})
        elif step == 'FINALIZE' and phase in (IMPORTED, DESTINATION_ABORTED):
            expected = 'imported' if phase == IMPORTED else 'returned'
            if envelope.get('outcome') != expected:
                raise TransferError('finalize outcome does not match the destination phase')
            self._settle(IN, peer, seq, tid)
            return self._ack(peer, tid, seq)
        elif step == 'ABORT' and phase in (COMMIT_RECEIVED, IMPORTED):
            raise TransferError('abort after commit is refused')
        # Anything else is a retransmission of a step already applied.

    def _ack(self, peer, tid, seq):
        return {'step': 'ACK', 'group': self.group, 'sender': self.region, 'recipient': peer,
                'transfer_id': tid, 'seq': seq}

    def _receive_as_source(self, step, peer, tid, seq):
        epoch, settled = self._fence(OUT, peer)
        if step == 'ACK':
            row = self.db.execute('SELECT body FROM outbox WHERE direction = ? AND peer = ?', (OUT, peer)).fetchone()
            if row and json.loads(row[0])['step'] == 'FINALIZE' and json.loads(row[0])['seq'] == seq and seq <= settled:
                self.db.execute('DELETE FROM outbox WHERE direction = ? AND peer = ?', (OUT, peer))
            return
        if seq <= settled:
            return
        active = self._active(OUT, peer)
        if active is None or active[1] != tid:
            raise TransferError('no matching outgoing transfer')
        phase = active[3]
        if step == 'PREPARE' and phase == ESCROWED:
            self._set_phase(tid, COMMIT_DECIDED)
            self._send(OUT, peer, 'COMMIT', {'transfer_id': tid, 'seq': seq})
        elif step == 'IMPORTED' and phase == COMMIT_DECIDED:
            # Retire the escrow for good and settle the channel.
            self._settle(OUT, peer, seq, tid)
            self._send(OUT, peer, 'FINALIZE', {'transfer_id': tid, 'seq': seq, 'outcome': 'imported'})
        elif step == 'TOMBSTONE' and phase == ABORT_DECIDED:
            self._set_phase(tid, RETURNING)
            self.db.execute('DELETE FROM outbox WHERE direction = ? AND peer = ?', (OUT, peer))
        elif step == 'PREPARE' and phase == ABORT_DECIDED:
            pass  # crossed with our ABORT; the ABORT in the outbox answers it
        elif step == 'IMPORTED' and phase != COMMIT_DECIDED:
            raise TransferError('import evidence without a commit decision')

    def lookup_train(self, train_id):
        """Find active custody and retained replay evidence after an unknown reply.

        No match does not authorize reuse after old journals have been retired;
        the caller must reconcile against its durable world effect list.
        """
        matches = []
        for tid, direction, phase, manifest in self.db.execute(
                'SELECT transfer_id, direction, phase, manifest FROM active'):
            train = _train_payload(json.loads(manifest).get('items', []))
            if train and train['id'] == train_id:
                matches.append({'transfer_id': tid, 'direction': direction, 'phase': phase,
                                'journey': train['journey'],
                                'manifest_hash': hashlib.sha256(manifest.encode('utf-8')).hexdigest()})
        replay = []
        for effect, kind, payloads in self.db.execute('SELECT effect_id, kind, payloads FROM journal ORDER BY seq'):
            train = _train_payload(json.loads(payloads))
            if train and train['id'] == train_id:
                replay.append({'effect_id': effect, 'kind': kind, 'journey': train['journey']})
        leases = [self.train_lease_status(journey) for journey, request in self.db.execute('SELECT journey,request FROM train_lease')
                  if json.loads(request)['id'] == train_id]
        return {'active': matches, 'replay': replay, 'leases': leases}

    def pending_train_admissions(self):
        """Uncommitted manifests awaiting the world's durable track reservation.

        The world must recheck station permission, route generation, complete
        geometry and body/cargo codec before admitting. A timeout is not an
        admission and does not expire a reservation after commit.
        """
        return [{'transfer_id': tid, 'peer': peer, 'payloads': json.loads(manifest)['items'],
                 'manifest_hash': hashlib.sha256(manifest.encode('utf-8')).hexdigest()}
                for tid, peer, manifest in self.db.execute(
                    'SELECT transfer_id, peer, manifest FROM active WHERE direction = ? AND phase = ?',
                    (IN, TRAIN_ADMISSION))]

    def prepare_train(self, tid, manifest_hash, reservation):
        """Acknowledge an exact manifest only after DM durably reserved its track.

        Repeated acknowledgements must match the original witness. This is a
        permissioned loopback operation, not a player-supplied reservation.
        """
        if not isinstance(reservation, str) or not 1 <= len(reservation) <= 200:
            raise TransferError('train admission needs a bounded reservation id')
        with self._tx():
            self._require_open()
            row = self._active_by_id(tid)
            if row is None or row[0] != IN or row[4] not in (TRAIN_ADMISSION, PREPARED, COMMIT_RECEIVED, IMPORTED):
                raise TransferError('train is not awaiting destination admission')
            if payload_kinds(row[3]) != ['train']:
                raise TransferError('admission requires a train manifest')
            expected = hashlib.sha256(row[3].encode('utf-8')).hexdigest()
            if manifest_hash != expected:
                raise TransferError('train manifest changed')
            prior = self.db.execute('SELECT manifest_hash, reservation FROM train_admission WHERE transfer_id = ?',
                                    (tid,)).fetchone()
            if prior:
                if prior != (manifest_hash, reservation):
                    raise TransferError('train already has another reservation')
                return {'prepared': True}
            if row[4] != TRAIN_ADMISSION:
                raise TransferError('train admission witness is missing')
            self.db.execute('INSERT INTO train_admission VALUES (?, ?, ?)', (tid, manifest_hash, reservation))
            self._set_phase(tid, PREPARED)
            self._send(IN, row[1], 'PREPARE', {'transfer_id': tid, 'seq': row[2]})
            return {'prepared': True}

    # -- home worlds --------------------------------------------------------

    def account(self, ckey, op, region=None, body=False, faction=None):
        """One account question or request from DM.

        claim: may this account play here? HOME, ELSEWHERE (with its home) or
        PENDING while the coordinator decides. arrive: a character arrived here
        through a recorded trip. depart: it left for region. release: its only
        character here died (its home goes back to the start region). Requests wait
        for the coordinator's next pass. A claim with body (a living character of
        the account is here) asks for custody when the account has no home, so a
        lost coordinator ledger cannot strand a character off the mainland.
        colony: start the account's next character at its faction's colony in
        region (faction names the parent; the coordinator checks the colony
        stands there and grants the start). colony_used: that start was taken.
        A HOME claim says which colony start, if any, is granted here. start:
        start the account's next character in the wilds of region, an OPEN land.
        """
        if not account_key_valid(ckey):
            raise TransferError('bad account key')
        if op not in ACCOUNT_OPS:
            raise TransferError('unknown account operation')
        target = region if op in ('depart', 'colony', 'start') else self.region
        if op in ('depart', 'colony', 'start') and (not isinstance(region, str) or not region or region == self.region):
            raise TransferError(op + ' needs another region')
        if op in ('colony', 'colony_used') and not faction_id_valid(faction):
            raise TransferError('bad faction id')
        with self._tx():
            if self._account_train_locked(ckey):
                if op == 'claim':
                    return {'verdict': 'PENDING', 'home': self.home_of(ckey)}
                raise TransferError('account is leased to a physical train')
            queued = [o for (o,) in self.db.execute('SELECT op FROM account_request WHERE ckey = ?', (ckey,))]
            home = self.home_of(ckey)
            if op == 'claim':
                # A character of this account is still on its way here (in a
                # source land's escrow, or received and not yet built by the
                # world): starting a new one now would replace it. A living
                # character already here (body) is played as usual.
                if body is not True and self.travelling_here(ckey):
                    return {'verdict': 'TRAVELLING', 'home': home, 'from': self.travelling_here(ckey)}
                if not queued and home == self.region:
                    grant = self.db.execute('SELECT faction FROM colony_grant WHERE ckey = ?', (ckey,)).fetchone()
                    return {'verdict': 'HOME', 'home': home, 'colony_grant': grant[0] if grant else None}
                if not queued and home is not None:
                    return {'verdict': 'ELSEWHERE', 'home': home}
                start = self.start_region()
                if body is True and home is None:
                    op = 'custody'
                elif not queued and home is None and start and start != self.region:
                    # New characters start in the start region and travel from there.
                    return {'verdict': 'ELSEWHERE', 'home': start}
                if op in queued or 'claim' in queued:
                    return {'verdict': 'PENDING', 'home': home}
            if op == 'colony_used':
                self.db.execute('DELETE FROM colony_grant WHERE ckey = ?', (ckey,))
            self.db.execute('INSERT INTO account_request(ckey, op, region, homes_epoch, home_rev, faction) VALUES (?, ?, ?, ?, ?, ?)',
                            (ckey, op, target, self._meta('homes_epoch'), int(self._meta('homes_rev')), faction or ''))
        return {'verdict': 'PENDING', 'home': home}

    def _account_train_locked(self, ckey):
        if (self.db.execute('SELECT 1 FROM train_home_lock WHERE ckey = ?', (ckey,)).fetchone()
                or self.db.execute('SELECT 1 FROM train_home_wait WHERE ckey = ?', (ckey,)).fetchone()):
            return True
        for (request,) in self.db.execute(
                "SELECT request FROM train_lease WHERE state IN ('pending','granted','cancel_pending','sealed')"):
            if ckey in json.loads(request)['accounts']:
                return True
        for (manifest,) in self.db.execute('SELECT manifest FROM active'):
            train = _train_payload(json.loads(manifest).get('items', []))
            if train and ckey in train['accounts']:
                return True
        return False

    def lobby_account_status(self, ckey):
        """Read-only barriers from this store, not authority to admit or route."""
        if not account_key_valid(ckey):
            raise TransferError('bad account key')
        self._require_open()
        if self._account_train_locked(ckey):
            state = 'PENDING'
        elif self.travelling_here(ckey) or any(ckey in character_owners(manifest) for (manifest,) in
                                              self.db.execute('SELECT manifest FROM active')):
            # Even returning/finalizing custody blocks a lobby handoff.
            state = 'TRAVELLING'
        elif self.db.execute('SELECT 1 FROM account_request WHERE ckey = ?', (ckey,)).fetchone():
            state = 'PENDING'
        else:
            state = 'CLEAR'
        return {'group': self.group, 'region': self.region, 'epoch': self._meta('homes_epoch'),
                'rev': int(self._meta('homes_rev')), 'state': state}

    def travelling_here(self, ckey):
        """The land a character of ckey is travelling here from, or None. Known
        from our own incoming transfers and from what the coordinator last
        said other lands hold in escrow for us."""
        for peer, manifest in self.db.execute(
                'SELECT peer, manifest FROM active WHERE direction = ? AND phase IN (?, ?, ?)',
                (IN, TRAIN_ADMISSION, PREPARED, COMMIT_RECEIVED)):
            if ckey in character_owners(manifest):
                return peer
        try:
            listed = json.loads(self._meta('travelling') or '{}')
        except ValueError:
            listed = {}
        source = listed.get(ckey) if isinstance(listed, dict) else None
        return source if isinstance(source, str) and source else None

    def travelling_out(self):
        """Characters this land holds in escrow for another: [{ckey, region}].
        A trip being returned or aborted comes back here and is left out."""
        found = []
        for peer, manifest in self.db.execute(
                'SELECT peer, manifest FROM active WHERE direction = ? AND phase IN (?, ?, ?) ORDER BY peer',
                (OUT, REQUESTED, ESCROWED, COMMIT_DECIDED)):
            found.extend({'ckey': owner, 'region': peer} for owner in sorted(character_owners(manifest)))
        return found

    def start_region(self):
        """Where new characters start, as the coordinator last said: its start
        region, or the mainland from a coordinator that sends none."""
        return self._meta('start_region') or self._meta('mainland') or None

    def home_of(self, ckey):
        row = self.db.execute('SELECT region FROM home WHERE ckey = ?', (ckey,)).fetchone()
        return row[0] if row else None

    def account_requests(self):
        """For the coordinator: queued requests and how current our ledger copy is."""
        return {'requests': [dict(zip(('id', 'ckey', 'op', 'region', 'homes_epoch', 'home_rev', 'faction'), r)) for r in self.db.execute(
                    'SELECT id, ckey, op, region, homes_epoch, home_rev, faction FROM account_request ORDER BY id')],
                'epoch': self._meta('homes_epoch'), 'rev': int(self._meta('homes_rev')),
                'travelling': self.travelling_out(),
                'store': self._meta('store_id'), 'train_history': self._meta('train_history') == '1', 'train_requests': self.train_lease_requests(),
                'land_sample': json.loads(self._meta('land_sample') or 'null'),
                'land_requests': [dict(zip(('id', 'region', 'stage', 'paused', 'admin'), (i, r, st, bool(p), a)))
                                  for i, r, st, p, a in self.db.execute(
                                      'SELECT id, region, stage, paused, admin FROM land_request ORDER BY id')],
                'chart_rev': json.loads(self._meta('chart')).get('key'),
                'chart_requests': [_chart_request_row(row) for row in self.db.execute(
                    'SELECT id, op, x, y, owner, admin, voyage, data FROM chart_request ORDER BY id')],
                'nation_requests': [dict(json.loads(b), id=i) for i, b in self.db.execute(
                    'SELECT id, body FROM nation_request ORDER BY id')]}

    def apply_homes(self, epoch, rev, rows, done, reset=False, mainland=None, train_locks=None, train_decisions=None,
                    lands=None, land_done=None, chart=None, chart_done=None, colony_grants=None,
                    nations=None, nation_results=None, start_region=None, travelling=None):
        """The coordinator's answer: ledger rows newer than our copy (region
        None removes a home) and the request ids it has decided."""
        if not isinstance(epoch, str) or not epoch or not isinstance(rev, int) or rev < 0:
            raise TransferError('bad home ledger version')
        with self._tx():
            if epoch == self._meta('homes_epoch') and rev < int(self._meta('homes_rev')):
                raise TransferError('stale home ledger snapshot')
            if reset or epoch != self._meta('homes_epoch'):
                self.db.execute('DELETE FROM home')
            for row in rows:
                ckey, region = row['ckey'], row['region']
                if not account_key_valid(ckey):
                    raise TransferError('bad account key')
                if region is None:
                    self.db.execute('DELETE FROM home WHERE ckey = ?', (ckey,))
                else:
                    self.db.execute('INSERT OR REPLACE INTO home VALUES (?, ?)', (ckey, str(region)))
            for request_id in done:
                self.db.execute('DELETE FROM account_request WHERE id = ?', (int(request_id),))
            if train_decisions is not None:
                self.apply_train_lease_decisions(epoch, train_decisions)
            if train_locks is not None:
                if not isinstance(train_locks, list) or not all(account_key_valid(k) for k in train_locks):
                    raise TransferError('invalid train lock snapshot')
                self.db.execute('DELETE FROM train_home_lock')
                self.db.executemany('INSERT OR IGNORE INTO train_home_lock VALUES (?)', [(k,) for k in train_locks])
            for owner, target, expected_epoch in list(self.db.execute('SELECT ckey,target,epoch FROM train_home_wait')):
                if expected_epoch == epoch and self.home_of(owner) == target and train_locks is not None and owner not in train_locks:
                    self.db.execute('DELETE FROM train_home_wait WHERE ckey = ?', (owner,))
            self._set_meta('homes_epoch', epoch)
            self._set_meta('homes_rev', rev)
            # Characters other lands hold in escrow for us (ckey: source land).
            # An older coordinator sends none: keep nobody waiting on a stale list.
            if travelling is not None and not (type(travelling) is dict and all(
                    account_key_valid(k) and isinstance(v, str) and 0 < len(v) <= 64 for k, v in travelling.items())):
                raise TransferError('invalid travelling list')
            self._set_meta('travelling', json.dumps(travelling or {}, sort_keys=True))
            self._set_meta('mainland', mainland if isinstance(mainland, str) else '')
            self._set_meta('start_region', start_region if isinstance(start_region, str) else '')
            # An older coordinator sends no land list: keep the copy we have.
            if lands is not None:
                if type(lands) is not dict or not all(land_id_valid(k) and land_stage_valid(v) for k, v in lands.items()):
                    raise TransferError('invalid land stage snapshot')
                self._set_meta('lands', json.dumps(lands, sort_keys=True))
            for request_id in land_done or []:
                self.db.execute('DELETE FROM land_request WHERE id = ?', (int(request_id),))
            # The coordinator's grants for this land replace ours; an older
            # coordinator sends none, and we keep what we have.
            if colony_grants is not None:
                if type(colony_grants) is not list or not all(
                        type(g) is dict and account_key_valid(g.get('ckey')) and faction_id_valid(g.get('faction'))
                        for g in colony_grants):
                    raise TransferError('invalid colony grants')
                self.db.execute('DELETE FROM colony_grant')
                for g in colony_grants:
                    self.db.execute('INSERT OR REPLACE INTO colony_grant VALUES (?, ?)', (g['ckey'], g['faction']))
            # The chart comes only when ours is older; keep ours otherwise.
            if chart is not None:
                if type(chart) is not dict or not isinstance(chart.get('key'), str) or type(chart.get('rows')) is not list \
                        or not all(isinstance(r, str) for r in chart['rows']) or type(chart.get('tiles')) is not dict:
                    raise TransferError('invalid world chart snapshot')
                self._set_meta('chart', json.dumps(chart, sort_keys=True))
            for request_id in chart_done or []:
                self.db.execute('DELETE FROM chart_request WHERE id = ?', (int(request_id),))
            if nations is not None:
                if type(nations) is not dict or len(nations) > MAX_NATIONS:
                    raise TransferError('invalid nation registry')
                self._set_meta('nations', json.dumps(nations, sort_keys=True))
            if nation_results is not None:
                if type(nation_results) is not list or not all(
                        type(r) is dict and type(r.get('id')) is int and (r.get('text') is None or isinstance(r['text'], str))
                        for r in nation_results):
                    raise TransferError('invalid nation results')
                now = int(time.time())
                for r in nation_results:
                    row = self.db.execute('SELECT body FROM nation_request WHERE id = ?', (r['id'],)).fetchone()
                    if not row:
                        continue
                    asked = json.loads(row[0])
                    if r['text']:
                        self.db.execute('INSERT OR REPLACE INTO nation_result VALUES (?, ?, ?, ?, ?)',
                                        (r['id'], asked['actor'], asked['faction'], r['text'][:300], now))
                    self.db.execute('DELETE FROM nation_request WHERE id = ?', (r['id'],))
                # A leader who never comes back does not keep outcomes forever.
                self.db.execute('DELETE FROM nation_result WHERE at < ?', (now - NATION_RESULT_SECONDS,))
        return {'rev': rev}

    # -- land stages ---------------------------------------------------------

    def request_land(self, region, stage, paused, admin):
        """An admin's change to a land's stage or pause, decided on the
        coordinator's next pass (the newest change for a land wins)."""
        if not land_id_valid(region):
            raise TransferError('bad land id')
        if stage not in LAND_STAGES:
            raise TransferError('unknown land stage')
        if paused not in (True, False):
            raise TransferError('paused must be true or false')
        if not account_key_valid(admin):
            raise TransferError('bad admin key')
        with self._tx():
            if region == self._meta('mainland'):
                raise TransferError('the mainland has no stage to set')
            cursor = self.db.execute('INSERT INTO land_request(region, stage, paused, admin) VALUES (?, ?, ?, ?)',
                                     (region, stage, 1 if paused else 0, admin))
        return {'id': cursor.lastrowid}

    def land_sample(self, players, living, colonies=None):
        """The world's population now: players connected and living characters
        that belong to an account, and the colonies planted here (each with the
        faction it was planted for, its local name, its age in hours, and its living
        members). The coordinator reads the latest one each pass."""
        if type(players) is not int or type(living) is not int or not 0 <= players <= 1000 or not 0 <= living <= 10000:
            raise TransferError('bad population sample')
        colonies = [] if colonies is None else colonies
        if type(colonies) is not list or len(colonies) > MAX_COLONIES or not all(colony_valid(c) for c in colonies):
            raise TransferError('bad colony list')
        sample = {'players': players, 'living': living, 'at': int(time.time()),
                  'colonies': [{k: c[k] for k in ('parent', 'name', 'age_hours', 'members')} for c in colonies]}
        with self._tx():
            self._set_meta('land_sample', json.dumps(sample, sort_keys=True))
        return {}

    def lands(self):
        """Every land's stage as last sent by the coordinator, and the admin
        changes still waiting for it."""
        return {'mainland': self._meta('mainland') or None, 'start_region': self.start_region(), 'lands': json.loads(self._meta('lands')),
                'pending': [dict(zip(('region', 'stage', 'paused', 'admin'), (r, st, bool(p), a)))
                            for r, st, p, a in self.db.execute(
                                'SELECT region, stage, paused, admin FROM land_request ORDER BY id')]}

    # -- nations -------------------------------------------------------------

    def request_nation(self, body):
        """A faction leader's nation request from this world, decided on the
        coordinator's next pass (tools/transfer_storage/nations.py)."""
        from tools.transfer_storage.nations import nation_request_valid
        if type(body) is not dict:
            raise TransferError('bad nation request')
        request = {k: body[k] for k in ('op', 'actor', 'faction', 'name', 'with', 'nation', 'applicant', 'yes',
                                        'candidate', 'to', 'tier', 'issuer', 'type', 'person', 'pname', 'pfaction',
                                        'religion', 'age', 'role', 'motion', 'choice', 'citizens',
                                        'wealth', 'sname', 'act', 'reason', 'office', 'other', 'treaty') if k in body}
        if not nation_request_valid(request):
            raise TransferError('bad nation request')
        if request['op'] != 'staff' and not request['faction'].startswith('civ:%s:' % self.region):
            raise TransferError('a world asks only for its own factions')
        with self._tx():
            if self.db.execute('SELECT COUNT(*) FROM nation_request').fetchone()[0] >= MAX_NATION_REQUESTS:
                raise TransferError('too many nation requests waiting')
            cursor = self.db.execute('INSERT INTO nation_request(body) VALUES (?)', (json.dumps(request, sort_keys=True),))
        return {'id': cursor.lastrowid}

    def nations(self):
        """The nation registry as last sent by the coordinator, requests still
        waiting for it, and outcomes the world has not yet told."""
        return {'nations': json.loads(self._meta('nations')),
                'pending': [json.loads(b) for (b,) in self.db.execute('SELECT body FROM nation_request ORDER BY id')],
                'results': [dict(zip(('id', 'actor', 'faction', 'text'), row)) for row in self.db.execute(
                    'SELECT id, actor, faction, text FROM nation_result ORDER BY id')]}

    def nation_seen(self, ids):
        """Outcomes the world has told their leader."""
        if type(ids) is not list or not all(type(i) is int for i in ids):
            raise TransferError('bad nation result ids')
        with self._tx():
            for i in ids:
                self.db.execute('DELETE FROM nation_result WHERE id = ?', (i,))
        return {}

    # -- world chart ---------------------------------------------------------

    def request_chart(self, op, x, y, admin, owner=None, voyage=None, data=None):
        """A chart change from this world, decided on the coordinator's next
        pass: an admin's 'reroll' of a charted tile or 'reveal' of the tiles
        round one for an owner, or a ship's 'scout' (what her crew saw round a
        tile) or 'course' (she set course for a land; voyage names her
        voyage), or a land's own crew deciding on it: 'settle', 'claim' (owner
        is the colony's parent faction), 'unclaim' (that faction gives its claim
        up) or 'abandon', or 'summon': the account's character is on a parked
        land (its home is 'land:x,y') and asks for it to be restored. 'access'
        and 'pass' come from a faction's leader or officers, in any land, for
        the island it claims at x, y (owner is the faction): data holds the
        new mode, one guest edit, or a visitor pass's account and hours. admin is
        the account asking."""
        if op not in ('reroll', 'reveal', 'scout', 'course', 'settle', 'claim', 'unclaim', 'abandon', 'summon', 'access', 'pass'):
            raise TransferError('unknown chart request')
        if type(x) is not int or type(y) is not int or not 0 <= x < 1000 or not 0 <= y < 1000:
            raise TransferError('bad chart tile')
        if not account_key_valid(admin):
            raise TransferError('bad admin key')
        if op in ('claim', 'unclaim'):
            # The claim's owner is the colony's parent faction (colony_charter.dm).
            # ...or the asking player themself, crew:<ckey> (land_choices.dm).
            if not (isinstance(owner, str) and (re.match(r'^civ:[a-z0-9_\-]{1,40}:[^\x00-\x1f]{1,60}$', owner)
                                                or owner == 'crew:' + admin)):
                raise TransferError('bad claiming faction')
        elif op in ('access', 'pass'):
            if not (isinstance(owner, str) and re.match(r'^civ:[a-z0-9_\-]{1,40}:[^\x00-\x1f]{1,60}$', owner)):
                raise TransferError('bad island faction')
            data = _island_access_data(op, data)
        elif op in ('settle', 'abandon', 'summon'):
            owner = None
        elif op != 'reroll' and not (isinstance(owner, str) and re.match(r'^(admin|faction:[a-z0-9_\-]{1,40}|crew:[a-z0-9_\-]{1,40})$', owner)):
            raise TransferError('bad chart owner')
        if op == 'course' and not (isinstance(voyage, str) and re.match(r'^[a-z0-9_\-]{1,80}$', voyage)):
            raise TransferError('bad voyage')
        with self._tx():
            cursor = self.db.execute('INSERT INTO chart_request(op, x, y, owner, admin, voyage, data) VALUES (?, ?, ?, ?, ?, ?, ?)',
                                     (op, x, y, owner if op not in ('reroll', 'settle', 'abandon', 'summon') else None, admin,
                                      voyage if op == 'course' else None,
                                      json.dumps(data, sort_keys=True) if op in ('access', 'pass') else None))
        return {'id': cursor.lastrowid}

    def chart(self):
        """The world chart as last sent by the coordinator, and the admin
        changes still waiting for it."""
        return {'chart': json.loads(self._meta('chart')),
                'pending': [dict(zip(('op', 'x', 'y', 'owner', 'admin'), row)) for row in self.db.execute(
                    'SELECT op, x, y, owner, admin FROM chart_request ORDER BY id')]}

    # -- inspection ---------------------------------------------------------

    # -- shared player records (records.py) ------------------------------------

    def add_records(self, records):
        with self._tx():
            return {'ids': player_records.region_add(self.db, self.region, records)}

    def record_outbox(self):
        return player_records.region_outbox(self.db)

    def ack_records(self, ids):
        with self._tx():
            return {'acked': player_records.region_ack(self.db, ids)}

    def status(self):
        return {
            'region': self.region,
            'ledger_seq': self.ledger_seq(),
            'confirmed_generation': self._meta('confirmed_generation'),
            'hold_reason': self._meta('hold_reason'),
            'active': [dict(zip(('direction', 'peer', 'seq', 'transfer_id', 'phase'), r)) for r in
                       self.db.execute('SELECT direction, peer, seq, transfer_id, phase FROM active ORDER BY direction, peer')],
            'fences': [dict(zip(('direction', 'peer', 'epoch', 'settled_seq'), r)) for r in
                       self.db.execute('SELECT direction, peer, epoch, settled_seq FROM fence ORDER BY direction, peer')],
            'journal': self.db.execute('SELECT COUNT(*) FROM journal').fetchone()[0],
            'pending_transfers': [tid for (tid,) in self.db.execute(
                "SELECT transfer_id FROM active WHERE (direction = 'in' AND phase = ?) OR (direction = 'out' AND phase = ?)",
                (COMMIT_RECEIVED, RETURNING))],
            # What each pending transfer carries, so DM can pick where it lands
            # before it records the effect.
            'pending_kinds': {tid: payload_kinds(manifest) for (tid, manifest) in self.db.execute(
                "SELECT transfer_id, manifest FROM active WHERE (direction = 'in' AND phase = ?) OR (direction = 'out' AND phase = ?)",
                (COMMIT_RECEIVED, RETURNING))},
        }

    def clear_hold(self, reason):
        """Operator step after a reviewed recovery. Never touches fences."""
        with self._tx():
            if self._meta('hold_reason') != reason:
                raise TransferError('hold reason changed; re-read status first')
            self._set_meta('hold_reason', '')
