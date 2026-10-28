"""516.1688 installed Windows binaries observed 2026-10-26, not vendor checksums.

PE product/file version is 5.0.516.1688. Central tools/byond/version.json pins
the installer separately. Compiler banner and runtime build are checked too.
The accompanying windows.py and owned_job.py are byte-identical copies of the
frozen floor_decal_tracking adapters. No containment or socket policy changes.
"""
import hashlib
from pathlib import Path

BINARIES = {
    'dm.exe': 'f29b3041c46df453b3f999583bef0bb0ff79fe2b53ee1b8686bb46ce18c7df77',
    'dd.exe': 'abb21de26047724bf64411e17da5e17cacc74221817c3e049a79626156b44866',
}
LIMITS = {'process_private_bytes': 1024 * 1024**2, 'watcher_private_bytes': 128 * 1024**2}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()
