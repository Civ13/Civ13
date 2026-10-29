"""Checked-in historical test inputs; never consult the repository's Git history."""
import hashlib
import json
from pathlib import Path

DIRECTORY = Path(__file__).with_name('fixtures')


def text(commit, path):
    manifest = json.loads((DIRECTORY / 'manifest.json').read_text(encoding='utf-8'))
    entry = manifest[commit + ':' + path]
    data = (DIRECTORY / entry['file']).read_bytes()
    if len(data) != entry['bytes'] or hashlib.sha256(data).hexdigest() != entry['sha256']:
        raise ValueError('Historical fixture changed: ' + entry['file'])
    return data.decode('utf-8').replace('\r\n', '\n').replace('\r', '\n')
