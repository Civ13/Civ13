"""Freeze source/assets and five full-source cases. Never launch native code."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

from prepare import prepare

ROOT = Path(__file__).resolve().parents[2]
ROOTS = {'code', 'icons', 'sound', 'UI', 'interface'}
CASES = ('baseline', 'candidate', 'virtual-master', 'halo', 'refusal-owner')
HELPER_HEAD = 'a8498878544bb37e0c8cbf922bea5d1cd118c7f1'
HELPER_HASHES = {
    'windows.py': 'bfe1a3be9556abbcef70b5bfee41bf235d9a5522dd07e94061d89b5f8a25cbc3',
    'owned_job.py': '1ddbb52ed9b92b9cfe15c9f0b023af71ce0b0217e91d02a7da8a7242411e09b3',
    'native_policy.py': 'bf3cecc93643a90ba1962db9f083c05eb4f6842e9cfe6dcba8b72f9504dd82a3',
    'guard_config.py': 'ee5db97cabe3bcb2d8acb6660d67bbb56ee1f82052f96da00d54b13756615d35',
    'z_budget_evidence.py': '133c130845ab28cfb6f0bfb8b2c63b595d3694afc44a3af398cb1fdf3de584db',
}
HELPER_FROZEN = Path('D:/GitHub/civ13-preview-evidence/lazy-floor-decal-tracking-20261018/contained-v7')
BYOND = Path('C:/Users/valza/.codex/cache/byond/516.1681/byond/bin')
BINARIES = {'dm.exe': '8ad7537fc1329ada04e8e1e8835ec9cf205f3e5029461a3ead1f8f4ced7b0bb8',
            'dd.exe': '7b148eceaaae483395b636fab817609b37f8fb852f1d5aad12d29bbcaf1585ae'}


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            value.update(chunk)
    return value.hexdigest()


def freeze(output):
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    diff = subprocess.check_output(['git', 'diff', 'HEAD'], cwd=ROOT)
    if diff:
        raise ValueError('Commit source changes before freezing')
    provenance = {'head': head, 'dirty_diff_sha256': hashlib.sha256(diff).hexdigest()}
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    frozen = output/'source'
    total = 0
    for rel in tracked:
        path = Path(rel)
        if not rel or not (path.parts[0] in ROOTS or rel == 'civ13.dme' or rel.startswith('tests/reserved_lighting/')):
            continue
        source = ROOT/path
        if source.is_symlink() or not source.is_file():
            raise ValueError('Nonregular frozen input: ' + rel)
        total += source.stat().st_size
        if total > 2 * 1024**3:
            raise ValueError('Immutable source/resource input exceeds 2 GiB')
        target = frozen/path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    profiles = []
    for case in CASES:
        generated = frozen/'cases'/case
        manifest = prepare(frozen, generated, None if case in ('baseline', 'candidate') else case, provenance)
        # FILE_DIR is already '.', with DME placed at the frozen checkout root.
        dme = frozen/(case + '.dme')
        shutil.copyfile(generated/'probe.dme', dme)
        profiles.append({'name': case, 'dme': str(dme), 'reserved': case != 'baseline',
                         'manifest': str(generated/'manifest.json'), 'probe_sha256': manifest['probe_sha256']})
    adapter = output/'adapter'
    adapter.mkdir()
    for name in ('windows.py', 'guard_config.py', 'owned_job.py', 'native_policy.py', 'z_budget_evidence.py'):
        # Preserve the exact accepted packet bytes, including its line endings.
        # Git blobs can differ from the Windows frozen copies under autocrlf.
        blob = (HELPER_FROZEN/name).read_bytes()
        if hashlib.sha256(blob).hexdigest() != HELPER_HASHES[name]:
            raise ValueError('Accepted helper hash mismatch: ' + name)
        (adapter/name).write_bytes(blob)
    shutil.copyfile(ROOT/'tests/reserved_lighting/run-contained.py', output/'run-contained.py')
    binaries = {}
    for name, sha in BINARIES.items():
        binary = BYOND/name
        if digest(binary) != sha:
            raise ValueError('Pinned executable hash mismatch')
        binaries[str(binary)] = sha
    files = {str(p.relative_to(output)): {'sha256': digest(p), 'bytes': p.stat().st_size}
             for p in sorted(output.rglob('*')) if p.is_file()}
    packet = {'head': head, 'profiles': profiles, 'files': files, 'native_executed': False,
              'compiler': str(BYOND/'dm.exe'), 'daemon': str(BYOND/'dd.exe'), 'binaries': binaries,
              'helper_head': HELPER_HEAD,
              'source_resource_bytes': total, 'immutable_source_bound': 2 * 1024**3,
              'compiled_artifact_bound_each': 1024**3, 'generated_text_bound': 16 * 1024**2,
              'envelope': {'compile_wall': 75, 'compile_cpu': 30, 'compile_private': 1024**3,
                           'runtime_wall': 30, 'runtime_cpu': 10, 'runtime_private': 512 * 1024**2,
                           'watcher_private': 128 * 1024**2, 'active_processes': 1, 'total_wall': 610},
              'executor_status': 'Exact v7 helper source and eight-phase containment evidence accepted; reserved fixture native unrun, exact root grant REQUIRED',
              'scope': 'Frozen full-source tiny 16x16x1 fixture; no normal config, userdata or maps copied'}
    receipt = output/'packet.json'
    receipt.write_text(json.dumps(packet, indent=2) + '\n', encoding='utf-8')
    return {'packet': str(receipt), 'sha256': digest(receipt), 'head': head, 'files': len(files)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    print(json.dumps(freeze(parser.parse_args().output)))
