"""Fixed executable allowlist and resource bounds; no host-memory admission."""
import hashlib
from pathlib import Path

BINARIES = {
    'DreamMaker.exe': 'cee8494af3b10e4a48accb5dfae81387fc75f247ebee160745127a6c222a0535',
    'DreamDaemon.exe': '970b096468fc3b77a711f82726a7a0d76a883c7f7583f6d3874183f80c2743a9',
}
LIMITS = {'process_private_bytes': 1024 * 1024**2, 'watcher_private_bytes': 128 * 1024**2}

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()
