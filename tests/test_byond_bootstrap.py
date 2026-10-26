"""Offline bootstrap command contract: stub sudo, never run apt or BYOND."""
import os
import shlex
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/travis_pre_byond.sh'
BASH = r'C:\Program Files\Git\bin\bash.exe' if os.name == 'nt' else '/bin/bash'


def shell_path(path):
    text = str(path).replace('\\', '/')
    return '/' + text[0].lower() + text[2:] if os.name == 'nt' else text

class ByondBootstrapTests(unittest.TestCase):
    def test_unknown_option_exits_before_setup(self):
        result = subprocess.run([BASH, '--noprofile', '--norc', shell_path(SCRIPT), '--unreviewed-version'],
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

    def test_download_is_bounded_without_source_or_tls_changes(self):
        commands = [shlex.split(line.strip()) for line in SCRIPT.read_text().splitlines()
                    if line.strip().startswith('timeout -k 5 65 wget ')]
        self.assertEqual(commands, [[
            'timeout', '-k', '5', '65', 'wget', '--timeout=30', '--tries=1', '--no-verbose',
            '-O', 'pinned.zip',
            'https://civ13.com/downloads/516.1681_byond_linux.zip',
        ]])

    def test_shell_syntax_and_pinned_compiler_contract(self):
        subprocess.run([BASH, '-n', shell_path(SCRIPT)], check=True, timeout=5)
        source = SCRIPT.read_text()
        self.assertIn('https://civ13.com/downloads/516.1681_byond_linux.zip', source)
        self.assertIn('--legacy-fixture-5161681', source)
        self.assertIn('archive_args=(--platform linux --output pinned.zip --source "${BYOND_ARCHIVE_SOURCE:-official}")', source)
        self.assertIn('byond_toolchain.py" download "${archive_args[@]}"', source)
        self.assertIn('--cache-dir "$BYOND_ARCHIVE_CACHE"', source)
        self.assertIn('byond-download.json', source)
        self.assertIn('DM compiler version $byond_version', source)
        self.assertIn('timeout -k 5 300 DreamMaker -max_errors 0 civ13.dme 2>&1 | tee result.log', source)
        self.assertIn("grep -q -- '- 0 errors, 0 warnings' result.log", source)
        self.assertNotIn('/home/runner/work/', source)
        for contract in ('set -eo pipefail', '--timeout=30 --tries=1',
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


if __name__ == '__main__':
    unittest.main()
