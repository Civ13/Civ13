"""Offline checks for player design codes (code/modules/paintings/design_codes.dm)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class DesignCodesTest(unittest.TestCase):
    def test_module_is_in_the_dme_after_the_codec(self):
        dme = read('civ13.dme')
        codec = dme.index('#include "code\\modules\\paintings\\painting_codec.dm"')
        codes = dme.index('#include "code\\modules\\paintings\\design_codes.dm"')
        self.assertLess(codec, codes)

    def test_every_kind_has_an_exporter_and_a_reader(self):
        pairs = {
            'code/modules/paintings/design_codes.dm': ('"C13ART/1/', 'design_code_fields(code, "ART", DESIGN_CODE_ART_MAX)'),
            'code/game/objects/structures/sign_flags.dm': ('"C13FLAG/1/', 'design_code_fields(code, "FLAG")'),
            'code/modules/1713/structures.dm': ('"C13POLE/1/', 'design_code_fields(code, "POLE")'),
            'code/modules/1713/dressmaking.dm': ('"C13CLOTH/1/', 'design_code_fields(code, "CLOTH")'),
        }
        for path, (writer, reader) in pairs.items():
            with self.subTest(path=path):
                text = read(path)
                self.assertIn(writer, text)
                self.assertIn(reader, text)

    def test_every_import_is_logged_and_rate_limited(self):
        for path, kind in (('code/game/objects/structures/sign_flags.dm', '"flag"'),
                           ('code/modules/1713/structures.dm', '"pole flag"'),
                           ('code/modules/1713/dressmaking.dm', '"clothing"'),
                           ('code/modules/paintings/painting_editor.dm', '"picture"')):
            with self.subTest(path=path):
                self.assertIn(f'design_code_log(', read(path))
                self.assertIn(kind, read(path))
        shared = read('code/modules/paintings/design_codes.dm')
        self.assertIn('log_game(line)', shared)
        self.assertIn('design_code_cooldown_ok(user)', shared)
        self.assertRegex(shared, r'#define DESIGN_CODE_SHORT_MAX \d+')
        self.assertIn('painting_import_log_html()', read('code/modules/paintings/painting_admin.dm'))

    def test_imports_keep_the_normal_rules(self):
        editor = read('code/modules/paintings/painting_editor.dm')
        # The browser only fills the grid; the save still checks pigments and size.
        self.assertIn("href_list[\"imported\"] == \"1\"", editor)
        self.assertIn('painting_allowed_colours(user, src)', editor)
        self.assertIn('MAXSIDE=[PAINT_MAX_SIDE]', editor)
        self.assertIn('function nearest(c)', editor)
        tailoring = read('code/modules/1713/dressmaking.dm')
        self.assertIn('tailoring_name_blocked(user.ckey) ? null : design["name"]', tailoring)
        self.assertRegex(tailoring, r'load_design\(user, design\["body"\].*"design code"\)')

    def test_finished_paintings_share_codes_only_with_the_painter(self):
        codec = read('code/modules/paintings/painting_codec.dm')
        self.assertIn('painting_code_allowed(user, C.author_ckey)', codec)
        drawings = read('code/modules/paintings/drawings.dm')
        self.assertIn('painting_code_allowed(reader, D["ckey"])', drawings)

    def test_saved_flags_redraw_from_their_design(self):
        self.assertIn('/obj/structure/sign/flag/custom/after_load()', read('code/game/objects/structures/sign_flags.dm'))
        self.assertIn('/obj/structure/flag/pole/custom/after_load()', read('code/modules/1713/structures.dm'))


if __name__ == '__main__':
    unittest.main()
