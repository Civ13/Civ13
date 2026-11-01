"""Offline policy/receipt controls. No compiler, runtime, inventory or network."""
from copy import deepcopy
import ast
import importlib.util
import json
import os
from pathlib import Path
import shutil
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
    def test_mount_native_preparation_registration_preserves_existing_coverage(self):
        suite = ci.SUITES['mount_native_preparation']
        self.assertEqual(suite['files'], ('tests/mount_lifecycle_native/test_prepare.py',
                                         'tests/mount_lifecycle_native/test_runner.py'))
        expected = {'policy', 'bootstrap', 'progress', 'mount_native_preparation'}
        self.assertEqual(self.selected(list(suite['files'])), expected)
        self.assertEqual(self.selected(['tests/mount_lifecycle_native/probe.dm']), expected)
        self.assertEqual(self.selected(['tests/mount_lifecycle_native/README.md']), expected)
        previous = {name: spec for name, spec in ci.SUITES.items() if name != 'mount_native_preparation'}
        for shared in suite['shared_paths']:
            with patch.object(ci, 'SUITES', previous):
                prior_selection = self.selected([shared])
            self.assertEqual(self.selected([shared]), prior_selection | {'mount_native_preparation'})

    def test_rider_deletion_registration_preserves_shared_fallback(self):
        suite = ci.SUITES['rider_deletion']
        self.assertEqual(suite['files'], ('tests/rider_deletion/test_destroy.py',))
        expected = {'policy', 'bootstrap', 'progress', 'rider_deletion'}
        self.assertEqual(self.selected(list(suite['files'])), expected)
        self.assertEqual(self.selected(['tests/rider_deletion/fixtures/destroy_before.txt']), expected)
        self.assertEqual(self.selected(['tests/rider_deletion/README.md']), expected)
        previous = {name: spec for name, spec in ci.SUITES.items() if name != 'rider_deletion'}
        for shared in suite['shared_paths']:
            with patch.object(ci, 'SUITES', previous):
                prior_selection = self.selected([shared])
            self.assertEqual(self.selected([shared]), prior_selection | {'rider_deletion'})

    def test_mount_deletion_registration_preserves_shared_fallback(self):
        suite = ci.SUITES['mount_deletion']
        self.assertEqual(suite['files'], ('tests/mount_deletion/test_destroy.py',))
        expected = {'policy', 'bootstrap', 'progress', 'mount_deletion'}
        self.assertEqual(self.selected(list(suite['files'])), expected)
        self.assertEqual(self.selected(['tests/mount_deletion/fixtures/destroy_before.txt']), expected)
        self.assertEqual(self.selected(['tests/mount_deletion/NATIVE_PLAN.md']), expected)
        previous = {name: spec for name, spec in ci.SUITES.items() if name != 'mount_deletion'}
        for shared in suite['shared_paths']:
            with patch.object(ci, 'SUITES', previous):
                prior_selection = self.selected([shared])
            self.assertEqual(self.selected([shared]), prior_selection | {'mount_deletion'})

    def test_mount_distance_registration_preserves_shared_fallback(self):
        suite = ci.SUITES['mount_distance']
        self.assertEqual(suite['files'], ('tests/mount_distance/test_distance.py',))
        expected = {'policy', 'bootstrap', 'progress', 'mount_distance'}
        self.assertEqual(self.selected(list(suite['files'])), expected)
        self.assertEqual(self.selected(['tests/mount_distance/fixtures/distance_before.txt']), expected)
        previous = {name: spec for name, spec in ci.SUITES.items() if name != 'mount_distance'}
        for shared in suite['shared_paths']:
            with patch.object(ci, 'SUITES', previous):
                prior_selection = self.selected([shared])
            self.assertEqual(self.selected([shared]), prior_selection | {'mount_distance'})

    def test_mount_lifecycle_registration_preserves_shared_fallback(self):
        suite = ci.SUITES['mount_lifecycle']
        self.assertEqual(suite['files'], ('tests/mount_lifecycle/test_death.py',))
        expected = {'policy', 'bootstrap', 'progress', 'mount_lifecycle'}
        self.assertEqual(self.selected(list(suite['files'])), expected)
        self.assertEqual(self.selected(['tests/mount_lifecycle/fixtures/death_before.txt']), expected)
        previous = {name: spec for name, spec in ci.SUITES.items() if name != 'mount_lifecycle'}
        for shared in suite['shared_paths']:
            with patch.object(ci, 'SUITES', previous):
                prior_selection = self.selected([shared])
            self.assertEqual(self.selected([shared]), prior_selection | {'mount_lifecycle'})

    def test_ladder_cleanup_registration_preserves_shared_fallback(self):
        suite = ci.SUITES['ladder_cleanup']
        self.assertEqual(suite['files'], ('tests/ladder_cleanup/test_destroy.py',))
        expected = {'policy', 'bootstrap', 'progress', 'ladder_cleanup'}
        self.assertEqual(self.selected(list(suite['files'])), expected)
        self.assertEqual(self.selected(['tests/ladder_cleanup/fixtures/destroy_before.txt']), expected)
        previous = {name: spec for name, spec in ci.SUITES.items() if name != 'ladder_cleanup'}
        for shared in suite['shared_paths']:
            with patch.object(ci, 'SUITES', previous):
                prior_selection = self.selected([shared])
            self.assertEqual(self.selected([shared]), prior_selection | {'ladder_cleanup'})

    def test_telephone_recipients_are_bounded_and_keep_existing_dependency_coverage(self):
        suite = ci.SUITES['telephone_recipients']
        self.assertEqual(suite['files'], ('tests/telephone/test_recipients.py',))
        expected = {'policy', 'bootstrap', 'progress', 'telephone_recipients'}
        self.assertEqual(self.selected(['tests/telephone/test_recipients.py']), expected)
        self.assertEqual(self.selected(['tests/telephone/fixtures/telephone_before.txt']), expected)
        prior = {name: spec for name, spec in ci.SUITES.items() if name != 'telephone_recipients'}
        for shared in suite['shared_paths']:
            with patch.object(ci, 'SUITES', prior):
                previous = self.selected([shared])
            self.assertEqual(self.selected([shared]), previous | {'telephone_recipients'})

    def test_vehicle_hud_registration_is_bounded_and_preserves_shared_fallback(self):
        suite = ci.SUITES['vehicle_hud']
        self.assertEqual(suite['files'], ('tests/vehicle_hud/test_driver_axis.py',))
        expected = {'policy', 'bootstrap', 'progress', 'vehicle_hud'}
        self.assertEqual(self.selected(['tests/vehicle_hud/test_driver_axis.py']), expected)
        self.assertEqual(self.selected(['tests/vehicle_hud/fixtures/axis_handlers_before.dm']), expected)
        previous_suites = {name: spec for name, spec in ci.SUITES.items() if name != 'vehicle_hud'}
        for shared in suite['shared_paths']:
            with patch.object(ci, 'SUITES', previous_suites):
                previous_selection = self.selected([shared])
            self.assertEqual(self.selected([shared]), previous_selection | {'vehicle_hud'})

    def test_tanning_rack_appearance_registration_is_offline_and_preserves_shared_fallback(self):
        suite = ci.SUITES['tanning_rack_appearance']
        self.assertEqual(suite['files'], ('tests/test_tanning_rack_appearance.py',))
        self.assertEqual(suite['paths'], ())
        self.assertEqual(self.selected(list(suite['files'])),
                         {'policy', 'bootstrap', 'progress', 'tanning_rack_appearance'})
        self.assertEqual(ci.impact(list(suite['files']))['fallback_reasons'], [])
        for shared in suite['shared_paths']:
            self.assertEqual(self.selected([shared]), set(ci.SUITES))
            self.assertIn('Unmapped impact: ' + shared, ci.impact([shared])['fallback_reasons'])
        tree = ast.parse((ROOT/suite['files'][0]).read_text())
        self.assertEqual({alias.name for node in ast.walk(tree) if isinstance(node, ast.Import)
                          for alias in node.names}, {'ast', 're', 'struct', 'unittest', 'zlib'})
        self.assertEqual({node.module for node in ast.walk(tree) if isinstance(node, ast.ImportFrom)},
                         {'functools', 'pathlib', 'types'})

    def test_tanning_rack_appearance_failure_fails_registered_baseline_and_aggregate(self):
        suite_name = 'tanning_rack_appearance'
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            suite = ci.SUITES[suite_name]
            for relative in ('scripts/ci_baseline.py', 'scripts/byond_toolchain.py',
                             'tools/byond/version.json', *suite['files'], *suite['shared_paths']):
                destination = root/relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT/relative, destination)

            def git(*args):
                return subprocess.check_output(['git', '-C', temporary, *args],
                                               stderr=subprocess.PIPE, timeout=10).decode().strip()

            git('init')
            git('config', 'user.name', 'Rack appearance offline fixture')
            git('config', 'user.email', 'ci@example.invalid')
            git('add', '.')
            git('commit', '-qm', 'passing offline appearance fixture')
            real_run = ci.subprocess.run

            def child(command, **kwargs):
                if 'unit' not in command:
                    return real_run(command, **kwargs)
                if command[command.index('--suite')+1] == suite_name:
                    command = list(command)
                    command[2] = str(root/'scripts/ci_baseline.py')
                    return real_run(command, **(kwargs | {'cwd': root}))
                # Only this suite executes: unrelated mandatory suites are adapters.
                ci.write_json(command[command.index('--output')+1], dict(
                    status='passed', tests=1, errors=0, failures=0, skipped=0))
                return subprocess.CompletedProcess(command, 0)

            for failing in (False, True):
                if failing:
                    target = root/'code/game/objects/structures/converters.dm'
                    target.write_text(target.read_text().replace('hide_overlay.color = hide.color',
                                                               'hide_overlay.color = "#C9AA84"'))
                    git('add', '.')
                    git('commit', '-qm', 'isolated lost wet-hide colour control')
                plan, _, compiler, jobs = fixtures(suite['files'])
                plan['head'] = compiler['head'] = git('rev-parse', 'HEAD')
                compiler['selection_sha256'] = ci.digest(plan)
                evidence = root/('negative' if failing else 'positive')
                with patch.object(ci, 'ROOT', root), patch.object(ci.subprocess, 'run', side_effect=child), \
                        patch.dict(os.environ, {'GITHUB_RUN_ATTEMPT': '1'}), patch('builtins.print'):
                    exit_code = ci.execute(plan, evidence)
                baseline = json.loads((evidence/'baseline.json').read_text())
                appearance = baseline['suites'][suite_name]
                self.assertEqual(exit_code, int(failing))
                self.assertEqual(appearance['counts']['tests'], 5)
                self.assertEqual(appearance['counts']['skipped'], 0)
                self.assertTrue(baseline['source_unchanged'])
                self.assertEqual(appearance['status'], 'failed' if failing else 'passed')
                errors = ci.aggregate(plan, baseline, compiler, jobs, False)
                if failing:
                    self.assertIn('Missing, failed or unexpectedly skipped suite: '+suite_name, errors)
                else:
                    self.assertEqual(errors, [])

    def test_work_animation_registration_and_source_fallback(self):
        suite = ci.SUITES['resource_work_animation']
        self.assertEqual(suite['files'], ('tests/test_resource_work_animation.py',))
        self.assertEqual(suite['paths'], suite['files'])
        self.assertEqual(self.selected(list(suite['files'])),
                         {'policy', 'bootstrap', 'progress', 'resource_work_animation'})
        for path in suite['shared_paths']:
            with self.subTest(path=path):
                self.assertEqual(self.selected([path]), set(ci.SUITES))
                self.assertIn('Unmapped impact: ' + path, ci.impact([path])['fallback_reasons'])
        tree = ast.parse((ROOT/suite['files'][0]).read_text())
        self.assertEqual({alias.name for node in ast.walk(tree) if isinstance(node, ast.Import)
                          for alias in node.names}, {'re', 'unittest'})
        self.assertEqual({node.module for node in ast.walk(tree) if isinstance(node, ast.ImportFrom)},
                         {'pathlib', 'types'})

    def test_harvest_inputs_registration_is_bounded_and_preserves_fallback(self):
        suite = ci.SUITES['harvest_inputs']
        self.assertEqual(suite['files'], ('tests/animal_harvest/test_input_accounting.py',))
        self.assertEqual(suite['paths'], suite['files'])
        self.assertFalse(suite.get('always', False))
        self.assertEqual(self.selected(list(suite['files'])),
                         {'policy', 'bootstrap', 'progress', 'harvest_inputs'})
        self.assertEqual(ci.impact(list(suite['files']))['fallback_reasons'], [])
        for path in suite['shared_paths']:
            candidate = path+'first.txt' if path.endswith('/') else path
            previous_suites = {name:spec for name,spec in ci.SUITES.items() if name != 'harvest_inputs'}
            with patch.object(ci,'SUITES',previous_suites):
                previous_selected = self.selected([candidate])
                previous_fallback = ci.impact([candidate])['fallback_reasons']
            self.assertEqual(self.selected([candidate]), previous_selected|{'harvest_inputs'})
            self.assertEqual(ci.impact([candidate])['fallback_reasons'], previous_fallback)

    def test_action_admission_registration_is_offline_and_preserves_fallback(self):
        suite = ci.SUITES['action_admission']
        self.assertEqual(suite['files'], ('tests/animal_harvest/test_action_admission.py',))
        self.assertEqual(suite['paths'], suite['files'])
        self.assertFalse(suite.get('always', False))
        self.assertEqual(self.selected(list(suite['files'])),
                         {'policy', 'bootstrap', 'progress', 'action_admission'})
        self.assertEqual(ci.impact(list(suite['files']))['fallback_reasons'], [])
        for path in suite['shared_paths']:
            with self.subTest(path=path):
                self.assertEqual(self.selected([path]), set(ci.SUITES))
                self.assertIn('Unmapped impact: ' + path, ci.impact([path])['fallback_reasons'])
        tree = ast.parse((ROOT/suite['files'][0]).read_text())
        self.assertEqual({alias.name for node in ast.walk(tree) if isinstance(node, ast.Import)
                          for alias in node.names}, {'re', 'unittest'})
        self.assertEqual({node.module for node in ast.walk(tree) if isinstance(node, ast.ImportFrom)},
                         {'pathlib', 'types'})
    def test_help_mood_history_offline_registration(self):
        suite = ci.SUITES['help_mood_history']
        self.assertEqual(suite['files'], ('tests/player_help/test_bridge.py',
                                          'tests/player_help/test_question_display_source.py'))
        for path in (*suite['files'], *suite['shared_paths']):
            with self.subTest(path=path):
                self.assertTrue(ci.impact([path])['suites']['help_mood_history']['selected'])
        self.assertFalse(ci.impact(['README.md'])['suites']['help_mood_history']['selected'])
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'mood-history.json'
            self.assertEqual(ci.run_unit('help_mood_history', output), 0)
            result = json.loads(output.read_text())
        self.assertEqual(result, dict(status='passed', tests=30, failures=0, errors=0, skipped=0))

    def test_help_wiki_guides_are_required_offline_for_exact_and_shared_inputs(self):
        suite = ci.SUITES['help_wiki_guides']
        self.assertEqual(suite['files'], ('tests/player_help/test_wiki_guides.py',))
        self.assertEqual(suite['paths'], ())
        tree = ast.parse((ROOT / 'scripts/player_help_bridge.py').read_text(encoding='utf-8'))
        production_sources = {node.value for node in ast.walk(tree)
                              if isinstance(node, ast.Constant) and isinstance(node.value, str)
                              and node.value.startswith('code/') and node.value.endswith('.dm')}
        self.assertTrue(production_sources)
        self.assertTrue(production_sources <= set(suite['shared_paths']))
        for path in (*suite['files'], *suite['shared_paths']):
            with self.subTest(path=path):
                self.assertTrue(ci.impact([path])['suites']['help_wiki_guides']['selected'])
        self.assertFalse(ci.impact(['README.md'])['suites']['help_wiki_guides']['selected'])
        for path in ('scripts/player_help_bridge.py', 'UI/crafting-atlas.json'):
            self.assertIn('Unmapped impact: ' + path, ci.impact([path])['fallback_reasons'])
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'wiki.json'
            self.assertEqual(ci.run_unit('help_wiki_guides', output), 0)
            result = json.loads(output.read_text())
        self.assertEqual(result, dict(status='passed', tests=12, failures=0, errors=0, skipped=0))
        plan, baseline, compiler, jobs = fixtures(('tests/player_help/test_wiki_guides.py',))
        baseline['suites']['help_wiki_guides']['counts'] = result
        self.assertEqual(ci.aggregate(plan, baseline, compiler, jobs, False), [])
        del baseline['suites']['help_wiki_guides']
        self.assertIn('Missing, failed or unexpectedly skipped suite: help_wiki_guides',
                      ci.aggregate(plan, baseline, compiler, jobs, False))

    def test_help_links_offline_registration_and_shared_fallback(self):
        suite = ci.SUITES['help_tab_links']
        self.assertEqual(suite['files'], ('tests/player_help/test_help_links.py',))
        self.assertEqual(suite['paths'], ())
        self.assertEqual(set(suite['shared_paths']), {
            'code/modules/client/client_verbs.dm', 'code/game/mob/crafting_atlas.dm'})
        for path in suite['shared_paths']:
            with self.subTest(path=path):
                decision = ci.impact([path])
                self.assertTrue(decision['suites']['help_tab_links']['selected'])
                self.assertIn('Unmapped impact: ' + path, decision['fallback_reasons'])
                self.assertTrue(all(row['selected'] for row in decision['suites'].values()))
        self.assertTrue(ci.impact(list(suite['files']))['suites']['help_tab_links']['selected'])
        self.assertFalse(ci.impact(['README.md'])['suites']['help_tab_links']['selected'])

    def test_help_links_baseline_executes_three_checks_and_aggregate_requires_it(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'help-links.json'
            self.assertEqual(ci.run_unit('help_tab_links', output), 0)
            result = json.loads(output.read_text())
            self.assertEqual(result, dict(status='passed', tests=3, failures=0, errors=0, skipped=0))
        plan, baseline, compiler, jobs = fixtures(('tests/player_help/test_help_links.py',))
        self.assertTrue(plan['baseline']['suites']['help_tab_links']['selected'])
        baseline['suites']['help_tab_links']['counts'] = result
        self.assertEqual(ci.aggregate(plan, baseline, compiler, jobs, False), [])
        baseline['suites']['help_tab_links']['counts']['tests'] = 0
        self.assertIn('Incomplete test execution: help_tab_links',
                      ci.aggregate(plan, baseline, compiler, jobs, False))
        del baseline['suites']['help_tab_links']
        self.assertIn('Missing, failed or unexpectedly skipped suite: help_tab_links',
                      ci.aggregate(plan, baseline, compiler, jobs, False))

    def test_destroyed_grab_preflight_registration_and_shared_fallback(self):
        suite = ci.SUITES['destroyed_grab_preflight']
        self.assertEqual(suite['files'], ('tests/test_destroyed_grab_preflight.py',))
        self.assertEqual(suite['paths'], ())
        self.assertEqual(set(suite['shared_paths']), {
            'code/game/mob/mob_movement.dm',
            'code/game/mob/living/carbon/human/subtile_movement.dm'})
        self.assertEqual(self.selected(suite['files']), {'policy', 'bootstrap', 'progress', 'destroyed_grab_preflight'})
        for source in suite['shared_paths']:
            with self.subTest(source=source):
                result = ci.impact([source])
                self.assertIn('Unmapped impact: ' + source, result['fallback_reasons'])
                self.assertEqual(self.selected([source]), set(ci.SUITES))
        tree = ast.parse((ROOT / suite['files'][0]).read_text())
        self.assertEqual({alias.name for node in ast.walk(tree) if isinstance(node, ast.Import)
                          for alias in node.names}, {'unittest'})
        self.assertEqual({node.module for node in ast.walk(tree) if isinstance(node, ast.ImportFrom)}, {'dataclasses', 'pathlib'})

    def test_character_traits_registration_and_shared_source_fallback(self):
        suite = ci.SUITES['character_traits']
        self.assertEqual(suite['files'], ('tests/character_traits/test_foundations.py',
                                         'tests/character_traits/test_random.py'))
        self.assertEqual(suite['paths'], ('tests/character_traits/',))
        self.assertFalse(suite.get('always', False))
        for path in (*suite['files'], 'tests/character_traits/README.md'):
            with self.subTest(path=path):
                self.assertEqual(self.selected([path]), {'policy', 'bootstrap', 'progress', 'character_traits'})
                self.assertEqual(ci.impact([path])['fallback_reasons'], [])
        expected_sources = {
            'code/game/mob/living/carbon/human/traits.dm',
            'code/modules/client/preferencesSQLite/preference_setup/general/01_basic.dm',
            'code/modules/client/preferencesSQLite/preferences.dm',
            'code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm',
            'code/game/mob/living/carbon/human/human_life.dm',
            'code/game/mob/living/carbon/human/human_stats.dm',
        }
        self.assertEqual(set(suite['shared_paths']), expected_sources)
        for path in expected_sources:
            with self.subTest(shared=path):
                self.assertIn('Unmapped impact: ' + path, ci.impact([path])['fallback_reasons'])
                self.assertEqual(self.selected([path]), set(ci.SUITES))
        for path, imports, from_imports in (
            (suite['files'][0], {'re', 'unittest'}, {'pathlib'}),
            (suite['files'][1], {'random', 'unittest'}, {'test_foundations'}),
        ):
            tree = ast.parse((ROOT / path).read_text())
            self.assertEqual({alias.name for node in ast.walk(tree) if isinstance(node, ast.Import)
                              for alias in node.names}, imports)
            self.assertEqual({node.module for node in ast.walk(tree) if isinstance(node, ast.ImportFrom)}, from_imports)

    def test_failing_character_traits_child_fails_baseline_and_required_aggregate(self):
        # Run the actual registered child on copied production inputs. Only the
        # unrelated mandatory suites use passing adapters to avoid recursion.
        suite_name = 'character_traits'
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for relative in ('scripts/ci_baseline.py', 'scripts/byond_toolchain.py',
                             'tools/byond/version.json', *ci.SUITES[suite_name]['files'],
                             *ci.SUITES[suite_name]['shared_paths']):
                destination = root / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, destination)

            def git(*args):
                return subprocess.check_output(['git', '-C', temporary, *args],
                                               stderr=subprocess.PIPE, timeout=10).decode().strip()

            git('init')
            git('config', 'user.name', 'Trait CI fixture')
            git('config', 'user.email', 'ci@example.invalid')
            git('add', '.')
            git('commit', '-qm', 'passing trait CI fixture')
            real_run = ci.subprocess.run

            def child(command, **kwargs):
                if 'unit' not in command:
                    return real_run(command, **kwargs)
                if command[command.index('--suite') + 1] == suite_name:
                    command = list(command)
                    command[2] = str(root / 'scripts/ci_baseline.py')
                    return real_run(command, **(kwargs | {'cwd': root}))
                ci.write_json(command[command.index('--output') + 1], dict(
                    status='passed', tests=1, errors=0, failures=0, skipped=0))
                return subprocess.CompletedProcess(command, 0)

            for failing in (False, True):
                with self.subTest(failing=failing):
                    if failing:
                        # Mutate only the isolated copy: the selected real test
                        # must fail when the zero-total commit guard is removed.
                        target = root / ci.SUITES[suite_name]['shared_paths'][1]
                        target.write_text(target.read_text().replace('check_trait_points(candidate) != 0', 'FALSE'))
                        git('add', '.')
                        git('commit', '-qm', 'isolated missing zero-total guard control')
                    plan, _, compiler, jobs = fixtures(('tests/character_traits/test_random.py',))
                    plan['head'] = compiler['head'] = git('rev-parse', 'HEAD')
                    compiler['selection_sha256'] = ci.digest(plan)
                    evidence = root / ('negative' if failing else 'positive')
                    with patch.object(ci, 'ROOT', root), patch.object(ci.subprocess, 'run', side_effect=child), \
                            patch.dict(os.environ, {'GITHUB_RUN_ATTEMPT': '1'}), patch('builtins.print'):
                        exit_code = ci.execute(plan, evidence)
                    baseline = json.loads((evidence / 'baseline.json').read_text())
                    traits = baseline['suites'][suite_name]
                    self.assertEqual(exit_code, int(failing))
                    self.assertEqual(baseline['status'], 'failed' if failing else 'passed')
                    self.assertTrue(baseline['source_unchanged'])
                    self.assertFalse(baseline['tracked_dirty'])
                    self.assertFalse(baseline['tracked_dirty_after'])
                    self.assertEqual(traits['exit_code'], int(failing))
                    self.assertEqual(traits['counts'], dict(status='failed' if failing else 'passed',
                        tests=16, failures=int(failing), errors=0, skipped=0))
                    self.assertEqual(traits['files'], list(ci.SUITES[suite_name]['files']))
                    errors = ci.aggregate(plan, baseline, compiler, jobs, False)
                    if failing:
                        self.assertIn('check_trait_points(candidate) != 0', (evidence / 'character_traits.log').read_text())
                        self.assertIn('Baseline did not pass', errors)
                        self.assertIn('Missing, failed or unexpectedly skipped suite: character_traits', errors)
                        self.assertIn('Incomplete test execution: character_traits', errors)
                    else:
                        self.assertEqual(errors, [])

    def test_grinder_registration_preserves_shared_source_fallback(self):
        suite = ci.SUITES['grinder']
        self.assertEqual(suite['files'], ('tests/grinder/test_transaction.py',))
        self.assertEqual(suite['paths'], ('tests/grinder/',))
        self.assertFalse(suite.get('always', False))
        for path in ('tests/grinder/test_transaction.py', 'tests/grinder/historical-grinder.dm'):
            with self.subTest(path=path):
                self.assertEqual(self.selected([path]), {'policy', 'bootstrap', 'progress', 'grinder'})
                self.assertEqual(ci.impact([path])['fallback_reasons'], [])
        for path in suite['shared_paths']:
            with self.subTest(path=path):
                self.assertEqual(self.selected([path]), set(ci.SUITES))
                self.assertIn('Unmapped impact: ' + path, ci.impact([path])['fallback_reasons'])
        self.assertEqual(self.selected(['unknown-grinder-impact.dm']), set(ci.SUITES))
        tree = ast.parse((ROOT / suite['files'][0]).read_text())
        imports = {node.names[0].name.split('.')[0] for node in ast.walk(tree) if isinstance(node, ast.Import)}
        self.assertEqual(imports, {'ast', 'heapq', 'math', 're', 'unittest'})
        self.assertEqual({node.module for node in ast.walk(tree) if isinstance(node, ast.ImportFrom)}, {'pathlib'})

    def test_failing_grinder_child_fails_selected_baseline_and_aggregate(self):
        # Stage exact reviewed inputs; never mutate production or launch DM.
        # Only unrelated mandatory suites use passing adapters to avoid recursively
        # running this policy test inside its own selected baseline fixture.
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for relative in ('scripts/ci_baseline.py', 'scripts/byond_toolchain.py',
                             'tools/byond/version.json', *ci.SUITES['grinder']['files'],
                             'tests/grinder/historical-grinder.dm',
                             'code/modules/reagents/Chemistry-Machinery.dm',
                             'code/modules/materials/material_sheets.dm',
                             'code/game/objects/structures/kitchen/oven.dm',
                             'code/modules/1713/wood_ash_compost.dm',
                             'code/game/objects/structures.dm',
                             'code/game/objects/items/stacks/civ_recipes.dm',
                             'code/modules/research_tree/research_node.dm',
                             'config/crafting/material_recipes_global.txt',
                             'config/crafting/material_recipes_camp.txt',
                             'config/crafting/material_recipes_carib.txt',
                             'code/game/objects/items/stacks/stack.dm'):
                destination = root / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, destination)
            def git(*args):
                return subprocess.check_output(['git', '-C', temporary, *args],
                                               stderr=subprocess.PIPE, timeout=10).decode().strip()
            git('init')
            git('config', 'user.name', 'Grinder CI fixture')
            git('config', 'user.email', 'ci@example.invalid')
            git('add', '.')
            git('commit', '-qm', 'passing grinder fixture')
            real_run = ci.subprocess.run
            def child(command, **kwargs):
                if 'unit' not in command:
                    return real_run(command, **kwargs)
                if command[command.index('--suite') + 1] == 'grinder':
                    command = list(command)
                    command[2] = str(root / 'scripts/ci_baseline.py')
                    return real_run(command, **(kwargs | {'cwd': root}))
                ci.write_json(command[command.index('--output') + 1], dict(
                    status='passed', tests=1, errors=0, failures=0, skipped=0))
                return subprocess.CompletedProcess(command, 0)
            passing_test_count = None
            for failing in (False, True):
                with self.subTest(failing=failing):
                    if failing:
                        test_file = root / ci.SUITES['grinder']['files'][0]
                        with test_file.open('a', encoding='utf-8') as output:
                            output.write('\nclass GrinderCiFailureControl(unittest.TestCase):\n'
                                         '    def test_selected_grinder_failure(self):\n'
                                         '        self.fail("intentional grinder CI failure")\n')
                        git('add', '.')
                        git('commit', '-qm', 'intentional isolated grinder test failure')
                    head = git('rev-parse', 'HEAD')
                    plan, _, compiler, jobs = fixtures(('tests/grinder/test_transaction.py',))
                    plan['head'] = compiler['head'] = head
                    compiler['selection_sha256'] = ci.digest(plan)
                    evidence = root / ('negative' if failing else 'positive')
                    with patch.object(ci, 'ROOT', root), patch.object(ci.subprocess, 'run', side_effect=child), \
                            patch.dict(os.environ, {'GITHUB_RUN_ATTEMPT': '1'}), patch('builtins.print'):
                        exit_code = ci.execute(plan, evidence)
                    baseline = json.loads((evidence / 'baseline.json').read_text())
                    grinder = baseline['suites']['grinder']
                    expected_status = 'failed' if failing else 'passed'
                    self.assertEqual(exit_code, int(failing))
                    self.assertEqual(baseline['status'], expected_status)
                    self.assertTrue(baseline['source_unchanged'])
                    self.assertFalse(baseline['tracked_dirty'])
                    self.assertFalse(baseline['tracked_dirty_after'])
                    self.assertEqual(grinder['exit_code'], int(failing))
                    if not failing:
                        passing_test_count = grinder['counts']['tests']
                        self.assertGreater(passing_test_count, 0)
                    self.assertEqual(grinder['counts'], dict(status=expected_status,
                        tests=passing_test_count + int(failing),
                        failures=int(failing), errors=0, skipped=0))
                    self.assertEqual(grinder['files'], ['tests/grinder/test_transaction.py'])
                    self.assertIn('--suite', grinder['command'])
                    errors = ci.aggregate(plan, baseline, compiler, jobs, False)
                    if failing:
                        self.assertIn('intentional grinder CI failure', (evidence / 'grinder.log').read_text())
                        self.assertIn('Baseline did not pass', errors)
                        self.assertIn('Missing, failed or unexpectedly skipped suite: grinder', errors)
                        self.assertIn('Incomplete test execution: grinder', errors)
                    else:
                        self.assertEqual(errors, [])

    def test_character_return_preparation_selects_actual_source_and_helper_inputs(self):
        manifest = json.loads((ROOT / 'tests/world_save/character_return/inputs.json').read_text())
        inputs = set(manifest['reference_sha256'])
        for relative in ('tests/world_save/character_return/prepare.py',
                         'tests/world_save/run-cross-level.py',
                         'tests/world_save/test_roundtrip_compat.py',
                         'tests/world_save/run-restart-transaction.py'):
            tree = ast.parse((ROOT / relative).read_text())
            inputs.add(relative)
            inputs.update(node.value for node in ast.walk(tree)
                          if isinstance(node, ast.Constant) and isinstance(node.value, str)
                          and node.value.startswith(('code/', 'tests/'))
                          and node.value.endswith(('.py', '.dm', '.dme', '.json')))
        for path in sorted(inputs):
            with self.subTest(input=path):
                self.assertIn('character_return_preparation', self.selected([path]))

    def test_character_shared_inputs_keep_conservative_unmapped_fallback(self):
        self.assertIn('character_return', self.selected(['code/game/gameticker.dm']))
        for path in ('code/predefines.dm', 'code/_macros.dm',
                     'tests/new_z_budget/z_budget_evidence.py'):
            with self.subTest(input=path):
                result = ci.impact([path])
                self.assertIn('Unmapped impact: ' + path, result['fallback_reasons'])
                self.assertEqual(self.selected([path]), set(ci.SUITES))

    def test_character_return_selects_all_direct_source_inputs(self):
        tree = ast.parse((ROOT / ci.SUITES['character_return']['files'][0]).read_text())
        inputs = {node.value for node in ast.walk(tree)
                  if isinstance(node, ast.Constant) and isinstance(node.value, str)
                  and node.value.startswith('code/') and node.value.endswith('.dm')}
        self.assertIn('code/modules/persistence/functions.dm', inputs)
        for path in sorted(inputs):
            with self.subTest(input=path):
                self.assertIn('character_return', self.selected([path]))

    def test_character_return_other_shared_reads_keep_unknown_fallback(self):
        for path in ('code/game/mob/living/carbon/carbon_defines.dm',
                     'code/game/mob/living/carbon/human/nomads_spawn.dm',
                     'code/game/mob/living/carbon/human/human_life.dm'):
            with self.subTest(input=path):
                self.assertIn('Unmapped impact: ' + path, ci.impact([path])['fallback_reasons'])
                self.assertEqual(self.selected([path]), set(ci.SUITES))

    def test_crop_stage_step_selection_preserves_shared_farming_fallback(self):
        suite = ci.SUITES['crop_stage_step']
        self.assertEqual(suite['files'], ('tests/crop_stage_step/test_source.py',))
        for path in ('tests/crop_stage_step/test_source.py',
                     'tests/crop_stage_step/baseline_growth.json',
                     'tests/plant_lifecycle/run.ps1'):
            self.assertIn('crop_stage_step', self.selected([path]))
        self.assertEqual(self.selected(['code/game/objects/farming.dm']), set(ci.SUITES))

    def test_furniture_joinery_inputs_select_offline_contracts(self):
        for path in ('tests/furniture_joinery/test_contract.py',
                     'code/game/objects/items/stacks/furniture_joinery.dm',
                     'config/crafting/furniture_joinery.json', 'scripts/audit-crafting-recipes.py'):
            self.assertIn('furniture_joinery', self.selected([path]))
        self.assertIn('furniture_joinery', self.selected(['code/modules/1713/cutting_board.dm']))
        self.assertEqual(self.selected(['code/modules/reagents/reagent_containers/glass.dm']), set(ci.SUITES))
        for dependency in ('tests/primitive_woodworking/source_adapter.py',
                           'code/modules/persistence/functions.dm',
                           'code/modules/reagents/reagent_containers/food.dm'):
            self.assertIn('furniture_joinery', self.selected([dependency]))
        # Shared chemistry keeps conservative fallback coverage for every suite,
        # including water-treatment consumers and the cutting-board threshold.
        for shared in ('code/modules/reagents/Chemistry-Holder.dm', 'code/__defines/chemistry.dm'):
            self.assertEqual(self.selected([shared]), set(ci.SUITES))
        self.assertEqual(ci.SUITES['furniture_joinery']['files'], ('tests/furniture_joinery/test_contract.py', 'tests/furniture_joinery/test_wooden_shelf.py', 'tests/furniture_joinery/test_bedroll.py', 'tests/furniture_joinery/test_document_drawers.py', 'tests/furniture_joinery/test_sofa_materials.py', 'tests/furniture_joinery/test_canopy.py', 'tests/furniture_joinery/test_cutting_board.py', 'tests/furniture_joinery/test_barrel_ingredients.py', 'tests/furniture_joinery/test_glass_extraction.py', 'tests/furniture_joinery/test_glass_cotton.py'))
        for path in ('code/game/objects/items/stacks/stack.dm', 'scripts/build-crafting-atlas.py',
                     'config/crafting/material_recipes_global.txt'):
            self.assertEqual(self.selected([path]), set(ci.SUITES))

    def test_los_event_identity_comes_from_validated_plan(self):
        plan, _, _, _ = fixtures()
        with patch.dict(os.environ, {'LOS_EVENT_BASE': 'stale', 'LOS_EVENT_HEAD': 'stale'}):
            environment = ci.suite_environment('los_context', plan)
        self.assertEqual(environment['LOS_EVENT_BASE'], plan['base'])
        self.assertEqual(environment['LOS_EVENT_HEAD'], plan['head'])
        plan['base'] = None
        self.assertEqual(ci.suite_environment('los_context', plan)['LOS_EVENT_BASE'], '')

    def test_visibility_selects_only_explicit_offline_file(self):
        self.assertEqual(ci.SUITES['los_context']['files'], ('tests/los_context/test_offline.py',
            'tests/los_context/test_production.py', 'tests/los_context/test_tile_motion.py',
            'tests/test_geometric_presentation.py',
            'tests/test_visibility_diagnostics.py'))
        self.assertIn('los_context', self.selected(['code/modules/visibility/los_context.dm']))
        self.assertIn('los_context', self.selected(['code/_onclick/hud/hover_name.dm']))

    def test_visibility_shared_motion_inputs_select_los_without_fallback(self):
        inputs = ('code/game/atoms_movable.dm', 'tests/save_movement/source_adapter.py')
        suite = ci.SUITES['los_context']
        for path in inputs:
            with self.subTest(path=path):
                result = ci.impact([path])
                self.assertEqual(result['fallback_reasons'], [])
                self.assertTrue(result['suites']['los_context']['selected'])
                self.assertEqual(result['suites']['los_context']['reason'], ['Affected input: ' + path])
                # Existing exclusive owners suppress fallback. Omitting this
                # shared read must reproduce the previously skipped LOS suite.
                remaining = tuple(p for p in suite.get('shared_paths', ()) if p != path)
                with patch.dict(suite, shared_paths=remaining):
                    self.assertNotIn('los_context', self.selected([path]))
                    self.assertEqual(ci.impact([path])['fallback_reasons'], [])

    def test_woodworking_runs_on_production_or_modified_test_changes_without_extensive(self):
        self.assertEqual(ci.SUITES['woodworking']['files'],('tests/primitive_woodworking/test_source.py','tests/test_atlas_navigation.py'))
        dedicated=('code/modules/1713/primitive_woodworking.dm',
                   'scripts/atlas/woodworking.py',
                   'scripts/atlas/woodworking-contract.json',
                   'tests/primitive_woodworking/test_source.py',
                   'tests/primitive_woodworking/source_adapter.py')
        for path in dedicated:
            with self.subTest(path=path):
                result=ci.impact([path])
                self.assertTrue(result['suites']['woodworking']['selected'])
                self.assertFalse(result['fallback_reasons'])
                # No extensive/new-test condition: every selected woodworking
                # run loads the existing complete regenerated-catalog comparison.
                self.assertIn('tests/test_atlas_navigation.py',ci.SUITES['woodworking']['files'])
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

    def test_woodworking_production_and_projector_only_changes_check_full_atlas(self):
        for path in ('code/modules/1713/primitive_woodworking.dm','scripts/atlas/woodworking.py'):
            with self.subTest(only_changed_input=path):
                plan=ci.impact([path])
                self.assertTrue(plan['suites']['woodworking']['selected'])
                files=ci.SUITES['woodworking']['files']
                self.assertIn('tests/test_atlas_navigation.py',files)
                test=(ROOT/'tests/test_atlas_navigation.py').read_text()
                self.assertIn('test_committed_catalog_matches_current_source',test)
                self.assertIn("'--catalog-only', '--game-catalog'",test)
                self.assertIn("self.assertEqual(self.catalog_bytes, (ROOT/'UI/crafting-atlas.json').read_bytes())",test)

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
        self.assertIn("Path(__file__).with_name('historical-ping.txt').read_bytes()", source)
        self.assertIn('ping', self.selected(['tests/ping_scheduler/historical-ping.txt']))
        self.assertIn('research', self.selected(['tests/research_scheduler/historical-research.txt']))
        self.assertEqual(self.selected(['code/processes/__processScheduler.dm']),
                         {'policy', 'bootstrap', 'progress', 'research'})

    def test_hub_status_inputs_select_only_reviewed_offline_contracts(self):
        self.assertEqual(ci.SUITES['hub_status']['files'], ('tests/test_hub_status.py',))
        for path in ('code/world.dm', 'config/config.txt', 'tests/test_hub_status.py'):
            with self.subTest(path=path):
                expected = {'policy', 'bootstrap', 'progress', 'hub_status'}
                if path == 'code/world.dm':
                    expected.add('dictionary')
                    expected.add('character_return_preparation')
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


class AdminCareSelection(unittest.TestCase):
    def test_care_source_suite_selects_shared_renderer_without_claiming_it(self):
        path = 'code/modules/visibility/root_tree_presenter.dm'
        plan = ci.impact([path])
        self.assertTrue(plan['suites']['admin_player_care']['selected'])
        self.assertFalse(plan['fallback_reasons'])
        self.assertEqual(ci.SUITES['admin_player_care']['files'],
                         ('tests/admin_player_care/test_player_care.py',
                          'tests/admin_player_care/test_hud_refresh.py'))
        self.assertNotIn(path, ci.SUITES['admin_player_care']['paths'])
        # Removing this owned-elsewhere dependency must lose care coverage:
        # it cannot be rescued by the conservative unmapped-input fallback.
        original = ci.SUITES['admin_player_care']
        try:
            ci.SUITES['admin_player_care'] = dict(original, shared_paths=())
            self.assertFalse(ci.impact([path])['suites']['admin_player_care']['selected'])
        finally:
            ci.SUITES['admin_player_care'] = original


if __name__ == '__main__':
    unittest.main()
