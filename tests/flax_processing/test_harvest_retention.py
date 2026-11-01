"""Linux harvest fallback, injected phases only; never native cleanup evidence."""
from contextlib import ExitStack, redirect_stdout, redirect_stderr
import hashlib
import importlib.util
import io
import json
import shlex
from pathlib import Path
import tempfile
from types import SimpleNamespace as NS
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('harvest_retention_contract', ROOT/'tests/animal_harvest/run.py')
harvest = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harvest)


class HarvestRetention(unittest.TestCase):
    def workflow_arguments(self):
        workflow=(ROOT/'.github/workflows/test.yml').read_text()
        step=workflow.split('- name: Verify bounded animal harvesting and binding conservation',1)[1].split('\n      - name:',1)[0]
        self.assertIn("contains(fromJSON(needs.changes.outputs.new_tests || '[]'), 'tests/animal_harvest')",step)
        line=next(line.strip() for line in step.splitlines() if 'tests/animal_harvest/run.py ' in line)
        tokens=shlex.split(line)
        self.assertEqual(tokens[:2],['/usr/bin/python3','tests/animal_harvest/run.py'])
        self.assertEqual(tokens[tokens.index('--acceptance-scope')+1],'limited')
        self.assertNotIn('--external-cleanup-receipt',tokens)
        return tokens[2:]

    def exercise(self, defect=None, scope='full', workflow=False):
        name_plan = harvest.required_name_plan()
        with tempfile.TemporaryDirectory(prefix='harvest-offline-retain-') as temporary, ExitStack() as stack:
            root = Path(temporary)
            (root/'code').mkdir()
            (root/'code/world.dm').write_text('/world/New()\n\t..()\n')
            (root/'civ13.dme').write_text('#include "code\\world.dm"\n')
            (root/'config/names').mkdir(parents=True)
            (root/'tests/flax_processing').mkdir(parents=True)
            (root/'tests/flax_processing/run.py').write_bytes((ROOT/'tests/flax_processing/run.py').read_bytes())
            (root/'tests/animal_harvest').mkdir()
            (root/'tests/animal_harvest/hide_recipe_probe.dm').write_bytes(
                (ROOT/'tests/animal_harvest/hide_recipe_probe.dm').read_bytes())
            logs = root/'evidence'
            receipt_path = root/'external-receipt.json'
            launches = []

            def launch(command, *, cwd, output, phase, timeout, **kwargs):
                launches.append(phase)
                (logs/(phase+'.stdout.log')).write_text('partial offline stdout')
                (logs/(phase+'.stderr.log')).write_text('partial offline stderr')
                (logs/(phase+'-phase.json')).write_text(json.dumps(dict(pid=111 if phase.endswith('compile') else 222,
                    direct_child_exited=True, stream_writers_closed=True, retention_complete=True, returncode=0)))
                if phase.endswith('compile'):
                    Path(command[-1]).with_suffix('.dmb').write_bytes(b'offline binary placeholder')
                    Path(command[-1]).with_suffix('.rsc').write_bytes(b'offline resource placeholder')
                    if defect == 'compile_timeout':
                        raise harvest.subprocess.TimeoutExpired(command, timeout)
                    return NS(returncode=0, stdout='DM compiler version 516.1688\nprobe.dmb - 0 errors, 0 warnings\n', stderr='')
                (cwd/'runtime.log').write_text('offline diagnostic survives')
                (cwd/'errors.txt').write_text('')
                (cwd/'port-closed.txt').write_text('closed')
                if defect == 'runtime_timeout':
                    raise harvest.subprocess.TimeoutExpired(command, timeout)
                if defect == 'runtime_interrupt':
                    raise KeyboardInterrupt('offline interruption')
                if defect != 'early_exit':
                    (cwd/'result.txt').write_text('PASS: injected offline result')
                if scope != 'full':
                    return NS(returncode=0, stdout='', stderr='')
                manifest = json.loads((logs/'evidence-manifest.json').read_text())
                os_record = 'SYNTHETIC OFFLINE TEST ONLY; not actual OS observations'
                (logs/'observer.json').write_text(os_record)
                receipt = dict(head_sha='a'*40, run_id=manifest['run_id'], evidence_directory=str(logs.resolve()),
                    phase_pids=[111,222], descendants_exited=True, sockets_closed=True, external_verifier='offline-test',
                    os_evidence_path='observer.json', os_evidence_sha256=hashlib.sha256(os_record.encode()).hexdigest())
                if defect == 'wrong_run': receipt['run_id'] = 'unrelated'
                if defect == 'wrong_head': receipt['head_sha'] = 'b'*40
                if defect == 'wrong_pid': receipt['phase_pids'] = [999]
                if defect == 'unverified': receipt['descendants_exited'] = False
                if defect == 'open_socket': receipt['sockets_closed'] = False
                if defect == 'self_receipt': receipt['external_verifier'] = 'runner'
                if defect == 'unsafe_os_path': receipt['os_evidence_path'] = '../outside.json'
                if defect == 'wrong_hash': receipt['os_evidence_sha256'] = '0'*64
                if scope == 'full' and defect != 'missing_receipt': receipt_path.write_text(json.dumps(receipt))
                return NS(returncode=0, stdout='', stderr='')

            stack.enter_context(patch.object(harvest, 'ROOT', root))
            stack.enter_context(patch.object(harvest, 'required_name_plan', return_value=name_plan))
            stack.enter_context(patch.object(harvest.sys, 'platform', 'linux'))
            stack.enter_context(patch.object(harvest.subprocess, 'check_output', return_value='a'*40))
            stack.enter_context(patch.object(harvest, 'runtime_identity', return_value={'scope':'offline-injected'}))
            stack.enter_context(patch.object(harvest.evidence, 'run_phase', side_effect=launch))
            stack.enter_context(patch.object(harvest, 'run_native', side_effect=AssertionError('No bare Linux fallback')))
            stack.enter_context(patch.object(harvest, 'Session', side_effect=AssertionError('No native Session in test')))
            stack.enter_context(patch.object(Path, 'unlink', side_effect=AssertionError('Never delete evidence')))
            captured = io.StringIO()
            stack.enter_context(redirect_stdout(captured))
            arguments = self.workflow_arguments() if workflow else ['--byond-bin',str(root/'bin'),'--byond-archive',str(root/'pin.zip')]
            arguments += ['--evidence-dir',str(logs),'--cleanup-receipt-wait','0']
            if not workflow and scope is not None: arguments += ['--acceptance-scope',scope]
            if scope == 'full': arguments += ['--external-cleanup-receipt',str(receipt_path)]
            else:
                stack.enter_context(patch.object(harvest,'verify_external_cleanup',side_effect=AssertionError('Limited mode cannot claim external cleanup')))
            if defect:
                with self.assertRaises((RuntimeError, FileNotFoundError, harvest.subprocess.TimeoutExpired, KeyboardInterrupt)):
                    harvest.main(arguments)
            else:
                harvest.main(arguments)
            manifest = json.loads((logs/'evidence-manifest.json').read_text())
            self.assertFalse(manifest['automatic_deletion'])
            self.assertTrue(list(root.glob('.animal_harvest_ci_*.dme')))
            self.assertTrue(list((logs/'generated-inputs').glob('*.dme')))
            self.assertTrue((logs/'harvest-compile.stderr.log').exists())
            if len(launches)==2:
                self.assertIn('diagnostic survives', (logs/'runtime/runtime.log').read_text())
            self.assertEqual(manifest['status'], 'failed' if defect else 'fixture_pass_with_cleanup_evidence' if scope == 'full' else 'limited_fixture_pass_cleanup_unverified')
            self.assertFalse(manifest['full_acceptance_complete'])
            if not defect and scope == 'full':
                self.assertTrue(manifest['external_cleanup_receipt']['requires_independent_os_evidence_review'])
            elif not defect:
                self.assertEqual(manifest['acceptance_scope'],'limited')
                self.assertEqual(manifest['external_descendant_cleanup'],'unverified_limited_scope')
                self.assertFalse(manifest['external_cleanup_required'])
                self.assertNotIn('external_cleanup_receipt',manifest)
                self.assertFalse(receipt_path.exists())
                self.assertFalse((logs/'observer.json').exists())
                self.assertIn('LIMITED fixture checks only',captured.getvalue())

    def test_linux_uses_retained_phase_adapter_and_preserves_all_inputs(self):
        self.exercise()

    def test_timeout_interruption_and_early_exit_keep_diagnostics(self):
        for defect in ('compile_timeout','runtime_timeout','runtime_interrupt','early_exit'):
            with self.subTest(defect=defect): self.exercise(defect)

    def test_missing_mismatched_or_unverified_external_cleanup_never_passes(self):
        for defect in ('missing_receipt','wrong_run','wrong_head','wrong_pid','unverified','open_socket','self_receipt','unsafe_os_path','wrong_hash'):
            with self.subTest(defect=defect): self.exercise(defect)

    def test_existing_workflow_selects_only_limited_checks_without_cleanup_producer(self):
        self.exercise(scope='limited',workflow=True)

    def test_legacy_arguments_preserve_limited_checks_but_not_cleanup_acceptance(self):
        self.exercise(scope=None)
        self.exercise('early_exit',scope='limited')

    def test_full_selection_requires_receipt_and_limited_selection_cannot_consume_one(self):
        base=['--byond-bin','unused-bin','--byond-archive','unused-pin.zip']
        for selection in (['--acceptance-scope','full'],
                          ['--acceptance-scope','limited','--external-cleanup-receipt','unused.json'],
                          ['--acceptance-scope','unknown']):
            with self.subTest(selection=selection), \
                 patch.object(harvest.sys,'platform','linux'), \
                 patch.object(harvest,'run_retained',side_effect=AssertionError('No native launch')) as launch, \
                 patch.object(harvest.subprocess,'check_output',side_effect=AssertionError('No source/process work')) as git, \
                 redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as failure: harvest.main(base+selection)
                self.assertEqual(failure.exception.code,2)
                launch.assert_not_called()
                git.assert_not_called()


if __name__ == '__main__':
    unittest.main(verbosity=2)
