"""Held acquisition of only the pinned Microsoft NuGet runtime package."""
import hashlib
import json
import re
import shutil
import stat
import time
from pathlib import Path
import zipfile

import acquire
import nuget_pins as pins
from prepare_official_toolchain import fetch, record_failure, require, WORK_SECONDS

PREPARE_NUGET_ENABLED = True
NUGET_LICENSE_ACCEPTED = True
NUGET_ENTRIES = 63
NUGET_UNPACKED_BYTES = 23308709


class NugetMemberError(RuntimeError):
    def __init__(self, component):
        super().__init__('nuget_member_identity')
        self.component = component


def inspect_package(archive, destination, check_budget):
    archive, destination = Path(archive).absolute(), Path(destination).absolute()
    acquire._plain_ancestors(archive.parent)
    acquire._plain_ancestors(destination.parent)
    require(archive.parent == destination.parent, 'nuget_destination_scope')
    require(not destination.exists() and not destination.is_symlink(), 'fresh_nuget_destination_required')
    raw = acquire._read(archive, pins.PACKAGE_BYTES)
    require(len(raw) == pins.PACKAGE_BYTES and acquire._sha(raw) == pins.PACKAGE_SHA256,
            'nuget_archive_identity')
    del raw
    selected = {row['member']: (name, row['bytes'], row['sha256']) for name, row in pins.FILES.items()}
    selected.update({'LICENSE.txt': ('LICENSE.txt', pins.LICENSE_BYTES, pins.LICENSE_SHA256),
                     'NOTICE.md': ('NOTICE.md', pins.NOTICE_BYTES, pins.NOTICE_SHA256)})
    with zipfile.ZipFile(archive) as z:
        infos = z.infolist()
        require(len(infos) == NUGET_ENTRIES and sum(i.file_size for i in infos) == NUGET_UNPACKED_BYTES, 'nuget_archive_bounds')
        names = set()
        for i in infos:
            check_budget()
            parts = i.filename.rstrip('/').split('/')
            require(all(p and p not in ('.', '..') and p.isascii() and '\\' not in p and ':' not in p
                        and not p.endswith(('.', ' ')) for p in parts), 'nuget_unsafe_path')
            require(i.filename.casefold() not in names and not stat.S_ISLNK((i.external_attr >> 16) & 0xffff),
                    'nuget_alias_or_link')
            names.add(i.filename.casefold())
            require(i.file_size <= 8*1024**2 and (not i.file_size or
                    (i.compress_size and i.file_size <= 500*i.compress_size)), 'nuget_member_bounds')
        require(all(name.casefold() in names for name in selected), 'nuget_required_member_missing')
        require('.signature.p7s' in names, 'nuget_package_signature_missing')
        destination.mkdir()
        result = {}
        for member, (name, size, digest) in selected.items():
            check_budget()
            data = z.read(member)
            if len(data) != size or hashlib.sha256(data).hexdigest() != digest:
                raise NugetMemberError(name)
            if name.endswith('.dll'):
                acquire._pe_x86(data)
            with (destination/name).open('xb') as stream:
                stream.write(data)
            result[name] = {'bytes': size, 'sha256': digest}
    return result


def prepare(root):
    require(PREPARE_NUGET_ENABLED is True and NUGET_LICENSE_ACCEPTED is True, 'nuget_prepare_held')
    from activation import require_runtime
    context = require_runtime()
    root = Path(root).absolute()
    acquire._plain_ancestors(root)
    package_root = root/'official-nuget'
    require(not package_root.exists() and not package_root.is_symlink(), 'fresh_nuget_root_required')
    package_root.mkdir()
    result = {'schema': 1, 'binding': context, 'status': 'FAILED', 'package_code_executed': False}
    deadline = time.monotonic() + WORK_SECONDS
    def budget(): require(time.monotonic() < deadline, 'acquisition_timeout')
    try:
        require(shutil.disk_usage(root).free >= 1024**3, 'toolchain_disk_reserve')
        package = package_root/'Microsoft.DXSDK.D3DX.9.29.952.8.nupkg'
        result['nuget_download'] = fetch(pins.PACKAGE_URL, package, pins.PACKAGE_BYTES, pins.PACKAGE_SHA256,
                                         {'www.nuget.org','globalcdn.nuget.org'}, deadline)
        result['nuget_files'] = inspect_package(package, package_root/'selected', budget)
        budget()
        result['status'] = 'PASSED'
    except Exception as error:
        record_failure(result, error)
        if isinstance(error, NugetMemberError):
            result['component'] = error.component
        raise
    finally:
        data=(json.dumps(result,sort_keys=True)+'\n').encode()
        require(len(data)<=16384, 'nuget_preparation_receipt_oversize')
        with (root/'nuget-preparation-receipt.json').open('xb') as stream:
            stream.write(data)
    return result


if __name__ == '__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,required=True);args=parser.parse_args()
    print(json.dumps(prepare(args.root),sort_keys=True))
