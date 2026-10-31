"""Held, bounded package acquisition and extraction; no package execution."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import time
import urllib.error
import urllib.parse
import urllib.request

import acquire
import bounded_extractor
import cabinet_slice
from extract_portable_ffmpeg import extract, MANIFEST_SHA
from verify_directx_extracted import verify, MANIFEST_SHA256

PREPARE_ENABLED = False
DIRECTX_URL = 'https://download.microsoft.com/download/8/4/a/84a35bf1-dafe-4ae8-82af-ad2ae20b6b14/directx_Jun2010_redist.exe'
FFMPEG_URL = 'https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-10-30-13-01/ffmpeg-n9.0.2-39-g7adfbe40dc-win64-gpl-shared-9.0.zip'
DIRECTX_SHA = '053f76dcbb28802e23341b6a787e3b0791c0fa5c8d4d011b1044172dbf89c73b'
FFMPEG_SHA = '7c09a4c6bd73a5013963f06b1c6175326605cbc2585444ebe0f740ef4f35b4c9'
WORK_SECONDS = 180


def require(value, code):
    if not value:
        raise RuntimeError(code)


def record_failure(receipt, error):
    code = str(error)
    component = re.fullmatch(r'(file_hash|file_size):([A-Za-z0-9_.-]{1,160})', code)
    receipt['error'] = (component.group(1) if component else
                        code if re.fullmatch('[a-z_]{1,80}', code) else type(error).__name__)
    if component:
        receipt['component'] = component.group(2)
    if isinstance(error, urllib.error.HTTPError):
        receipt['http_status'] = error.code
    elif isinstance(error, urllib.error.URLError):
        receipt['network_reason_class'] = type(error.reason).__name__


class AllowedRedirects(urllib.request.HTTPRedirectHandler):
    def __init__(self, hosts):
        super().__init__()
        self.hosts = hosts
        self.count = 0

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        u = urllib.parse.urlsplit(newurl)
        self.count += 1
        require(self.count <= 4 and u.scheme == 'https' and u.hostname in self.hosts and
                u.port in (None, 443) and u.username is None and u.password is None and
                not u.fragment, 'unapproved_redirect')
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def fetch(url, destination, size, expected, hosts, deadline):
    require(not destination.exists() and not destination.is_symlink(), 'fresh_download_required')
    redirect = AllowedRedirects(hosts)
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), redirect)
    request = urllib.request.Request(url, headers={'User-Agent': 'Civ13-disposable-preflight/1'})
    h = hashlib.sha256()
    count = 0
    with opener.open(request, timeout=25) as response, destination.open('xb') as stream:
        final = urllib.parse.urlsplit(response.geturl())
        require(final.scheme == 'https' and final.hostname in hosts and final.port in (None, 443) and
                final.username is None and final.password is None, 'unapproved_response')
        length = response.headers.get('Content-Length')
        require(length is None or int(length) == size, 'content_length_mismatch')
        while True:
            require(time.monotonic() < deadline, 'acquisition_timeout')
            block = response.read(1024 * 1024)
            if not block:
                break
            count += len(block)
            require(count <= size, 'download_size_exceeded')
            h.update(block)
            stream.write(block)
        stream.flush()
        os.fsync(stream.fileno())
    require(count == size and h.hexdigest() == expected, 'download_identity_mismatch')
    return {'bytes': count, 'sha256': h.hexdigest(), 'redirect_count': redirect.count}


def verify_system_extractors(root):
    receipt = json.loads(acquire._read(root / 'system-extractors.json', 16384))
    binding = {key: os.environ.get(key, '') for key in
               ('GITHUB_SHA', 'GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT', 'GITHUB_JOB', 'GITHUB_REF')}
    require(receipt.get('status') == 'PASSED' and receipt.get('binding') == binding and
            set(receipt.get('files', {})) == {'tar.exe', 'expand.exe'}, 'extractor_signature_receipt')
    system = Path(os.environ['SystemRoot']) / 'System32'
    acquire._plain_ancestors(system)
    for name, row in receipt['files'].items():
        raw = acquire._read(system / name, 32 * 1024 ** 2)
        require(row.get('signature') == 'Valid' and row.get('signer') == 'Microsoft Windows' and
                row.get('bytes') == len(raw) and row.get('sha256') == acquire._sha(raw),
                'extractor_identity_changed')


def is_unsupported_archive(stderr):
    return re.fullmatch(rb'(?:bsdtar|tar(?:\.exe)?): error opening archive: unrecognized archive format\.?',
                        stderr.strip().lower()) is not None


def extract_directx(archive, output, workdir, deadline):
    manifest_path = Path(__file__).with_name('directx-official-file-manifest.json')
    raw = manifest_path.read_bytes()
    require(hashlib.sha256(raw).hexdigest() == MANIFEST_SHA256, 'directx_manifest_mismatch')
    rows = json.loads(raw)
    names = [row['name'] for row in rows]
    require(len(names) == 157 and len({n.casefold() for n in names}) == 157 and
            all(re.fullmatch(r'[A-Za-z0-9_.-]+', n) and n not in ('.', '..') for n in names),
            'directx_manifest_names')
    require(not output.exists() and not output.is_symlink(), 'fresh_directx_extract_required')
    root = Path(os.environ['SystemRoot'])
    tar = root / 'System32' / 'tar.exe'
    acquire._plain_ancestors(tar.parent)
    acquire._plain(tar)
    env = {'SystemRoot': str(root), 'WINDIR': str(root), 'SystemDrive': root.drive,
           'PATH': str(tar.parent), 'TEMP': str(workdir), 'TMP': str(workdir)}
    verify_system_extractors(workdir.parent)
    # The hosted version may not recognize a self-extracting PE. Keep distinct
    # bounded diagnostics; continue only for that specific format error.
    listing = bounded_extractor.invoke([str(tar), '-tvf', str(archive)], workdir, env, 'tar-list', deadline)
    require(listing['direct_child_exited'] and listing['pipes_closed'] and not listing['timed_out'], 'tar_cleanup_or_timeout')
    require(not listing['stdout_read_error'] and not listing['stderr_read_error'], 'tar_log_read_failure')
    require(not listing['stdout_overflow'], 'tar_listing_stdout_oversize')
    require(not listing['stderr_overflow'], 'tar_listing_stderr_oversize')
    stderr = (workdir / 'tar-list.stderr.log').read_bytes().lower()
    require(listing['exit_code'] == 0 or is_unsupported_archive(stderr), 'tar_listing_failed')
    if listing['exit_code'] == 0:
        lines = (workdir / 'tar-list.stdout.log').read_text(encoding='utf-8').splitlines()
        require(len(lines) == 157 and all(line.startswith('-') for line in lines), 'archive_nonregular')
        listed = [line.split()[-1] for line in lines]
        require(len(set(listed)) == 157 and set(listed) == set(names), 'archive_membership')
    cab = workdir / 'directx-payload.cab'
    cabinet_slice.write_payload(archive, cab, manifest_path,
                                lambda: require(time.monotonic() < deadline, 'acquisition_timeout'))
    expand = root / 'System32' / 'expand.exe'
    acquire._plain(expand)
    output.mkdir()
    verify_system_extractors(workdir.parent)
    extraction = bounded_extractor.invoke([str(expand), str(cab), '-F:*', str(output)],
                                          workdir, env, 'expand-extract', deadline)
    require(extraction['direct_child_exited'] and extraction['pipes_closed'] and not extraction['timed_out'], 'expand_cleanup_or_timeout')
    require(not extraction['stdout_read_error'] and not extraction['stderr_read_error'], 'expand_log_read_failure')
    require(not extraction['stdout_overflow'], 'expand_stdout_oversize')
    require(not extraction['stderr_overflow'], 'expand_stderr_oversize')
    require(extraction['exit_code'] == 0, 'expand_failed')
    return verify(output, manifest_path, lambda: require(time.monotonic() < deadline, 'acquisition_timeout'))


def prepare(root):
    require(PREPARE_ENABLED is True, 'toolchain_prepare_disabled')
    from activation import require_runtime
    binding = require_runtime()
    root = Path(root).absolute()
    acquire._plain_ancestors(root)
    workdir = root / 'official-directx'
    require(not workdir.exists() and not workdir.is_symlink(), 'fresh_toolchain_root_required')
    workdir.mkdir()
    receipt = {'schema': 1, 'binding': binding, 'status': 'FAILED', 'executed_packages': False}
    deadline = time.monotonic() + WORK_SECONDS
    try:
        require(shutil.disk_usage(root).free >= 1024 ** 3, 'toolchain_disk_reserve')
        directx = workdir / 'directx_Jun2010_redist.exe'
        zipfile = workdir / 'portable-ffmpeg.zip'
        receipt['directx_download'] = fetch(DIRECTX_URL, directx, 100275120, DIRECTX_SHA,
                                            {'download.microsoft.com'}, deadline)
        receipt['ffmpeg_download'] = fetch(FFMPEG_URL, zipfile, 85920853, FFMPEG_SHA,
                                           {'github.com', 'release-assets.githubusercontent.com'}, deadline)
        receipt['directx_extract'] = extract_directx(directx, workdir / 'extracted', workdir, deadline)
        pin = {'archive_bytes': 85920853, 'archive_sha256': FFMPEG_SHA}
        receipt['ffmpeg_extract'] = extract(zipfile, root / 'portable-ffmpeg', root, pin,
                                            Path(__file__).with_name('ffmpeg-btbn-file-manifest.json'),
                                            MANIFEST_SHA,
                                            lambda: require(time.monotonic() < deadline, 'acquisition_timeout'))
        require(time.monotonic() < deadline, 'acquisition_timeout')
        receipt['status'] = 'PASSED'
    except Exception as error:
        record_failure(receipt, error)
        raise
    finally:
        raw = (json.dumps(receipt, sort_keys=True) + '\n').encode()
        require(len(raw) <= 16384, 'preparation_receipt_oversize')
        with (root / 'toolchain-preparation-receipt.json').open('xb') as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
    return receipt


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(prepare(args.root), sort_keys=True))
