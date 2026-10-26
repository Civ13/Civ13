"""Offline policy/receipt controls. No compiler, runtime, inventory or network."""
from copy import deepcopy
import ast
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('ci_baseline', ROOT / 'scripts/ci_baseline.py')
ci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci)


def fixtures(paths=('README.md',)):
    source = dict(head='a' * 40, base='b' * 40, requested_base='b' * 40,
                  run_id='123', run_attempt='1')
    plan = dict(schema_version=1, kind='selection', status='passed', **source,
                event='pull_request', action='opened', eligibility=dict(action='opened', metadata_valid=True,
                    compile=dict(eligible=True, reason='Ordinary diff selection'),
                    native=dict(eligible=True, reason='Ordinary PR admission'),
                    gating=dict(eligible=True, reason='Full ordinary PR scope')),
                baseline=ci.impact(paths), compile={'selected': False, 'reason': 'Documentation only'})
    baseline = dict(schema_version=1, kind='baseline', status='passed', **source,
                    selection_run_attempt=source['run_attempt'],
                    selection_sha256=ci.digest(plan), tracked_dirty=False,
                    tracked_dirty_after=False, source_unchanged=True,
                    observed_head_before=source['head'], observed_head_after=source['head'], suites={})
    for name, selected in plan['baseline']['suites'].items():
        baseline['suites'][name] = dict(selected, status='passed' if selected['selected'] else 'skipped')
        if selected['selected']:
            baseline['suites'][name].update(exit_code=0, counts=dict(
                status='passed', tests=1, errors=0, failures=0, skipped=0))
    compiler = dict(schema_version=1, kind='compile', status='skipped', selected=False,
                    selection_run_attempt=source['run_attempt'],
                    step_outcome='skipped', reason='Documentation only', **source,
                    toolchain='BYOND ' + ci.toolchain.load()['version'], toolchain_error=None,
                    selection_sha256=ci.digest(plan))
    requirement = ci.toolchain.load()
    archive = requirement['linux']
    compiler['acquisition'] = dict(version=requirement['version'], platform='linux', url=archive['repositoryRelease']['url'],
        sha256=archive['sha256'], bytes=archive['bytes'], integritySource=requirement['integritySource'],
        source='repository-release', requested_source='repository-release', upstream_source='repository-release',
        upstream_url=archive['repositoryRelease']['url'], cache_key=ci.toolchain.cache_key(requirement, 'linux'), cache_status='miss',
        repository_release=deepcopy(archive['repositoryRelease']))
    jobs = {name: {'result': 'success'} for name in ('changes', 'baseline', 'evidence-checker', 'build')}
    jobs['extraction-instances'] = {'result': 'skipped'}
    return plan, baseline, compiler, jobs


class BaselinePolicyTests(unittest.TestCase):
    def selected(self, paths, comparison='available'):
        return {name for name, row in ci.impact(paths, comparison)['suites'].items() if row['selected']}

    def test_docs_keep_small_mandatory_baseline_and_compile_optimization(self):
        self.assertEqual(self.selected(['AGENTS.md', 'docs/api/index.html']),
                         {'policy', 'bootstrap', 'progress'})
        self.assertFalse(ci.documentation('docs/new.dm'))
        self.assertEqual(self.selected(['docs/new.dm']), set(ci.SUITES))

    def test_docs_scripts_and_config_cannot_evade_unknown_impact_fallback(self):
        for path in ('docs/helper.py', 'docs/tool.sh', 'docs/helper.js', 'docs/helper.ps1',
                     'docs/config.json', 'docs/config.yaml', 'docs/config.toml',
                     'docs/requirements.txt', 'scripts/build-api-docs.py',
                     '.github/workflows/api-docs.yml'):
            with self.subTest(path=path):
                result = ci.impact([path])
                self.assertFalse(ci.documentation(path))
                self.assertEqual(self.selected([path]), set(ci.SUITES))
                self.assertIn('Unmapped impact: ' + path, result['fallback_reasons'])
        # The offline fallback does not change the separately reviewed compiler
        # selection, including its existing docs/ and generator optimization.
        selection_spec = importlib.util.spec_from_file_location('compile_policy', ROOT / 'scripts/select-ci.py')
        selection = importlib.util.module_from_spec(selection_spec)
        selection_spec.loader.exec_module(selection)
        self.assertFalse(selection.needs_game(['docs/helper.py', 'docs/tool.sh',
                                              'scripts/build-api-docs.py']))

    def test_reviewed_documentation_formats_and_exact_assets_remain_cheap(self):
        for path in ('docs/guide.md', 'docs/guide.rst', 'docs/api/index.html',
                     'docs/api/search.css', 'docs/api/search.js', 'docs/api/baseline-diagnostics.txt',
                     'docs/images/example.png', 'docs/images/example.svg', 'docs/guide.pdf'):
            with self.subTest(path=path):
                self.assertTrue(ci.documentation(path))
                self.assertEqual(self.selected([path]), {'policy', 'bootstrap', 'progress'})
                self.assertEqual(ci.impact([path])['fallback_reasons'], [])

    def test_production_inputs_select_existing_affected_offline_tests(self):
        self.assertEqual(self.selected(['code/processes/research_tree.dm']),
                         {'policy', 'bootstrap', 'progress', 'research'})
        self.assertEqual(self.selected(['code/processes/_process.dm']),
                         {'policy', 'bootstrap', 'progress', 'research', 'ping'})
        self.assertIn('year', self.selected(['code/setup.dm']))

    def test_ping_source_dependencies_match_its_actual_registered_test_reads(self):
        # Ping uses a Python dispatch adapter, not the production scheduler.
        # Audit the exact direct ROOT-relative source reads in its registered
        # file so adding a new direct source input requires updating this list.
        source = (ROOT / ci.SUITES['ping']['files'][0]).read_text()
        tree = ast.parse(source)
        reads = {node.right.value for node in ast.walk(tree)
                 if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Div)
                 and isinstance(node.left, ast.Name) and node.left.id == 'ROOT'
                 and isinstance(node.right, ast.Constant) and isinstance(node.right.value, str)}
        self.assertEqual(reads, {'code/processes/ping_track.dm', 'code/processes/_process.dm'})
        self.assertTrue(reads.issubset(set(ci.SUITES['ping']['paths'])))
        self.assertNotIn('__processScheduler.dm', source)
        self.assertIn('"git", "show", BASE + ":code/processes/ping_track.dm"', source)
        self.assertEqual(self.selected(['code/processes/__processScheduler.dm']),
                         {'policy', 'bootstrap', 'progress', 'research'})

    def test_hub_status_inputs_select_only_reviewed_offline_contracts(self):
        self.assertEqual(ci.SUITES['hub_status']['files'], ('tests/test_hub_status.py',))
        for path in ('code/world.dm', 'config/config.txt', 'tests/test_hub_status.py'):
            with self.subTest(path=path):
                self.assertEqual(self.selected([path]), {'policy', 'bootstrap', 'progress', 'hub_status'})
                self.assertEqual(ci.impact([path])['fallback_reasons'], [])

    def test_modified_tests_and_helpers_are_affected_without_introduced_test_admission(self):
        for path, name in (('tests/ping_scheduler/test_resume.py', 'ping'),
                           ('tests/ping_scheduler/helper.py', 'ping'),
                           ('tests/persistence_year/test_native.py', 'year'),
                           ('tests/world_save/stubs.dm', 'year'),
                           ('scripts/check-game-evidence.py', 'evidence')):
            with self.subTest(path=path):
                self.assertIn(name, self.selected([path]))
        self.assertEqual(ci.SUITES['year']['files'], ('tests/persistence_year/test_floor.py',))
        self.assertFalse(any('test_native.py' in f for s in ci.SUITES.values() for f in s['files']))

    def test_unknown_dependencies_and_failed_comparisons_are_visible_and_bounded(self):
        for paths, comparison in ((['requirements.txt'], 'available'),
                                  (['code/new_system.dm'], 'available'),
                                  (['tests/unreviewed/run.py'], 'available'),
                                  (['scripts/ci_baseline.py'], 'available'),
                                  ([], 'unavailable')):
            with self.subTest(paths=paths):
                impact = ci.impact(paths, comparison)
                self.assertEqual(self.selected(paths, comparison), set(ci.SUITES))
                self.assertTrue(impact['fallback_reasons'])
                self.assertTrue(all(row['reason'] for row in impact['suites'].values()))

    def test_real_exact_git_comparison_modified_helper_deleted_source_and_docs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            def git(*args):
                return subprocess.check_output(['git', '-C', temporary, *args],
                                               stderr=subprocess.PIPE, timeout=10).decode().strip()
            git('init')
            git('config', 'user.name', 'Baseline test')
            git('config', 'user.email', 'ci@example.invalid')
            (root / 'code/processes').mkdir(parents=True)
            (root / 'code/processes/ping_track.dm').write_text('// before')
            (root / 'README.md').write_text('before')
            (root / 'tests/ping_scheduler').mkdir(parents=True)
            (root / 'tests/ping_scheduler/helper.py').write_text('# before')
            git('add', '.')
            git('commit', '-qm', 'base')
            base = git('rev-parse', 'HEAD')
            for relative in ('README.md', 'tests/ping_scheduler/helper.py', 'code/processes/ping_track.dm'):
                if relative.startswith('code/'):
                    (root / relative).unlink()
                else:
                    (root / relative).write_text('after')
                git('add', '-A')
                git('commit', '-qm', 'change')
                head = git('rev-parse', 'HEAD')
                with patch.object(ci, 'ROOT', root):
                    receipt = ci.selection_receipt(base, head, relative != 'README.md', False,
                                                   [], 'test policy', 'pull_request')
                self.assertEqual(receipt['head'], head)
                self.assertEqual(receipt['base'], base)
                self.assertEqual(receipt['comparison']['paths'], [relative])
                self.assertEqual(receipt['baseline']['suites']['ping']['selected'], relative != 'README.md')
                base = head

    def test_missing_comparison_has_fallback_and_mismatched_head_fails(self):
        with patch.object(ci, 'revision', side_effect=lambda value: 'a' * 40):
            plan = ci.selection_receipt('', 'a' * 40, True, False, [], 'No base', 'push')
        self.assertEqual(plan['comparison']['status'], 'unavailable')
        self.assertEqual({n for n, row in plan['baseline']['suites'].items() if row['selected']}, set(ci.SUITES))
        with patch.object(ci, 'revision', side_effect=['a' * 40, 'b' * 40]):
            with self.assertRaisesRegex(ValueError, 'checked-out HEAD'):
                ci.provenance('b' * 40, '')

    def test_selector_process_failure_cannot_emit_successful_outputs(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'output'
            receipt = Path(temporary) / 'selection.json'
            result = subprocess.run([sys.executable, '-B', str(ROOT / 'scripts/select-ci.py'),
                '--base', '', '--head', 'nonexistent-ci-test-head', '--output', str(output),
                '--event', 'push', '--receipt', str(receipt)],
                cwd=ROOT, capture_output=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(output.exists())
            self.assertFalse(receipt.exists())

    def test_suite_deadline_and_missing_test_counts_fail_execution(self):
        plan, _, _, _ = fixtures()
        real_run = ci.subprocess.run
        def deadline(command, **kwargs):
            if 'unit' in command:
                raise subprocess.TimeoutExpired('offline fixture', 30)
            return real_run(command, **kwargs)
        def no_counts(command, **kwargs):
            if 'unit' in command:
                return subprocess.CompletedProcess(command, 0)
            return real_run(command, **kwargs)
        with tempfile.TemporaryDirectory() as temporary, patch('builtins.print'), patch.object(ci.subprocess, 'run',
                side_effect=deadline):
            self.assertEqual(ci.execute(plan, temporary), 1)
            receipt = json.loads((Path(temporary) / 'baseline.json').read_text())
            self.assertEqual(receipt['status'], 'failed')
            self.assertTrue(all(row['status'] == 'failed' for row in receipt['suites'].values() if row['selected']))
        with tempfile.TemporaryDirectory() as temporary, patch('builtins.print'), patch.object(ci.subprocess, 'run',
                side_effect=no_counts):
            self.assertEqual(ci.execute(plan, temporary), 1)

    def test_post_test_tracked_mutation_or_head_change_invalidates_baseline(self):
        for change in ('tracked-file', 'head'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                def git(*args):
                    return subprocess.check_output(['git', '-C', temporary, *args],
                                                   stderr=subprocess.PIPE, timeout=10).decode().strip()
                git('init')
                git('config', 'user.name', 'Post-test source fixture')
                git('config', 'user.email', 'ci@example.invalid')
                tracked = root / 'tracked.py'
                tracked.write_text('# original\n')
                git('add', '.')
                git('commit', '-qm', 'base')
                head = git('rev-parse', 'HEAD')
                plan, _, _, _ = fixtures()
                plan['head'] = head
                mutated = False
                real_run = ci.subprocess.run
                def run(command, **kwargs):
                    nonlocal mutated
                    if 'unit' not in command:
                        return real_run(command, **kwargs)
                    ci.write_json(command[command.index('--output') + 1], dict(
                        status='passed', tests=1, errors=0, failures=0, skipped=0))
                    if not mutated:
                        mutated = True
                        if change == 'tracked-file':
                            tracked.write_text('# changed during synthetic test\n')
                        else:
                            git('commit', '--allow-empty', '-qm', 'unexpected test commit')
                    return subprocess.CompletedProcess(command, 0)
                with patch.object(ci, 'ROOT', root), patch.object(ci.subprocess, 'run', side_effect=run), patch('builtins.print'):
                    self.assertEqual(ci.execute(plan, root / 'evidence'), 1)
                result = json.loads((root / 'evidence/baseline.json').read_text())
                self.assertFalse(result['tracked_dirty'])
                self.assertFalse(result['source_unchanged'])
                self.assertEqual(result['status'], 'failed')
                self.assertTrue(all(row['status'] == 'passed' for row in result['suites'].values() if row['selected']))
                if change == 'tracked-file':
                    self.assertTrue(result['tracked_dirty_after'])
                    self.assertIn('changed during synthetic test', (root / 'evidence/tested-after.patch').read_text())
                else:
                    self.assertFalse(result['tracked_dirty_after'])
                    self.assertNotEqual(result['observed_head_after'], head)
    def test_selection_loader_rejects_disabled_mandatory_tests_and_stale_source(self):
        plan, _, _, _ = fixtures()
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'selection.json'
            with patch.object(ci, 'provenance', return_value={key: plan[key] for key in (
                    'head', 'base', 'requested_base', 'run_id', 'run_attempt')}):
                ci.write_json(path, plan)
                self.assertEqual(ci.load_selection(path, plan['head'], plan['base']), plan)
                for key in ('head', 'base', 'run_id', 'run_attempt'):
                    changed = deepcopy(plan)
                    changed[key] = 'wrong'
                    ci.write_json(path, changed)
                    with self.assertRaisesRegex(ValueError, 'provenance'):
                        ci.load_selection(path, plan['head'], plan['base'])
                plan['baseline']['suites']['policy']['selected'] = False
                ci.write_json(path, plan)
                with self.assertRaisesRegex(ValueError, 'Always-required'):
                    ci.load_selection(path, plan['head'], plan['base'])


class AggregateTests(unittest.TestCase):
    def test_selected_compilation_rejects_missing_or_wrong_archive_provenance(self):
        for bad in (None, {}, {'source':'cache'}, {'url':'https://example.com'}):
            plan, baseline, compiler, jobs = fixtures()
            plan['compile']['selected'] = True
            baseline['selection_sha256'] = compiler['selection_sha256'] = ci.digest(plan)
            compiler.update(selected=True, status='passed', step_outcome='success', acquisition=bad)
            with self.subTest(acquisition=bad):
                self.assertIn('Missing/invalid exact-source BYOND acquisition receipt', ci.aggregate(plan, baseline, compiler, jobs, False))

    def test_selected_compilation_binds_release_identity_even_with_valid_compiler_outcome(self):
        plan, baseline, compiler, jobs = fixtures()
        plan['compile']['selected'] = True
        compiler.update(selected=True, status='passed', step_outcome='success')
        baseline['selection_sha256'] = compiler['selection_sha256'] = ci.digest(plan)
        self.assertEqual(ci.aggregate(plan, baseline, compiler, jobs, False), [])
        for key in compiler['acquisition']['repository_release']:
            invalid = deepcopy(compiler)
            invalid['acquisition']['repository_release'][key] = None
            with self.subTest(key=key):
                self.assertIn('Missing/invalid exact-source BYOND acquisition receipt',
                              ci.aggregate(plan, baseline, invalid, jobs, False))
        invalid = deepcopy(compiler)
        del invalid['acquisition']['repository_release']
        self.assertIn('Missing/invalid exact-source BYOND acquisition receipt',
                      ci.aggregate(plan, baseline, invalid, jobs, False))

    def test_selected_compilation_rejects_missing_or_wrong_toolchain_metadata(self):
        for label in (None, 'BYOND 516.1681', 'BYOND 516.1689'):
            plan, baseline, compiler, jobs = fixtures()
            plan['compile']['selected'] = True
            baseline['selection_sha256'] = compiler['selection_sha256'] = ci.digest(plan)
            compiler.update(selected=True, status='passed', step_outcome='success', toolchain=label)
            with self.subTest(label=label):
                self.assertIn('Compiler receipt differs from active BYOND requirement', ci.aggregate(plan, baseline, compiler, jobs, False))

    def test_docs_compile_skip_is_explicit_and_accepted_after_real_baseline(self):
        self.assertEqual(ci.aggregate(*fixtures(), False), [])

    def test_required_job_failure_skip_cancel_missing_and_selector_failure_fail(self):
        for name in ('changes', 'baseline', 'build', 'evidence-checker'):
            for outcome in ('failure', 'skipped', 'cancelled', None):
                plan, baseline, compiler, jobs = fixtures()
                jobs[name]['result'] = outcome
                with self.subTest(name=name, outcome=outcome):
                    self.assertTrue(ci.aggregate(plan, baseline, compiler, jobs, False))

    def test_selected_extraction_cannot_be_skipped(self):
        plan, baseline, compiler, jobs = fixtures()
        self.assertTrue(ci.aggregate(plan, baseline, compiler, jobs, True))
        jobs['extraction-instances']['result'] = 'success'
        self.assertEqual(ci.aggregate(plan, baseline, compiler, jobs, True), [])

    def test_selected_compilation_cannot_be_a_job_level_green_skip(self):
        plan, baseline, compiler, jobs = fixtures()
        plan['compile']['selected'] = True
        baseline['selection_sha256'] = compiler['selection_sha256'] = ci.digest(plan)
        self.assertTrue(ci.aggregate(plan, baseline, compiler, jobs, False))
        compiler.update(selected=True, status='passed', step_outcome='success')
        self.assertEqual(ci.aggregate(plan, baseline, compiler, jobs, False), [])

    def test_unexpected_suite_skip_empty_tests_or_missing_receipts_fail(self):
        for change in (
                lambda b: b.update(tracked_dirty=True),
                lambda b: b.update(tracked_dirty_after=True),
                lambda b: b.update(source_unchanged=False),
                lambda b: b.update(observed_head_after='changed'),
                lambda b: b.pop('tracked_dirty_after'),
                lambda b: b['suites']['policy'].update(status='skipped'),
                lambda b: b['suites']['policy']['counts'].update(tests=0),
                lambda b: b['suites']['policy']['counts'].update(skipped=1),
                lambda b: b['suites']['policy'].update(exit_code=1),
                lambda b: b['suites'].pop('policy'),
                lambda b: b.clear()):
            plan, baseline, compiler, jobs = fixtures()
            change(baseline)
            self.assertTrue(ci.aggregate(plan, baseline, compiler, jobs, False))
        plan, baseline, _, jobs = fixtures()
        self.assertTrue(ci.aggregate(plan, baseline, {}, jobs, False))

    def test_missing_or_incomplete_eligibility_cannot_claim_a_gating_verdict(self):
        for change in (lambda p: p.pop('eligibility'),
                       lambda p: p['eligibility'].update(metadata_valid=False),
                       lambda p: p['eligibility']['native'].update(eligible=False),
                       lambda p: p['eligibility']['gating'].update(reason='')):
            plan, baseline, compiler, jobs = fixtures()
            change(plan)
            baseline['selection_sha256'] = compiler['selection_sha256'] = ci.digest(plan)
            self.assertTrue(ci.aggregate(plan, baseline, compiler, jobs, False))

    def test_compiler_success_cannot_certify_an_omitted_native_failure(self):
        for compiler_failed in (True, False):
            with self.subTest(compiler_failed=compiler_failed):
                plan, baseline, compiler, jobs = fixtures()
                plan['compile']['selected'] = True
                compiler.update(selected=True, status='failed' if compiler_failed else 'passed',
                                step_outcome='failure' if compiler_failed else 'success')
                jobs['build']['result'] = 'failure'  # Compiler or later native fixture failed.
                baseline['selection_sha256'] = compiler['selection_sha256'] = ci.digest(plan)
                self.assertIn('Required job did not succeed: build', ci.aggregate(
                    plan, baseline, compiler, jobs, False))
                # A later edited event can pass only its admitted work; its
                # eligibility remains informational even after a real compile.
                plan['action'] = plan['eligibility']['action'] = 'edited'
                plan['eligibility']['native'].update(eligible=False, reason='Edited native coverage omitted')
                plan['eligibility']['gating'].update(eligible=False, reason='Edited event is informational')
                compiler.update(status='passed', step_outcome='success')
                jobs['build']['result'] = 'success'
                baseline['selection_sha256'] = compiler['selection_sha256'] = ci.digest(plan)
                self.assertEqual(ci.aggregate(plan, baseline, compiler, jobs, False), [])
                self.assertFalse(ci.selection_eligibility(plan)['gating']['eligible'])

    def test_informational_compile_still_requires_exact_byond_acquisition(self):
        plan, baseline, compiler, jobs = fixtures()
        plan['action'] = plan['eligibility']['action'] = 'edited'
        plan['eligibility']['native'].update(eligible=False, reason='Edited native coverage omitted')
        plan['eligibility']['gating'].update(eligible=False, reason='Edited event is informational')
        plan['compile']['selected'] = True
        compiler.update(selected=True, status='passed', step_outcome='success')
        baseline['selection_sha256'] = compiler['selection_sha256'] = ci.digest(plan)
        self.assertEqual(ci.aggregate(plan, baseline, compiler, jobs, False), [])
        for acquisition in (None, dict(compiler['acquisition'], sha256='0' * 64)):
            with self.subTest(acquisition=acquisition):
                invalid = dict(compiler, acquisition=acquisition)
                self.assertIn('Missing/invalid exact-source BYOND acquisition receipt',
                              ci.aggregate(plan, baseline, invalid, jobs, False))

    def test_stale_head_base_run_attempt_and_changed_selection_fail(self):
        for kind in (1, 2):
            for key in ('head', 'base', 'run_id', 'run_attempt', 'selection_sha256'):
                data = list(fixtures())
                data[kind][key] = 'stale'
                with self.subTest(kind=kind, key=key):
                    self.assertTrue(ci.aggregate(*data, False))

    def test_workflow_aggregate_always_checks_jobs_and_retains_hidden_receipts(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        aggregate = workflow.split('\n  ci-required:\n')[1]
        self.assertIn('if: always()', aggregate)
        self.assertIn('needs: [changes, baseline, evidence-checker, build, extraction-instances]', aggregate)
        self.assertIn('CI_NEEDS: ${{ toJSON(needs) }}', aggregate)
        self.assertIn('--compile-receipt .ci/compile/compile.json', aggregate)
        self.assertIn('include-hidden-files: true', aggregate)
        reusable = (ROOT / '.github/workflows/ci-selection.yml').read_text()
        policy = reusable.split('- name: Selection regression tests on every invocation\n')[1].split('- name:', 1)[0]
        self.assertNotIn('if:', policy)
        self.assertIn('--suite policy', policy)


class ProducerAttemptTests(unittest.TestCase):
    """Partial reruns reuse exact dependency receipts, never a latest-artifact guess."""
    def mixed(self, selection='1', baseline='1', compiler='2'):
        plan, offline, build, jobs = fixtures()
        plan['run_attempt'] = selection
        offline.update(run_attempt=baseline, selection_run_attempt=selection, selection_sha256=ci.digest(plan))
        build.update(run_attempt=compiler, selection_run_attempt=selection, selection_sha256=ci.digest(plan))
        for job, attempt in (('changes',selection),('baseline',baseline),('build',compiler)):
            jobs[job]['outputs'] = {'artifact_attempt': attempt}
        return plan, offline, build, jobs

    def test_loader_requires_explicit_earlier_selection_binding_and_keeps_source_checks(self):
        plan, _, _, _ = self.mixed()
        expected={key:plan[key] for key in ('head','base','requested_base','run_id','run_attempt')}
        expected['run_attempt']='2'
        with tempfile.TemporaryDirectory() as temporary, patch.object(ci,'provenance',return_value=expected):
            path=Path(temporary)/'selection.json'; ci.write_json(path,plan)
            with self.assertRaisesRegex(ValueError,'run_attempt'): ci.load_selection(path,plan['head'],plan['base'])
            self.assertEqual(ci.load_selection(path,plan['head'],plan['base'],'1'),plan)
            for key in ('head','base','requested_base','run_id','run_attempt'):
                bad=dict(plan,**{key:'wrong'});ci.write_json(path,bad)
                with self.subTest(key=key), self.assertRaisesRegex(ValueError,'provenance'):
                    ci.load_selection(path,plan['head'],plan['base'],'1')

    def test_new_execution_stamps_own_attempt_without_relabelling_selection(self):
        plan, _, _, _ = self.mixed()
        before=deepcopy(plan)
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ,GITHUB_RUN_ATTEMPT='2'), \
                patch.object(ci,'git',return_value='source tree'), patch.object(ci.subprocess,'check_output',return_value=b''):
            output=Path(temporary)/'compile.json'
            self.assertEqual(ci.compile_receipt(plan,'skipped',output),0)
            receipt=json.loads(output.read_text())
            self.assertEqual(receipt['run_attempt'],'2')
            self.assertEqual(receipt['selection_run_attempt'],'1')
            self.assertEqual(receipt['selection_sha256'],ci.digest(plan))
        self.assertEqual(plan,before)

    def test_failed_build_baseline_and_aggregate_only_reruns_and_full_rerun(self):
        for current, selection, baseline, compiler in (('2','1','1','2'),('2','1','2','1'),
                                                       ('3','1','1','2'),('2','2','2','2')):
            data=self.mixed(selection,baseline,compiler)
            attempts=dict(selection=selection,baseline=baseline,compile=compiler)
            with self.subTest(attempts=attempts,current=current), patch.dict(os.environ,GITHUB_RUN_ATTEMPT=current):
                self.assertEqual(ci.aggregate(*data,False,attempts),[])
                if compiler != selection or baseline != selection:
                    self.assertTrue(ci.aggregate(*data,False))  # No implicit cross-attempt acceptance.
                data[3]['build']['result']='failure'
                self.assertIn('Required job did not succeed: build',ci.aggregate(*data,False,attempts))

    def test_invalid_future_missing_and_wrong_producer_bindings_fail_closed(self):
        data=self.mixed();good=dict(selection='1',baseline='1',compile='2')
        with patch.dict(os.environ,GITHUB_RUN_ATTEMPT='2'):
            for bad in ('',None,True,1,'0','-1','01',' 1','1.0','x','3','١','9'*30):
                for kind in good:
                    with self.subTest(kind=kind,bad=bad):
                        self.assertTrue(ci.aggregate(*data,False,dict(good,**{kind:bad})))
            self.assertTrue(ci.aggregate(*data,False,dict(selection='1',baseline='1')))
            self.assertTrue(ci.aggregate(*data,False,dict(good,compile='1')))
            self.assertTrue(ci.aggregate(*data,False,dict(good,selection='2')))
            with patch.dict(os.environ,GITHUB_RUN_ATTEMPT=''):
                self.assertTrue(ci.aggregate(*data,False,good))

    def test_bound_attempts_do_not_accept_stale_receipts_or_changed_selection(self):
        attempts=dict(selection='1',baseline='1',compile='2')
        with patch.dict(os.environ,GITHUB_RUN_ATTEMPT='2'):
            for index in (1,2):
                for key in ('head','base','requested_base','run_id','run_attempt','selection_run_attempt','selection_sha256'):
                    data=list(self.mixed());data[index][key]='stale'
                    with self.subTest(index=index,key=key): self.assertTrue(ci.aggregate(*data,False,attempts))
            data=self.mixed();data[1]['tracked_dirty_after']=True
            self.assertTrue(ci.aggregate(*data,False,attempts))
            data=self.mixed();data[1]['suites']['policy']['counts']['tests']=0
            self.assertTrue(ci.aggregate(*data,False,attempts))

    def test_cli_aggregate_records_consumer_and_each_producer_without_fabricating_a_rerun(self):
        plan, offline, build, jobs=self.mixed()
        plan['action']=plan['eligibility']['action']='edited'
        for key in ('native','gating'): plan['eligibility'][key].update(eligible=False,reason='Edited informational scope')
        offline['selection_sha256']=build['selection_sha256']=ci.digest(plan)
        expected={key:plan[key] for key in ('head','base','requested_base','run_id','run_attempt')};expected['run_attempt']='2'
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            for name,value in (('selection',plan),('baseline',offline),('compile',build)):ci.write_json(root/(name+'.json'),value)
            args=['ci','aggregate','--selection',str(root/'selection.json'),'--selection-attempt','1',
                  '--head',plan['head'],'--base',plan['base'],'--baseline',str(root/'baseline.json'),
                  '--compile-receipt',str(root/'compile.json'),'--output',str(root/'aggregate.json')]
            env=dict(GITHUB_RUN_ATTEMPT='2',CI_NEEDS=json.dumps(jobs),GATING_SELECTION='0',EXTRACTION_SELECTED='false')
            with patch.object(sys,'argv',args),patch.dict(os.environ,env),patch.object(ci,'provenance',return_value=expected), \
                    patch.object(ci.subprocess,'Popen',side_effect=AssertionError('No process allowed')),patch('builtins.print'):
                self.assertEqual(ci.main(),0)
            result=json.loads((root/'aggregate.json').read_text())
            self.assertEqual(result['run_attempt'],'2');self.assertEqual(result['selection_run_attempt'],'1')
            self.assertEqual(result['producer_attempts'],dict(selection='1',baseline='1',compile='2'))
            self.assertEqual(result['coverage'],'informational')

    def test_workflow_downloads_exact_producer_attempts_and_keeps_own_upload_names(self):
        workflow=(ROOT/'.github/workflows/test.yml').read_text()
        reusable=(ROOT/'.github/workflows/ci-selection.yml').read_text()
        self.assertIn('value: ${{ jobs.changes.outputs.artifact_attempt }}',reusable)
        self.assertIn('artifact_attempt: ${{ github.run_attempt }}',reusable)
        self.assertEqual(workflow.count('artifact_attempt: ${{ github.run_attempt }}'),2)
        self.assertEqual(workflow.count('--selection-attempt "$CI_SELECTION_ATTEMPT"'),3)
        downloads=workflow.split('uses: actions/download-artifact@')[1:]
        names=[block.split('\n      - ',1)[0] for block in downloads]
        bindings=[block for block in names if 'name: ci-' in block]
        self.assertEqual(len(bindings),5)
        for block in bindings:
            self.assertNotIn('${{ github.run_attempt }}',block)
            self.assertNotIn('pattern:',block)
            self.assertNotIn('continue-on-error:',block)
        self.assertEqual(sum('needs.changes.outputs.artifact_attempt' in b for b in bindings),3)
        self.assertEqual(sum('needs.baseline.outputs.artifact_attempt' in b for b in bindings),1)
        self.assertEqual(sum('needs.build.outputs.artifact_attempt' in b for b in bindings),1)
        for prefix in ('ci-baseline','ci-compile','ci-aggregate'):
            self.assertIn('name: '+prefix+'-${{ github.event.pull_request.head.sha || github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}',workflow)


if __name__ == '__main__':
    unittest.main()
