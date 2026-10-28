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
    baseline = dict(schema_version=1, kind='baseline', status='passed', **source, job_attempt='1',
                    selection_sha256=ci.digest(plan), tracked_dirty=False,
                    tracked_dirty_after=False, source_unchanged=True,
                    observed_head_before=source['head'], observed_head_after=source['head'], suites={})
    for name, selected in plan['baseline']['suites'].items():
        baseline['suites'][name] = dict(selected, status='passed' if selected['selected'] else 'skipped')
        if selected['selected']:
            baseline['suites'][name].update(exit_code=0, counts=dict(
                status='passed', tests=1, errors=0, failures=0, skipped=0))
    compiler = dict(schema_version=1, kind='compile', status='skipped', selected=False,
                    step_outcome='skipped', reason='Documentation only', **source, job_attempt='1',
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
    def test_woodworking_runs_on_production_or_modified_test_changes_without_extensive(self):
        self.assertEqual(ci.SUITES['woodworking']['files'],('tests/primitive_woodworking/test_source.py',))
        dedicated=('code/modules/1713/primitive_woodworking.dm',
                   'scripts/atlas/woodworking.py',
                   'tests/primitive_woodworking/test_source.py',
                   'tests/primitive_woodworking/source_adapter.py')
        for path in dedicated:
            with self.subTest(path=path):
                result=ci.impact([path])
                self.assertTrue(result['suites']['woodworking']['selected'])
                self.assertFalse(result['fallback_reasons'])
        self.assertIn('woodworking',self.selected(['code/modules/persistence/functions.dm']))
        self.assertIn('woodworking',self.selected(['civ13.dme']))
        source=(ROOT/'tests/primitive_woodworking/test_source.py').read_text()
        tree=ast.parse(source)
        reads={node.right.value for node in ast.walk(tree)
               if isinstance(node,ast.BinOp) and isinstance(node.op,ast.Div)
               and isinstance(node.left,ast.Name) and node.left.id=='ROOT'
               and isinstance(node.right,ast.Constant) and isinstance(node.right.value,str)}
        self.assertIn('civ13.dme',reads)
        for path in reads:
            with self.subTest(actual_dependency=path):
                self.assertIn('woodworking',self.selected([path]))
        shared=('code/modules/materials/material_sheets.dm','code/modules/materials/materials.dm',
                'code/game/objects/items/weapons/material/kitchen.dm',
                'code/game/objects/items/weapons/material/thrown.dm',
                'code/game/objects/items/weapons/surgery_tools.dm',
                'scripts/build-crafting-atlas.py','scripts/player_help_bridge.py','UI/crafting-atlas.json')
        for path in shared:
            with self.subTest(shared=path):
                self.assertEqual(self.selected([path]),set(ci.SUITES))
                self.assertIn('Unmapped impact: '+path,ci.impact([path])['fallback_reasons'])

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
                expected = {'policy', 'bootstrap', 'progress', 'hub_status'}
                if path == 'code/world.dm':
                    expected.add('dictionary')
                self.assertEqual(self.selected([path]), expected)
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

    def test_water_treatment_and_save_checks_run_for_all_source_inputs(self):
        self.assertEqual(ci.SUITES['water_treatment']['files'],
                         ('tests/stone_boiling/test_source.py', 'tests/stone_kiln/test_source.py'))
        self.assertEqual(ci.SUITES['save_movement']['files'], ('tests/save_movement/test_guard.py',))
        inputs = ('code/game/objects/structures/kitchen/stone_boiling.dm',
                  'code/game/objects/structures/kitchen/stone_kiln_upgrade.dm',
                  'code/game/objects/structures/kitchen/oven.dm',
                  'code/modules/1713/machinery/engines/heatsource.dm',
                  'code/modules/persistence/functions.dm',
                  'code/modules/reagents/Chemistry-Holder.dm',
                  'code/modules/reagents/reagent_containers/glass.dm',
                  'code/modules/reagents/reagent_containers/food/drinks/drinkingglass.dm',
                  'code/modules/materials/material_sheets.dm',
                  'code/modules/1713/resource_sifting.dm',
                  'code/modules/research_tree/research_node.dm',
                  'config/crafting/material_recipes_global.txt')
        for path in inputs:
            with self.subTest(path=path):
                self.assertIn('water_treatment', self.selected([path]))
                if path != 'code/modules/persistence/functions.dm':
                    self.assertEqual(self.selected([path]), set(ci.SUITES))
                    self.assertIn('Unmapped impact: ' + path, ci.impact([path])['fallback_reasons'])
        for path in ('tests/stone_boiling/test_source.py', 'tests/stone_kiln/test_source.py'):
            self.assertIn('water_treatment', self.selected([path]))
        for path in ('tests/save_movement/source_adapter.py', 'tests/save_movement/test_guard.py',
                     'code/modules/persistence/functions.dm'):
            self.assertIn('save_movement', self.selected([path]))
        self.assertFalse(any('test_native.py' in f for s in ci.SUITES.values() for f in s['files']))

    def test_fishing_stock_registration_is_exact_and_offline(self):
        suite = ci.SUITES['fishing_stock']
        self.assertEqual(suite['files'], ('tests/fishing_stock/test_source_contract.py',
                                         'tests/fishing_stock/test_preparation.py',
                                         'tests/fishing_stock/test_native_runner.py'))
        self.assertEqual(suite['paths'], ('tests/fishing_stock/',))
        self.assertFalse(suite.get('always', False))
        source = (ROOT / suite['files'][0]).read_text()
        tree = ast.parse(source)
        imports = {node.module if isinstance(node, ast.ImportFrom) else alias.name
                   for node in ast.walk(tree) if isinstance(node, (ast.Import, ast.ImportFrom))
                   for alias in node.names}
        self.assertEqual(imports, {'argparse', 'dataclasses', 'itertools', 'pathlib', 're', 'unittest'})
        self.assertEqual(ci.TIMEOUT, 30)

    def test_fishing_stock_selection_preserves_shared_source_fallback(self):
        for path in ('tests/fishing_stock/test_source_contract.py', 'tests/fishing_stock/README.md',
                     'tests/fishing_stock/run_native.py', 'tests/fishing_stock/fixture.dm'):
            with self.subTest(path=path):
                self.assertEqual(self.selected([path]), {'policy', 'bootstrap', 'progress', 'fishing_stock'})
                self.assertEqual(ci.impact([path])['fallback_reasons'], [])
        shared = 'code/game/mob/living/simple_animal/friendly/static.dm'
        self.assertEqual(self.selected([shared]), set(ci.SUITES))
        self.assertIn('Unmapped impact: ' + shared, ci.impact([shared])['fallback_reasons'])

    def test_sawmill_registration_and_selection_are_offline_and_bounded(self):
        suite = ci.SUITES['sawmill']
        self.assertEqual(suite['files'], ('tests/sawmill/test_contract.py',
                                          'tests/test_atlas_navigation.py',
                                          'tests/player_help/test_recipe_context.py'))
        self.assertEqual(suite['paths'], ('tests/sawmill/',))
        self.assertFalse(suite.get('always', False))
        for path in suite['files']:
            with self.subTest(path=path):
                self.assertIn('sawmill', self.selected([path]))
                self.assertEqual(ci.impact([path])['fallback_reasons'], [])
        for shared in ('code/modules/1713/production.dm', 'scripts/atlas/catalog_metadata.py',
                       'scripts/player_help_bridge.py', 'UI/crafting-atlas.json'):
            with self.subTest(shared=shared):
                self.assertEqual(self.selected([shared]), set(ci.SUITES))
                self.assertIn('Unmapped impact: ' + shared, ci.impact([shared])['fallback_reasons'])
        self.assertFalse(any(path.endswith(('.dm', 'run.py')) for path in suite['files']))

    def test_dictionary_inputs_select_only_the_reviewed_offline_file(self):
        self.assertEqual(ci.SUITES['dictionary']['files'],
                         ('tests/dictionary_era/test_sources.py',
                          'tests/dictionary_era/test_slang_content.py',
                          'tests/dictionary_era/test_phrase_mode.py'))
        for path in ('code/_helpers/dictionary.dm', 'config/dictionary.txt',
                     'code/game/mob/living/carbon/human/say.dm',
                     'code/game/mob/living/carbon/human/whisper.dm',
                     'tests/dictionary_era/prepare.py', 'tests/dictionary_era/probe.dm'):
            with self.subTest(path=path):
                self.assertEqual(self.selected([path]),
                                 {'policy', 'bootstrap', 'progress', 'dictionary'})
                self.assertEqual(ci.impact([path])['fallback_reasons'], [])
        registered = ci.SUITES['dictionary']['files']
        self.assertFalse(any(path.endswith(('probe.dm', 'prepare.py')) for path in registered))

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

    def test_selection_from_an_earlier_attempt_of_the_same_run_is_named_explicitly(self):
        # Re-running failed jobs reuses the successful selection job, so its
        # receipt keeps attempt 1 while the consumer runs in attempt 2.
        plan, _, _, _ = fixtures()
        current = {key: plan[key] for key in ('head', 'base', 'requested_base', 'run_id')}
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'selection.json'
            ci.write_json(path, plan)
            with patch.object(ci, 'provenance', return_value=dict(current, run_attempt='2')):
                self.assertEqual(ci.load_selection(path, plan['head'], plan['base'], '1'), plan)
                with self.assertRaisesRegex(ValueError, 'provenance mismatch: run_attempt'):
                    ci.load_selection(path, plan['head'], plan['base'])
                for declared in ('2', '3'):
                    with self.subTest(declared=declared), self.assertRaisesRegex(ValueError, 'run_attempt'):
                        ci.load_selection(path, plan['head'], plan['base'], declared)
                for declared in ('', '0', '01', 'x', '1 '):
                    with self.subTest(declared=declared), self.assertRaises(ValueError):
                        ci.load_selection(path, plan['head'], plan['base'], declared)
                changed = dict(plan, run_id='456')
                ci.write_json(path, changed)
                with self.assertRaisesRegex(ValueError, 'provenance mismatch: run_id'):
                    ci.load_selection(path, plan['head'], plan['base'], '1')
            with patch.object(ci, 'provenance', return_value=dict(current, run_attempt='1')):
                ci.write_json(path, dict(plan, run_attempt='2'))
                with self.assertRaisesRegex(ValueError, 'run_attempt'):
                    ci.load_selection(path, plan['head'], plan['base'], '2')

    def test_receipts_record_the_attempt_that_executed_them(self):
        plan, _, _, _ = fixtures()
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ, {'GITHUB_RUN_ATTEMPT': '2'}):
            ci.compile_receipt(plan, 'skipped', Path(temporary) / 'compile.json')
            receipt = json.loads((Path(temporary) / 'compile.json').read_text())
        self.assertEqual((receipt['run_attempt'], receipt['job_attempt']), ('1', '2'))
        source = (ROOT / 'scripts/ci_baseline.py').read_text()
        execute = source.split('def execute(', 1)[1].split('\ndef ', 1)[0]
        self.assertIn("job_attempt=os.environ.get('GITHUB_RUN_ATTEMPT')", execute)


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

    def test_reused_and_rerun_jobs_validate_against_their_own_attempts(self):
        plan, baseline, compiler, jobs = fixtures()
        compiler['job_attempt'] = '2'
        attempts = dict(baseline='1', compile='2', current='2')
        self.assertEqual(ci.aggregate(plan, baseline, compiler, jobs, False, attempts), [])
        self.assertIn('compile job attempt mismatch', ci.aggregate(plan, baseline, compiler, jobs, False))
        for change, kind in ((dict(compile='1'), 'compile'), (dict(current='1'), 'compile'),
                             (dict(baseline='2'), 'baseline'), (dict(baseline=''), 'baseline'),
                             (dict(compile=None), 'compile'), (dict(current=None), 'baseline')):
            with self.subTest(change=change):
                self.assertIn(kind + ' job attempt mismatch', ci.aggregate(
                    plan, baseline, compiler, jobs, False, dict(attempts, **change)))
        earlier = deepcopy(baseline)
        earlier['job_attempt'] = '0'
        self.assertIn('baseline job attempt mismatch', ci.aggregate(
            plan, earlier, compiler, jobs, False, dict(attempts, baseline='0')))
        missing = deepcopy(baseline)
        del missing['job_attempt']
        self.assertIn('baseline job attempt mismatch', ci.aggregate(plan, missing, compiler, jobs, False, attempts))
        # A rerun cannot pair receipts from another selection or attempt.
        stale = deepcopy(compiler)
        stale['run_attempt'] = '2'
        self.assertIn('compile provenance mismatch: run_attempt', ci.aggregate(
            plan, baseline, stale, jobs, False, attempts))

    def test_workflow_consumers_download_receipts_by_their_producing_attempt(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        reusable = (ROOT / '.github/workflows/ci-selection.yml').read_text()
        self.assertIn('value: ${{ jobs.changes.outputs.attempt }}', reusable)
        self.assertIn('      attempt: ${{ github.run_attempt }}\n    steps:', reusable)
        import re
        jobs = {name: re.split(r'\n  (?:# [^\n]*\n  )*[\w-]+:\n', workflow.split('\n  ' + name + ':\n', 1)[1], 1)[0]
                for name in ('baseline', 'build')}
        self.assertNotIn('Compile selected exact-head game', jobs['baseline'])
        self.assertIn('Compile selected exact-head game', jobs['build'])
        for name, block in jobs.items():
            with self.subTest(job=name):
                self.assertIn('    outputs:\n      attempt: ${{ github.run_attempt }}\n', block)
                self.assertIn('ci-selection-${{ github.event.pull_request.head.sha || github.sha }}-${{ github.run_id }}-${{ needs.changes.outputs.attempt }}', block)
                self.assertIn('SELECTION_ATTEMPT: ${{ needs.changes.outputs.attempt }}', block)
                self.assertIn('--selection-attempt "$SELECTION_ATTEMPT"', block)
        aggregate = workflow.split('\n  ci-required:\n')[1]
        for artifact, producer in (('selection', 'changes'), ('baseline', 'baseline'), ('compile', 'build')):
            self.assertIn('ci-%s-${{ github.event.pull_request.head.sha || github.sha }}-${{ github.run_id }}-${{ needs.%s.outputs.attempt }}' % (artifact, producer), aggregate)
        for flag in ('--selection-attempt "$SELECTION_ATTEMPT"', '--baseline-attempt "$BASELINE_ATTEMPT"',
                     '--compile-attempt "$COMPILE_ATTEMPT"'):
            self.assertIn(flag, aggregate)
        # Every attempt still publishes its own receipts under its own attempt.
        self.assertIn('name: ci-aggregate-${{ github.event.pull_request.head.sha || github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}', aggregate)
        self.assertIn('name: ci-selection-${{ github.event.pull_request.head.sha || github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}', reusable)

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


if __name__ == '__main__':
    unittest.main()
