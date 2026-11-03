"""Pure parsing/lock controls. Never runs provisioning, apt, sudo or a renderer."""
import importlib.util
import json
import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('renderer_setup', HERE / 'renderer_setup.py')
setup = importlib.util.module_from_spec(spec); spec.loader.exec_module(setup)

class RendererSetupTests(unittest.TestCase):
    def setUp(self):
        self.packages = {'ffmpeg': {'name': 'ffmpeg', 'version': '7:6.1.1-3ubuntu5',
            'filename': 'pool/universe/f/ffmpeg/ffmpeg_6.1.1-3ubuntu5_amd64.deb',
            'bytes': 1878920, 'sha256': '1a23baace5f2688a47e28119aedae6993cd638e6279a7227dfc52d9a337a1c17'}}
        self.enterContext(patch.object(setup.subprocess, 'run', side_effect=AssertionError('process execution forbidden')))
        self.enterContext(patch.object(setup.subprocess, 'Popen', side_effect=AssertionError('process execution forbidden')))
        self.enterContext(patch.object(setup.urllib.request, 'urlopen', side_effect=AssertionError('network forbidden')))
    def test_exact_new_package(self):
        self.assertEqual(setup.transaction('Inst ffmpeg (7:6.1.1-3ubuntu5 Ubuntu:24.04/noble [amd64])', self.packages), self.packages)
    def test_already_satisfied_is_empty(self):
        self.assertEqual(setup.transaction('0 upgraded, 0 newly installed', self.packages), {})
    def test_upgrade_downgrade_rejected(self):
        for version in ['1', '9']:
            with self.assertRaisesRegex(RuntimeError, 'Upgrade'):
                setup.transaction('Inst ffmpeg [' + version + '] (7:6.1.1-3ubuntu5 Ubuntu [amd64])', self.packages)
    def test_removal_rejected(self):
        for action in ('Remv', 'Purg'):
            with self.assertRaisesRegex(RuntimeError, 'removal'):
                setup.transaction(action + ' libc6 [1]', self.packages)
    def test_unlisted_package_and_version_rejected(self):
        for line in ('Inst evil (1 Ubuntu [amd64])', 'Inst ffmpeg (1 Ubuntu [amd64])'):
            with self.assertRaisesRegex(RuntimeError, 'Unlisted'):
                setup.transaction(line, self.packages)
    def test_preexisting_configuration_rejected(self):
        with self.assertRaisesRegex(RuntimeError, 'Pre-existing'):
            setup.transaction('Conf libc6 (2.39 Ubuntu [amd64])', self.packages)
    def test_percent_encoded_upstream_path(self):
        self.packages['ffmpeg']['filename'] = 'pool/f/ffmpeg_1+build1.deb'
        text = self.uri(url=setup.BASE + 'pool/f/ffmpeg_1%2bbuild1.deb')
        self.assertEqual(len(setup.download_plan(text, self.packages)), 1)
    def test_duplicate_rejected(self):
        line = 'Inst ffmpeg (7:6.1.1-3ubuntu5 Ubuntu [amd64])'
        with self.assertRaisesRegex(RuntimeError, 'Duplicate'):
            setup.transaction(line + '\n' + line, self.packages)
    def uri(self, url=None, target='ffmpeg_7%3a6.1.1-3ubuntu5_amd64.deb', size='1878920'):
        return "'" + (url or setup.BASE + self.packages['ffmpeg']['filename']) + "' " + target + ' ' + size + ' MD5Sum:ignored'
    def test_download_allowlist(self):
        result = setup.download_plan(self.uri(), self.packages)
        self.assertEqual(result[0][2], self.packages['ffmpeg'])
    def test_missing_extra_uri_rejected(self):
        for text in ('', self.uri() + '\n' + self.uri(), self.uri(url='https://example.com/package.deb')):
            with self.assertRaises(RuntimeError): setup.download_plan(text, self.packages)
    def test_unsafe_filename_and_size_rejected(self):
        for text in (self.uri(target='../x.deb'), self.uri(size='1')):
            with self.assertRaises(RuntimeError): setup.download_plan(text, self.packages)
    def test_real_lock_is_bounded_and_unique(self):
        lock = json.loads((HERE / 'renderer-lock.json').read_text())
        self.assertEqual(lock['snapshot'], setup.SNAPSHOT)
        self.assertEqual(len(lock['packages']), 233)
        self.assertEqual(len({p['name'] for p in lock['packages']}), 233)
        self.assertEqual(sum(p['bytes'] for p in lock['packages']), 145446530)
        for p in lock['packages']:
            self.assertRegex(p['sha256'], r'^[a-f0-9]{64}$')
            self.assertTrue(p['filename'].startswith('pool/'))
            self.assertNotIn('..', Path(p['filename']).parts)

    def test_privileged_wrapper_is_waited_not_killed(self):
        proc = Mock(); proc.poll.return_value = None
        setup.finish_command(proc, True, 20, now=lambda: 12)
        proc.wait.assert_called_once_with(timeout=8)
        proc.kill.assert_not_called()

    def test_privileged_completion_uncertainty_propagates_without_false_cleanup(self):
        proc = Mock(); proc.poll.return_value = None
        proc.wait.side_effect = subprocess.TimeoutExpired('root timeout', 8)
        with self.assertRaises(subprocess.TimeoutExpired):
            setup.finish_command(proc, True, 20, now=lambda: 12)
        proc.kill.assert_not_called()

    def test_unprivileged_running_wrapper_is_killed_and_reaped(self):
        proc = Mock(); proc.poll.return_value = None
        setup.finish_command(proc, False, 20, now=lambda: 12)
        proc.kill.assert_called_once(); proc.wait.assert_called_once_with(timeout=2)

    def test_already_exited_wrapper_requires_no_signal(self):
        proc = Mock(); proc.poll.return_value = 0
        setup.finish_command(proc, True, 20, now=lambda: 12)
        proc.kill.assert_not_called(); proc.wait.assert_not_called()

    def test_package_state_distinguishes_architectures_and_rejects_duplicates(self):
        state = setup.package_state('libc6:amd64\tamd64\t1\tii \nlibc6:i386\ti386\t2\tii \n')
        self.assertEqual(state, {('libc6','amd64'):('1','ii '),('libc6','i386'):('2','ii ')})
        with self.assertRaises(RuntimeError):
            setup.package_state('ffmpeg\tamd64\t1\tii \nffmpeg:amd64\tamd64\t1\tii \n')

    def test_exact_post_install_delta_passes(self):
        before = {('base','amd64'):('1','ii ')}
        after = before | {('ffmpeg','amd64'):('7:6.1.1-3ubuntu5','ii ')}
        setup.verify_package_delta(before, after, self.packages)
        setup.verify_package_delta(before, before, {})

    def test_post_install_rejects_wrong_missing_or_unconfigured_package(self):
        before = {('base','amd64'):('1','ii ')}
        for extra in ({}, {('ffmpeg','amd64'):('wrong','ii ')},
                      {('ffmpeg','amd64'):('7:6.1.1-3ubuntu5','iU ')}):
            with self.assertRaises(RuntimeError):
                setup.verify_package_delta(before, before | extra, self.packages)

    def test_post_install_rejects_existing_mutation_and_unlisted_addition(self):
        before = {('base','amd64'):('1','ii ')}
        good = before | {('ffmpeg','amd64'):('7:6.1.1-3ubuntu5','ii ')}
        for after in (good | {('base','amd64'):('2','ii ')}, good | {('extra','amd64'):('1','ii ')}):
            with self.assertRaises(RuntimeError): setup.verify_package_delta(before, after, self.packages)
        with self.assertRaisesRegex(RuntimeError, 'existing status'):
            setup.verify_package_delta(good, good, self.packages)

    def test_release_receipts_require_exact_reviewed_bytes_and_unique_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary); rows = []
            for suite in ('noble','noble-updates','noble-security'):
                data = ('reviewed-' + suite).encode()
                (directory / ('snapshot_dists_' + suite + '_InRelease')).write_bytes(data)
                rows.append({'name':suite+'.InRelease','bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
            self.assertEqual(len(setup.verify_release_metadata(directory, {'metadata':rows})),3)
            (directory/'snapshot_dists_noble_InRelease').write_bytes(b'changed')
            with self.assertRaisesRegex(RuntimeError,'differs'):
                setup.verify_release_metadata(directory, {'metadata':rows})

    def test_final_install_is_cache_only_exact_versions_with_root_tool_path(self):
        planned = self.packages | {'dep':{'version':'2'}}
        install = ['--yes','--no-install-recommends','--no-remove','install','ffmpeg=7:6.1.1-3ubuntu5']
        argv = setup.install_command(['/usr/bin/apt-get','-c','/private/apt.conf'], Path('/private/apt.conf'), install, planned)
        for flag in ('--no-download','--no-upgrade','--no-install-recommends','--no-remove','dep=2',
                     'PATH=/usr/sbin:/usr/bin:/sbin:/bin'):
            self.assertIn(flag,argv)
        self.assertNotIn('update',argv)

    def test_private_apt_config_excludes_ambient_hooks_sources_and_binary_caches(self):
        out = Path('/private/setup')
        config = setup.apt_configuration(out, out/'sources.list')
        for directive in ('Dir::Etc::parts "-";', 'Dir::Etc::main "-";',
                          'Dir::Etc::sourceparts "-";', 'Dir::Etc::preferences "-";',
                          'Dir::Etc::preferencesparts "-";', 'Dir::Cache "/private/setup";',
                          'Dir::Cache::pkgcache "";', 'Dir::Cache::srcpkgcache "";',
                          'Dir::State::lists "/private/setup/lists";',
                          'Dir::Cache::archives "/private/setup/archives";'):
            self.assertIn(directive,config.replace('\\','/'))

if __name__ == '__main__': unittest.main()
