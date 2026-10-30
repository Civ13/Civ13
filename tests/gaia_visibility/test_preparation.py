"""Exercise preparation against a tiny immutable repository, never BYOND."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('gaia_visibility_prepare', HERE / 'prepare.py')
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        subprocess.run(['git', 'init', '-q', str(self.repo)], check=True)
        inputs = {
            'tests/gaia_visibility/prepare.py': (HERE / 'prepare.py').read_bytes(),
            'tests/gaia_visibility/isolation.py': (HERE / 'isolation.py').read_bytes(),
            'tests/gaia_visibility/bootstrap.dm': (HERE / 'bootstrap.dm').read_bytes(),
            'tests/gaia_visibility/fixture.dm': (HERE / 'fixture.dm').read_bytes(),
            'civ13.dme': b'#include "code/dependency.dm"\n// BEGIN_SELECTED_MAP\n#include "old.dmm"\n// END_SELECTED_MAP\n',
            'code/dependency.dm': b'// full dependency retained\n',
            'code/modules/visibility/root_light_snapshot.dm': b'/proc/root_light_rgb(turf/root, mob/viewer)\n\treturn null\n',
            'code/modules/visibility/root_tree_presenter.dm': b'\tI.pixel_x = 0\n',
            'tools/byond/version.json': b'{"version":"516.1688"}',
        }
        for name, guards in prepare.isolation.GUARDS.items():
            inputs[name] = ''.join(signature + '\n\treturn \"original unreachable\"\n' for signature, _ in guards).encode()
        for name, data in inputs.items():
            path = self.repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        self.commit()

    def tearDown(self):
        self.temp.cleanup()

    def commit(self):
        subprocess.run(['git', '-C', str(self.repo), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(self.repo), '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', '-c', 'commit.gpgsign=false', 'commit', '-qm', 'fixture'], check=True)
        self.head = prepare.git(self.repo, 'rev-parse', 'HEAD').decode().strip()

    def stage(self, name='out', control=None):
        return prepare.prepare(self.root / name, self.head, repo=self.repo, control=control)

    def test_full_dependencies_exact_commit_and_no_execution(self):
        (self.repo / 'code/dependency.dm').write_text('dirty not admitted')
        manifest = self.stage()
        self.assertEqual((self.root / 'out/code/dependency.dm').read_bytes(), b'// full dependency retained\n')
        self.assertFalse(manifest['executed'])
        self.assertFalse(manifest['compiled'])
        self.assertFalse(manifest['client_pixel_evidence'])
        self.assertEqual(manifest['head'], self.head)
        self.assertEqual(manifest['scene']['real_clients_required'], 3)
        dme = (self.root / 'out/gaia_visibility.dme').read_text()
        self.assertNotIn('old.dmm', dme)
        self.assertIn('code/dependency.dm', dme)
        self.assertIn('tests/gaia_visibility/fixture.dm', dme)

    def test_guarded_bootstrap_and_empty_owned_runtime(self):
        self.stage()
        root = self.root / 'out'
        source = (root / 'code/world.dm').read_text()
        self.assertIn('/datum/global_init/New()\n\treturn gaia_visibility_global_init()', source)
        self.assertIn('/world/New()\n\treturn gaia_visibility_start()', source)
        self.assertIn('bootstrap.dm', (root / 'gaia_visibility.dme').read_text())
        for folder in ('config', 'data', 'map_saves', 'SQL', 'logs'):
            self.assertEqual(list((root / 'owned-runtime' / folder).iterdir()), [])

    def test_large_asset_streams_without_source_size_limit(self):
        asset = self.repo / 'icons/large-asset.bin'
        asset.parent.mkdir()
        with asset.open('wb') as stream:
            for _ in range(9):
                stream.write(b'x' * (1024 * 1024))
        self.commit()
        manifest = self.stage()
        self.assertEqual((self.root / 'out/icons/large-asset.bin').stat().st_size, 9 * 1024 * 1024)
        self.assertEqual(manifest['files']['icons/large-asset.bin']['original_sha256'], manifest['files']['icons/large-asset.bin']['prepared_sha256'])

    def test_scene_has_two_full_levels_and_twelve_roots_each(self):
        text = prepare.scene().decode()
        levels = text.split('= {"\n')[1:]
        self.assertEqual(len(levels), 2)
        for level in levels:
            rows = level.split('\n"}')[0].splitlines()
            self.assertEqual(len(rows), 48)
            self.assertTrue(all(len(row) == 48 for row in rows))
            self.assertEqual(sum(row.count(ch) for row in rows for ch in 'tpsjl'), 12)
        self.assertIn('/obj/roof', text)
        self.assertIn('/obj/structure/simple_door', text)

    def test_controls_are_declared_exact_mutations(self):
        for control in prepare.CONTROLS:
            manifest = self.stage(control, control)
            self.assertEqual(manifest['control'], control)
            changed = [name for name, hashes in manifest['files'].items() if hashes['original_sha256'] and hashes['original_sha256'] != hashes['prepared_sha256']]
            self.assertEqual(len(changed), len(prepare.isolation.GUARDS) + (0 if control == 'native-los' else 1))

    def test_refuses_mutable_ref_existing_output_and_tool_drift(self):
        with self.assertRaises(ValueError):
            prepare.prepare(self.root / 'bad', 'HEAD', repo=self.repo)
        self.stage()
        with self.assertRaises(FileExistsError):
            self.stage()
        (self.repo / prepare.SELF).write_text('different staging tool')
        self.commit()
        with self.assertRaisesRegex(ValueError, 'exact candidate'):
            self.stage('drift')

    def test_control_anchor_drift_is_not_silently_accepted(self):
        path = self.repo / 'code/modules/visibility/root_tree_presenter.dm'
        path.write_text('changed implementation')
        self.commit()
        with self.assertRaisesRegex(ValueError, 'anchor drift'):
            self.stage('bad-control', 'double-offset')
        self.assertFalse((self.root / 'bad-control').exists())

    def test_manifest_hashes_every_prepared_file(self):
        manifest = self.stage()
        for name, hashes in manifest['files'].items():
            self.assertEqual(hashes['prepared_sha256'], prepare.sha((self.root / 'out' / name).read_bytes()))
        saved = json.loads((self.root / 'out/gaia-visibility-manifest.json').read_text())
        self.assertEqual(manifest, saved)


if __name__ == '__main__':
    unittest.main()
