"""Bounded native semantic-adapter regression; not OpenDream recovery acceptance."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

DIAGNOSTIC = re.compile(r'runtime error:|bad ref|BUG:|##\s*ERROR\s*:|RUNTIME:|assertion failed|infinite loop|segmentation|fatal error', re.I)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--expected-saving-sha256', required=True)
    parser.add_argument('--negative-control', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    fixture = root / 'tests/world_save'
    byond = args.byond_bin.resolve(strict=True)
    compiler = byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    if not compiler.is_file() or not daemon.is_file():
        raise RuntimeError('Configured compiler/daemon missing')
    output = Path(tempfile.mkdtemp(prefix='civ13-string-path-'))
    print(f'Retained evidence: {output}', flush=True)
    production = root / 'code/modules/persistence/saving.dm'
    if hashlib.sha256(production.read_bytes()).hexdigest() != args.expected_saving_sha256.lower():
        raise RuntimeError('Production saving source hash mismatch')
    environment = (fixture / 'string_path_roundtrip.dme').read_text(encoding='utf-8')
    environment = environment.replace('#define FILE_DIR "../.."', f'#define FILE_DIR "{root.as_posix()}"')
    hashes = {}
    generated = {}

    def include(match):
        original = (fixture / match.group(1)).resolve(strict=True)
        source = original.read_text(encoding='utf-8')
        hashes[original.relative_to(root).as_posix()] = hashlib.sha256(original.read_bytes()).hexdigest()
        if original == production and args.negative_control:
            before = 'var/F0 = "map_saves/map.txt"'
            if source.count(before) != 1:
                raise RuntimeError('Negative control needs exactly one corrected metadata path')
            source = source.replace(before, 'var/F0 = file("map_saves/map.txt")', 1)
        if original.name == 'roundtrip.dm':
            before = '\tcatch(var/exception/e)\n'
            if source.count(before) != 1:
                raise RuntimeError('Fixture must have one failure handler')
            source = source.replace(before, before + '\t\ttext2file(e.name, "failure-name.txt")\n', 1)
        target = output / original.name
        if target.exists():
            raise RuntimeError('Ambiguous source basename')
        target.write_text(source, encoding='utf-8')
        generated[target.name] = hashlib.sha256(target.read_bytes()).hexdigest()
        return f'#include "{target.as_posix()}"'

    environment = re.sub(r'^#include "([^"]+)"', include, environment, flags=re.MULTILINE)
    (output / 'probe.dme').write_text(environment, encoding='utf-8')
    hashes['tests/world_save/string_path_roundtrip.dme'] = hashlib.sha256((fixture / 'string_path_roundtrip.dme').read_bytes()).hexdigest()
    processes = []

    def read(path):
        if path.stat().st_size > 1048576:
            raise RuntimeError('Output exceeds bounded read size')
        return path.read_text(encoding='utf-8', errors='replace')

    def owned(role, command):
        row = {'role': role, 'pid': None, 'exit': None, 'cancelled': False}
        processes.append(row)
        process = None
        try:
            with (output / f'{role}-stdio.log').open('w', encoding='utf-8') as stream:
                process = subprocess.Popen(command, cwd=output, stdout=stream, stderr=subprocess.STDOUT,
                                           creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
                row['pid'] = process.pid
                try:
                    process.wait(timeout=120)
                finally:
                    if process.poll() is None:
                        row['cancelled'] = True
                        try:
                            process.terminate()
                            process.wait(timeout=4)
                        except (OSError, subprocess.TimeoutExpired):
                            process.kill()
                            process.wait(timeout=2)
        finally:
            row['exit'] = process.poll() if process else None
            (output / 'cleanup.json').write_text(json.dumps(processes, indent=2), encoding='utf-8')
        logs = read(output / f'{role}-stdio.log')
        if role == 'daemon':
            logs += '\n' + read(output / 'runtime.log')
        if row['exit'] != 0 or row['cancelled'] or DIAGNOSTIC.search(logs):
            raise RuntimeError(f'Invalid {role} evidence: {row}\n{logs}')
        return logs

    (output / 'source-inputs.json').write_text(json.dumps({'original': hashes, 'generated': generated}, indent=2), encoding='utf-8')
    build = owned('compile', [str(compiler), '-max_errors', '0', 'probe.dme'])
    if '516.1681' not in build or '0 errors, 0 warnings' not in build:
        raise RuntimeError('Pinned clean compilation required')
    owned('daemon', [str(daemon), 'probe.dmb', '-invisible', '-close', '-safe', '-log', 'runtime.log'])
    actual = read(output / 'result.txt').strip()
    if args.negative_control:
        failure = read(output / 'failure-name.txt').strip()
        if failure != 'Could not write world-save metadata' or not actual.startswith('FAIL:'):
            raise RuntimeError(f'Wrong negative failure: {actual!r}, {failure!r}')
        if (output / 'map_saves/save_complete.txt').exists():
            raise RuntimeError('Failed metadata export published completion marker')
    elif actual != 'PASS':
        raise RuntimeError(f'Positive regression failed: {actual!r}')
    (output / 'summary.json').write_text(json.dumps({
        'scope': __doc__, 'result': actual, 'negative_control': args.negative_control,
        'sources_sha256': hashes, 'generated_sha256': generated, 'processes': processes,
        'opendream_verified': False, 'fresh_process_recovery_verified': False,
        'crash_rpo_verified': False, 'clean_shutdown_verified': False}, indent=2), encoding='utf-8')
    print(f'PASS: string-path regression {"negative" if args.negative_control else "positive"}')


if __name__ == '__main__':
    main()
