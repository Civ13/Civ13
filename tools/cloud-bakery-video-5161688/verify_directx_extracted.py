"""Verify already-extracted official DirectX files; never run the installer."""
import hashlib
import json
import stat
import sys
from pathlib import Path

MANIFEST_SHA256 = 'd5d7c9dc1e6118b81b28e836e4fce6bc28a4735c5069d17e5b2a3ae04b2b24c8'


def verify(directory, manifest, check_budget=None):
    check_budget = check_budget or (lambda: None)
    directory = Path(directory)
    raw = Path(manifest).read_bytes()
    if hashlib.sha256(raw).hexdigest() != MANIFEST_SHA256:
        raise ValueError('manifest_identity')
    rows = json.loads(raw)
    if not isinstance(rows, list) or len(rows) != 157:
        raise ValueError('manifest_count')
    expected = {}
    for row in rows:
        name = row['name']
        if not name.isascii() or Path(name).name != name or any(c in name for c in '\\/:'):
            raise ValueError('unsafe_name')
        if name.casefold() in expected:
            raise ValueError('duplicate_name')
        expected[name.casefold()] = row
    info = directory.lstat()
    if not stat.S_ISDIR(info.st_mode) or getattr(info, 'st_file_attributes', 0) & 0x400:
        raise ValueError('unsafe_directory')
    entries = list(directory.iterdir())
    if len(entries) != len(expected):
        raise ValueError('file_count')
    total = 0
    for path in entries:
        check_budget()
        row = expected.get(path.name.casefold())
        info = path.lstat()
        if not row or path.name != row['name'] or not stat.S_ISREG(info.st_mode) or getattr(info, 'st_file_attributes', 0) & 0x400:
            raise ValueError('unexpected_or_linked_file')
        if info.st_size != row['bytes']:
            raise ValueError('file_size:' + path.name)
        h = hashlib.sha256()
        with path.open('rb') as handle:
            for block in iter(lambda: handle.read(1024 * 1024), b''):
                check_budget()
                h.update(block)
        if h.hexdigest() != row['sha256']:
            raise ValueError('file_hash:' + path.name)
        total += info.st_size
    return {'files': len(entries), 'bytes': total, 'executed': False,
            'authenticode_checked_by_this_script': False}


if __name__ == '__main__':
    print(json.dumps(verify(sys.argv[1], sys.argv[2]), indent=2))
