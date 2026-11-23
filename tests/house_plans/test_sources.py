"""House plans (code/game/objects/house_plan.dm, house_plan_checks.dm,
house_designer.dm): every part the planner offers is described and costs what
its recipe says, the sheet reads the code and the window's page is sound.
The rules themselves are proved by the native probe (run.py). Stdlib only.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OBJECTS = ROOT / 'code/game/objects'
PLAN = (OBJECTS / 'house_plan.dm').read_text(encoding='utf-8')
CHECKS = (OBJECTS / 'house_plan_checks.dm').read_text(encoding='utf-8')
DESIGNER = (OBJECTS / 'house_designer.dm').read_text(encoding='utf-8')
DEFINES = (ROOT / 'code/__defines/house_plans.dm').read_text(encoding='utf-8')
PEGS = (OBJECTS / 'house_plan_pegs.dm').read_text(encoding='utf-8')
MARKERS = (OBJECTS / 'build_markers.dm').read_text(encoding='utf-8')
MARKER_DEFINES = (ROOT / 'code/__defines/build_markers.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8', errors='replace')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8', errors='replace')

# What a builder crafts to get each roof: the plan names the roof it becomes.
ROOFING = {
    '/obj/roof/thatch': '/obj/item/weapon/roofbuilder/leaves',
    '/obj/roof/wood': '/obj/item/weapon/roofbuilder',
    '/obj/roof/clay': '/obj/item/weapon/clay/roofing',
    '/obj/roof/concrete': '/obj/item/weapon/roofbuilder/concrete',
    '/obj/roof/glass': '/obj/item/weapon/roofbuilder/glass',
}
# Built in steps by hand, not from one recipe line.
STAGED = {'/obj/covers/wood_wall/log', '/obj/covers/cement_wall'}


def table(name):
    block = PLAN.split('/proc/%s()' % name, 1)[1].split('\treturn table', 1)[0]
    rows = {}
    for key, body in re.findall(r'^\t\t"(\w)" = list\((.*)\),$', block, re.M):
        cost = re.search(r'"cost" = list\("([\w ]+)" = ([\d.]+)\)', body)
        rows[key] = {
            'name': re.search(r'"name" = "([^"]+)"', body).group(1),
            'type': re.search(r'"type" = ([\w/]+)', body).group(1),
            'cost': float(cost.group(2)),
        }
    return rows


def recipe_costs(path):
    return [float(cost) for cost in re.findall(r'^RECIPE: [^,]+,[^,]+,%s,([\d.]+),' % re.escape(path), RECIPES, re.M)]


class HousePlanTables(unittest.TestCase):
    def test_tables_are_read(self):
        self.assertEqual(len(table('house_plan_pieces')), 11)
        self.assertEqual(len(table('house_plan_floors')), 3)
        self.assertEqual(len(table('house_plan_roofs')), 5)

    def test_every_part_is_described(self):
        book = CHECKS.split('/datum/design_part_book/house_plan/entries()', 1)[1]
        described = set(re.findall(r'^\t\t"(\w+)" = list\("what" = "[^"]+", "use" = "[^"]+", "how" = "[^"]+"\),$', book, re.M))
        wanted = set(table('house_plan_pieces'))
        wanted |= {'floor_' + key for key in table('house_plan_floors')}
        wanted |= {'roof_' + key for key in table('house_plan_roofs')}
        wanted |= {'x', 'note'}
        self.assertEqual(described, wanted)

    def test_parts_cost_what_their_recipes_say(self):
        rows = {**table('house_plan_pieces'), **{'f' + k: v for k, v in table('house_plan_floors').items()},
                **{'r' + k: v for k, v in table('house_plan_roofs').items()}}
        for key, row in rows.items():
            if row['type'] in STAGED:
                continue
            costs = recipe_costs(ROOFING.get(row['type'], row['type']))
            self.assertTrue(costs, '%s has no recipe for %s' % (row['name'], row['type']))
            self.assertIn(row['cost'], costs, row['name'])

    def test_checks_name_real_parts(self):
        keys = set(re.findall(r'^\t\t"(\w+)" = list\("what"', CHECKS, re.M))
        for part in re.findall(r'R\.(?:error|warning|note)\(.*?, (?:\w+|null), "(\w+)", \w+(?: - 1)?\)$', CHECKS, re.M):
            self.assertIn(part, keys)
        self.assertEqual(CHECKS.count('\tkind = "house_plan"'), 2)


class BuildersPegs(unittest.TestCase):
    def dmi_states(self):
        import zlib
        data = (ROOT / 'icons/obj/build_markers.dmi').read_bytes()
        at = data.index(b'zTXtDescription\x00\x00') + len(b'zTXtDescription\x00\x00')
        length = int.from_bytes(data[at - len(b'zTXtDescription\x00\x00') - 4:at - len(b'zTXtDescription\x00\x00')], 'big')
        text = zlib.decompress(data[at:at + length - len(b'Description\x00\x00')]).decode('utf-8')
        return re.findall(r'^state = "(\w+)"', text, re.M)

    def test_included_and_defined(self):
        self.assertIn('#include "code\\game\\objects\\build_markers.dm"', DME)
        self.assertIn('#include "code\\game\\objects\\house_plan_pegs.dm"', DME)
        self.assertIn('#include "code\\__defines\\build_markers.dm"', DME)
        for define in ('BUILD_MARKER_WORLD_MAX', 'BUILD_MARKER_SWEEP', 'BUILD_MARKER_BATCH'):
            self.assertEqual(len(re.findall(r'^#define %s \d+' % define, MARKER_DEFINES, re.M)), 1)
            self.assertNotIn('#define ' + define, MARKERS + PEGS)

    def test_every_kind_has_a_tag_and_a_rule(self):
        kinds = dict(re.findall(r'^\t\t"(\w+)" = list\("name" = "[^"]+", "state" = "(\w+)"\),$', MARKERS, re.M))
        self.assertEqual(set(kinds), {'wall', 'door', 'window', 'pillar', 'stairs', 'ladder', 'floor', 'roof'})
        states = self.dmi_states()
        built = MARKERS.split('/proc/build_marker_built(', 1)[1].split('\n/proc/', 1)[0]
        for kind, state in kinds.items():
            self.assertIn(state, states)
            self.assertIn('if ("%s")' % kind, built)
        for state in ('peg', 'note', 'rail'):
            self.assertIn(state, states)

    def test_every_plan_piece_is_a_kind_of_peg(self):
        kinds = set(re.findall(r'^\t\t"(\w+)" = list\("name" = "[^"]+", "state"', MARKERS, re.M))
        pieces = PLAN.split('/proc/house_plan_pieces()', 1)[1].split('\n\treturn table', 1)[0]
        self.assertTrue(set(re.findall(r'"kind" = "(\w+)"', pieces)) <= kinds)
        self.assertIn('. += "floor=[', PEGS)
        self.assertIn('. += "roof=[', PEGS)

    def test_a_peg_saves_as_text_and_keeps_no_global(self):
        self.assertIn('map_storage_saved_vars = "icon_state;name;wants;set_id;set_name;note"', MARKERS)
        self.assertNotIn('var/global', MARKERS + PEGS)
        for field in ('peg_set', 'peg_x', 'peg_y', 'peg_z'):
            self.assertEqual(len(re.findall(r'^\tvar/%s = ' % field, PEGS, re.M)), 1)

    def test_a_peg_passes_clicks_to_its_tile(self):
        click = MARKERS.split('/obj/effect/build_marker/Click(', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('modifiers["shift"] || modifiers["alt"]', click)
        self.assertIn('return T.Click(location, control, params)', click)
        self.assertIn('density = FALSE', MARKERS)

    def test_the_sheet_offers_pegging(self):
        menu = PLAN.split('/obj/item/ship_draught/proc/house_sheet_menu(', 1)[1]
        for option in ('"Peg it out on the ground"', '"Peg out the storey I stand on"', '"Pull up the pegs and forget the site"'):
            self.assertIn(option, menu)


class HousePlanSheet(unittest.TestCase):
    def test_included_and_defined(self):
        for name in ('house_plan', 'house_plan_checks', 'house_designer'):
            self.assertIn('#include "code\\game\\objects\\%s.dm"' % name, DME)
        self.assertIn('#include "code\\__defines\\house_plans.dm"', DME)
        for define in ('HOUSE_PLAN_SIDE', 'HOUSE_PLAN_STOREYS', 'HOUSE_PLAN_NOTES_MAX', 'HOUSE_PLAN_NOTE_LENGTH', 'DESIGN_CODE_HOUSE_MAX'):
            self.assertEqual(len(re.findall(r'^#define %s \d+' % define, DEFINES, re.M)), 1)
            self.assertNotIn('#define ' + define, PLAN + CHECKS + DESIGNER)

    def test_the_sheet_reads_a_house_code(self):
        kinds = (ROOT / 'code/modules/naval/draught_kinds.dm').read_text(encoding='utf-8')
        self.assertIn('"HOUSE" = list("name" = "house", "title" = "House plan", "max" = DESIGN_CODE_HOUSE_MAX, "read" = /proc/house_plan_from_code, "take" = "take_house", "open" = "open_house_designer"', kinds)
        sheet = (ROOT / 'code/modules/naval/ship_draught.dm').read_text(encoding='utf-8')
        self.assertIn('"Draw a house on the sheet"', sheet)
        self.assertEqual(sheet.count('house_plan()'), 2)
        codes = (ROOT / 'code/modules/paintings/design_codes.dm').read_text(encoding='utf-8')
        self.assertIn('if ("HOUSE")\n\t\t\treturn "a house plan"', codes)

    def test_file_local_defines_are_undefined(self):
        for source in (PLAN, DESIGNER, PEGS, MARKERS):
            for name in re.findall(r'^#define (\w+)', source, re.M):
                self.assertIn('#undef ' + name, source)


class HouseDesignerPage(unittest.TestCase):
    def setUp(self):
        self.page = DESIGNER.split('/proc/house_designer_page()\n\treturn @{"', 1)[1].split('"}\n\n#undef', 1)[0]

    def test_page_is_one_raw_string(self):
        self.assertEqual(self.page.count('@@DATA@@'), 1)
        self.assertNotIn('"}', self.page)
        self.assertTrue(self.page.rstrip().endswith('</html>'))

    def test_page_answers_the_server(self):
        for name in ('houseAck', 'housePlan', 'houseStatus', 'houseSaved'):
            self.assertIn('function %s(' % name, self.page)
            self.assertIn('browser:%s"' % name, DESIGNER)
        for word in ('begin', 'part', 'end'):
            self.assertIn("house=%s" % word, self.page)
            self.assertIn('if ("%s")' % word, DESIGNER)

    def test_page_and_plan_write_the_same_code(self):
        self.assertIn("return 'C13HOUSE/1/'+nm+'/'+runs.join(';')+'/'+nt.join(';');", self.page)
        self.assertIn('return "C13HOUSE/1/[replacetext(house_plan_clean_name(name), " ", "_")]/[jointext(runs, ";")]/[jointext(pinned, ";")]"', PLAN)

    def test_window_data_is_all_used(self):
        data = DESIGNER.split('/proc/house_designer_data(', 1)[1].split('\n\t)\n', 1)[0]
        for key in re.findall(r'^\t\t"(\w+)" = ', data, re.M):
            self.assertIn('DATA.' + key, self.page, key)


if __name__ == '__main__':
    unittest.main()
