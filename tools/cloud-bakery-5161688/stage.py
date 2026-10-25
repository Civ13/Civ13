"""Stage the exact pinned current Civ13 assets plus the explicitly reviewed cloud derivative."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from materialize import export_blobs

HERE = Path(__file__).resolve().parent
REVISION = '9683866a89d2bdc12f8dc7d25444e350583c5483'


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def verify_global_publication_source(master, globals_source):
    """Bind this narrow fixture fix to the hash-verified original source contract."""
    caller = '\tif(!GLOB)\n\t\tnew /datum/controller/global_vars'
    publisher = '/datum/controller/global_vars/New()\n\tif(GLOB)\n\t\tCRASH("Multiple instances of global variable controller created")\n\tGLOB = src'
    if caller not in master or publisher not in globals_source:
        raise ValueError('Original global-controller caller/publication contract changed')


def stage(repository, destination):
    repository, destination = Path(repository).resolve(), Path(destination).absolute()
    if destination.exists() or any(p.is_symlink() or getattr(p, 'is_junction', lambda: False)() for p in (destination, *destination.parents)):
        raise ValueError('Fresh non-reparse staging destination required')
    actual = subprocess.check_output(['git', '-C', str(repository), 'rev-parse', 'HEAD'], timeout=15, text=True).strip()
    if actual != REVISION:
        raise ValueError('Wrong source checkout')
    manifest = json.loads((HERE/'v4-source-manifest.json').read_text())
    derivative = json.loads((HERE/'derived-source.json').read_text())
    if manifest['revision'] != REVISION or derivative['scene_revision'] != REVISION:
        raise ValueError('Wrong source manifest')
    expected = {row['path']: row['git_blob'] for row in manifest['materialization_allowlist']}
    exported = export_blobs(repository, REVISION, destination,
                            ['civ13.dme', 'code', 'icons', 'sound', 'UI', 'interface', 'config/names'], expected)
    verify_global_publication_source((destination/'code/controllers/mc/master.dm').read_text(),
                                     (destination/'code/controllers/mc/globals.dm').read_text())
    for relative, expected_hash in derivative['changes'].items():
        source = HERE/'changed-source'/relative
        if digest(source) != expected_hash:
            raise ValueError('Reviewed derivative changed')
        target = destination/relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(source.read_bytes())
    if '#define FILMING_NATIVE_RELEASED TRUE' not in (destination/'filming/scene.dm').read_text():
        raise ValueError('Cloud fixture source release missing')
    receipt = {'source_revision': REVISION, 'source_blob_count': exported['count'], 'source_bytes': exported['bytes'],
               'v4_manifest_sha256': digest(HERE/'v4-source-manifest.json'),
               'derived_manifest_sha256': digest(HERE/'derived-source.json'),
               'scope': 'isolated genuine Civ13 tree process; one real engine guest camera',
               'native_executed': False}
    (destination/'source-receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
    return receipt


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--repository', type=Path, required=True)
    p.add_argument('--destination', type=Path, required=True)
    a = p.parse_args()
    print(json.dumps(stage(a.repository, a.destination)))
