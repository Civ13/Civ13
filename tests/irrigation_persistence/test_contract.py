"""Offline source contracts and JSON round trips, not native restoration tests."""
from copy import deepcopy
from hashlib import sha1
from itertools import product
import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

from source_adapter import ROOT, DMList, FileEntry, admitted_fields, export_channel, procedure, validator

MANIFEST = json.loads(Path(__file__).with_name('baseline.json').read_text())
BASE = MANIFEST['upstream_commit']
available = subprocess.run(['git', 'cat-file', '-e', f'{BASE}:code/modules/1713/trench.dm'],
                           cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
if available.returncode:
    raise RuntimeError('Fetch the immutable upstream baseline before running these source contracts')
PATH = 'code/modules/1713/trench.dm'
SOURCE = (ROOT / PATH).read_text(encoding='utf-8')
LOADING = (ROOT / 'code/modules/persistence/loading.dm').read_text(encoding='utf-8')
BEFORE = subprocess.check_output(['git', 'show', f'{BASE}:{PATH}'], cwd=ROOT).decode()
CHECK = validator(SOURCE)
STATES = ((1, 0, 0), (1, 1, 0), (1, 1, 1))


def envelope(value):
    return {'kind': 'value', 'value': value}


class SourceBaseline(unittest.TestCase):
    def test_exact_upstream_blobs(self):
        for entry in MANIFEST['files']:
            data = subprocess.check_output(['git', 'show', f"{BASE}:{entry['path']}"], cwd=ROOT)
            self.assertEqual(sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest(), entry['blob_sha'])

    def test_baseline_admission_gap_is_source_only(self):
        self.assertEqual(admitted_fields(BEFORE), ())
        row = export_channel(BEFORE, (1, 1, 1), name='flooded saltwater irrigation channel')
        self.assertNotIn('irrigation', row)
        self.assertNotIn('flooded', row)
        self.assertNotIn('salty', row)
        with self.assertRaisesRegex(ValueError, 'Legacy named'):
            CHECK(FileEntry(row), 2)

    def test_existing_native_fixture_is_not_ordinary_irrigation(self):
        baseline = subprocess.check_output(['git', 'show', f'{BASE}:tests/trench_save/probe.dm'], cwd=ROOT).decode()
        self.assertIn('new /turf/floor/trench/flooded/salty', baseline)
        self.assertNotIn('.irrigate(', baseline)


class ScalarContract(unittest.TestCase):
    def test_real_scalar_encoder_contract(self):
        source = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        self.assertIn('return list("kind" = "value", "value" = value)', source)
        self.assertIn('var/list/changing_vars = A.get_saved_vars()', source)
        self.assertIn('for(var/v in changing_vars)', source)

    def test_valid_channel_disk_round_trips(self):
        self.assertEqual(set(admitted_fields(SOURCE)), {'irrigation_save_version', 'irrigation', 'flooded', 'salty'})
        with tempfile.TemporaryDirectory(prefix='irrigation-offline-') as folder:
            target = Path(folder) / 'abstract-entries.json'
            for bits in STATES:
                row = export_channel(SOURCE, bits)
                target.write_text(json.dumps(row), encoding='utf-8')
                loaded = FileEntry(json.loads(target.read_text(encoding='utf-8')))
                self.assertTrue(CHECK(loaded, 2))
                self.assertEqual(tuple(loaded[key]['value'] for key in ('irrigation', 'flooded', 'salty')), bits)
                # Zero-valued dry/fresh flags must be written, not truthiness-filtered.
                self.assertIn('salty', loaded)
                self.assertIn('flooded', loaded)

    def test_missing_and_wrong_typed_fields(self):
        for field in admitted_fields(SOURCE):
            row = export_channel(SOURCE, (1, 1, 1))
            del row[field]
            with self.subTest(field=field), self.assertRaises(ValueError):
                CHECK(FileEntry(row), 2)
            for value in (None, '1', [], {}, -1, 2, 0.5):
                row = export_channel(SOURCE, (1, 1, 1))
                row[field] = envelope(value)
                with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                    CHECK(FileEntry(row), 2)

    def test_envelopes_never_decode_graph_references(self):
        for value in (1, None, DMList([1, 2]), {'kind': 'entry', 'ref': 17},
                      {'kind': 'list', 'ref': 1}, {'kind': 'value'},
                      {'kind': 'value', 'value': 1, 'extra': 3}):
            row = export_channel(SOURCE, (1, 1, 1))
            row['salty'] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                CHECK(FileEntry(row), 2)

    def test_invalid_bit_combinations_and_schema(self):
        for bits in product((0, 1), repeat=3):
            row = export_channel(SOURCE, (1, 1, 1))
            row.update({key: envelope(value) for key, value in zip(('irrigation', 'flooded', 'salty'), bits)})
            if bits in STATES:
                self.assertTrue(CHECK(FileEntry(row), 2))
            else:
                with self.assertRaises(ValueError):
                    CHECK(FileEntry(row), 2)
        row = export_channel(SOURCE, (1, 1, 1))
        row['irrigation_save_version'] = envelope(2)
        with self.assertRaisesRegex(ValueError, 'Unsupported'):
            CHECK(FileEntry(row), 2)

    def test_legacy_is_not_silently_migrated(self):
        for name in ('irrigation channel', 'flooded irrigation channel', 'flooded saltwater irrigation channel'):
            for version in (0, 2):
                row = {'name': envelope(name) if version == 2 else name}
                with self.assertRaisesRegex(ValueError, 'Legacy named'):
                    CHECK(FileEntry(row), version)
        for field in ('irrigation', 'irrigation_overlay'):
            for value in (0, 1, None):
                with self.assertRaisesRegex(ValueError, 'Unversioned'):
                    CHECK(FileEntry({field: envelope(value)}), 2)
        # Native non-channel source fields belong to their existing subtype path.
        self.assertTrue(CHECK(FileEntry({'name': envelope('flooded trench'), 'flooded': envelope(1), 'salty': envelope(1)}), 2))
        self.assertTrue(CHECK(FileEntry({'name': envelope('ordinary custom name')}), 2))

    def test_rejection_is_read_only(self):
        row = FileEntry(export_channel(SOURCE, (1, 1, 1)))
        row['salty'] = envelope('not a number')
        before = deepcopy(row)
        with self.assertRaises(ValueError):
            CHECK(row, 2)
        self.assertEqual(row, before)

    def test_mutation_controls(self):
        cases = [
            ('schema', 'schema != 1', 'schema != 2', export_channel(SOURCE, (1, 1, 1))),
            ('salt', '(salt && !wet)', 'FALSE', {**export_channel(SOURCE, (1, 1, 1)), 'flooded': envelope(0)}),
        ]
        for label, before, after, row in cases:
            mutated = validator(SOURCE.replace(before, after, 1))
            if label == 'schema':
                with self.assertRaises(ValueError):
                    mutated(FileEntry(row), 2)  # Previously valid schema now fails.
            else:
                self.assertTrue(mutated(FileEntry(row), 2))  # Bad dry-salt now accepted: control detected.
        dropped = SOURCE.replace('"irrigation_save_version", "irrigation", "flooded", "salty"',
                                 '"irrigation_save_version", "irrigation", "flooded"', 1)
        with self.assertRaises(ValueError):
            CHECK(FileEntry(export_channel(dropped, (1, 1, 1))), 2)


class HookScope(unittest.TestCase):
    def test_preflight_placement_and_decode_reset(self):
        validation = procedure(LOADING, '/map_storage/proc/validate_world_save(')
        self.assertIn('if(ispath(type, /turf/floor))\n\t\t\t\t\t\tvalidate_saved_irrigation(F, version)', validation)
        reset = LOADING.index('restored_floor.irrigation_prepare_load()')
        self.assertLess(reset, LOADING.index('for(var/v in savefile.dir)'))
        functions = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        start = functions.index('/map_storage/proc/import_saved_world(') if '/map_storage/proc/import_saved_world(' in functions else functions.index('if(!map_storage.prepare_saved_dimensions()')
        self.assertLess(functions.index('map_storage.validate_world_save()', start), functions.index('map_storage.ClearMap()', start))

    def test_same_type_reset_uses_native_defaults(self):
        body = procedure(SOURCE, '/turf/floor/proc/irrigation_prepare_load()')
        for field in ('irrigation', 'flooded', 'salty', 'irrigation_save_version'):
            self.assertIn(f'{field} = initial({field})', body)
        self.assertIn('overlays -= irrigation_overlay', body)
        self.assertNotIn('check_relatives(', body)

    def test_overlay_is_derived_and_does_not_propagate(self):
        body = procedure(SOURCE, '/turf/floor/proc/irrigation_restore_overlay()')
        for forbidden in ('expand_flood(', 'check_relatives(', 'growth(', 'spawn(', 'sleep(', 'new /', 'flooded =', 'salty =', 'update_icon()'):
            self.assertNotIn(forbidden, body)
        self.assertIn('for (var/checkdir in cardinal)', body)
        self.assertIn('layer = src.layer + 0.01', body)
        self.assertIn('key == "irrigation_overlay" || ..()', SOURCE)
        self.assertIn('/turf/floor/proc/irrigation_after_load()', SOURCE)
        self.assertIn('overlays += irrigation_overlay', body)

    def test_floor_after_load_keeps_snow_and_irrigation(self):
        owners = []
        for path in (ROOT / 'code').rglob('*.dm'):
            if re.search(r'^/turf/floor/after_load\(\)\s*$', path.read_text(encoding='utf-8-sig'), re.M):
                owners.append(path.relative_to(ROOT).as_posix())
        self.assertEqual(owners, ['code/modules/1713/snowfall_ground.dm'])
        path = owners[0]
        current = (ROOT / path).read_text(encoding='utf-8')
        baseline = subprocess.check_output(['git', 'show', f'{BASE}:{path}'], cwd=ROOT).decode()
        self.assertEqual(current, baseline)
        self.assertTrue(procedure(current, '/turf/floor/after_load()').lstrip().startswith('/turf/floor/after_load()\n\t..()'))
        parent = procedure(SOURCE, '/turf/after_load()')
        self.assertIn('if (istype(src, /turf/floor))', parent)
        self.assertIn('F.irrigation_after_load()', parent)

    def test_existing_water_gameplay_unchanged(self):
        # After removing the single new admission/helper block and metadata var,
        # the complete production irrigation file is exactly the upstream blob.
        begin = SOURCE.index('\t// Entry-local metadata:')
        end = SOURCE.index('/turf/floor/update_icon()', begin)
        self.assertEqual(SOURCE[:begin] + '\n' + SOURCE[end:], BEFORE)
        old_load = subprocess.check_output(['git', 'show', f'{BASE}:code/modules/persistence/loading.dm'], cwd=ROOT).decode()
        reset = '\t\t\tif (istype(restored_turf, /turf/floor))\n\t\t\t\tvar/turf/floor/restored_floor = restored_turf\n\t\t\t\trestored_floor.irrigation_prepare_load()\n'
        preflight = '\t\t\t\t\tif(ispath(type, /turf/floor))\n\t\t\t\t\t\tvalidate_saved_irrigation(F, version)\n'
        self.assertEqual(LOADING.replace(reset, '', 1).replace(preflight, '', 1), old_load)


if __name__ == '__main__':
    unittest.main()
