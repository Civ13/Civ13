"""Runs the Edge translator service's offline Node tests (detector and HTTP
service with a stand-in for Edge): tools/edge-translator/test/test.js."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]


class EdgeTranslatorService(unittest.TestCase):
    def test_node_suite(self):
        node = shutil.which('node')
        if not node:
            self.skipTest('node is not installed')
        result = subprocess.run([node, str(ROOT / 'tools/edge-translator/test/test.js')], capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('edge translator: all checks passed', result.stdout)

    def test_dependency_pinned(self):
        import json
        package = json.loads((ROOT / 'tools/edge-translator/package.json').read_text(encoding='utf-8'))
        lock = json.loads((ROOT / 'tools/edge-translator/package-lock.json').read_text(encoding='utf-8'))
        self.assertEqual(package['dependencies'], {'playwright-core': lock['packages']['node_modules/playwright-core']['version']})


if __name__ == '__main__':
    unittest.main()
