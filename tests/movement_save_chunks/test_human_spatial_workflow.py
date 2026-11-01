"""Offline source contracts for the unpublished hosted-run proposal."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class WorkflowContracts(unittest.TestCase):
    def test_fixture_is_manual_and_preserves_ordinary_job_admission(self):
        text = (ROOT / '.github/workflows/moving-save-chunks.yml').read_text()
        self.assertIn("github.event_name != 'workflow_dispatch' || (inputs.human_spatial_only != true && inputs.human_scale_only != true)", text)
        self.assertIn("github.event_name == 'workflow_dispatch' && inputs.human_spatial_only == true", text)
        self.assertIn("persist-credentials: false", text)
        self.assertIn("contents: read", text)
        self.assertNotIn('secrets.', text)

    def test_external_review_binding_precedes_bootstrap_and_reaches_driver(self):
        text = (ROOT / '.github/workflows/moving-save-chunks.yml').read_text()
        body = text.split('  human-spatial:\n', 1)[1].split('  human-scale:\n', 1)[0]
        self.assertLess(body.index('review_scope()['), body.index('bash scripts/travis_pre_byond.sh'))
        self.assertIn('test "$REVIEWED_HEAD" = "$EVENT_HEAD"', body)
        self.assertIn('--expected-head "$REVIEWED_HEAD" --expected-scope-sha256 "$REVIEWED_SCOPE"', body)
        self.assertIn('BYOND_ARCHIVE_SOURCE: repository-release', body)
        self.assertIn('timeout-minutes: 40', body)


if __name__ == '__main__':
    unittest.main()
