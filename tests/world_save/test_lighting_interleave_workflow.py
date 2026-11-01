"""Offline workflow contract only; does not download or execute BYOND."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/moving-save-chunks.yml"


class LightingInterleaveWorkflow(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = WORKFLOW.read_text(encoding="utf-8")
        cls.job = cls.source.split("\n  lighting-interleave:\n", 1)[1].split("\n  human-spatial:\n", 1)[0]

    def test_manual_only_and_exclusive_against_existing_jobs(self):
        self.assertIn("lighting_interleave_only:\n", self.source)
        self.assertIn("github.event_name == 'workflow_dispatch' && inputs.lighting_interleave_only == true", self.job)
        self.assertIn('test "$SPATIAL_ONLY" != true', self.job)
        self.assertIn('test "$SCALE_ONLY" != true', self.job)
        other = self.source.replace(self.job, "")
        self.assertEqual(other.count("inputs.lighting_interleave_only != true"), 3)

    def test_verified_head_scope_and_runtime_envelope(self):
        for value in ("persist-credentials: false", 'test "$REVIEWED_HEAD" = "$EVENT_HEAD"',
                      'test "$(git rev-parse HEAD)" = "$REVIEWED_HEAD"',
                      'r.verify(os.environ["REVIEWED_HEAD"],os.environ["REVIEWED_SCOPE"])',
                      'r.scale.free_space(os.environ["RUNNER_TEMP"], r.scale.MIN_FREE_START)',
                      "timeout-minutes: 20", "timeout-minutes: 8"):
            self.assertIn(value, self.job)
        self.assertEqual(self.job.count("lighting_interleave_run.py --run-native"), 1)
        self.assertIn('github.event_name == \'workflow_dispatch\'', self.job)

    def test_provisioning_uses_verified_archive_without_extra_game_compile(self):
        for value in ("python3 -B scripts/byond_toolchain.py download --platform linux",
                      "--source repository-release", "unzip -q BYOND/pinned.zip -d BYOND",
                      "python3 -B scripts/byond_runtime.py", "test -x BYOND/byond/bin/DreamMaker",
                      "test -x BYOND/byond/bin/DreamDaemon"):
            self.assertIn(value, self.job)
        for forbidden in ("travis_pre_byond.sh", "make here", "build-crafting-atlas.py",
                          "DreamMaker -max_errors", "DreamDaemon -"):
            self.assertNotIn(forbidden, self.job)

    def test_evidence_upload_retains_logs_without_save_or_binary_files(self):
        upload = self.job.split("- name: Retain synthetic receipts and diagnostics", 1)[1]
        self.assertIn("if: always()", upload)
        self.assertIn("lighting-interleave-evidence/writer/*.json", upload)
        self.assertIn("lighting-interleave-evidence/reader/*.log", upload)
        self.assertNotIn("map_saves", upload)
        self.assertNotIn("*.dmb", upload)
        self.assertNotIn("*.rsc", upload)


if __name__ == "__main__":
    unittest.main()
