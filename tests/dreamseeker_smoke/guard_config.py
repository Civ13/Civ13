"""Smoke-only vendor allowlist and bounds, separate from headless HUD admission."""
import hashlib
import json
from pathlib import Path

VENDOR = json.loads(Path(__file__).with_name('vendor.json').read_text())
BINARIES = VENDOR['binaries']
LIMITS = {'process_private_bytes': 512 * 1024**2, 'watcher_private_bytes': 128 * 1024**2}

def digest(path):
    result = hashlib.sha256()
    with Path(path).open("rb") as stream:
        while chunk := stream.read(64 * 1024):
            result.update(chunk)
    return result.hexdigest()
