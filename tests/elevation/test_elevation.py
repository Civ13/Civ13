"""Offline production-source projections and integration contracts; no native tools."""
import hashlib
import importlib.util
import json
from pathlib import Path
import random
import subprocess
import tempfile
from types import SimpleNamespace as NS
import unittest

from projection import L, ROOT, SOURCE, body, load, packed, unpacked


def region(x1=2, x2=4, y1=2, y2=4, z=1, metres=1200):
    return L(dict(x1=x1, x2=x2, y1=y1, y2=y2, z=z, metres=metres))


class ElevationTests(unittest.TestCase):
    def setUp(self):
        self.env = load()

    def build(self, rows=(), default=0, dimensions=(8, 6, 2)):
        return self.env['build_elevation_profile'](default, L(rows), *dimensions)

    def test_flat_default_null_map_and_physical_containers(self):
        e = self.env
        self.assertEqual(e['get_elevation'](None, None), 0)
        turf = NS(is_turf=True, x=3, y=3, z=1, loc=NS(climate='jungle'))
        item = NS(loc=NS(loc=turf))
        self.assertEqual(e['get_elevation'](None, item), 0)
        e['map'] = e['Map'](50, L([region()]))
        self.assertEqual(e['get_elevation'](None, item), 1200)
        e['map'] = None
        self.assertEqual(e['get_elevation'](None, item), 0)

    def test_inclusive_edges_disjoint_z_and_no_height_inference(self):
        p = self.build([region(), region(z=2, metres=-25)], default=100)
        for x, y in ((2, 2), (2, 4), (4, 2), (4, 4), (3, 3)):
            self.assertEqual(p.at(x, y, 1), 1200)
            self.assertEqual(p.at(x, y, 2), -25)
        for x, y in ((1, 3), (5, 3), (3, 1), (3, 5)):
            self.assertEqual(p.at(x, y, 1), 100)
        self.assertEqual(p.at(8, 6, 2), 100)

    def test_finite_numeric_bounds_and_coordinate_admission(self):
        for value in (-12000, -0.5, 0, 12000):
            self.assertEqual(self.build(default=value).at(1, 1, 1), value)
        for value in (None, '100', [], float('nan'), float('inf'), -float('inf'), -12001, 12001):
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.build(default=value)
            with self.subTest(region_value=value), self.assertRaises(ValueError):
                self.build([region(metres=value)])
        for key, value in (('x1', 0), ('x2', 9), ('y1', 1.5), ('y2', 7),
                           ('z', 0), ('z', 3), ('x1', 5), ('y1', 5), ('x1', None)):
            row = region()
            row[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                self.build([row])
        for dimensions in ((0, 6, 2), (8, 6, -1), (8.5, 6, 2), (32768, 6, 2)):
            with self.assertRaises(ValueError):
                self.build(dimensions=dimensions)

    def test_exact_fields_and_outer_list_records(self):
        good = region()
        for rows in (L([1]), L([None]), L({'bad': good}), 'not a list', None):
            with self.assertRaises(ValueError):
                self.env['build_elevation_profile'](0, rows, 8, 6, 2)
        for field in ('metres', 'x1'):
            row = packed(region())
            del row[field]
            row['unknown'] = 1
            with self.assertRaises(ValueError):
                self.build([unpacked(row)])
        row = region()
        row['unknown'] = 1
        with self.assertRaises(ValueError):
            self.build([row])

    def test_overlap_rejected_including_shared_edge_equal_height_and_containment(self):
        for other in (region(), region(x1=4, x2=5), region(x1=3, x2=3, y1=3, y2=3)):
            for rows in ((region(), other), (other, region())):
                with self.assertRaisesRegex(ValueError, 'Overlapping'):
                    self.build(rows)
        self.build([region(), region(x1=5, x2=5)])
        self.build([region(), region(z=2)])

    def test_region_cap_and_lookup_against_coordinate_oracle(self):
        rows = [region(x1=x, x2=x, y1=1, y2=1, metres=x) for x in range(1, 257)]
        p = self.build(rows, dimensions=(256, 6, 2))
        self.assertEqual(p.regions.len, 256)
        self.assertEqual(p.at(256, 1, 1), 256)
        with self.assertRaises(ValueError):
            self.build(rows + [region(z=2)], dimensions=(256, 6, 2))
        rng = random.Random(223)
        rng.shuffle(rows)
        p = self.build(rows, default=-1, dimensions=(256, 6, 2))
        for _ in range(500):
            x, y, z = rng.randint(1, 256), rng.randint(1, 6), rng.randint(1, 2)
            self.assertEqual(p.at(x, y, z), x if y == 1 and z == 1 else -1)

    def test_author_and_snapshot_rows_are_detached_and_cache_is_reused(self):
        e, original = self.env, region()
        m = e['Map'](25, L([original]))
        p = m.effective_elevation_profile()
        original['metres'] = 9999
        m.elevation_default_metres = 77
        self.assertIs(m.effective_elevation_profile(), p)
        self.assertEqual(p.at(3, 3, 1), 1200)
        self.assertEqual(p.at(8, 6, 2), 25)
        snapshot = m.elevation_snapshot()
        snapshot['regions'][1]['metres'] = 8888
        self.assertEqual(p.at(3, 3, 1), 1200)
        self.assertEqual(m.elevation_snapshot()['regions'][1]['metres'], 1200)

    def test_saved_snapshot_overrides_new_defaults_and_legacy_is_flat_zero(self):
        e = self.env
        old_map = e['Map'](-50, L([region(metres=600)]))
        saved = unpacked(json.loads(json.dumps(packed(old_map.elevation_snapshot()))))
        m = e['Map'](8000, L([region(metres=9000)]))
        m.effective_elevation_profile()
        m.restore_elevation_snapshot(L({'elevation': saved}), 8, 6, 2)
        self.assertEqual(m.effective_elevation_profile().at(3, 3, 1), 600)
        self.assertEqual(m.effective_elevation_profile().at(1, 1, 2), -50)
        saved['regions'][1]['metres'] = 999
        self.assertEqual(m.effective_elevation_profile().at(3, 3, 1), 600)
        m.restore_elevation_snapshot(L(), 8, 6, 2)
        self.assertEqual(m.effective_elevation_profile().regions.len, 0)
        self.assertEqual(m.effective_elevation_profile().at(3, 3, 1), 0)
        self.assertEqual(m.elevation_snapshot()['default_metres'], 0)

    def test_invalid_snapshot_rejected_without_replacing_live_cache(self):
        e = self.env
        m = e['Map'](5)
        before = m.effective_elevation_profile()
        good = packed(m.elevation_snapshot())
        bad_values = [None, 1, {}, {**good, 'version': 2}, {**good, 'maxz': 3},
                      {**good, 'unknown': 1}, {**good, 'regions': None},
                      {**good, 'regions': [packed(region(x2=9))]},
                      {**good, 'regions': [packed(region()), packed(region())]}]
        for bad in bad_values:
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                m.restore_elevation_snapshot(L({'elevation': unpacked(bad)}), 8, 6, 2)
            self.assertIs(m.elevation_profile_cache, before)
        self.assertEqual(before.at(1, 1, 1), 5)

    def test_round_v1_v2_disk_json_admission_and_missing_legacy_snapshot(self):
        with tempfile.TemporaryDirectory() as directory:
            fs = Path(directory)
            (fs / 'map_saves').mkdir()
            (fs / 'map_saves/map.txt').write_text('TEST\nepoch\n')
            e = load(filesystem=fs)
            e['map'].ID = 'TEST'
            store = NS(save_validation_maxz=lambda: 2)
            for version in (1, 2):
                marker = f'round-v{version}:test'
                state = e['capture'](store, marker)
                state['metadata'] = hashlib.md5((fs / 'map_saves/map.txt').read_text().encode()).hexdigest()
                state['version'] = version
                if version == 2:
                    state['world_state'] = L({'schema': 1})
                (fs / 'map_saves/save_complete.txt').write_text(marker)
                def write(value):
                    (fs / 'map_saves/round.json').write_text(json.dumps(value))
                good = packed(state)
                write(good)
                self.assertEqual(e['read'](store)['elevation']['default_metres'], 0)
                legacy = {k: v for k, v in good.items() if k != 'elevation'}
                write(legacy)
                self.assertNotIn('elevation', e['read'](store))
                for elevation in (None, {}, {**good['elevation'], 'maxz': 3},
                                  {**good['elevation'], 'regions': [packed(region()), packed(region())]}):
                    write({**good, 'elevation': elevation})
                    with self.assertRaises(ValueError):
                        e['read'](store)
                write({**legacy, 'unknown': 1})
                with self.assertRaises(ValueError):
                    e['read'](store)
                # The same rejection oracle detects removal of preflight validation.
                write({**good, 'elevation': None})
                mutant = SOURCE.read_text().replace('if(has_elevation)\n', 'if(FALSE)\n', 1)
                unsafe = load(mutant, filesystem=fs)
                unsafe['map'].ID = 'TEST'
                with self.assertRaises(AssertionError):
                    with self.assertRaises(ValueError):
                        unsafe['read'](store)

    def test_lifecycle_wiring_before_mutation_and_constructor_callbacks(self):
        source = SOURCE.read_text()
        loading = (ROOT / 'code/modules/persistence/loading.dm').read_text()
        save = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        preflight = body(loading, '/map_storage/proc/validate_world_save()')
        loadmap = body(source, '/datum/controller/gameticker/proc/loadmap(datum/persistence_restart_transaction/transaction)')
        self.assertLess(preflight.index('read_round_state()'), preflight.index('prepare_saved_roof_areas('))
        self.assertLess(loadmap.index('read_round_state()'), loadmap.index('operation.mutation_started = TRUE'))
        self.assertLess(loadmap.index('map.restore_elevation_snapshot('), loadmap.index('map_storage.ClearMap()'))
        self.assertLess(loadmap.index('map.restore_elevation_snapshot('), loadmap.index('run_world_operation("load"'))
        self.assertLess(save.index('capture_round_state(generation)'), save.index('fdel("map_saves/save_complete.txt")'))
        block = source[source.index('// Geographic metres'):source.index('// Custom persistence iterates vars')]
        self.assertNotIn('in world', block)
        self.assertNotIn('get_area(', block)
        self.assertNotIn('climate', body(source, '/proc/get_elevation(atom/location)'))
        self.assertIn('return key == "elevation_profile_cache" || ..()', block)

    def test_temperature_precipitation_turf_and_maps_unchanged_from_base(self):
        base = 'fa363b8a01ed7d936c10a6303ce1be4c26d82ab0'
        for path in ('code/modules/1713/weather.dm', 'code/game/turfs/turf_changing.dm',
                     'code/modules/persistence/durable_contract.dm'):
            original = subprocess.check_output(['git', 'show', f'{base}:{path}'], cwd=ROOT).decode()
            self.assertEqual((ROOT / path).read_text(), original.replace('\r\n', '\n'))
        self.assertEqual(subprocess.check_output(['git', 'diff', '--name-only', base, '--', 'maps'], cwd=ROOT), b'')

    def test_negative_controls_detect_overlap_alias_legacy_and_unknown_statements(self):
        source = SOURCE.read_text()
        overlap = source.replace('row["z"] == other["z"] &&', 'FALSE &&', 1)
        e = load(overlap)
        p = e['build_elevation_profile'](0, L([region(), region()]), 8, 6, 2)
        self.assertEqual(p.regions.len, 2)  # The rejection oracle would fail.
        e = load(source.replace('list(row.Copy())', 'list(row)', 1))
        row = region()
        p = e['build_elevation_profile'](0, L([row]), 8, 6, 2)
        row['metres'] = 99
        self.assertNotEqual(p.at(3, 3, 1), 1200)
        e = load(source.replace('profile = build_elevation_profile(0, list(), maxx, maxy, maxz)',
                                'profile = build_elevation_profile(elevation_default_metres, list(), maxx, maxy, maxz)', 1))
        m = e['Map'](6000)
        m.restore_elevation_snapshot(L(), 8, 6, 2)
        self.assertNotEqual(m.effective_elevation_profile().at(1, 1, 1), 0)
        # An unknown source statement must fail closed, not disappear from projection.
        with self.assertRaisesRegex(ValueError, 'Unknown production statement'):
            load(source.replace('return profile.at(T.x, T.y, T.z)', 'world.maxz++', 1))

    def test_native_preparation_hashes_sources_and_never_executes_them(self):
        path = Path(__file__).with_name('prepare.py')
        spec = importlib.util.spec_from_file_location('prepare_elevation_fixture', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'prepared'
            receipt = module.prepare(output)
            self.assertTrue(receipt['prepared_only'])
            self.assertFalse(receipt['native_executed'])
            self.assertEqual(receipt['source_sha256']['code/modules/persistence/functions.dm'],
                             hashlib.sha256(SOURCE.read_bytes()).hexdigest())
            self.assertEqual((output / 'functions.dm').read_bytes(), SOURCE.read_bytes())
            self.assertIn('#define get_turf(A) get_step(A,0)', (output / 'stubs.dm').read_text())
            self.assertNotIn('/proc/get_turf(atom/A)', (output / 'stubs.dm').read_text())
            self.assertIn('#include "functions.dm"', (output / 'elevation.dme').read_text())
            self.assertFalse(list(output.glob('*.dmb')))
            self.assertFalse((output / 'elevation-result.json').exists())
            self.assertNotIn('subprocess', path.read_text())
            with self.assertRaisesRegex(ValueError, 'new directory'):
                module.prepare(output)
            for name, digest in receipt['generated_sha256'].items():
                self.assertEqual(hashlib.sha256((output / name).read_bytes()).hexdigest(), digest)


if __name__ == '__main__':
    unittest.main()
