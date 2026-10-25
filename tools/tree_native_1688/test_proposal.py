"""Offline fixture/controller contract tests: synthetic evidence is not native evidence."""
import copy
import os
import hashlib
import json
from pathlib import Path
import tempfile
import shutil
import unittest

from audit_offline import install, guard
install()
from prepare import (ADAPTER, VERSION, CONTROLS, VARIANTS, adapt_probe, bounded_file,
                     canonical, digest, replace_once, safe_root, startup_sources,
                     validate_inventory_bytes, verify_prepared, generated_files, INPUTS, HEAD, TREE)
from oracle import expected, verify_result, verify_compile, listener_diagnostics, SUCCESS
from plan import PHASES, TOTAL_WALL_SECONDS, CLEANUP_RESERVE_SECONDS, copy_restart, RESTART_FILES, activation_gate, proposed_plan
from receipts import LifecycleModel

BINDING = 'a' * 64


def evidence(variant='baseline', phase='roundtrip'):
    rows = expected(variant, phase)
    failure = None if variant == 'baseline' else CONTROLS[variant][3]
    result = dict(schema=1, adapter=ADAPTER, candidate_manifest_sha256=BINDING,
                  version=VERSION, head=HEAD, tree=TREE, variant=variant, phase=phase, port=0,
                  status='passed' if failure is None else 'assertion-rejected',
                  failure=failure, legacy_result=SUCCESS[phase] if failure is None else 'FAIL: ' + failure,
                  assertions=rows)
    log = '\n'.join('TREE1688_ASSERT ' + json.dumps(row) for row in rows)
    log += '\nTREE1688_RESULT ' + variant + ':' + phase + '\n'
    return result, log


def process_receipt(pid=123):
    return dict(process_started=True, pid=pid, termination_observed=True, leader_reaped=True,
                cleanup_verified=True, cleanup_no_observed_live_descendants=True,
                cleanup_process_group_absent=True, owned_child_listing_available=True,
                owned_observation_trusted=True, signal_handlers_restored=True,
                exit_code=0, stop_reason=None, log_truncated=False, cleanup_errors=[])


class OracleTests(unittest.TestCase):
    def test_all_fixed_phases_and_controls(self):
        for variant, phase in [('baseline', p) for p in SUCCESS] + [(v, 'roundtrip') for v in VARIANTS[1:]]:
            with self.subTest(variant=variant, phase=phase):
                result, log = evidence(variant, phase)
                verdict = verify_result(BINDING, variant, phase, result, log)
                self.assertEqual(verdict['status'], 'passed' if variant == 'baseline' else 'causal-control-detected')
                self.assertEqual(verdict['assertions'], len(expected(variant, phase)))

    def test_source_and_runtime_bindings_fail_closed(self):
        for key, value in [('candidate_manifest_sha256', 'b'*64), ('adapter', 'other'), ('version', '516.1681'),
                           ('head', '0'*40), ('tree', '0'*40), ('variant', 'clock'), ('phase', 'reader'), ('schema', True), ('port', False), ('port', 42)]:
            with self.subTest(key=key):
                result, log = evidence(); result[key] = value
                with self.assertRaises(ValueError): verify_result(BINDING, 'baseline', 'roundtrip', result, log)

    def test_exact_schema_and_assertion_types(self):
        for mutation in ('extra', 'missing', 'bool', 'reorder', 'truncate', 'duplicate'):
            with self.subTest(mutation=mutation):
                result, log = evidence()
                if mutation == 'extra': result['unreviewed'] = True
                if mutation == 'missing': del result['port']
                if mutation == 'bool': result['assertions'][0]['ok'] = True
                if mutation == 'reorder': result['assertions'].reverse()
                if mutation == 'truncate': result['assertions'].pop()
                if mutation == 'duplicate': result['assertions'].append(result['assertions'][0])
                with self.assertRaises(ValueError): verify_result(BINDING, 'baseline', 'roundtrip', result, log)

    def test_log_inventory_and_terminal_fail_closed(self):
        result, log = evidence()
        lines = log.splitlines()
        for altered in ['\n'.join(lines[1:]), log + lines[-1] + '\n',
                        '\n'.join([lines[-1], *lines[:-1]]), log.replace('baseline:roundtrip', 'clock:roundtrip'),
                        log + 'TREE1688_ASSERT {}\n']:
            with self.subTest(log=altered[-80:]):
                with self.assertRaises(ValueError): verify_result(BINDING, 'baseline', 'roundtrip', result, altered)

    def test_wrong_control_target_and_unexpected_success_rejected(self):
        result, log = evidence('clock')
        for key, value in [('status', 'passed'), ('failure', CONTROLS['duration'][3]), ('legacy_result', SUCCESS['roundtrip'])]:
            altered = copy.deepcopy(result); altered[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                verify_result(BINDING, 'clock', 'roundtrip', altered, log)

    def test_fatal_and_auxiliary_logs(self):
        result, log = evidence()
        for diagnostic in ['runtime error', 'warning: unused', 'TREE1688_FATAL failure', 'FAIL: unexpected', 'cleanup failed']:
            with self.subTest(diagnostic=diagnostic), self.assertRaises(ValueError):
                verify_result(BINDING, 'baseline', 'roundtrip', result, log, {'extra.log': diagnostic})
        self.assertEqual(verify_result(BINDING, 'baseline', 'roundtrip', result, log, {'copy.log': log})['status'], 'passed')
        with self.assertRaises(ValueError):
            verify_result(BINDING, 'baseline', 'roundtrip', result, log, {'partial.log': log.splitlines()[0]})

    def test_listener_diagnostics_are_not_census(self):
        good = 'World opened on network port 1234 for address 127.0.0.1.\nWorld no longer opened to new users.'
        listener_diagnostics(good); listener_diagnostics('')
        for bad in [good.replace('127.0.0.1', '0.0.0.0'), good.replace('1234', '0'), good + good,
                    good.splitlines()[0], 'World opened on network port nonsense']:
            with self.subTest(log=bad), self.assertRaises(ValueError): listener_diagnostics(bad)

    def test_compiler_exact_version_clean_summary(self):
        good = 'DM compiler version 516.1688\n0 errors, 0 warnings\n'
        self.assertEqual(verify_compile(good)['status'], 'passed')
        for bad in [good.replace('1688', '1681'), good + good, good.replace('0 errors', '1 errors'),
                    good + 'warning: bad', good + 'invalid file', good.replace('0 warnings', '1 warnings')]:
            with self.subTest(log=bad), self.assertRaises(ValueError): verify_compile(bad)

    def test_unknown_variant_and_phase_rejected(self):
        for variant, phase in [('other', 'roundtrip'), ('baseline', 'other'), ('clock', 'reader')]:
            with self.subTest(variant=variant, phase=phase), self.assertRaises(ValueError): expected(variant, phase)


class LifecycleTests(unittest.TestCase):
    def test_complete_fixed_order_is_explicitly_synthetic(self):
        model = LifecycleModel(BINDING)
        for n, (phase, role, variant, mode) in enumerate(PHASES):
            model.attempt(phase, n); model.started(123); model.process_returned(process_receipt())
            model.validate('causal-control-detected' if role == 'daemon' and variant != 'baseline' else 'passed', n + 0.5)
        self.assertEqual(model.state['status'], 'completed')
        self.assertIn('not-native-execution', model.state['evidence_kind'])
        self.assertTrue(model.state['compiler_completed']); self.assertTrue(model.state['daemon_completed'])
        with self.assertRaises(ValueError): model.attempt(PHASES[0][0], 100)

    def test_attempt_is_not_start_or_completion(self):
        model = LifecycleModel(BINDING); model.attempt(PHASES[0][0], 0)
        self.assertTrue(model.state['compiler_attempted']); self.assertFalse(model.state['compiler_started'])
        self.assertFalse(model.state['native_executed'])
        with self.assertRaises(ValueError): model.process_returned(process_receipt())
        model.fail('spawn rejected')
        self.assertFalse(model.state['compiler_started']); self.assertEqual(model.state['status'], 'failed')

    def test_start_fact_survives_failure_receipt_io(self):
        model = LifecycleModel(BINDING); model.attempt(PHASES[0][0], 0)
        model.fail('write failed', {'process_started': True, 'pid': 123})
        self.assertTrue(model.state['compiler_started']); self.assertTrue(model.state['native_executed'])
        self.assertFalse(model.state['compiler_completed']); self.assertFalse(model.state['phases'][0]['cleanup_verified'])

    def test_cleanup_failures_cannot_advance(self):
        required = ('termination_observed', 'leader_reaped', 'cleanup_verified', 'cleanup_no_observed_live_descendants',
                    'cleanup_process_group_absent', 'owned_child_listing_available', 'owned_observation_trusted', 'signal_handlers_restored')
        for key, value in [(k, False) for k in required] + [('exit_code', 1), ('exit_code', False), ('stop_reason', 'timeout'),
                                                         ('log_truncated', True), ('cleanup_errors', ['still alive'])]:
            with self.subTest(key=key):
                model = LifecycleModel(BINDING); model.attempt(PHASES[0][0], 0); model.started(123)
                receipt = process_receipt(); receipt[key] = value
                with self.assertRaises(ValueError): model.process_returned(receipt)
                self.assertEqual(model.state['status'], 'failed')
                with self.assertRaises(ValueError): model.attempt(PHASES[1][0], 1)

    def test_phase_order_and_pid_identity(self):
        model = LifecycleModel(BINDING)
        with self.assertRaises(ValueError): model.attempt(PHASES[1][0], 0)
        model.attempt(PHASES[0][0], 0)
        for pid in [True, 0, -1, '123']:
            with self.assertRaises(ValueError): model.started(pid)
        model.started(123)
        with self.assertRaises(ValueError): model.started(123)
        with self.assertRaises(ValueError): model.process_returned(process_receipt(124))
        with self.assertRaises(ValueError): model.fail('wrong invocation', process_receipt(124))

    def test_deadlines_and_verdict(self):
        model = LifecycleModel(BINDING)
        with self.assertRaises(ValueError): model.attempt(PHASES[0][0], TOTAL_WALL_SECONDS - CLEANUP_RESERVE_SECONDS)
        for verdict, now in [('causal-control-detected', 1), ('passed', TOTAL_WALL_SECONDS + 1), ('unknown', 1)]:
            model = LifecycleModel(BINDING); model.attempt(PHASES[0][0], 0); model.started(123); model.process_returned(process_receipt())
            with self.subTest(verdict=verdict, now=now), self.assertRaises(ValueError): model.validate(verdict, now)


class FileContractTests(unittest.TestCase):
    def test_inventory_hash_schema_and_paths(self):
        data = b'source'; row = dict(path='code/example.dm', type='blob', mode='100644', size=len(data),
                                   sha=hashlib.sha1(b'blob 6\0' + data).hexdigest(), sha256=digest(data))
        raw = canonical([row]); self.assertEqual(validate_inventory_bytes(raw, digest(raw))[row['path']], row)
        with self.assertRaises(ValueError): validate_inventory_bytes(raw, 'f' * 64)
        for changes in [{'path':'../escape'}, {'path':'/absolute'}, {'path':'a\\b'}, {'path':'.git/config'},
                        {'size':True}, {'mode':'120000'}, {'type':'tree'}, {'sha':'bad'}, {'extra':0}]:
            bad = dict(row, **changes); raw = canonical([bad])
            with self.subTest(changes=changes), self.assertRaises(ValueError): validate_inventory_bytes(raw, digest(raw))
        raw = canonical([row, row])
        with self.assertRaises(ValueError): validate_inventory_bytes(raw, digest(raw))

    def test_bounded_files_reject_links_and_oversize(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root); source = root/'source'; source.write_bytes(b'abcd')
            self.assertEqual(bounded_file(source, 4), b'abcd')
            with self.assertRaises(ValueError): bounded_file(source, 3)
            link = root/'link'; link.symlink_to(source)
            with self.assertRaises(ValueError): bounded_file(link)
            with self.assertRaises(ValueError): safe_root(link)
            with self.assertRaises(ValueError): bounded_file(root)

    def test_restart_copy_sealed_fixed_names(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root); writer = root/'writer'; writer.mkdir()
            files = {}
            for name in RESTART_FILES:
                data = ('synthetic ' + name).encode(); (writer/name).write_bytes(data)
                files[name] = dict(bytes=len(data), sha256=digest(data))
            receipt = dict(candidate_manifest_sha256=BINDING, phase='baseline-writer', started=True,
                           process_completed=True, cleanup_verified=True, validated=True, restart_files=files)
            copied = copy_restart(writer, root/'reader', receipt, BINDING)
            self.assertEqual(copied, files)
            self.assertEqual(json.loads((root/'reader'/'restart-copy.json').read_text())['paths_from_save_contents'], False)
            for key, value in [('cleanup_verified', False), ('validated', 1), ('candidate_manifest_sha256', 'b'*64), ('phase', 'other')]:
                bad = dict(receipt, **{key:value})
                with self.subTest(key=key), self.assertRaises(ValueError): copy_restart(writer, root/('reader-'+key), bad, BINDING)
            (writer/'tree-restart.sav').write_bytes(b'changed')
            with self.assertRaises(ValueError): copy_restart(writer, root/'changed-reader', receipt, BINDING)

    def test_restart_rejects_alias_and_unsealed_members(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root); writer=root/'writer'; writer.mkdir()
            receipt=dict(candidate_manifest_sha256=BINDING, phase='baseline-writer', started=True,
                         process_completed=True, cleanup_verified=True, validated=True, restart_files={})
            for reader in [writer, writer/'nested', root]:
                with self.assertRaises(ValueError): copy_restart(writer, reader, receipt, BINDING)
            with self.assertRaises(ValueError): copy_restart(writer, root/'reader', receipt, BINDING)

    def test_adapter_unique_anchors_and_startup_isolation(self):
        self.assertEqual(replace_once('abc', 'b', 'B'), 'aBc')
        for text in ['none', 'bb']:
            with self.assertRaises(ValueError): replace_once(text, 'b', 'B')
        world = '/world/New()\n\t..()\n\tfoo()\n/world/Topic(T, addr, master, key)\n\tfoo()\n/datum/global_init/New()\n\tfoo()\n'
        globals_text = '/datum/controller/global_vars/New()\n\tfoo()\n'
        adapted, globals_adapted = startup_sources(world, globals_text)
        self.assertNotIn('/world/New()', adapted); self.assertNotIn('\n\t..()', adapted)
        self.assertIn('world.OpenPort("none")\n\treturn', adapted)
        self.assertIn('/datum/controller/global_vars/New()\n\treturn\n', globals_adapted)

    def test_plan_and_activation_remain_explicit(self):
        plan = proposed_plan(BINDING)
        self.assertFalse(plan['native_executed']); self.assertEqual(len(plan['phases']), len(PHASES))
        self.assertEqual(plan['candidate_manifest_sha256'], BINDING)
        with self.assertRaises(RuntimeError): activation_gate()

    def test_offline_audit_guard_without_attempting_actions(self):
        for event, args in [('subprocess.Popen', ()), ('socket.__new__', ()), ('ctypes.dlopen', ()),
                            ('os.fork', ()), ('open', ('/proc/self/status',)), ('os.scandir', ('/proc',))]:
            with self.subTest(event=event), self.assertRaises(RuntimeError): guard(event, args)
        guard('open', ('/tmp/synthetic-fixture',))


class PreparedTamperTests(unittest.TestCase):
    """Use retained exact inputs, regenerate overlays, and mutate disposable copies.

    Requires the separately prepared review packet at ../../prepared. Never
    writes to the actual packet or production source.
    """
    @classmethod
    def setUpClass(cls):
        # Read only exact manifest-bound inputs; these are OFFLINE previews,
        # never actual-checkout admission evidence or native receipts.
        from prepare import validate_inventory_bytes
        root = Path(__file__).resolve().parent
        cls.manifest_bytes = bounded_file(root / 'source-manifest.json', 16 * 1024**2)
        manifest = validate_inventory_bytes(cls.manifest_bytes)
        selected = os.environ.get('TREE_TEST_SOURCE')
        fallback = Path(__file__).resolve().parents[2] / 'prepared/inputs'
        source = Path(selected) if selected else fallback
        cls.inputs = {name: bounded_file(source / name) for name in INPUTS}
        for name, data in cls.inputs.items():
            if digest(data) != manifest[name]['sha256'] or len(data) != manifest[name]['size']:
                raise ValueError('Offline preview input differs from exact manifest')
        cls.original_receipt = {'schema': 1, 'adapter': ADAPTER, 'version': VERSION,
            'candidate_manifest_sha256': digest(cls.manifest_bytes), 'git_head': None, 'git_tree': None,
            'native_executed': False, 'compiler_attempted': False, 'compiler_started': False,
            'compiler_completed': False, 'daemon_attempted': False, 'daemon_started': False,
            'daemon_completed': False, 'portable_or_compile_ready': False, 'normal_startup': False,
            'inputs': {name: {'sha256': manifest[name]['sha256'], 'bytes': manifest[name]['size']} for name in INPUTS}}

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)/'prepared'
        self.root.mkdir()
        (self.root/'candidate-manifest.json').write_bytes(self.manifest_bytes)
        self.receipt = copy.deepcopy(self.original_receipt)
        self.receipt['generated'] = {}
        for name, data in self.inputs.items():
            target = self.root/'inputs'/name; target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(data)
        for variant in VARIANTS:
            for name, data in generated_files(self.inputs, self.receipt['candidate_manifest_sha256'], variant).items():
                relative = 'generated/' + variant + '/' + name
                target = self.root/relative; target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(data)
                self.receipt['generated'][relative] = {'sha256': digest(data), 'bytes': len(data)}

    def test_reproduced_packet_validates(self):
        verify_prepared(self.root, self.receipt)

    def test_missing_input_or_generated_receipt_member_rejected(self):
        for group in ['inputs', 'generated']:
            altered = copy.deepcopy(self.receipt); del altered[group][next(iter(altered[group]))]
            with self.subTest(group=group), self.assertRaises(ValueError): verify_prepared(self.root, altered)

    def test_added_input_or_generated_receipt_member_rejected(self):
        for group in ['inputs', 'generated']:
            altered = copy.deepcopy(self.receipt); altered[group]['unknown.dm'] = {'sha256': digest(b''), 'bytes': 0}
            with self.subTest(group=group), self.assertRaises(ValueError): verify_prepared(self.root, altered)

    def test_modified_input_and_rehashed_receipt_rejected(self):
        name = 'code/game/objects/farming.dm'
        data = self.inputs[name] + b'\n// unauthorized input mutation\n'
        (self.root/'inputs'/name).write_bytes(data)
        self.receipt['inputs'][name] = {'sha256': digest(data), 'bytes': len(data)}
        with self.assertRaises(ValueError): verify_prepared(self.root, self.receipt)

    def test_modified_generated_and_rehashed_receipt_rejected(self):
        name = 'generated/baseline/tree1688-probe.dm'
        data = (self.root/name).read_bytes() + b'\n// unauthorized generated mutation\n'
        (self.root/name).write_bytes(data)
        self.receipt['generated'][name] = {'sha256': digest(data), 'bytes': len(data)}
        with self.assertRaises(ValueError): verify_prepared(self.root, self.receipt)

    def test_version_adapter_and_execution_flags_rejected(self):
        mutations = [('version', '516.1681'), ('adapter', 'unreviewed'), ('git_head', 'a'*40), ('git_tree', 'b'*40),
                     ('native_executed', True), ('compiler_attempted', True), ('compiler_started', True),
                     ('compiler_completed', True), ('daemon_attempted', True), ('daemon_started', True),
                     ('daemon_completed', True), ('portable_or_compile_ready', True), ('normal_startup', True),
                     ('native_executed', 0), ('compiler_started', None)]
        for key, value in mutations:
            altered = copy.deepcopy(self.receipt); altered[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): verify_prepared(self.root, altered)

    def test_generated_appearance_inventory_and_disposal_returns(self):
        self.assertEqual({phase: len(expected('baseline', phase)) for phase in SUCCESS},
                         {'roundtrip': 84, 'writer': 3, 'reader': 25})
        probe = (self.root/'generated/baseline/tree1688-probe.dm').read_text()
        for assertion in ['constructor appearance state exists in native icon resource',
                          'disk round trip preserves explicitly staged appearance state',
                          'production stage appearance matches native icon resource']:
            self.assertIn(assertion, probe)
        self.assertEqual(probe.count('\tdel(world)\n\treturn'), 2)
        self.assertNotIn('\tdel(world)\n\tsleep(1)', probe)


if __name__ == '__main__':
    unittest.main(verbosity=2)
