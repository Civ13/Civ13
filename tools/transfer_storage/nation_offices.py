"""Offices of state (docs/nation-government.md, "Offices of state").

A nation whose government has a head fills three offices, each with one
delegated power:

- Treasurer: chooses the common money in the ruler's place under personal
  rule, or brings a common money before the senate, council or citizens.
- Chancellor: admits or refuses applications in the ruler's place under
  personal rule. Nation laws and courts will go through this office.
- Marshal: guards the nation's assemblies: a marshal standing at one pauses
  any claim or revolt held there (nation_government.dm).

The head appoints ('appoint' op). Under personal rule the appointment stands
at once; under an elective government it is an 'office' motion that the body
confirms by a majority. The head dismisses and a holder resigns ('dismiss'
op) at once. A person holds one office at a time, never the head's own seat.
Offices lapse when the government changes, and a holder whose faction leaves
the nation loses the office. Worlds vouch that the person appointed is a
citizen with a verified account.
"""
import json

OFFICES = {'treasurer': 'Treasurer', 'chancellor': 'Chancellor', 'marshal': 'Marshal'}


class NationOffices:
    """Mixed into Nations; uses its db, government(), government_info(),
    nation_of(), ruler(), body() and the motions mixin."""

    def _office_tables(self):
        self.db.execute('''CREATE TABLE IF NOT EXISTS nation_office(
            nation TEXT NOT NULL, office TEXT NOT NULL, account TEXT NOT NULL, name TEXT NOT NULL,
            faction TEXT NOT NULL, since INTEGER NOT NULL, PRIMARY KEY(nation, office))''')

    def offices(self, nation):
        """Office -> holder, for holders whose faction is still a member."""
        return {o: {'account': a, 'name': n, 'faction': f, 'since': s} for o, a, n, f, s in self.db.execute(
            'SELECT office, account, name, faction, since FROM nation_office WHERE nation = ? ORDER BY office', (nation,))
            if self.nation_of(f) == nation}

    def office_of(self, nation, account):
        for office, holder in self.offices(nation).items():
            if holder['account'] == account:
                return office
        return None

    def clear_offices(self, nation):
        self.db.execute('DELETE FROM nation_office WHERE nation = ?', (nation,))

    # -- requests --------------------------------------------------------------

    def appoint(self, nation, r, now):
        g = self.government(nation)
        info = self.government_info(nation)
        title = OFFICES[r['office']]
        if not info['ruler']:
            return 'A confederation has no head to appoint officers.'
        if r['actor'] != g['head_account']:
            return 'Only the %s appoints the %s.' % (info['ruler'], title)
        if r['person'] == g['head_account']:
            return 'You cannot hold an office yourself.'
        if self.nation_of(r['pfaction']) != nation:
            return 'Only a citizen of a member faction can hold an office.'
        held = self.office_of(nation, r['person'])
        if held and held != r['office']:
            return '%s already holds the office of %s.' % (r['pname'], OFFICES[held])
        subject = [r['office'], r['person'], r['pname'], r['pfaction']]
        if not info['body']:
            self.fill_office(nation, subject, now)
            return '%s is appointed %s.' % (r['pname'], title)
        mid = self.open_motion(nation, 'office', subject, r['actor'], now)
        if mid is None:
            return 'The nation has too many open motions; wait for some to close.'
        return 'The %s must confirm %s as %s.' % (
            {'senate': 'senate', 'council': 'council', 'referendum': 'citizens'}[info['body']], r['pname'], title)

    def fill_office(self, nation, subject, now):
        office, account, name, faction = subject
        if self.nation_of(faction) != nation or account == self.government(nation)['head_account']:
            return
        self.db.execute('DELETE FROM nation_office WHERE nation = ? AND account = ?', (nation, account))
        self.db.execute('INSERT OR REPLACE INTO nation_office VALUES (?, ?, ?, ?, ?, ?)',
                        (nation, office, account, name, faction, now))

    def dismiss(self, nation, r, now):
        holder = self.offices(nation).get(r['office'])
        title = OFFICES[r['office']]
        if not holder:
            return 'The office of %s is empty.' % title
        head = self.government(nation)['head_account']
        if r['actor'] not in (head, holder['account']):
            return 'Only the head of the nation dismisses the %s.' % title
        self.db.execute('DELETE FROM nation_office WHERE nation = ? AND office = ?', (nation, r['office']))
        if r['actor'] == holder['account']:
            return 'You resign as %s.' % title
        return '%s is dismissed as %s.' % (holder['name'], title)

    def office_acts(self, nation, r, now):
        """A request an officer makes by their office's power, or None when
        the request is not one."""
        office = self.office_of(nation, r['actor'])
        ruler = self.ruler(nation)
        if r['op'] == 'currency' and office == 'treasurer':
            if r['issuer'] and self.nation_of(r['issuer']) != nation:
                return "Only a member faction's coin can be the nation's money."
            if ruler:
                return self._ruler_currency(ruler, ruler, nation, r['issuer'])
            if self.body(nation) and r.get('role', 'leader') != 'leader':  # a leader votes as usual
                mid = self.open_motion(nation, 'currency', r['issuer'], r['actor'], now)
                if mid is None:
                    return 'The nation has too many open motions; wait for some to close.'
                self.settle(mid, now)
                return 'As Treasurer you bring the common money to a vote.'
        if r['op'] == 'vote' and office == 'chancellor' and ruler:
            return self._ruler_admits(ruler, ruler, nation, r['applicant'], r['yes'], now)
        return None

    def offices_due(self):
        for nation, office, account, faction in self.db.execute(
                'SELECT nation, office, account, faction FROM nation_office').fetchall():
            # Gone from the nation, no head to serve, or now the head themself.
            if self.nation_of(faction) != nation or not self.government_info(nation)['ruler'] \
                    or account == self.government(nation)['head_account']:
                self.db.execute('DELETE FROM nation_office WHERE nation = ? AND office = ?', (nation, office))

    def offices_rename(self, old, new):
        self.db.execute('UPDATE nation_office SET faction = ? WHERE faction = ?', (new, old))
        for mid, subject in self.db.execute("SELECT id, subject FROM nation_motion WHERE kind = 'office'").fetchall():
            c = json.loads(subject)
            if c[3] == old:
                c[3] = new
                self.db.execute('UPDATE nation_motion SET subject = ? WHERE id = ?', (json.dumps(c), mid))
