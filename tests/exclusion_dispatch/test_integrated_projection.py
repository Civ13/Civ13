"""Reviewed squash projection: exact source preservation, no native execution."""
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

from historical_fixtures import text
import integrated_projection as profile


class IntegratedProjectionTests(unittest.TestCase):
    def sources(self, revision):
        return {path: text(revision, path) for path in profile.PATHS}

    def project(self, base, candidate, *, ancestry=0):
        def show(command, **kwargs):
            if command[:3] == ['git', 'rev-parse', '--is-shallow-repository']:
                return 'false\n'
            return base[command[-1].split(':', 1)[1]]
        real_run = subprocess.run
        def run(command, **kwargs):
            if command[:3] == ['git', 'merge-base', '--is-ancestor']:
                return subprocess.CompletedProcess(command, ancestry, '', '')
            return real_run(command, **kwargs)
        with patch.object(profile.subprocess, 'check_output', side_effect=show), \
             patch.object(profile.subprocess, 'run', side_effect=run):
            return profile.project(Path('.'), {'base': 'b' * 40, 'head': 'a' * 40}, candidate)

    def test_push_transition_and_already_integrated_pr_base(self):
        after = self.sources(profile.AFTER)
        for revision in (profile.BEFORE, profile.AFTER):
            with self.subTest(base=revision):
                self.assertTrue(self.project(self.sources(revision), after))

    def test_preserves_independent_event_base_evolution(self):
        base, candidate = self.sources(profile.AFTER), self.sources(profile.AFTER)
        for path in profile.PATHS:
            base[path] += '\n// Independent event-base bookkeeping.\n'
            candidate[path] = base[path]
        self.assertTrue(self.project(base, candidate))
        with self.assertRaisesRegex(ValueError, 'Integrated source drift'):
            self.project(base, self.sources(profile.AFTER))

    def test_rejects_every_changed_candidate_file_and_removed_custody(self):
        base = self.sources(profile.AFTER)
        for path in profile.PATHS:
            candidate = dict(base)
            candidate[path] += '\n// Unreviewed head-only change.\n'
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, 'Integrated source drift'):
                self.project(base, candidate)
        with self.assertRaises(ValueError):
            self.project(base, self.sources(profile.BEFORE))

    def test_requires_positive_integrated_ancestry_and_propagates_git_failure(self):
        after = self.sources(profile.AFTER)
        self.assertFalse(self.project(after, after, ancestry=1))
        with self.assertRaisesRegex(ValueError, 'Cannot verify integrated ancestry'):
            self.project(after, after, ancestry=128)


if __name__ == '__main__':
    unittest.main()
