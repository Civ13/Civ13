"""Bounded, pinned BYOND acquisition and read-only/static dependency preflight.

Importing this module performs no work. A reviewed caller may invoke acquire()
then check_dependencies(). The latter may extract only the pinned d3dx9_43.dll
from the bundled CAB using installed Windows expand.exe; it never installs a
runtime or executes a package binary. Static checks are not a runtime pass.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import stat
import struct
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
import zipfile

from inspect_package import pe_imports

ARCHIVE_BYTES = 8602470
ARCHIVE_SHA256 = '9079f29b0747719233715dfeff223641e6fb69bd16b8ba9676d5cd42cfcd0148'
ARCHIVE_URL = 'https://cmss13-devs.github.io/byond-build-mirror/download/build/516/516.1688_byond.zip'
VENDOR_SHA256 = 'c8900f77f5db139dde7dc964e8667da330681688869e4fb2db42bc6b1df690f9'
MAX_UNPACKED = 64 * 1024 * 1024
MAX_FILE = 32 * 1024 * 1024
MAX_ENTRIES = 128
MAX_RATIO = 500
DOWNLOAD_SECONDS = 15
EXPAND_SECONDS = 10
D3DX_NAME = 'd3dx9_43.dll'
D3DX_BYTES = 1998168
D3DX_SHA256 = '0b28546be22c71834501f7d7185ede5d79742457331c7ee09efc14490dd64f5f'
CAB_NAME = 'byond/directx/Jun2010_d3dx9_43_x86.cab'
CAB_SHA256 = 'fcc6cf0966b4853d6fa3d32ab299cde5a9824feaecb0d4f34ea452fb9fd1c867'
_RUNTIME_NAMES = {'mfc140u.dll', 'vcruntime140.dll', 'msvcp140.dll'}
_LIMITATION = ('Static regular/delay import inspection and on-disk PE checks do not '
               'prove API-set resolution, dynamically loaded dependencies, graphics '
               'availability, WebView2 availability, or successful program startup.')


class PreflightError(RuntimeError):
    """Safe diagnostic containing no credentials, user paths, or raw tool output."""
    def __init__(self, code, details=()):
        self.code = code
        self.details = tuple(details)
        super().__init__(code + (': ' + ', '.join(self.details) if self.details else ''))


def _sha(data):
    return hashlib.sha256(data).hexdigest()


def _plain(path, directory=False):
    """Reject symlinks, Windows reparse points, and non-regular objects."""
    try:
        info = Path(path).lstat()
    except OSError:
        raise PreflightError('required_path_unavailable') from None
    wanted = stat.S_ISDIR if directory else stat.S_ISREG
    if not wanted(info.st_mode) or getattr(info, 'st_file_attributes', 0) & 0x400:
        raise PreflightError('non_plain_path')
    return info


def _plain_ancestors(path):
    for parent in [Path(path), *Path(path).parents]:
        _plain(parent, directory=True)


def _read(path, limit):
    info = _plain(path)
    if info.st_size > limit:
        raise PreflightError('file_size_limit')
    with Path(path).open('rb') as stream:
        data = stream.read(limit + 1)
    if len(data) > limit or len(data) != info.st_size:
        raise PreflightError('file_size_changed_or_exceeded')
    return data


def _vendor():
    raw = _read(Path(__file__).with_name('vendor.json'), 65536)
    if _sha(raw) != VENDOR_SHA256:
        raise PreflightError('vendor_manifest_hash_mismatch')
    return json.loads(raw)


def _relative(name, directory=False):
    if not isinstance(name, str) or not name or not name.isascii():
        raise PreflightError('unsafe_zip_name')
    if '\\' in name or ':' in name or '\x00' in name or name.startswith('/'):
        raise PreflightError('unsafe_zip_name')
    clean = name[:-1] if directory and name.endswith('/') else name
    if len(clean) > 240 or not clean:
        raise PreflightError('unsafe_zip_name')
    for part in clean.split('/'):
        if (not part or part in ('.', '..') or part.endswith((' ', '.')) or
                not re.fullmatch(r'[A-Za-z0-9_.-]+', part) or
                part.split('.')[0].upper() in {'CON', 'PRN', 'AUX', 'NUL',
                   *('COM' + str(n) for n in range(10)),
                   *('LPT' + str(n) for n in range(10))}):
            raise PreflightError('unsafe_zip_name')
    return clean


def _validate_archive(raw, manifest, *, expected_size=ARCHIVE_BYTES,
                      expected_sha256=ARCHIVE_SHA256):
    """Return fully checked bytes before any extraction. Test helper is offline."""
    if len(raw) != expected_size or _sha(raw) != expected_sha256:
        raise PreflightError('archive_size_or_hash_mismatch')
    expected = {entry['path']: entry for entry in manifest}
    if len(expected) != len(manifest):
        raise PreflightError('duplicate_manifest_path')
    directories = set()
    for name in expected:
        _relative(name)
        parts = name.split('/')
        directories.update('/'.join(parts[:n]) for n in range(1, len(parts)))
    contents = {}
    seen = set()
    total = 0
    try:
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            members = archive.infolist()
            if len(members) > MAX_ENTRIES:
                raise PreflightError('zip_entry_limit')
            for item in members:
                name = _relative(item.filename, item.is_dir())
                key = name.casefold()
                if key in seen:
                    raise PreflightError('duplicate_zip_name')
                seen.add(key)
                mode = item.external_attr >> 16
                kind = stat.S_IFMT(mode)
                if kind not in (0, stat.S_IFDIR if item.is_dir() else stat.S_IFREG) or item.external_attr & 0x400:
                    raise PreflightError('zip_special_file')
                if item.flag_bits & 1 or item.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
                    raise PreflightError('zip_unsupported_encoding')
                if item.is_dir():
                    if name not in directories or item.file_size != 0:
                        raise PreflightError('unexpected_zip_directory')
                    continue
                total += item.file_size
                if (item.file_size > MAX_FILE or total > MAX_UNPACKED or
                        item.file_size > MAX_RATIO * max(item.compress_size, 1)):
                    raise PreflightError('zip_expansion_limit')
                if name not in expected or item.file_size != expected[name]['bytes']:
                    raise PreflightError('zip_manifest_membership_or_size')
                with archive.open(item) as stream:
                    data = stream.read(item.file_size + 1)
                if len(data) != item.file_size or _sha(data) != expected[name]['sha256']:
                    raise PreflightError('zip_member_hash_mismatch')
                contents[name] = data
    except (zipfile.BadZipFile, EOFError, RuntimeError, OSError, ValueError) as exc:
        if isinstance(exc, PreflightError):
            raise
        raise PreflightError('invalid_zip') from None
    if set(contents) != set(expected):
        raise PreflightError('incomplete_zip_manifest')
    return contents


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise PreflightError('download_redirect_refused')


def _download_child(destination):
    """Exactly one request; defaults retain the configured proxy and verified TLS.

    The parent owns a hard wall-clock process timeout, including DNS/TLS/read.
    No cookies, auth handlers, source fallback, retries, or redirect following.
    """
    proxies = urllib.request.getproxies()
    for value in proxies.values():
        parsed = urllib.parse.urlsplit(value)
        if parsed.username is not None or parsed.password is not None:
            raise PreflightError('authenticated_proxy_not_authorized')
    opener = urllib.request.build_opener(urllib.request.ProxyHandler(proxies), _NoRedirect())
    request = urllib.request.Request(ARCHIVE_URL, headers={
        'User-Agent': 'BYOND-pinned-preflight/1', 'Accept-Encoding': 'identity'})
    deadline = time.monotonic() + DOWNLOAD_SECONDS
    with opener.open(request, timeout=DOWNLOAD_SECONDS) as response:
        if response.status != 200 or response.geturl() != ARCHIVE_URL:
            raise PreflightError('download_response_refused')
        length = response.headers.get('Content-Length')
        if length is not None and length != str(ARCHIVE_BYTES):
            raise PreflightError('download_length_refused')
        if response.headers.get('Content-Encoding', 'identity').lower() not in ('identity', ''):
            raise PreflightError('download_encoding_refused')
        size = 0
        digest = hashlib.sha256()
        with Path(destination).open('xb') as stream:
            while True:
                if time.monotonic() >= deadline:
                    raise PreflightError('download_deadline')
                chunk = response.read(min(65536, ARCHIVE_BYTES + 1 - size))
                if not chunk:
                    break
                size += len(chunk)
                if size > ARCHIVE_BYTES:
                    raise PreflightError('download_size_limit')
                digest.update(chunk)
                stream.write(chunk)
        if size != ARCHIVE_BYTES or digest.hexdigest() != ARCHIVE_SHA256:
            raise PreflightError('download_integrity_failure')


def _minimal_environment():
    allowed = {'SYSTEMROOT', 'WINDIR', 'TEMP', 'TMP', 'HTTPS_PROXY', 'HTTP_PROXY',
               'ALL_PROXY', 'NO_PROXY'}
    return {k: v for k, v in os.environ.items() if k.upper() in allowed}


def _run_bounded(argv, cwd, seconds, label):
    """Retain the launched process handle and reap it on success or failure."""
    process = None
    try:
        process = subprocess.Popen(argv, cwd=cwd, stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, shell=False,
            close_fds=True, env=_minimal_environment(),
            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        try:
            code = process.wait(timeout=seconds)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
            raise PreflightError(label + '_timeout') from None
        if code != 0:
            raise PreflightError(label + '_failed', (str(code),))
    except OSError:
        raise PreflightError(label + '_start_failed') from None
    finally:
        if process is not None and process.poll() is None:
            process.kill()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                raise PreflightError(label + '_cleanup_unconfirmed') from None


def _source_receipt():
    return {name: _sha(_read(Path(__file__).with_name(name), 262144))
            for name in ('acquire.py', 'inspect_package.py', 'vendor.json')}


def acquire(root, archive=None):
    """Create fresh root/byond and return (bin_path, receipt).

    root must be a task-owned plain directory, or a fresh child of an existing
    plain directory. No existing package or receipt is reused/overwritten. The archive argument selects a local exact
    pinned ZIP; otherwise the sole HTTPS source is fetched once, <=15 seconds.
    """
    root = Path(root).absolute()
    _plain_ancestors(root.parent)
    root.mkdir(exist_ok=True)
    _plain_ancestors(root)
    vendor = _vendor()
    package = root / 'byond'
    receipt_path = root / 'acquisition-receipt.json'
    if package.exists() or package.is_symlink() or receipt_path.exists() or receipt_path.is_symlink():
        raise PreflightError('fresh_package_and_receipt_required')
    stage = Path(tempfile.mkdtemp(prefix='.byond-acquire-', dir=root))
    package_created = False
    receipt_created = False
    try:
        source_kind = 'verified-local-archive' if archive is not None else 'pinned-https-download'
        if archive is None:
            local = stage / '516.1688_byond.zip'
            # -I avoids user site configuration. Explicit script directory import
            # is added only by the internal child bootstrap below.
            script = str(Path(__file__).resolve())
            _run_bounded([sys.executable, '-I', '-c',
                "import runpy,sys; sys.path.insert(0,sys.argv[1]); "
                "sys.argv=sys.argv[2:]; runpy.run_path(sys.argv[0],run_name='__main__')",
                str(Path(script).parent), script, '--download-child', str(local)],
                stage, DOWNLOAD_SECONDS, 'download')
            raw = _read(local, ARCHIVE_BYTES)
        else:
            raw = _read(Path(archive), ARCHIVE_BYTES)
        contents = _validate_archive(raw, vendor['files'])
        package.mkdir()
        package_created = True
        for name, data in contents.items():
            path = root.joinpath(*name.split('/'))
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open('xb') as stream:
                stream.write(data)
        receipt = {
            'schema': 1, 'version': '516.1688', 'source_kind': source_kind,
            'source_url': ARCHIVE_URL, 'archive_bytes': len(raw),
            'archive_sha256': _sha(raw), 'manifest_files': len(contents),
            'manifest_sha256': VENDOR_SHA256, 'source_sha256': _source_receipt(),
            'all_package_files_and_notices_preserved': True,
            'package_code_executed': False, 'installers_executed': False,
            'limitations': [_LIMITATION]}
        with receipt_path.open('x', encoding='utf-8') as stream:
            receipt_created = True
            stream.write(json.dumps(receipt, indent=2) + '\n')
        return package / 'bin', receipt
    except BaseException:
        # Remove only outputs created by this invocation, never the task root.
        if package_created:
            shutil.rmtree(package)
        if receipt_created:
            receipt_path.unlink()
        raise
    finally:
        shutil.rmtree(stage)


def _pe_x86(data):
    """Bounded header-only architecture inspection; never loads inspected data."""
    if len(data) < 64 or data[:2] != b'MZ':
        raise PreflightError('dependency_not_pe')
    pe = struct.unpack_from('<I', data, 0x3c)[0]
    if pe > len(data) - 26 or data[pe:pe + 4] != b'PE\0\0':
        raise PreflightError('dependency_not_pe')
    machine = struct.unpack_from('<H', data, pe + 4)[0]
    optsize = struct.unpack_from('<H', data, pe + 20)[0]
    magic = struct.unpack_from('<H', data, pe + 24)[0]
    if machine != 0x14c or magic != 0x10b or optsize < 96 or pe + 24 + optsize > len(data):
        raise PreflightError('dependency_not_x86_pe32')
    return {'machine': '0x014c', 'optional_header': 'PE32'}


def _verified_package(binpath, vendor):
    base = Path(binpath).parent.parent
    if Path(binpath).name != 'bin' or Path(binpath).parent.name != 'byond':
        raise PreflightError('unexpected_bin_location')
    _plain_ancestors(binpath)
    verified = {}
    for entry in vendor['files']:
        path = base.joinpath(*entry['path'].split('/'))
        _plain_ancestors(path.parent)
        data = _read(path, entry['bytes'])
        if len(data) != entry['bytes'] or _sha(data) != entry['sha256']:
            raise PreflightError('package_file_changed', (entry['path'],))
        if entry['path'].startswith('byond/bin/') and path.suffix.lower() in ('.exe', '.dll'):
            _pe_x86(data)
            try:
                imports = pe_imports(data)
            except (ValueError, struct.error, UnicodeError, IndexError):
                raise PreflightError('invalid_package_pe', (path.name,)) from None
            reviewed = vendor['binaries'][entry['path']]
            if imports != {key: reviewed[key] for key in ('machine', 'imports', 'delay_imports')}:
                raise PreflightError('package_imports_changed', (path.name,))
            verified[path.name.lower()] = dict(imports, sha256=entry['sha256'], bytes=len(data))
    expected_bin = {Path(entry['path']).name for entry in vendor['files']
                    if entry['path'].startswith('byond/bin/')}
    for path in Path(binpath).iterdir():
        if path.name not in expected_bin | {D3DX_NAME}:
            raise PreflightError('unexpected_bin_entry')
        _plain(path)
    return base, verified


def verify_files(root):
    """Rebind all 45 original files and PE/import metadata before a reviewed use.

    No network, process launch, extraction, or Windows API calls. The only
    permitted extra bin file is the independently pinned CAB-derived d3dx DLL.
    """
    root = Path(root).absolute()
    vendor = _vendor()
    _, verified = _verified_package(root / 'byond' / 'bin', vendor)
    d3dx = root / 'byond' / 'bin' / D3DX_NAME
    if d3dx.exists():
        raw = _read(d3dx, D3DX_BYTES)
        if len(raw) != D3DX_BYTES or _sha(raw) != D3DX_SHA256:
            raise PreflightError('app_local_d3dx_changed')
        _pe_x86(raw)
    return {'schema': 1, 'manifest_files': len(vendor['files']),
            'archive_sha256': ARCHIVE_SHA256, 'manifest_sha256': VENDOR_SHA256,
            'binaries': {name: entry['sha256'] for name, entry in sorted(verified.items())},
            'package_code_executed': False}


def _windows_root():
    if os.name != 'nt':
        raise PreflightError('windows_dependency_check_required')
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    get_directory = kernel.GetWindowsDirectoryW
    get_directory.argtypes = [ctypes.c_wchar_p, ctypes.c_uint]
    get_directory.restype = ctypes.c_uint
    buffer = ctypes.create_unicode_buffer(32768)
    count = get_directory(buffer, len(buffer))
    if not 0 < count < len(buffer):
        raise PreflightError('windows_directory_unavailable')
    root = Path(buffer.value)
    _plain_ancestors(root)
    return root


def _static_needs(verified):
    selected = set()
    regular = set()
    delayed = set()
    pending = ['dreamseeker.exe', 'dd.exe', 'dm.exe']
    while pending:
        name = pending.pop()
        if name in selected:
            continue
        selected.add(name)
        current = verified[name]
        for kind in ('imports', 'delay_imports'):
            for dependency in current[kind]:
                if dependency in verified:
                    pending.append(dependency)
                else:
                    (regular if kind == 'imports' else delayed).add(dependency)
    api_sets = {name for name in regular if name.startswith('api-ms-win-crt-')}
    # API-set names are virtual contracts, not reliably individual disk files.
    regular -= api_sets
    regular.add('ucrtbase.dll')
    # d3d9 is the graphics delay import needed by this rendering task. Steam's
    # optional delay imports remain explicitly unresolved, never silently passed.
    if 'd3d9.dll' in delayed:
        regular.add('d3d9.dll')
    regular |= _RUNTIME_NAMES
    return selected, regular, delayed, api_sets


def _extract_d3dx(base, binpath, windows_root):
    cab = base.joinpath(*CAB_NAME.split('/'))
    if _sha(_read(cab, 768036)) != CAB_SHA256:
        raise PreflightError('cab_integrity_failure')
    expand = windows_root / 'System32' / 'expand.exe'
    tool = _read(expand, MAX_FILE)
    # Installed Windows tool only, never a PATH lookup or package executable.
    if len(tool) < 64 or tool[:2] != b'MZ':
        raise PreflightError('installed_expand_unavailable')
    stage = Path(tempfile.mkdtemp(prefix='.cab-data-', dir=base))
    try:
        _run_bounded([str(expand), '-F:' + D3DX_NAME, str(cab), str(stage)],
                     stage, EXPAND_SECONDS, 'cab_expand')
        outputs = list(stage.iterdir())
        if len(outputs) != 1 or outputs[0].name.casefold() != D3DX_NAME:
            raise PreflightError('cab_unexpected_output')
        data = _read(outputs[0], D3DX_BYTES)
        if len(data) != D3DX_BYTES or _sha(data) != D3DX_SHA256:
            raise PreflightError('cab_dll_integrity_failure')
        _pe_x86(data)
        with (Path(binpath) / D3DX_NAME).open('xb') as stream:
            stream.write(data)
        return {'tool': 'installed-windows-expand.exe', 'tool_sha256': _sha(tool),
                'cab_sha256': CAB_SHA256, 'bytes': len(data),
                'dll_sha256': _sha(data), 'data_extraction_only': True,
                'process_handle_reaped': True}
    finally:
        shutil.rmtree(stage)


def _check_dependencies(binpath, windows_root, *, allow_cab_extraction):
    vendor = _vendor()
    binpath = Path(binpath).absolute()
    base, verified = _verified_package(binpath, vendor)
    selected, needed, delayed, api_sets = _static_needs(verified)
    windows_root = Path(windows_root)
    _plain_ancestors(windows_root)
    system = windows_root / 'SysWOW64'
    if not system.exists():
        system = windows_root / 'System32'
    _plain_ancestors(system)
    resolved = {}
    missing = []
    for name in sorted(needed):
        path = binpath / name if name == D3DX_NAME and (binpath / name).exists() else system / name
        if not path.exists():
            missing.append(name)
            continue
        try:
            raw = _read(path, MAX_FILE)
            header = _pe_x86(raw)
            if path.parent == binpath and (len(raw) != D3DX_BYTES or _sha(raw) != D3DX_SHA256):
                raise PreflightError('app_local_d3dx_changed')
        except PreflightError as exc:
            raise PreflightError(exc.code, (name,)) from None
        resolved[name] = dict(header, bytes=len(raw), sha256=_sha(raw),
                             location='package-bin' if path.parent == binpath else 'windows-x86-system')
    blockers = sorted(set(missing) - {D3DX_NAME})
    if blockers:
        raise PreflightError('missing_x86_dependencies_no_install_attempted', blockers)
    cab_receipt = None
    if D3DX_NAME in missing:
        if not allow_cab_extraction:
            raise PreflightError('missing_x86_dependencies', (D3DX_NAME,))
        cab_receipt = _extract_d3dx(base, binpath, windows_root)
        resolved[D3DX_NAME] = {'machine': '0x014c', 'optional_header': 'PE32',
            'bytes': D3DX_BYTES, 'sha256': D3DX_SHA256, 'location': 'package-bin'}
    unresolved_delay = sorted(delayed - set(resolved))
    return {'schema': 1, 'kind': 'static-dependency-preflight',
            'package_archive_sha256': ARCHIVE_SHA256,
            'manifest_sha256': VENDOR_SHA256, 'source_sha256': _source_receipt(),
            'package_binaries': {name: verified[name] for name in sorted(selected)},
            'resolved_x86_dependencies': resolved,
            'ucrt_api_set_contracts_not_individually_resolved': sorted(api_sets),
            'unresolved_delay_imports': unresolved_delay,
            'cab_extraction': cab_receipt, 'package_code_executed': False,
            'installers_executed': False, 'runtime_validation': 'not_performed',
            'limitations': [_LIMITATION]}


def _write_dependency_receipt(binpath, receipt):
    root = Path(binpath).absolute().parent.parent
    _plain_ancestors(root)
    try:
        with (root / 'dependency-receipt.json').open('x', encoding='utf-8') as stream:
            stream.write(json.dumps(receipt, indent=2) + '\n')
    except OSError:
        raise PreflightError('dependency_receipt_write_failed') from None


def check_dependencies(binpath):
    """Verify pinned package and installed x86 dependencies, or raise exact missing.

    No runtime installation. A missing d3dx9_43.dll alone can be supplied by the
    exact bundled CAB; all VC/MFC/UCRT/OS blockers stop before that data extraction.
    Write root/dependency-receipt.json on success or concrete preflight failure.
    The returned receipt is static evidence, not permission to launch binaries.
    """
    try:
        receipt = _check_dependencies(binpath, _windows_root(), allow_cab_extraction=True)
    except PreflightError as exc:
        failure = {'schema': 1, 'kind': 'static-dependency-preflight',
                   'status': 'blocked', 'error': exc.code, 'details': list(exc.details),
                   'package_code_executed': False, 'installers_executed': False,
                   'runtime_validation': 'not_performed', 'limitations': [_LIMITATION]}
        _write_dependency_receipt(binpath, failure)
        raise
    receipt['status'] = 'static-checks-passed-with-stated-limitations'
    _write_dependency_receipt(binpath, receipt)
    return receipt


def _write_acquisition_failure(root, failure):
    """Retain a bounded diagnostic only inside the validated existing task root."""
    root = Path(root)
    if not root.is_absolute():
        raise PreflightError('failure_receipt_root_not_absolute')
    if '..' in root.parts:
        raise PreflightError('failure_receipt_root_not_canonical')
    _plain_ancestors(root)
    # PreflightError fields originate in this module; filter nonetheless so a
    # later caller cannot cause path/secret/control-character disclosure here.
    code = failure.code
    if not re.fullmatch(r'[a-z0-9_]{1,96}', code):
        code = 'preflight_error'
    details = []
    for detail in failure.details[:64]:
        if (isinstance(detail, str) and len(detail) <= 160 and
                re.fullmatch(r'[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*', detail) and
                all(part not in ('.', '..') for part in detail.split('/'))):
            details.append(detail)
    receipt = {'schema': 1, 'kind': 'acquisition-failure', 'status': 'blocked',
               'error': code, 'details': details,
               'archive_sha256': ARCHIVE_SHA256, 'manifest_sha256': VENDOR_SHA256,
               'package_code_executed': False, 'installers_executed': False}
    raw = (json.dumps(receipt, indent=2) + '\n').encode('utf-8')
    if len(raw) > 8192:
        raise PreflightError('failure_receipt_size_limit')
    try:
        with (root / 'acquisition-failure.json').open('xb') as stream:
            stream.write(raw)
    except OSError:
        raise PreflightError('failure_receipt_write_failed') from None


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--download-child':
        try:
            _vendor()
            _download_child(Path(sys.argv[2]))
        except (PreflightError, OSError, ValueError):
            raise SystemExit(2) from None
    else:
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument('--root', type=Path, required=True)
        parser.add_argument('--archive', type=Path)
        args = parser.parse_args()
        if not args.root.is_absolute():
            parser.error('--root must be an absolute task-owned directory')
        try:
            _, result = acquire(args.root, args.archive)
            print(json.dumps(result, sort_keys=True))
        except PreflightError as exc:
            retained = False
            receipt_error = None
            try:
                _write_acquisition_failure(args.root, exc)
                retained = True
            except PreflightError as write_error:
                receipt_error = write_error.code
            print(json.dumps({'error': exc.code, 'details': exc.details,
                              'failure_receipt_retained': retained,
                              'receipt_error': receipt_error}), file=sys.stderr)
            raise SystemExit(2) from None
