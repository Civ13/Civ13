"""Motions, ballots and elections of elective nation governments
(docs/nation-government.md, "Votes").

A republic, democracy or merchant league decides its admissions, common money
and changes of government by motion, and elects its head for a term:

- Republic: a senate in which each member faction's leader casts a vote
  weighted by the faction's active citizens (at least 1). The consul is
  elected by all citizens.
- Democracy: a referendum of all eligible citizens, which needs a third of
  them to take part. The archon is elected by all citizens.
- Merchant league: a council of member leaders, each vote weighted by the
  coin in the faction's strongbox (at least 1), no faction above
  LEAGUE_SHARE_MAX of the whole. The doge is elected by the council.

Worlds report each member faction's eligible citizens (Discord-verified,
member for 3 days, seen in the last 7) and strongbox worth with the 'census'
op, and they vouch that a ballot's actor is eligible (a citizen ballot) or the
faction's leader (a leader ballot). One account casts one ballot per motion.
A changed ballot replaces the old one.

A senate or council motion closes as soon as its outcome cannot change; a
referendum and an election run their full window. Changes of government need
two thirds (and, in a referendum, half of the citizens taking part).
"""
import json

HOUR = 3600
DAY = 24 * HOUR
SENATE_WINDOW = 12 * HOUR
REFERENDUM_WINDOW = DAY
ELECTION_WINDOW = DAY
LEAGUE_SHARE_MAX = 0.4
REFERENDUM_QUORUM = 1 / 3
CHANGE_TURNOUT = 1 / 2
MOTIONS_PER_NATION = 12
CANDIDATES_PER_ELECTION = 12
CITIZENS_MAX = 1000
WEALTH_MAX = 10 ** 7
# Body -> who casts ballots on motions, and who elects the head.
BODIES = {
    'senate': {'motions': 'leader', 'election': 'citizen'},
    'referendum': {'motions': 'citizen', 'election': 'citizen'},
    'council': {'motions': 'leader', 'election': 'leader'},
}


class NationMotions:
    """Mixed into Nations; uses its db, government(), members() and the
    helpers named below."""

    def _motion_tables(self):
        db = self.db
        db.execute('''CREATE TABLE IF NOT EXISTS nation_motion(
            id INTEGER PRIMARY KEY AUTOINCREMENT, nation TEXT NOT NULL, kind TEXT NOT NULL, subject TEXT NOT NULL,
            opened INTEGER NOT NULL, closes INTEGER NOT NULL, by TEXT NOT NULL)''')
        # voter: an account (citizen ballot) or a member faction id (leader ballot).
        db.execute('''CREATE TABLE IF NOT EXISTS nation_ballot(
            motion INTEGER NOT NULL, voter TEXT NOT NULL, choice TEXT NOT NULL, PRIMARY KEY(motion, voter))''')
        db.execute('''CREATE TABLE IF NOT EXISTS nation_candidate(
            motion INTEGER NOT NULL, account TEXT NOT NULL, name TEXT NOT NULL, faction TEXT NOT NULL,
            at INTEGER NOT NULL, PRIMARY KEY(motion, account))''')
        db.execute('''CREATE TABLE IF NOT EXISTS nation_census(
            faction TEXT PRIMARY KEY, citizens INTEGER NOT NULL, wealth INTEGER NOT NULL)''')
        db.execute('''CREATE TABLE IF NOT EXISTS nation_term(
            nation TEXT PRIMARY KEY, ends INTEGER NOT NULL)''')

    # -- reading ---------------------------------------------------------------

    def body(self, nation):
        return self.government_info(nation)['body']

    def census(self, faction):
        row = self.db.execute('SELECT citizens, wealth FROM nation_census WHERE faction = ?', (faction,)).fetchone()
        return row if row else (0, 0)

    def weights(self, nation):
        """Member faction -> its vote's weight in the senate or council."""
        body = self.body(nation)
        members = self.members(nation)
        if body == 'senate':
            return {f: max(1, self.census(f)[0]) for f in members}
        raw = {f: max(1, self.census(f)[1]) for f in members}
        cap = LEAGUE_SHARE_MAX * sum(raw.values())
        return {f: min(w, cap) for f, w in raw.items()}

    def eligible(self, nation):
        """Citizens who may take part in a referendum, as the worlds count them."""
        return sum(self.census(f)[0] for f in self.members(nation))

    def open_motions(self, nation):
        return self.db.execute('''SELECT id, kind, subject, opened, closes, by FROM nation_motion
            WHERE nation = ? ORDER BY id''', (nation,)).fetchall()

    def motion_voters(self, nation, kind):
        body = self.body(nation)
        return BODIES[body]['election' if kind == 'election' else 'motions'] if body else None

    def tally(self, motion):
        """(yes, no, possible) weights of a yes/no motion; possible is the
        whole body (all weights, or every eligible citizen)."""
        nation, kind = self.db.execute('SELECT nation, kind FROM nation_motion WHERE id = ?', (motion,)).fetchone()
        ballots = self.db.execute('SELECT voter, choice FROM nation_ballot WHERE motion = ?', (motion,)).fetchall()
        if self.motion_voters(nation, kind) == 'leader':
            weights = self.weights(nation)
            yes = sum(weights.get(v, 0) for v, c in ballots if c == 'yes')
            no = sum(weights.get(v, 0) for v, c in ballots if c == 'no')
            return yes, no, sum(weights.values())
        return (sum(1 for _, c in ballots if c == 'yes'), sum(1 for _, c in ballots if c == 'no'),
                max(self.eligible(nation), len(ballots)))

    def election_count(self, motion):
        """Candidate account -> votes (weighted for a council), in the order they stood."""
        nation = self.db.execute('SELECT nation FROM nation_motion WHERE id = ?', (motion,)).fetchone()[0]
        leader = self.motion_voters(nation, 'election') == 'leader'
        weights = self.weights(nation) if leader else {}
        count = {a: 0 for (a,) in self.db.execute('SELECT account FROM nation_candidate WHERE motion = ? ORDER BY at, account',
                                                   (motion,))}
        for voter, choice in self.db.execute('SELECT voter, choice FROM nation_ballot WHERE motion = ?', (motion,)):
            if choice in count:
                count[choice] += weights.get(voter, 0) if leader else 1
        return count

    def motions_snapshot(self, nation):
        result = []
        for mid, kind, subject, opened, closes, by in self.open_motions(nation):
            row = {'id': mid, 'kind': kind, 'subject': json.loads(subject), 'opened': opened, 'closes': closes,
                   'voters': self.motion_voters(nation, kind),
                   'ballots': dict(self.db.execute('SELECT voter, choice FROM nation_ballot WHERE motion = ?', (mid,)))}
            if kind == 'election':
                count = self.election_count(mid)
                row['candidates'] = [{'account': a, 'name': n, 'faction': f, 'votes': count.get(a, 0)} for a, n, f in
                                     self.db.execute('''SELECT account, name, faction FROM nation_candidate
                                         WHERE motion = ? ORDER BY at, account''', (mid,))]
            else:
                row['yes'], row['no'], row['possible'] = self.tally(mid)
            result.append(row)
        return result

    # -- opening and voting ---------------------------------------------------------

    def open_motion(self, nation, kind, subject, by, now):
        """The open motion of that kind and subject, opened if there is none.
        Returns its id, or None when the nation has too many open."""
        text = json.dumps(subject)
        row = self.db.execute('SELECT id FROM nation_motion WHERE nation = ? AND kind = ? AND subject = ?',
                              (nation, kind, text)).fetchone()
        if row:
            return row[0]
        if len(self.open_motions(nation)) >= MOTIONS_PER_NATION:
            return None
        window = ELECTION_WINDOW if kind == 'election' else (
            REFERENDUM_WINDOW if self.body(nation) == 'referendum' else SENATE_WINDOW)
        cursor = self.db.execute('INSERT INTO nation_motion(nation, kind, subject, opened, closes, by) VALUES (?, ?, ?, ?, ?, ?)',
                                 (nation, kind, text, now, now + window, by))
        return cursor.lastrowid

    def voter_key(self, nation, kind, r):
        """Who this request votes as on a motion of kind, or None when the
        request cannot vote there."""
        voters = self.motion_voters(nation, kind)
        role = r.get('role', 'leader')
        if voters == 'leader':
            return r['faction'] if role == 'leader' else None
        if voters == 'citizen':
            return r['actor'] if role in ('citizen', 'leader') else None
        return None

    def propose(self, nation, kind, subject, r, now):
        """Opens (or joins) a motion and records the proposer's yes when they
        may vote on it. Returns a sentence for them."""
        if self.motion_voters(nation, kind) == 'leader' and r.get('role', 'leader') != 'leader':
            return "Only a member faction's leader can bring that before the %s." % self.body(nation)
        mid = self.open_motion(nation, kind, subject, r['actor'], now)
        if mid is None:
            return 'The nation has too many open motions; wait for some to close.'
        voter = self.voter_key(nation, kind, r)
        if voter:
            self.db.execute('INSERT OR REPLACE INTO nation_ballot VALUES (?, ?, ?)', (mid, voter, 'yes'))
        self.settle(mid, now)
        if not self.db.execute('SELECT 1 FROM nation_motion WHERE id = ?', (mid,)).fetchone():
            return 'The motion is decided at once.'
        return 'The motion is open until the vote closes; your vote for it is counted.'

    def ballot(self, nation, r, now):
        row = self.db.execute('SELECT kind FROM nation_motion WHERE id = ? AND nation = ?', (r['motion'], nation)).fetchone()
        if not row:
            return 'That motion is closed.'
        kind = row[0]
        voter = self.voter_key(nation, kind, r)
        if not voter:
            return 'You have no vote on that motion.'
        choice = r['choice']
        if kind == 'election':
            if not self.db.execute('SELECT 1 FROM nation_candidate WHERE motion = ? AND account = ?',
                                   (r['motion'], choice)).fetchone():
                return 'That person is not standing.'
        elif choice not in ('yes', 'no'):
            return 'Vote yes or no.'
        self.db.execute('INSERT OR REPLACE INTO nation_ballot VALUES (?, ?, ?)', (r['motion'], voter, choice))
        self.settle(r['motion'], now)
        return 'Your vote is counted.'

    def stand(self, nation, r, now):
        row = self.db.execute("SELECT id FROM nation_motion WHERE nation = ? AND kind = 'election'", (nation,)).fetchone()
        if not row:
            return 'No election is open.'
        if self.db.execute('SELECT COUNT(*) FROM nation_candidate WHERE motion = ?', (row[0],)).fetchone()[0] \
                >= CANDIDATES_PER_ELECTION:
            return 'The election has as many candidates as it can take.'
        self.db.execute('INSERT OR REPLACE INTO nation_candidate VALUES (?, ?, ?, ?, ?)',
                        (row[0], r['actor'], r['pname'], r['faction'], now))
        return 'You stand for election.'

    # -- closing ------------------------------------------------------------------

    def settle(self, motion, now):
        """Closes a motion whose time is up, or whose outcome can no longer
        change (senate and council only)."""
        row = self.db.execute('SELECT nation, kind, subject, closes FROM nation_motion WHERE id = ?', (motion,)).fetchone()
        if not row:
            return
        nation, kind, subject, closes = row
        if not self.body(nation):
            self.close_motion(motion)
            return
        if kind == 'election':
            if now >= closes:
                self.close_election(nation, motion, now)
            return
        yes, no, possible = self.tally(motion)
        subject = json.loads(subject)
        if self.motion_voters(nation, kind) == 'leader':
            # The whole senate or council is known: decide once it is certain.
            if possible and self.passes(kind, yes, possible):
                return self.carry(nation, motion, kind, subject, now)
            if possible and not self.passes(kind, possible - no, possible):
                return self.fail(nation, motion, kind, subject)
            if now < closes:
                return
            # Time is up: a majority (or two thirds) of the votes cast.
            if self.passes(kind, yes, yes + no):
                return self.carry(nation, motion, kind, subject, now)
            return self.fail(nation, motion, kind, subject)
        if now < closes:
            return
        cast = yes + no
        turnout = CHANGE_TURNOUT if kind == 'government' else REFERENDUM_QUORUM
        if cast >= turnout * possible and self.passes(kind, yes, cast):
            return self.carry(nation, motion, kind, subject, now)
        return self.fail(nation, motion, kind, subject)

    def passes(self, kind, yes, base):
        """Two thirds for a change of government, more than half otherwise."""
        if base <= 0:
            return False
        return yes * 3 >= base * 2 if kind == 'government' else yes * 2 > base

    def close_motion(self, motion):
        self.db.execute('DELETE FROM nation_ballot WHERE motion = ?', (motion,))
        self.db.execute('DELETE FROM nation_candidate WHERE motion = ?', (motion,))
        self.db.execute('DELETE FROM nation_motion WHERE id = ?', (motion,))

    def carry(self, nation, motion, kind, subject, now):
        self.close_motion(motion)
        self.legitimacy_shift(nation, 1)
        if kind == 'admit':
            if self.db.execute('SELECT 1 FROM nation_application WHERE faction = ? AND nation = ?',
                               (subject, nation)).fetchone():
                self._drop_application(subject)
                if len(self.members(nation)) < self.capacity(nation):
                    self.db.execute('INSERT INTO nation_member VALUES (?, ?, ?)', (subject, nation, now))
                    self.legitimacy_shift(nation, 2)
        elif kind == 'currency':
            if subject and self.nation_of(subject) == nation:
                self.db.execute('INSERT OR REPLACE INTO nation_currency VALUES (?, ?)', (nation, subject))
            elif not subject:
                self.db.execute('DELETE FROM nation_currency WHERE nation = ?', (nation,))
        elif kind == 'government':
            g = self.government(nation)
            if not g['pending']:
                self._propose(nation, json.dumps(subject), now)
        elif kind == 'office':
            self.fill_office(nation, subject, now)
        elif kind == 'treaty':
            self.treaty_apply(nation, subject, now)

    def fail(self, nation, motion, kind, subject):
        self.close_motion(motion)
        self.legitimacy_shift(nation, -1)
        if kind == 'admit':
            self._drop_application(subject)

    def close_election(self, nation, motion, now):
        count = self.election_count(motion)
        rows = {a: (n, f) for a, n, f in self.db.execute(
            'SELECT account, name, faction FROM nation_candidate WHERE motion = ?', (motion,))}
        self.close_motion(motion)
        best = max(count.values()) if count else 0
        winners = [a for a, v in count.items() if v == best and v > 0 and self.nation_of(rows[a][1]) == nation]
        term = self.government_info(nation)['term'] * DAY
        if not winners:
            # Nobody stood or voted: the head keeps the seat, or it stays
            # empty, until the next election a day later.
            self.db.execute('INSERT OR REPLACE INTO nation_term VALUES (?, ?)', (nation, now + DAY))
            return
        account = winners[0]  # a tie goes to whoever stood first
        name, faction = rows[account]
        self.db.execute('UPDATE nation_government SET head_account = ?, head_name = ? WHERE nation = ?',
                        (account, name, nation))
        self.db.execute('UPDATE nation SET head = ? WHERE id = ?', (faction, nation))
        self.db.execute('INSERT OR REPLACE INTO nation_term VALUES (?, ?)', (nation, now + term))
        self.db.execute('INSERT OR REPLACE INTO nation_seen VALUES (?, ?, ?)', (nation, account, now))
        # A deputy serves the consul who named them.
        self.db.execute('DELETE FROM nation_successor WHERE nation = ?', (nation,))

    def motions_due(self, now):
        """Closes motions that are due, drops motions of nations that are no
        longer elective, and opens elections whose term has ended."""
        for (mid,) in self.db.execute('SELECT id FROM nation_motion WHERE closes <= ?', (now,)).fetchall():
            self.settle(mid, now)
        for mid, nation in self.db.execute('SELECT id, nation FROM nation_motion').fetchall():
            if not self.body(nation) or not self.db.execute('SELECT 1 FROM nation WHERE id = ?', (nation,)).fetchone():
                self.close_motion(mid)
        for (nation,) in self.db.execute('SELECT id FROM nation').fetchall():
            if not self.body(nation):
                self.db.execute('DELETE FROM nation_term WHERE nation = ?', (nation,))
                continue
            row = self.db.execute('SELECT ends FROM nation_term WHERE nation = ?', (nation,)).fetchone()
            if (not row or row[0] <= now) and not self.db.execute(
                    "SELECT 1 FROM nation_motion WHERE nation = ? AND kind = 'election'", (nation,)).fetchone():
                self.open_motion(nation, 'election', '', 'world', now)

    def term_ends(self, nation):
        row = self.db.execute('SELECT ends FROM nation_term WHERE nation = ?', (nation,)).fetchone()
        return row[0] if row else None
