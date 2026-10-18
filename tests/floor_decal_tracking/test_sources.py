"""Offline preparation/causality guards, never a Python model of DM behavior."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('decal_prepare', HERE / 'prepare.py')
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


class SourceTests(unittest.TestCase):
    def test_fixture_anchored_matches_production_owner_and_default(self):
        production = (p.ROOT / 'code/game/atoms_movable.dm').read_text()
        fixture = (HERE / 'probe.dm').read_text()
        self.assertTrue(production.startswith('/atom/movable\n'))
        self.assertIn('\tvar/anchored = FALSE\n', production.split('\n\n', 1)[0])
        self.assertIn('/atom/movable\n\tvar/anchored = FALSE\n', fixture)

    def test_exact_writer_and_season_reader(self):
        files, _ = p.sources()
        original = (p.ROOT / p.DECAL).read_text().split('/obj/effect/floor_decal/ex_act(severity)\n')[0]
        self.assertEqual(files['decal.dm'], original)
        writer = files['decal.dm']
        self.assertEqual(writer.count(p.GUARD), 1)
        self.assertIn(p.GUARD + '\t\tT.floor_decal_cache_keys |= cache_key', writer)
        self.assertIn('for (var/cache_key in G.floor_decal_cache_keys)', files['seasonal.dm'])
        self.assertIn('G.season != "SPRING" && G.uses_winter_overlay', files['seasonal.dm'])

    def test_controls_change_only_target_allocation(self):
        fixed, hashes = p.sources()
        for case in p.CASES[1:]:
            changed, actual_hashes = p.sources(case=case)
            self.assertEqual(hashes, actual_hashes)
            self.assertEqual(set(changed), set(fixed))
            self.assertEqual([key for key in fixed if fixed[key] != changed[key]], ['decal.dm'])
        eager, _ = p.sources(case='eager')
        self.assertEqual(eager['decal.dm'], fixed['decal.dm'].replace(
            p.DECLARATION, p.DECLARATION.rstrip() + ' = list()\n'))
        missing, _ = p.sources(case='missing-lazy')
        self.assertEqual(missing['decal.dm'], fixed['decal.dm'].replace(p.GUARD, ''))

    def test_freezes_all_includes_and_resources_with_hashes(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / 'packet'
            result = p.prepare(output)
            self.assertFalse(result['native_executed'])
            self.assertFalse(result['compiler_executed'])
            self.assertEqual(set(result['cases']), set(p.CASES))
            for case, files in result['cases'].items():
                for name, digest in files.items():
                    self.assertEqual(hashlib.sha256((output / case / name).read_bytes()).hexdigest(), digest)
                environment = (output / case / 'probe.dme').read_text()
                self.assertNotIn('#include "../', environment)
                self.assertIn((output / case).as_posix(), environment)
                self.assertIn('source/code/modules/persistence/saving.dm', environment)
                self.assertIn('source/code/modules/persistence/loading.dm', environment)
                self.assertIn('icons/turf/flooring/decals.dmi', files)
            for name, digest in result['source_sha256'].items():
                self.assertEqual(hashlib.sha256((p.ROOT / name).read_bytes()).hexdigest(), digest)
            self.assertEqual(json.loads((output / 'manifest.json').read_text()), result)
            with self.assertRaises(FileExistsError):
                p.prepare(output)

    def test_changed_guard_rejects_preparation(self):
        original = Path.read_bytes
        def changed(path):
            value = original(path)
            if path == p.ROOT / p.DECAL:
                value = value.replace(p.GUARD.encode(), b'', 1)
            return value
        with patch.object(Path, 'read_bytes', changed):
            with self.assertRaisesRegex(ValueError, 'Lazy production anchors'):
                p.sources()

    def test_changed_season_boundary_rejects_preparation(self):
        original = Path.read_bytes
        # Use the exact reader anchor, not an unrelated earlier season branch.
        def reader_changed(path):
            value = original(path)
            if path == p.ROOT / p.SEASONS:
                value = value.replace(b'G.season != "SPRING" && G.uses_winter_overlay', b'FALSE', 1)
            return value
        with patch.object(Path, 'read_bytes', reader_changed):
            with self.assertRaisesRegex(ValueError, 'Seasonal production anchors'):
                p.sources()

    def test_complete_caller_inventory_and_no_serializer_edit(self):
        callers = []
        for path in (p.ROOT / 'code').rglob('*.dm'):
            if 'floor_decal_cache_keys' in path.read_text(encoding='utf-8', errors='replace'):
                callers.append(path.relative_to(p.ROOT).as_posix())
        self.assertEqual(sorted(callers), sorted([p.DECAL, p.SEASONS]))
        files, _ = p.sources()
        for name in ('functions.dm', 'saving.dm', 'loading.dm'):
            key = 'source/code/modules/persistence/' + name
            self.assertEqual(files[key], (p.ROOT / key.removeprefix('source/')).read_text())


if __name__ == '__main__':
    unittest.main()
