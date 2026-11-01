"""Offline bootstrap command contract: stub sudo, never run apt or BYOND."""
import os
import ast
import importlib.util
import json
import shlex
import shutil
import socket
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/travis_pre_byond.sh'
BASH = r'C:\Program Files\Git\bin\bash.exe' if os.name == 'nt' else '/bin/bash'


def shell_path(path):
    text = str(path).replace('\\', '/')
    return '/' + text[0].lower() + text[2:] if os.name == 'nt' else text

class ByondBootstrapTests(unittest.TestCase):
    def test_train_shell_syntax_and_missing_identity_cli_are_inert(self):
        script = shell_path(ROOT / 'tests/train_collision/run.sh')
        subprocess.run([BASH, '-n', script], check=True, timeout=5)
        for options in ([], ['--legacy-fixture-5161681']):
            result = subprocess.run([BASH, '--noprofile', '--norc', script, *options],
                                    capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 2)
            self.assertIn('Usage: run.sh', result.stderr)

    def test_unknown_or_retired_option_exits_before_setup(self):
        for option in ('--unreviewed-version', '--legacy-fixture-5161681'):
            result = subprocess.run([BASH, '--noprofile', '--norc', shell_path(SCRIPT), option],
                                    capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 2)
            self.assertIn('Unsupported BYOND bootstrap option', result.stderr)
            self.assertNotIn('Setting up', result.stdout)

    def run_package_prefix(self, fail_phase='', fail_status=19):
        source = SCRIPT.read_text()
        marker = 'echo "Setting up BYOND."'
        self.assertEqual(source.count(marker), 1)
        prefix = ('set -eo pipefail\n' + source.split('# BEGIN package setup\n')[1].split('# END package setup')[0]
                  + '\nprintf "%s\\n" NATIVE_SETUP_REACHED\n')
        with tempfile.TemporaryDirectory(prefix='byond-bootstrap-stubs-') as temporary:
            root = Path(temporary)
            # PATH contains only this stub. No sudo, env, apt, dpkg, network or
            # compiler command can execute outside it; printf is a shell builtin.
            stub = root / 'sudo'
            stub.write_text('''#!/bin/sh
printf '%s\\n' "$*" >> "$COMMAND_LOG"
case "$*" in
  *" update") [ "$FAIL_PHASE" = update ] && exit "$FAIL_STATUS" ;;
  *" install "*) [ "$FAIL_PHASE" = install ] && exit "$FAIL_STATUS" ;;
esac
exit 0
''')
            stub.chmod(0o700)
            log = root / 'commands.txt'
            result = subprocess.run([BASH, '--noprofile', '--norc', '-c', prefix], cwd=root,
                                    env={'PATH': shell_path(root), 'COMMAND_LOG': shell_path(log),
                                         'FAIL_PHASE': fail_phase, 'FAIL_STATUS': str(fail_status)},
                                    capture_output=True, text=True, timeout=5)
            return result, log.read_text().splitlines()

    def test_only_existing_packages_are_installed_noninteractively(self):
        result, commands = self.run_package_prefix()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, [
            'timeout -k 5 30 dpkg --add-architecture i386',
            'env DEBIAN_FRONTEND=noninteractive timeout -k 5 120 apt-get -o Acquire::Retries=2 -o Acquire::http::Timeout=15 -o Acquire::https::Timeout=15 update',
            'env DEBIAN_FRONTEND=noninteractive timeout -k 5 180 apt-get -o Acquire::Retries=2 -o Acquire::http::Timeout=15 -o Acquire::https::Timeout=15 install -y --no-install-recommends python3 wget git unzip make sudo libstdc++6:i386 libgcc-s1:i386 libc6-i386 libcurl4:i386 lib32z1 libncurses6 libncurses6:i386',
        ])
        self.assertIn('NATIVE_SETUP_REACHED', result.stdout)
        self.assertFalse(any('upgrade' in command for command in commands))

    def test_package_failure_stops_before_install_or_native_setup(self):
        for phase, count in (('update', 2), ('install', 3)):
            # Include APT's nonzero refusal and the observed outer timeout. There
            # is no shell-level retry or fall-through into native setup.
            for status in (19, 100, 124):
                with self.subTest(phase=phase, status=status):
                    result, commands = self.run_package_prefix(phase, status)
                    self.assertEqual(result.returncode, status)
                    self.assertEqual(len(commands), count)
                    self.assertNotIn('NATIVE_SETUP_REACHED', result.stdout)

    def test_transfer_options_do_not_modify_sources_authentication_or_host_networking(self):
        result, commands = self.run_package_prefix()
        self.assertEqual(result.returncode, 0, result.stderr)
        # Only the three existing privileged invocations execute. APT's own
        # retry budget stays inside the unchanged outer phase timeouts.
        self.assertEqual(len(commands), 3)
        for command in commands[1:]:
            tokens = shlex.split(command)
            self.assertEqual(tokens.count('Acquire::Retries=2'), 1)
            self.assertEqual(tokens.count('Acquire::http::Timeout=15'), 1)
            self.assertEqual(tokens.count('Acquire::https::Timeout=15'), 1)
            self.assertFalse(any(flag in command for flag in (
                '--allow-unauthenticated', '--allow-insecure-repositories', '--fix-missing',
                'Verify-Peer=false', 'Verify-Host=false', 'ForceIPv', 'sources.list',
                '/etc/apt/', 'iptables', 'ufw', 'sysctl')))

    def test_download_is_bounded_and_uses_only_canonical_verified_acquisition(self):
        source = SCRIPT.read_text()
        self.assertFalse(any(line.strip().startswith(('wget ', 'timeout -k 5 65 wget '))
                             for line in source.splitlines()))
        self.assertNotIn('legacy_fixture', source)
        self.assertIn('byond_version="$(python3 "$script_dir/byond_toolchain.py" field version)"', source)
        self.assertIn('timeout -k 5 65 python3 "$script_dir/byond_toolchain.py" download', source)

    def test_shell_syntax_and_pinned_compiler_contract(self):
        subprocess.run([BASH, '-n', shell_path(SCRIPT)], check=True, timeout=5)
        source = SCRIPT.read_text()
        self.assertNotIn('516.1681', source)
        self.assertNotIn('--legacy-fixture-5161681', source)
        self.assertIn('archive_args=(--platform linux --output pinned.zip --source "${BYOND_ARCHIVE_SOURCE:-official}")', source)
        self.assertIn('byond_toolchain.py" download "${archive_args[@]}"', source)
        self.assertIn('--cache-dir "$BYOND_ARCHIVE_CACHE"', source)
        self.assertIn('byond-download.json', source)
        self.assertIn('DM compiler version $byond_version', source)
        self.assertIn('timeout -k 5 300 DreamMaker -max_errors 0 civ13.dme 2>&1 | tee result.log', source)
        self.assertIn("grep -q -- '- 0 errors, 0 warnings' result.log", source)
        self.assertNotIn('/home/runner/work/', source)
        for contract in ('set -eo pipefail', 'timeout -k 5 65 python3',
                         'timeout -k 5 30 unzip', 'timeout -k 5 60 make',
                         'byond-archive.sha256', 'trap ', 'source-before.patch'):
            self.assertIn(contract, source)

    def test_compiler_status_and_warning_contract_using_shell_functions_only(self):
        source = SCRIPT.read_text()
        function = source.split('# BEGIN compiler status contract\n')[1].split('# END compiler status contract')[0]
        for compiler_status, line, tee_status, expected in (
                (0, '- 0 errors, 0 warnings', 0, 0),
                (9, '- 0 errors, 0 warnings', 0, 9),
                (0, '- 0 errors, 1 warnings', 0, 1),
                (0, 'missing summary', 0, 1),
                (0, '- 0 errors, 0 warnings', 23, 23)):
            with self.subTest(compiler_status=compiler_status, line=line, tee_status=tee_status):
                # Neither timeout nor a compiler executable is invoked. These
                # shell functions emit fixed synthetic text and return statuses.
                stub = ('byond_version=516.1688\ntimeout() { shift 3; "$@"; }\n'
                        f'DreamMaker() {{ printf "%s\\n" "DM compiler version 516.1688" "{line}"; return {compiler_status}; }}\n')
                if tee_status:
                    stub += f'tee() {{ cat > /dev/null; return {tee_status}; }}\n'
                with tempfile.TemporaryDirectory() as temporary:
                    result = subprocess.run([BASH, '--noprofile', '--norc', '-c',
                                             'set -eo pipefail\n' + stub + function + '\ncompile_game'],
                                            cwd=temporary, capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, expected, result.stderr)

class RetiredInstallerTests(unittest.TestCase):
    def check_retired(self, command):
        for arguments in ([], ['516', '1681'], ['516', '1688'], ['--help']):
            with self.subTest(arguments=arguments), tempfile.TemporaryDirectory(prefix='retired installer ') as temporary:
                root = Path(temporary)
                sentinel = root / 'existing-save'
                sentinel.write_bytes(b'preserve existing data')
                # No external setup command can be resolved through PATH.
                # Both retired entrypoints need only their interpreter/builtins.
                result = subprocess.run([*command, *arguments], cwd=root,
                                        env={'PATH': '', 'SYSTEMROOT': os.environ.get('SYSTEMROOT', '')},
                                        capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertEqual(result.stdout, '')
                for text in ('retired; no changes were made', 'tools/byond/version.json',
                             'docs/local-wsl.md', 'Windows/WSL', 'Debian-compatible Linux',
                             'not a production-server migration', 'NOT upgraded'):
                    self.assertIn(text, result.stderr)
                self.assertEqual(list(root.iterdir()), [sentinel])
                self.assertEqual(sentinel.read_bytes(), b'preserve existing data')

    def test_shell_entrypoint_fails_without_provisioning_from_other_directory(self):
        self.check_retired([BASH, '--noprofile', '--norc', shell_path(ROOT / 'INSTALL')])

    def test_python_entrypoint_fails_without_provisioning_from_other_directory(self):
        self.check_retired([sys.executable, '-I', '-B', str(ROOT / 'INSTALL.py')])


class ManualCanonicalProfileTests(unittest.TestCase):
    """Execute entrypoint/identity seams with fake native children only."""
    def setUp(self):
        self.temp = self.enterContext(tempfile.TemporaryDirectory(prefix='manual-fixture-offline-'))
        self.root = Path(self.temp)
        self.enterContext(patch.object(subprocess, 'Popen', side_effect=AssertionError('Native spawn forbidden')))
        self.enterContext(patch.object(socket, 'socket', side_effect=AssertionError('Network forbidden')))
        self.events = []

    def module(self, name, relative):
        spec = importlib.util.spec_from_file_location(name, ROOT / relative)
        value = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(value)
        return value

    def runtime(self, reject=None):
        shared = self.module('manual_current_runtime', 'tests/world_save/current_runtime.py')
        value = shared.CurrentRuntime.__new__(shared.CurrentRuntime)
        value.identity = {'version': json.loads((ROOT / 'tools/byond/version.json').read_text())['version']}
        value.compiler = self.module('manual_compile_diagnostics', 'tests/new_z_budget/z_budget_evidence.py')
        def before(role, output):
            self.events.append(role)
            if role == reject:
                raise ValueError('identity changed before ' + role)
        value.before_launch = Mock(side_effect=before)
        return value

    def train(self):
        source = (ROOT / 'tests/train_collision/run.sh').read_text()
        code = source.split("<<'PY'\n", 1)[1].rsplit('\nPY', 1)[0]
        namespace = {'__name__': 'offline_train_driver'}
        exec(compile(code, 'train_collision/run.sh:python-driver', 'exec'), namespace)
        return namespace

    def populate(self, relative):
        target = self.root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / relative, target)

    def component_source(self):
        for relative in ('scripts/check-component-tools.py', 'code/world.dm', 'code/controllers/mc/globals.dm',
                         'code/game/objects/structures/blacksmithing/component_workbench.dm', 'civ13.dme',
                         'tests/component_tools/checks.dm', 'tests/component_tools/workbench.dm',
                         'tests/world_save/current_runtime.py', 'scripts/byond_runtime.py',
                         'scripts/byond_toolchain.py', 'tools/byond/version.json', 'tests/new_z_budget/z_budget_evidence.py'):
            self.populate(relative)
        for name in ('crafting', 'names'):
            directory = self.root / 'config' / name
            directory.mkdir(parents=True)
            (directory / 'offline.txt').write_text('isolated config fixture')

    def component(self, control=None, *, reject=None, build=None, runtime_log='', marker=None, load_error=None):
        self.component_source()
        module = self.module('manual_component', 'scripts/check-component-tools.py')
        runtime = self.runtime(reject)
        output = self.root / 'evidence'
        calls = []
        def native(command, **kwargs):
            role = 'compiler' if Path(command[0]).name == 'DreamMaker' else 'daemon'
            calls.append(command)
            self.assertEqual(self.events[-1], role)
            self.assertEqual(kwargs['timeout'], 180 if role == 'compiler' else 90)
            if role == 'compiler':
                if isinstance(build, BaseException): raise build
                for suffix in ('.dmb', '.rsc'):
                    (output / 'source' / ('recipes' + suffix)).write_bytes(b'offline artifact')
                text = 'DM compiler version ' + runtime.identity['version'] + '\nrecipes.dmb - 0 errors, 0 warnings\n'
                return subprocess.CompletedProcess(command, 0, build or text, '')
            kwargs['stdout'].write(runtime_log)
            if marker is not False:
                (output / 'runtime/component-checks.txt').write_text(marker or ('FAIL' if control else 'PASS'))
            return subprocess.CompletedProcess(command, 0)
        options = ['--byond-bin', str(self.root), '--byond-archive', str(self.root / 'inert.zip'), '--output', str(output)]
        if control: options += ['--negative-control', control]
        with patch.object(module, 'ROOT', self.root), patch.object(module, 'load_runtime', return_value=runtime, side_effect=load_error), \
                patch.object(subprocess, 'run', side_effect=native):
            return module.main(options), output, runtime, calls

    def test_component_positive_and_both_existing_omission_controls(self):
        for control in (None, 'consumption', 'runtime-save'):
            with self.subTest(control=control), tempfile.TemporaryDirectory() as temp:
                self.root = Path(temp); self.events = []
                code, output, runtime, calls = self.component(control)
                self.assertEqual(code, 0)
                self.assertEqual([c[0] for c in runtime.before_launch.call_args_list], [('compiler', output), ('daemon', output)])
                self.assertEqual(len(calls), 2)
                self.assertTrue((output / 'generated-source.json').exists())
                self.assertIn(str(self.root).replace('\\', '/'), (output / 'source/recipes.dme').read_text())
                if control:
                    mutated = (output / 'source/bench.dm').read_text()
                    self.assertEqual('Deliberately leave both paid components alive.' in mutated, control == 'consumption')
                    if control == 'runtime-save': self.assertNotIn('(key in list("busy", "cancelled", "assembler", "assembly_time"))', mutated)
                self.assertEqual((output / 'runtime/config/names/offline.txt').read_text(), 'isolated config fixture')

    def test_component_cli_requires_identity_and_new_evidence_before_any_effect(self):
        module = self.module('manual_component_cli', 'scripts/check-component-tools.py')
        with patch.object(module, 'load_runtime', side_effect=AssertionError('Identity must not be reached')):
            for options in ([], ['--compiler', 'DreamMaker'], ['--byond-bin', str(self.root)]):
                with self.subTest(options=options), self.assertRaises(SystemExit): module.main(options)
        self.assertEqual(list(self.root.iterdir()), [])

    def test_component_wrong_banner_and_warning_stop_before_daemon(self):
        for log in ('DM compiler version 516.1681\nrecipes.dmb - 0 errors, 0 warnings\n',
                    'DM compiler version 516.1688\nrecipes.dmb - 0 errors, 1 warnings\n'):
            with self.subTest(log=log), tempfile.TemporaryDirectory() as temp:
                self.root = Path(temp); self.events = []
                with self.assertRaises(RuntimeError): self.component(build=log)
                self.assertEqual(self.events, ['compiler'])
                self.assertTrue((self.root / 'evidence/compile.log').exists())
                self.assertTrue((self.root / 'evidence/failure.json').exists())

    def test_component_identity_recheck_failure_prevents_each_native_role(self):
        for role in ('compiler', 'daemon'):
            with self.subTest(role=role), tempfile.TemporaryDirectory() as temp:
                self.root = Path(temp); self.events = []
                with self.assertRaisesRegex(ValueError, 'identity changed'): self.component(reject=role)
                self.assertEqual(self.events[-1], role)
                self.assertTrue((self.root / 'evidence/failure.json').exists())

    def test_component_timeout_retains_partial_compile_and_failure(self):
        with self.assertRaises(subprocess.TimeoutExpired):
            self.component(build=subprocess.TimeoutExpired('offline', 180, output=b'partial compile'))
        self.assertEqual((self.root / 'evidence/compile.log').read_text(), 'partial compile')
        self.assertEqual(self.events, ['compiler'])

    def test_component_initial_identity_failure_retains_inputs_without_launch(self):
        self.component_source()
        module = self.module('component_bad_archive', 'scripts/check-component-tools.py')
        output = self.root / 'evidence'
        with patch.object(module, 'ROOT', self.root), \
                patch.object(module, 'load_runtime', side_effect=ValueError('Archive hash mismatch')):
            with self.assertRaisesRegex(ValueError, 'Archive hash mismatch'):
                module.main(['--byond-bin', str(self.root), '--byond-archive', str(self.root / 'inert.zip'), '--output', str(output)])
        self.assertTrue((output / 'inputs.json').exists())
        self.assertTrue((output / 'failure.json').exists())
        self.assertFalse((output / 'compile.log').exists())

    def test_component_refuses_reusing_existing_evidence(self):
        code, output, _, _ = self.component()
        self.assertEqual(code, 0)
        before = (output / 'compile.log').read_bytes()
        module = self.module('component_existing_evidence', 'scripts/check-component-tools.py')
        with patch.object(module, 'ROOT', self.root), \
                patch.object(module, 'load_runtime', side_effect=AssertionError('Existing packet must stop before identity')):
            with self.assertRaises(FileExistsError):
                module.main(['--byond-bin', str(self.root), '--byond-archive', str(self.root / 'inert.zip'), '--output', str(output)])
        self.assertEqual((output / 'compile.log').read_bytes(), before)

    def test_component_runtime_diagnostics_or_missing_report_fail(self):
        for kwargs in ({'runtime_log': 'runtime error: controlled'}, {'marker': False}):
            with self.subTest(kwargs=kwargs), tempfile.TemporaryDirectory() as temp:
                self.root = Path(temp); self.events = []
                code, output, _, _ = self.component(**kwargs)
                self.assertEqual(code, 1)
                self.assertTrue((output / 'runtime/runtime.log').exists())

    def train_case(self, *, reject=None, build=None, log='RESULT failures=0\n', load_error=None):
        driver = self.train(); runtime = self.runtime(reject)
        work = self.root / 'train'; work.mkdir()
        for name in ('production.dm', 'fixture.dm', 'probe.dme'):
            (work / name).write_text('offline generated source')
        calls = []
        def native(command, **kwargs):
            role = 'compiler' if Path(command[0]).name == 'DreamMaker' else 'daemon'
            calls.append(command)
            self.assertEqual(self.events[-1], role)
            self.assertEqual(kwargs['timeout'], 60 if role == 'compiler' else 15)
            if role == 'compiler':
                if isinstance(build, BaseException): raise build
                text = 'DM compiler version ' + runtime.identity['version'] + '\nprobe.dmb - 0 errors, 0 warnings\n'
                return subprocess.CompletedProcess(command, 0, build or text, '')
            self.assertIs(kwargs['preexec_fn'], driver['daemon_limits'])
            kwargs['stdout'].write(log)
            return subprocess.CompletedProcess(command, 0)
        with patch.dict(driver, {'load_runtime': Mock(return_value=runtime, side_effect=load_error)}), \
                patch.object(subprocess, 'run', side_effect=native):
            code = driver['execute'](ROOT, work, self.root, self.root / 'inert.zip')
        return code, work, runtime, calls

    def test_train_exact_compiler_then_daemon_identity_and_limits(self):
        code, work, runtime, calls = self.train_case()
        self.assertEqual(code, 0)
        self.assertEqual(self.events, ['compiler', 'daemon'])
        self.assertEqual(len(calls), 2)
        self.assertEqual(json.loads((work / 'fixture-status.json').read_text())['status'], 'passed')
        self.assertEqual([c[0] for c in runtime.before_launch.call_args_list], [('compiler', work), ('daemon', work)])
        limits = ast.parse((ROOT / 'tests/train_collision/run.sh').read_text().split("<<'PY'\n", 1)[1].rsplit('\nPY', 1)[0])
        self.assertIn('256 * 1024 ** 2', ast.unparse(limits))
        self.assertIn('resource.RLIMIT_CPU, (5, 5)', ast.unparse(limits))

    def test_train_bad_archive_retains_failure_without_native_launch(self):
        with self.assertRaisesRegex(ValueError, 'archive mismatch'):
            self.train_case(load_error=ValueError('archive mismatch'))
        self.assertEqual(self.events, [])
        self.assertEqual(json.loads((self.root / 'train/fixture-status.json').read_text())['status'], 'failed')

    def test_train_recheck_and_unclean_compile_prevent_daemon(self):
        for options in ({'reject': 'compiler'}, {'reject': 'daemon'},
                        {'build': 'DM compiler version 516.1681\nprobe.dmb - 0 errors, 0 warnings\n'}):
            with self.subTest(options=options), tempfile.TemporaryDirectory() as temp:
                self.root = Path(temp); self.events = []
                with self.assertRaises((ValueError, RuntimeError)): self.train_case(**options)
                self.assertTrue((self.root / 'train/fixture-status.json').exists())

    def test_train_bad_results_and_timeouts_remain_failures(self):
        for options in ({'log': 'FAIL guard\nRESULT failures=0\n'}, {'log': ''},
                        {'build': subprocess.TimeoutExpired('offline', 60, output=b'partial train compile')}):
            with self.subTest(options=options), tempfile.TemporaryDirectory() as temp:
                self.root = Path(temp); self.events = []
                with self.assertRaises((RuntimeError, subprocess.TimeoutExpired)): self.train_case(**options)
                self.assertEqual(json.loads((self.root / 'train/fixture-status.json').read_text())['status'], 'failed')

    def test_workflows_remain_manual_only_with_canonical_identity_and_retention(self):
        for name in ('train-collision', 'component-tools'):
            source = (ROOT / ('.github/workflows/' + name + '.yml')).read_text()
            self.assertIn('workflow_dispatch:', source)
            for denied in ('pull_request:', 'push:', 'workflow_call:', 'BYOND_MINOR:', 'legacy-fixture'):
                self.assertNotIn(denied, source)
            self.assertIn('BYOND_ARCHIVE_SOURCE: repository-release', source)
            self.assertIn('run: bash scripts/travis_pre_byond.sh', source)
            self.assertIn('if: always()', source)
            self.assertIn('${{ github.run_attempt }}', source)
            self.assertIn('if-no-files-found: error', source)
            self.assertIn('timeout-minutes: 10', source)
            self.assertIn('BYOND/pinned.zip', source)
        component = (ROOT / '.github/workflows/component-tools.yml').read_text()
        self.assertEqual(component.count('/usr/bin/python3 scripts/check-component-tools.py'), 3)
        self.assertIn('--negative-control consumption', component)
        self.assertIn('--negative-control runtime-save', component)

    def test_secondary_retention_failure_preserves_initial_identity_error(self):
        original = Path.write_text
        def retain(path, *args, **kwargs):
            if path.name in ('failure.json', 'fixture-status.json'):
                raise OSError('controlled retention failure')
            return original(path, *args, **kwargs)
        for profile in ('component', 'train'):
            with self.subTest(profile=profile), tempfile.TemporaryDirectory() as temp:
                self.root = Path(temp); self.events = []
                with patch.object(Path, 'write_text', retain), self.assertRaisesRegex(ValueError, 'Archive identity mismatch'):
                    if profile == 'component': self.component(load_error=ValueError('Archive identity mismatch'))
                    else: self.train_case(load_error=ValueError('Archive identity mismatch'))
                self.assertEqual(self.events, [])


if __name__ == '__main__':
    unittest.main()
