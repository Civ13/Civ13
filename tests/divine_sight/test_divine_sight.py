"""Offline source contract for Divine Sight, the gods' observer; does not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


TEXT = read('code/modules/divine/divine_sight.dm')
PANEL = read('code/modules/divine/divine_sight_panel.dm')


def body(text, header):
    return text.split(header, 1)[1].split('\n/', 1)[0]


class DivineSightSource(unittest.TestCase):
    def test_included_and_staff_only(self):
        dme = read('civ13.dme')
        for name in ('divine_sight.dm', 'divine_sight_panel.dm'):
            self.assertIn('#include "code\\modules\\divine\\' + name + '"', dme)
        self.assertIn('/client/proc/divine_sight,', read('code/modules/admin/admin_verbs.dm'))
        verb = body(TEXT, '/client/proc/divine_sight()')
        self.assertIn('check_rights(R_ADMIN)', verb)
        self.assertIn('divine_identity_of(ckey)', verb)
        self.assertIn('admin_ghost()', verb)
        allowed = body(TEXT, '/mob/observer/ghost/proc/divine_allowed()')
        self.assertIn('check_rights(R_ADMIN, FALSE, src)', allowed)

    def test_every_action_rechecks_and_logs(self):
        for proc in ('divine_sight_panel()', 'divine_manifest()', 'divine_whisper()', 'divine_patron_menu()'):
            self.assertIn('if (!divine_allowed())', body(TEXT, '/mob/observer/ghost/proc/' + proc))
        for proc in ('divine_manifest()', 'divine_whisper()', 'divine_sight_start('):
            self.assertIn('log_admin(', body(TEXT, '/mob/observer/ghost/proc/' + proc))
        topic = body(TEXT, '/mob/observer/ghost/proc/divine_topic(')
        self.assertIn('usr != src || !divine_allowed()', topic)
        self.assertIn('log_admin(', topic)
        self.assertIn('divine_topic(href_list)', body(read('code/game/mob/observer/ghost/ghost.dm'), '/mob/observer/ghost/Topic('))

    def test_panel_gathers_what_a_god_answers(self):
        data = body(TEXT, '/mob/observer/ghost/proc/divine_panel_data()')
        for key in ('divine_pending_requests', 'R.covenant.deity_id != claim', 'divine_answer=approve',
                    'spirit_revival_prayers', 'spirit_grant=1', 'spirit_bindings', 'divine_release',
                    'divine_book_key(H.divine_patron) != claim'):
            self.assertIn(key, data)
        self.assertIn('/proc/divine_sight_panel_html(mob/observer/ghost/G, list/data)', PANEL)
        self.assertIn('html_encode(', PANEL)

    def test_manifest_is_timed_and_restores_hiding(self):
        self.assertIn('#define DIVINE_MANIFEST_TIME 300', TEXT)
        end = body(TEXT, '/mob/observer/ghost/proc/divine_end_manifest()')
        self.assertIn('invisibility = initial(invisibility)', end)
        self.assertIn('set_admin_hidden(TRUE)', end)
        self.assertIn('divine_sight_stop()', body(read('code/game/mob/observer/ghost/ghost.dm'), '/mob/observer/ghost/verb/reenter_corpse()'))

    def test_hidden_mechanic_header(self):
        self.assertIn('Hidden mechanic', TEXT.split('\n', 3)[1] + TEXT.split('\n', 3)[2])


if __name__ == '__main__':
    unittest.main()
