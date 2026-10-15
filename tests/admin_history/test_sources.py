"""Pure preparation checks: no native compiler, daemon or production state."""
import hashlib
import tempfile
from pathlib import Path
import unittest

from run import CONTROLS, prepare, replace_once


class SourcePreparation(unittest.TestCase):
    def test_production_and_controls_prepare(self):
        with tempfile.TemporaryDirectory() as directory:
            for control in (None, *CONTROLS):
                with self.subTest(control=control):
                    output = Path(directory) / (control or 'positive')
                    metadata = prepare(output, control)
                    source = (output / 'history.dm').read_text()
                    self.assertEqual(metadata['control'], control)
                    for name, digest in metadata['compiled_sha256'].items():
                        self.assertEqual(hashlib.sha256((output / name).read_bytes()).hexdigest(), digest)
                    self.assertIn('admin_log.Add(text)', source)
                    self.assertIn('game_log("ADMIN", text)', source)
                    self.assertIn('history_probe_write(payload, diary)', source)
                    self.assertNotIn('/proc/log_discord(', source)
                    self.assertIn('if (!.)', (output / 'view.dm').read_text())

    def test_ambiguous_or_missing_adapters_rejected(self):
        for source in ('missing', 'anchor anchor'):
            with self.subTest(source=source), self.assertRaises(ValueError):
                replace_once(source, 'anchor', 'changed')


if __name__ == '__main__':
    unittest.main()
