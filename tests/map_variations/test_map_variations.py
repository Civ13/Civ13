"""Offline checks for per-round battle map variations.

They parse every maps/zones/variations/<map>/variations.json and its inserts, check
them against the base map the JSON names, and compare them with the generator.
They also project the loader's file rules from
code/modules/map_variations/map_variations.dm. They do not compile or run
BYOND, so they are not in-game placement, lighting or movement acceptance.

Run from the repository root:
    python3 -I -B tests/map_variations/test_map_variations.py
"""
from pathlib import Path
import json
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_inserts as build  # noqa: E402

VARIATIONS = ROOT / 'maps' / 'zones' / 'variations'
LOADER = ROOT / 'code' / 'modules' / 'map_variations' / 'map_variations.dm'
MAP_DEFINES = ROOT / 'code' / '__defines' / 'maps.dm'
METADATA_DIR = ROOT / 'code' / 'game' / 'objects' / 'map_metadata'


def folders():
    return sorted(p for p in VARIATIONS.iterdir() if p.is_dir())


def load_insert(path):
    text = path.read_text(encoding='utf-8')
    models = {}
    header, _, rest = text.partition('\n\n')
    for line in header.split('\n'):
        match = build.DEFINITION.match(line)
        assert match, '%s: bad model line %r' % (path.name, line)
        models[match.group(1)] = match.group(2)
    grids = build.GRID.findall(text)
    return models, grids


_DEFINED = None


def defined_paths():
    global _DEFINED
    if _DEFINED is None:
        found = set()
        pattern = re.compile(r'^(/[A-Za-z0-9_/]+)')
        for path in (ROOT / 'code').rglob('*.dm'):
            for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
                match = pattern.match(line)
                if match:
                    found.add(match.group(1).split('/proc')[0].split('/verb')[0])
        _DEFINED = found
    return _DEFINED


def metadata_id(dmm_path):
    """The map ID string of the map metadata object placed in a base DMM."""
    text = (ROOT / dmm_path).read_text(encoding='utf-8')
    paths = set(re.findall(r'(/obj/map_metadata[A-Za-z0-9_/]*)', text))
    assert len(paths) == 1, '%s should place one map metadata object' % dmm_path
    meta = paths.pop()
    for source in METADATA_DIR.rglob('*.dm'):
        body = source.read_text(encoding='utf-8', errors='replace')
        match = re.search(r'^%s\s*\n((?:[ \t]+.*\n|\n)*)' % re.escape(meta), body, re.M)
        if match:
            id_match = re.search(r'^\s+ID\s*=\s*(MAP_[A-Z0-9_]+)', match.group(1), re.M)
            assert id_match, '%s has no ID' % meta
            define = re.search(r'^#define %s\s+"([^"]+)"' % id_match.group(1), MAP_DEFINES.read_text(), re.M)
            return define.group(1)
    raise AssertionError('No definition for %s' % meta)


class MapVariationTests(unittest.TestCase):
    def test_generator_is_current(self):
        files = build.build()
        for rel, text in files.items():
            self.assertEqual((VARIATIONS / rel).read_text(encoding='utf-8'), text, rel + ' is stale')
        on_disk = {str(p.relative_to(VARIATIONS)).replace('\\', '/') for p in VARIATIONS.rglob('*') if p.is_file()}
        self.assertEqual(on_disk, set(files))

    def test_manifests_match_their_maps(self):
        self.assertTrue(folders())
        for folder in folders():
            data = json.loads((folder / 'variations.json').read_text(encoding='utf-8'))
            self.assertEqual(folder.name, data['map'].lower(), 'the loader looks up lowertext(map.ID)')
            self.assertEqual(metadata_id(data['base_map']), data['map'])

    def test_slots_and_variants(self):
        for folder in folders():
            data = json.loads((folder / 'variations.json').read_text(encoding='utf-8'))
            cells, (width, height) = build.read_base(data['base_map'])
            claimed = {}
            slot_ids = set()
            for slot in data['slots']:
                self.assertNotIn(slot['id'], slot_ids)
                slot_ids.add(slot['id'])
                self.assertEqual(slot['z'], 1)
                self.assertGreaterEqual(slot['x'], 1)
                self.assertGreaterEqual(slot['y'], 1)
                self.assertLessEqual(slot['x'] + slot['width'] - 1, width)
                self.assertLessEqual(slot['y'] + slot['height'] - 1, height)
                for x in range(slot['x'], slot['x'] + slot['width']):
                    for y in range(slot['y'], slot['y'] + slot['height']):
                        self.assertNotIn((x, y), claimed, 'slots %s and %s overlap' % (slot['id'], claimed.get((x, y))))
                        claimed[(x, y)] = slot['id']
                ids = [v['id'] for v in slot['variants']]
                self.assertEqual(len(ids), len(set(ids)))
                self.assertTrue(any('file' not in v for v in slot['variants']), 'keep an as-built choice')
                self.assertGreaterEqual(sum(1 for v in slot['variants'] if 'file' in v), 1)
                for variant in slot['variants']:
                    self.assertIsInstance(variant['weight'], int)
                    self.assertGreater(variant['weight'], 0)
                    if 'file' in variant:
                        self.assertTrue(variant['desc'].endswith('.'))
                        self.check_insert(folder / variant['file'], slot, cells)

    def check_insert(self, path, slot, cells):
        models, grids = load_insert(path)
        self.assertEqual(len(grids), 1, path.name + ' must have one grid')
        gx, gy, gz, grid = grids[0]
        self.assertEqual((gx, gy, gz), ('1', '1', '1'))
        keep = [key for key, model in models.items() if model == build.KEEP]
        self.assertEqual(len(keep), 1)
        rows = grid.split('\n')
        self.assertEqual(len(rows), slot['height'], path.name)
        changed = 0
        for index, row in enumerate(rows):
            self.assertEqual(len(row), slot['width'] * 2, path.name)
            y = slot['y'] + len(rows) - 1 - index
            for column in range(slot['width']):
                key = row[column * 2:column * 2 + 2]
                self.assertIn(key, models)
                if key == keep[0]:
                    continue
                changed += 1
                x = slot['x'] + column
                self.assertTrue(build.is_open(cells[(x, y)]),
                                '%s changes (%d,%d), which is not open ground in the base map' % (path.name, x, y))
        self.assertGreater(changed, 0)
        for key, model in models.items():
            self.assertNotIn('/area', model, 'inserts may not carry areas')
            for atom in build.split_atoms(model):
                self.assertIn(build.atom_path(atom), defined_paths(), '%s uses an undefined type' % path.name)

    def test_layouts_are_mirrored(self):
        """Every change has a partner across the slot's north-south centre."""
        for folder in folders():
            data = json.loads((folder / 'variations.json').read_text(encoding='utf-8'))
            for slot in data['slots']:
                for variant in slot['variants']:
                    if 'file' not in variant:
                        continue
                    models, grids = load_insert(folder / variant['file'])
                    rows = grids[0][3].split('\n')
                    for index, row in enumerate(rows):
                        mirror = rows[len(rows) - 1 - index]
                        for column in range(slot['width']):
                            here = models[row[column * 2:column * 2 + 2]] == build.KEEP
                            there = models[mirror[column * 2:column * 2 + 2]] == build.KEEP
                            self.assertEqual(here, there, '%s is not mirrored at column %d' % (variant['file'], column))

    def test_loader_rules(self):
        source = LOADER.read_text(encoding='utf-8')
        self.assertIn('#define MAP_VARIATION_KEEP "%s"' % build.KEEP, source)
        self.assertIn('lowertext(map_id)', source)
        self.assertIn('return "inserts may not carry areas"', source)
        self.assertIn('persistence_round_active()', source)
        self.assertIn('map_storage.round_restored', source)
        self.assertIn('CM-SS13', source)
        ticker = (ROOT / 'code' / 'game' / 'gameticker.dm').read_text(encoding='utf-8')
        self.assertIn('if (apply_map_variations())', ticker)
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\map_variations\\map_variations.dm"', dme)


if __name__ == '__main__':
    unittest.main()
