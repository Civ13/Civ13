"""Stage the exact V4 Civ13 assets plus the explicitly reviewed cloud derivative."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile

HERE = Path(__file__).resolve().parent
REVISION = '58404f5bd16e3fed80f1d9844c5db3edd144942c'


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


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
    destination.mkdir(parents=True)
    seen, total = set(), 0
    command = ['git', '-C', str(repository), 'archive', '--format=tar', REVISION, 'civ13.dme', 'code', 'icons', 'sound', 'UI', 'interface', 'config/names']
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL) as child:
        try:
            with tarfile.open(fileobj=child.stdout, mode='r|') as archive:
                for item in archive:
                    if item.isdir():
                        continue
                    if not item.isfile() or item.name not in expected or item.name in seen or item.size > 64*1024**2:
                        raise ValueError('Unexpected source archive member')
                    total += item.size
                    if total > 1024**3:
                        raise ValueError('Source byte bound')
                    raw = archive.extractfile(item).read()
                    if hashlib.sha1(('blob %d\0' % len(raw)).encode()+raw).hexdigest() != expected[item.name]:
                        raise ValueError('Source blob mismatch')
                    target = destination/item.name
                    if not target.resolve().is_relative_to(destination.resolve()):
                        raise ValueError('Source path escape')
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(raw)
                    seen.add(item.name)
            if child.wait(timeout=15) or seen != set(expected):
                raise ValueError('Incomplete source export')
        except BaseException:
            child.kill()
            child.wait(timeout=5)
            raise
    for relative, expected_hash in derivative['changes'].items():
        source = HERE/'changed-source'/relative
        if digest(source) != expected_hash:
            raise ValueError('Reviewed derivative changed')
        target = destination/relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(source.read_bytes())
    if '#define FILMING_NATIVE_RELEASED TRUE' not in (destination/'filming/scene.dm').read_text():
        raise ValueError('Cloud fixture source release missing')
    receipt = {'source_revision': REVISION, 'source_blob_count': len(seen), 'source_bytes': total,
               'v4_manifest_sha256': digest(HERE/'v4-source-manifest.json'),
               'derived_manifest_sha256': digest(HERE/'derived-source.json'),
               'scope': 'isolated genuine Civ13 bakery; one real engine guest camera',
               'native_executed': False}
    (destination/'source-receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
    return receipt


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--repository', type=Path, required=True)
    p.add_argument('--destination', type=Path, required=True)
    a = p.parse_args()
    print(json.dumps(stage(a.repository, a.destination)))
