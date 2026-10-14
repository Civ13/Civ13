"""Bounded experimental detached capture probe, not active game-save acceptance."""
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
    parser.add_argument('--negative-control', choices=('callback', 'admission', 'hook'))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    fixture = root / 'tests/world_save'
    byond = args.byond_bin.resolve(strict=True)
    compiler = byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    if not compiler.is_file() or not daemon.is_file():
        raise RuntimeError('Configured compiler/daemon missing')
    output = Path(tempfile.mkdtemp(prefix='civ13-immutable-capture-'))
    print(f'Retained evidence: {output}', flush=True)
    prototype = root / 'code/modules/persistence/immutable_capture.dm'
    source = prototype.read_text(encoding='utf-8')
    expected = 'PASS'
    if args.negative_control == 'callback':
        before = 'var/list/saved = projection_manifest["[source.type]"]'
        # Restrict the deliberate callback regression to its paid-state input;
        # unrelated world projections must not mask the exact failure oracle.
        after = before + '\n\tif(source.type == text2path("/datum/capture_input/mutating")) saved = source.get_saved_vars()'
        expected = 'FAIL: capture invoked mutating projection'
    elif args.negative_control == 'admission':
        before = 'if(!islist(saved)) throw EXCEPTION("No audited exact-type capture projection")'
        after = 'if(!islist(saved)) saved = list()'
        expected = 'FAIL: unreviewed projection admitted'
    elif args.negative_control == 'hook':
        before, after = '\treject_hook(source)\n', '\tif(FALSE) reject_hook(source)\n'
        expected = 'FAIL: mutating paid hook admitted'
    if args.negative_control:
        if source.count(before) != 1:
            raise RuntimeError('Omission control requires unique production guard')
        source = source.replace(before, after, 1)
    (output / 'immutable_capture.dm').write_text(source, encoding='utf-8')
    environment = (fixture / 'immutable_capture.dme').read_text(encoding='utf-8')
    environment = environment.replace('#define FILE_DIR "../.."', f'#define FILE_DIR "{root.as_posix()}"')
    hashes = {}

    def include(match):
        original = (fixture / match.group(1)).resolve(strict=True)
        target = output / 'immutable_capture.dm' if original == prototype else original
        hashes[original.relative_to(root).as_posix()] = hashlib.sha256(target.read_bytes()).hexdigest()
        return f'#include "{target.as_posix()}"'

    environment = re.sub(r'^#include "([^"]+)"', include, environment, flags=re.MULTILINE)
    (output / 'probe.dme').write_text(environment, encoding='utf-8')
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

    build = owned('compile', [str(compiler), '-max_errors', '0', 'probe.dme'])
    if '516.1681' not in build or '0 errors, 0 warnings' not in build:
        raise RuntimeError('Pinned clean compilation required')
    owned('daemon', [str(daemon), 'probe.dmb', '-invisible', '-close', '-safe', '-log', 'runtime.log'])
    actual = read(output / 'result.txt').strip()
    if actual != expected:
        raise RuntimeError(f'Unexpected probe result {actual!r}; expected {expected!r}')
    (output / 'summary.json').write_text(json.dumps({
        'scope': __doc__, 'result': actual, 'negative_control': args.negative_control,
        'sources_sha256': hashes, 'processes': processes, 'opendream_verified': False,
        'representative_pause_measured': False, 'peak_memory_measured': False,
        'world_cohort_verified': False, 'durable_generation_verified': False,
        'crash_rpo_verified': False, 'clean_shutdown_verified': False}, indent=2), encoding='utf-8')
    print(f'PASS: immutable capture experiment {args.negative_control or "positive"}')


if __name__ == '__main__':
    main()
