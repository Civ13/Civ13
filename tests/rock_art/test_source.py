"""Rock art: source contract checks.

    python3 tests/rock_art/test_source.py
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/rock_art.dm'


class RockArtSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included_after_paintings(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        index = {line: i for i, line in enumerate(dme)}
        self.assertLess(index['#include "code\\modules\\paintings\\paintings.dm"'], index['#include "code\\modules\\1713\\rock_art.dm"'])

    def test_reuses_painting_pigments(self):
        self.assertNotIn('/obj/item/pigment/', self.text.replace('/obj/item/pigment/afterattack', ''))
        self.assertIn('/obj/item/canvas/rock\n', self.text)
        self.assertIn('needs_easel = FALSE', self.text)

    def test_reach_rule(self):
        editor = (ROOT / 'code/modules/paintings/painting_editor.dm').read_text(encoding='utf-8')
        self.assertIn('istype(C.loc, /obj/structure/rock_art)', editor)

    def test_runtime_overlays(self):
        self.assertIn('/obj/structure/rock_art/persistence_runtime_var(key)\n\treturn key == "overlays" || ..()', self.text)

    def test_no_forbidden_patterns(self):
        self.assertIsNone(re.search(r'(?<![a-z_])(spawn|input)\(', self.text))
        self.assertNotIn(' in world', self.text)


if __name__ == '__main__':
    unittest.main()
