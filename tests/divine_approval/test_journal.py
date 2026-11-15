"""Sealed-note source contracts; actual DM assertions are in journal_probe.dm."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
TEXT = (ROOT/'code/modules/divine/journal.dm').read_text()
BOOK = (ROOT/'code/modules/1713/book.dm').read_text()
def body(path):
    return TEXT.split(path, 1)[1].split('\n/', 1)[0]

class Journal(unittest.TestCase):
    def test_ordinary_item_without_cosmetic_or_public_metadata_changes(self):
        self.assertIn('code\\modules\\divine\\journal.dm', (ROOT/'civ13.dme').read_text())
        self.assertIn('/obj/item/weapon/book\n', TEXT)
        for forbidden in ('/obj/item/weapon/book/', 'name =', 'desc =', 'icon =', 'icon_state ='):
            if forbidden.endswith('/'):
                continue # procedures extend the ordinary type, no subtype exists
            self.assertNotIn(forbidden, TEXT)
        self.assertNotIn('/obj/item/weapon/hidden_journal', TEXT)
    def test_initiation_gate(self):
        # Only a god-initiated character played by its own client reads sealed notes.
        gate = body('/mob/living/human/proc/can_read_divine_journal()')
        for check in ('istext(divine_patron)', 'length(divine_patron)', 'client.mob == src'):
            self.assertIn(check, gate)
        code = [line for line in gate.splitlines() if not line.strip().startswith('//')]
        self.assertNotIn('return TRUE', gate)
        for forbidden in ('holder', 'R_ADMIN', 'math', 'password'):
            self.assertNotIn(forbidden, '\n'.join(code))
    def test_projection_gate_and_escaping(self):
        projection = body('/obj/item/weapon/book/proc/divine_journal_html')
        self.assertLess(projection.index('!divine_journal_reader_allowed(H)'), projection.index('var/html'))
        self.assertIn('return ""', projection.split('var/html')[0])
        self.assertIn('html_encode(copytext(title, 1, 81))', projection)
        self.assertIn('html_encode(copytext(note, 1, 1025))', projection)
    def test_bounded_authorized_write(self):
        write = body('/obj/item/weapon/book/proc/record_divine_advancement')
        for check in ('!divine_journal_reader_allowed(H)', 'length(title) > 80', 'length(note) > 1024', 'divine_advancement_entries.len >= 32'):
            self.assertIn(check, write)
        self.assertLess(write.index('!divine_journal_reader_allowed(H)'), write.index('divine_advancement_entries[title] = note'))
    def test_no_ordinary_page_or_research_writes_or_casting(self):
        for forbidden in ('dat =', 'written_pages =', 'cipher_progress', 'cipher_readers', 'research_chapters', 'approve(', 'consume(', '/Topic('):
            self.assertNotIn(forbidden, TEXT)
    def test_read_hook_is_after_viewer_resolution_before_rendering(self):
        read = BOOK.split('/obj/item/weapon/book/proc/show_content', 1)[1].split('\n/', 1)[0]
        self.assertLess(read.index('divine_journal_html'), read.index('var/legacy_snapshot'))
        self.assertIn('call(src, "divine_journal_html")(user)', read)
        self.assertNotIn('dat +=', read)
    def test_copy_routes_do_not_copy_sealed_ledger(self):
        for path in ('code/modules/research_tree/book_printing.dm', 'code/modules/research_tree/book_cipher.dm', 'code/modules/research_tree/book_pages.dm'):
            self.assertNotIn('divine_advancement_entries', (ROOT/path).read_text())

if __name__ == '__main__':
    unittest.main()
