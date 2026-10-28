"""Offline profile/runner controls. Native processes and network are forbidden.

Runner-flow cases inject Popen and identity; their synthetic PASS is NOT a DM pass.
The unchanged test_byond_runtime.py separately exercises passive archive matching.
"""
from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import io
import json
from pathlib import Path
import shutil
import shlex
import sys
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import round_metadata_engine as engine

spec = importlib.util.spec_from_file_location('round_metadata_runner', HERE / 'run-round-metadata.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
EXPECTED = {None: 'PASS', 'restore': 'FAIL: round-mode flag lost: persistence',
            'preflight': 'FAIL: invalid round extension passed preflight: partial',
            'integrity': 'FAIL: modern metadata tamper passed preflight'}


class EngineSelectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = Path(self.enterContext(tempfile.TemporaryDirectory(prefix='round-engine-offline-')))
        self.bin = self.temp / 'bin'
        self.bin.mkdir()
        for name in ('DreamMaker', 'DreamDaemon'):
            (self.bin / name).write_text('INERT OFFLINE TEST DATA - NEVER EXECUTE\n')
        for target in ('subprocess.Popen', 'subprocess.run', 'subprocess.check_output',
                       'subprocess.call', 'subprocess.check_call', 'os.system',
                       'socket.socket', 'urllib.request.urlopen', 'urllib.request.OpenerDirector.open'):
            self.enterContext(patch(target, side_effect=AssertionError('native/network forbidden')))
        self.calls = []

    def profile(self):
        return engine.EngineProfile(engine.CURRENT, self.temp / 'archive.zip', self.temp / 'acquisition.json')

    def flow(self, selected=None, banner='516.1681', control=None, identity_error_at=None,
             build_suffix='', result=None, bin_path=None):
        output = self.temp / ('evidence-' + str(len(list(self.temp.glob('evidence-*')))))
        output.mkdir()
        argv = ['--byond-bin', str(bin_path or self.bin)]
        if control:
            argv += ['--negative-control', control]
        if selected:
            argv += ['--expected-byond-version', selected]
        if selected == engine.CURRENT:
            argv += ['--byond-archive', str(self.temp / 'archive.zip'),
                     '--acquisition-receipt', str(self.temp / 'acquisition.json')]
        identity_calls = []

        def identity(binary):
            identity_calls.append(binary)
            if len(identity_calls) == identity_error_at:
                raise ValueError('injected exact identity rejection')
            return {'injected_offline_test': True, 'installed': {'version': engine.CURRENT}}

        def fake_popen(command, **kwargs):
            self.calls.append(command)
            self.assertEqual(kwargs['cwd'], output)
            if Path(command[0]).name == 'DreamMaker':
                kwargs['stdout'].write('DM compiler version ' + banner + '\nroundtrip.dmb - 0 errors, 0 warnings\n' + build_suffix)
            else:
                (output / 'runtime.log').write_text('Injected offline daemon log\n')
                (output / 'result.txt').write_text(result if result is not None else EXPECTED[control])
            return type('InertProcess', (), {'pid': 123, 'wait': lambda self, **kw: 0,
                                            'poll': lambda self: 0})()

        self.last_output = output
        self.identity_calls = identity_calls
        with patch.object(runner.tempfile, 'mkdtemp', return_value=str(output)), \
             patch.object(runner.subprocess, 'Popen', side_effect=fake_popen), \
             patch.object(engine.EngineProfile, 'identity', side_effect=identity), \
             redirect_stdout(io.StringIO()):
            runner.main(argv)
        return json.loads((output / 'summary.json').read_text())

    def test_omitted_profile_keeps_1681_default_and_all_control_choices(self):
        for control in EXPECTED:
            argv = ['--byond-bin', str(self.bin)]
            if control:
                argv += ['--negative-control', control]
            args = runner.parse_args(argv)
            self.assertEqual(args.expected_byond_version, engine.LEGACY)
            self.assertEqual(args.negative_control, control)

    def test_unknown_cli_versions_reject_before_any_process(self):
        for version in ('516', '516.16810', '516.1688x', '517.1688', 'auto', ''):
            with self.subTest(version=version), redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                runner.parse_args(['--byond-bin', str(self.bin), '--expected-byond-version', version])

    def test_profile_rejects_unknown_version_without_loading_helpers(self):
        with patch.object(engine, 'load_runtime', side_effect=AssertionError('must not load')):
            with self.assertRaisesRegex(ValueError, 'Unsupported'):
                engine.EngineProfile('516.1689')

    def test_legacy_never_claims_archive_identity_or_loads_current_helpers(self):
        with patch.object(engine, 'load_runtime', side_effect=AssertionError('must not load')):
            legacy = engine.EngineProfile(engine.LEGACY)
            self.assertIsNone(legacy.runtime)
            with self.assertRaisesRegex(ValueError, 'does not establish'):
                legacy.identity(self.bin)

    def test_legacy_refuses_unvalidated_provenance_arguments(self):
        for archive, receipt in ((self.temp, None), (None, self.temp), (self.temp, self.temp)):
            with self.subTest(archive=archive, receipt=receipt), self.assertRaisesRegex(ValueError, 'explicit'):
                engine.EngineProfile(engine.LEGACY, archive, receipt)

    def test_current_requires_both_provenance_arguments(self):
        for archive, receipt in ((None, None), (self.temp, None), (None, self.temp)):
            with self.subTest(archive=archive, receipt=receipt), self.assertRaisesRegex(ValueError, 'requires'):
                engine.EngineProfile(engine.CURRENT, archive, receipt)

    def test_current_refuses_non_linux_before_loading_helpers(self):
        with patch.object(engine.sys, 'platform', 'win32'), \
             patch.object(engine, 'load_runtime', side_effect=AssertionError('must not load')):
            with self.assertRaisesRegex(ValueError, 'Linux only'):
                self.profile()

    def test_current_reuses_exact_reviewed_helpers(self):
        profile = self.profile()
        self.assertEqual(profile.runtime.pin.load()['version'], engine.CURRENT)
        self.assertEqual(profile.runtime.MEMBERS, ('DreamMaker', 'DreamDaemon', 'libbyond.so', 'libext.so'))

    def test_each_helper_or_manifest_drift_rejects(self):
        root = self.temp / 'drift'
        for relative in engine.PINS:
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(engine.ROOT / relative, target)
        for relative in engine.PINS:
            target = root / relative
            original = target.read_bytes()
            target.write_bytes(original + b'\n')
            with self.subTest(path=relative), patch.object(engine, 'ROOT', root), self.assertRaisesRegex(ValueError, 'dependency changed'):
                engine.load_runtime()
            target.write_bytes(original)

    def test_current_requires_one_exact_clean_compiler_banner(self):
        profile = self.profile()
        clean = 'DM compiler version 516.1688\nroundtrip.dmb - 0 errors, 0 warnings\n'
        profile.check_compile(clean)
        for invalid in (clean.replace('1688', '1681'), clean.replace('1688', '16880'),
                        clean.replace('1688', '1688x'), clean.replace('DM compiler', 'prefix DM compiler'),
                        clean + 'DM compiler version 516.1688\n', clean + 'DM compiler version 516.1681\n',
                        clean.replace('0 warnings', '1 warnings'), clean.replace('0 errors', '1 errors')):
            with self.subTest(log=invalid), self.assertRaisesRegex(ValueError, 'banner/result'):
                profile.check_compile(invalid)

    def test_current_checks_acquisition_before_installed_members(self):
        profile = self.profile()
        with patch.object(profile.runtime.pin, 'read_download_receipt', side_effect=ValueError('bad acquisition')), \
             patch.object(profile.runtime, 'verify_linux', side_effect=AssertionError('must not inspect install')):
            with self.assertRaisesRegex(ValueError, 'bad acquisition'):
                profile.identity(self.bin)

    def test_current_keeps_exact_acquisition_and_install_receipts(self):
        profile = self.profile()
        acquisition = {'origin': 'injected offline record, not real download provenance'}
        installed = {'version': engine.CURRENT, 'members': 'injected offline data'}
        with patch.object(profile.runtime.pin, 'read_download_receipt', return_value=acquisition) as receipt, \
             patch.object(profile.runtime, 'verify_linux', return_value=installed) as verify:
            actual = profile.identity(self.bin)
        self.assertIs(actual['acquisition'], acquisition)
        self.assertIs(actual['installed'], installed)
        self.assertEqual(receipt.call_args.args[2], 'linux')
        verify.assert_called_once_with(self.bin, profile.archive)

    def test_real_acquisition_validation_rejects_wrong_hash_url_version_and_origin(self):
        profile = self.profile()
        pin = profile.runtime.pin
        requirement = pin.load()
        archive = requirement['linux']
        receipt = dict(version=engine.CURRENT, platform='linux', url=archive['url'],
                       sha256=archive['sha256'], bytes=archive['bytes'],
                       integritySource=requirement['integritySource'], source='official',
                       requested_source='official', upstream_source='official',
                       upstream_url=archive['url'], cache_key=pin.cache_key(requirement, 'linux'),
                       cache_status='disabled')
        profile.acquisition.write_text(json.dumps(receipt))
        with patch.object(profile.runtime, 'verify_linux', return_value={'version': engine.CURRENT}) as verify:
            self.assertEqual(profile.identity(self.bin)['acquisition'], receipt)
            self.assertEqual(verify.call_count, 1)
            for key, wrong in (('sha256', '0' * 64), ('bytes', archive['bytes'] + 1),
                               ('version', engine.LEGACY), ('platform', 'windows'),
                               ('upstream_url', archive['url'] + '?token=not-used'),
                               ('source', 'cache'), ('cache_key', 'different')):
                profile.acquisition.write_text(json.dumps(dict(receipt, **{key: wrong})))
                with self.subTest(field=key), self.assertRaises(ValueError):
                    profile.identity(self.bin)
            self.assertEqual(verify.call_count, 1, 'invalid acquisition must reject before inspecting install')
            profile.acquisition.write_text(json.dumps(receipt)[:-1] + ', "version": "516.1688"}')
            with self.assertRaisesRegex(ValueError, 'Duplicate'):
                profile.identity(self.bin)

    def test_current_rejects_wrong_installed_version(self):
        profile = self.profile()
        with patch.object(profile.runtime.pin, 'read_download_receipt', return_value={}), \
             patch.object(profile.runtime, 'verify_linux', return_value={'version': engine.LEGACY}):
            with self.assertRaisesRegex(ValueError, 'identity mismatch'):
                profile.identity(self.bin)

    def test_current_rechecks_manifest_version_before_identity(self):
        profile = self.profile()
        with patch.object(profile.runtime.pin, 'load', return_value={'version': engine.LEGACY}):
            with self.assertRaisesRegex(ValueError, 'profile changed'):
                profile.identity(self.bin)

    def test_default_runner_preserves_positive_and_three_exact_controls(self):
        for control, expected in EXPECTED.items():
            with self.subTest(control=control):
                result = self.flow(control=control)
                self.assertEqual(result['expected_byond_version'], engine.LEGACY)
                self.assertEqual(result['result'], expected)
                self.assertEqual(self.identity_calls, [])
                self.assertNotIn('engine_identity', result['processes'][0])

    def test_explicit_current_keeps_controls_and_verifies_before_both_processes(self):
        for control, expected in EXPECTED.items():
            with self.subTest(control=control):
                result = self.flow(selected=engine.CURRENT, banner=engine.CURRENT, control=control)
                self.assertEqual(result['expected_byond_version'], engine.CURRENT)
                self.assertEqual(result['result'], expected)
                self.assertEqual(self.identity_calls, [self.bin, self.bin])
                for role in ('compile', 'daemon'):
                    self.assertTrue(json.loads((self.last_output / (role + '-engine.json')).read_text())['injected_offline_test'])

    def test_default_still_rejects_1688_without_running_daemon(self):
        with self.assertRaisesRegex(RuntimeError, 'Pinned clean'):
            self.flow(banner=engine.CURRENT)
        self.assertEqual(len(self.calls), 1)
        self.assertFalse((self.last_output / 'summary.json').exists())

    def test_explicit_current_rejects_1681_before_daemon(self):
        with self.assertRaisesRegex(ValueError, 'banner/result'):
            self.flow(selected=engine.CURRENT, banner=engine.LEGACY)
        self.assertEqual(len(self.calls), 1)

    def test_compile_identity_failure_preserves_cleanup_and_launches_nothing(self):
        with self.assertRaisesRegex(ValueError, 'identity rejection'):
            self.flow(selected=engine.CURRENT, banner=engine.CURRENT, identity_error_at=1)
        self.assertEqual(self.calls, [])
        row, = json.loads((self.last_output / 'cleanup.json').read_text())
        self.assertEqual((row['role'], row['pid'], row['exit']), ('compile', None, None))
        self.assertFalse((self.last_output / 'summary.json').exists())

    def test_daemon_identity_failure_preserves_successful_compile_identity(self):
        with self.assertRaisesRegex(ValueError, 'identity rejection'):
            self.flow(selected=engine.CURRENT, banner=engine.CURRENT, identity_error_at=2)
        self.assertEqual(len(self.calls), 1)
        rows = json.loads((self.last_output / 'cleanup.json').read_text())
        self.assertEqual((rows[1]['role'], rows[1]['pid'], rows[1]['exit']), ('daemon', None, None))
        self.assertTrue((self.last_output / 'compile-engine.json').exists())
        self.assertFalse((self.last_output / 'summary.json').exists())

    def test_current_does_not_resolve_away_bin_symlink_before_identity(self):
        linked = self.temp / 'linked-bin'
        linked.symlink_to(self.bin, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'identity rejection'):
            self.flow(selected=engine.CURRENT, banner=engine.CURRENT, identity_error_at=1, bin_path=linked)
        self.assertEqual(self.identity_calls, [linked])
        self.assertEqual(self.calls, [])

    def test_diagnostic_and_unexpected_assertion_remain_failures(self):
        with self.assertRaisesRegex(RuntimeError, 'Invalid compile evidence'):
            self.flow(selected=engine.CURRENT, banner=engine.CURRENT, build_suffix='runtime error: offline control\n')
        with self.assertRaisesRegex(RuntimeError, 'Unexpected round metadata result'):
            self.flow(selected=engine.CURRENT, banner=engine.CURRENT, control='restore', result='PASS')

    def check_hosted_commands(self, source):
        commands = [line.strip() for line in source.splitlines()
                    if 'python3 tests/world_save/run-round-metadata.py' in line]
        self.assertEqual(len(commands), 4)
        controls = []
        for command in commands:
            argv = shlex.split(command)
            self.assertEqual(argv[:2], ['python3', 'tests/world_save/run-round-metadata.py'])
            args = runner.parse_args(argv[2:])
            self.assertEqual(args.expected_byond_version, engine.CURRENT)
            self.assertEqual(str(args.byond_bin), '$PWD/BYOND/byond/bin')
            self.assertEqual(str(args.byond_archive), '$PWD/BYOND/pinned.zip')
            self.assertEqual(str(args.acquisition_receipt), '$PWD/.ci/compile/byond-download.json')
            controls.append(args.negative_control)
        self.assertEqual(controls, [None, 'restore', 'preflight', 'integrity'])

    def test_hosted_commands_explicitly_select_current_engine_and_existing_provenance(self):
        source = (engine.ROOT / '.github/workflows/test.yml').read_text()
        self.check_hosted_commands(source)
        bootstrap = (engine.ROOT / 'scripts/travis_pre_byond.sh').read_text()
        self.assertIn('cd BYOND', bootstrap)
        self.assertIn('archive_args=(--platform linux --output pinned.zip', bootstrap)
        self.assertIn('> "$repo_root/.ci/compile/byond-download.json"', bootstrap)

    def test_hosted_command_omission_wrong_version_path_and_control_mutations_reject(self):
        source = (engine.ROOT / '.github/workflows/test.yml').read_text()
        for before, after in (
                (' --expected-byond-version 516.1688', ''),
                (' --expected-byond-version 516.1688', ' --expected-byond-version 516.1681'),
                (' --byond-archive "$PWD/BYOND/pinned.zip"', ''),
                (' --acquisition-receipt "$PWD/.ci/compile/byond-download.json"', ''),
                ('--byond-archive "$PWD/BYOND/pinned.zip"', '--byond-archive "$PWD/BYOND/unreviewed.zip"'),
                ('--acquisition-receipt "$PWD/.ci/compile/byond-download.json"', '--acquisition-receipt "$PWD/other.json"'),
                (' --negative-control integrity', ' --negative-control restore')):
            self.assertIn(before, source)
            with self.subTest(mutation=before), self.assertRaises(AssertionError):
                self.check_hosted_commands(source.replace(before, after))

    def test_added_roundtrip_files_keep_existing_native_suite_classification(self):
        spec = importlib.util.spec_from_file_location('round_metadata_selection', engine.ROOT / 'scripts/select-ci.py')
        selection = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(selection)
        paths = ('tests/world_save/roundtrip_compat.dm', 'tests/world_save/test_roundtrip_compat.py',
                 'tests/world_save/round_metadata_engine.py', 'tests/world_save/test_round_metadata_engine.py')
        for added in ((path,) for path in paths):
            with self.subTest(added=added), patch.object(selection.subprocess, 'check_output',
                    return_value=('\0'.join(added) + '\0').encode()):
                self.assertEqual(selection.introduced_tests('base', 'head', 'pull_request'), ['tests/world_save'])
        self.assertEqual(selection.SOURCE_PREPARATION_ONLY_TESTS, frozenset({
            'tests/world_save/character_return/fixture.dm',
            'tests/world_save/character_return/prepare.py',
            'tests/world_save/character_return/test_prepare.py'}))


if __name__ == '__main__':
    unittest.main()
