"""Offline flax runner contracts with all native launch/identity seams injected."""
from contextlib import ExitStack, redirect_stdout
import importlib.util
import io
import json
from pathlib import Path
from types import SimpleNamespace as NS
import tempfile
import unittest
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

    def exercise(self, defect=None):
        with tempfile.TemporaryDirectory(prefix='flax-runner-offline-') as directory, ExitStack() as stack:
            root = Path(directory)
            # Only source inputs and synthetic output files; no executables.
            for relative in (runner.CORE, 'code/modules/persistence/saving.dm',
                             'code/modules/persistence/loading.dm', 'code/modules/persistence/functions.dm',
                             'config/crafting/material_recipes_global.txt', 'code/modules/research_tree/research_node.dm',
                             'tests/flax_processing/probe.dm', 'tests/flax_processing/run.py',
                             'scripts/byond_runtime.py', 'scripts/byond_toolchain.py', 'tools/byond/version.json'):
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / relative).read_bytes())
            (root / 'config/names').mkdir()
            (root / 'code/controllers/mc').mkdir(parents=True)
            (root / 'code/world.dm').write_text('/world/New()\n\t..()\n/datum/global_init/New()\n\treturn\n')
            (root / 'code/controllers/mc/globals.dm').write_text('/datum/controller/global_vars/New()\n\treturn\n')
            (root / 'civ13.dme').write_text('#include "code\\world.dm"\n#include "code\\controllers\\mc\\globals.dm"\n#include "code\\modules\\1713\\flax_processing.dm"\n')
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
                if len(launches) == 1:
                    events.append('compile')
                    dme = Path(command[-1])
                    dme.with_suffix('.dmb').write_bytes(b'offline test data')
                    dme.with_suffix('.rsc').write_bytes(b'offline test data')
                    version = '516.1681' if defect == 'old_banner' else '516.1688'
                    return NS(returncode=0, stdout=f'DM compiler version {version}\nprobe.dmb - 0 errors, 0 warnings\n', stderr='')
                events.append('daemon')
                self.assertIn('-trusted', command)
                work = kwargs['cwd']
                (work / 'result.txt').write_text('PASS: flax processing and native disk round trips')
                (work / 'runtime.log').write_text('offline injected runner test')
                return NS(returncode=0, stdout='', stderr='')

            stack.enter_context(patch.object(runner, 'ROOT', root))
            stack.enter_context(patch.object(runner, 'runtime_identity', side_effect=verify))
            stack.enter_context(patch.object(runner.subprocess, 'check_output', side_effect=['a' * 40, b'']))
            stack.enter_context(patch.object(runner.subprocess, 'run', side_effect=launch))
            stack.enter_context(patch.object(runner.sys, 'argv', ['run.py', '--byond-bin', str(root / 'bin'),
                '--byond-archive', str(root / 'pinned.zip'), '--output', str(output)]))
            # Synthetic native-result text must not look like real acceptance.
            stack.enter_context(redirect_stdout(io.StringIO()))
            if defect:
                with self.assertRaises((RuntimeError, ValueError)):
                    runner.main()
            else:
                runner.main()
                self.assertEqual(json.loads((output / 'metadata.json').read_text())['expected_byond_version'], '516.1688')
                self.assertEqual(json.loads((output / 'compiler-runtime.json').read_text()), identity)
                self.assertEqual(json.loads((output / 'daemon-runtime.json').read_text()), identity)
            self.assertEqual(list(root.glob('.flax_probe_*')), [], 'generated fixture files must be cleaned')
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

    def test_all_three_existing_mutation_controls_still_have_unique_targets(self):
        self.assertEqual(set(runner.CONTROLS), {'payment', 'replay', 'persistence'})
        original = runner.source_for(None)
        for control, (old, new, _) in runner.CONTROLS.items():
            self.assertEqual(original.count(old), 1)
            self.assertEqual(runner.source_for(control), original.replace(old, new, 1))


if __name__ == '__main__':
    unittest.main(verbosity=2)
