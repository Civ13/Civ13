"""1688 cloud-only derivative; the original 1681 guard remains unchanged."""
import hashlib
import json
from pathlib import Path
VENDOR = json.loads(Path(__file__).with_name('vendor.json').read_text())
BINARIES = {Path(row['path']).name.lower(): row['sha256'] for row in VENDOR['files'] if '/bin/' in row['path']}
BINARIES['dxsetup.exe'] = next(row['sha256'] for row in VENDOR['files'] if row['path'] == 'byond/directx/DXSETUP.exe')
LIMITS = {'process_private_bytes': 512*1024**2, 'watcher_private_bytes': 128*1024**2}
def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()
