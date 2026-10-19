"""Smoke-only vendor allowlist and bounds, separate from headless HUD admission."""
import hashlib
import json
from pathlib import Path

VENDOR = json.loads(Path(__file__).with_name('vendor.json').read_text())
BINARIES = VENDOR['binaries']
LIMITS = {'process_private_bytes': 512 * 1024**2, 'watcher_private_bytes': 128 * 1024**2}

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()
