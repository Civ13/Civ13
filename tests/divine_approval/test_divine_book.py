"""Source guards for the god's book: one original per god, copies are plain books."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "code/modules/divine/divine_book.dm"
TEXT = SOURCE.read_text()
VERB = (ROOT / "code/modules/admin/verbs/divine_book.dm").read_text()


def body(path):
    return TEXT.split(path, 1)[1].split('\n/', 1)[0]


class DivineBook(unittest.TestCase):
    def test_built_and_admin_only(self):
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('#include "code\\modules\\divine\\divine_book.dm"', dme)
        self.assertIn('#include "code\\modules\\admin\\verbs\\divine_book.dm"', dme)
        self.assertIn('/client/proc/cmd_admin_create_divine_book,', (ROOT / 'code/modules/admin/admin_verbs.dm').read_text())
        verb = VERB.split('/client/proc/cmd_admin_create_divine_book()', 1)[1]
        self.assertIn('check_rights(R_ADMIN)', verb)
        self.assertLess(verb.index('check_rights(R_ADMIN)'), verb.index('input('))

    def test_one_original_per_god(self):
        create = body('/proc/create_divine_book(')
        self.assertLess(create.index('divine_book_problem(deity)'), create.index('new('))
        problem = body('/proc/divine_book_problem(')
        self.assertIn('divine_book_original(deity)', problem)
        find = body('/proc/divine_book_original(')
        self.assertIn('QDELETED(B)', find)
        self.assertIn('B.divine_original', find)
        # Names match regardless of case or spacing.
        self.assertIn('lowertext(trim(deity))', body('/proc/divine_book_key('))

    def test_waits_for_load_and_save(self):
        problem = body('/proc/divine_book_problem(')
        for check in ('persistence_player_restore_ready', 'persistence_save_in_progress', 'persistence_active_operation'):
            self.assertIn(check, problem)

    def test_survives_saves(self):
        # Saved fields, not tmp or runtime vars, so a load restores the original.
        self.assertRegex(TEXT, r'\n\tvar/divine_deity = null')
        self.assertRegex(TEXT, r'\n\tvar/divine_original = FALSE')
        self.assertNotIn('var/tmp/divine', TEXT)
        self.assertNotIn('persistence_runtime_var', TEXT)
        # Restored books register themselves in New, before their fields arrive.
        self.assertIn('divine_book_originals += src', body('/obj/item/weapon/book/divine/New()'))
        self.assertIn('divine_book_originals -= src', body('/obj/item/weapon/book/divine/Destroy()'))

    def test_copies_are_plain_books_and_original_is_sealed(self):
        # Copy paths build /obj/item/weapon/book, never the divine type.
        press = (ROOT / 'code/modules/research_tree/book_printing.dm').read_text()
        self.assertNotIn('book/divine', press)
        self.assertNotIn('book/divine', (ROOT / 'code/modules/1713/book.dm').read_text())
        self.assertNotRegex(TEXT, r'\n\tunique = TRUE')
        self.assertIn('divine_original ? FALSE', body('/obj/item/weapon/book/divine/can_hold_notes()'))

    def test_no_new_original_from_copy_paths(self):
        self.assertEqual(len(re.findall(r'divine_original = TRUE', TEXT)), 1)


if __name__ == '__main__':
    unittest.main()
