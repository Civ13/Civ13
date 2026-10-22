"""Offline bootstrap command contract: stub sudo, never run apt or BYOND."""
import os
import shlex
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

    def test_download_is_bounded_without_source_or_tls_changes(self):
        commands = [shlex.split(line) for line in SCRIPT.read_text().splitlines()
                    if line.startswith('wget ')]
        self.assertEqual(commands, [[
            'wget', '--timeout=60', '--tries=3', '--waitretry=5',
            '-O', '516.1681_byond_linux.zip',
            'https://civ13.com/downloads/516.1681_byond_linux.zip',
        ]])

    def test_shell_syntax_and_pinned_compiler_contract(self):
        subprocess.run(['/bin/bash', '-n', str(SCRIPT)], check=True, timeout=5)
        source = SCRIPT.read_text()
        self.assertIn('https://civ13.com/downloads/516.1681_byond_linux.zip', source)
        self.assertIn('DreamMaker -max_errors 0 civ13.dme | tee result.log', source)
        self.assertIn("grep '\\- 0 errors, 0 warnings' result.log", source)



class OfficialMallBootstrapTests(unittest.TestCase):
    """Only shell fragments and builtin/stub commands, never the bootstrap."""
    def run_download(self, *, transport=0, http='200', size='4884042', hash_exit=0, existing=False):
        source = SCRIPT.read_text()
        block = source.split('# BEGIN FIXED OFFICIAL MALL DOWNLOAD\n', 1)[1].split('# END FIXED OFFICIAL MALL DOWNLOAD', 1)[0]
        with tempfile.TemporaryDirectory(prefix='byond-official-stubs-') as temporary:
            root = Path(temporary)
            archive = root / '516.1681_byond_linux.zip'
            if existing:
                archive.write_text('owned by someone else')
            stubs = r"""
curl() {
  printf '%s\n' "$@" > curl-arguments.txt
  printf 'offline transport fixture; not an actual BYOND archive' > 516.1681_byond_linux.zip
  printf '%s' "$HTTP_STATUS"
  return "$TRANSPORT_EXIT"
}
wc() { printf '%s\n' "$STUB_BYTES"; }
sha256sum() {
  printf '%s\n' "$@" > hash-arguments.txt
  IFS= read -r identity
  printf '%s\n' "$identity" > hash-input.txt
  return "$HASH_EXIT"
}
"""
            result = subprocess.run(['/bin/bash', '-c', 'set -e\n' + stubs + block + '\ndownload_official_pinned_mall\nprintf verified > verification-gate.txt\n'],
                                    cwd=root, env={'PATH': str(root), 'TRANSPORT_EXIT': str(transport),
                                                  'HTTP_STATUS': http, 'STUB_BYTES': size, 'HASH_EXIT': str(hash_exit)},
                                    capture_output=True, text=True, timeout=5)
            files = {path.name: path.read_text() for path in root.iterdir() if path.is_file()}
            return result, files

    def test_fixed_transport_arguments_and_identity_gate(self):
        result, files = self.run_download()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(files['verification-gate.txt'], 'verified')
        self.assertEqual(files['curl-arguments.txt'].splitlines(), [
            '--disable', '--proxy', '', '--noproxy', '*', '--proto', '=https',
            '--tlsv1.2', '--fail', '--silent', '--show-error', '--request', 'GET',
            '--connect-timeout', '10', '--max-time', '60', '--max-filesize', '8388608',
            '--retry', '0', '--max-redirs', '0', '--output', '516.1681_byond_linux.zip',
            '--write-out', '%{http_code}', 'https://www.byond.com/download/build/516/516.1681_byond_linux.zip'])
        self.assertEqual(files['hash-arguments.txt'].splitlines(), ['--check', '--status'])
        self.assertEqual(files['hash-input.txt'], '614c126b9d0073c67558172c2c2fcb92c31298cf36092208ed55a416326bede3  516.1681_byond_linux.zip\n')
        self.assertIn('Verified observed official-origin', result.stdout)

    def test_transport_tls_timeout_and_limit_failures_never_reach_hash_or_gate(self):
        for code in (22, 28, 60, 63):
            with self.subTest(curl_exit=code):
                result, files = self.run_download(transport=code)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('hash-input.txt', files)
                self.assertNotIn('verification-gate.txt', files)

    def test_redirect_and_non200_status_never_reach_hash_or_gate(self):
        for status in ('301', '302', '403', '206', '200extra'):
            with self.subTest(http=status):
                result, files = self.run_download(http=status)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('hash-input.txt', files)
                self.assertNotIn('verification-gate.txt', files)

    def test_truncated_oversize_and_malformed_lengths_never_reach_hash_or_gate(self):
        for size in ('4884041', '4884043', '8388609', 'unknown', '-1'):
            with self.subTest(size=size):
                result, files = self.run_download(size=size)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('hash-input.txt', files)
                self.assertNotIn('verification-gate.txt', files)

    def test_digest_failure_never_reaches_gate(self):
        result, files = self.run_download(hash_exit=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('hash-input.txt', files)
        self.assertNotIn('verification-gate.txt', files)

    def test_existing_output_is_not_overwritten(self):
        result, files = self.run_download(existing=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(files['516.1681_byond_linux.zip'], 'owned by someone else')
        self.assertNotIn('curl-arguments.txt', files)
        self.assertNotIn('verification-gate.txt', files)

    def test_missing_curl_and_unknown_arguments_stop_before_package_effects(self):
        prefix = SCRIPT.read_text().split('echo "Setting up the system for BYOND compilation."')[0]
        with tempfile.TemporaryDirectory(prefix='byond-mode-stubs-') as temporary:
            for args, expected in ((['--official-pinned-mall'], 69), (['--other'], 64),
                                   (['--official-pinned-mall', '--other'], 64), ([], 0)):
                with self.subTest(args=args):
                    result = subprocess.run(['/bin/bash', '-c', prefix, '--', *args], cwd=temporary,
                                            env={'PATH': temporary}, capture_output=True, text=True, timeout=5)
                    self.assertEqual(result.returncode, expected, result.stderr)
            self.assertEqual(list(Path(temporary).iterdir()), [])

    def test_official_verification_precedes_unpack_make_and_binary_execution(self):
        source = SCRIPT.read_text()
        self.assertLess(source.index('command -v curl'), source.index('sudo dpkg'))
        call = source.index('\n  download_official_pinned_mall\n')
        self.assertLess(call, source.index('\nunzip -o'))
        self.assertLess(call, source.index('\nmake here'))
        self.assertLess(call, source.index('\nDreamMaker '))
        self.assertIn('not a publisher-signed checksum', source)

    def test_official_selection_is_exactly_the_twelve_flag_mall_only_timeout_predicate(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        timeout = next(line.strip() for line in workflow.splitlines() if line.startswith('    timeout-minutes: ${{'))
        predicate = timeout.split('${{ ', 1)[1].rsplit(' && 45 || 360 }}', 1)[0]
        selected = next(line.strip() for line in workflow.splitlines() if line.strip().startswith('OFFICIAL_PINNED_MALL:'))
        self.assertEqual(selected, 'OFFICIAL_PINNED_MALL: ${{ ' + predicate + ' }}')
        self.assertEqual(predicate.count('inputs.'), 12)
        self.assertIn('true) sudo bash ./scripts/travis_pre_byond.sh --official-pinned-mall ;;', workflow)
        self.assertIn('false) sudo bash ./scripts/travis_pre_byond.sh ;;', workflow)


if __name__ == '__main__':
    unittest.main()
