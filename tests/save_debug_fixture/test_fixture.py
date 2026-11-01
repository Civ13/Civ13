"""Offline controller and staging contracts; no compiler or daemon runs."""
import copy
import json
from pathlib import Path
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest import mock

import controller
import stage


def evidence():
    generation = 'round-v2:' + '1' * 32
    seed = 'round-v2:' + '2' * 32
    incident = {'kind': 'moved_leaf_animal', 'action': 'omit_entity_and_replace_references_with_null',
                'child_type': '/mob/living/simple_animal/debug_save_fixture', 'child_ref': 'synthetic', 'parent_ref': 'box'}
    audit = {'mode': 'debug_lossy', 'outcome': 'candidate_commit_intent', 'generation': generation,
             'attempt': 2, 'incidents': [incident],
             'attempt_history': [{'attempt': 1, 'outcome': 'failed_retryable'}],
             'omissions': [{'target_ref': 'synthetic', 'target_type': incident['child_type'], 'source_type': '/obj/structure/debug_save_fixture', 'source_ref': 'box', 'field': 'fixture_reference', 'replacement': 'null_reference'},
                           {'target_ref': 'synthetic', 'target_type': incident['child_type'], 'replacement': 'null_reference', 'list_location': {'z': 1, 'list_id': 2, 'index': 1, 'side': 'key'}},
                           {'target_ref': 'synthetic', 'target_type': incident['child_type'], 'replacement': 'null_reference', 'list_location': {'z': 1, 'list_id': 2, 'index': 3, 'side': 'value'}}]}
    writer = {'generation': generation, 'seed_generation': seed, 'fixture_moves': 2, 'audit': audit,
              'controls': {'unsupported_contents': True, 'missing_child': True, 'associated_key': True, 'owner_bound': True, 'owner_lost': True}}
    reader = {'generation': generation, 'audit': copy.deepcopy(audit), 'retained_box': True,
              'retained_item': True, 'retained_control_item': True, 'omitted_animal': True, 'reference_null': True,
              'nested_alias_and_cycle': True, 'nested_losses_and_neighbor': True}
    files = {'map.txt': 'a', 'round.json': 'b', '1.sav': 'c', 'save_complete.txt': 'd'}
    return writer, reader, files, dict(files), generation


class ControllerContracts(unittest.TestCase):
    def test_name_data_copy_is_bounded_and_rejects_unexpected_entries(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'stage' / 'config' / 'names'
            source.mkdir(parents=True)
            (source / 'names.txt').write_bytes(b'fixture')
            work = root / 'work'
            work.mkdir()
            controller.copy_name_data(root / 'stage', work, time.monotonic() + 5)
            self.assertEqual((work / 'config' / 'names' / 'names.txt').read_bytes(), b'fixture')
            other = root / 'unexpected'
            other.mkdir()
            (source / 'subdir').mkdir()
            with self.assertRaises(ValueError): controller.copy_name_data(root / 'stage', other, time.monotonic() + 5)
            late = root / 'late'
            late.mkdir()
            with self.assertRaises(ValueError): controller.copy_name_data(root / 'stage', late, time.monotonic() - 1)
            fake = SimpleNamespace(is_symlink=lambda: True, is_file=lambda **kwargs: True)
            with mock.patch.object(controller.os, 'scandir') as scan:
                scan.return_value.__enter__.return_value = iter([fake])
                rejected = root / 'rejected'
                rejected.mkdir()
                with self.assertRaises(ValueError): controller.copy_name_data(root / 'stage', rejected, time.monotonic() + 5)

    def test_native_diagnostic_scanner_preserves_handled_capture_failure(self):
        for text in ('## ERROR: File not found (config/names/test.txt)',
                     'Cannot execute null.initialize_position_limits()', 'runtime error: issue',
                     'BUG: issue', 'RUNTIME: issue', 'assertion failed'):
            with self.subTest(text=text): self.assertIsNotNone(controller.DIAGNOSTIC.search(text))
        self.assertIsNone(controller.DIAGNOSTIC.search('World-save export failed: Child moved or disappeared during capture'))

    def test_name_data_copy_rejects_excess_bytes_and_entries(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'stage' / 'config' / 'names'
            source.mkdir(parents=True)
            (source / 'oversized').write_bytes(b'x' * (8 * 1024**2 + 1))
            work = root / 'size'
            work.mkdir()
            with self.assertRaises(ValueError): controller.copy_name_data(root / 'stage', work, time.monotonic() + 10)
            (source / 'oversized').unlink()
            for index in range(513): (source / str(index)).write_bytes(b'')
            work = root / 'count'
            work.mkdir()
            with self.assertRaises(ValueError): controller.copy_name_data(root / 'stage', work, time.monotonic() + 10)

    def test_positive_and_independent_fault_controls(self):
        args = evidence()
        controller.validate_writer(args[0], args[2], args[3], args[4], args[0]['seed_generation'])
        self.assertTrue(controller.validate_evidence(*args))
        numeric = list(evidence())
        for key in ('retained_box', 'retained_item', 'retained_control_item', 'omitted_animal', 'reference_null'):
            numeric[1][key] = 1
        self.assertTrue(controller.validate_evidence(*numeric))
        cases = []
        a = list(evidence()); a[3]['1.sav'] = 'changed'; cases.append(a)
        a = list(evidence()); a[4] = a[0]['seed_generation']; cases.append(a)
        a = list(evidence()); a[1]['generation'] = a[0]['seed_generation']; cases.append(a)
        a = list(evidence()); a[1]['audit']['generation'] = 'different'; cases.append(a)
        a = list(evidence()); a[0]['fixture_moves'] = 1; cases.append(a)
        a = list(evidence()); a[0]['controls']['owner_lost'] = False; cases.append(a)
        a = list(evidence()); a[1]['retained_item'] = False; cases.append(a)
        a = list(evidence()); a[1]['retained_control_item'] = False; cases.append(a)
        a = list(evidence()); a[1]['reference_null'] = False; cases.append(a)
        a = list(evidence()); a[1]['reference_null'] = 1.0; cases.append(a)
        a = list(evidence()); a[1]['reference_null'] = '1'; cases.append(a)
        a = list(evidence()); a[1]['nested_alias_and_cycle'] = False; cases.append(a)
        a = list(evidence()); a[1]['nested_losses_and_neighbor'] = False; cases.append(a)
        a = list(evidence()); a[0]['audit']['omissions'][1]['list_location']['index'] = 0; a[1]['audit'] = copy.deepcopy(a[0]['audit']); cases.append(a)
        a = list(evidence()); a[0]['audit']['omissions'][2]['list_location']['list_id'] = 9; a[1]['audit'] = copy.deepcopy(a[0]['audit']); cases.append(a)
        a = list(evidence()); del a[1]['reference_null']; cases.append(a)
        a = list(evidence()); a[0]['audit']['omissions'][0]['target_ref'] = 'wrong'; a[1]['audit'] = copy.deepcopy(a[0]['audit']); cases.append(a)
        a = list(evidence()); a[0]['audit']['omissions'][0]['source_ref'] = 'wrong'; a[1]['audit'] = copy.deepcopy(a[0]['audit']); cases.append(a)
        a = list(evidence()); a[0]['audit']['attempt_history'][0]['outcome'] = 'success'; a[1]['audit'] = copy.deepcopy(a[0]['audit']); cases.append(a)
        for args in cases:
            with self.subTest(args=args), self.assertRaises(ValueError):
                controller.validate_evidence(*args)

    def test_writer_rejection_occurs_before_reader_admission(self):
        writer, _, seed, backup, marker = evidence()
        with self.assertRaises(ValueError): controller.validate_writer(writer, seed, backup, 'wrong', writer['seed_generation'])
        with self.assertRaises(ValueError): controller.validate_writer(writer, seed, backup, marker, 'wrong')
        backup['1.sav'] = 'changed'
        with self.assertRaises(ValueError): controller.validate_writer(writer, seed, backup, marker, writer['seed_generation'])

    def test_inventory_deadline_and_unexpected_saved_file_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ('map.txt', 'round.json', '1.sav', 'save_complete.txt'):
                (root / name).write_bytes(name.encode())
            self.assertEqual(len(controller.saved_hashes(root)), 4)
            (root / 'unexpected').write_text('x')
            with self.assertRaises(ValueError): controller.saved_hashes(root)
            with self.assertRaises(ValueError): controller.inventory(root, time.monotonic() - 1)

    def test_receipt_binds_phase_head_scope_and_engine(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'receipt.json'
            row = {'phase': 'reader', 'head': 'a' * 40, 'scope': 'b' * 64,
                   'byond_version': 516, 'byond_build': 1688, 'port': 0, 'error': None}
            path.write_text(json.dumps(row))
            self.assertEqual(controller.read_receipt(path, 'reader', row['head'], row['scope']), row)
            with self.assertRaises(ValueError): controller.read_receipt(path, 'writer', row['head'], row['scope'])
            with self.assertRaises(ValueError): controller.read_receipt(path, 'reader', row['head'], 'c' * 64)

    def test_bounded_read_is_actual_bytes_not_only_stat(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'large'
            path.write_bytes(b'x' * 11)
            with self.assertRaises(ValueError): controller.bounded_bytes(path, 10)

    def test_compiler_warning_or_wrong_version_is_never_accepted(self):
        clean = 'DM compiler version 516.1688\nhuman_subtile.dmb - 0 errors, 0 warnings\n'
        controller.validate_compile(clean)
        for bad in (clean.replace('1688', '1681'), clean + 'other.dm: warning: issue\n', clean.replace('0 warnings', '1 warnings')):
            with self.subTest(bad=bad), self.assertRaises(ValueError): controller.validate_compile(bad)

    def test_owned_child_cleanup_and_monitor_failure_with_fake_process(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            child = SimpleNamespace(pid=731, wait=mock.Mock(return_value=0))
            fake_os = SimpleNamespace(name='posix', P_PID=1, WEXITED=2, WNOHANG=4, WNOWAIT=8,
                                      waitid=mock.Mock(return_value=object()), killpg=mock.Mock())
            fake_signal = SimpleNamespace(SIGKILL=9)
            with mock.patch.object(controller, 'os', fake_os), mock.patch.object(controller, 'signal', fake_signal), mock.patch.object(controller.subprocess, 'Popen') as not_launched:
                with self.assertRaises(ValueError):
                    controller.owned(['fake'], root, 'expired', root, time.monotonic() - 1)
                not_launched.assert_not_called()
            with mock.patch.object(controller, 'os', fake_os), mock.patch.object(controller, 'signal', fake_signal), mock.patch.object(controller.subprocess, 'Popen', return_value=child):
                row = controller.owned(['fake'], root, 'positive', root, time.monotonic() + 5)
            self.assertEqual(row['exit'], 0)
            fake_os.killpg.assert_called_once_with(731, fake_signal.SIGKILL)
            fake_os.waitid.return_value = None
            fake_os.killpg.reset_mock()
            with mock.patch.object(controller, 'os', fake_os), mock.patch.object(controller, 'signal', fake_signal), mock.patch.object(controller.subprocess, 'Popen', return_value=child), mock.patch.object(controller, 'inventory', side_effect=ValueError('sampled output budget')):
                with self.assertRaises(ValueError):
                    controller.owned(['fake'], root, 'refusal', root, time.monotonic() + 5, root)
            fake_os.killpg.assert_called_once_with(731, fake_signal.SIGKILL)
            self.assertIn('sampled output budget', (root / 'refusal.process.json').read_text())
            fake_os.killpg.reset_mock()
            fake_os.waitid.reset_mock()
            fake_os.waitid.return_value = object()
            clock = SimpleNamespace(monotonic=mock.Mock(side_effect=[0, 0, 121]))
            with mock.patch.object(controller, 'os', fake_os), mock.patch.object(controller, 'signal', fake_signal), mock.patch.object(controller, 'time', clock), mock.patch.object(controller.subprocess, 'Popen', return_value=child):
                with self.assertRaises(ValueError): controller.owned(['fake'], root, 'late', root, 1000)
            fake_os.killpg.assert_called_once_with(731, fake_signal.SIGKILL)
            fake_os.waitid.assert_not_called()
            self.assertTrue(json.loads((root / 'late.process.json').read_text())['timeout'])

    def test_writer_failure_prevents_reader_process(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output, byond, archive = root / 'out', root / 'byond', root / 'pinned.zip'
            byond.mkdir()
            (byond / 'DreamMaker').write_bytes(b'fake')
            (byond / 'DreamDaemon').write_bytes(b'fake')
            archive.write_bytes(b'fake')
            roles = []
            def fake_stage(out, head, review_scope):
                (out / 'stage').mkdir(parents=True)
                (out / 'stage' / 'config' / 'names').mkdir(parents=True)
                (out / 'stage' / 'config' / 'names' / 'fixture.txt').write_text('fixture')
                (out / 'debug-fixture-manifest.json').write_text('{}')
                for ext in ('.dmb', '.rsc'):
                    (out / 'stage' / ('human_subtile' + ext)).write_bytes(b'fake')
                return {}
            def fake_owned(command, cwd, role, out, deadline, data_root=None, extra_logs=(), env=None):
                roles.append(role)
                if role == 'compile':
                    (out / 'compile.stdout.log').write_text('DM compiler version 516.1688\nhuman_subtile.dmb - 0 errors, 0 warnings\n')
                    (out / 'compile.stderr.log').write_text('')
                else:
                    self.assertEqual(command[-2:], ['-log', role + '.native.log'])
                    self.assertEqual(command[command.index('-params') + 1], f'phase={role}&tested_commit=' + 'a' * 40 + '&scope=' + 'b' * 64)
                    (cwd / (role + '.native.log')).write_text('')
                    (cwd / ('debug-fixture-' + role + '.json')).write_text(json.dumps({'phase': role, 'head': 'a' * 40, 'scope': 'b' * 64, 'byond_version': 516, 'byond_build': 1688, 'port': 0, 'error': 'synthetic_failure'}))
                return {'role': role, 'exit': 0}
            fake_os = SimpleNamespace(name='posix', scandir=controller.os.scandir)
            runtime = SimpleNamespace(before=mock.Mock())
            with mock.patch.object(controller, 'os', fake_os), mock.patch.object(stage, 'stage', side_effect=fake_stage), mock.patch.object(controller, 'owned', side_effect=fake_owned), mock.patch.object(controller, 'RuntimeIdentity', return_value=runtime), mock.patch.object(controller, 'child_environment', return_value={}):
                with self.assertRaises(ValueError): controller.execute(output, 'a' * 40, 'b' * 64, byond, archive)
            self.assertEqual(roles, ['compile', 'writer'])
            self.assertEqual(runtime.before.call_args_list, [mock.call('compile'), mock.call('writer')])
            self.assertIn('synthetic_failure', (output / 'failure.json').read_text())
            roles.clear()
            output2 = root / 'identity-refusal'
            runtime.before.side_effect = ValueError('runtime identity changed')
            runtime.before.reset_mock()
            with mock.patch.object(controller, 'os', fake_os), mock.patch.object(stage, 'stage', side_effect=fake_stage), mock.patch.object(controller, 'owned', side_effect=fake_owned), mock.patch.object(controller, 'RuntimeIdentity', return_value=runtime), mock.patch.object(controller, 'child_environment', return_value={}):
                with self.assertRaises(ValueError): controller.execute(output2, 'a' * 40, 'b' * 64, byond, archive)
            self.assertEqual(roles, [])
            self.assertIn('runtime identity changed', (output2 / 'failure.json').read_text())

    def test_runtime_members_rechecked_before_each_launch_and_drift_refused(self):
        identity = {'version': '516.1688', 'members': {name: {'sha256': name} for name in ('DreamMaker', 'DreamDaemon', 'libbyond.so', 'libext.so')}}
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            verifier = SimpleNamespace(verify_linux=mock.Mock(side_effect=[identity, identity, {**identity, 'version': 'wrong'}]))
            with mock.patch.object(stage, 'scope', return_value={'sha256': 'scope'}):
                runtime = controller.RuntimeIdentity(Path('bin'), Path('archive'), 'scope', output, verifier)
                runtime.before('compile')
                with self.assertRaises(ValueError): runtime.before('writer')
            self.assertEqual(runtime.checked, ['compile'])
            self.assertEqual(verifier.verify_linux.call_count, 3)
            self.assertIn('runtime identity changed', (output / 'runtime-identity.json').read_text())
            with self.assertRaises(ValueError):
                controller.RuntimeIdentity(Path('bin'), Path('archive'), 'scope', output, SimpleNamespace(verify_linux=mock.Mock(return_value={'version': '516.1688', 'members': {}})))

    def test_loader_environment_replaces_untrusted_inherited_ld_variables(self):
        env = {'PATH': 'safe-path', 'LD_PRELOAD': 'untrusted', 'LD_AUDIT': 'untrusted', 'LD_LIBRARY_PATH': 'old'}
        with mock.patch.object(controller, 'os', SimpleNamespace(environ=env)):
            actual = controller.child_environment(Path('/fixture/byond/bin'), Path('/fixture/runtime'))
        self.assertNotIn('LD_PRELOAD', actual)
        self.assertNotIn('LD_AUDIT', actual)
        self.assertEqual(actual['LD_LIBRARY_PATH'], str(Path('/fixture/byond/bin')))
        self.assertEqual(actual['PATH'], '/usr/bin:/bin')
        self.assertEqual(actual['HOME'], str(Path('/fixture/runtime')))
        self.assertEqual(set(actual), {'PATH', 'HOME', 'TMPDIR', 'LANG', 'LC_ALL', 'LD_LIBRARY_PATH'})


class StagingContracts(unittest.TestCase):
    def test_fixture_initializes_real_job_controller_before_load(self):
        probe = (stage.ROOT / 'tests/save_debug_fixture/probe.dm').read_text(encoding='utf-8')
        self.assertIn('job_master = new /datum/controller/occupations()', probe)
        self.assertIn('debug_fixture_assert(job_master, "fixture_no_job_controller")', probe)
        self.assertIn('ticker.loadmap(', probe)

    def test_handoff_injection_retains_guard_and_refuses_drift(self):
        source = (stage.ROOT / 'code/modules/persistence/saving.dm').read_text(encoding='utf-8')
        result = stage.inject_mob_handoff(source)
        self.assertEqual(result.count('debug_fixture_after_child_capture(parent, content, child_ref)'), 1)
        self.assertEqual(result.count('throw EXCEPTION("Child moved or disappeared during capture")'), source.count('throw EXCEPTION("Child moved or disappeared during capture")'))
        with self.assertRaises(ValueError): stage.inject_mob_handoff(source.replace('for(var/mob/content in parent.contents)', 'for(var/mob/content in other.contents)'))
        with self.assertRaises(ValueError): stage.inject_mob_handoff(source + source)

    def test_scope_includes_candidate_controller_and_probe(self):
        result = stage.scope()
        self.assertEqual(len(result['sha256']), 64)
        for name in ('code/modules/persistence/debug_lossy.dm', 'tests/save_debug_fixture/probe.dm',
                     'tests/save_debug_fixture/controller.py', 'tests/save_debug_fixture/test_fixture.py'):
            self.assertIn(name, result['files'])

    def test_scope_normalizes_only_crlf_and_refuses_lone_cr(self):
        self.assertEqual(stage.canonical(b'one\r\ntwo\r\n'), b'one\ntwo\n')
        with self.assertRaises(ValueError): stage.canonical(b'one\rtwo')


if __name__ == '__main__': unittest.main()
