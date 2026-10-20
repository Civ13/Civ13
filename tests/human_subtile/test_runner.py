"""Public staging/receipt controls, without BYOND or network calls."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('human_subtile_runner', HERE / 'run.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class RunnerContracts(unittest.TestCase):
    def fixture_repository(self, directory):
        root = Path(directory) / 'repo'
        root.mkdir()
        files = {'civ13.dme': '#include "code\\world.dm"\n#include "maps\\removed.dmm"\n',
                 'code/world.dm': '/datum/global_init/New()\n\tinitialize()\n/world/New()\n\t..()\n\tstartup()\n',
                 'code/controllers/mc/globals.dm': '/datum/controller/global_vars/New()\n\tinitialize()\n',
                 'tests/human_subtile/mining.dm': '// integration fixture\n',
                 'code/game/turfs/floor_attackby.dm': '// actor.step_x == sx && actor.step_y == sy && guard\n',
                 'tests/human_subtile/probe.dm': '/client/New()\n\tdel(src)\n/world/Topic()\n\treturn null\n/world/New()\n\tOpenPort("none")\n',
                 'tests/subtile_movement/prototype.dme': '#include "kernel.dm"\n#include "fixture.dm"\n',
                 'tests/subtile_movement/kernel.dm': '// actual primitive\n',
                 'tests/subtile_movement/fixture.dm': '// closed primitive\n',
                 'config/names/example.txt': 'Public name\n',
                 'icons/fixture.dmi': 'test resource',
                 'unrelated-private.txt': 'must not enter snapshot'}
        for rel, value in files.items():
            destination = root / rel
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(value, encoding='utf-8')
        def git(*args):
            return subprocess.check_output(['git', '-C', str(root), *args], stderr=subprocess.PIPE)
        git('init')
        git('add', '.')
        git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-m', 'fixture')
        return root, files, git('rev-parse', 'HEAD').decode().strip()

    def test_prepare_uses_exact_git_objects_and_preserves_closed_probe(self):
        with tempfile.TemporaryDirectory() as directory:
            root, files, head = self.fixture_repository(directory)
            (root / 'tests/human_subtile/probe.dm').write_text('UNCOMMITTED SHOULD NOT ENTER')
            out = Path(directory) / 'evidence'
            manifest = runner.prepare(root, out, 'human')
            self.assertEqual(manifest['head'], head)
            self.assertFalse(manifest['native_executed'])
            self.assertEqual((out / 'stage/tests/human_subtile/probe.dm').read_text(), files['tests/human_subtile/probe.dm'])
            self.assertNotIn('maps\\removed.dmm', (out / 'stage/human_subtile.dme').read_text())
            self.assertIn('#include "tests\\human_subtile\\probe.dm"', (out / 'stage/human_subtile.dme').read_text())
            self.assertFalse((out / 'stage/unrelated-private.txt').exists())
            self.assertFalse((out / 'stage/private_visual_adapter.dm').exists())
            self.assertEqual(set(manifest['adaptations']), {'code/world.dm', 'code/controllers/mc/globals.dm'})
            self.assertEqual((out / 'stage/config/config.txt').read_bytes(), b'')
            self.assertEqual(json.loads((out / 'source-manifest.json').read_text())['head'], head)

    def test_mining_control_changes_only_staged_position_guard(self):
        with tempfile.TemporaryDirectory() as directory:
            root, files, head = self.fixture_repository(directory)
            out = Path(directory) / 'mining'
            manifest = runner.prepare(root, out, 'mining', 'mining-position')
            rel = 'code/game/turfs/floor_attackby.dm'
            self.assertEqual((root / rel).read_text(), files[rel])
            self.assertNotIn('actor.step_x == sx', (out / 'stage' / rel).read_text())
            self.assertIn(rel, manifest['adaptations'])
            self.assertEqual(manifest['head'], head)
            self.assertFalse(manifest['native_executed'])
            self.assertEqual((out / 'stage/tests/human_subtile/mining.dm').read_text(), files['tests/human_subtile/mining.dm'])

    def test_mining_receipt_rejects_missing_cases_checks_and_unrelated_failure(self):
        rows = [dict(enabled=enabled, sy=sy, client=0, effects=1, bumps=3)
                for enabled, sy in ((0, 0), (1, 0), (1, 4), (1, 28))]
        receipt = dict(head='abc', byond_version=516, byond_build=1681,
                       error=None, mining_checks=52, mining_rows=rows)
        runner.validate_receipt(receipt, 'mining', 'none', 'abc')
        for key, value in [('head', 'wrong'), ('mining_checks', 51),
                           ('error', 'mining_native_collision_dispatch'), ('mining_rows', rows[:3])]:
            bad = copy.deepcopy(receipt)
            bad[key] = value
            with self.assertRaises(ValueError):
                runner.validate_receipt(bad, 'mining', 'none', 'abc')
        for key, value in [('effects', 2), ('client', 1), ('bumps', 0), ('sy', 1)]:
            bad = copy.deepcopy(receipt)
            bad['mining_rows'][0][key] = value
            with self.assertRaises(ValueError):
                runner.validate_receipt(bad, 'mining', 'none', 'abc')
        receipt.update(error='mining_drift_rejected', mining_checks=24)
        runner.validate_receipt(receipt, 'mining', 'mining-position', 'abc')
        for key, value in [('error', None), ('error', 'mining_second_snapshot'), ('mining_checks', 11)]:
            bad = copy.deepcopy(receipt)
            bad[key] = value
            with self.assertRaises(ValueError):
                runner.validate_receipt(bad, 'mining', 'mining-position', 'abc')

    def test_primitive_snapshot_does_not_import_game_or_change_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            root, files, _ = self.fixture_repository(directory)
            out = Path(directory) / 'primitive'
            manifest = runner.prepare(root, out, 'primitive', 'cosmetic')
            self.assertEqual(manifest['adaptations'], {})
            self.assertEqual(len(manifest['original_git_files']), 3)
            self.assertFalse((out / 'stage/code').exists())
            self.assertEqual((out / 'stage/tests/subtile_movement/kernel.dm').read_text(), files['tests/subtile_movement/kernel.dm'])
            with self.assertRaises(ValueError):
                runner.prepare(root, out, 'primitive')

    def test_unknown_controls_and_startup_drift_fail_closed(self):
        for suite, control in (('human', 'cosmetic'), ('other', 'none'), ('primitive', 'other')):
            with self.assertRaises(ValueError):
                runner.prepare(ROOT, ROOT / 'must-not-be-created', suite, control)
        with self.assertRaises(ValueError):
            runner.isolate_startup('code/controllers/mc/globals.dm', '// missing anchor')
        with self.assertRaises(ValueError):
            runner.isolate_startup('unknown.dm', '')

    def test_exact_human_receipt_and_omission_controls(self):
        row = {'head': 'a' * 40, 'byond_version': 516, 'byond_build': 1681,
               'checks': 42, 'error': None, 'rows': [{'scene': 'normal', 'rows':
                [{'sx': 4, 'locs': 2, 'native': 4}] + [{'native': 4}] * 7}]}
        runner.validate_receipt(row, 'human', 'none', 'a' * 40)
        for key, value in (('head', 'b' * 40), ('checks', 41), ('error', 'failed'),
                           ('byond_build', 1688), ('rows', [])):
            with self.assertRaises(ValueError):
                runner.validate_receipt(dict(row, **{key: value}), 'human', 'none', 'a' * 40)
        for field, value in (('sx', 0), ('locs', 1), ('native', 1)):
            wrong = copy.deepcopy(row)
            wrong['rows'][0]['rows'][0][field] = value
            with self.assertRaises(ValueError):
                runner.validate_receipt(wrong, 'human', 'none', 'a' * 40)

    def test_primitive_control_requires_exact_physical_failure(self):
        before = dict(x=2, y=2, z=1, sx=0, sy=0)
        row = dict(byond_version=516, byond_build=1681, port=0, checks=3,
                   failed=['physical_east_four_pixels'], control='cosmetic',
                   error='physical_east_four_pixels', observations=[dict(name='first_east', before=before, after=dict(before))])
        runner.validate_receipt(row, 'primitive', 'cosmetic', 'a' * 40)
        with self.assertRaises(ValueError):
            runner.validate_receipt(dict(row, error='unrelated'), 'primitive', 'cosmetic', 'a' * 40)

    def test_windows_native_execution_refused_before_any_launch(self):
        with patch.object(runner.os, 'name', 'nt'), patch.object(runner.subprocess, 'Popen') as launch:
            with self.assertRaisesRegex(RuntimeError, 'Linux CI only'):
                runner.execute(HERE, {}, HERE)
            launch.assert_not_called()

    def test_phase_timeout_reaps_only_the_owned_process_group(self):
        process = Mock(pid=73001, returncode=-9)
        process.poll.return_value = None
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(runner.subprocess, 'Popen', return_value=process) as launch, \
                    patch.object(runner.time, 'monotonic', side_effect=[0, 181, 181]), \
                    patch.object(runner.signal, 'SIGKILL', 9, create=True), \
                    patch.object(runner.os, 'killpg', create=True) as kill:
                with self.assertRaisesRegex(RuntimeError, 'Native phase failed'):
                    runner.run_process(['injected-no-native'], Path(directory), 'timeout', 180)
                self.assertTrue(launch.call_args.kwargs['start_new_session'])
                kill.assert_called_once_with(73001, runner.signal.SIGKILL)
                process.wait.assert_called_once_with(timeout=10)

    def test_binary_and_output_root_are_identical_for_both_suites(self):
        for suite, rel in (('human', 'stage/human_subtile.dme'),
                           ('primitive', 'stage/tests/subtile_movement/prototype.dme')):
            with self.subTest(suite=suite), tempfile.TemporaryDirectory() as directory:
                out = Path(directory)
                dme = out / rel
                dme.parent.mkdir(parents=True)
                dme.with_suffix('.dmb').write_bytes(b'compiled fixture')
                if suite == 'human':
                    dme.with_suffix('.rsc').write_bytes(b'actual resources')
                    (out / 'stage/config/names').mkdir(parents=True)
                    (out / 'stage/config/names/fixture.txt').write_bytes(b'public name')
                manifest = {'suite': suite, 'dme': rel}
                work, binary, artifacts = runner.prepare_runtime(out, manifest)
                self.assertEqual(work, out / 'runtime')
                self.assertEqual(binary.parent, work)
                self.assertEqual(binary.read_bytes(), b'compiled fixture')
                self.assertIn(binary.name, artifacts)
                self.assertEqual((work / 'config/names/fixture.txt').exists(), suite == 'human')
                self.assertEqual((work / dme.with_suffix('.rsc').name).exists(), suite == 'human')

    def test_daemon_uses_explicit_runtime_binary_cwd_and_marker_root(self):
        # Inject compiler/daemon only; a stale stage-root marker must never win.
        with tempfile.TemporaryDirectory() as directory:
            out = Path(directory)
            stage = out / 'stage'
            stage.mkdir()
            tools = out / 'bin'
            tools.mkdir()
            for executable in ('DreamMaker', 'DreamDaemon'):
                (tools / executable).write_bytes(b'not executed')
            manifest = {'suite': 'primitive', 'control': 'cosmetic',
                        'head': 'a' * 40, 'dme': 'stage/prototype.dme'}
            (stage / 'prototype.dmb').write_bytes(b'compiled')
            (stage / 'result.txt').write_bytes(b'PASS\n')
            (stage / 'port-closed.txt').write_bytes(b'closed\n')
            calls = []
            def phase(command, cwd, name, deadline):
                calls.append((command, cwd, name))
                if name == 'compile':
                    (stage / 'compile-stdout.log').write_text('DM compiler version 516.1681\nprototype.dmb - 0 errors, 0 warnings\n')
                    (stage / 'compile-stderr.log').write_text('')
                else:
                    self.assertEqual(command[1], str(cwd / 'prototype.dmb'))
                    self.assertEqual(cwd, out / 'runtime')
                    (cwd / 'port-closed.txt').write_bytes(b'closed\n')
                    (cwd / 'result.txt').write_bytes(b'FAIL physical_east_four_pixels\n')
                    (cwd / 'receipt.json').write_text('{}')
                return {'returncode': 0}
            with patch.object(runner.os, 'name', 'posix'), \
                    patch.object(runner, 'run_process', side_effect=phase), \
                    patch.object(runner, 'validate_receipt') as validate:
                result = runner.execute(out, manifest, tools)
                self.assertTrue(result['accepted'])
                validate.assert_called_once_with({}, 'primitive', 'cosmetic', 'a' * 40)
            self.assertEqual(len(calls), 2)

    def test_full_diagnostic_policy_includes_nested_runtime_text_and_bounds(self):
        for text in ('infinite loop', 'infinite_loop', 'unexpected runtime',
                     'CRASH', 'CRASHED', 'OOM', 'out of memory', 'access violation', 'invalid file'):
            with self.subTest(text=text), tempfile.TemporaryDirectory() as directory:
                work = Path(directory)
                log = work / 'data/logs/runtime/fixture.txt'
                log.parent.mkdir(parents=True)
                log.write_text(text)
                with self.assertRaisesRegex(RuntimeError, 'Native diagnostic'):
                    runner.inspect_logs(work)
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            log = work / 'data/logs/runtime/large.txt'
            log.parent.mkdir(parents=True)
            log.write_bytes(b'x' * (4 * 1024**2 + 1))
            with self.assertRaisesRegex(RuntimeError, 'Oversized diagnostic'):
                runner.inspect_logs(work, check_diagnostics=False)

    def test_compile_requires_one_clean_pinned_result_without_warning_noise(self):
        good = 'DM compiler version 516.1681\nprototype.dmb - 0 errors, 0 warnings (10/19/26 1:05 pm)\n'
        runner.validate_compile(good, 'prototype.dmb')
        for bad in (good + good, good.replace('1681', '1688'),
                    good + 'warning: invalid file\n', good + 'warning: unrelated\n',
                    good.replace('0 errors, 0 warnings', '0 errors, 1 warning'),
                    'prototype.dmb - 0 errors, 0 warnings\nDM compiler version 516.1681\n'):
            with self.assertRaises(RuntimeError):
                runner.validate_compile(bad, 'prototype.dmb')

    def test_minimal_serializer_stub_rejects_owned_entries(self):
        stub = (ROOT / 'tests/world_save/stubs.dm').read_text()
        start = stub.index('/mob/living/human/proc/human_subtile_prepare_import(savefile/F)')
        body = stub[start:stub.index('/mob/living/human/proc/rejuvenate()', start)]
        self.assertIn('if ("human_subtile_position" in F.dir)', body)
        self.assertIn('throw EXCEPTION("Sub-tile restoration requires the full-source human fixture")', body)
        self.assertNotIn('F[', body)  # Optional-field inspection must not create it.
        self.assertNotIn('Move(', body)

    def test_ci_selection_covers_both_new_suites_with_unique_guard(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        self.assertEqual(workflow.count('- name: Verify opt-in human and primitive sub-tile movement'), 1)
        block = workflow.split('- name: Verify opt-in human and primitive sub-tile movement', 1)[1].split('      - name:', 1)[0]
        for suite in ('tests/human_subtile', 'tests/subtile_movement'):
            self.assertIn("contains(fromJSON(needs.changes.outputs.new_tests), '" + suite + "')", block)
        self.assertIn('--suite primitive --control cosmetic', block)
        self.assertIn('--suite human', block)
        self.assertIn('steps.human_subtile.outputs.started', workflow)


if __name__ == '__main__':
    unittest.main(verbosity=2)
