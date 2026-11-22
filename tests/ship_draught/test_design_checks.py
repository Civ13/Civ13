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


class StationDesigner(unittest.TestCase):
    """The station designer window (code/modules/space/station_designer.dm)."""
    SOURCE = (SPACE / 'station_designer.dm').read_text(encoding='utf-8')

    def pictures(self):
        block = self.SOURCE.split('/proc/station_designer_sprites()', 1)[1].split('\treturn table', 1)[0]
        return re.findall(r'"(\w+)" = \'(icons/station_designer/(\w+)\.png)\'', block)

    def test_every_module_has_a_picture_cut_by_the_script(self):
        # scripts/build_station_designer_icons.py cuts them from the game's DMIs.
        pairs = self.pictures()
        names = [name for name, _path, _stem in pairs]
        self.assertEqual(len({name.lower() for name in names}), len(names))
        for name, path, stem in pairs:
            with self.subTest(picture=name):
                self.assertEqual(name, stem)
                data = (ROOT / path).read_bytes()
                self.assertEqual(data[:8], b'\x89PNG\r\n\x1a\n')
                self.assertEqual(data[16:24], b'\x00\x00\x00\x20\x00\x00\x00\x20')
        block = STATION.split('/proc/station_plan_pieces()', 1)[1].split('\treturn table', 1)[0]
        for key in re.findall(r'^\t\t"(\w)" = list\(', block, re.M):
            self.assertIn('mod_' + key, names)
        for name in ('hull', 'floor', 'hatch', 'keel_truss', 'keel_wing', 'keel_thruster'):
            self.assertIn(name, names)
        on_disk = sorted(path.stem for path in (ROOT / 'icons/station_designer').glob('*.png'))
        self.assertEqual(on_disk, sorted(names))
        script = (ROOT / 'scripts/build_station_designer_icons.py').read_text(encoding='utf-8')
        self.assertEqual(sorted(re.findall(r"^    '(\w+)': \{'layers'", script, re.M)), sorted(names))

    def test_the_window_replaces_the_stopgap_and_is_built(self):
        self.assertIn('#include "code\\modules\\space\\station_designer.dm"', DME)
        self.assertEqual(STATION.count('proc/open_station_designer'), 0)
        self.assertEqual(self.SOURCE.count('/obj/item/ship_draught/proc/open_station_designer(mob/living/human/H)'), 1)
        # No global initialiser: the world's global init proc is full.
        self.assertNotRegex(self.SOURCE, r'var/global/')

    def test_the_page_is_one_raw_string_with_one_block_of_data(self):
        page = self.SOURCE.split('/proc/station_designer_page()\n\treturn @{"', 1)[1]
        self.assertEqual(page.count('"}'), 1)
        page = page.split('"}', 1)[0]
        self.assertEqual(page.count('@@DATA@@'), 1)
        self.assertNotIn('\u2014', self.SOURCE)
        for name in ('stationPlan', 'stationStatus'):
            self.assertIn('function %s(' % name, page)
            self.assertIn('.browser:%s"' % name, self.SOURCE)

    def test_what_the_window_sends_is_checked(self):
        topic = self.SOURCE.split('/datum/station_designer/Topic(', 1)[1].split('\n/proc/', 1)[0]
        for needed in ('H != drawer', 'station_designers()[H] != src', 'ship_designer_can_draw(H, sheet)', 'length(code) > DESIGN_CODE_STATION_MAX', 'station_plan_from_code(code)', 'station_plan_clean_name(href_list["name"])', 'sheet.take_station(D)'):
            self.assertIn(needed, topic)
        self.assertLess(topic.index('station_plan_from_code(code)'), topic.index('sheet.take_station(D)'))


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
