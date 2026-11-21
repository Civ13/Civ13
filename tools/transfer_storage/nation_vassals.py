"""Vassals (docs/nation-government.md, "Vassals").

One nation may be another's vassal. Each is decided under the nation's own
government through the 'treaty' op, like any treaty:

- By agreement: one nation agrees to be 'overlord' of the other and the other
  agrees to be its 'vassal' (either may offer first; an offer stands for 7
  days, as for treaties). A nation at war may surrender this way, which ends
  the war.
- Imposed ('impose'): a nation at war with another that has won
  VASSAL_IMPOSE_WINS sieges against it in the last VASSAL_WIN_DAYS days may
  make it a vassal alone. The worlds report each won siege between nations
  ('siege_won' op).
- Release: the overlord renounces its vassal alone.
- Independence ('independence'): after VASSAL_LOCK_DAYS a vassal breaks free
  alone; the two nations are then at war.

No chains: a vassal takes no vassals and a nation with vassals cannot become
one. An overlord keeps at most VASSALS_PER_NATION (FEUDAL_VASSALS under a
feudal crown, whose vassals wait FEUDAL_LOCK_DAYS for independence). An overlord and its vassal
cannot declare war on each other, and never contest each other's provinces.
Tribute is taken in the worlds (code/modules/provinces/province_treaties.dm).
"""

DAY = 24 * 3600
VASSAL_KINDS = ('overlord', 'vassal', 'impose', 'independence')
VASSAL_LOCK_DAYS = 14
VASSAL_IMPOSE_WINS = 2
VASSAL_WIN_DAYS = 14
VASSALS_PER_NATION = 4
# A feudal crown keeps more vassals and holds them longer.
FEUDAL_VASSALS = 8
FEUDAL_LOCK_DAYS = 28


class NationVassals:
    """Mixed into Nations; uses its db and the treaties mixin."""

    def _vassal_tables(self):
        self.db.execute('''CREATE TABLE IF NOT EXISTS nation_vassal(
            vassal TEXT PRIMARY KEY, overlord TEXT NOT NULL, since INTEGER NOT NULL, imposed INTEGER NOT NULL)''')
        self.db.execute('''CREATE TABLE IF NOT EXISTS nation_siege_win(
            winner TEXT NOT NULL, loser TEXT NOT NULL, at INTEGER NOT NULL)''')

    def feudal(self, nation):
        return self.government(nation)['type'] == 'feudal'

    def overlord_of(self, nation):
        row = self.db.execute('SELECT overlord FROM nation_vassal WHERE vassal = ?', (nation,)).fetchone()
        return row[0] if row else None

    def vassals_of(self, nation):
        return [v for (v,) in self.db.execute('SELECT vassal FROM nation_vassal WHERE overlord = ? ORDER BY since', (nation,))]

    def bound(self, a, b):
        """TRUE when one of the two is the other's vassal."""
        return self.overlord_of(a) == b or self.overlord_of(b) == a

    def vassal_rows(self, nation):
        rows = [{'other': o, 'kind': 'vassal', 'since': s, 'imposed': bool(i)} for o, s, i in self.db.execute(
            'SELECT overlord, since, imposed FROM nation_vassal WHERE vassal = ?', (nation,))]
        rows += [{'other': v, 'kind': 'overlord', 'since': s, 'imposed': bool(i)} for v, s, i in self.db.execute(
            'SELECT vassal, since, imposed FROM nation_vassal WHERE overlord = ? ORDER BY since', (nation,))]
        return rows

    def siege_wins(self, winner, loser, now):
        return self.db.execute('SELECT COUNT(*) FROM nation_siege_win WHERE winner = ? AND loser = ? AND at >= ?',
                               (winner, loser, now - VASSAL_WIN_DAYS * DAY)).fetchone()[0]

    def siege_won(self, nation, loser, now):
        """A world reports a siege won by one of nation's factions against loser."""
        if loser != nation and self.treaty(nation, loser, 'war'):
            self.db.execute('INSERT INTO nation_siege_win VALUES (?, ?, ?)', (nation, loser, now))
        return None

    def vassal_check(self, nation, other, kind, act, now):
        if act == 'renounce':
            if kind == 'overlord' and self.overlord_of(other) == nation:
                return None
            if kind == 'vassal':
                return 'A vassal breaks free by declaring independence.'
            return 'There is no such vassal to release.'
        if kind == 'independence':
            row = self.db.execute('SELECT since FROM nation_vassal WHERE vassal = ? AND overlord = ?',
                                  (nation, other)).fetchone()
            if not row:
                return 'Your nation is not a vassal of that nation.'
            lock = FEUDAL_LOCK_DAYS if self.feudal(other) else VASSAL_LOCK_DAYS
            if now < row[0] + lock * DAY:
                return 'A vassal can declare independence only %d days after it became one.' % lock
            return None
        lord, vassal = (other, nation) if kind == 'vassal' else (nation, other)
        if self.overlord_of(vassal) == lord:
            return 'That vassalage is already in force.'
        if self.overlord_of(vassal):
            return 'The would-be vassal already serves an overlord.'
        if self.overlord_of(lord):
            return 'A vassal cannot take vassals of its own.'
        if self.vassals_of(vassal):
            return 'A nation with vassals cannot become a vassal; it must release them first.'
        cap = FEUDAL_VASSALS if self.feudal(lord) else VASSALS_PER_NATION
        if len(self.vassals_of(lord)) >= cap:
            return 'This overlord keeps at most %d vassals.' % cap
        if kind == 'impose':
            if not self.treaty(lord, vassal, 'war'):
                return 'Vassalage can only be imposed on a nation at war with yours.'
            if self.siege_wins(lord, vassal, now) < VASSAL_IMPOSE_WINS:
                return 'Your nation must win %d sieges against it within %d days to impose vassalage.' % (
                    VASSAL_IMPOSE_WINS, VASSAL_WIN_DAYS)
        return None

    def vassal_apply(self, nation, subject, now):
        act, other, kind = subject
        if act == 'renounce':
            self.db.execute('DELETE FROM nation_vassal WHERE vassal = ?', (other,))
            return 'The nation releases its vassal.'
        if kind == 'independence':
            self.db.execute('DELETE FROM nation_vassal WHERE vassal = ?', (nation,))
            self.treaty_apply(nation, ['agree', other, 'war'], now)
            self.legitimacy_shift(nation, 5)
            return 'The nation declares its independence, and the two nations are at war.'
        if kind == 'impose':
            self._make_vassal(nation, other, now, True)
            self.legitimacy_shift(other, -5)
            return 'The nation imposes vassalage, and the war is over.'
        lord, vassal = (other, nation) if kind == 'vassal' else (nation, other)
        counter = 'overlord' if kind == 'vassal' else 'vassal'
        if self.db.execute('SELECT 1 FROM nation_treaty_offer WHERE nation = ? AND other = ? AND kind = ?',
                           (other, nation, counter)).fetchone():
            self._make_vassal(lord, vassal, now, False)
            return 'Both nations agree: the vassalage is in force.'
        self.db.execute('INSERT OR REPLACE INTO nation_treaty_offer VALUES (?, ?, ?, ?)', (nation, other, kind, now))
        return 'The nation offers vassalage; it stands for 7 days.'

    def _make_vassal(self, lord, vassal, now, imposed):
        a, b = (lord, vassal) if lord < vassal else (vassal, lord)
        self.db.execute("DELETE FROM nation_treaty WHERE a = ? AND b = ? AND kind = 'war'", (a, b))
        self.db.execute('''DELETE FROM nation_treaty_offer WHERE ((nation = ? AND other = ?) OR (nation = ? AND other = ?))
            AND kind IN ('overlord', 'vassal', 'peace')''', (a, b, b, a))
        self.db.execute('DELETE FROM nation_siege_win WHERE (winner = ? AND loser = ?) OR (winner = ? AND loser = ?)',
                        (a, b, b, a))
        self.db.execute('INSERT OR REPLACE INTO nation_vassal VALUES (?, ?, ?, ?)', (vassal, lord, now, int(imposed)))

    def vassals_due(self, now):
        self.db.execute('''DELETE FROM nation_vassal WHERE vassal NOT IN (SELECT id FROM nation)
            OR overlord NOT IN (SELECT id FROM nation)''')
        self.db.execute('DELETE FROM nation_siege_win WHERE at < ? OR winner NOT IN (SELECT id FROM nation) '
                        'OR loser NOT IN (SELECT id FROM nation)', (now - VASSAL_WIN_DAYS * DAY,))
