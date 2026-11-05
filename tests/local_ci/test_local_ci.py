"""Offline checks for scripts/local_ci.py: every forged or stale pass must fall back to hosted CI."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('local_ci', ROOT / 'scripts/local_ci.py')
local_ci = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(local_ci)

HEAD, TREE, OTHER = 'a' * 40, 'b' * 40, 'c' * 40
VAL, TAISLIN, STRANGER = 7202504, 14982498, 999
VERSION = '516.1688'


def plan(paths=('code/game/x.dm',), compile_selected=True, extensive=False, new_tests=(), event='pull_request',
         gating=True):
    return dict(head=HEAD, event=event, extensive=extensive, new_tests=list(new_tests),
                eligibility=dict(gating=dict(eligible=gating, reason='r')),
                comparison=dict(status='available', paths=list(paths)),
                compile=dict(selected=compile_selected, reason='r'),
                baseline=dict(suites={'policy': dict(selected=True), 'grinder': dict(selected=False)}))


def receipt(selection, **changes):
    core = local_ci.selection_core(selection)
    value = dict(schema=1, kind='local-ci', status='passed', head=HEAD, tree=TREE, byond=VERSION,
                 selection_core=core, selection_core_sha256=local_ci.sha256_text(local_ci.canonical(core)),
                 baseline=dict(status='passed'), compile=dict(status='passed'),
                 dreamchecker=dict(status='passed'), attester='valzargaming')
    value.update(changes)
    return value


def published(value, creator=VAL, commenter=None, commit=HEAD, digest=None, state='success', comment_id=42):
    text = local_ci.canonical(value)
    status = dict(context=local_ci.CONTEXT, state=state, creator=dict(id=creator),
                  description='local-ci v1 sha256=' + (digest or local_ci.sha256_text(text)),
                  target_url=f'https://github.com/{local_ci.REPO}/commit/{HEAD}#commitcomment-{comment_id}')
    comment = dict(id=comment_id, user=dict(id=commenter or creator), commit_id=commit,
                   body=f'{local_ci.MARKER}\nLocal CI pass\n\n```json\n{text}\n```\n')
    return [status], {comment_id: comment}


def decide(selection, statuses=(), comments=None, labels=(), label_events=(), tree=TREE, version=VERSION):
    return local_ci.decide(head=HEAD, tree=tree, plan=selection, statuses=list(statuses),
                           get_comment=lambda number: (comments or {}).get(number),
                           attesters={VAL, TAISLIN}, version=version, labels=list(labels),
                           label_events=list(label_events))


class AttestationTests(unittest.TestCase):
    def test_valid_pass_skips_heavy_jobs(self):
        selection = plan()
        verdict = decide(selection, *published(receipt(selection)))
        self.assertEqual((verdict['skip'], verdict['mode'], verdict['skip_dreamchecker']), (True, 'attested', True))

    def test_second_attester_is_trusted(self):
        selection = plan()
        self.assertTrue(decide(selection, *published(receipt(selection), creator=TAISLIN))['skip'])

    def test_no_status_runs_hosted(self):
        verdict = decide(plan())
        self.assertFalse(verdict['skip'])
        self.assertIn('No local-ci/attested status', verdict['reasons'])

    def test_untrusted_creator_runs_hosted(self):
        selection = plan()
        self.assertFalse(decide(selection, *published(receipt(selection), creator=STRANGER))['skip'])

    def test_comment_by_someone_else_runs_hosted(self):
        selection = plan()
        self.assertFalse(decide(selection, *published(receipt(selection), commenter=STRANGER))['skip'])

    def test_receipt_edited_after_status_runs_hosted(self):
        selection = plan()
        self.assertFalse(decide(selection, *published(receipt(selection), digest='f' * 64))['skip'])

    def test_receipt_for_other_commit_runs_hosted(self):
        selection = plan()
        self.assertFalse(decide(selection, *published(receipt(selection, head=OTHER)))['skip'])
        self.assertFalse(decide(selection, *published(receipt(selection), commit=OTHER))['skip'])

    def test_different_tree_runs_hosted(self):
        selection = plan()
        self.assertFalse(decide(selection, *published(receipt(selection)), tree=OTHER)['skip'])

    def test_failed_or_pending_status_runs_hosted(self):
        selection = plan()
        for state in ('failure', 'pending', 'error'):
            with self.subTest(state=state):
                self.assertFalse(decide(selection, *published(receipt(selection), state=state))['skip'])

    def test_latest_status_wins(self):
        selection = plan()
        statuses, comments = published(receipt(selection))
        stale = dict(statuses[0], state='failure')
        self.assertFalse(decide(selection, [stale] + statuses, comments)['skip'])

    def test_stale_selection_runs_hosted(self):
        local = plan()
        hosted = plan()
        hosted['baseline']['suites']['grinder']['selected'] = True
        verdict = decide(hosted, *published(receipt(local)))
        self.assertFalse(verdict['skip'])
        self.assertIn('Local selection differs from hosted selection', verdict['reasons'])

    def test_wrong_compiler_runs_hosted(self):
        selection = plan()
        self.assertFalse(decide(selection, *published(receipt(selection, byond='516.1681')))['skip'])

    def test_failed_local_steps_run_hosted(self):
        selection = plan()
        for change in (dict(status='failed'), dict(baseline=dict(status='failed')),
                       dict(compile=dict(status='skipped'))):
            with self.subTest(change=change):
                self.assertFalse(decide(selection, *published(receipt(selection, **change)))['skip'])

    def test_crlf_comment_body_still_verifies(self):
        selection = plan()
        statuses, comments = published(receipt(selection))
        comments[42]['body'] = comments[42]['body'].replace('\n', '\r\n')
        self.assertTrue(decide(selection, statuses, comments)['skip'])

    def test_link_to_another_repository_runs_hosted(self):
        selection = plan()
        statuses, comments = published(receipt(selection))
        statuses[0]['target_url'] = statuses[0]['target_url'].replace(local_ci.REPO, 'evil/Civ13')
        self.assertFalse(decide(selection, statuses, comments)['skip'])

    def test_dreamchecker_not_run_locally_keeps_hosted_dreamchecker(self):
        selection = plan()
        verdict = decide(selection, *published(receipt(selection, dreamchecker=dict(status='not_run'))))
        self.assertTrue(verdict['skip'])
        self.assertFalse(verdict['skip_dreamchecker'])


class ScopeTests(unittest.TestCase):
    def test_native_or_introduced_suites_run_hosted(self):
        for selection in (plan(extensive=True), plan(new_tests=['tests/extraction'])):
            with self.subTest(selection=selection['extensive']):
                self.assertFalse(decide(selection, *published(receipt(selection)))['skip'])

    def test_control_paths_run_hosted(self):
        for path in ('.github/workflows/test.yml', 'scripts/local_ci.py', 'tools/ci/local_attesters.json',
                     'scripts/select-ci.py', 'tools/byond/version.json'):
            with self.subTest(path=path):
                selection = plan(paths=[path])
                self.assertFalse(decide(selection, *published(receipt(selection)))['skip'])

    def test_push_and_informational_runs_never_skip(self):
        for selection in (plan(event='push'), plan(gating=False)):
            self.assertFalse(decide(selection, *published(receipt(selection)))['skip'])


class WaiverTests(unittest.TestCase):
    label = local_ci.WAIVER_PREFIX + HEAD

    def events(self, actor=VAL, last='labeled', name=None):
        return [dict(event=last, label=dict(name=name or self.label), actor=dict(id=actor))]

    def test_maintainer_waiver_skips_non_game_change(self):
        verdict = decide(plan(paths=['scripts/foo.py']), labels=[self.label], label_events=self.events())
        self.assertEqual((verdict['skip'], verdict['mode']), (True, 'waived'))

    def test_waiver_refused_for_game_files(self):
        for path in ('code/x.dm', 'maps/x.dmm', 'icons/x.dmi', 'civ13.dme'):
            with self.subTest(path=path):
                self.assertFalse(decide(plan(paths=[path]), labels=[self.label], label_events=self.events())['skip'])

    def test_waiver_needs_trusted_labeller(self):
        self.assertFalse(decide(plan(paths=['docs/x.md']), labels=[self.label],
                                label_events=self.events(actor=STRANGER))['skip'])

    def test_waiver_is_bound_to_head(self):
        old = local_ci.WAIVER_PREFIX + OTHER
        self.assertFalse(decide(plan(paths=['docs/x.md']), labels=[old],
                                label_events=self.events(name=old))['skip'])

    def test_waiver_refused_for_control_paths(self):
        self.assertFalse(decide(plan(paths=['.github/workflows/x.yml']), labels=[self.label],
                                label_events=self.events())['skip'])


class HelperTests(unittest.TestCase):
    def test_checked_in_attesters_are_val_and_taislin(self):
        ids = local_ci.load_attesters(ROOT / local_ci.ATTESTERS)
        self.assertEqual(ids, {VAL, TAISLIN})

    def test_malformed_attesters_are_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'a.json'
            for value in ({}, dict(schema=1, attesters=[dict(login='x', id='7')]),
                          dict(schema=1, attesters=[dict(login='x', id=0)])):
                path.write_text(json.dumps(value))
                with self.assertRaises(ValueError):
                    local_ci.load_attesters(path)

    def test_verify_never_fails_and_falls_back_on_errors(self):
        with tempfile.TemporaryDirectory() as directory:
            out, verdict = Path(directory) / 'out', Path(directory) / 'verdict.json'
            args = ['verify', '--head', HEAD, '--checkout', directory, '--selection', str(Path(directory) / 'missing.json'),
                    '--attesters', str(ROOT / local_ci.ATTESTERS), '--verdict', str(verdict), '--output', str(out)]
            with mock.patch.dict('os.environ', {'GITHUB_STEP_SUMMARY': ''}):
                self.assertEqual(local_ci.main(args), 0)
            self.assertIn('skip=false', out.read_text())
            self.assertFalse(json.loads(verdict.read_text())['skip'])

    def test_aggregate_requires_gate_skip(self):
        jobs = {'changes': dict(result='success'),
                'local-attestation': dict(result='success', outputs=dict(skip='true', mode='attested')),
                'baseline': dict(result='skipped'), 'evidence-checker': dict(result='skipped'),
                'build': dict(result='skipped'), 'extraction-instances': dict(result='skipped')}
        with tempfile.TemporaryDirectory() as directory:
            output = str(Path(directory) / 'aggregate.json')
            with mock.patch.dict('os.environ', {'CI_NEEDS': json.dumps(jobs), 'GITHUB_STEP_SUMMARY': ''}):
                self.assertEqual(local_ci.main(['aggregate', '--head', HEAD, '--output', output]), 0)
            jobs['local-attestation']['outputs']['skip'] = 'false'
            with mock.patch.dict('os.environ', {'CI_NEEDS': json.dumps(jobs), 'GITHUB_STEP_SUMMARY': ''}):
                self.assertEqual(local_ci.main(['aggregate', '--head', HEAD, '--output', output]), 1)
            jobs['local-attestation']['outputs'].update(skip='true')
            jobs['build']['result'] = 'failure'
            with mock.patch.dict('os.environ', {'CI_NEEDS': json.dumps(jobs), 'GITHUB_STEP_SUMMARY': ''}):
                self.assertEqual(local_ci.main(['aggregate', '--head', HEAD, '--output', output]), 1)

    def test_workflow_gate_reads_trusted_base_and_skips_heavy_jobs(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        gate = workflow.split('\n  local-attestation:\n', 1)[1]
        self.assertIn('ref: ${{ github.event.pull_request.base.sha }}', gate)
        self.assertIn('trusted/scripts/local_ci.py verify', gate)
        self.assertIn('--attesters trusted/tools/ci/local_attesters.json', gate)
        self.assertNotIn('statuses: write', workflow)
        for name in ('baseline', 'evidence-checker', 'build', 'extraction-instances'):
            block = workflow.split('\n  ' + name + ':\n', 1)[1].split('\n    runs-on:', 1)[0]
            self.assertIn("needs.local-attestation.outputs.skip != 'true'", block, name)
        dream = workflow.split('\n  dreamchecker:\n', 1)[1].split('\n    runs-on:', 1)[0]
        self.assertIn("needs.local-attestation.outputs.skip_dreamchecker != 'true'", dream)


if __name__ == '__main__':
    unittest.main()
