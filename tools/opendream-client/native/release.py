"""Exact-tag native launcher publication. No release creation or asset overwrite."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
from urllib.parse import quote, unquote, urlparse

REPO = 'Civ13/Civ13'
FEED = 'native-launcher-updates'
VERSION = re.compile(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\Z')
SHA = re.compile(r'[a-f0-9]{40}\Z')


def digest(path):
    with open(path, 'rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def encoded(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode('utf-8')


def version(value):
    if not isinstance(value, str) or not VERSION.fullmatch(value):
        raise ValueError('Expected a three-part numeric launcher version.')
    result = tuple(map(int, value.split('.')))
    if any(component > 65534 for component in result):
        raise ValueError('Launcher version exceeds Windows PE version limits.')
    return result


def make_plan(event, configured, head, tagged_head):
    release = event.get('release', {})
    tag = release.get('tag_name', '')
    if (event.get('action') != 'published' or event.get('repository', {}).get('full_name', '').lower() != REPO.lower()
            or release.get('draft') is not False or type(release.get('prerelease')) is not bool
            or type(release.get('id')) is not int or release['id'] <= 0
            or not isinstance(tag, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._/-]{0,199}', tag)
            or '..' in tag or not SHA.fullmatch(head) or tagged_head != head):
        raise ValueError('Release identity, publication state or exact tag commit is invalid.')
    if tag.lower().startswith('byond-toolchain-cache-'):
        raise ValueError('BYOND toolchain cache releases are not launcher releases.')
    configured_version = configured.get('version')
    if configured.get('schema') != 1:
        raise ValueError('Invalid launcher version configuration.')
    version(configured_version)
    # Existing dated game release names remain supported via exact-tag version.json.
    semantic_tag = re.fullmatch(r'(?:launcher-)?v?(\d+\.\d+\.\d+)', tag)
    if semantic_tag and semantic_tag.group(1) != configured_version:
        raise ValueError('Semantic release tag differs from exact-tag launcher version.json.')
    return {'schema': 1, 'repo': REPO, 'release_id': release['id'], 'tag': tag,
            'head': head, 'version': configured_version, 'prerelease': release['prerelease']}


class ApiError(RuntimeError):
    def __init__(self, message, status=None):
        super().__init__(message)
        self.status = status


class GitHub:
    def api(self, endpoint, body=None, method=None):
        command = ['gh', 'api', f'repos/{REPO}/{endpoint}']
        if method:
            command += ['--method', method]
        if body is not None:
            command += ['--input', '-']
        response = subprocess.run(command, input=encoded(body) if body is not None else None,
                                  capture_output=True, check=False)
        if response.returncode:
            # Never print request headers or credentials. Preserve only bounded API diagnostics.
            stderr = response.stderr.decode('utf-8', errors='replace')
            raise ApiError(stderr[:1000], 404 if 'HTTP 404' in stderr else None)
        return json.loads(response.stdout)

    def upload(self, tag, paths):
        subprocess.run(['gh', 'release', 'upload', tag, *map(str, paths), '--repo', REPO], check=True)

    def download(self, tag, name, destination):
        subprocess.run(['gh', 'release', 'download', tag, '--repo', REPO,
                        '--pattern', name, '--dir', str(destination)], check=True)
        return destination / name


def check_release(api, plan):
    release = api.api(f"releases/{plan['release_id']}")
    if (release.get('id') != plan['release_id'] or release.get('tag_name') != plan['tag']
            or release.get('draft') is not False or release.get('prerelease') != plan['prerelease']):
        raise ValueError('Release changed during deployment.')
    if api.api('commits/' + quote(plan['tag'], safe=''))['sha'] != plan['head']:
        raise ValueError('Release tag moved during deployment.')


def asset_map(api, plan):
    assets = api.api(f"releases/{plan['release_id']}/assets?per_page=100")
    if len(assets) >= 100:
        raise ValueError('Release assets exceed bounded deployment inventory.')
    result = {}
    for asset in assets:
        if asset['name'] in result:
            raise ValueError('Duplicate release asset names.')
        result[asset['name']] = asset
    return result


def asset_url(asset, plan):
    url = asset.get('browser_download_url', '')
    parsed = urlparse(url)
    prefix = '/Civ13/Civ13/releases/download/'
    suffix = '/' + asset['name']
    if (parsed.scheme != 'https' or parsed.netloc != 'github.com' or parsed.query or parsed.fragment
            or not parsed.path.startswith(prefix) or not parsed.path.endswith(suffix)
            or unquote(parsed.path[len(prefix):-len(suffix)]) != plan['tag']):
        raise ValueError('Release asset URL differs from the planned repository/tag.')
    return url


def verify_asset(api, plan, asset, local):
    asset_url(asset, plan)
    expected = digest(local)
    if asset.get('state') != 'uploaded' or asset.get('size') != local.stat().st_size:
        raise ValueError('Existing or uploaded release asset is incomplete or differs in size.')
    if asset.get('digest') and asset['digest'] != 'sha256:' + expected:
        raise ValueError('Release asset digest differs; immutable assets will not be overwritten.')
    with tempfile.TemporaryDirectory(prefix='civ13-release-readback-') as temporary:
        received = api.download(plan['tag'], local.name, Path(temporary))
        if digest(received) != expected:
            raise ValueError('Release asset readback hash differs; feed unchanged.')


def feed_policy(current, desired):
    for manifest in (current, desired):
        if (manifest.get('schema') != 1 or not re.fullmatch(r'[a-f0-9]{64}', manifest.get('sha256', ''))):
            raise ValueError('Invalid native feed manifest.')
        version(manifest['version'])
    if version(desired['version']) < version(current['version']):
        raise ValueError('Stable launcher feed cannot downgrade.')
    if version(desired['version']) == version(current['version']):
        if desired != current:
            raise ValueError('Same launcher version cannot change bytes or release URL.')
        return False
    return True


def activate_feed(api, desired):
    parent = None
    tree = None
    try:
        ref = api.api('git/ref/heads/' + FEED)
    except ApiError as error:
        if error.status != 404:
            raise
    else:
        parent = ref['object']['sha']
        # Read through the exact parent, so concurrent deployments cannot mix snapshots.
        current_file = api.api('contents/native-launcher-channel.json?ref=' + parent)
        current = json.loads(base64.b64decode(current_file['content'], validate=False))
        if not feed_policy(current, desired):
            return 'unchanged'
        tree = api.api('git/commits/' + parent)['tree']['sha']
    blob = api.api('git/blobs', {'encoding': 'base64', 'content': base64.b64encode(encoded(desired)).decode('ascii')}, 'POST')['sha']
    tree_request = {'tree': [{'path': 'native-launcher-channel.json', 'mode': '100644', 'type': 'blob', 'sha': blob}]}
    if tree:
        tree_request['base_tree'] = tree
    new_tree = api.api('git/trees', tree_request, 'POST')['sha']
    commit = api.api('git/commits', {'message': 'Publish verified native launcher ' + desired['version'],
                    'tree': new_tree, 'parents': [parent] if parent else []}, 'POST')['sha']
    published = api.api('contents/native-launcher-channel.json?ref=' + commit)
    if json.loads(base64.b64decode(published['content'])) != desired:
        raise ValueError('Committed feed content differs; previous feed unchanged.')
    if parent:
        # No force: a competing sibling commit fails without changing the winning feed.
        api.api('git/refs/heads/' + FEED, {'sha': commit, 'force': False}, 'PATCH')
    else:
        api.api('git/refs', {'ref': 'refs/heads/' + FEED, 'sha': commit}, 'POST')
    return 'activated'


def publish(api, plan, executable, output, client_channel):
    check_release(api, plan)
    sha256 = digest(executable)
    output.mkdir(parents=True, exist_ok=True)
    checksum = output / 'Civ13.exe.sha256'
    checksum.write_text(sha256 + '  Civ13.exe\n', encoding='utf-8')
    metadata = output / 'native-launcher-release.json'
    metadata.write_bytes(encoded({**plan, 'exe': {'name': 'Civ13.exe', 'sha256': sha256,
                        'size': executable.stat().st_size}, 'client_channel_sha256': digest(client_channel)}))
    paths = [executable, checksum, metadata]
    assets = asset_map(api, plan)
    # Validate every pre-existing asset before adding missing ones; never --clobber.
    for path in paths:
        if path.name in assets:
            verify_asset(api, plan, assets[path.name], path)
    missing = [path for path in paths if path.name not in assets]
    if missing:
        api.upload(plan['tag'], missing)
    check_release(api, plan)
    assets = asset_map(api, plan)
    for path in paths:
        if path.name not in assets:
            raise ValueError('Release upload incomplete; feed unchanged.')
        verify_asset(api, plan, assets[path.name], path)
    check_release(api, plan)
    desired = {'schema': 1, 'version': plan['version'], 'url': asset_url(assets['Civ13.exe'], plan), 'sha256': sha256}
    # Stable releases only. Prereleases generate assets without changing the stable feed.
    result = 'prerelease-not-activated' if plan['prerelease'] else activate_feed(api, desired)
    return {'head': plan['head'], 'version': plan['version'], 'sha256': sha256, 'feed': result, 'url': desired['url']}


def git(*args):
    return subprocess.check_output(['git', *args], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['plan', 'publish'])
    parser.add_argument('--event', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--executable', type=Path)
    options = parser.parse_args()
    native = Path(__file__).resolve().parent
    event = json.loads(options.event.read_text(encoding='utf-8-sig'))
    tag = event.get('release', {}).get('tag_name', '')
    plan = make_plan(event, json.loads((native / 'version.json').read_text()), git('rev-parse', 'HEAD'),
                     git('rev-parse', '--verify', 'refs/tags/' + tag + '^{commit}'))
    options.output.mkdir(parents=True, exist_ok=True)
    if options.mode == 'plan':
        (options.output / 'plan.json').write_bytes(encoded(plan))
        print(json.dumps(plan))
        return
    if not options.executable or options.executable.name != 'Civ13.exe':
        raise ValueError('The checked and tested Civ13.exe is required.')
    if json.loads((options.output / 'plan.json').read_text()) != plan:
        raise ValueError('Build plan differs from current exact-tag identity.')
    print(json.dumps(publish(GitHub(), plan, options.executable, options.output, native.parent / 'channel.json')))


if __name__ == '__main__':
    main()
