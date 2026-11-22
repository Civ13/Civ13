"""Treaties between nations (docs/nation-government.md, "Treaties").

Two nations make a treaty when each agrees to it ('treaty' op, act 'agree',
naming the other nation and the kind). A nation's agreement stands as an
offer for TREATY_OFFER_DAYS; once both have agreed the treaty is in force.

- alliance, pact (non-aggression), trade: need both nations, and cannot be
  made while they are at war.
- war: one nation declares it alone, which ends any alliance or pact
  between them.
- peace: ends a war; needs both nations.

Either nation may renounce an alliance, pact or trade treaty alone (act
'renounce'). A nation agrees or renounces under its own government: the ruler
alone under personal rule, a motion of the senate, council or citizens under
an elective government, and more than half of the member factions' leaders
in a confederation. Treaties end when either nation dissolves.
"""
import json

from tools.transfer_storage.nation_vassals import VASSAL_KINDS

DAY = 24 * 3600
TREATY_KINDS = ('alliance', 'pact', 'trade', 'war', 'peace') + VASSAL_KINDS
TREATY_NAMES = {'alliance': 'an alliance', 'pact': 'a non-aggression pact', 'trade': 'a trade treaty',
                'war': 'war', 'peace': 'peace'}
TREATY_OFFER_DAYS = 7
TREATIES_PER_NATION = 24


def pair(a, b):
    return (a, b) if a < b else (b, a)


class NationTreaties:
    """Mixed into Nations; uses its db, ruler(), body(), members() and the
    motions mixin."""

    def _treaty_tables(self):
        self.db.execute('''CREATE TABLE IF NOT EXISTS nation_treaty(
            a TEXT NOT NULL, b TEXT NOT NULL, kind TEXT NOT NULL, since INTEGER NOT NULL, PRIMARY KEY(a, b, kind))''')
        self.db.execute('''CREATE TABLE IF NOT EXISTS nation_treaty_offer(
            nation TEXT NOT NULL, other TEXT NOT NULL, kind TEXT NOT NULL, at INTEGER NOT NULL,
            PRIMARY KEY(nation, other, kind))''')

    def treaty(self, a, b, kind):
        return self.db.execute('SELECT since FROM nation_treaty WHERE a = ? AND b = ? AND kind = ?',
                               pair(a, b) + (kind,)).fetchone() is not None

    def treaties_snapshot(self, nation):
        rows = [{'other': b if a == nation else a, 'kind': k, 'since': s} for a, b, k, s in self.db.execute(
            'SELECT a, b, kind, since FROM nation_treaty WHERE a = ? OR b = ? ORDER BY since, kind', (nation, nation))]
        offers = {'made': [{'other': o, 'kind': k, 'at': at} for o, k, at in self.db.execute(
            'SELECT other, kind, at FROM nation_treaty_offer WHERE nation = ? ORDER BY at', (nation,))],
                  'received': [{'other': n, 'kind': k, 'at': at} for n, k, at in self.db.execute(
            'SELECT nation, kind, at FROM nation_treaty_offer WHERE other = ? ORDER BY at', (nation,))]}
        return {'in_force': rows + self.vassal_rows(nation), 'offers': offers}

    # -- deciding under the nation's government -----------------------------------

    def treaty_request(self, nation, r, now):
        other, kind, act = r['other'], r['treaty'], r['act']
        if other == nation or not self.db.execute('SELECT 1 FROM nation WHERE id = ?', (other,)).fetchone():
            return 'There is no such nation.'
        check = self.treaty_check(nation, other, kind, act, now)
        if check:
            return check
        subject = [act, other, kind]
        ruler = self.ruler(nation)
        if ruler:
            if r['actor'] != ruler:
                return 'Only the %s decides on treaties.' % self.government_info(nation)['ruler']
            return self.treaty_apply(nation, subject, now)
        if self.body(nation):
            return self.propose(nation, 'treaty', subject, r, now)
        if r.get('role', 'leader') != 'leader':
            return "Only a member faction's leader can vote on treaties."
        key = 'treaty:' + json.dumps(subject)
        self.db.execute('INSERT OR REPLACE INTO nation_vote VALUES (?, ?, ?, ?)', (nation, key, r['faction'], 'yes'))
        votes = self.db.execute('SELECT COUNT(*) FROM nation_vote WHERE nation = ? AND kind = ?', (nation, key)).fetchone()[0]
        if votes * 2 > len(self.members(nation)):
            self.db.execute('DELETE FROM nation_vote WHERE nation = ? AND kind = ?', (nation, key))
            return self.treaty_apply(nation, subject, now)
        return 'Your vote is counted; more than half of the member factions must agree.'

    def treaty_check(self, nation, other, kind, act, now):
        if kind in VASSAL_KINDS:
            return self.vassal_check(nation, other, kind, act, now)  # nation_vassals.py
        at_war = self.treaty(nation, other, 'war')
        if kind == 'war' and act != 'renounce' and self.bound(nation, other):
            return 'A vassal and its overlord cannot go to war: declare independence, or release the vassal.'
        if act == 'renounce':
            if kind not in ('alliance', 'pact', 'trade') or not self.treaty(nation, other, kind):
                return 'There is no such treaty to renounce.'
            return None
        if kind == 'peace':
            return None if at_war else 'The two nations are not at war.'
        if self.treaty(nation, other, kind):
            return 'That treaty is already in force.'
        if kind != 'war' and at_war:
            return 'The two nations are at war; make peace first.'
        if self.db.execute('SELECT COUNT(*) FROM nation_treaty WHERE a = ? OR b = ?', (nation, nation)).fetchone()[0] \
                >= TREATIES_PER_NATION:
            return 'The nation has as many treaties as it can keep.'
        return None

    def treaty_apply(self, nation, subject, now):
        """The nation's government has decided."""
        act, other, kind = subject
        if not self.db.execute('SELECT 1 FROM nation WHERE id = ?', (other,)).fetchone():
            return 'There is no such nation.'
        check = self.treaty_check(nation, other, kind, act, now)
        if check:
            return check
        if kind in VASSAL_KINDS:
            return self.vassal_apply(nation, subject, now)
        a, b = pair(nation, other)
        if act == 'renounce':
            self.db.execute('DELETE FROM nation_treaty WHERE a = ? AND b = ? AND kind = ?', (a, b, kind))
            return 'The nation renounces %s.' % TREATY_NAMES[kind]
        if kind == 'war':
            self.db.execute("DELETE FROM nation_treaty WHERE a = ? AND b = ? AND kind IN ('alliance', 'pact')", (a, b))
            self.db.execute('DELETE FROM nation_treaty_offer WHERE (nation = ? AND other = ?) OR (nation = ? AND other = ?)',
                            (a, b, b, a))
            self.db.execute('INSERT INTO nation_treaty VALUES (?, ?, ?, ?)', (a, b, 'war', now))
            return 'The nation declares war.'
        if self.db.execute('SELECT 1 FROM nation_treaty_offer WHERE nation = ? AND other = ? AND kind = ?',
                           (other, nation, kind)).fetchone():
            self.db.execute('DELETE FROM nation_treaty_offer WHERE nation = ? AND other = ? AND kind = ?', (other, nation, kind))
            if kind == 'peace':
                self.db.execute("DELETE FROM nation_treaty WHERE a = ? AND b = ? AND kind = 'war'", (a, b))
                return 'Both nations agree: the war is over.'
            self.db.execute('INSERT OR REPLACE INTO nation_treaty VALUES (?, ?, ?, ?)', (a, b, kind, now))
            return 'Both nations agree: %s is in force.' % TREATY_NAMES[kind]
        self.db.execute('INSERT OR REPLACE INTO nation_treaty_offer VALUES (?, ?, ?, ?)', (nation, other, kind, now))
        return 'The nation offers %s; it stands for %d days.' % (TREATY_NAMES[kind], TREATY_OFFER_DAYS)

    # -- upkeep -------------------------------------------------------------------

    def treaties_due(self, now):
        self.db.execute('DELETE FROM nation_treaty_offer WHERE at < ?', (now - TREATY_OFFER_DAYS * DAY,))
        for table, x, y in (('nation_treaty', 'a', 'b'), ('nation_treaty_offer', 'nation', 'other')):
            self.db.execute('''DELETE FROM %s WHERE %s NOT IN (SELECT id FROM nation)
                OR %s NOT IN (SELECT id FROM nation)''' % (table, x, y))
        self.db.execute("""DELETE FROM nation_vote WHERE kind LIKE 'treaty:%' AND voter NOT IN (
            SELECT faction FROM nation_member WHERE nation = nation_vote.nation)""")
