"""Freeze the Windows executor and source cases without executing native code."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def freeze(output, byond_bin, compiler_diagnostic=False, remaining_controls=False):
    if compiler_diagnostic and remaining_controls:
        raise ValueError('Choose one packet mode')
    output = output.resolve()
    compiler, daemon = byond_bin / 'dm.exe', byond_bin / 'dd.exe'
    spec = importlib.util.spec_from_file_location('decal_guard', HERE / 'guard_config.py')
    guard = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(guard)
    for executable in (compiler, daemon):
        if guard.digest(executable) != guard.BINARIES[executable.name]:
            raise ValueError('Pinned executable hash mismatch')
    output.mkdir(parents=True, exist_ok=False)
    spec = importlib.util.spec_from_file_location('decal_prepare', HERE / 'prepare.py')
    preparation = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(preparation)
    preparation.prepare(output / 'source-packet')
    for name in ('run-contained.py', 'windows.py', 'guard_config.py', 'z_budget_evidence.py', 'native_policy.py', 'owned_job.py'):
        shutil.copyfile(HERE / name, output / name)
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    files = {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
             for path in sorted(output.rglob('*')) if path.is_file()}
    for path in (compiler, daemon, Path(__file__).resolve()):
        files[str(path)] = guard.digest(path)
    packet = {'head': head, 'runner_sha256': guard.digest(output / 'run-contained.py'),
              'sources': str(output / 'source-packet'), 'adapter_root': str(output),
              'compiler': str(compiler), 'daemon': str(daemon), 'files': files,
              'gaia': {'pid': 161088, 'creation_filetime': 134368205457714990},
              'native_executed': False, 'total_seconds': 90 if compiler_diagnostic else 180 if remaining_controls else 240,
              'mode': 'compiler-diagnostic' if compiler_diagnostic else 'remaining-controls' if remaining_controls else 'fixture',
              'native_assertions': 0 if compiler_diagnostic else 33,
              'cases': ['fixed-compile'] if compiler_diagnostic else ['missing-lazy', 'shared'] if remaining_controls else ['fixed', 'eager-parity', 'eager-negative', 'missing-lazy', 'shared']}
    path = output / 'packet.json'
    path.write_text(json.dumps(packet, indent=2) + '\n', encoding='utf-8')
    return {'packet': str(path), 'packet_sha256': guard.digest(path), 'head': head,
            'native_executed': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--compiler-diagnostic', action='store_true')
    parser.add_argument('--remaining-controls', action='store_true')
    args = parser.parse_args()
    print(json.dumps(freeze(args.output, args.byond_bin.resolve(), args.compiler_diagnostic, args.remaining_controls), indent=2))
