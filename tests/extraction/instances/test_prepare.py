"""Offline packaging checks only. DM behavior requires a later native grant."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import prepare


class PrepareTests(unittest.TestCase):
    def test_production_bytes_and_input_hashes(self):
        with tempfile.TemporaryDirectory() as root:
            output = Path(root) / 'packet'
            manifest = prepare.prepare(output)
            self.assertFalse(manifest['native_executed'])
            self.assertEqual((output / 'instances.dm').read_bytes(), prepare.SOURCE.read_bytes())
            for name, digest in manifest['inputs'].items():
                self.assertEqual(hashlib.sha256((output / name).read_bytes()).hexdigest(), digest)
            self.assertEqual(json.loads((output / 'manifest.json').read_text()), manifest)

    def test_only_include_is_adapted(self):
        with tempfile.TemporaryDirectory() as root:
            output = Path(root) / 'packet'
            prepare.prepare(output)
            expected = prepare.PROBE.read_text().replace(prepare.INCLUDE, '#include "instances.dm"')
            self.assertEqual((output / 'probe.dme').read_text(), expected)

    def test_existing_output_preserved(self):
        with tempfile.TemporaryDirectory() as root:
            output = Path(root) / 'packet'
            prepare.prepare(output)
            before = {p.name: p.read_bytes() for p in output.iterdir()}
            with self.assertRaises(FileExistsError):
                prepare.prepare(output)
            self.assertEqual(before, {p.name: p.read_bytes() for p in output.iterdir()})


if __name__ == '__main__':
    unittest.main()
