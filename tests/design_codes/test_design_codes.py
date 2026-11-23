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
            'code/modules/paintings/design_codes.dm': ('"C13SYMBOL/1/', 'design_code_fields(code, "SYMBOL", DESIGN_CODE_SYMBOL_MAX)'),
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

    def test_both_symbol_editors_copy_and_paste_codes(self):
        for path in ('code/game/mob/groups/faction_symbol.dm', 'code/game/mob/groups/faction_creation.dm'):
            with self.subTest(path=path):
                text = read(path)
                self.assertIn('href_list["export_code"]', text)
                self.assertIn('href_list["import_code"]', text)
                self.assertIn('faction_symbol_ask_code(owner,', text)
        # Both banner editors share one screen, and their owners admit the two buttons.
        screen = read('tgui/src/interfaces/Faction.tsx')
        self.assertIn('action="export_code">Copy design code<', screen)
        self.assertIn('action="import_code">Paste design code<', screen)
        for path in ('code/game/mob/groups/faction_symbol.dm', 'code/game/mob/groups/faction_creation.dm'):
            with self.subTest(path=path):
                declared = read(path).split('/ui_actions(ui_key)', 1)[1].split('\n/', 1)[0]
                self.assertIn('"export_code", "import_code"', declared)
        editor = read('code/game/mob/groups/faction_symbol.dm')
        # A pasted symbol only fills the canvas, and only for the Leader; Save puts it on banners.
        self.assertIn('if (imported && map.is_faction_leader(owner, faction))', editor)
        shared = read('code/modules/paintings/design_codes.dm')
        self.assertIn('design_code_log(user, "faction symbol", what, code)', shared)

    def test_saved_flags_redraw_from_their_design(self):
        self.assertIn('/obj/structure/sign/flag/custom/after_load()', read('code/game/objects/structures/sign_flags.dm'))
        self.assertIn('/obj/structure/flag/pole/custom/after_load()', read('code/modules/1713/structures.dm'))


class PlanCodesTest(unittest.TestCase):
    """Every plan on a ship's draught exports and imports the same way."""

    DESIGNERS = {
        'code/modules/naval/ship_designer.dm': ('ship', 'SHIP_DESIGNER_WINDOW'),
        'code/modules/naval/sub_designer.dm': ('sub', 'SUB_DESIGNER_WINDOW'),
        'code/modules/naval/air_designer.dm': ('air', 'AIR_DESIGNER_WINDOW'),
        'code/modules/craft/vehicle_designer.dm': ('car', 'VEHICLE_DESIGNER_WINDOW'),
        'code/modules/1713/train_designer.dm': ('train', 'TRAIN_DESIGNER_WINDOW'),
        'code/modules/space/station_designer.dm': ('station', 'STATION_DESIGNER_WINDOW'),
        'code/modules/space/rocket_designer.dm': ('rocket', 'ROCKET_DESIGNER_WINDOW'),
        'code/game/objects/house_designer.dm': ('house', 'HOUSE_DESIGNER_WINDOW'),
        'code/modules/1713/rail_designer.dm': ('rail', 'RAIL_DESIGNER_WINDOW'),
        'code/modules/naval/harbor_planner.dm': ('harbor', 'HARBOR_WINDOW'),
        'code/modules/1713/waterworks_designer.dm': ('waterworks', 'WATERWORKS_DESIGNER_WINDOW'),
        'code/modules/1713/contraption_designer.dm': ('contraption', 'CONTRAPTION_WINDOW'),
    }
    MENUS = ('code/modules/naval/ship_draught.dm', 'code/modules/naval/sub_draught.dm',
             'code/modules/naval/air_draught.dm', 'code/modules/craft/vehicle_draught.dm',
             'code/modules/1713/train_draught.dm', 'code/modules/space/station_plan.dm', 'code/modules/space/rocket_plan.dm',
             'code/game/objects/house_plan.dm', 'code/modules/1713/rail_plan.dm',
             'code/modules/naval/harbor_planner.dm', 'code/modules/1713/waterworks_plan.dm',
             'code/modules/1713/contraption_designer.dm')

    def test_every_kind_row_names_its_designer(self):
        kinds = read('code/modules/naval/draught_kinds.dm')
        rows = re.findall(r'^\t\t"(\w+)" = list\((.*)\),$', kinds, re.M)
        self.assertEqual({k for k, _ in rows}, {'SHIP', 'SUB', 'CAR', 'AIR', 'HOUSE', 'TRAIN', 'STATION', 'ROCKET', 'RAIL', 'HARBOR', 'WATER', 'MECH'})
        windows = {w: re.search(r'#define %s "(\w+)"' % w, read(p)).group(1) for p, (_, w) in self.DESIGNERS.items()}
        for kind, row in rows:
            with self.subTest(kind=kind):
                for field in ('"name"', '"title"', '"max"', '"read"', '"take"', '"open"', '"window"'):
                    self.assertIn(field + ' = ', row)
                window = re.search(r'"window" = "(\w+)"', row).group(1)
                self.assertIn(window, windows.values())
        self.assertIn('"age" = ORBIT_MIN_AGE', dict(rows)['STATION'])
        self.assertIn('"age" = ORBIT_MIN_AGE', dict(rows)['ROCKET'])

    def test_every_sheet_menu_uses_the_shared_labels(self):
        for path in self.MENUS:
            with self.subTest(path=path):
                text = read(path)
                self.assertIn('DRAUGHT_EXPORT_LABEL', text)
                self.assertIn('DRAUGHT_IMPORT_LABEL', text)
                self.assertIn('draught_export(H, D.name)', text)
                self.assertRegex(text, r'draught_import\(H(?:, [a-z_]+)?\)')
                self.assertNotIn('Copy her design code', text)
                self.assertNotIn('"Paste a design code"', text)
        self.assertIn('#define DRAUGHT_EXPORT_LABEL', read('code/__defines/naval.dm'))

    def test_every_designer_window_imports_and_exports(self):
        for path, (key, window) in self.DESIGNERS.items():
            with self.subTest(path=path):
                text = read(path)
                self.assertIn('if (href_list["%s"] == "import")' % key, text)
                self.assertRegex(text, r'draught_import_in_window\(H, %s(?:, (?:[a-z_]+|CALLBACK\(src, PROC_REF\(can_edit\), H\)))?\)' % window)
                self.assertIn('draught_export(H, ', text)

    def test_import_uses_the_designer_reader_and_rules(self):
        kinds = read('code/modules/naval/draught_kinds.dm')
        body = kinds.split('/obj/item/ship_draught/proc/draught_import(mob/living/human/H,', 1)[1].split('\n/', 1)[0]
        for needle in ('design_code_ask(H,', 'length(typed) > K["max"]', 'call(K["read"])(typed)',
                       'design_code_refusal(', 'map.ordinal_age < K["age"]', 'design_code_log(H,',
                       'check_design()', 'R.chat_lines()'):
            self.assertIn(needle, body)
        self.assertNotIn('paste_any_code', read('code/modules/naval/sub_draught.dm'))


if __name__ == '__main__':
    unittest.main()
