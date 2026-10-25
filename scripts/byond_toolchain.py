"""Read the reviewed BYOND pin and fetch exact archive bytes. Never run BYOND."""
import argparse
from datetime import date
import hashlib
import http.client
import json
from pathlib import Path
import re
import stat
import time
import urllib.request
import urllib.response
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'tools/byond/version.json'
MAX_BYTES = 64 * 1024 * 1024
TRUST_SUFFIX = '; exact-byte reproducibility only, not BYOND-published or independently authenticated checksums'


# This one published asset was independently read back anonymously on 2026-10-25.
# A replacement asset, tag or version needs a new review, not a broader redirect rule.
REPOSITORY_RELEASE = {
    'url': 'https://github.com/Civ13/Civ13/releases/download/byond-toolchain-cache-516.1688-linux-16278f318cde/516.1688_byond_linux.zip',
    'repositoryId': 141349998,
    'releaseId': 423087014,
    'assetId': 673801489,
    'redirectUrl': 'https://release-assets.githubusercontent.com/github-production-release-asset/141349998/2c92a741-bfd1-4b43-8ec3-8c3813669b82',
    'tagTarget': '3f3dd47f614f4659031a793dc590346f5e4de3e6',
    'provenance': 'Complete unchanged official-observed Linux archive and bundled notices; user-approved repository mirror, not a vendor-authenticated checksum',
}
REPOSITORY_ARCHIVE = ('516.1688', 4887281,
                      '16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9')


def unique(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError('Duplicate BYOND metadata field')
        value[key] = item
    return value


def version(value):
    if not isinstance(value, str) or not re.fullmatch(r'[1-9][0-9]{0,4}\.[1-9][0-9]{0,4}', value):
        raise ValueError('Missing or malformed BYOND version')
    parts = tuple(map(int, value.split('.')))
    if max(parts) > 65534:
        raise ValueError('BYOND version exceeds PE version bounds')
    return parts


def load(path=MANIFEST):
    data = Path(path).read_bytes()
    if len(data) > 32768:
        raise ValueError('BYOND metadata exceeds limit')
    value = json.loads(data, object_pairs_hook=unique)
    keys = {'schema', 'version', 'url', 'sha256', 'bytes', 'linux', 'minimumCompiler',
            'savefileMajor', 'integritySource', 'releaseNotes', 'downloadPage'}
    if not isinstance(value, dict) or set(value) != keys or type(value['schema']) is not int or value['schema'] != 1:
        raise ValueError('Invalid BYOND metadata schema')
    major, _ = version(value['version'])
    minimum = version(value['minimumCompiler'])
    if minimum > version(value['version']) or minimum[0] != major or type(value['savefileMajor']) is not int or value['savefileMajor'] != major:
        raise ValueError('Inconsistent compiler minimum or savefile major')
    source = value['integritySource']
    if not isinstance(source, str) or not re.fullmatch(r'Observed official HTTPS downloads on [0-9]{4}-[0-9]{2}-[0-9]{2}' + re.escape(TRUST_SUFFIX), source):
        raise ValueError('Invalid observed provenance declaration')
    date.fromisoformat(source.split(' on ', 1)[1].split(';', 1)[0])
    if (value['releaseNotes'] != f'https://www.byond.com/docs/notes/{major}.html'
            or value['downloadPage'] != 'https://www.byond.com/download/'):
        raise ValueError('Invalid BYOND provenance metadata')
    if not isinstance(value['linux'], dict) or set(value['linux']) != {'url', 'communityMirrorUrl', 'repositoryRelease', 'sha256', 'bytes'}:
        raise ValueError('Missing or malformed Linux archive metadata')
    if value['linux']['communityMirrorUrl'] != f'https://byond-builds.dm-lang.org/{major}/{value["version"]}_byond_linux.zip':
        raise ValueError('Community mirror must be the exact reviewed versioned HTTPS URL')
    for platform, archive in (('windows', value), ('linux', value['linux'])):
        expected = f'https://www.byond.com/download/build/{major}/{value["version"]}_byond' + ('.exe' if platform == 'windows' else '_linux.zip')
        if archive.get('url') != expected:
            raise ValueError('Archive URL must be the exact official versioned HTTPS URL')
        if not isinstance(archive.get('sha256'), str) or not re.fullmatch('[0-9a-f]{64}', archive['sha256']):
            raise ValueError('Missing or malformed observed archive SHA-256')
        if type(archive.get('bytes')) is not int or not 0 < archive['bytes'] <= MAX_BYTES:
            raise ValueError('Missing or malformed archive byte count')
    reviewed_release(value['linux']['repositoryRelease'])
    if (value['version'], value['linux']['bytes'], value['linux']['sha256']) != REPOSITORY_ARCHIVE:
        raise ValueError('Repository release must match the exact reviewed Linux asset and archive')
    return value


def reviewed_release(binding):
    if (not isinstance(binding, dict) or set(binding) != set(REPOSITORY_RELEASE)
            or any(type(binding[key]) is not type(expected) or binding[key] != expected
                   for key, expected in REPOSITORY_RELEASE.items())):
        raise ValueError('Repository release identity differs from the reviewed public asset')


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *_args):
        raise ValueError('BYOND archive redirects are not admitted')


class ReleaseResponseOnly(NoRedirect):
    """Expose the initial 302 for explicit inspection; never follow it here."""
    def http_error_302(self, request, response, code, message, headers):
        return urllib.response.addinfourl(response, headers, request.full_url, code)


def release_target(target, binding):
    # Keep the signed query opaque and ephemeral. Never return it in receipts or errors.
    if (not isinstance(target, str) or len(target) > 8192
            or '#' in target or any(ord(char) < 33 or ord(char) > 126 for char in target)):
        raise ValueError('Malformed repository release redirect')
    parts = urlsplit(target)
    if (not target.startswith(binding['redirectUrl'] + '?') or not parts.query or parts.fragment
            or parts._replace(query='').geturl() != binding['redirectUrl']):
        raise ValueError('Repository release redirect differs from the exact reviewed asset')
    return target


def download_release(url, binding, output, archive, opener, clock, started):
    # Separate requests do not forward response cookies, Authorization or caller
    # headers. Retain urllib's ordinary configured proxy and TLS policy.
    fetch = opener or urllib.request.build_opener(ReleaseResponseOnly()).open

    def request(target):
        if clock() - started >= 60:
            raise ValueError('BYOND archive deadline exceeded')
        try:
            return fetch(urllib.request.Request(target, method='GET'), timeout=15)
        except Exception:
            # urllib/transport errors can embed the signed URL. Suppress both
            # their text and traceback chain, without retries or another source.
            raise ValueError('Repository release request failed') from None

    with request(url) as response:
        if response.geturl() != url or response.status != 302:
            raise ValueError('Repository release requires its single reviewed redirect')
        locations = (response.headers.get_all('Location', []) if hasattr(response.headers, 'get_all')
                     else [response.headers.get('Location')])
        if len(locations) != 1:
            raise ValueError('Repository release requires one redirect destination')
        target = release_target(locations[0], binding)
    with request(target) as response:
        if response.geturl() != target or response.status != 200:
            raise ValueError('Unexpected repository release asset response')
        length = response.headers.get('Content-Length')
        if length is not None and length != str(archive['bytes']):
            raise ValueError('BYOND archive Content-Length mismatch')
        try:
            publish(response, output, archive, clock, started)
        except (OSError, http.client.HTTPException):
            raise ValueError('Repository release transfer failed') from None


def archive_for(value, platform):
    archive = value if platform == 'windows' else value['linux'] if platform == 'linux' else None
    if archive is None:
        raise ValueError('Unknown BYOND platform')
    return archive


def source_url(value, platform, source):
    archive = archive_for(value, platform)
    if source == 'official':
        return archive['url']
    if source == 'community-mirror' and platform == 'linux':
        return archive['communityMirrorUrl']
    if source == 'repository-release' and platform == 'linux':
        return archive['repositoryRelease']['url']
    raise ValueError('Unreviewed BYOND source/platform; no automatic fallback')


def cache_key(value, platform):
    archive = archive_for(value, platform)
    return f'byond-archive-v1-{platform}-{value["version"]}-{archive["sha256"]}'


def regular(path):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or getattr(info, 'st_file_attributes', 0) & 0x400:
        raise ValueError('Archive/cache metadata must be an ordinary non-symlink file')


def publish(stream, output, archive, clock, started):
    """Verify bounded bytes while copying; publish exclusively only after proof."""
    output = Path(output)
    if output.exists() or output.is_symlink():
        raise ValueError('Refusing to overwrite an existing archive')
    partial = output.with_name(output.name + '.part')
    digest, total = hashlib.sha256(), 0
    with partial.open('xb') as target:
        while True:
            if clock() - started >= 60:
                raise ValueError('BYOND archive deadline exceeded')
            chunk = stream.read(65536)
            if not chunk:
                break
            total += len(chunk)
            if total > archive['bytes']:
                raise ValueError('BYOND archive exceeds reviewed byte count')
            digest.update(chunk)
            target.write(chunk)
    if total != archive['bytes'] or digest.hexdigest() != archive['sha256']:
        raise ValueError('BYOND archive observed SHA-256 or byte count mismatch')
    output.hardlink_to(partial)
    partial.unlink()


def validate_download_receipt(receipt, value, platform):
    keys = {'version', 'platform', 'url', 'sha256', 'bytes', 'integritySource', 'source',
            'requested_source', 'upstream_source', 'upstream_url', 'cache_key', 'cache_status'}
    if isinstance(receipt, dict) and receipt.get('upstream_source') == 'repository-release':
        keys.add('repository_release')
    if not isinstance(receipt, dict) or set(receipt) != keys:
        raise ValueError('Missing or malformed BYOND acquisition receipt')
    if any(not isinstance(receipt[key], str) for key in ('source', 'requested_source', 'upstream_source', 'upstream_url', 'cache_status')):
        raise ValueError('Malformed BYOND acquisition source fields')
    archive = archive_for(value, platform)
    for key, expected in (('version', value['version']), ('platform', platform), ('sha256', archive['sha256']),
                          ('bytes', archive['bytes']), ('integritySource', value['integritySource']),
                          ('cache_key', cache_key(value, platform))):
        if type(receipt[key]) is not type(expected) or receipt[key] != expected:
            raise ValueError('BYOND acquisition receipt differs from reviewed ' + key)
    if receipt['upstream_source'] == 'repository-release':
        reviewed_release(receipt['repository_release'])
        if platform != 'linux' or receipt['repository_release'] != archive['repositoryRelease']:
            raise ValueError('BYOND acquisition repository release identity mismatch')
    requested = source_url(value, platform, receipt['requested_source'])
    upstream = source_url(value, platform, receipt['upstream_source'])
    if receipt['upstream_url'] != upstream:
        raise ValueError('BYOND acquisition upstream URL mismatch')
    if receipt['source'] == 'cache':
        if receipt['cache_status'] != 'hit' or receipt['url'] is not None:
            raise ValueError('Invalid BYOND cache hit receipt')
    elif (receipt['source'] != receipt['requested_source'] or receipt['source'] != receipt['upstream_source']
          or receipt['url'] != requested or receipt['cache_status'] not in {'disabled', 'miss'}):
        raise ValueError('Invalid BYOND network source receipt')
    return receipt


def read_download_receipt(path, value, platform):
    path = Path(path)
    regular(path)
    if path.stat().st_size > 32768:
        raise ValueError('BYOND acquisition receipt exceeds limit')
    return validate_download_receipt(json.loads(path.read_bytes(), object_pairs_hook=unique), value, platform)


def download(platform, output, *, source='official', cache_dir=None, opener=None, clock=time.monotonic):
    value = load()
    archive = archive_for(value, platform)
    url = source_url(value, platform, source)  # No caller-supplied URL or fallback.
    output = Path(output)
    if output.exists() or output.is_symlink():
        raise ValueError('Refusing to overwrite an existing archive')
    partial = output.with_name(output.name + '.part')
    if partial.exists() or partial.is_symlink():
        raise FileExistsError('Preserving previous BYOND partial archive')
    started = clock()
    key = cache_key(value, platform)
    cached = None
    if cache_dir is not None:
        directory = Path(cache_dir)
        directory.mkdir(parents=True, exist_ok=True)
        if directory.is_symlink() or getattr(directory.lstat(), 'st_file_attributes', 0) & 0x400:
            raise ValueError('Linked BYOND cache directory refused')
        cached = directory / (key + '.zip')
        metadata = cached.with_suffix('.json')
        cache_partial = cached.with_name(cached.name + '.part')
        if cache_partial.exists() or cache_partial.is_symlink():
            raise ValueError('Incomplete cached BYOND archive preserved; no network fallback')
        if cached.exists() or cached.is_symlink() or metadata.exists() or metadata.is_symlink():
            regular(cached)
            prior = read_download_receipt(metadata, value, platform)
            if prior['source'] == 'cache' or prior['cache_status'] != 'miss':
                raise ValueError('Cache origin receipt must describe its original verified download')
            if cached.stat().st_size != archive['bytes']:
                raise ValueError('Cached BYOND archive size mismatch; no network fallback')
            with cached.open('rb') as stream:
                publish(stream, output, archive, clock, started)
            return validate_download_receipt(dict(prior, source='cache', url=None, requested_source=source,
                                                  cache_status='hit'), value, platform)
    if source == 'repository-release':
        download_release(url, archive['repositoryRelease'], output, archive, opener, clock, started)
    else:
        fetch = opener or urllib.request.build_opener(NoRedirect()).open
        # No headers, credential/proxy customization or alternate-origin retries.
        with fetch(url, timeout=15) as response:
            if response.geturl() != url or response.status != 200:
                raise ValueError('Unexpected BYOND archive response')
            length = response.headers.get('Content-Length')
            if length is not None and length != str(archive['bytes']):
                raise ValueError('BYOND archive Content-Length mismatch')
            publish(response, output, archive, clock, started)
    receipt = validate_download_receipt(dict(version=value['version'], platform=platform, url=url,
        sha256=archive['sha256'], bytes=archive['bytes'], integritySource=value['integritySource'],
        source=source, requested_source=source, upstream_source=source, upstream_url=url,
        cache_key=key, cache_status='miss' if cached else 'disabled',
        **({'repository_release': dict(archive['repositoryRelease'])} if source == 'repository-release' else {})), value, platform)
    if cached is not None:
        regular(output)
        with output.open('rb') as stream:
            publish(stream, cached, archive, clock, started)
        with metadata.open('x', encoding='utf-8') as target:
            json.dump(receipt, target, indent=2)
            target.write('\n')
    return receipt


def compiler_log(text, expected):
    version(expected)
    banners = re.findall(r'^DM compiler version[^\r\n]*', text, re.M)
    if banners != ['DM compiler version ' + expected] or '- 0 errors, 0 warnings' not in text:
        raise ValueError('Compiler banner/result differs from reviewed BYOND requirement')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    field = commands.add_parser('field')
    field.add_argument('name', choices=('version', 'major', 'build', 'linux-bin', 'linux-cache-key'))
    fetch = commands.add_parser('download')
    fetch.add_argument('--platform', choices=('linux', 'windows'), required=True)
    fetch.add_argument('--output', type=Path, required=True)
    fetch.add_argument('--source', choices=('official', 'community-mirror', 'repository-release'), default='official')
    fetch.add_argument('--cache-dir', type=Path)
    args = parser.parse_args()
    value = load()
    if args.command == 'field':
        major, build = version(value['version'])
        print({'version': value['version'], 'major': str(major), 'build': str(build),
               'linux-bin': f'/opt/civ13-byond-{value["version"]}/byond/bin',
               'linux-cache-key': cache_key(value, 'linux')}[args.name])
    else:
        print(json.dumps(download(args.platform, args.output, source=args.source, cache_dir=args.cache_dir), indent=2))


if __name__ == '__main__':
    main()
