"""Offline release/error/idempotence controls; no gh, uploads or live releases."""
import base64
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from urllib.parse import quote

spec = importlib.util.spec_from_file_location('native_release', Path(__file__).resolve().parents[1] / 'release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)
HEAD = 'a' * 40


def event(prerelease=False):
    return {'action': 'published', 'repository': {'full_name': 'Civ13/Civ13'},
            'release': {'id': 123, 'tag_name': 'launcher-v1.0.0', 'draft': False, 'prerelease': prerelease}}


class FakeGitHub:
    def __init__(self, plan):
        self.plan = plan
        self.assets = {}
        self.uploads = 0
        self.activations = 0
        self.parent = None
        self.feeds = {}
        self.blobs = {}
        self.trees = {}
        self.fail_upload = False
        self.corrupt_download = False
        self.corrupt_commit = False
        self.fail_compare_and_swap = False
        self.tag_head = HEAD
        self.counter = 0

    def _sha(self):
        self.counter += 1
        return f'{self.counter:040x}'

    def api(self, endpoint, body=None, method=None):
        if endpoint == 'releases/123':
            return {'id': 123, 'tag_name': self.plan['tag'], 'draft': False, 'prerelease': self.plan['prerelease']}
        if endpoint.startswith('commits/'):
            return {'sha': self.tag_head}
        if endpoint == 'releases/123/assets?per_page=100':
            return [asset['metadata'] for asset in self.assets.values()]
        if endpoint == 'git/ref/heads/' + release.FEED:
            if self.parent is None:
                raise release.ApiError('missing', 404)
            return {'object': {'sha': self.parent}}
        if endpoint.startswith('contents/native-launcher-channel.json?ref='):
            sha = endpoint.split('=', 1)[1]
            value = self.feeds[sha]
            if self.corrupt_commit and sha != self.parent:
                value = {'corrupt': True}
            return {'content': base64.b64encode(release.encoded(value)).decode()}
        if endpoint.startswith('git/commits/'):
            return {'tree': {'sha': 'old-tree'}}
        if endpoint == 'git/blobs':
            sha = self._sha()
            self.blobs[sha] = json.loads(base64.b64decode(body['content']))
            return {'sha': sha}
        if endpoint == 'git/trees':
            sha = self._sha()
            self.trees[sha] = self.blobs[body['tree'][0]['sha']]
            return {'sha': sha}
        if endpoint == 'git/commits':
            sha = self._sha()
            self.feeds[sha] = self.trees[body['tree']]
            return {'sha': sha}
        if endpoint in ('git/refs', 'git/refs/heads/' + release.FEED):
            if self.fail_compare_and_swap:
                raise release.ApiError('non-fast-forward')
            if body.get('force') is True:
                raise AssertionError('Forced feed update')
            self.parent = body['sha']
            self.activations += 1
            return {'object': {'sha': self.parent}}
        raise AssertionError('Unexpected API call: ' + endpoint)

    def upload(self, tag, paths):
        self.uploads += 1
        for path in paths:
            data = path.read_bytes()
            self.assets[path.name] = {'data': data, 'metadata': {
                'name': path.name, 'state': 'uploaded', 'size': len(data),
                'digest': 'sha256:' + hashlib.sha256(data).hexdigest(),
                'browser_download_url': f'https://github.com/Civ13/Civ13/releases/download/{quote(tag, safe="")}/{path.name}'}}
            if self.fail_upload:
                raise release.ApiError('simulated interrupted upload')

    def download(self, tag, name, destination):
        path = destination / name
        path.write_bytes(b'corrupt' if self.corrupt_download else self.assets[name]['data'])
        return path


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='civ13-release-tests-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.exe = self.root / 'Civ13.exe'
        self.exe.write_bytes(b'MZ fixture binary; never executed')
        self.client = self.root / 'client-channel.json'
        self.client.write_text('{}')
        self.plan = release.make_plan(event(), {'schema': 1, 'version': '1.0.0'}, HEAD, HEAD)
        self.api = FakeGitHub(self.plan)

    def publish(self):
        return release.publish(self.api, self.plan, self.exe, self.root / 'output', self.client)

    def old_feed(self):
        self.api.parent = 'f' * 40
        self.api.feeds[self.api.parent] = {'schema': 1, 'version': '0.9.0',
            'url': 'https://github.com/Civ13/Civ13/releases/download/old/Civ13.exe', 'sha256': '0' * 64}

    def test_success_readback_then_feed_and_idempotent_repeat(self):
        result = self.publish()
        self.assertEqual(result['feed'], 'activated')
        self.assertEqual(set(self.api.assets), {'Civ13.exe', 'Civ13.exe.sha256', 'native-launcher-release.json'})
        self.assertEqual(self.api.feeds[self.api.parent]['sha256'], release.digest(self.exe))
        self.assertEqual(self.publish()['feed'], 'unchanged')
        self.assertEqual((self.api.uploads, self.api.activations), (1, 1))

    def test_prerelease_generates_assets_without_stable_activation(self):
        self.plan['prerelease'] = True
        self.old_feed()
        previous = self.api.parent
        self.assertEqual(self.publish()['feed'], 'prerelease-not-activated')
        self.assertEqual(self.api.parent, previous)
        self.assertEqual((len(self.api.assets), self.api.activations), (3, 0))

    def test_partial_upload_leaves_previous_feed(self):
        self.old_feed()
        previous = self.api.parent
        self.api.fail_upload = True
        with self.assertRaises(release.ApiError):
            self.publish()
        self.assertEqual(self.api.parent, previous)
        self.assertEqual(self.api.activations, 0)
        self.api.fail_upload = False
        self.assertEqual(self.publish()['feed'], 'activated')

    def test_corrupt_download_and_commit_leave_previous_feed(self):
        for control in ('corrupt_download', 'corrupt_commit'):
            with self.subTest(control=control):
                self.api = FakeGitHub(self.plan)
                self.old_feed()
                previous = self.api.parent
                setattr(self.api, control, True)
                with self.assertRaises(ValueError):
                    self.publish()
                self.assertEqual(self.api.parent, previous)
                self.assertEqual(self.api.activations, 0)

    def test_changed_existing_bytes_never_overwrite(self):
        self.publish()
        parent = self.api.parent
        original = self.api.assets['Civ13.exe']['data']
        self.exe.write_bytes(b'different binary')
        with self.assertRaises(ValueError):
            self.publish()
        self.assertEqual(self.api.assets['Civ13.exe']['data'], original)
        self.assertEqual((self.api.uploads, self.api.parent), (1, parent))

    def test_tag_movement_blocks_publication(self):
        self.api.tag_head = 'b' * 40
        with self.assertRaisesRegex(ValueError, 'tag moved'):
            self.publish()
        self.assertEqual((self.api.uploads, self.api.activations), (0, 0))

    def test_conflicting_feed_commit_never_forces(self):
        self.old_feed()
        previous = self.api.parent
        self.api.fail_compare_and_swap = True
        with self.assertRaises(release.ApiError):
            self.publish()
        self.assertEqual((self.api.parent, self.api.activations), (previous, 0))

    def test_release_metadata_negative_controls(self):
        for key, value in [('action', 'created'), ('repository', {'full_name': 'Other/Repo'})]:
            bad = copy.deepcopy(event())
            bad[key] = value
            with self.assertRaises(ValueError):
                release.make_plan(bad, {'schema': 1, 'version': '1.0.0'}, HEAD, HEAD)
        for key, value in [('draft', True), ('id', 0), ('tag_name', '-option'), ('prerelease', 'false')]:
            bad = copy.deepcopy(event())
            bad['release'][key] = value
            with self.assertRaises(ValueError):
                release.make_plan(bad, {'schema': 1, 'version': '1.0.0'}, HEAD, HEAD)
        with self.assertRaises(ValueError):
            release.make_plan(event(), {'schema': 1, 'version': '1.0.1'}, HEAD, HEAD)
        with self.assertRaises(ValueError):
            release.make_plan(event(), {'schema': 1, 'version': '1.0.0'}, HEAD, 'b' * 40)
        with self.assertRaises(ValueError):
            release.make_plan(event(), {'schema': 1, 'version': '99999.0.0'}, HEAD, HEAD)

    def test_dated_release_uses_exact_tag_version_config(self):
        payload = event()
        payload['release']['tag_name'] = 'opendream-client-2026-10-14'
        self.assertEqual(release.make_plan(payload, {'schema': 1, 'version': '1.0.0'}, HEAD, HEAD)['version'], '1.0.0')

    def test_stable_no_downgrade_or_same_version_replacement(self):
        current = {'schema': 1, 'version': '1.0.0', 'url': 'old', 'sha256': '0' * 64}
        for candidate in (dict(current, version='0.9.0'), dict(current, sha256='1' * 64)):
            with self.assertRaises(ValueError):
                release.feed_policy(current, candidate)
        self.assertFalse(release.feed_policy(current, current))


if __name__ == '__main__':
    unittest.main()
