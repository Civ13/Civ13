"""Prepare pinned Microsoft x86 DLLs as data only; never install or load them.

Not wired to a workflow. Requires separately approved manual hosted preparation.
Existing BYOND acquisition, execution and socket guards are deliberately untouched.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import time
import urllib.request
import zipfile

from dependency_audit import admit_source, pe_imports, require

ROOT = Path(__file__).resolve().parents[2]
PIN_PATH = ROOT / 'tools/byond/d3dx-package.json'
PACKAGE_URL = ('https://api.nuget.org/v3-flatcontainer/microsoft.dxsdk.d3dx/'
               '9.29.952.8/microsoft.dxsdk.d3dx.9.29.952.8.nupkg')
D3DX = 'build/native/release/bin/x86/D3DX9_43.dll'
COMPILER = 'build/native/release/bin/x86/D3DCompiler_43.dll'
LEGAL = ('LICENSE.txt', 'NOTICE.md', '.signature.p7s')
CAP = 16 * 1024**2
REPORT_CAP = 128 * 1024


def sha256(raw):
    return hashlib.sha256(raw).hexdigest()


def load_pin():
    pin = json.loads(PIN_PATH.read_text(encoding='utf-8'))
    require((pin['id'], pin['version'], pin['url'], pin['bytes']) ==
            ('Microsoft.DXSDK.D3DX', '9.29.952.8', PACKAGE_URL, 9833468), 'Review package pin advance')
    require(re.fullmatch('[0-9a-f]{128}', pin['sha512']) is not None, 'Expected SHA512 pin')
    require(set(pin['entries']) == {D3DX, COMPILER, *LEGAL}, 'Exact selected metadata')
    require(pin['byond']['version'] == '516.1688' and len(pin['byond']['files']) == 13, 'Original BYOND binding')
    return pin


def check_time(deadline):
    require(time.monotonic() < deadline, 'Data preparation deadline')


def plain(path, boundary):
    """Reject links/reparse points in every existing component before resolution."""
    path, boundary = Path(path).absolute(), Path(boundary).absolute()
    require(path.is_relative_to(boundary), 'Path outside disposable runner temp')
    current = path
    while True:
        info = current.lstat()
        require(not stat.S_ISLNK(info.st_mode) and not getattr(info, 'st_file_attributes', 0) & 0x400,
                'Linked or reparse component')
        if current == boundary:
            break
        current = current.parent
    return path.resolve()


def byond_snapshot(binary, pin, deadline):
    """Flat, exact 13-file snapshot; no provider search and no BYOND mutation."""
    binary = Path(binary)
    entries = list(binary.iterdir())
    require(len(entries) == 13 and {p.name for p in entries} == set(pin['byond']['files']), 'BYOND inventory drift')
    facts = {}
    for path in entries:
        check_time(deadline)
        info = path.lstat()
        require(stat.S_ISREG(info.st_mode) and not getattr(info, 'st_file_attributes', 0) & 0x400,
                'Nonregular BYOND input')
        expected = pin['byond']['files'][path.name]
        require(info.st_size == expected['bytes'] and info.st_size <= 8*1024**2, 'BYOND size drift')
        raw = path.read_bytes()
        after = path.stat()
        require((info.st_size, info.st_mtime_ns) == (after.st_size, after.st_mtime_ns), 'BYOND changed while read')
        facts[path.name] = dict(bytes=len(raw), sha256=sha256(raw))
        require(facts[path.name] == expected, 'BYOND hash drift: '+path.name)
    return facts


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        raise ValueError('Microsoft package redirects are not authorized')


def fetch_package(path, pin, deadline):
    """One exact HTTPS URL, no proxy/credentials, redirect, retry or alternate source."""
    require(pin['url'] == PACKAGE_URL, 'Exact Microsoft URL only')
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    request = urllib.request.Request(PACKAGE_URL, headers={'User-Agent': 'Civ13-data-preparation'})
    with opener.open(request, timeout=20) as response, Path(path).open('xb') as stream:
        require(response.status == 200 and response.geturl() == PACKAGE_URL, 'Exact package response')
        length = response.headers.get('Content-Length')
        require(length is None or length == str(pin['bytes']), 'Package Content-Length drift')
        size = 0
        while True:
            check_time(deadline)
            chunk = response.read(65536)
            if not chunk:
                break
            size += len(chunk)
            require(size <= pin['bytes'], 'Package byte ceiling')
            stream.write(chunk)
    verify_package(path, pin)  # Before ZipFile or decompression.


def verify_package(path, pin):
    require(Path(path).stat().st_size == pin['bytes'], 'Package size mismatch')
    raw = Path(path).read_bytes()
    require(len(raw) == pin['bytes'] and hashlib.sha512(raw).hexdigest() == pin['sha512'],
            'Official catalog SHA512 mismatch')
    return dict(bytes=len(raw), sha512=hashlib.sha512(raw).hexdigest(), sha256=sha256(raw))


def safe_member(name):
    require(name and len(name) <= 240 and not re.search(r'[\x00-\x1f\\:*?<>|\"]', name) and not name.startswith('/'), 'Unsafe ZIP path')
    parts = name.rstrip('/').split('/')
    require(all(p not in ('', '.', '..') and p.rstrip(' .') == p and
                not re.match(r'(?i)^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)', p)
                for p in parts), 'Unsafe ZIP component')
    require(not PurePosixPath(name).is_absolute(), 'Absolute ZIP path')
    return name.rstrip('/').casefold()


def archive_index(archive, pin):
    infos = archive.infolist()
    require(0 < len(infos) <= 128, 'ZIP entry count bound')
    index, seen = {}, set()
    for info in infos:
        key = safe_member(info.filename)
        require(key not in seen, 'Duplicate ZIP member'); seen.add(key)
        kind = stat.S_IFMT(info.external_attr >> 16)
        require(kind in (0, stat.S_IFREG, stat.S_IFDIR) and not info.flag_bits & 1 and not info.external_attr & 0x400,
                'Linked, special or encrypted ZIP member')
        require(info.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED), 'ZIP compression method')
        index[info.filename] = info
    for name, expected in pin['entries'].items():
        require(name in index and not index[name].is_dir(), 'Missing selected ZIP member')
        info = index[name]
        require(info.file_size == expected['bytes'] and info.compress_size == expected['compressed_bytes'],
                'Catalog member metadata drift')
    return index


def read_member(archive, info, deadline):
    check_time(deadline)
    require(0 < info.file_size <= 3*1024**2, 'Selected member bound')
    with archive.open(info) as stream:
        raw = stream.read(info.file_size+1)
        require(len(raw) == info.file_size and stream.read(1) == b'', 'ZIP member length/CRC')
    check_time(deadline)
    return raw


def stage_members(package, output, pin, deadline):
    """Only approved x86 files and legal data. No extractall/targets/installation."""
    package_facts = verify_package(package, pin)
    selected = Path(output)/'selected'
    selected.mkdir()
    facts = {}
    with zipfile.ZipFile(package) as archive:
        index = archive_index(archive, pin)
        d3dx = read_member(archive, index[D3DX], deadline)
        image = pe_imports(d3dx)
        require((image['machine'], image['format']) == (0x14c, 'PE32'), 'D3DX must be x86 PE32')
        compiler_edges = [i for i in image['imports'] if i['name'].casefold() == 'd3dcompiler_43.dll']
        admitted = {D3DX: d3dx}
        # A normal or delay import is concrete evidence for the companion.
        # Dynamic LoadLibrary is intentionally not inferred or exercised.
        if compiler_edges:
            admitted[COMPILER] = read_member(archive, index[COMPILER], deadline)
        admitted.update({name: read_member(archive, index[name], deadline) for name in LEGAL})
        for name, raw in admitted.items():
            relative = ('x86/' if name not in LEGAL else 'licenses/')+PurePosixPath(name).name
            target = selected/relative
            target.parent.mkdir(exist_ok=True)
            with target.open('xb') as stream:
                stream.write(raw)
            fact = dict(bytes=len(raw), sha256=sha256(raw), member=name, path='selected/'+relative)
            if name not in LEGAL:
                fact['pe'] = pe_imports(raw)
                require((fact['pe']['machine'], fact['pe']['format']) == (0x14c, 'PE32'), 'Companion must be x86 PE32')
            facts[relative] = fact
    return dict(package=package_facts, files=facts, compiler_import_edges=compiler_edges,
                compiler_included=bool(compiler_edges), dynamic_dependencies_not_resolved=True)


def signature_file(path, deadline):
    check_time(deadline)
    shell = Path(os.environ['SystemRoot'])/'System32/WindowsPowerShell/v1.0/powershell.exe'
    result = subprocess.run([str(shell), '-NoLogo', '-NoProfile', '-NonInteractive', '-File',
                             str(Path(__file__).with_name('d3dx-signature.ps1')), '-LiteralFile', str(path)],
                            capture_output=True, timeout=min(20, max(.1, deadline-time.monotonic())))
    require(len(result.stdout)+len(result.stderr) <= 32768, 'Signature output bound')
    require(result.returncode == 0, 'Signature metadata command failed')
    return json.loads(result.stdout.decode('utf-8-sig').strip())


def validate_signature(fact):
    require(fact['status'] == 'Valid' and fact['signature_type'] == 'Authenticode', 'Valid embedded signature required')
    signer = fact['signer']
    require(signer and signer['simple_name'] == 'Microsoft Corporation' and
            re.search(r'(?:^|,\s*)O=Microsoft Corporation(?:,|$)', signer['subject']) and
            re.fullmatch('[0-9a-f]{64}', signer['certificate_sha256']) and
            fact.get('timestamp') is not None, 'Microsoft signer and timestamp required')


def census(output):
    paths = list(Path(output).rglob('*'))
    require(len(paths) <= 16, 'Retained entry count bound')
    total = 0
    for path in paths:
        info = path.lstat()
        require(not stat.S_ISLNK(info.st_mode) and not getattr(info, 'st_file_attributes', 0) & 0x400,
                'Linked output')
        if path.is_file():
            total += info.st_size
    require(total <= CAP, '16 MiB retained data bound')
    return total


def persist(output, report):
    raw = (json.dumps(report, indent=2, sort_keys=True)+'\n').encode()
    require(len(raw) <= REPORT_CAP, 'Report size bound')
    require(census(output)+len(raw) <= CAP, 'Final report retention reserve')
    (Path(output)/'preparation.json').write_bytes(raw)
    census(output)


def prepare(source, binary, output):
    began = time.monotonic()
    admit_source(source, os.environ, os.name)
    require(os.environ.get('D3DX_DATA_PREPARE') == 'approved-data-only', 'Explicit data-only mode required')
    temporary = Path(os.environ['RUNNER_TEMP']).absolute()
    output = Path(output).absolute()
    require(output == temporary/'tree-d3dx-data', 'Exact new owned preparation output')
    plain(temporary, temporary)
    binary = plain(binary, temporary)
    require(not output.exists() and not binary.is_relative_to(output) and not output.is_relative_to(binary),
            'Output must be new and separate from original BYOND')
    pin = load_pin()
    output.mkdir()
    report = dict(source=source, status='failed', native_ready=False, native_executed=False,
                  software_installed=False, package_url=PACKAGE_URL, byond_preserved=False,
                  trust_scope='Existing OS Authenticode validation; no trust/revocation policy changes. May require OS trust metadata network access.',
                  limits=dict(seconds=240, outer_job_seconds=300, retained_bytes=CAP), error=None)
    original = None
    try:
        original = byond_snapshot(binary, pin, began+240)
        report['byond_before'] = original
        fetch_package(output/'package.nupkg', pin, began+120)
        require(census(output) <= CAP-REPORT_CAP, 'Extraction reserve')
        report['staging'] = stage_members(output/'package.nupkg', output, pin, began+240)
        for fact in report['staging']['files'].values():
            if 'pe' not in fact:
                continue
            file = output/fact['path']
            signature = signature_file(file, began+240)
            fact['signature'] = signature  # Retain unsuccessful trust facts too.
            validate_signature(signature)
            require(sha256(file.read_bytes()) == fact['sha256'], 'DLL changed during signature check')
        for fact in report['staging']['files'].values():
            file = output/fact['path']
            require(file.stat().st_size == fact['bytes'] and sha256(file.read_bytes()) == fact['sha256'],
                    'Selected file changed before final binding')
        require(verify_package(output/'package.nupkg', pin) == report['staging']['package'], 'Package changed before final binding')
        check_time(began+240)
        report['status'] = 'completed_data_preparation'
    except Exception as error:
        report['error'] = str(error)[:2048]
    finally:
        try:
            after = byond_snapshot(binary, pin, began+270)
            report['byond_after'] = after
            report['byond_preserved'] = original is not None and original == after
            require(report['byond_preserved'], 'Original BYOND not verified unchanged')
        except Exception as error:
            report.update(status='failed', preservation_error=str(error)[:2048])
        report['elapsed_seconds'] = time.monotonic()-began
        persist(output, report)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True)
    parser.add_argument('--input-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--acquire-data', action='store_true', required=True)
    arguments = parser.parse_args()
    result = prepare(arguments.source, arguments.input_bin, arguments.output)
    print(json.dumps(dict(status=result['status'], native_ready=False)))
    raise SystemExit(0 if result['status'] == 'completed_data_preparation' else 1)
