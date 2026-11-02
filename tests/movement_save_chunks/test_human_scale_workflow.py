"""Offline admission and bounds for the proposed manual hosted scale job."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ScaleWorkflowContracts(unittest.TestCase):
    def test_scale_is_manual_exclusive_and_bounded(self):
        text = (ROOT / '.github/workflows/moving-save-chunks.yml').read_text()
        self.assertIn("github.event_name != 'workflow_dispatch' || (inputs.human_spatial_only != true && inputs.human_scale_only != true && inputs.lighting_interleave_only != true && inputs.debug_lossy_only != true)", text)
        spatial = text.split('  human-spatial:\n', 1)[1].split('  human-scale:\n', 1)[0]
        scale = text.split('  human-scale:\n', 1)[1]
        self.assertIn('inputs.human_scale_only != true', spatial)
        self.assertIn("github.event_name == 'workflow_dispatch' && inputs.human_scale_only == true", scale)
        self.assertIn('inputs.lighting_interleave_only != true', scale)
        self.assertIn('test "$SPATIAL_ONLY" != true', scale)
        self.assertLess(scale.index('test "$SPATIAL_ONLY" != true'), scale.index('bash scripts/travis_pre_byond.sh'))
        self.assertIn('timeout-minutes: 90', scale)
        self.assertIn('timeout-minutes: 68', scale)
        self.assertIn('persist-credentials: false', scale)
        self.assertIn('contents: read', text)
        self.assertNotIn('secrets.', scale)

    def test_review_and_disk_checks_precede_bootstrap_and_native(self):
        text = (ROOT / '.github/workflows/moving-save-chunks.yml').read_text()
        scale = text.split('  human-scale:\n', 1)[1]
        self.assertLess(scale.index('verify_review('), scale.index('bash scripts/travis_pre_byond.sh'))
        self.assertLess(scale.index('shutil.disk_usage'), scale.index('bash scripts/travis_pre_byond.sh'))
        self.assertIn('16*1024**3', scale)
        self.assertIn('test "$REVIEWED_HEAD" = "$EVENT_HEAD"', scale)
        self.assertIn('--expected-head "$REVIEWED_HEAD" --expected-scope-sha256 "$REVIEWED_SCOPE"', scale)
        self.assertIn('BYOND_ARCHIVE_SOURCE: repository-release', scale)
        self.assertIn('human_scale_run.py --run-native', scale)
        # The large synthetic save bytes are not uploaded; the reports and logs are.
        upload = scale.split('  Retain bounded scale receipts and logs', 1)[-1]
        self.assertIn('human-scale-evidence/*.json', upload)
        self.assertNotIn('human-scale-evidence/**', upload)


if __name__ == '__main__':
    unittest.main()
