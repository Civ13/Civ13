"""Tiny offline package fixtures. No compiler, client, daemon or game is run."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/opendream/verify-client-package.py'
spec = importlib.util.spec_from_file_location('client_package', SCRIPT)
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


class ClientPackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.files = {}
        for name in [package.LOADER, 'Resources/manifest.yml', 'RobustToolbox/Resources/test.yml',
                     'bin/Content.Client/OpenDreamClient.dll', 'bin/Content.Client/OpenDreamShared.dll',
                     'auth-webview/Robust.Client.WebView.dll']:
            path = self.root / 'standalone' / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'fixture')
            self.files[name] = {'bytes': 7, 'sha256': hashlib.sha256(b'fixture').hexdigest()}
        self.layout = {'schema': 1, 'loader': package.LOADER, 'webview': 'auth-webview', 'files': self.files}
        self.receipt = {'engine_head': package.ENGINE_HEAD, 'robust_head': package.ROBUST_HEAD,
                        'build': 'passed', 'standalone_layout': self.layout,
                        'standalone_startup': {'sandboxed_headless_startup': 'passed'}}
        self.write()

    def write(self):
        (self.root / 'receipt.json').write_text(json.dumps(self.receipt), encoding='utf-8')
        (self.root / 'standalone-layout.json').write_text(json.dumps(self.layout), encoding='utf-8')

    def test_complete_package(self):
        result = package.verify(self.root)
        self.assertEqual(result['root'], str(self.root / 'standalone'))

    def test_stage_isolated_and_verified(self):
        result = package.stage(self.root, self.root / 'runtime')
        staged = Path(result['staging_root'])
        self.assertEqual(staged.parent, self.root / 'runtime')
        package.verify(staged)
        (Path(result['root']) / 'user_data').mkdir()
        (Path(result['root']) / 'user_data/settings').write_bytes(b'runtime')
        package.verify(self.root)

    def test_stage_failure_cleans_owned_directory(self):
        from unittest.mock import patch
        original = package.verify
        calls = 0
        def changed(path):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise ValueError('copied input changed')
            return original(path)
        parent = self.root / 'runtime'
        with patch.object(package, 'verify', side_effect=changed):
            with self.assertRaisesRegex(ValueError, 'copied input changed'):
                package.stage(self.root, parent)
        self.assertEqual(list(parent.iterdir()), [])

    def test_same_length_assembly_mutation(self):
        (self.root / 'standalone/bin/Content.Client/OpenDreamShared.dll').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'altered'):
            package.verify(self.root)

    def test_missing_engine_resource(self):
        (self.root / 'standalone/RobustToolbox/Resources/test.yml').unlink()
        with self.assertRaisesRegex(ValueError, 'incomplete'):
            package.verify(self.root)

    def test_added_user_data(self):
        (self.root / 'standalone/user_data').mkdir()
        (self.root / 'standalone/user_data/config.toml').write_bytes(b'injected')
        with self.assertRaisesRegex(ValueError, 'Unexpected'):
            package.verify(self.root)

    def test_wrong_head_or_unrun_startup(self):
        for field, value in [('engine_head', '0' * 40), ('standalone_startup', {})]:
            previous = self.receipt[field]
            self.receipt[field] = value
            self.write()
            with self.assertRaisesRegex(ValueError, 'exact-head'):
                package.verify(self.root)
            self.receipt[field] = previous

    def test_mismatched_metadata(self):
        (self.root / 'standalone-layout.json').write_text('{}', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'coherent receipt'):
            package.verify(self.root)

    def test_traversal_and_case_collision(self):
        for name in ['../external.dll', 'Resources/./test', 'resources/MANIFEST.yml']:
            self.files[name] = {'bytes': 7, 'sha256': hashlib.sha256(b'fixture').hexdigest()}
            self.write()
            with self.assertRaisesRegex(ValueError, 'inventory entry'):
                package.verify(self.root)
            del self.files[name]

    def test_native_hash_and_unbound_rsc(self):
        native = self.root / 'native'
        native.mkdir()
        (native / 'DreamDaemon.exe').write_bytes(b'fake exe')
        (native / 'bridge.dmb').write_bytes(b'fixture')
        manifest = {'schema': 1, 'byond_version': '516.1681', 'source_commit': package.ENGINE_HEAD, 'files': {
            'bridge.dmb': hashlib.sha256(b'fixture').hexdigest(), 'bridge.rsc': None}}
        (native / 'native-observer.json').write_text(json.dumps(manifest), encoding='utf-8')
        package.verify_native(native, native)
        manifest['source_commit'] = '0' * 40
        (native / 'native-observer.json').write_text(json.dumps(manifest), encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'Unsupported'):
            package.verify_native(native, native)
        manifest['source_commit'] = package.ENGINE_HEAD
        (native / 'native-observer.json').write_text(json.dumps(manifest), encoding='utf-8')
        (native / 'bridge.rsc').write_bytes(b'unbound')
        with self.assertRaisesRegex(ValueError, 'Unbound'):
            package.verify_native(native, native)
        (native / 'bridge.rsc').unlink()
        (native / 'bridge.dmb').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'differs'):
            package.verify_native(native, native)


if __name__ == '__main__':
    unittest.main()
