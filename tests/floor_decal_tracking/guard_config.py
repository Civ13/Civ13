"""Fixed executable allowlist and resource bounds; no host-memory admission."""
import hashlib
from pathlib import Path

BINARIES = {
    'dm.exe': '8ad7537fc1329ada04e8e1e8835ec9cf205f3e5029461a3ead1f8f4ced7b0bb8',
    'dd.exe': '7b148eceaaae483395b636fab817609b37f8fb852f1d5aad12d29bbcaf1585ae',
}
LIMITS = {'process_private_bytes': 1024 * 1024**2, 'watcher_private_bytes': 128 * 1024**2}

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()
