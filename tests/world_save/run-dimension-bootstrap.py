"""Fresh-process saved-dimension preflight with actual production serialization.

The shared production allocator runs in a tiny world, without roof construction.
All native processes and saves are isolated and retained for inspection.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

DIAGNOSTIC = re.compile(r'runtime error:|bad ref|BUG:|##\s*ERROR\s*:|RUNTIME:|assertion failed|infinite loop|segmentation|fatal error', re.I)
CASES = ('positive', 'matching', 'fractional', 'negative', 'text', 'total-cap',
         'growth-cap', 'shrink', 'horizontal', 'missing', 'marker', 'metadata',
         'generation', 'grid', 'reference', 'area', 'json', 'intent',
         'allocation-failure', 'exact-post')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--negative-control', choices=('preflight',))
    args = parser.parse_args()
    if not args.prepare_only and not args.byond_bin:
        parser.error('--byond-bin is required for native execution')
    root = Path(__file__).resolve().parents[2]
    fixture = root / 'tests/world_save'
    output = Path(tempfile.mkdtemp(prefix='civ13-dimension-bootstrap-'))
    print(f'Retained evidence: {output}', flush=True)
    hashes = {}
    allocator_hash = None
    environment = (fixture / 'dimension_bootstrap.dme').read_text(encoding='utf-8')
    environment = environment.replace('#define FILE_DIR "../.."', f'#define FILE_DIR "{root.as_posix()}"')

    def include(match):
        nonlocal allocator_hash
        original = (fixture / match.group(1)).resolve(strict=True)
        text = original.read_text(encoding='utf-8')
        if original.name == 'building_levels.dm':
            allocator_hash = hashlib.sha256(text.encode()).hexdigest()
            # Compile the complete allocator and sky definition verbatim. The
            # following gameplay Entered/support/paired-construction procedures
            # are exercised by tests/building_levels instead of re-stubbed here.
            text = text[:text.index('/turf/sky/building/Entered')]
        if original.name == 'functions.dm' and args.negative_control == 'preflight':
            before = '\t\tvar/valid = validate_world_save()'
            if text.count(before) != 1:
                raise RuntimeError('Preflight control requires a unique production guard')
            text = text.replace(before, '\t\tvar/valid = TRUE', 1)
        hashes[original.relative_to(root).as_posix()] = hashlib.sha256(text.encode()).hexdigest()
        target = output / original.name
        if target.exists():
            raise RuntimeError(f'Include filename collision: {target.name}')
        target.write_text(text, encoding='utf-8', newline='\n')
        return f'#include "{target.as_posix()}"'

    environment = re.sub(r'^#include "([^"]+)"', include, environment, flags=re.M)
    (output / 'dimension_bootstrap.dme').write_text(environment, encoding='utf-8', newline='\n')
    receipt = {'prepared_only': args.prepare_only, 'negative_control': args.negative_control,
               'sources_sha256': hashes, 'cases': {}, 'processes': [],
               'allocator': 'production shared allocator, verbatim prefix',
               'allocator_full_source_sha256': allocator_hash, 'full_game_verified': False}

    def persist():
        (output / 'summary.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')

    persist()
    if args.prepare_only:
        print('Prepared source only; no compiler or runtime was executed.')
        return
    byond = args.byond_bin.resolve(strict=True)
    compiler = byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    if not compiler.is_file() or not daemon.is_file():
        raise RuntimeError('Missing configured compiler or daemon')

    def owned(role, command, cwd):
        row = {'role': role, 'pid': None, 'exit': None, 'cancelled': False}
        receipt['processes'].append(row)
        process = None
        try:
            with (cwd / 'stdio.log').open('w', encoding='utf-8') as stream:
                process = subprocess.Popen(command, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT,
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
                row['pid'] = process.pid
                try:
                    process.wait(timeout=120)
                finally:
                    if process.poll() is None:
                        row['cancelled'] = True
                        process.terminate()
                        try:
                            process.wait(timeout=4)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait(timeout=2)
        finally:
            row['exit'] = process.poll() if process else None
            persist()
        logs = []
        for name in ('stdio.log', 'runtime.log'):
            path = cwd / name
            if path.exists():
                if path.stat().st_size > 1024 * 1024:
                    raise RuntimeError(f'Output limit: {role}/{name}')
                logs.append(path.read_text(encoding='utf-8', errors='replace'))
        text = '\n'.join(logs)
        if row['exit'] != 0 or row['cancelled'] or DIAGNOSTIC.search(text):
            raise RuntimeError(f'Invalid native evidence: {row}\n{text}')
        return text

    build = owned('compile', [str(compiler), '-max_errors', '0', 'dimension_bootstrap.dme'], output)
    if '516.1681' not in build or '0 errors, 0 warnings' not in build:
        raise RuntimeError(f'Pinned clean compilation required: {build}')

    def run(name, params, seed=None):
        cwd = output / name
        cwd.mkdir()
        for suffix in ('dmb', 'rsc'):
            source = output / f'dimension_bootstrap.{suffix}'
            if source.exists():
                shutil.copy2(source, cwd / source.name)
        if seed:
            shutil.copytree(seed / 'map_saves', cwd / 'map_saves')
        owned(name, [str(daemon), 'dimension_bootstrap.dmb', '-invisible', '-close',
                     '-safe', '-params', params, '-log', 'runtime.log'], cwd)
        result = (cwd / 'result.txt').read_text(encoding='utf-8').strip()
        native = json.loads((cwd / 'receipt.json').read_text(encoding='utf-8'))
        receipt['cases'][name] = {'result': result, **native}
        persist()
        return cwd, result, native

    seeds = {}
    for count in (2, 3):
        cwd, result, native = run(f'write{count}', f'mode=write{count}')
        if result != 'PASS' or native != {'checks': 2, 'maxz': count, 'allocations': 0}:
            raise RuntimeError(f'Writer did not produce the intended generation: {result}, {native}')
        seeds[count] = cwd
    selected = ('missing',) if args.negative_control else CASES
    for case in selected:
        cwd, result, native = run(case, f'mode=read;case={case}', seeds[2 if case == 'matching' else 3])
        expected = 'FAIL: rejected save allocated levels' if args.negative_control else 'PASS'
        if result != expected:
            raise RuntimeError(f'Unexpected {case} result: {result!r}; expected {expected!r}')
        if args.negative_control:
            if native['allocations'] != 1 or native['maxz'] != 3:
                raise RuntimeError('Preflight control failed for an unrelated reason')
        else:
            expected_allocations = int(case in ('positive', 'allocation-failure', 'exact-post'))
            expected_z = 3 if expected_allocations else 2
            # Reject incomplete or truncated execution even when PASS was emitted.
            minimum = 10 if case in ('positive', 'matching') else 5
            if native['allocations'] != expected_allocations or native['maxz'] != expected_z or native['checks'] < minimum:
                raise RuntimeError(f'Unexpected native dimensions/check count: {case}: {native}')
    print(f'PASS: dimension bootstrap {args.negative_control or "positive and malformed controls"}')


if __name__ == '__main__':
    main()
