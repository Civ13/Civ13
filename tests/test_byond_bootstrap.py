"""Offline bootstrap command contract: stub sudo, never run apt or BYOND."""
import os
from pathlib import Path
import subprocess
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

    def run_package_prefix(self, fail_update=False):
        source = SCRIPT.read_text()
        marker = 'echo "Setting up BYOND."'
        self.assertEqual(source.count(marker), 1)
        prefix = 'set -eo pipefail\n' + source.split('# BEGIN package setup\n')[1].split('# END package setup')[0]
        with tempfile.TemporaryDirectory(prefix='byond-bootstrap-stubs-') as temporary:
            root = Path(temporary)
            # PATH contains only this stub. No sudo, env, apt, dpkg, network or
            # compiler command can execute outside it; printf is a shell builtin.
            stub = root / 'sudo'
            stub.write_text('''#!/bin/sh
printf '%s\\n' "$*" >> "$COMMAND_LOG"
case "$*" in
  *"apt-get update") [ "$FAIL_UPDATE" = 1 ] && exit 19 ;;
esac
exit 0
''')
            stub.chmod(0o700)
            log = root / 'commands.txt'
            result = subprocess.run([BASH, '--noprofile', '--norc', '-c', prefix], cwd=root,
                                    env={'PATH': shell_path(root), 'COMMAND_LOG': shell_path(log),
                                         'FAIL_UPDATE': '1' if fail_update else '0'},
                                    capture_output=True, text=True, timeout=5)
            return result, log.read_text().splitlines()

    def test_only_existing_packages_are_installed_noninteractively(self):
        result, commands = self.run_package_prefix()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, [
            'timeout -k 5 30 dpkg --add-architecture i386',
            'env DEBIAN_FRONTEND=noninteractive timeout -k 5 120 apt-get update',
            'env DEBIAN_FRONTEND=noninteractive timeout -k 5 180 apt-get install -y python3 wget git unzip make sudo libstdc++6:i386 libgcc-s1:i386 libc6-i386 libcurl4:i386 lib32z1 libncurses6 libncurses6:i386',
        ])
        self.assertFalse(any('upgrade' in command for command in commands))

    def test_package_failure_stops_before_install_or_native_setup(self):
        result, commands = self.run_package_prefix(fail_update=True)
        self.assertEqual(result.returncode, 19)
        self.assertEqual(len(commands), 2)
        self.assertNotIn('Setting up BYOND.', result.stdout)

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

if __name__ == '__main__':
    unittest.main()
