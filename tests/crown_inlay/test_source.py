"""Offline checks for inlaying diamonds into crowns."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'code/modules/1713/apparel_medieval.dm'


class CrownInlayTest(unittest.TestCase):
    def setUp(self):
        self.text = SRC.read_text(encoding='utf-8')

    def test_crowns_accept_cut_diamonds(self):
        proc = self.text[self.text.index('/proc/inlay_crown_diamond('):]
        proc = proc[:proc.index('\n/')]
        self.assertIn('/obj/item/stack/gemstone/diamond', proc)
        self.assertIn('/obj/item/stack/material/diamond', proc)
        self.assertIn('S.use(1)', proc)

    def test_crown_handlers_fall_through(self):
        for metal in ('gold', 'silver'):
            decl = f'/obj/item/clothing/head/helmet/{metal}_crown/attackby'
            self.assertEqual(self.text.count(decl), 1)
            body = self.text[self.text.index(decl):]
            body = body[:body.index('\n/', 1)]
            self.assertIn('inlay_crown_diamond(', body)
            self.assertIn('return ..()', body)
            self.assertRegex(self.text, rf'/obj/item/clothing/head/helmet/{metal}_crown\n\tvar/inlaid_type = /obj/item/clothing/head/helmet/{metal}_crown_diamond')


if __name__ == '__main__':
    unittest.main()
