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
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "new_z_budget"))
from z_budget_evidence import DIAGNOSTIC, validate_compile


CASES = ('positive', 'matching', 'fractional', 'negative', 'text', 'total-cap',
         'growth-cap', 'shrink', 'horizontal', 'missing', 'marker', 'metadata',
         'generation', 'grid', 'reference', 'area', 'json', 'intent',
         'custody-positive', 'custody-denied', 'custody-binding',
         'allocation-failure', 'exact-post', 'budget', 'multi-budget', 'unmeasured', 'multi-unmeasured')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--negative-control', choices=('preflight', 'memory-admission', 'budget-hold'))
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
        if original.name == 'world_z_budget.dm' and args.negative_control == 'memory-admission':
            before = 'return "UNMEASURED: new levels are disabled until this map has a validated memory/headroom profile. Existing planes remain usable. Preserve saves and request a reviewed profile; no level was allocated."'
            if text.count(before) != 1:
                raise RuntimeError('Memory admission control requires a unique production refusal')
            text = text.replace(before, 'return null', 1)
        if original.name == 'functions.dm' and args.negative_control == 'budget-hold':
            before = 'dimension_budget_hold = TRUE'
            if text.count(before) != 1:
                raise RuntimeError('Hold control requires one production latch')
            text = text.replace(before, 'dimension_budget_hold = FALSE', 1)
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
    validate_compile(0, build, 'dimension_bootstrap.dmb')

    def run(name, params, seed=None):
        cwd = output / name
        cwd.mkdir()
        for suffix in ('dmb', 'rsc'):
            source = output / f'dimension_bootstrap.{suffix}'
            if source.exists():
                shutil.copy2(source, cwd / source.name)
        if seed:
            shutil.copytree(seed / 'map_saves', cwd / 'map_saves')
        seed_hashes = {p.relative_to(cwd / 'map_saves').as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in (cwd / 'map_saves').rglob('*') if p.is_file()} if seed else {}
        owned(name, [str(daemon), 'dimension_bootstrap.dmb', '-ip', '127.0.0.1', '-nowebclient', '-invisible', '-close',
                     '-trusted', '-params', params, '-log', 'runtime.log'], cwd)
        if name in ('budget', 'multi-budget', 'unmeasured', 'multi-unmeasured') and not args.negative_control:
            after = {p.relative_to(cwd / 'map_saves').as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in (cwd / 'map_saves').rglob('*') if p.is_file()}
            if any(after.get(path) != digest for path, digest in seed_hashes.items()):
                raise RuntimeError('Admission refusal modified or removed an original generation file')
        result = (cwd / 'result.txt').read_text(encoding='utf-8').strip()
        native = json.loads((cwd / 'receipt.json').read_text(encoding='utf-8'))
        if native.get('byond_version') != 516 or native.get('byond_build') != 1681:
            raise RuntimeError('Pinned runtime required')
        receipt['cases'][name] = {'result': result, **native}
        persist()
        return cwd, result, native

    seeds = {}
    for count in (2, 3, 4):
        cwd, result, native = run(f'write{count}', f'mode=write{count}')
        if result != 'PASS' or native != {'checks': 4, 'maxz': count, 'allocations': 0, 'byond_version': 516, 'byond_build': 1681}:
            raise RuntimeError(f'Writer did not produce the intended generation: {result}, {native}')
        seeds[count] = cwd
    selected = ('missing',) if args.negative_control == 'preflight' else ('unmeasured',) if args.negative_control else CASES
    for case in selected:
        cwd, result, native = run(case, f'mode=read;case={case}', seeds[2 if case == 'matching' else 4 if case in ('multi-budget', 'multi-unmeasured') else 3])
        expected = {'preflight': 'FAIL: rejected save allocated levels', 'memory-admission': 'FAIL: unmeasured saved target accepted', 'budget-hold': 'FAIL: admission denial did not retain non-allocation recovery hold'}.get(args.negative_control, 'PASS')
        if result != expected:
            raise RuntimeError(f'Unexpected {case} result: {result!r}; expected {expected!r}')
        if args.negative_control:
            control_allocations = 0 if args.negative_control == 'budget-hold' else 1
            control_z = 2 if args.negative_control == 'budget-hold' else 3
            if native['allocations'] != control_allocations or native['maxz'] != control_z:
                raise RuntimeError('Control failed for an unrelated allocation outcome')
        else:
            expected_allocations = int(case in ('positive', 'custody-positive', 'allocation-failure', 'exact-post'))
            expected_z = 3 if expected_allocations else 2
            # Reject incomplete or truncated execution even when PASS was emitted.
            minimum = 10 if case in ('positive', 'matching', 'custody-positive') else 5
            if native['allocations'] != expected_allocations or native['maxz'] != expected_z or native['checks'] < minimum:
                raise RuntimeError(f'Unexpected native dimensions/check count: {case}: {native}')
    print(f'PASS: dimension bootstrap {args.negative_control or "positive and malformed controls"}')


if __name__ == '__main__':
    main()
