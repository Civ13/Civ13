"""Design checks and part descriptions (code/modules/craft/design_checks.dm,
code/modules/naval/draught_checks.dm, draught_part_help.dm): every part a
vehicle editor offers is described, and every check names a kind. Stdlib only.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NAVAL = ROOT / 'code/modules/naval'
SHIP = (NAVAL / 'ship_draught.dm').read_text(encoding='utf-8')
SUB = (NAVAL / 'sub_draught.dm').read_text(encoding='utf-8')
HELP = (NAVAL / 'draught_part_help.dm').read_text(encoding='utf-8')
CRAFT = ROOT / 'code/modules/craft'
CAR = (CRAFT / 'vehicle_draught.dm').read_text(encoding='utf-8')
CAR_HELP = (CRAFT / 'vehicle_draught_checks.dm').read_text(encoding='utf-8')
AIR = (NAVAL / 'air_draught.dm').read_text(encoding='utf-8')
AIR_HELP = (NAVAL / 'air_draught_checks.dm').read_text(encoding='utf-8')
SPACE = ROOT / 'code/modules/space'
STATION = (SPACE / 'station_plan.dm').read_text(encoding='utf-8')
STATION_HELP = (SPACE / 'station_plan_checks.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8', errors='replace')


def table_keys(source, name):
    block = source.split('/proc/%s()\n\tvar/static/list/table\n\tif (!table)\n\t\ttable = list(' % name if '/proc/%s()\n' % name in source else 'var/global/list/%s = list(' % name, 1)[1].split('\n)\n', 1)[0]
    return re.findall(r'^\t"(\w+)" = ', block, re.M)


def book(kind, source=None):
    block = (source or HELP).split('/datum/design_part_book/%s/entries()' % kind, 1)[1]
    block = block.split('\n\t)\n', 1)[0]
    rows = {}
    for key, what, use, how in re.findall(r'^\t\t"(\w+)" = list\("what" = "([^"]+)", "use" = "([^"]+)", "how" = "([^"]+)"\)', block, re.M):
        rows[key] = (what, use, how)
    return rows


class PartDescriptions(unittest.TestCase):
    def test_every_ship_part_is_described(self):
        rows = book('ship')
        wanted = table_keys(SHIP, 'ship_draught_floors') + table_keys(SHIP, 'ship_draught_pieces') + ['u', 'x']
        self.assertGreaterEqual(len(wanted), 24)
        for key in wanted:
            with self.subTest(part=key):
                self.assertIn(key, rows)

    def test_every_submarine_part_is_described(self):
        rows = book('sub')
        wanted = table_keys(SUB, 'sub_draught_frames') + table_keys(SUB, 'sub_draught_fittings') + ['wb', 'wd', 'wn']
        for key in wanted:
            with self.subTest(part=key):
                self.assertIn(key, rows)

    def test_every_vehicle_sheet_part_is_described(self):
        rows = book('vehicle_sheet', CAR_HELP)
        wanted = ['x']
        for table in ('vehicle_draught_axes', 'vehicle_draught_frames', 'vehicle_draught_movers', 'vehicle_draught_parts', 'vehicle_draught_engines'):
            wanted += table_keys(CAR, table)
        self.assertGreaterEqual(len(wanted), 29)
        for key in wanted:
            with self.subTest(part=key):
                self.assertIn(key, rows)

    def test_every_airship_sheet_part_is_described(self):
        rows = book('air_sheet', AIR_HELP)
        wanted = ['x'] + table_keys(CAR, 'vehicle_draught_engines')
        for table in ('air_draught_decks', 'air_draught_cells', 'air_draught_parts'):
            block = AIR.split('/proc/%s()' % table, 1)[1].split('\treturn table', 1)[0]
            wanted += re.findall(r'^\t\t"(\w+)" = list\(', block, re.M)
        self.assertGreaterEqual(len(wanted), 23)
        for key in wanted:
            with self.subTest(part=key):
                self.assertIn(key, rows)

    def test_every_station_plan_part_is_described(self):
        rows = book('station_plan', STATION_HELP)
        block = STATION.split('/proc/station_plan_pieces()', 1)[1].split('\treturn table', 1)[0]
        wanted = ['x'] + re.findall(r'^\t\t"(\w+)" = list\(', block, re.M)
        self.assertGreaterEqual(len(wanted), 9)
        for key in wanted:
            with self.subTest(part=key):
                self.assertIn(key, rows)

    def test_descriptions_are_sentences_without_em_dashes(self):
        sources = {'vehicle_sheet': CAR_HELP, 'air_sheet': AIR_HELP, 'station_plan': STATION_HELP}
        for kind in ('ship', 'sub', 'vehicle_sheet', 'air_sheet', 'station_plan'):
            for key, texts in book(kind, sources.get(kind)).items():
                for text in texts:
                    with self.subTest(kind=kind, part=key):
                        self.assertNotIn('—', text)
                        self.assertTrue(text.endswith('.'), text)


class VehicleDesignerPictures(unittest.TestCase):
    def test_every_picture_exists_and_keys_are_case_safe(self):
        source = (CRAFT / 'vehicle_designer.dm').read_text(encoding='utf-8')
        block = source.split('var/global/list/vehicle_designer_sprites = list(', 1)[1].split('\n)', 1)[0]
        pairs = re.findall(r'"(\w+)" = \'([^\']+)\'', block)
        self.assertEqual(len(pairs), 16)
        self.assertEqual(len({k.lower() for k, _ in pairs}), len(pairs))
        for key, path in pairs:
            with self.subTest(picture=key):
                self.assertTrue((ROOT / path).is_file(), path)


class Checks(unittest.TestCase):
    def test_check_parents_name_a_kind_and_skip_themselves(self):
        for path, kind in (('code/modules/naval/draught_checks.dm', 'ship'), ('code/modules/naval/draught_checks.dm', 'sub'), ('code/modules/craft/vehicle_checks.dm', 'vehicle'), ('code/modules/craft/vehicle_draught_checks.dm', 'vehicle_sheet')):
            source = (ROOT / path).read_text(encoding='utf-8')
            with self.subTest(kind=kind):
                self.assertRegex(source, r'/datum/design_check/%s\n\tkind = "%s"\n\tabstract_type = /datum/design_check/%s\n' % (kind, kind, kind))

    def test_levels_are_shared_defines_and_files_are_built(self):
        defines = (ROOT / 'code/__defines/design_checks.dm').read_text(encoding='utf-8')
        for name in ('DESIGN_NOTE', 'DESIGN_WARNING', 'DESIGN_ERROR'):
            self.assertIn('#define %s ' % name, defines)
        for path in ('code\\__defines\\design_checks.dm', 'code\\modules\\craft\\design_checks.dm', 'code\\modules\\craft\\vehicle_checks.dm', 'code\\modules\\naval\\draught_checks.dm', 'code\\modules\\naval\\draught_part_help.dm', 'code\\modules\\craft\\vehicle_draught.dm', 'code\\modules\\craft\\vehicle_draught_checks.dm', 'code\\modules\\craft\\vehicle_designer.dm'):
            self.assertIn('#include "%s"' % path, DME)


if __name__ == '__main__':
    unittest.main()
