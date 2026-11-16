"""Nations: unions of factions across the region group (docs/land-stages.md,
"Nations").

A nation is a union of factions that keep their own leaders, research,
treasuries, recruitment and member limits, and may oppose each other. The
coordinator keeps the registry for the whole group, so one nation can hold
factions from several lands. A faction is named by its land-qualified id
(civ:<land>:<name>, colony_charter.dm). Worlds queue their leaders' requests
with their agent; the coordinator decides them on its pass, sends every agent
the registry, and tells the asking world each request's outcome.

Rules (Val approved, 2026-11-14): two or more faction leaders found a nation;
a faction joins by application and a majority vote of the member factions'
leaders; a faction may secede at any time and then waits SECEDE_COOLDOWN
before it may rejoin that nation; a nation left with one faction dissolves;
member factions elect a head by majority, whose powers are symbolic. Member
factions may also adopt one member faction's coin as the nation's common money
by majority (Val GO 2026-11-16, docs/money-changers.md); a vote for no faction
drops it. A nation
takes at most capacity() factions: NATION_CAPACITY by the highest tier of
assembly any member faction keeps standing (nation_assembly.dm). A faction
renamed in its own land keeps its place.
"""
import time

from tools.transfer_storage.region import account_key_valid, faction_id_valid

NATION_OPS = ('found', 'apply', 'vote', 'head', 'secede', 'rename', 'assembly', 'currency')
NATION_NAME_MAX = 40
# Member factions allowed by assembly tier: none, meeting ground, assembly
# hall, parliament.
NATION_CAPACITY = (3, 4, 6, 8)
NATION_MAX_FACTIONS = NATION_CAPACITY[-1]
APPLICATION_SECONDS = 3 * 24 * 3600
SECEDE_COOLDOWN = 3 * 24 * 3600


def nation_name_valid(name):
    return type(name) is str and 3 <= len(name.strip()) <= NATION_NAME_MAX and name == name.strip() and all(
        c.isalnum() or c in " '-." for c in name)


def nation_request_valid(r):
    """A leader's request as a world queues it."""
    if type(r) is not dict or r.get('op') not in NATION_OPS or not account_key_valid(r.get('actor')):
        return False
    if not faction_id_valid(r.get('faction')):
        return False
    op = r['op']
    if op == 'found':
        others = r.get('with')
        return (nation_name_valid(r.get('name')) and type(others) is list and 1 <= len(others) < NATION_CAPACITY[0]
                and all(faction_id_valid(f) for f in others) and r['faction'] not in others
                and len(set(others)) == len(others))
    if op == 'apply':
        return type(r.get('nation')) is str and len(r['nation']) <= 16
    if op == 'vote':
        return faction_id_valid(r.get('applicant')) and r.get('yes') in (True, False)
    if op == 'head':
        return faction_id_valid(r.get('candidate'))
    if op == 'currency':
        # The faction whose coin to adopt, or '' for none.
        return r.get('issuer') == '' or faction_id_valid(r.get('issuer'))
    if op == 'rename':
        to = r.get('to')
        return faction_id_valid(to) and to != r['faction'] and faction_land(to) == faction_land(r['faction'])
    if op == 'assembly':
        return type(r.get('tier')) is int and 0 <= r['tier'] < len(NATION_CAPACITY)
    return True  # secede


def faction_land(faction):
    return faction[4:].partition(':')[0]


class Nations:
    def __init__(self, db):
        self.db = db
        db.execute('''CREATE TABLE IF NOT EXISTS nation(
            id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE, head TEXT, founded INTEGER NOT NULL)''')
        db.execute('''CREATE TABLE IF NOT EXISTS nation_member(
            faction TEXT PRIMARY KEY, nation TEXT NOT NULL, joined INTEGER NOT NULL)''')
        db.execute('''CREATE TABLE IF NOT EXISTS nation_application(
            faction TEXT PRIMARY KEY, nation TEXT NOT NULL, at INTEGER NOT NULL)''')
        db.execute('''CREATE TABLE IF NOT EXISTS nation_vote(
            nation TEXT NOT NULL, kind TEXT NOT NULL, voter TEXT NOT NULL, choice TEXT NOT NULL,
            PRIMARY KEY(nation, kind, voter))''')
        db.execute('''CREATE TABLE IF NOT EXISTS nation_cooldown(
            faction TEXT NOT NULL, nation TEXT NOT NULL, until INTEGER NOT NULL, PRIMARY KEY(faction, nation))''')
        # The highest assembly tier each member faction keeps standing in its land.
        db.execute('''CREATE TABLE IF NOT EXISTS nation_assembly(
            faction TEXT PRIMARY KEY, tier INTEGER NOT NULL)''')
        # The member faction whose coin the nation adopted as its common money.
        db.execute('''CREATE TABLE IF NOT EXISTS nation_currency(
            nation TEXT PRIMARY KEY, issuer TEXT NOT NULL)''')
        db.execute("CREATE TABLE IF NOT EXISTS nation_seq(id INTEGER PRIMARY KEY CHECK (id = 1), next INTEGER NOT NULL)")
        db.execute('INSERT OR IGNORE INTO nation_seq VALUES (1, 1)')

    # -- reading ---------------------------------------------------------------

    def nation_of(self, faction):
        row = self.db.execute('SELECT nation FROM nation_member WHERE faction = ?', (faction,)).fetchone()
        return row[0] if row else None

    def members(self, nation):
        return [f for (f,) in self.db.execute('SELECT faction FROM nation_member WHERE nation = ? ORDER BY joined, faction',
                                               (nation,))]

    def assembly_tier(self, nation):
        row = self.db.execute('''SELECT MAX(a.tier) FROM nation_assembly a JOIN nation_member m ON m.faction = a.faction
            WHERE m.nation = ?''', (nation,)).fetchone()
        return row[0] or 0

    def currency(self, nation):
        row = self.db.execute('SELECT issuer FROM nation_currency WHERE nation = ?', (nation,)).fetchone()
        return row[0] if row else None

    def capacity(self, nation):
        """How many factions the nation may hold (raised by its assembly)."""
        return NATION_CAPACITY[self.assembly_tier(nation)]

    def snapshot(self, now=None):
        """The registry every world gets: nation id -> name, head, founded,
        members, capacity, assembly tier (the nation's and each member's),
        open applications with their votes, head votes, the common currency
        (a member faction id or None) and currency votes."""
        now = time.time() if now is None else now
        self.expire(now)
        result = {}
        for nid, name, head, founded in self.db.execute('SELECT id, name, head, founded FROM nation ORDER BY id'):
            votes = {}
            for kind, voter, choice in self.db.execute('SELECT kind, voter, choice FROM nation_vote WHERE nation = ?', (nid,)):
                votes.setdefault(kind, {})[voter] = choice
            result[nid] = {
                'name': name, 'head': head, 'founded': founded, 'members': self.members(nid),
                'capacity': self.capacity(nid), 'assembly': self.assembly_tier(nid),
                'assemblies': dict(self.db.execute('''SELECT a.faction, a.tier FROM nation_assembly a
                    JOIN nation_member m ON m.faction = a.faction WHERE m.nation = ?''', (nid,))),
                'applications': [{'faction': f, 'at': at, 'votes': votes.get('admit:' + f, {})} for f, at in self.db.execute(
                    'SELECT faction, at FROM nation_application WHERE nation = ? ORDER BY at, faction', (nid,))],
                'head_votes': votes.get('head', {}),
                'currency': self.currency(nid), 'currency_votes': votes.get('currency', {})}
        return result

    def expire(self, now):
        old = [f for (f,) in self.db.execute('SELECT faction FROM nation_application WHERE at < ?',
                                              (int(now) - APPLICATION_SECONDS,))]
        for f in old:
            self._drop_application(f)
        self.db.execute('DELETE FROM nation_cooldown WHERE until < ?', (int(now),))

    # -- deciding --------------------------------------------------------------

    def decide(self, source, r, now=None):
        """One request from world source. Returns the outcome as a sentence
        for the leader who asked."""
        now = int(time.time() if now is None else now)
        if not nation_request_valid(r):
            return 'That nation request was not understood.'
        faction = r['faction']
        # A world speaks only for factions founded in it.
        if faction_land(faction) != source:
            return 'Only a faction in its own land can act for it.'
        self.expire(now)
        op = r['op']
        if op == 'found':
            return self._found(source, r, now)
        if op == 'rename':
            return self._rename(faction, r['to'])
        if op == 'assembly':
            # Kept even outside a nation, so a faction that joins brings it.
            if r['tier']:
                self.db.execute('INSERT OR REPLACE INTO nation_assembly VALUES (?, ?)', (faction, r['tier']))
            else:
                self.db.execute('DELETE FROM nation_assembly WHERE faction = ?', (faction,))
            return None
        nation = self.nation_of(faction)
        if op == 'apply':
            return self._apply(faction, r['nation'], now)
        if not nation:
            return 'Your faction is not part of a nation.'
        if op == 'secede':
            return self._secede(faction, nation, now)
        if op == 'vote':
            return self._vote(faction, nation, r['applicant'], r['yes'], now)
        if op == 'currency':
            return self._currency(faction, nation, r['issuer'])
        return self._head(faction, nation, r['candidate'])

    def _found(self, source, r, now):
        founders = [r['faction']] + r['with']
        if any(faction_land(f) != source for f in founders):
            return 'Every founding faction must sign in the same land.'
        if any(self.nation_of(f) for f in founders):
            return 'A founding faction already belongs to a nation.'
        name = r['name']
        if self.db.execute('SELECT 1 FROM nation WHERE name = ?', (name,)).fetchone():
            return 'A nation called %s already exists.' % name
        seq = self.db.execute('SELECT next FROM nation_seq WHERE id = 1').fetchone()[0]
        nid = 'n%d' % seq
        self.db.execute('UPDATE nation_seq SET next = ? WHERE id = 1', (seq + 1,))
        self.db.execute('INSERT INTO nation VALUES (?, ?, ?, ?)', (nid, name, r['faction'], now))
        for f in founders:
            self._drop_application(f)
            self.db.execute('INSERT INTO nation_member VALUES (?, ?, ?)', (f, nid, now))
        return 'The nation of %s is founded.' % name

    def _apply(self, faction, nation, now):
        if self.nation_of(faction):
            return 'Your faction already belongs to a nation.'
        row = self.db.execute('SELECT name FROM nation WHERE id = ?', (nation,)).fetchone()
        if not row:
            return 'That nation no longer exists.'
        if self.db.execute('SELECT 1 FROM nation_cooldown WHERE faction = ? AND nation = ?', (faction, nation)).fetchone():
            return 'Your faction left %s recently and cannot apply again yet.' % row[0]
        if len(self.members(nation)) >= self.capacity(nation):
            return '%s holds as many factions as its assembly allows.' % row[0]
        self._drop_application(faction)
        self.db.execute('INSERT INTO nation_application VALUES (?, ?, ?)', (faction, nation, now))
        return 'Your faction applied to join %s. Its member factions will vote.' % row[0]

    def _drop_application(self, faction):
        row = self.db.execute('SELECT nation FROM nation_application WHERE faction = ?', (faction,)).fetchone()
        if row:
            self.db.execute('DELETE FROM nation_vote WHERE nation = ? AND kind = ?', (row[0], 'admit:' + faction))
            self.db.execute('DELETE FROM nation_application WHERE faction = ?', (faction,))

    def _vote(self, voter, nation, applicant, yes, now):
        if not self.db.execute('SELECT 1 FROM nation_application WHERE faction = ? AND nation = ?',
                               (applicant, nation)).fetchone():
            return 'There is no such application.'
        kind = 'admit:' + applicant
        self.db.execute('INSERT OR REPLACE INTO nation_vote VALUES (?, ?, ?, ?)', (nation, kind, voter, 'yes' if yes else 'no'))
        members = len(self.members(nation))
        choices = [c for (c,) in self.db.execute('SELECT choice FROM nation_vote WHERE nation = ? AND kind = ?', (nation, kind))]
        if choices.count('yes') * 2 > members:
            if members >= self.capacity(nation):
                self._drop_application(applicant)
                return 'The nation is full, so the application lapses.'
            self._drop_application(applicant)
            self.db.execute('INSERT INTO nation_member VALUES (?, ?, ?)', (applicant, nation, now))
            return 'The vote passed: the faction joins the nation.'
        if choices.count('no') * 2 >= members:
            self._drop_application(applicant)
            return 'The vote failed: the application is refused.'
        return 'Your vote is counted.'

    def _head(self, voter, nation, candidate):
        if self.nation_of(candidate) != nation:
            return 'Only a member faction can lead the nation.'
        self.db.execute('INSERT OR REPLACE INTO nation_vote VALUES (?, ?, ?, ?)', (nation, 'head', voter, candidate))
        members = len(self.members(nation))
        choices = [c for (c,) in self.db.execute("SELECT choice FROM nation_vote WHERE nation = ? AND kind = 'head'", (nation,))]
        if choices.count(candidate) * 2 > members:
            self.db.execute('UPDATE nation SET head = ? WHERE id = ?', (candidate, nation))
            self.db.execute("DELETE FROM nation_vote WHERE nation = ? AND kind = 'head'", (nation,))
            return 'A majority chose the new head of the nation.'
        return 'Your vote for head is counted.'

    def _currency(self, voter, nation, issuer):
        if issuer and self.nation_of(issuer) != nation:
            return "Only a member faction's coin can be the nation's money."
        choice = issuer or 'none'
        self.db.execute('INSERT OR REPLACE INTO nation_vote VALUES (?, ?, ?, ?)', (nation, 'currency', voter, choice))
        members = len(self.members(nation))
        choices = [c for (c,) in self.db.execute("SELECT choice FROM nation_vote WHERE nation = ? AND kind = 'currency'", (nation,))]
        if choices.count(choice) * 2 > members:
            if issuer:
                self.db.execute('INSERT OR REPLACE INTO nation_currency VALUES (?, ?)', (nation, issuer))
            else:
                self.db.execute('DELETE FROM nation_currency WHERE nation = ?', (nation,))
            self.db.execute("DELETE FROM nation_vote WHERE nation = ? AND kind = 'currency'", (nation,))
            return 'A majority chose the common money of the nation.' if issuer else 'A majority chose to have no common money.'
        return 'Your vote on the common money is counted.'

    def _rename(self, old, new):
        """A faction renamed in its own land keeps its membership, votes,
        application, cooldowns and assembly."""
        if self.db.execute('SELECT 1 FROM nation_member WHERE faction = ?', (new,)).fetchone() or \
                self.db.execute('SELECT 1 FROM nation_application WHERE faction = ?', (new,)).fetchone():
            return None  # a stale row under the new name; keep the old one
        for table, column in (('nation_member', 'faction'), ('nation_application', 'faction'), ('nation_vote', 'voter'),
                              ('nation_vote', 'choice'), ('nation_cooldown', 'faction'), ('nation_assembly', 'faction'),
                              ('nation', 'head'), ('nation_currency', 'issuer')):
            self.db.execute('UPDATE OR REPLACE %s SET %s = ? WHERE %s = ?' % (table, column, column), (new, old))
        self.db.execute('UPDATE nation_vote SET kind = ? WHERE kind = ?', ('admit:' + new, 'admit:' + old))
        return None

    def _secede(self, faction, nation, now):
        self.db.execute('DELETE FROM nation_member WHERE faction = ?', (faction,))
        self.db.execute('DELETE FROM nation_vote WHERE nation = ? AND voter = ?', (nation, faction))
        self.db.execute('INSERT OR REPLACE INTO nation_cooldown VALUES (?, ?, ?)', (faction, nation, now + SECEDE_COOLDOWN))
        rest = self.members(nation)
        if len(rest) < 2:
            self.db.execute('DELETE FROM nation WHERE id = ?', (nation,))
            self.db.execute('DELETE FROM nation_member WHERE nation = ?', (nation,))
            self.db.execute('DELETE FROM nation_vote WHERE nation = ?', (nation,))
            self.db.execute('DELETE FROM nation_currency WHERE nation = ?', (nation,))
            for (f,) in self.db.execute('SELECT faction FROM nation_application WHERE nation = ?', (nation,)).fetchall():
                self._drop_application(f)
            return 'Your faction seceded, and with one faction left the nation dissolved.'
        # A nation cannot keep the coin of a faction that left it.
        self.db.execute('DELETE FROM nation_currency WHERE nation = ? AND issuer = ?', (nation, faction))
        self.db.execute("DELETE FROM nation_vote WHERE nation = ? AND kind = 'currency' AND choice = ?", (nation, faction))
        head = self.db.execute('SELECT head FROM nation WHERE id = ?', (nation,)).fetchone()[0]
        if head == faction:
            # The longest-standing member speaks for the nation until a vote.
            self.db.execute('UPDATE nation SET head = ? WHERE id = ?', (rest[0], nation))
        return 'Your faction seceded from the nation.'
