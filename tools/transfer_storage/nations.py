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

Governments (Val GO 2026-11-21, docs/nation-government.md): a nation picks a
system of government. Confederation is the default and is exactly the rules
above. The others (GOVERNMENTS) change who heads the nation, who admits new
members, how much notice a seceding faction gives and how large the nation may
grow. Member factions keep their own leaders, offices and courts whatever the
nation's government. A change is voted by two thirds of the member factions
(under a personal rule, the ruler decides alone), takes effect after
GOVERNMENT_NOTICE and is allowed once per GOVERNMENT_COOLDOWN. A type needs a
majority of the member factions' lands to have reached its ordinal age, which
each world reports with the 'era' op.
"""
import json
import time

from tools.transfer_storage.nation_motions import CITIZENS_MAX, WEALTH_MAX, NationMotions
from tools.transfer_storage.nation_succession import NationSuccession
from tools.transfer_storage.nation_revolt import NationRevolt
from tools.transfer_storage.nation_offices import OFFICES, NationOffices
from tools.transfer_storage.nation_treaties import TREATY_KINDS, NationTreaties
from tools.transfer_storage.nation_staff import FROZEN_OPS, STAFF_ACTS, STAFF_REASON_MAX, NationStaff
from tools.transfer_storage.region import account_key_valid, faction_id_valid

NATION_OPS = ('found', 'apply', 'vote', 'head', 'secede', 'rename', 'assembly', 'currency', 'govern', 'stay', 'era', 'ballot',
              'stand', 'census', 'present', 'heir', 'deputy', 'faith', 'claim', 'revolt', 'sign', 'overthrow', 'staff',
              'appoint', 'dismiss', 'treaty')
NATION_NAME_MAX = 40
# Member factions allowed by assembly tier: none, meeting ground, assembly
# hall, parliament.
NATION_CAPACITY = (3, 4, 6, 8)
# A government may let a nation hold a few more factions, never more than this.
NATION_MAX_FACTIONS = 9
APPLICATION_SECONDS = 3 * 24 * 3600
SECEDE_COOLDOWN = 3 * 24 * 3600
HOUR = 3600
DAY = 24 * HOUR
# Type -> name, the ruler's title (None: the member factions rule together),
# earliest ordinal age, extra factions held, secession notice in seconds, and
# whether the ruler alone decides (admissions, the common money, a change of
# government); the body that votes and the head's term in days (elective,
# nation_motions.py); and how many days the head may be away before the seat
# passes on (nation_succession.py); and the share of eligible citizens a
# revolt petition needs (nation_revolt.py). Starting values from the approved plan, to
# tune after play.
GOVERNMENTS = {
    'confederation': {'name': 'Confederation', 'ruler': None, 'age': 0, 'bonus': 0, 'notice': 0, 'personal': False,
                      'body': None, 'term': 0, 'away': 0, 'revolt': 0.5},
    'theocracy': {'name': 'Theocracy', 'ruler': 'High Priest', 'age': 0, 'bonus': 0, 'notice': DAY, 'personal': True,
                  'body': None, 'term': 0, 'away': 7, 'revolt': 0.5},
    'monarchy': {'name': 'Monarchy', 'ruler': 'Monarch', 'age': 1, 'bonus': 1, 'notice': 2 * DAY, 'personal': True,
                 'body': None, 'term': 0, 'away': 7, 'revolt': 0.5},
    'dictatorship': {'name': 'Dictatorship', 'ruler': 'Dictator', 'age': 1, 'bonus': 2, 'notice': 3 * DAY,
                     'personal': True, 'body': None, 'term': 0, 'away': 3, 'revolt': 0.33},
    # Elective governments decide by motion (nation_motions.py) and elect
    # their head for a term in days.
    'republic': {'name': 'Republic', 'ruler': 'Consul', 'age': 1, 'bonus': 1, 'notice': DAY, 'personal': False,
                 'body': 'senate', 'term': 14, 'away': 3, 'revolt': 0.66},
    'democracy': {'name': 'Democracy', 'ruler': 'Archon', 'age': 1, 'bonus': 0, 'notice': DAY, 'personal': False,
                  'body': 'referendum', 'term': 7, 'away': 3, 'revolt': 0.75},
    'league': {'name': 'Merchant league', 'ruler': 'Doge', 'age': 2, 'bonus': 1, 'notice': DAY, 'personal': False,
               'body': 'council', 'term': 14, 'away': 3, 'revolt': 0.4},
}
DEFAULT_GOVERNMENT = 'confederation'
GOVERNMENT_NOTICE = DAY
GOVERNMENT_COOLDOWN = 7 * DAY
PERSON_NAME_MAX = 64
RELIGION_NAME_MAX = 40
AGE_MAX = 9


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
    if op == 'era':
        return type(r.get('age')) is int and 0 <= r['age'] <= AGE_MAX
    if op == 'staff':
        act = r.get('act')
        return act in STAFF_ACTS and text_valid(r.get('reason'), STAFF_REASON_MAX) and (
            act != 'void_motion' or type(r.get('motion')) is int) and (act != 'set' or government_proposal_valid(r))
    if r.get('role', 'leader') not in ('leader', 'citizen'):
        return False
    if op == 'govern':
        return government_proposal_valid(r)
    if op == 'appoint':
        return r.get('office') in OFFICES and account_key_valid(r.get('person')) and \
            text_valid(r.get('pname'), PERSON_NAME_MAX) and faction_id_valid(r.get('pfaction'))
    if op == 'dismiss':
        return r.get('office') in OFFICES
    if op == 'treaty':
        return type(r.get('other')) is str and 0 < len(r['other']) <= 16 and r.get('treaty') in TREATY_KINDS \
            and r.get('act') in ('agree', 'renounce')
    if op == 'revolt':
        return government_proposal_valid(r) and text_valid(r.get('sname'), PERSON_NAME_MAX)
    if op == 'sign':
        return text_valid(r.get('sname'), PERSON_NAME_MAX)
    if op == 'ballot':
        return type(r.get('motion')) is int and type(r.get('choice')) is str and 0 < len(r['choice']) <= 32
    if op == 'stand':
        return text_valid(r.get('pname'), PERSON_NAME_MAX)
    if op in ('heir', 'deputy'):
        return account_key_valid(r.get('person')) and text_valid(r.get('pname'), PERSON_NAME_MAX) and \
            faction_id_valid(r.get('pfaction'))
    if op == 'faith':
        return text_valid(r.get('pname'), PERSON_NAME_MAX) and text_valid(r.get('religion'), RELIGION_NAME_MAX)
    if op == 'claim':
        return text_valid(r.get('pname'), PERSON_NAME_MAX)
    if op == 'census':
        return type(r.get('citizens')) is int and 0 <= r['citizens'] <= CITIZENS_MAX and \
            type(r.get('wealth')) is int and 0 <= r['wealth'] <= WEALTH_MAX
    return True  # secede, stay, overthrow


def text_valid(value, limit):
    return type(value) is str and 0 < len(value) <= limit and value == value.strip() and \
        not any(c in value for c in '<>&"|\n\r\t')


def government_proposal_valid(r):
    """A change of government: the type and, except for a confederation, the
    person to head it (account, character name, member faction) and, for a
    theocracy, the state religion."""
    kind = r.get('type')
    if kind not in GOVERNMENTS:
        return False
    if kind == DEFAULT_GOVERNMENT:
        return not r.get('person') and not r.get('religion')
    if not (account_key_valid(r.get('person')) and text_valid(r.get('pname'), PERSON_NAME_MAX)
            and faction_id_valid(r.get('pfaction'))):
        return False
    if kind == 'theocracy':
        return text_valid(r.get('religion'), RELIGION_NAME_MAX)
    return not r.get('religion')


def government_choice(r):
    """The proposal as one comparable vote choice."""
    return json.dumps([r['type'], r.get('person') or '', r.get('pname') or '', r.get('pfaction') or '',
                       r.get('religion') or ''])


def faction_land(faction):
    return faction[4:].partition(':')[0]


class Nations(NationMotions, NationSuccession, NationRevolt, NationStaff, NationOffices, NationTreaties):
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
        # The nation's government; a nation without a row is a confederation.
        # pending is a proposal (government_choice) taking effect at pending_at.
        db.execute('''CREATE TABLE IF NOT EXISTS nation_government(
            nation TEXT PRIMARY KEY, type TEXT NOT NULL, since INTEGER NOT NULL, changed INTEGER NOT NULL,
            head_account TEXT, head_name TEXT, religion TEXT, pending TEXT, pending_at INTEGER)''')
        # The ordinal age each faction's land has reached, as its world reports it.
        db.execute('''CREATE TABLE IF NOT EXISTS nation_era(
            faction TEXT PRIMARY KEY, age INTEGER NOT NULL)''')
        # Member factions seceding after their government's notice.
        db.execute('''CREATE TABLE IF NOT EXISTS nation_leaving(
            faction TEXT PRIMARY KEY, nation TEXT NOT NULL, at INTEGER NOT NULL)''')
        self._motion_tables()
        self._succession_tables()
        self._revolt_tables()
        self._staff_tables()
        self._office_tables()
        self._treaty_tables()
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
        """How many factions the nation may hold: raised by its assembly and
        by some governments, never above NATION_MAX_FACTIONS."""
        bonus = GOVERNMENTS[self.government(nation)['type']]['bonus']
        return min(NATION_CAPACITY[self.assembly_tier(nation)] + bonus, NATION_MAX_FACTIONS)

    def government(self, nation):
        """The nation's government row as a dict (a confederation without one)."""
        row = self.db.execute('''SELECT type, since, changed, head_account, head_name, religion, pending, pending_at
            FROM nation_government WHERE nation = ?''', (nation,)).fetchone()
        if not row or row[0] not in GOVERNMENTS:
            return {'type': DEFAULT_GOVERNMENT, 'since': 0, 'changed': 0, 'head_account': None, 'head_name': None,
                    'religion': None, 'pending': None, 'pending_at': None}
        g = dict(zip(('type', 'since', 'changed', 'head_account', 'head_name', 'religion', 'pending', 'pending_at'), row))
        g['pending'] = json.loads(g['pending']) if g['pending'] else None
        return g

    def government_info(self, nation):
        return GOVERNMENTS[self.government(nation)['type']]

    def ruler(self, nation):
        """The account that rules alone, or None."""
        g = self.government(nation)
        return g['head_account'] if GOVERNMENTS[g['type']]['personal'] else None

    def era_ready(self, nation, kind):
        """A majority of member factions' lands have reached the type's age."""
        need = GOVERNMENTS[kind]['age']
        if not need:
            return True
        members = self.members(nation)
        ages = dict(self.db.execute('SELECT faction, age FROM nation_era'))
        return sum(1 for f in members if ages.get(f, 0) >= need) * 2 > len(members)

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
                'currency': self.currency(nid), 'currency_votes': votes.get('currency', {}),
                'government': self.government_snapshot(nid),
                'government_votes': {v: json.loads(c) for v, c in votes.get('government', {}).items()},
                'leaving': dict(self.db.execute('SELECT faction, at FROM nation_leaving WHERE nation = ?', (nid,))),
                'motions': self.motions_snapshot(nid), 'term_ends': self.term_ends(nid),
                'revolt': self.revolt_snapshot(nid), 'frozen': self.frozen(nid), 'staff_log': self.staff_log(nid),
                'offices': self.offices(nid), 'treaties': self.treaties_snapshot(nid),
                'census': {f: list(self.census(f)) for f in self.members(nid)},
                'eras': dict(self.db.execute('''SELECT e.faction, e.age FROM nation_era e
                    JOIN nation_member m ON m.faction = e.faction WHERE m.nation = ?''', (nid,)))}
        return result

    def government_snapshot(self, nation):
        g = self.government(nation)
        info = GOVERNMENTS[g['type']]
        pending = None
        if g['pending']:
            kind, person, pname, pfaction, religion = g['pending']
            pending = {'type': kind, 'name': GOVERNMENTS[kind]['name'], 'at': g['pending_at'], 'person': person,
                       'pname': pname, 'pfaction': pfaction, 'religion': religion}
        return {'type': g['type'], 'name': info['name'], 'ruler': info['ruler'], 'personal': info['personal'],
                'body': info['body'], 'term': info['term'], 'away': info['away'], 'revolt': info['revolt'],
                'head_seen': self.head_seen(nation), 'successor': self.successor(nation),
                'notice': info['notice'], 'since': g['since'], 'changed': g['changed'],
                'head_account': g['head_account'], 'head_name': g['head_name'], 'religion': g['religion'],
                'pending': pending}

    def expire(self, now):
        old = [f for (f,) in self.db.execute('SELECT faction FROM nation_application WHERE at < ?',
                                              (int(now) - APPLICATION_SECONDS,))]
        for f in old:
            self._drop_application(f)
        self.db.execute('DELETE FROM nation_cooldown WHERE until < ?', (int(now),))
        for faction, nation in self.db.execute('SELECT faction, nation FROM nation_leaving WHERE at <= ?',
                                               (int(now),)).fetchall():
            if self.nation_of(faction) == nation:
                self._leave(faction, nation, int(now))
            self.db.execute('DELETE FROM nation_leaving WHERE faction = ?', (faction,))
        for (nation,) in self.db.execute('SELECT nation FROM nation_government WHERE pending_at <= ?',
                                         (int(now),)).fetchall():
            if not self.frozen(nation):
                self._establish(nation, int(now))
        self.succession_due(int(now))
        self.motions_due(int(now))
        self.revolts_due(int(now))
        self.offices_due()
        self.treaties_due(int(now))

    # -- deciding --------------------------------------------------------------

    def decide(self, source, r, now=None):
        """One request from world source. Returns the outcome as a sentence
        for the leader who asked."""
        now = int(time.time() if now is None else now)
        if not nation_request_valid(r):
            return 'That nation request was not understood.'
        faction = r['faction']
        if r['op'] == 'staff':
            # Staff act on any nation, naming one of its member factions.
            self.expire(now)
            nation = self.nation_of(faction)
            if not nation:
                return 'That faction is not part of a nation.'
            return self.staff(nation, r, government_choice(r) if r['act'] == 'set' else None, now)
        # A world speaks only for factions founded in it.
        if faction_land(faction) != source:
            return 'Only a faction in its own land can act for it.'
        self.expire(now)
        op = r['op']
        if op == 'found':
            return self._found(source, r, now)
        if op == 'rename':
            return self._rename(faction, r['to'])
        if op == 'era':
            # Kept even outside a nation, like the assembly.
            self.db.execute('INSERT OR REPLACE INTO nation_era VALUES (?, ?)', (faction, r['age']))
            return None
        if op == 'census':
            self.db.execute('INSERT OR REPLACE INTO nation_census VALUES (?, ?, ?)', (faction, r['citizens'], r['wealth']))
            return None
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
        citizen = r.get('role') == 'citizen'
        if op in FROZEN_OPS and self.frozen(nation):
            return 'Staff have paused the government of your nation for now.'
        if op == 'present':
            return self.present(nation, r, now)
        if op in ('heir', 'deputy'):
            return self.name_successor(nation, r, now)
        if op == 'faith':
            return self.faith(nation, r, now)
        if op == 'claim':
            return self.claim(nation, r, now)
        if op == 'treaty':
            return self.treaty_request(nation, r, now)
        if op == 'appoint':
            return self.appoint(nation, r, now)
        if op == 'dismiss':
            return self.dismiss(nation, r, now)
        done = self.office_acts(nation, r, now)
        if done:
            return done
        if op == 'revolt':
            return self.open_revolt(nation, r, government_choice(r), now)
        if op == 'sign':
            return self.sign(nation, r, now)
        if op == 'overthrow':
            return self.overthrow(nation, r, now)
        if self.body(nation):
            if op == 'ballot':
                return self.ballot(nation, r, now)
            if op == 'stand':
                return self.stand(nation, r, now)
            if op == 'vote':
                return self._elective_admit(nation, r, now)
            if op == 'currency':
                if r['issuer'] and self.nation_of(r['issuer']) != nation:
                    return "Only a member faction's coin can be the nation's money."
                return self.propose(nation, 'currency', r['issuer'], r, now)
            if op == 'govern':
                return self._govern(faction, nation, r, now)
        elif op in ('ballot', 'stand'):
            return 'The nation holds no elections or motions under its government.'
        if citizen and op != 'govern':
            return "Only a member faction's leader can do that."
        if op == 'secede':
            return self._secede(faction, nation, now)
        if op == 'stay':
            return self._stay(faction)
        if op == 'govern':
            return self._govern(faction, nation, r, now)
        ruler = self.ruler(nation)
        if op == 'vote':
            if ruler:
                return self._ruler_admits(r['actor'], ruler, nation, r['applicant'], r['yes'], now)
            return self._vote(faction, nation, r['applicant'], r['yes'], now)
        if op == 'currency':
            if ruler:
                return self._ruler_currency(r['actor'], ruler, nation, r['issuer'])
            return self._currency(faction, nation, r['issuer'])
        if self.government(nation)['type'] != DEFAULT_GOVERNMENT:
            return "The nation's head is set by its government, not by a vote of the factions."
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
        if self.body(nation):
            self.open_motion(nation, 'admit', faction, 'world', now)
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
                              ('nation', 'head'), ('nation_currency', 'issuer'), ('nation_era', 'faction'),
                              ('nation_leaving', 'faction'), ('nation_ballot', 'voter'),
                              ('nation_candidate', 'faction'), ('nation_census', 'faction'),
                              ('nation_successor', 'faction')):
            self.db.execute('UPDATE OR REPLACE %s SET %s = ? WHERE %s = ?' % (table, column, column), (new, old))
        self.db.execute('UPDATE nation_vote SET kind = ? WHERE kind = ?', ('admit:' + new, 'admit:' + old))
        # Proposals name the head's faction inside their JSON.
        for nation, voter, choice in self.db.execute(
                "SELECT nation, voter, choice FROM nation_vote WHERE kind = 'government'").fetchall():
            c = json.loads(choice)
            if c[3] == old:
                c[3] = new
                self.db.execute("UPDATE nation_vote SET choice = ? WHERE nation = ? AND kind = 'government' AND voter = ?",
                                (json.dumps(c), nation, voter))
        for mid, kind, subject in self.db.execute('SELECT id, kind, subject FROM nation_motion').fetchall():
            c = json.loads(subject)
            if kind in ('admit', 'currency') and c == old:
                c = new
            elif kind == 'government' and c[3] == old:
                c[3] = new
            else:
                continue
            self.db.execute('UPDATE nation_motion SET subject = ? WHERE id = ?', (json.dumps(c), mid))
        for nation, pending in self.db.execute(
                'SELECT nation, pending FROM nation_government WHERE pending IS NOT NULL').fetchall():
            c = json.loads(pending)
            if c[3] == old:
                c[3] = new
                self.db.execute('UPDATE nation_government SET pending = ? WHERE nation = ?', (json.dumps(c), nation))
        self.revolt_rename(old, new)
        self.offices_rename(old, new)
        return None

    def _secede(self, faction, nation, now):
        row = self.db.execute('SELECT at FROM nation_leaving WHERE faction = ?', (faction,)).fetchone()
        if row:
            return 'Your faction is already leaving the nation; it is out in %d hours.' % max(1, -(-(row[0] - now) // HOUR))
        notice = GOVERNMENTS[self.government(nation)['type']]['notice']
        if notice:
            self.db.execute('INSERT INTO nation_leaving VALUES (?, ?, ?)', (faction, nation, now + notice))
            return 'Your faction gives notice: it leaves the nation in %d hours, unless you choose to stay.' % (notice // HOUR)
        return self._leave(faction, nation, now)

    def _stay(self, faction):
        if not self.db.execute('SELECT 1 FROM nation_leaving WHERE faction = ?', (faction,)).fetchone():
            return 'Your faction is not leaving the nation.'
        self.db.execute('DELETE FROM nation_leaving WHERE faction = ?', (faction,))
        return 'Your faction withdraws its notice and stays in the nation.'

    def _leave(self, faction, nation, now):
        self.db.execute('DELETE FROM nation_member WHERE faction = ?', (faction,))
        self.db.execute('DELETE FROM nation_leaving WHERE faction = ?', (faction,))
        self.db.execute('DELETE FROM nation_vote WHERE nation = ? AND voter = ?', (nation, faction))
        self.db.execute('INSERT OR REPLACE INTO nation_cooldown VALUES (?, ?, ?)', (faction, nation, now + SECEDE_COOLDOWN))
        rest = self.members(nation)
        if len(rest) < 2:
            self.db.execute('DELETE FROM nation WHERE id = ?', (nation,))
            self.db.execute('DELETE FROM nation_member WHERE nation = ?', (nation,))
            self.db.execute('DELETE FROM nation_vote WHERE nation = ?', (nation,))
            self.db.execute('DELETE FROM nation_currency WHERE nation = ?', (nation,))
            self.db.execute('DELETE FROM nation_government WHERE nation = ?', (nation,))
            self.db.execute('DELETE FROM nation_leaving WHERE nation = ?', (nation,))
            self.db.execute('DELETE FROM nation_term WHERE nation = ?', (nation,))
            self.db.execute('DELETE FROM nation_successor WHERE nation = ?', (nation,))
            self.db.execute('DELETE FROM nation_seen WHERE nation = ?', (nation,))
            self.drop_revolt(nation)
            self.staff_dissolved(nation)
            self.clear_offices(nation)
            self.db.execute('DELETE FROM nation_revolt_cooldown WHERE nation = ?', (nation,))
            for (mid,) in self.db.execute('SELECT id FROM nation_motion WHERE nation = ?', (nation,)).fetchall():
                self.close_motion(mid)
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
            # A ruler whose faction leaves takes the government with them: the
            # nation falls back to a confederation.
            self._collapse(nation, now)
        # A proposal naming someone of the faction that left lapses.
        pending = self.government(nation)['pending']
        if pending and pending[3] == faction:
            self.db.execute('UPDATE nation_government SET pending = NULL, pending_at = NULL WHERE nation = ?', (nation,))
        for voter, choice in self.db.execute("SELECT voter, choice FROM nation_vote WHERE nation = ? AND kind = 'government'",
                                             (nation,)).fetchall():
            if json.loads(choice)[3] == faction:
                self.db.execute("DELETE FROM nation_vote WHERE nation = ? AND kind = 'government' AND voter = ?",
                                (nation, voter))
        return 'Your faction seceded from the nation.'

    # -- governments -----------------------------------------------------------

    def _govern(self, faction, nation, r, now):
        """A proposal to change the government: the ruler's decree under a
        personal rule, otherwise a vote of the member factions that passes
        with two thirds."""
        g = self.government(nation)
        info = GOVERNMENTS[r['type']]
        if g['pending']:
            return 'The nation is already changing its government.'
        if g['changed'] and now < g['changed'] + GOVERNMENT_COOLDOWN:
            return 'The nation changed its government recently; it may change again in %d days.' % \
                max(1, -(-(g['changed'] + GOVERNMENT_COOLDOWN - now) // DAY))
        if r['type'] == g['type'] and (r.get('person') or None) == g['head_account']:
            return 'That is already the government of the nation.'
        if r.get('pfaction') and self.nation_of(r['pfaction']) != nation:
            return 'Only a citizen of a member faction can head the nation.'
        if not self.era_ready(nation, r['type']):
            return "A %s needs most member factions' lands to have reached the age it belongs to." % info['name'].lower()
        ruler = self.ruler(nation)
        if ruler:
            if r['actor'] != ruler:
                return 'Only the %s can change the government.' % GOVERNMENTS[g['type']]['ruler']
            self._propose(nation, government_choice(r), now)
            return 'By your decree the nation becomes a %s in a day.' % info['name'].lower()
        if self.body(nation):
            return self.propose(nation, 'government', json.loads(government_choice(r)), r, now)
        if r.get('role') == 'citizen':
            return "Only a member faction's leader can do that."
        choice = government_choice(r)
        self.db.execute('INSERT OR REPLACE INTO nation_vote VALUES (?, ?, ?, ?)', (nation, 'government', faction, choice))
        members = len(self.members(nation))
        choices = [c for (c,) in self.db.execute("SELECT choice FROM nation_vote WHERE nation = ? AND kind = 'government'",
                                                 (nation,))]
        if choices.count(choice) * 3 >= members * 2:
            self._propose(nation, choice, now)
            return 'Two thirds of the member factions agree: the nation becomes a %s in a day.' % info['name'].lower()
        return 'Your vote on the government is counted.'

    def _propose(self, nation, choice, now):
        g = self.government(nation)
        self.db.execute('INSERT OR REPLACE INTO nation_government VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
                        (nation, g['type'], g['since'], g['changed'], g['head_account'], g['head_name'], g['religion'],
                         choice, now + GOVERNMENT_NOTICE))
        self.db.execute("DELETE FROM nation_vote WHERE nation = ? AND kind = 'government'", (nation,))

    def _establish(self, nation, now):
        """A proposal whose notice has run out takes effect."""
        g = self.government(nation)
        if not g['pending']:
            return
        kind, person, pname, pfaction, religion = g['pending']
        if pfaction and self.nation_of(pfaction) != nation:
            self.db.execute('UPDATE nation_government SET pending = NULL, pending_at = NULL WHERE nation = ?', (nation,))
            return
        self.db.execute('INSERT OR REPLACE INTO nation_government VALUES (?, ?, ?, ?, ?, ?, ?, NULL, NULL)',
                        (nation, kind, now, now, person or None, pname or None, religion or None))
        if pfaction:
            self.db.execute('UPDATE nation SET head = ? WHERE id = ?', (pfaction, nation))
        self.db.execute("DELETE FROM nation_vote WHERE nation = ? AND kind = 'head'", (nation,))
        # Motions of the old government lapse; an elective head serves a term.
        for (mid,) in self.db.execute('SELECT id FROM nation_motion WHERE nation = ?', (nation,)).fetchall():
            self.close_motion(mid)
        self.db.execute('DELETE FROM nation_term WHERE nation = ?', (nation,))
        if GOVERNMENTS[kind]['body'] and person:
            self.db.execute('INSERT INTO nation_term VALUES (?, ?)', (nation, now + GOVERNMENTS[kind]['term'] * DAY))
        self.db.execute('DELETE FROM nation_successor WHERE nation = ?', (nation,))
        self.db.execute('DELETE FROM nation_seen WHERE nation = ?', (nation,))
        self.clear_offices(nation)  # a new government appoints its own
        if person:
            self.db.execute('INSERT INTO nation_seen VALUES (?, ?, ?)', (nation, person, now))

    def _collapse(self, nation, now):
        """The government falls back to a confederation (a ruler gone)."""
        if self.government(nation)['type'] == DEFAULT_GOVERNMENT:
            return
        self.db.execute('INSERT OR REPLACE INTO nation_government VALUES (?, ?, ?, ?, NULL, NULL, NULL, NULL, NULL)',
                        (nation, DEFAULT_GOVERNMENT, now, now))
        for (mid,) in self.db.execute('SELECT id FROM nation_motion WHERE nation = ?', (nation,)).fetchall():
            self.close_motion(mid)
        self.db.execute('DELETE FROM nation_term WHERE nation = ?', (nation,))
        self.db.execute('DELETE FROM nation_successor WHERE nation = ?', (nation,))
        self.db.execute('DELETE FROM nation_seen WHERE nation = ?', (nation,))
        self.clear_offices(nation)

    def _ruler_admits(self, actor, ruler, nation, applicant, yes, now):
        title = GOVERNMENTS[self.government(nation)['type']]['ruler']
        if actor != ruler:
            return 'Only the %s admits new members.' % title
        if not self.db.execute('SELECT 1 FROM nation_application WHERE faction = ? AND nation = ?',
                               (applicant, nation)).fetchone():
            return 'There is no such application.'
        self._drop_application(applicant)
        if not yes:
            return 'The %s refuses the application.' % title
        if len(self.members(nation)) >= self.capacity(nation):
            return 'The nation is full, so the application lapses.'
        self.db.execute('INSERT INTO nation_member VALUES (?, ?, ?)', (applicant, nation, now))
        return "By the %s's word the faction joins the nation." % title

    def _ruler_currency(self, actor, ruler, nation, issuer):
        title = GOVERNMENTS[self.government(nation)['type']]['ruler']
        if actor != ruler:
            return 'Only the %s chooses the common money.' % title
        if issuer and self.nation_of(issuer) != nation:
            return "Only a member faction's coin can be the nation's money."
        if issuer:
            self.db.execute('INSERT OR REPLACE INTO nation_currency VALUES (?, ?)', (nation, issuer))
            return "By the %s's word the nation has a new common money." % title
        self.db.execute('DELETE FROM nation_currency WHERE nation = ?', (nation,))
        return "By the %s's word the nation has no common money." % title

    def _elective_admit(self, nation, r, now):
        """A leader's admission vote under an elective government: a ballot on
        the application's motion."""
        applicant = r['applicant']
        if not self.db.execute('SELECT 1 FROM nation_application WHERE faction = ? AND nation = ?',
                               (applicant, nation)).fetchone():
            return 'There is no such application.'
        mid = self.open_motion(nation, 'admit', applicant, 'world', now)
        if mid is None:
            return 'The nation has too many open motions; wait for some to close.'
        return self.ballot(nation, dict(r, motion=mid, choice='yes' if r['yes'] else 'no'), now)
