"""Actual CLI preparation in tiny Git histories; no BYOND or binary queries."""
from contextlib import contextmanager
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from preparation import FIXTURE, INHERITED, PATH
from source_contract import project_lighting_policy

ROOT = Path(__file__).resolve().parents[2]
# Seed content only; never supplied as the temporary runner's live reference.
SEED = 'eedc9862fcb7b2b7c3617c6972965fafa650e51a'
EVOLUTION = '\n// Independently evolved upstream bookkeeping.\n/map_storage/proc/evolution_probe()\n\treturn TRUE\n'


def git(repo, *args):
    return subprocess.check_output(['git', *args], cwd=repo, text=True,
                                   encoding='utf-8', stderr=subprocess.PIPE, timeout=15).strip()


class ActualPreparationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.seed = subprocess.check_output(['git', 'show', SEED + ':' + PATH], cwd=ROOT,
                                           text=True, encoding='utf-8')

    def commit(self, repo, text):
        (repo / PATH).write_text(text, encoding='utf-8')
        git(repo, 'add', '.')
        git(repo, '-c', 'user.name=Offline Test', '-c', 'user.email=offline@example.invalid',
            '-c', 'commit.gpgsign=false', 'commit', '--allow-empty', '-qm', 'Fixture snapshot')
        return git(repo, 'rev-parse', 'HEAD')

    @contextmanager
    def history(self, base_text=None, head_text=None, inherited_evolution=False):
        with tempfile.TemporaryDirectory(prefix='exclusion-offline-') as temp:
            directory = Path(temp)
            repo = directory / 'repo'
            repo.mkdir()
            git(repo, 'init', '-q')
            for path in FIXTURE:
                target = repo / path
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / path, target)
            for path, _ in INHERITED:
                target = repo / path
                target.parent.mkdir(parents=True, exist_ok=True)
                text = subprocess.check_output(['git', 'show', SEED + ':' + path], cwd=ROOT,
                                               text=True, encoding='utf-8')
                target.write_text(text + ('\n// Shared inherited evolution.\n' if inherited_evolution else ''),
                                  encoding='utf-8')
            (repo / PATH).parent.mkdir(parents=True, exist_ok=True)
            base = self.commit(repo, self.seed if base_text is None else base_text)
            head = self.commit(repo, project_lighting_policy(self.seed) if head_text is None else head_text)
            yield directory, repo, base, head

    def invoke(self, directory, repo, base, head, *, expected=None, event='pull_request',
               missing=None, arguments=()):
        # Clear inherited host event state: each subprocess receives its own
        # immutable test event, not a mocked prepare() or git-show implementation.
        environment = {key: value for key, value in os.environ.items()
                       if not key.startswith(('GITHUB_', 'CI_BASE', 'CI_HEAD'))}
        environment.update(CI_BASE=base, CI_HEAD=head, GITHUB_ACTIONS='true',
                           GITHUB_EVENT_NAME=event, PYTHONDONTWRITEBYTECODE='1')
        pair = expected or (base, head)
        metadata = ({'before': pair[0], 'after': pair[1]} if event == 'push' else
                    {'pull_request': {'base': {'sha': pair[0]}, 'head': {'sha': pair[1]}}})
        event_path = directory / 'event.json'
        event_path.write_text(json.dumps(metadata), encoding='utf-8')
        environment['GITHUB_EVENT_PATH'] = str(event_path)
        if missing:
            environment.pop(missing, None)
        output = directory / ('receipt-' + str(len(list(directory.glob('receipt-*')))) + '.json')
        completed = subprocess.run([sys.executable, '-B', str(repo / 'tests/exclusion_dispatch/run.py'),
            '--source-only', '--output', str(output), *arguments], cwd=repo, env=environment,
            text=True, encoding='utf-8', capture_output=True, timeout=30)
        return completed, output

    def passed(self, directory, repo, base, head, **kwargs):
        completed, output = self.invoke(directory, repo, base, head, **kwargs)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        receipt = json.loads(output.read_text())
        self.assertEqual((receipt['baseline_sha'], receipt['head_sha']), (base, head))
        self.assertEqual(receipt['identity_source'], 'event')
        self.assertFalse(receipt['native_execution'])
        self.assertEqual(receipt['binaries'], {})
        return (output.with_suffix('.sources') / 'production.dm').read_text()

    def rejected(self, directory, repo, base, head, message, **kwargs):
        completed, output = self.invoke(directory, repo, base, head, **kwargs)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn(message, completed.stderr)
        self.assertFalse(output.exists())
        self.assertFalse(output.with_suffix('.sources').exists())

    def test_event_base_before_and_after_lighting_additions(self):
        for after in (False, True):
            with self.subTest(after=after), self.history(
                    base_text=project_lighting_policy(self.seed) if after else self.seed) as args:
                production = self.passed(*args)
                self.assertIn('"area_change_owner"', production)
                self.assertIn('/atom/movable/baseline_runtime(key)\n\treturn key == "original_target"', production)

    def test_shared_unrelated_base_head_and_inherited_evolution(self):
        for after in (False, True):
            base = project_lighting_policy(self.seed) if after else self.seed
            with self.subTest(after=after), self.history(base + EVOLUTION,
                    project_lighting_policy(self.seed) + EVOLUTION, inherited_evolution=True) as args:
                self.passed(*args)

    def test_diverged_event_base_with_only_unrelated_file_evolution(self):
        with self.history() as (directory, repo, original_base, head):
            git(repo, 'checkout', '-qb', 'upstream', original_base)
            (repo / 'unrelated.txt').write_text('Upstream-only flower-like change.\n')
            base = self.commit(repo, self.seed)
            git(repo, 'checkout', '-q', head)
            self.passed(directory, repo, base, head)

    def test_each_addition_can_already_exist_independently(self):
        from source_contract import project_area_change_owner, project_fullbright_exclusions
        for projection in (project_area_change_owner, project_fullbright_exclusions):
            with self.subTest(projection=projection.__name__), self.history(projection(self.seed)) as args:
                self.passed(*args)

    def test_one_sided_unrelated_evolution_is_rejected_in_actual_cli(self):
        for on_base in (False, True):
            with self.subTest(on_base=on_base), self.history(
                    self.seed + (EVOLUTION if on_base else ''),
                    project_lighting_policy(self.seed) + ('' if on_base else EVOLUTION)) as args:
                self.rejected(*args, 'Only approved fullbright exclusions')

    def test_one_sided_policy_and_parent_regressions_before_and_after_additions(self):
        candidate = project_lighting_policy(self.seed)
        mutations = (
            lambda text: text.replace('"area_change_owner"', '"lost_owner"', 1),
            lambda text: text.replace('/atom/movable/lighting_fullbright', '/atom/movable/lost_type', 1),
            lambda text: '/atom/movable/lost_type'.join(text.rsplit('/atom/movable/lighting_fullbright', 1)),
            lambda text: text.replace('"snowfall_ground_index"', '"lost_snow"', 1),
            lambda text: text.replace('"persistence_zone_id"', '"lost_zone"', 1),
            lambda text: text.replace('key == "original_target"', 'FALSE', 1),
            lambda text: text.replace('\treturn ..()', '\treturn FALSE', 1),
            lambda text: text.replace('\tswitch(key)', '\t..()\n\tswitch(key)', 1),
        )
        for after in (False, True):
            with self.history(candidate if after else self.seed) as (directory, repo, base, _):
                for index, mutation in enumerate(mutations):
                    with self.subTest(after=after, mutation=index):
                        changed = mutation(candidate)
                        self.assertNotEqual(changed, candidate)
                        head = self.commit(repo, changed)
                        self.rejected(directory, repo, base, head, 'Only approved fullbright exclusions')

    def test_partial_existing_base_policy_is_rejected(self):
        candidate = project_lighting_policy(self.seed)
        for broken in (candidate.replace('/atom/movable/lighting_fullbright', '/atom/movable/lost_type', 1),
                       candidate.replace('"area_change_owner")\n\t\treturn TRUE',
                                         '"area_change_owner")\n\t\treturn FALSE', 1)):
            with self.subTest(broken=broken[-50:]), self.history(broken) as args:
                self.rejected(*args, 'Event base has partial or changed')

    def test_missing_mutable_self_mismatched_and_unknown_identities_fail_closed(self):
        with self.history() as (directory, repo, base, head):
            for missing in ('CI_BASE', 'CI_HEAD', 'GITHUB_EVENT_PATH'):
                with self.subTest(missing=missing):
                    self.rejected(directory, repo, base, head,
                                  'required' if missing == 'GITHUB_EVENT_PATH' else 'identity', missing=missing)
            self.rejected(directory, repo, base, head, 'non-immutable base', arguments=('--base', 'HEAD~1'))
            self.rejected(directory, repo, head, head, 'self-comparison')
            self.rejected(directory, repo, head, base, 'differs from checked-out HEAD')
            self.rejected(directory, repo, base, head, 'differ from immutable event', expected=(head, head))
            self.rejected(directory, repo, 'f' * 40, head, 'CalledProcessError')
            self.rejected(directory, repo, base, head, 'No immutable base/head pair', event='workflow_dispatch')

    def test_dirty_source_helper_and_fixture_are_rejected_before_output(self):
        with self.history() as (directory, repo, base, head):
            for path in (PATH, INHERITED[0][0], 'tests/exclusion_dispatch/probe.dm'):
                with self.subTest(path=path):
                    target = repo / path
                    original = target.read_bytes()
                    try:
                        target.write_bytes(original + b'\n// dirty input\n')
                        self.rejected(directory, repo, base, head, 'Working input differs')
                    finally:
                        target.write_bytes(original)

    def test_one_sided_committed_inherited_drift_is_rejected(self):
        with self.history() as (directory, repo, base, head):
            path = repo / INHERITED[0][0]
            path.write_text(path.read_text() + '\n// candidate-only inherited drift\n')
            head = self.commit(repo, project_lighting_policy(self.seed))
            self.rejected(directory, repo, base, head, 'Inherited helper drift from event base')

    def test_push_event_uses_before_and_checked_out_after(self):
        with self.history() as args:
            self.passed(*args, event='push')


if __name__ == '__main__':
    unittest.main()
