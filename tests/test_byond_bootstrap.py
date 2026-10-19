"""Offline bootstrap command contract: stub sudo, never run apt or BYOND."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/travis_pre_byond.sh'

class ByondBootstrapTests(unittest.TestCase):
    def run_package_prefix(self, fail_update=False):
        source = SCRIPT.read_text()
        marker = 'echo "Setting up BYOND."'
        self.assertEqual(source.count(marker), 1)
        prefix = source.split(marker)[0]
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
            result = subprocess.run(['/bin/bash', '-c', prefix], cwd=root,
                                    env={'PATH': str(root), 'COMMAND_LOG': str(log),
                                         'FAIL_UPDATE': '1' if fail_update else '0'},
                                    capture_output=True, text=True, timeout=5)
            return result, log.read_text().splitlines()

    def test_only_existing_packages_are_installed_noninteractively(self):
        result, commands = self.run_package_prefix()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, [
            'dpkg --add-architecture i386',
            'env DEBIAN_FRONTEND=noninteractive apt-get update',
            'env DEBIAN_FRONTEND=noninteractive apt-get install -y python3 wget git unzip make sudo',
            'env DEBIAN_FRONTEND=noninteractive apt-get install -y libstdc++6:i386 libgcc1:i386 libc6-i386 libcurl4:i386 lib32z1 libncurses6 libncurses6:i386',
        ])
        self.assertFalse(any('upgrade' in command for command in commands))

    def test_package_failure_stops_before_install_or_native_setup(self):
        result, commands = self.run_package_prefix(fail_update=True)
        self.assertEqual(result.returncode, 19)
        self.assertEqual(len(commands), 2)
        self.assertNotIn('Setting up BYOND.', result.stdout)

    def test_shell_syntax_and_pinned_compiler_contract(self):
        subprocess.run(['/bin/bash', '-n', str(SCRIPT)], check=True, timeout=5)
        source = SCRIPT.read_text()
        self.assertIn('https://civ13.com/downloads/516.1681_byond_linux.zip', source)
        self.assertIn('DreamMaker -max_errors 0 civ13.dme | tee result.log', source)
        self.assertIn("grep '\\- 0 errors, 0 warnings' result.log", source)

if __name__ == '__main__':
    unittest.main()
