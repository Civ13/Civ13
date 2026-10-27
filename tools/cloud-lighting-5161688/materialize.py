"""Export exact Git blobs, never checkout/archive line-ending conversions.

The bootstrap may be read from a normal Windows checkout, but it reads every
materialized byte from the admitted object database. No vendor code is executed.
A single retained cat-file process handles both small tooling and full scene trees.
"""
import argparse
import hashlib
from pathlib import Path
import re
import subprocess

MAX_FILES = 10000
MAX_BLOB = 64 * 1024**2
MAX_TOTAL = 1024**3
HEX = re.compile(r'[0-9a-f]{40}')


def _plain_ancestors(path):
    for part in (path, *path.parents):
        if part.is_symlink() or getattr(part, 'is_junction', lambda: False)():
            raise ValueError('Symlink/reparse materialization path rejected')
        if part.exists() and not part.is_dir():
            raise ValueError('Non-directory materialization ancestor')


def _relative(name):
    parts = name.split('/')
    reserved = {'CON', 'PRN', 'AUX', 'NUL'} | {p+str(n) for p in ('COM', 'LPT') for n in range(1,10)}
    if (not name or any(not p or p.casefold() in ('.','..','.git') or p.endswith(('.', ' ')) or
            any(ord(c) < 32 or c in '\\<>:"|?*' for c in p) or
            p.split('.')[0].upper() in reserved for p in parts)):
        raise ValueError('Unsafe Git source path')
    return name


def export_blobs(repository, revision, destination, paths, expected=None):
    repository, destination = Path(repository).absolute(), Path(destination).absolute()
    if not HEX.fullmatch(revision):
        raise ValueError('Exact 40-hex Git revision required')
    _plain_ancestors(destination)
    if destination.exists() or destination.is_symlink():
        raise ValueError('Fresh raw-blob destination required')
    if not paths or any(_relative(p) != p for p in paths):
        raise ValueError('Explicit Git source paths required')
    raw_tree = subprocess.check_output(['git','-C',str(repository),'ls-tree','-rz',
                                       '--full-tree',revision,'--',*paths], timeout=15)
    if len(raw_tree) > 2*1024**2 or not raw_tree.endswith(b'\0'):
        raise ValueError('Empty/oversized or malformed Git tree')
    entries, aliases = {}, {}
    for raw in raw_tree[:-1].split(b'\0'):
        metadata, name = raw.split(b'\t', 1)
        mode, kind, oid = metadata.decode('ascii').split(' ')
        name = _relative(name.decode('utf-8'))
        if mode not in ('100644','100755') or kind != 'blob' or not HEX.fullmatch(oid):
            raise ValueError('Only exact regular Git blobs are admitted')
        if name in entries:
            raise ValueError('Duplicate Git path')
        parts = name.split('/')
        for index in range(1, len(parts)+1):
            prefix = '/'.join(parts[:index])
            identity = (prefix, index == len(parts))
            key = prefix.casefold()
            if key in aliases and aliases[key] != identity:
                raise ValueError('Case-aliased or file/directory Git path')
            aliases[key] = identity
        entries[name] = oid
    if not entries or len(entries) > MAX_FILES or (expected is not None and entries != expected):
        raise ValueError('Git blob manifest membership/identity mismatch')
    destination.mkdir()
    child = subprocess.Popen(['git','-C',str(repository),'cat-file','--batch'],
                             stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                             stderr=subprocess.DEVNULL)
    total = 0
    try:
        for name, oid in entries.items():
            child.stdin.write(oid.encode('ascii')+b'\n'); child.stdin.flush()
            header = child.stdout.readline(128)
            fields = header.rstrip(b'\n').split(b' ')
            if (not header.endswith(b'\n') or len(fields) != 3 or
                    fields[0] != oid.encode('ascii') or fields[1] != b'blob' or
                    not re.fullmatch(rb'0|[1-9][0-9]*', fields[2])):
                raise ValueError('Unexpected cat-file identity/type/framing')
            size = int(fields[2]); total += size
            if size > MAX_BLOB or total > MAX_TOTAL:
                raise ValueError('Raw Git source byte bound exceeded')
            data = child.stdout.read(size)
            if len(data) != size or child.stdout.read(1) != b'\n':
                raise ValueError('Truncated or incorrectly framed Git blob')
            actual = hashlib.sha1(('blob %d\0' % size).encode('ascii')+data).hexdigest()
            if actual != oid:
                raise ValueError('Canonical Git blob SHA-1 mismatch')
            target = destination.joinpath(*name.split('/'))
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open('xb') as stream:
                stream.write(data)
        child.stdin.close()
        if child.wait(timeout=15) != 0 or child.stdout.read(1):
            raise ValueError('cat-file failed or returned unexpected trailing data')
    finally:
        if child.poll() is None:
            child.kill()
        try:
            child.wait(timeout=5)
        finally:
            if not child.stdin.closed:
                child.stdin.close()
            child.stdout.close()
    return {'count':len(entries), 'bytes':total}


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--repository', type=Path, required=True)
    p.add_argument('--revision', required=True)
    p.add_argument('--destination', type=Path, required=True)
    a = p.parse_args()
    # The sole bootstrap exports reviewed tooling/workflow, not arbitrary paths.
    print(export_blobs(a.repository, a.revision, a.destination,
          ['.github/workflows/cloud-lighting-5161688.yml','tools/cloud-lighting-5161688']))
