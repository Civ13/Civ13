"""Revolts against a nation's government (docs/nation-government.md, "Revolt").

Citizens who reject their government overthrow it in play, not by a menu:

1. An eligible citizen opens a petition naming the government they want and,
   except for a confederation, its head ('revolt' op).
2. Eligible citizens sign it ('sign' op) within REVOLT_SIGNING. It needs the
   government's share of the eligible citizens (GOVERNMENTS 'revolt').
3. Once it has them, every citizen is warned, and from REVOLT_NOTICE later the
   signers have REVOLT_HOLD to hold a member faction's nation assembly for 30
   minutes, in that land's defence window where it has provinces
   (nation_government.dm). The count pauses while a citizen who did not sign
   stands there.
4. Success ('overthrow' op from the world) installs the petition's government
   at once. A filled petition that fails or succeeds closes, and the nation
   cannot be petitioned again for REVOLT_COOLDOWN. A petition that never fills
   bars only the citizen who opened it for that long, so a loyalist cannot
   shield the government with a sham petition.

The nation's head can neither open nor sign a petition against themself.

Signing is never a crime in itself; a failed revolt removes no one from play.
Worlds vouch that a petitioner or signer is an eligible citizen (verified,
member for 3 days, played this week).
"""
import json

HOUR = 3600
DAY = 24 * HOUR
REVOLT_SIGNING = 2 * DAY
REVOLT_NOTICE = DAY
REVOLT_HOLD = 3 * DAY
REVOLT_COOLDOWN = 7 * DAY


class NationRevolt:
    """Mixed into Nations; uses its db, government(), government_info(),
    members(), eligible(), era_ready(), nation_of() and _establish()."""

    def _revolt_tables(self):
        self.db.execute('''CREATE TABLE IF NOT EXISTS nation_revolt(
            nation TEXT PRIMARY KEY, proposal TEXT NOT NULL, by TEXT NOT NULL, opened INTEGER NOT NULL,
            ripe INTEGER)''')
        self.db.execute('''CREATE TABLE IF NOT EXISTS nation_signature(
            nation TEXT NOT NULL, account TEXT NOT NULL, name TEXT NOT NULL, faction TEXT NOT NULL,
            PRIMARY KEY(nation, account))''')
        # account '' bars the whole nation; otherwise one petitioner.
        self.db.execute('''CREATE TABLE IF NOT EXISTS nation_revolt_cooldown(
            nation TEXT NOT NULL, account TEXT NOT NULL, until INTEGER NOT NULL, PRIMARY KEY(nation, account))''')

    def revolt_row(self, nation):
        row = self.db.execute('SELECT proposal, by, opened, ripe FROM nation_revolt WHERE nation = ?', (nation,)).fetchone()
        return dict(zip(('proposal', 'by', 'opened', 'ripe'), row)) if row else None

    def signers(self, nation):
        """Signatures of citizens whose faction is still a member."""
        return [{'account': a, 'name': n, 'faction': f} for a, n, f in self.db.execute(
            'SELECT account, name, faction FROM nation_signature WHERE nation = ? ORDER BY rowid', (nation,))
            if self.nation_of(f) == nation]

    def signatures_needed(self, nation):
        share = self.government_info(nation)['revolt']
        return max(2, -(-int(share * self.eligible(nation) * 1000) // 1000))

    def revolt_cooldown(self, nation, account=''):
        row = self.db.execute('SELECT until FROM nation_revolt_cooldown WHERE nation = ? AND account = ?',
                              (nation, account)).fetchone()
        return row[0] if row else None

    def revolt_snapshot(self, nation):
        row = self.revolt_row(nation)
        cooldown = self.revolt_cooldown(nation)
        if not row:
            return {'cooldown': cooldown}
        kind, person, pname, pfaction, religion = json.loads(row['proposal'])
        return {'type': kind, 'person': person, 'pname': pname, 'pfaction': pfaction, 'religion': religion,
                'opened': row['opened'], 'ripe': row['ripe'],
                'hold_from': row['ripe'] + REVOLT_NOTICE if row['ripe'] else None,
                'ends': row['ripe'] + REVOLT_NOTICE + REVOLT_HOLD if row['ripe'] else row['opened'] + REVOLT_SIGNING,
                'signers': self.signers(nation), 'needed': self.signatures_needed(nation),
                'cooldown': cooldown}

    # -- requests --------------------------------------------------------------

    def open_revolt(self, nation, r, choice, now):
        if self.revolt_row(nation):
            return 'A revolt petition is already open; sign it instead.'
        if r['actor'] == self.government(nation)['head_account']:
            return 'You cannot petition against your own rule.'
        for account, what in (('', 'A revolt failed or succeeded recently; the nation cannot be petitioned again'),
                              (r['actor'], 'Your last petition found too few signers; you cannot open another')):
            until = self.revolt_cooldown(nation, account)
            if until and until > now:
                return '%s for %d days.' % (what, max(1, -(-(until - now) // DAY)))
        if r.get('pfaction') and self.nation_of(r['pfaction']) != nation:
            return 'Only a citizen of a member faction can head the nation.'
        if not self.era_ready(nation, r['type']):
            return "That government needs most member factions' lands to have reached the age it belongs to."
        self.db.execute('INSERT INTO nation_revolt VALUES (?, ?, ?, ?, NULL)', (nation, choice, r['actor'], now))
        self.db.execute('DELETE FROM nation_signature WHERE nation = ?', (nation,))
        return self.sign(nation, r, now, opened=True)

    def sign(self, nation, r, now, opened=False):
        row = self.revolt_row(nation)
        if not row:
            return 'No revolt petition is open.'
        if row['ripe']:
            return 'The petition already has its signatures; the rebels must now hold the assembly.'
        if r['actor'] == self.government(nation)['head_account']:
            return 'You cannot sign a petition against your own rule.'
        self.db.execute('INSERT OR REPLACE INTO nation_signature VALUES (?, ?, ?, ?)',
                        (nation, r['actor'], r['sname'], r['faction']))
        if len(self.signers(nation)) >= self.signatures_needed(nation):
            self.db.execute('UPDATE nation_revolt SET ripe = ? WHERE nation = ?', (now, nation))
            return 'The petition has its signatures. In a day the rebels may hold an assembly to overthrow the government.'
        return 'You open a revolt petition and sign it.' if opened else 'You sign the revolt petition.'

    def overthrow(self, nation, r, now):
        row = self.revolt_row(nation)
        if not row or not row['ripe']:
            return 'No revolt is ready.'
        if now < row['ripe'] + REVOLT_NOTICE:
            return 'The rebels must wait a day after the petition fills.'
        if now > row['ripe'] + REVOLT_NOTICE + REVOLT_HOLD:
            return 'The time to hold the assembly has passed.'
        if r['actor'] not in [s['account'] for s in self.signers(nation)]:
            return 'Only a signer of the petition can lead the revolt.'
        proposal = json.loads(row['proposal'])
        self.end_revolt(nation, now)
        if proposal[3] and self.nation_of(proposal[3]) != nation:
            return "The revolt's candidate is no longer a citizen; the revolt fails."
        self.db.execute('''INSERT OR REPLACE INTO nation_government
            SELECT ?, type, since, changed, head_account, head_name, religion, ?, ? FROM nation_government WHERE nation = ?''',
                        (nation, row['proposal'], now, nation))
        if not self.db.execute('SELECT 1 FROM nation_government WHERE nation = ?', (nation,)).fetchone():
            self.db.execute('INSERT INTO nation_government VALUES (?, ?, 0, 0, NULL, NULL, NULL, ?, ?)',
                            (nation, 'confederation', row['proposal'], now))
        self._establish(nation, now)
        return 'The rebels hold the assembly: the government falls.'

    def end_revolt(self, nation, now):
        row = self.revolt_row(nation)
        self.drop_revolt(nation)
        if row:
            # Unfilled, it bars only the citizen who opened it.
            self.db.execute('INSERT OR REPLACE INTO nation_revolt_cooldown VALUES (?, ?, ?)',
                            (nation, '' if row['ripe'] else row['by'], now + REVOLT_COOLDOWN))

    def drop_revolt(self, nation):
        self.db.execute('DELETE FROM nation_revolt WHERE nation = ?', (nation,))
        self.db.execute('DELETE FROM nation_signature WHERE nation = ?', (nation,))

    def revolts_due(self, now):
        for nation, opened, ripe in self.db.execute('SELECT nation, opened, ripe FROM nation_revolt').fetchall():
            if not self.db.execute('SELECT 1 FROM nation WHERE id = ?', (nation,)).fetchone():
                self.drop_revolt(nation)
            elif (not ripe and now > opened + REVOLT_SIGNING) or (ripe and now > ripe + REVOLT_NOTICE + REVOLT_HOLD):
                self.end_revolt(nation, now)
        self.db.execute('DELETE FROM nation_revolt_cooldown WHERE until <= ?', (now,))

    def revolt_rename(self, old, new):
        self.db.execute('UPDATE OR REPLACE nation_signature SET faction = ? WHERE faction = ?', (new, old))
        for nation, proposal in self.db.execute('SELECT nation, proposal FROM nation_revolt').fetchall():
            c = json.loads(proposal)
            if c[3] == old:
                c[3] = new
                self.db.execute('UPDATE nation_revolt SET proposal = ? WHERE nation = ?', (json.dumps(c), nation))
