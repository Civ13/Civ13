"""Offline checks for the optional one-shot hosted proposal. No dispatch occurs."""
from pathlib import Path
import re
import unittest
from prepare import HEAD, TREE

WORKFLOW = Path(__file__).resolve().parents[2] / '.github/workflows/snow-native-1688-once.yml'


class WorkflowTests(unittest.TestCase):
    def test_one_exact_initial_branch_and_first_attempt_only(self):
        text = WORKFLOW.read_text()
        self.assertIn('      - codex/snow-native-1688-20261025-attempt1\n', text)
        for gate in ("github.repository == 'Civ13/Civ13'", 'github.event.created == true',
                     'github.run_attempt == 1', "github.ref == 'refs/heads/codex/snow-native-1688-20261025-attempt1'"):
            self.assertIn(gate, text)
        self.assertNotIn('workflow_dispatch:', text)
        self.assertNotIn('pull_request', text)
        self.assertIn('  cancel-in-progress: false\n', text)

    def test_exact_source_parent_archive_and_restricted_checkout(self):
        text = WORKFLOW.read_text()
        self.assertIn('test "$(git -C runner rev-parse HEAD^)" = 68a89db5c3d93afc486522e4d0a9be9351758a0e', text)
        self.assertIn('test "$(git -C source rev-parse HEAD)" = ' + HEAD, text)
        self.assertIn('test "$(git -C source rev-parse \'HEAD^{tree}\')" = ' + TREE, text)
        self.assertEqual(text.count('          persist-credentials: false'), 2)
        self.assertIn('permissions:\n  contents: read\n', text)
        self.assertNotIn('secrets.', text)
        self.assertNotIn('self-hosted', text)
        self.assertIn('--source repository-release', text)
        self.assertIn('16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9', text)
        for action in re.findall(r'uses: (\S+)', text):
            self.assertRegex(action, r'@\w{40}$')

    def test_limits_reviewed_flag_and_allowlisted_retention(self):
        text = WORKFLOW.read_text()
        self.assertIn('    timeout-minutes: 25\n', text)
        self.assertIn('        timeout-minutes: 11\n', text)
        self.assertEqual(text.count('            --reviewed-native\n'), 1)
        self.assertNotIn('--source-export', text)
        self.assertIn('SNOW_TEST_SOURCE: ${{ github.workspace }}/source', text)
        self.assertIn('            --output "$RUNNER_TEMP/snow-1688-retained"', text)
        self.assertIn('          path: ${{ runner.temp }}/snow-1688-retained/\n', text)


if __name__ == '__main__':
    unittest.main()
