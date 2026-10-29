"""Native production admission-adapter contract only; no host custody proof."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
import fixture_toolchain as current


DIAGNOSTIC = re.compile(r'runtime error:|bad ref|BUG:|##\s*ERROR\s*:|RUNTIME:|assertion failed|infinite loop|segmentation|fatal error', re.I)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--negative-control', choices=('binding', 'recheck'))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    byond = args.byond_bin.resolve(strict=True)
    compiler = byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    if not compiler.is_file() or not daemon.is_file():
        raise RuntimeError('Missing configured compiler or daemon')
    output = Path(tempfile.mkdtemp(prefix='civ13-admission-contract-'))
    print(f'Evidence: {output}', flush=True)
    source = (root / 'code/modules/persistence/admission_contract.dm').read_text(encoding='utf-8')
    expected = 'PASS'
    if args.negative_control == 'binding':
        before = 'if(!islist(selection) || selection.len != 8) return FALSE'
        after = 'if(!islist(selection)) return FALSE'
        expected = 'FAIL: extra binding rejected'
    elif args.negative_control == 'recheck':
        before = '\t\treturn capability_matches(capability, action)\n\tproc/capability_matches'
        after = '\t\treturn istype(capability) && capability.action == action\n\tproc/capability_matches'
        expected = 'FAIL: callback validate_binding denied'
    if args.negative_control:
        if source.count(before) != 1:
            raise RuntimeError('Negative control requires one unique production guard')
        source = source.replace(before, after, 1)
    probe = (root / 'tests/persistence_admission/probe.dm').read_text(encoding='utf-8')
    (output / 'adapter.dm').write_text(source, encoding='utf-8')
    (output / 'probe.dm').write_text(probe, encoding='utf-8')
    (output / 'probe.dme').write_text('#define TRUE 1\n#define FALSE 0\n#include "probe.dm"\n#include "adapter.dm"\n', encoding='utf-8')
    hashes = {name: hashlib.sha256((output / name).read_bytes()).hexdigest()
              for name in ('adapter.dm', 'probe.dm', 'probe.dme')}
    cleanup = []

    def text(path):
        if path.stat().st_size > 1024 * 1024:
            raise RuntimeError(f'Output limit: {path.name}')
        return path.read_text(encoding='utf-8', errors='replace')

    def owned(role, command, timeout):
        row = {'role': role, 'command': command, 'parent_pid': os.getpid(),
               'pid': None, 'exit': None, 'cancelled': False, 'errors': []}
        cleanup.append(row)
        process = None
        try:
            with (output / f'{role}-stdio.log').open('w', encoding='utf-8') as stream:
                current.verify(command[0])
                process = subprocess.Popen(command, cwd=output, stdout=stream, stderr=subprocess.STDOUT,
                                           creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
                row['pid'] = process.pid
                try:
                    process.wait(timeout=timeout)
                finally:
                    if process.poll() is None:
                        row['cancelled'] = True
                        try:
                            process.terminate()
                            process.wait(timeout=4)
                        except (OSError, subprocess.TimeoutExpired):
                            process.kill()
                            process.wait(timeout=2)
        except (OSError, subprocess.TimeoutExpired) as error:
            row['errors'].append(str(error))
            raise
        finally:
            row['exit'] = process.poll() if process else None
            (output / 'cleanup.json').write_text(json.dumps(cleanup, indent=2), encoding='utf-8')
        if row['exit'] != 0 or row['cancelled'] or row['errors']:
            raise RuntimeError(f'Owned process failed: {row}')
        logs = text(output / f'{role}-stdio.log')
        if role == 'daemon':
            logs += '\n' + text(output / 'runtime.log')
        if DIAGNOSTIC.search(logs):
            raise RuntimeError(f'Unexpected engine diagnostic: {logs}')
        return logs

    build = owned('compile', [str(compiler), '-max_errors', '0', 'probe.dme'], 60)
    current.validate_compiler(subprocess.CompletedProcess([], 0, build, ''))
    if current.VERSION not in build or '0 errors, 0 warnings' not in build:
        raise RuntimeError(f'Pinned clean compilation required: {build}')
    owned('daemon', [str(daemon), 'probe.dmb', '-ip', '127.0.0.1', '-nowebclient', '-invisible', '-close', '-trusted', '-log', 'runtime.log'], 30)
    actual = text(output / 'result.txt').strip()
    if actual != expected:
        raise RuntimeError(f'Unexpected adapter result: {actual!r}; expected {expected!r}')
    (output / 'summary.json').write_text(json.dumps({'scope': __doc__, 'negative_control': args.negative_control,
        'result': actual, 'source_sha256': hashes, 'cleanup': cleanup, 'host_custody_verified': False}, indent=2), encoding='utf-8')
    print(f'PASS: adapter contract {args.negative_control or "positive"}')


if __name__ == '__main__':
    main()
