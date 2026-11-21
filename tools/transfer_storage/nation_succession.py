"""Succession of nation heads (docs/nation-government.md, "Succession").

Worlds report when a nation's head is playing a member faction's character in
their land ('present' op). When the head has been away longer than their
government allows (GOVERNMENTS 'away', days), the seat passes on:

- Theocracy: the seat goes empty; it follows the faith's leadership whenever a
  world reports a citizen leading the state religion ('faith' op).
- Monarchy: the named heir takes the throne ('heir' op by the monarch). With
  none, the throne is empty until a citizen claims it by holding the nation's
  assembly ('claim' op, nation_government.dm).
- Dictatorship: the government collapses to a confederation.
- Republic: the consul's named deputy ('deputy' op) acts while an election
  opens at once.
- Democracy and merchant league: an election opens at once.

An empty seat under a personal rule leaves its decisions to the member
factions until it is filled. Heirs, deputies and claimants are citizens with
a verified account, which their world vouches for.
"""

DAY = 24 * 3600


class NationSuccession:
    """Mixed into Nations; uses its db, government(), government_info(),
    nation_of(), _collapse() and the motions mixin."""

    def _succession_tables(self):
        self.db.execute('''CREATE TABLE IF NOT EXISTS nation_seen(
            nation TEXT PRIMARY KEY, account TEXT NOT NULL, at INTEGER NOT NULL)''')
        # The monarch's heir or the consul's deputy.
        self.db.execute('''CREATE TABLE IF NOT EXISTS nation_successor(
            nation TEXT PRIMARY KEY, account TEXT NOT NULL, name TEXT NOT NULL, faction TEXT NOT NULL)''')

    def head_seen(self, nation):
        g = self.government(nation)
        row = self.db.execute('SELECT account, at FROM nation_seen WHERE nation = ?', (nation,)).fetchone()
        return row[1] if row and row[0] == g['head_account'] else None

    def successor(self, nation):
        row = self.db.execute('SELECT account, name, faction FROM nation_successor WHERE nation = ?', (nation,)).fetchone()
        return {'account': row[0], 'name': row[1], 'faction': row[2]} if row else None

    def seat(self, nation, account, name, faction, now):
        """Puts a person in the head's seat."""
        self.db.execute('UPDATE nation_government SET head_account = ?, head_name = ? WHERE nation = ?',
                        (account, name, nation))
        if faction:
            self.db.execute('UPDATE nation SET head = ? WHERE id = ?', (faction, nation))
        if account:
            self.db.execute('INSERT OR REPLACE INTO nation_seen VALUES (?, ?, ?)', (nation, account, now))
        else:
            self.db.execute('DELETE FROM nation_seen WHERE nation = ?', (nation,))
        self.db.execute('DELETE FROM nation_successor WHERE nation = ? AND account = ?', (nation, account or ''))

    # -- requests --------------------------------------------------------------

    def present(self, nation, r, now):
        g = self.government(nation)
        if g['head_account'] and r['actor'] == g['head_account']:
            self.db.execute('INSERT OR REPLACE INTO nation_seen VALUES (?, ?, ?)', (nation, r['actor'], now))
        return None

    def name_successor(self, nation, r, now):
        g = self.government(nation)
        title = self.government_info(nation)['ruler']
        wanted = {'monarchy': 'heir', 'republic': 'deputy'}.get(g['type'])
        if r['op'] != wanted:
            return 'Your nation has no %s to name.' % r['op']
        if r['actor'] != g['head_account']:
            return 'Only the %s names the %s.' % (title, wanted)
        if r['person'] == g['head_account']:
            return 'You cannot name yourself.'
        if self.nation_of(r['pfaction']) != nation:
            return 'Only a citizen of a member faction can be named.'
        self.db.execute('INSERT OR REPLACE INTO nation_successor VALUES (?, ?, ?, ?)',
                        (nation, r['person'], r['pname'], r['pfaction']))
        return '%s is named %s.' % (r['pname'], wanted)

    def faith(self, nation, r, now):
        """A citizen leading the state religion becomes High Priest."""
        g = self.government(nation)
        if g['type'] != 'theocracy' or r.get('religion') != g['religion'] or r['actor'] == g['head_account']:
            return None
        self.seat(nation, r['actor'], r['pname'], r['faction'], now)
        return None

    def claim(self, nation, r, now):
        g = self.government(nation)
        if g['type'] != 'monarchy' or g['head_account']:
            return 'The throne is not empty.'
        self.seat(nation, r['actor'], r['pname'], r['faction'], now)
        return 'You hold the assembly and take the empty throne.'

    # -- absence ---------------------------------------------------------------

    def succession_due(self, now):
        for (nation,) in self.db.execute('SELECT nation FROM nation_government').fetchall():
            g = self.government(nation)
            info = self.government_info(nation)
            if not g['head_account'] or not info['away']:
                continue
            seen = self.head_seen(nation) or g['since']
            if now - seen <= info['away'] * DAY:
                continue
            kind = g['type']
            if kind == 'dictatorship':
                self._collapse(nation, now)
            elif kind in ('monarchy', 'republic'):
                heir = self.successor(nation)
                if heir and self.nation_of(heir['faction']) == nation:
                    self.seat(nation, heir['account'], heir['name'], heir['faction'], now)
                else:
                    self.seat(nation, None, None, None, now)
                if kind == 'republic':
                    self.db.execute('INSERT OR REPLACE INTO nation_term VALUES (?, ?)', (nation, now))
            elif info['body']:
                # An election opens at once; the absent head keeps the seat until it closes.
                self.db.execute('INSERT OR REPLACE INTO nation_term VALUES (?, ?)', (nation, now))
                self.db.execute('INSERT OR REPLACE INTO nation_seen VALUES (?, ?, ?)', (nation, g['head_account'], now))
            else:
                self.seat(nation, None, None, None, now)
            self.db.execute('DELETE FROM nation_successor WHERE nation = ?', (nation,))
