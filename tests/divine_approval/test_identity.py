"""Source guards for staff divine names and picking a god when praying (identity.dm)."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
IDENTITY = (ROOT / 'code/modules/divine/identity.dm').read_text()
PRAY = (ROOT / 'code/game/mob/pray.dm').read_text()
VERB = (ROOT / 'code/modules/admin/verbs/divine_patron.dm').read_text()
BOOK_VERB = (ROOT / 'code/modules/admin/verbs/divine_book.dm').read_text()
COVENANT = (ROOT / 'code/modules/divine/covenant.dm').read_text()


def body(text, path):
    return text.split(path, 1)[1].split('\n/', 1)[0]


class Identity(unittest.TestCase):
    def test_built(self):
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('#include "code\\modules\\divine\\identity.dm"', dme)

    def test_saved_outside_world_saves(self):
        self.assertIn('"data/divine_identities.json"', IDENTITY)
        load = body(IDENTITY, '/proc/divine_identities_load()')
        self.assertIn('try', load)
        self.assertIn('divine_clean_name(', load)
        clean = body(IDENTITY, '/proc/divine_clean_name(')
        self.assertIn('sanitize(text, max_length)', clean)

    def test_list_only_offers_current_staff(self):
        choices = body(IDENTITY, '/proc/divine_god_choices()')
        self.assertIn('divine_identity_is_staff(', choices)
        # Never filtered by who is online: the list must not reveal that.
        self.assertNotIn('directory[', choices)
        self.assertIn('R_ADMIN', body(IDENTITY, '/proc/divine_identity_is_staff('))

    def test_label_is_name_and_title(self):
        label = body(IDENTITY, '/proc/divine_identity_label(')
        self.assertIn('"[entry["name"]], [entry["title"]]"', label)

    def test_admins_set_their_own_name(self):
        edit = body(IDENTITY, '/client/proc/divine_edit_identity()')
        self.assertIn('check_rights(R_ADMIN)', edit)
        self.assertIn('divine_set_identity(ckey, name, title)', edit)
        self.assertIn('divine_rename_deity(', edit)
        self.assertIn('"Set my divine name"', VERB)
        speak = VERB.split('if ("Speak as a god")', 1)[1].split('if ("Stop speaking', 1)[0]
        self.assertIn('divine_identity_of(ckey)', speak)
        self.assertNotIn('as text', speak)
        self.assertIn('divine_identity_of(ckey)', BOOK_VERB)
        self.assertNotIn('Which god is writing', BOOK_VERB)

    def test_pray_picks_from_the_list(self):
        pray = body(PRAY, '/mob/verb/pray()')
        self.assertIn('divine_god_choices()', pray)
        self.assertIn('"The gods"', pray)
        self.assertLess(pray.index('divine_god_choices()'), pray.index('"What do you say'))
        self.assertIn('divine_staff_for(deity)', pray)
        self.assertNotIn('pray(msg as text)', PRAY)

    def test_beseech_names_the_god_with_title(self):
        self.assertIn('pray to [divine_label_for(divine_patron)]', body(COVENANT, '/mob/living/human/proc/divine_beseech()'))


if __name__ == '__main__':
    unittest.main()
