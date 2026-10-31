"""Offline flax runner contracts with all native launch/identity seams injected."""
from contextlib import ExitStack, redirect_stdout, redirect_stderr
import importlib.util
import hashlib
import io
import json
from pathlib import Path
from types import SimpleNamespace as NS
import tempfile
import unittest
import zipfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('flax_runner_contract', Path(__file__).with_name('run.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class FlaxRunnerContracts(unittest.TestCase):
    def test_compiler_accepts_only_exact_current_pin_and_one_clean_banner(self):
        expected = runner.byond_toolchain.load()['version']
        self.assertEqual(expected, '516.1688')
        clean = f'DM compiler version {expected}\nprobe.dmb - 0 errors, 0 warnings\n'
        runner.check_compile(NS(returncode=0, stdout=clean, stderr=''), expected)
        for text in ('', clean.replace('1688', '1681'), clean.replace('1688', '1689'),
                     clean.replace('1688', '16880'), clean.replace(expected, expected + ' extra'),
                     clean + f'DM compiler version {expected}\n',
                     clean.replace('0 warnings', '1 warnings'), clean.replace('0 errors', '1 errors'),
                     'note: 516.1688\nDM compiler version 516.1681\nprobe.dmb - 0 errors, 0 warnings\n'):
            with self.subTest(text=text), self.assertRaisesRegex(RuntimeError, 'version/result contract rejected'):
                runner.check_compile(NS(returncode=0, stdout=text, stderr=''), expected)
        with self.assertRaisesRegex(RuntimeError, 'exited nonzero'):
            runner.check_compile(NS(returncode=1, stdout=clean, stderr=''), expected)

    def test_linux_identity_requires_archive_and_forwards_exact_member_verification(self):
        binary, archive = Path('bin'), Path('pinned.zip')
        identity = object()
        with patch.object(runner.sys, 'platform', 'linux'), \
                patch.object(runner.byond_runtime, 'verify_linux', return_value=identity) as verify:
            with self.assertRaisesRegex(ValueError, '--byond-archive'):
                runner.runtime_identity(binary, None)
            verify.assert_not_called()
            self.assertIs(runner.runtime_identity(binary, archive), identity)
            verify.assert_called_once_with(binary, archive)
        with patch.object(runner.sys, 'platform', 'linux'), \
                patch.object(runner.byond_runtime, 'verify_linux', side_effect=ValueError('member mismatch')):
            with self.assertRaisesRegex(ValueError, 'member mismatch'):
                runner.runtime_identity(binary, archive)

    def exercise(self, defect=None, human_entry=False, entry_control=None, fail_finalizer=False):
        with tempfile.TemporaryDirectory(prefix='flax-runner-offline-') as directory, ExitStack() as stack:
            root = Path(directory)
            # Only source inputs and synthetic output files; no executables.
            for relative in (runner.CORE, 'code/modules/persistence/saving.dm',
                             'code/modules/persistence/loading.dm', 'code/modules/persistence/functions.dm',
                             'config/crafting/material_recipes_global.txt', 'code/modules/research_tree/research_node.dm',
                             'tests/flax_processing/probe.dm', 'tests/flax_processing/run.py',
                             runner.REQUIRED_INPUT_MANIFEST, 'code/names.dm',
                             'code/_helpers/files.dm', 'code/_helpers/type2type.dm',
                             'scripts/byond_runtime.py', 'scripts/byond_toolchain.py', 'scripts/native_fixture.py',
                             'tools/byond/version.json'):
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / relative).read_bytes())
            if human_entry:
                for relative in (*runner.ENTRY_SOURCES, *runner.ENTRY_CONTRACTS,
                                 'tests/flax_processing/human_entry_probe.dm'):
                    target = root / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes((ROOT / relative).read_bytes())
            for row in runner.required_input_plan():
                if row['path'].startswith('config/names/'):
                    target = root / row['path']
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes((ROOT / row['path']).read_bytes())
            (root / 'code/controllers/mc').mkdir(parents=True, exist_ok=True)
            (root / 'code/world.dm').write_text('/world/New()\n\t..()\n/datum/global_init/New()\n\treturn\n')
            (root / 'code/controllers/mc/globals.dm').write_text('/datum/controller/global_vars/New()\n\treturn\n')
            (root / 'civ13.dme').write_text('#include "code\\world.dm"\n#include "code\\controllers\\mc\\globals.dm"\n#include "code\\game\\mob\\inventory.dm"\n#include "code\\game\\mob\\living\\living.dm"\n#include "code\\game\\mob\\living\\carbon\\human\\human.dm"\n#include "code\\modules\\1713\\flax_processing.dm"\n')
            output = root / 'evidence'
            events, launches = [], []
            identity = {'version': '516.1688', 'identity_basis': 'injected-offline-test'}

            def verify(binary, archive):
                events.append('identity')
                if defect == 'archive' or (defect == 'changed_member' and len(launches) == 1):
                    raise ValueError('injected archive/member mismatch')
                return identity

            def launch(command, **kwargs):
                launches.append(kwargs)
                phase = kwargs['phase']
                (output / (phase + '.stdout.log')).write_text('injected partial stdout')
                (output / (phase + '.stderr.log')).write_text('injected partial stderr')
                if len(launches) == 1:
                    events.append('compile')
                    preflight = json.loads((output / 'staging-compile.json').read_text())
                    self.assertEqual(preflight['counts']['required_inputs'], 147)
                    self.assertEqual(preflight['counts']['runtime_binaries'], 0)
                    dme = Path(command[-1])
                    if human_entry:
                        self.assertIn('#include "tests/flax_processing/human_entry_probe.dm"', dme.read_text())
                        for relative, suffix in zip(runner.ENTRY_SOURCES, ('_living.dm', '_human.dm')):
                            staged = next(root.glob('.flax_probe_*' + suffix))
                            self.assertEqual(staged.read_text(), runner.entry_sources(entry_control)[relative])
                    dme.with_suffix('.dmb').write_bytes(b'offline test data')
                    dme.with_suffix('.rsc').write_bytes(b'offline test data')
                    if defect == 'compile_timeout':
                        raise runner.subprocess.TimeoutExpired(command, 180)
                    if defect == 'compile_failure':
                        return NS(returncode=9, stdout='compiler failed', stderr='diagnostic')
                    version = '516.1681' if defect == 'old_banner' else '516.1688'
                    return NS(returncode=0, stdout=f'DM compiler version {version}\nprobe.dmb - 0 errors, 0 warnings\n', stderr='')
                events.append('daemon')
                preflight = json.loads((output / 'staging-daemon.json').read_text())
                self.assertEqual(preflight['counts']['required_inputs'], 147)
                self.assertEqual(preflight['counts']['runtime_binaries'], 2)
                upload = json.loads((output / 'evidence-manifest.json').read_text())
                self.assertTrue(all(row['status'] == 'retained' for row in upload['upload_aliases']))
                self.assertIn('-trusted', command)
                if human_entry:
                    ip = command.index('-ip')
                    self.assertEqual(command[ip:ip + 3], ['-ip', '127.0.0.1', '-nowebclient'])
                work = kwargs['cwd']
                (work / 'runtime.log').write_text('diagnostic survives every runtime exit')
                (work / 'errors.txt').write_text('injected failure detail' if defect in ('daemon_timeout', 'daemon_interrupt', 'daemon_failure', 'daemon_early_exit') else '')
                if defect == 'daemon_timeout':
                    raise runner.subprocess.TimeoutExpired(command, 45)
                if defect == 'daemon_interrupt':
                    raise KeyboardInterrupt('injected interruption')
                if defect == 'daemon_failure':
                    return NS(returncode=7, stdout='early exit', stderr='failure detail')
                if defect == 'daemon_early_exit':
                    return NS(returncode=0, stdout='exited before receipt', stderr='')
                expected = 'PASS: flax processing and native disk round trips'
                diagnostic = 'offline injected runner test'
                if human_entry:
                    expected = ('FAIL: human afterattack enters production wait' if entry_control
                                else 'PASS: production human flax afterattack entry and caller contracts')
                    if defect == 'wrong_entry_failure':
                        expected = 'FAIL: unrelated assertion'
                    if defect != 'missing_placement':
                        diagnostic += '\nENTRY PASS: afterattack physically places the paid bundle before the entry oracle'
                    (work / 'port-closed.txt').write_text('closed')
                (work / 'result.txt').write_text(expected)
                (work / 'runtime.log').write_text(diagnostic)
                return NS(returncode=0, stdout='', stderr='')

            stack.enter_context(patch.object(runner, 'ROOT', root))
            stack.enter_context(patch.object(Path, 'unlink', side_effect=AssertionError('Runner must retain owned files')))
            stack.enter_context(patch.object(runner, 'runtime_identity', side_effect=verify))
            git_results = ['a' * 40, 'dirty' if defect == 'dirty_inputs' else '', b''] if human_entry else ['a' * 40, b'']
            stack.enter_context(patch.object(runner.subprocess, 'check_output', side_effect=git_results))
            stack.enter_context(patch.object(runner, 'run_phase', side_effect=launch))
            if fail_finalizer:
                retain = runner.retain_manifest
                def failed_inventory(*args, **kwargs):
                    if kwargs.get('finalized'):
                        raise OSError('injected manifest write failure')
                    return retain(*args, **kwargs)
                stack.enter_context(patch.object(runner, 'retain_manifest', side_effect=failed_inventory))
            arguments = ['run.py', '--byond-bin', str(root / 'bin'), '--byond-archive', str(root / 'pinned.zip'), '--output', str(output)]
            if human_entry:
                arguments += ['--human-entry', '--expected-head', 'b' * 40 if defect == 'wrong_head' else 'a' * 40]
                if entry_control:
                    arguments += ['--entry-control', entry_control]
                stack.enter_context(patch.object(runner.sys, 'platform', 'linux'))
            stack.enter_context(patch.object(runner.sys, 'argv', arguments))
            # Synthetic native-result text must not look like real acceptance.
            stack.enter_context(redirect_stdout(io.StringIO()))
            stack.enter_context(redirect_stderr(io.StringIO()))
            if defect:
                with self.assertRaises((RuntimeError, ValueError, runner.subprocess.TimeoutExpired, KeyboardInterrupt)) as failure:
                    runner.main()
                if fail_finalizer:
                    self.assertIsInstance(failure.exception, runner.subprocess.TimeoutExpired)
            else:
                runner.main()
                metadata = json.loads((output / 'metadata.json').read_text())
                self.assertEqual(metadata['expected_byond_version'], '516.1688')
                self.assertIn('scripts/native_fixture.py', metadata['source_sha256'])
                if human_entry:
                    self.assertTrue(set(runner.ENTRY_CONTRACTS) <= metadata['source_sha256'].keys())
                self.assertEqual(json.loads((output / 'compiler-runtime.json').read_text()), identity)
                self.assertEqual(json.loads((output / 'daemon-runtime.json').read_text()), identity)
            manifest = json.loads((output / 'evidence-manifest.json').read_text())
            self.assertFalse(manifest['automatic_deletion'])
            if fail_finalizer:
                self.assertFalse(manifest['finalized'])
            elif defect:
                self.assertIn(manifest['status'], ('failed', 'interrupted'))
            else:
                self.assertEqual(manifest['status'], 'passed_expected_control' if entry_control else 'passed')
                self.assertTrue(manifest['inventory_complete'])
                self.assertFalse(manifest.get('inventory_truncated', False))
            if launches:
                self.assertTrue(list(root.glob('.flax_probe_*.dme')), 'generated source must survive')
                self.assertTrue(list((output / 'generated-inputs').glob('*.dme')))
                self.assertTrue((output / 'compile.stdout.log').is_file())
                if not fail_finalizer:
                    self.assertEqual(manifest['upload_alias_status'], 'complete_for_existing_generated_files')
                    for row in manifest['upload_aliases']:
                        self.assertEqual(row['status'], 'retained')
                        original, alias = Path(row['original_path']), output / row['alias_path']
                        self.assertEqual(original.read_bytes(), alias.read_bytes())
                        self.assertEqual(hashlib.sha256(alias.read_bytes()).hexdigest(), row['sha256'])
            if defect in ('daemon_timeout', 'daemon_interrupt', 'daemon_failure', 'daemon_early_exit'):
                self.assertIn('diagnostic survives', (output / 'runtime/runtime.log').read_text())
                self.assertIn('injected failure detail', (output / 'runtime/errors.txt').read_text())
                self.assertEqual((output / 'daemon.stderr.log').read_text(), 'injected partial stderr')
                self.assertIn('runtime/runtime.log', manifest['expected_diagnostics'])
                if not fail_finalizer:
                    self.assertIn('runtime/runtime.log', [record['path'] for record in manifest['retained_outputs']])
            if launches:
                self.assertEqual(launches[0]['timeout'], 180)
            if len(launches) == 2:
                self.assertEqual(launches[1]['timeout'], 45)
            if defect == 'old_banner':
                self.assertIn('516.1681', (output / 'compile.log').read_text())
            return events

    def test_identity_is_rechecked_before_each_existing_bounded_launch(self):
        self.assertEqual(self.exercise(), ['identity', 'compile', 'identity', 'daemon'])

    def test_wrong_archive_old_banner_or_changed_member_never_launches_daemon(self):
        for defect, expected in (
            ('archive', ['identity']),
            ('old_banner', ['identity', 'compile']),
            ('changed_member', ['identity', 'compile', 'identity']),
        ):
            with self.subTest(defect=defect):
                self.assertEqual(self.exercise(defect), expected)

    def test_prepared_human_entry_and_control_stage_actual_sources_without_native_execution(self):
        for control in (None, 'legacy-return'):
            with self.subTest(control=control):
                self.assertEqual(self.exercise(human_entry=True, entry_control=control), ['identity', 'compile', 'identity', 'daemon'])
        for defect in ('wrong_head', 'dirty_inputs'):
            with self.subTest(defect=defect):
                self.assertEqual(self.exercise(defect, human_entry=True), [])
        for defect in ('wrong_entry_failure', 'missing_placement'):
            with self.subTest(defect=defect):
                self.assertEqual(self.exercise(defect, human_entry=True, entry_control='legacy-return'),
                                 ['identity', 'compile', 'identity', 'daemon'])

    def test_all_three_existing_mutation_controls_still_have_unique_targets(self):
        self.assertEqual(set(runner.CONTROLS), {'payment', 'replay', 'persistence'})
        original = runner.source_for(None)
        for control, (old, new, _) in runner.CONTROLS.items():
            self.assertEqual(original.count(old), 1)
            self.assertEqual(runner.source_for(control), original.replace(old, new, 1))

    def test_failure_timeout_and_interruption_keep_inputs_and_runtime_diagnostics(self):
        for defect in ('compile_timeout', 'compile_failure', 'daemon_timeout', 'daemon_interrupt', 'daemon_failure', 'daemon_early_exit'):
            with self.subTest(defect=defect):
                self.exercise(defect, human_entry=True)

    def test_inventory_failure_does_not_mask_timeout_or_delete_retained_files(self):
        self.exercise('daemon_timeout', human_entry=True, fail_finalizer=True)


class DefaultArtifactSelection(unittest.TestCase):
    def fixture(self, root):
        prefix = '.flax_probe_' + 'a' * 32
        generated = [root / (prefix + suffix) for suffix in runner.GENERATED_SUFFIXES]
        for index, path in enumerate(generated):
            path.write_bytes(('owned generated bytes ' + str(index)).encode())
        output = root / 'case-evidence'
        (output / 'generated-inputs').mkdir(parents=True)
        # Historical snapshots are deliberately left in place and filtered out.
        for path in generated:
            (output / 'generated-inputs' / path.name).write_bytes(path.read_bytes())
        (root / '.unrelated-secret').write_bytes(b'never enumerate or copy this')
        return generated, output, {'upload_aliases': []}

    def test_default_linux_artifact_filter_keeps_exact_enumerated_alias_bytes(self):
        with tempfile.TemporaryDirectory(prefix='flax-upload-offline-') as directory:
            root = Path(directory)
            generated, output, manifest = self.fixture(root)
            with patch.object(runner, 'ROOT', root):
                runner.retain_manifest(output, generated, manifest)
                runner.retain_manifest(output, generated, manifest, finalized=True)
            selected = [p for p in output.rglob('*') if p.is_file()
                        and all(not part.startswith('.') for part in p.relative_to(output).parts)]
            self.assertFalse(any(p.name.startswith('.flax_probe_') for p in selected))
            with zipfile.ZipFile(io.BytesIO(), 'w') as artifact:
                for path in selected:
                    artifact.writestr(path.relative_to(output).as_posix(), path.read_bytes())
                self.assertEqual(manifest['upload_alias_status'], 'complete_for_existing_generated_files')
                self.assertEqual(len(manifest['upload_aliases']), 8)
                for original, row in zip(generated, manifest['upload_aliases']):
                    self.assertEqual(row['original_path'], str(original))
                    self.assertEqual(row['status'], 'retained')
                    data = artifact.read(row['alias_path'])
                    self.assertEqual(data, original.read_bytes())
                    self.assertEqual(len(data), row['bytes'])
                    self.assertEqual(hashlib.sha256(data).hexdigest(), row['sha256'])
                    self.assertLessEqual(row['bytes'], row['limit_bytes'])
                self.assertNotIn('unrelated-secret', '\n'.join(artifact.namelist()))
            self.assertTrue((root / '.unrelated-secret').exists())
            workflow = (ROOT / '.github/workflows/test.yml').read_text()
            upload = workflow.split('      - name: Upload flax processing evidence\n', 1)[1].split('      - name:', 1)[0]
            self.assertNotIn('include-hidden-files', upload)

    def test_overrun_unowned_input_and_alias_collision_fail_without_deletion(self):
        for defect in ('source_limit', 'artifact_limit', 'file_limit', 'total_limit', 'unowned', 'collision'):
            with self.subTest(defect=defect), tempfile.TemporaryDirectory(prefix='flax-upload-negative-') as directory:
                root = Path(directory)
                generated, output, manifest = self.fixture(root)
                with ExitStack() as stack:
                    stack.enter_context(patch.object(runner, 'ROOT', root))
                    if defect in ('source_limit', 'artifact_limit', 'file_limit', 'total_limit'):
                        bound = {'source_limit': 'INPUT_LIMIT', 'artifact_limit': 'ARTIFACT_LIMIT',
                                 'file_limit': 'FILE_LIMIT', 'total_limit': 'OUTPUT_LIMIT'}[defect]
                        stack.enter_context(patch.object(runner, bound, 1))
                    if defect == 'unowned':
                        generated.append(root / '.unrelated-secret')
                    collision = output / 'generated-inputs/generated-0.dme'
                    if defect == 'collision':
                        collision.write_bytes(b'preserve earlier evidence')
                    with self.assertRaises(RuntimeError):
                        runner.retain_manifest(output, generated, manifest)
                receipt = json.loads((output / 'evidence-manifest.json').read_text())
                self.assertEqual(receipt['upload_alias_status'], 'failed')
                self.assertTrue(all(path.exists() for path in generated))
                self.assertEqual((root / '.unrelated-secret').read_bytes(), b'never enumerate or copy this')
                if defect == 'collision':
                    self.assertEqual(collision.read_bytes(), b'preserve earlier evidence')


class NativePhaseRetention(unittest.TestCase):
    def exercise(self, mode):
        with tempfile.TemporaryDirectory(prefix='flax-phase-offline-') as directory:
            output = Path(directory)

            class Child:
                pid = 12345
                def __init__(self):
                    self.stdout = io.BytesIO(b'0123456789abcdef' if mode == 'over_limit' else b'partial stdout')
                    self.stderr = io.BytesIO(b'partial stderr')
                    self.returncode = None if mode in ('timeout', 'interrupt', 'sigterm') else 7 if mode == 'early_exit' else 0
                def poll(self): return self.returncode
                def kill(self): self.returncode = -9
                def wait(self, timeout): return self.returncode

            child = Child()
            clocks = [0, KeyboardInterrupt('offline signal')] if mode == 'interrupt' else [0, 2]
            with ExitStack() as stack:
                stack.enter_context(patch.object(runner.subprocess, 'Popen', return_value=child))
                stack.enter_context(patch.object(runner.time, 'monotonic', side_effect=clocks))
                if mode == 'over_limit':
                    stack.enter_context(patch.object(runner, 'LOG_LIMIT', 8))
                    # Isolate the stream cap from the much larger JSON receipt.
                    stack.enter_context(patch.object(runner, 'check_output_budget', return_value=(0, 0)))
                if mode == 'sigterm':
                    calls = 0
                    def invoke_handler(directory):
                        nonlocal calls
                        calls += 1
                        if calls == 1:
                            return (0, 0)  # Prelaunch guard; interrupt only after launch.
                        runner.signal.getsignal(runner.signal.SIGTERM)(runner.signal.SIGTERM, None)
                    stack.enter_context(patch.object(runner, 'check_output_budget', side_effect=invoke_handler))
                if mode in ('timeout', 'interrupt', 'sigterm', 'over_limit'):
                    with self.assertRaises((runner.subprocess.TimeoutExpired, KeyboardInterrupt, InterruptedError, RuntimeError)):
                        runner.run_phase(['never-launched'], cwd=output, output=output, phase='daemon', timeout=1)
                else:
                    result = runner.run_phase(['never-launched'], cwd=output, output=output, phase='daemon', timeout=1)
                    self.assertEqual(result.returncode, 7 if mode == 'early_exit' else 0)
            receipt = json.loads((output / 'daemon-phase.json').read_text())
            self.assertEqual(receipt['descendant_cleanup'], 'unverified')
            self.assertEqual(receipt['socket_cleanup'], 'unverified')
            self.assertEqual(receipt['returncode_status'], 'observed')
            self.assertEqual(receipt['returncode'], child.returncode)
            self.assertEqual(receipt['retention_complete_scope'], 'captured_streams_only')
            self.assertTrue(receipt['stream_writers_closed'])
            self.assertTrue(receipt['direct_child_exited'])
            if mode == 'over_limit':
                self.assertEqual((output / 'daemon.stdout.log').read_bytes(), b'01234567')
                self.assertTrue(receipt['streams']['stdout']['truncated'])
                self.assertFalse(receipt['retention_complete'])
            else:
                self.assertEqual((output / 'daemon.stdout.log').read_text(), 'partial stdout')
                self.assertEqual((output / 'daemon.stderr.log').read_text(), 'partial stderr')
                self.assertTrue(receipt['retention_complete'])

    def test_timeout_interrupt_signal_and_early_exit_preserve_partial_streams(self):
        for mode in ('timeout', 'interrupt', 'sigterm', 'early_exit', 'success'):
            with self.subTest(mode=mode):
                self.exercise(mode)

    def test_oversized_stream_retains_bounded_prefix_and_cannot_pass(self):
        self.exercise('over_limit')

    def test_postlaunch_budget_failure_records_observed_or_unknown_exit_without_passing(self):
        for outcome in ('killed', 'zero', 'unknown'):
            with self.subTest(outcome=outcome), tempfile.TemporaryDirectory(prefix='flax-budget-cleanup-') as directory:
                output = Path(directory)
                class Child:
                    pid = 12345
                    returncode = None
                    stdout = io.BytesIO(b'partial stdout')
                    stderr = io.BytesIO(b'partial stderr')
                    def poll(self): return self.returncode
                    def kill(self):
                        if outcome == 'unknown': raise OSError('injected stop failure')
                        self.returncode = 0 if outcome == 'zero' else -9
                    def wait(self, timeout): return self.returncode
                child = Child()
                calls = 0
                def budget(*args):
                    nonlocal calls
                    calls += 1
                    if calls > 1: raise RuntimeError('injected postlaunch budget failure')
                    return (0, 0)
                with patch.object(runner.subprocess, 'Popen', return_value=child) as launch, \
                        patch.object(runner, 'check_output_budget', side_effect=budget):
                    with self.assertRaisesRegex(RuntimeError, 'postlaunch budget failure'):
                        runner.run_phase(['never-launched'], cwd=output, output=output, phase='daemon', timeout=1)
                    launch.assert_called_once()
                receipt = json.loads((output/'daemon-phase.json').read_text())
                self.assertEqual(receipt['status'], 'failed')
                self.assertEqual(receipt['returncode'], None if outcome == 'unknown' else 0 if outcome == 'zero' else -9)
                self.assertEqual(receipt['returncode_status'], 'unknown' if outcome == 'unknown' else 'observed')
                self.assertEqual(receipt['direct_child_exited'], outcome != 'unknown')
                self.assertTrue(receipt['stream_retention_complete'])
                self.assertEqual(receipt['descendant_cleanup'], 'unverified')
                self.assertEqual(receipt['socket_cleanup'], 'unverified')


if __name__ == '__main__':
    unittest.main(verbosity=2)
