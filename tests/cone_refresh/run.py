"""Bounded isolated native verification. Preparation alone never launches BYOND."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

from prepare import CONTROLS, ROOT, prepare

from evidence import DIAGNOSTIC, MAX_COMPILE_LOG, validate_compile


def validate_native(exit_code, diagnostics, result, receipt, control):
    if exit_code != 0 or DIAGNOSTIC.search(diagnostics):
        raise RuntimeError('Native exit/diagnostics invalidated evidence')
    if receipt.get('byond_version') != 516 or receipt.get('byond_build') != 1681 or receipt.get('port') != 0:
        raise RuntimeError('Pinned 516.1681 runtime and closed port required')
    expected = 'FAIL: ' + CONTROLS[control][0] if control else 'PASS: cone refresh'
    if result != expected or not isinstance(receipt.get('checks'), int) or receipt['checks'] <= 0:
        raise RuntimeError(f'Incomplete or unintended result: {result!r}; expected {expected!r}')
    if not control and (receipt.get('checks', 0) < 35 or receipt.get('save_roundtrip') != 1 or receipt.get('phases') != ['forced', 'vehicle', 'seats', 'save']):
        raise RuntimeError('Incomplete production-path coverage')
    if control:
        expected_phases = [] if control == 'forced-move' else ['forced', 'vehicle'] if control == 'seat-facing' else ['forced']
        if receipt.get('phases') != expected_phases or receipt.get('save_roundtrip') != 0:
            raise RuntimeError('Control failed outside its intended phase')


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--prepared', type=Path)
    parser.add_argument('--control', choices=CONTROLS)
    parser.add_argument('--expected-commit')
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args()
    if not args.prepare_only and not args.byond_bin:
        parser.error('--byond-bin required for native verification')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    if args.prepared:
        prepared = args.prepared.resolve(strict=True)
    else:
        prepared = output / 'source'
        prepare(prepared, args.control)
    source = json.loads((prepared / 'receipt.json').read_text(encoding='utf-8'))
    if source['control'] != args.control:
        raise RuntimeError('Prepared control does not match requested control')
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    if source['head'] != head or (args.expected_commit and head != args.expected_commit):
        raise RuntimeError('Prepared/current/expected commit mismatch')
    if subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=no'], cwd=ROOT).strip():
        raise RuntimeError('Tracked source changes invalidate exact-commit verification')
    for name, digest in source['source_sha256'].items():
        if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != digest:
            raise RuntimeError('Changed source: ' + name)
    for name, digest in source['generated_sha256'].items():
        if hashlib.sha256((prepared / name).read_bytes()).hexdigest() != digest:
            raise RuntimeError('Changed prepared source: ' + name)
    if args.prepare_only:
        print('PASS: exact source preparation only; no compiler/runtime launched')
        return
    binary = args.byond_bin.resolve(strict=True)
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    if not compiler.is_file() or not daemon.is_file():
        raise RuntimeError('Missing explicit compiler/runtime')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    build = output / 'build'
    build.mkdir()
    # Includes keep pointing at the hash-verified frozen source; outputs live here.
    shutil.copy2(prepared / 'probe.dme', build / 'probe.dme')
    compiled = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=build,
                              capture_output=True, text=True, timeout=180, creationflags=flags)
    compile_log = compiled.stdout + compiled.stderr
    (output / 'compile.log').write_text(compile_log, encoding='utf-8')
    validate_compile(compiled.returncode, compile_log)
    runtime = output / 'runtime'
    runtime.mkdir()
    for suffix in ('dmb', 'rsc'):
        shutil.copy2(build / ('probe.' + suffix), runtime / ('probe.' + suffix))
    shutil.copytree(ROOT / 'config/names', runtime / 'config/names')
    (runtime / 'config/crafting').mkdir()
    shutil.copy2(ROOT / 'config/crafting/material_recipes_global.txt', runtime / 'config/crafting/material_recipes_global.txt')
    daemon_argv = [str(daemon), 'probe.dmb', '-ip', '127.0.0.1', '-invisible', '-close', '-trusted', '-log', 'runtime.log']
    (output / 'launch.json').write_text(json.dumps({'argv': daemon_argv, 'cwd': str(runtime),
                                                  'binding': 'requested loopback; fixture closes listener in New; no socket-monitor claim'}, indent=2) + '\n', encoding='utf-8')
    completed = subprocess.run(daemon_argv,
                               cwd=runtime, capture_output=True, text=True, timeout=90, creationflags=flags)
    diagnostics = completed.stdout + completed.stderr
    (output / 'daemon.log').write_text(diagnostics, encoding='utf-8')
    for name in ('runtime.log', 'errors.txt'):
        path = runtime / name
        if path.exists():
            if path.stat().st_size > 1024 * 1024:
                raise RuntimeError('Diagnostic output exceeded bound')
            diagnostics += path.read_text(encoding='utf-8', errors='replace')
    result = (runtime / 'result.txt').read_text(encoding='utf-8').strip()
    receipt = json.loads((runtime / 'receipt.json').read_text(encoding='utf-8'))
    validate_native(completed.returncode, diagnostics, result, receipt, args.control)
    summary = {'head': head, 'control': args.control, 'result': result, 'native': receipt,
               'compiler_sha256': hashlib.sha256(compiler.read_bytes()).hexdigest(),
               'daemon_sha256': hashlib.sha256(daemon.read_bytes()).hexdigest(), 'daemon_argv': daemon_argv, 'source': source}
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    print('PASS: bounded isolated fixture ' + (args.control or 'positive'))


if __name__ == '__main__':
    main()
