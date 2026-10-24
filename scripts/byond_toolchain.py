"""Read the reviewed BYOND pin and fetch exact archive bytes. Never run BYOND."""
import argparse
from datetime import date
import hashlib
import json
from pathlib import Path
import re
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'tools/byond/version.json'
MAX_BYTES = 64 * 1024 * 1024
TRUST_SUFFIX = '; exact-byte reproducibility only, not BYOND-published or independently authenticated checksums'


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
    if not isinstance(value['linux'], dict) or set(value['linux']) != {'url', 'sha256', 'bytes'}:
        raise ValueError('Missing or malformed Linux archive metadata')
    for platform, archive in (('windows', value), ('linux', value['linux'])):
        expected = f'https://www.byond.com/download/build/{major}/{value["version"]}_byond' + ('.exe' if platform == 'windows' else '_linux.zip')
        if archive.get('url') != expected:
            raise ValueError('Archive URL must be the exact official versioned HTTPS URL')
        if not isinstance(archive.get('sha256'), str) or not re.fullmatch('[0-9a-f]{64}', archive['sha256']):
            raise ValueError('Missing or malformed observed archive SHA-256')
        if type(archive.get('bytes')) is not int or not 0 < archive['bytes'] <= MAX_BYTES:
            raise ValueError('Missing or malformed archive byte count')
    return value


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *_args):
        raise ValueError('BYOND archive redirects are not admitted')


def download(platform, output, *, opener=None, clock=time.monotonic):
    value = load()
    archive = value if platform == 'windows' else value['linux'] if platform == 'linux' else None
    if archive is None:
        raise ValueError('Unknown BYOND platform')
    output = Path(output)
    if output.exists():
        raise ValueError('Refusing to overwrite an existing archive')
    partial = output.with_name(output.name + '.part')
    started = clock()
    digest = hashlib.sha256()
    total = 0
    fetch = opener or urllib.request.build_opener(NoRedirect()).open
    # Exclusive creation preserves both pre-existing output and failed evidence.
    with partial.open('xb') as target:
        with fetch(archive['url'], timeout=15) as response:
            if response.geturl() != archive['url'] or response.status != 200:
                raise ValueError('Unexpected BYOND archive response')
            length = response.headers.get('Content-Length')
            if length is not None and length != str(archive['bytes']):
                raise ValueError('BYOND archive Content-Length mismatch')
            while True:
                if clock() - started >= 60:
                    raise ValueError('BYOND archive deadline exceeded')
                chunk = response.read(65536)
                if not chunk:
                    break
                total += len(chunk)
                if total > archive['bytes']:
                    raise ValueError('BYOND archive exceeds reviewed byte count')
                digest.update(chunk)
                target.write(chunk)
    if total != archive['bytes'] or digest.hexdigest() != archive['sha256']:
        raise ValueError('BYOND archive observed SHA-256 or byte count mismatch')
    # A hard link publishes the completed file exclusively, without replacing a
    # concurrently created output. Both paths are in the same filesystem.
    output.hardlink_to(partial)
    partial.unlink()
    return dict(version=value['version'], platform=platform, url=archive['url'],
                sha256=digest.hexdigest(), bytes=total, integritySource=value['integritySource'])


def compiler_log(text, expected):
    version(expected)
    banners = re.findall(r'^DM compiler version[^\r\n]*', text, re.M)
    if banners != ['DM compiler version ' + expected] or '- 0 errors, 0 warnings' not in text:
        raise ValueError('Compiler banner/result differs from reviewed BYOND requirement')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    field = commands.add_parser('field')
    field.add_argument('name', choices=('version', 'major', 'build', 'linux-bin'))
    fetch = commands.add_parser('download')
    fetch.add_argument('--platform', choices=('linux', 'windows'), required=True)
    fetch.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    value = load()
    if args.command == 'field':
        major, build = version(value['version'])
        print({'version': value['version'], 'major': str(major), 'build': str(build),
               'linux-bin': f'/opt/civ13-byond-{value["version"]}/byond/bin'}[args.name])
    else:
        print(json.dumps(download(args.platform, args.output), indent=2))


if __name__ == '__main__':
    main()
