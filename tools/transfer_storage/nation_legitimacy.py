"""Legitimacy of a nation's government (docs/nation-government.md, "Legitimacy").

Each government holds a legitimacy score from 0 to 100. A new government
starts at LEGITIMACY_START. Once a day:

- a head who played that day adds 2, a head away longer takes 2 off, and an
  empty seat under personal rule takes 2 off;
- a confederation drifts 1 a day towards LEGITIMACY_START.

Events move it too: a motion that carries adds 1 and one that fails takes 1
off; a faction admitted adds 2 and a faction that secedes takes 3 off; a
filled revolt petition that fails adds 5, and one that never fills adds 1.

The share of eligible citizens a revolt petition needs is the government's
share times (0.5 + score / 100): half of it at 0, as set at 50, and half
again at 100, never above REVOLT_SHARE_MAX.
"""
DAY = 24 * 3600
LEGITIMACY_START = 50
REVOLT_SHARE_MAX = 0.9
CATCH_UP_DAYS = 30


class NationLegitimacy:
    """Mixed into Nations; uses its db, government(), government_info() and
    head_seen()."""

    def _legitimacy_tables(self):
        self.db.execute('''CREATE TABLE IF NOT EXISTS nation_legitimacy(
            nation TEXT PRIMARY KEY, score REAL NOT NULL, at INTEGER NOT NULL)''')

    def legitimacy(self, nation):
        row = self.db.execute('SELECT score FROM nation_legitimacy WHERE nation = ?', (nation,)).fetchone()
        return int(round(row[0])) if row else LEGITIMACY_START

    def legitimacy_shift(self, nation, delta):
        row = self.db.execute('SELECT score FROM nation_legitimacy WHERE nation = ?', (nation,)).fetchone()
        if not row:
            return
        self.db.execute('UPDATE nation_legitimacy SET score = ? WHERE nation = ?',
                        (max(0, min(100, row[0] + delta)), nation))

    def legitimacy_reset(self, nation, now):
        self.db.execute('INSERT OR REPLACE INTO nation_legitimacy VALUES (?, ?, ?)', (nation, LEGITIMACY_START, now))

    def revolt_share(self, nation):
        base = self.government_info(nation)['revolt']
        return min(REVOLT_SHARE_MAX, base * (0.5 + self.legitimacy(nation) / 100))

    def legitimacy_due(self, now):
        self.db.execute('DELETE FROM nation_legitimacy WHERE nation NOT IN (SELECT id FROM nation)')
        for (nation,) in self.db.execute('SELECT id FROM nation').fetchall():
            row = self.db.execute('SELECT score, at FROM nation_legitimacy WHERE nation = ?', (nation,)).fetchone()
            if not row:
                self.legitimacy_reset(nation, now)
                continue
            score, at = row
            days = min(CATCH_UP_DAYS, (now - at) // DAY)
            if days <= 0:
                continue
            g = self.government(nation)
            info = self.government_info(nation)
            for _ in range(days):
                if not info['ruler']:
                    score += max(-1, min(1, LEGITIMACY_START - score))
                elif g['head_account']:
                    seen = self.head_seen(nation) or g['since']
                    score += 2 if now - seen <= DAY else -2
                elif info['personal']:
                    score -= 2
                score = max(0, min(100, score))
            self.db.execute('UPDATE nation_legitimacy SET score = ?, at = ? WHERE nation = ?',
                            (score, at + days * DAY, nation))
