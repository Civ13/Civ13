"""Train sheets (code/modules/1713/train_draught.dm, train_draught_checks.dm,
train_works.dm): stock cars cost their kits' recipes, every table row is
described, the rail works can be crafted and researched, and the sheet is a
draught kind. Stdlib only. The native probe is probe.dm.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TRAINS = ROOT / 'code/modules/1713'
DRAUGHT = (TRAINS / 'train_draught.dm').read_text(encoding='utf-8')
CHECKS = (TRAINS / 'train_draught_checks.dm').read_text(encoding='utf-8')
WORKS = (TRAINS / 'train_works.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8', errors='replace')
RESEARCH = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
KINDS = (ROOT / 'code/modules/naval/draught_kinds.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8', errors='replace')
DOC = (ROOT / 'docs/train-sheets.md').read_text(encoding='utf-8')


def table(name):
    block = DRAUGHT.split('/proc/%s()' % name, 1)[1].split('\treturn table', 1)[0]
    return re.findall(r'^\t\t"(\w+)" = list\((.*)\),?$', block, re.M)


def recipe(path):
    found = []
    for line in RECIPES.splitlines():
        if line.startswith('RECIPE: ') and not line.startswith('//'):
            fields = line[len('RECIPE: '):].split(',')
            if len(fields) > 3 and fields[2] == path:
                found.append((fields[0].strip('/').split('/')[-1], int(fields[3])))
    return found


def kit_kinds():
    kinds = {'/obj/structure/train_car_kit': 'flatbed'}
    for source in TRAINS.glob('train_*.dm'):
        text = source.read_text(encoding='utf-8')
        for path, kind in re.findall(r'^(/obj/structure/train_car_kit/\w+)\n(?:\t.*\n)*?\tcar_kind = "(\w+)"', text, re.M):
            kinds[path] = kind
    return kinds


class StockCars(unittest.TestCase):
    def test_every_stock_car_costs_its_kit_recipe(self):
        rows = table('train_draught_stock')
        self.assertGreaterEqual(len(rows), 29)
        kits = kit_kinds()
        for kind, body in rows:
            with self.subTest(kind=kind):
                kit = re.search(r'"kit" = (/obj/structure/train_car_kit[\w/]*)', body).group(1)
                self.assertEqual(kits.get(kit), kind)
                cost = dict((m, int(n)) for m, n in re.findall(r'"(\w+)" = (\d+)', body.split('"cost"', 1)[1]))
                found = recipe(kit)
                self.assertEqual(len(found), 1, found)
                material, amount = found[0]
                self.assertEqual(cost, {material: amount})

    def test_every_kit_kind_can_be_drawn(self):
        kinds = {kind for kind, _ in table('train_draught_stock')}
        for path, kind in kit_kinds().items():
            with self.subTest(kit=path):
                self.assertIn(kind, kinds)


class Tables(unittest.TestCase):
    def test_every_row_is_described(self):
        for name in ('train_draught_floors', 'train_draught_roofs', 'train_draught_edges', 'train_draught_fittings'):
            rows = table(name)
            self.assertGreaterEqual(len(rows), 6)
            for key, body in rows:
                with self.subTest(table=name, key=key):
                    self.assertEqual(len(key), 1)
                    for field in ('name', 'use', 'how'):
                        self.assertIn('"%s" = "' % field, body)
                    for text in re.findall(r'"(?:use|how)" = "([^"]+)"', body):
                        self.assertTrue(text.endswith('.'), text)
                        self.assertNotIn('—', text)

    def test_keys_are_unique_letters_per_table_and_never_the_none_mark(self):
        for name in ('train_draught_floors', 'train_draught_roofs', 'train_draught_edges', 'train_draught_fittings'):
            keys = [key for key, _ in table(name)]
            self.assertEqual(len(keys), len(set(keys)), name)
            self.assertNotIn('.', keys)

    def test_edges_and_floors_use_existing_states(self):
        dmi = (ROOT / 'icons/obj/vehicles/train_platforms.dmi').read_bytes()
        import struct
        import zlib
        states = set()
        i = 8
        while i < len(dmi):
            n, = struct.unpack('>I', dmi[i:i + 4])
            kind = dmi[i + 4:i + 8]
            if kind == b'zTXt':
                body = dmi[i + 8:i + 8 + n]
                _key, rest = body.split(b'\0', 1)
                states.update(re.findall(r'state = "([^"]+)"', zlib.decompress(rest[1:]).decode()))
            i += 12 + n
        for key, body in table('train_draught_edges'):
            style = re.search(r'"style" = "(\w+)"', body).group(1)
            self.assertIn('edge_' + style, states, key)
        for key, body in table('train_draught_floors'):
            for part, prefix in (('center', 'deck_center_'), ('side', 'deck_side_')):
                state = re.search(r'"%s" = "(\w+)"' % part, body).group(1)
                self.assertIn(prefix + state, states, key)
        for key, body in table('train_draught_roofs'):
            state = re.search(r'"state" = "(\w+)"', body).group(1)
            for row in 'fmb':
                for col in 'lcr':
                    self.assertIn('roof_%s_%s%s' % (state, row, col), states, key)


class Wiring(unittest.TestCase):
    def test_rail_works_is_crafted_and_gated(self):
        self.assertEqual(recipe('/obj/structure/rail_works'), [('iron', 30)])
        self.assertIn('"/obj/structure/rail_works" = "rail_steam"', RESEARCH)

    def test_sheet_is_a_draught_kind(self):
        self.assertIn('"TRAIN" = list("name" = "train", "max" = DESIGN_CODE_TRAIN_MAX, "read" = /proc/train_draught_from_code, "take" = "take_train")', KINDS)

    def test_files_are_included(self):
        for name in ('train_draught', 'train_draught_checks', 'train_works', 'train_designer'):
            self.assertIn('#include "code\\modules\\1713\\%s.dm"' % name, DME)

    def test_checks_name_their_kind_and_part_book_covers_tables(self):
        self.assertIn('kind = "train_sheet"', CHECKS)
        for prefix, name in (('floor_', 'train_draught_floors'), ('roof_', 'train_draught_roofs'), ('edge_', 'train_draught_edges'), ('fit_', 'train_draught_fittings')):
            self.assertIn('"%s" = %s()' % (prefix, name), CHECKS)

    def test_works_spends_stock_only_after_building(self):
        build = WORKS.split('/obj/structure/rail_works/proc/build_train(', 1)[1].split('\n/', 1)[0]
        self.assertLess(build.index('K.assemble(heading)'), build.index('stock[key] -= costs[key]'))
        self.assertIn('qdel(M)', build)

    def test_doc_describes_the_code_format(self):
        self.assertIn('C13TRAIN/1/<name>/<car>;<car>;...', DOC)
        self.assertIn('c:<length>:<floor>:<roof>:<front>:<back>:<section>,...:<name>', DOC)


if __name__ == '__main__':
    unittest.main()
