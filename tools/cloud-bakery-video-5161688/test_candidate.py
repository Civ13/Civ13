"""Offline verification of held switches and package-tree guards."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
BASE = HERE.parent / 'city-route-preflight-held-v4-20261030' / 'controller'
sys.path.insert(0, str(BASE))
sys.path.insert(0, str(HERE))
import directx_official_setup as directx
import encoder_proof as encoder
import verify_directx_extracted as dx_tree
import verify_portable_tree as ff_tree


class HeldSwitches(unittest.TestCase):
    def test_installer_cannot_run_when_held(self):
        with patch.object(directx, 'OFFICIAL_INSTALL_ENABLED', False), \
             patch.object(directx, 'binding', side_effect=AssertionError('unexpected binding')):
            with self.assertRaisesRegex(RuntimeError, 'official_install_disabled'):
                directx.run('unused', 'unused', accept_terms=True)

    def test_encoder_cannot_run_when_held(self):
        with patch.object(encoder, 'ENCODER_PROOF_ENABLED', False), \
             patch.object(encoder, 'binding', side_effect=AssertionError('unexpected binding')):
            with self.assertRaisesRegex(RuntimeError, 'encoder_proof_disabled'):
                encoder.run('unused')


class TreeChecks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def populate(self, count):
        rows = []
        for index in range(count):
            name = f'file{index}.bin'
            (self.root / name).write_bytes(b'x')
            rows.append({'name': name, 'bytes': 1, 'sha256': hashlib.sha256(b'x').hexdigest()})
        manifest = self.root.parent / (self.root.name + '-manifest.json')
        manifest.write_text(json.dumps(rows), encoding='utf-8')
        self.addCleanup(manifest.unlink, missing_ok=True)
        return manifest, hashlib.sha256(manifest.read_bytes()).hexdigest()

    def test_directx_valid_and_changed_file_rejected(self):
        manifest, digest = self.populate(157)
        old = dx_tree.MANIFEST_SHA256
        dx_tree.MANIFEST_SHA256 = digest
        self.addCleanup(setattr, dx_tree, 'MANIFEST_SHA256', old)
        self.assertEqual(dx_tree.verify(self.root, manifest)['files'], 157)
        (self.root / 'file1.bin').write_bytes(b'y')
        with self.assertRaisesRegex(ValueError, 'file_hash'):
            dx_tree.verify(self.root, manifest)

    def test_directx_extra_file_rejected(self):
        manifest, digest = self.populate(157)
        old = dx_tree.MANIFEST_SHA256
        dx_tree.MANIFEST_SHA256 = digest
        self.addCleanup(setattr, dx_tree, 'MANIFEST_SHA256', old)
        (self.root / 'unexpected').write_bytes(b'')
        with self.assertRaisesRegex(ValueError, 'file_count'):
            dx_tree.verify(self.root, manifest)

    def test_ffmpeg_valid_and_changed_file_rejected(self):
        manifest, digest = self.populate(224)
        old = ff_tree.MANIFEST_SHA
        ff_tree.MANIFEST_SHA = digest
        self.addCleanup(setattr, ff_tree, 'MANIFEST_SHA', old)
        self.assertEqual(ff_tree.verify(self.root, manifest)['files'], 224)
        (self.root / 'file1.bin').write_bytes(b'y')
        with self.assertRaisesRegex(ValueError, 'file_hash'):
            ff_tree.verify(self.root, manifest)

    def test_ffmpeg_unexpected_file_rejected(self):
        manifest, digest = self.populate(224)
        old = ff_tree.MANIFEST_SHA
        ff_tree.MANIFEST_SHA = digest
        self.addCleanup(setattr, ff_tree, 'MANIFEST_SHA', old)
        (self.root / 'unexpected').write_bytes(b'')
        with self.assertRaisesRegex(ValueError, 'unexpected_file'):
            ff_tree.verify(self.root, manifest)


if __name__ == '__main__':
    unittest.main()
