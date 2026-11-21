"""Staff tools for nation governments (docs/nation-government.md, "Staff tools").

A world's staff act on any nation through the 'staff' op, naming one of its
member factions (any land) and an act:

- 'freeze' / 'thaw': a frozen nation cannot change government, hold votes,
  name successors, claim a throne or revolt, and its head's absence does not
  count. Thawing restarts the head's absence clock.
- 'void_motion': closes one open motion or election without a result.
- 'void_revolt': closes the open revolt petition without a cooldown.
- 'set': installs a government and head at once, past the era and notice.

Every act needs a reason and is kept in the nation's staff log, which the
registry snapshot carries (the last STAFF_LOG_SHOWN entries). Worlds check the
staff member's rights before they send the op.
"""
import json

STAFF_ACTS = ('freeze', 'thaw', 'void_motion', 'void_revolt', 'set')
STAFF_REASON_MAX = 200
STAFF_LOG_SHOWN = 10
STAFF_LOG_KEPT = 100
# Ops a frozen nation does not hear.
FROZEN_OPS = ('govern', 'ballot', 'stand', 'heir', 'deputy', 'faith', 'claim', 'revolt', 'sign', 'overthrow', 'appoint',
              'dismiss')


class NationStaff:
    """Mixed into Nations; uses its db, government(), nation_of(), close_motion(),
    drop_revolt() and _establish()."""

    def _staff_tables(self):
        self.db.execute('CREATE TABLE IF NOT EXISTS nation_frozen(nation TEXT PRIMARY KEY, since INTEGER NOT NULL)')
        self.db.execute('''CREATE TABLE IF NOT EXISTS nation_staff_log(
            nation TEXT NOT NULL, at INTEGER NOT NULL, actor TEXT NOT NULL, act TEXT NOT NULL, detail TEXT NOT NULL)''')

    def frozen(self, nation):
        row = self.db.execute('SELECT since FROM nation_frozen WHERE nation = ?', (nation,)).fetchone()
        return row[0] if row else None

    def staff_log(self, nation):
        return [{'at': at, 'actor': actor, 'act': act, 'detail': detail} for at, actor, act, detail in self.db.execute(
            'SELECT at, actor, act, detail FROM nation_staff_log WHERE nation = ? ORDER BY rowid DESC LIMIT ?',
            (nation, STAFF_LOG_SHOWN))]

    def staff(self, nation, r, choice, now):
        act = r['act']
        if act == 'freeze':
            if self.frozen(nation):
                return 'The nation is already frozen.'
            self.db.execute('INSERT INTO nation_frozen VALUES (?, ?)', (nation, now))
            done = 'The nation is frozen.'
        elif act == 'thaw':
            if not self.frozen(nation):
                return 'The nation is not frozen.'
            self.db.execute('DELETE FROM nation_frozen WHERE nation = ?', (nation,))
            head = self.government(nation)['head_account']
            if head:
                self.db.execute('INSERT OR REPLACE INTO nation_seen VALUES (?, ?, ?)', (nation, head, now))
            done = 'The nation is thawed.'
        elif act == 'void_motion':
            if not self.db.execute('SELECT 1 FROM nation_motion WHERE id = ? AND nation = ?',
                                   (r['motion'], nation)).fetchone():
                return 'That nation has no such motion.'
            self.close_motion(r['motion'])
            done = 'The motion is void.'
        elif act == 'void_revolt':
            if not self.revolt_row(nation):
                return 'The nation has no revolt petition.'
            self.drop_revolt(nation)
            done = 'The revolt petition is void.'
        else:
            if r.get('pfaction') and self.nation_of(r['pfaction']) != nation:
                return 'The head must be a citizen of a member faction.'
            self.db.execute('''INSERT OR REPLACE INTO nation_government
                SELECT ?, type, since, changed, head_account, head_name, religion, ?, ? FROM nation_government WHERE nation = ?''',
                            (nation, choice, now, nation))
            if not self.db.execute('SELECT 1 FROM nation_government WHERE nation = ?', (nation,)).fetchone():
                self.db.execute("INSERT INTO nation_government VALUES (?, 'confederation', 0, 0, NULL, NULL, NULL, ?, ?)",
                                (nation, choice, now))
            self._establish(nation, now)
            done = 'The government is set.'
        detail = r['reason'] + ('' if act != 'void_motion' else ' (motion %d)' % r['motion'])
        if act == 'set':
            detail += ' (%s)' % ', '.join(x for x in json.loads(choice) if x)
        self.db.execute('INSERT INTO nation_staff_log VALUES (?, ?, ?, ?, ?)', (nation, now, r['actor'], act, detail))
        self.db.execute('''DELETE FROM nation_staff_log WHERE nation = ? AND rowid NOT IN (
            SELECT rowid FROM nation_staff_log WHERE nation = ? ORDER BY rowid DESC LIMIT ?)''',
                        (nation, nation, STAFF_LOG_KEPT))
        return done

    def staff_dissolved(self, nation):
        self.db.execute('DELETE FROM nation_frozen WHERE nation = ?', (nation,))
