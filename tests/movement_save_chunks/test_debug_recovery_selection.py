"""Offline CI selection contract; never starts native processes."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / '.github/workflows/moving-save-chunks.yml'


class DebugRecoverySelection(unittest.TestCase):
    def test_pr_filter_selects_debug_recovery_inputs(self):
        text = WORKFLOW.read_text(encoding='utf-8')
        paths = text.split('  pull_request:\n    paths:\n', 1)[1].split('  workflow_dispatch:', 1)[0]
        for name in ('tests/save_debug_fixture/**', 'tests/save_debug_lossy/**',
                     'tests/save_debug_combined/**', 'code/modules/persistence/debug_lossy.dm',
                     'code/modules/persistence/admin.dm', 'code/modules/admin/admin_verbs.dm'):
            self.assertIn("      - '" + name + "'", paths)

    def test_automatic_job_runs_offline_contracts_only(self):
        text = WORKFLOW.read_text(encoding='utf-8')
        isolated = text.split('  isolated-native:\n', 1)[1].split('\n  lighting-interleave:', 1)[0]
        block = isolated.split('      - name: Debug recovery source and fixture contracts\n', 1)[1].split('      - name:', 1)[0]
        for path in ('tests/save_debug_lossy', 'tests/save_debug_fixture', 'tests/save_debug_combined'):
            self.assertIn('python3 -B -m unittest discover -s ' + path, block)
        for forbidden in ('--run-native', 'DreamDaemon', 'DreamMaker', 'workflow_dispatch'):
            self.assertNotIn(forbidden, block)
        self.assertIn("github.event_name == 'workflow_dispatch'", text.split('  debug-lossy:', 1)[1])


if __name__ == '__main__':
    unittest.main()
