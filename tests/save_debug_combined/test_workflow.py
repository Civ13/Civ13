"""Offline hosted-dispatch contract, not execution of GitHub Actions."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / '.github/workflows/moving-save-chunks.yml'


class CombinedWorkflowContract(unittest.TestCase):
    def setUp(self):
        self.text = WORKFLOW.read_text(encoding='utf-8')
        self.body = self.text.split('\n  debug-combined:\n', 1)[1]

    def test_manual_selection_is_exclusive_before_provisioning(self):
        self.assertIn("github.event_name == 'workflow_dispatch' && inputs.debug_combined_only == true", self.body)
        for job in ('isolated-native', 'lighting-interleave', 'human-spatial', 'human-scale', 'debug-lossy'):
            header = self.text.split('\n  ' + job + ':\n', 1)[1].split('\n', 4)[:4]
            self.assertIn('inputs.debug_combined_only != true', '\n'.join(header), job)
        for selector in ('SPATIAL_ONLY', 'SCALE_ONLY', 'LIGHTING_ONLY', 'LOSSY_ONLY'):
            guard = 'test "$' + selector + '" != true'
            self.assertIn(guard, self.body)
            self.assertLess(self.body.index(guard), self.body.index('dpkg --add-architecture i386'))

    def test_head_scope_and_runtime_are_bound_before_native(self):
        for token in ('contents: read', 'persist-credentials: false'):
            self.assertIn(token, self.text)
        for token in ('test "$REVIEWED_HEAD" = "$EVENT_HEAD"', 'test "$(git rev-parse HEAD)" = "$REVIEWED_HEAD"',
                      'stage.scope()["sha256"] == os.environ["REVIEWED_SCOPE"]',
                      'tests/save_debug_combined/controller.py --run-native',
                      'scripts/byond_runtime.py --byond-bin', '--source repository-release'):
            self.assertIn(token, self.body)
        self.assertLess(self.body.index('stage.scope()['), self.body.index('dpkg --add-architecture i386'))
        self.assertLess(self.body.index('scripts/byond_runtime.py --byond-bin'), self.body.index('controller.py --run-native'))
        for forbidden in ('secrets.', 'bash scripts/travis_pre_byond.sh', 'DreamMaker -max_errors 0 civ13.dme'):
            self.assertNotIn(forbidden, self.body)


if __name__ == '__main__':
    unittest.main()
