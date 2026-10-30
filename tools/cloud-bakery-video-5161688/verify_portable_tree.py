"""Check the entire pinned portable distribution without executing it."""
import hashlib
import json
import os
import stat
from pathlib import Path

MANIFEST_SHA = 'e563f015220d49397a1f80651ef165faca4616d84a6bfa3656f21bf7ddfe7b0e'


def verify(root, manifest, check_budget=None):
    check_budget = check_budget or (lambda: None)
    root = Path(root).absolute()
    for directory in (root, *root.parents):
        info = directory.lstat()
        if not stat.S_ISDIR(info.st_mode) or getattr(info, 'st_file_attributes', 0) & 0x400:
            raise ValueError('unsafe_ancestor')
    raw = Path(manifest).read_bytes()
    if hashlib.sha256(raw).hexdigest() != MANIFEST_SHA:
        raise ValueError('manifest_identity')
    rows = json.loads(raw)
    if type(rows) is not list or len(rows) != 224:
        raise ValueError('manifest_count')
    expected = {row['name']: row for row in rows}
    if len(expected) != len(rows):
        raise ValueError('duplicate_manifest')
    seen = set()
    for directory, names, files in os.walk(root, followlinks=False):
        check_budget()
        parent = Path(directory)
        for name in names + files:
            item = parent / name
            info = item.lstat()
            if item.is_symlink() or getattr(info, 'st_file_attributes', 0) & 0x400:
                raise ValueError('reparse_point')
        for name in files:
            check_budget()
            path = parent / name
            key = path.relative_to(root).as_posix()
            row = expected.get(key)
            info = path.lstat()
            if not row or not stat.S_ISREG(info.st_mode) or info.st_size != row['bytes']:
                raise ValueError('unexpected_file')
            h = hashlib.sha256()
            with path.open('rb') as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b''):
                    check_budget()
                    h.update(block)
            if h.hexdigest() != row['sha256']:
                raise ValueError('file_hash')
            seen.add(key)
    if seen != set(expected):
        raise ValueError('missing_file')
    return {'files': len(seen), 'manifest_sha256': MANIFEST_SHA}
