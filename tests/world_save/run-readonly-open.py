"""Windows readonly-attribute native-open go/no-go; no ACL custody claim."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import tempfile

DIAGNOSTIC = re.compile(r'runtime error:|bad ref|BUG:|##\s*ERROR\s*:|RUNTIME:|assertion failed|infinite loop|segmentation|fatal error', re.IGNORECASE)


def bounded_text(path):
    if path.stat().st_size > 1024 * 1024:
        raise RuntimeError(f'Output limit: {path.name}')
    return path.read_text(encoding='utf-8', errors='replace')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--negative-control', choices=('writable', 'value'))
    args = parser.parse_args()
    if os.name != 'nt':
        raise RuntimeError('This initial compatibility probe supports Windows only')
    root = Path(__file__).resolve().parents[2]
    byond = args.byond_bin.resolve(strict=True)
    compiler, daemon = byond / 'dm.exe', byond / 'dd.exe'
    if not compiler.is_file() or not daemon.is_file():
        raise RuntimeError('Missing configured BYOND executable')
    output = Path(tempfile.mkdtemp(prefix='civ13-readonly-open-'))
    print(f'Evidence: {output}', flush=True)
    source = (root / 'tests/world_save/readonly_open.dm').read_text(encoding='utf-8')
    if args.negative_control == 'value':
        guard = 'if(value != "A")'
        if source.count(guard) != 1:
            raise RuntimeError('Value control requires one unique guard')
        source = source.replace(guard, 'if(value != "WRONG")', 1)
    (output / 'probe.dm').write_text(source, encoding='utf-8')
    (output / 'probe.dme').write_text('#include "probe.dm"\n', encoding='utf-8')
    cleanup = []

    def run_owned(role, command, timeout):
        row = {'role': role, 'parent_pid': os.getpid(), 'command': command,
               'launch_requested_utc': datetime.now(timezone.utc).isoformat(),
               'pid': None, 'exit_code': None, 'cancelled': False, 'errors': []}
        cleanup.append(row)
        process = None
        try:
            with (output / f'{role}-stdio.log').open('w', encoding='utf-8') as stream:
                process = subprocess.Popen(command, cwd=output, stdout=stream,
                                           stderr=subprocess.STDOUT,
                                           creationflags=subprocess.CREATE_NO_WINDOW)
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
            row['exit_code'] = process.poll() if process else None
            (output / 'cleanup.json').write_text(json.dumps(cleanup, indent=2), encoding='utf-8')
        if row['cancelled'] or row['errors'] or row['exit_code'] != 0:
            raise RuntimeError(f'Owned process failed: {row}')
        log = bounded_text(output / f'{role}-stdio.log')
        runtime = output / f'{role}-runtime.log'
        if runtime.exists():
            log += '\n' + bounded_text(runtime)
        if DIAGNOSTIC.search(log):
            raise RuntimeError(f'Engine diagnostic in {role}: {log}')
        return log

    compile_log = run_owned('compile', [str(compiler), '-max_errors', '0', 'probe.dme'], 60)
    if '516.1681' not in compile_log or '0 errors, 0 warnings' not in compile_log:
        raise RuntimeError(f'Pinned clean compilation required: {compile_log}')

    def native(role, expected):
        run_owned(role, [str(daemon), 'probe.dmb', '-ip', '127.0.0.1', '-nowebclient', '-invisible', '-close', '-trusted',
                        '-log', f'{role}-runtime.log', '-params', f'role={role}'], 15)
        receipt = json.loads(bounded_text(output / f'{role}.json'))
        if (receipt.get('role') != role or receipt.get('byond_version') != 516
                or receipt.get('byond_build') != 1681 or receipt.get('result') != expected
                or (role == 'consumer' and receipt.get('value') != 'A')
                or bounded_text(output / f'{role}.result').strip() != expected):
            raise RuntimeError(f'Unexpected native receipt: {receipt}')
        return receipt

    seed = native('seed', 'PASS')
    selected = output / 'selected.sav'
    if not selected.is_file() or not 0 < selected.stat().st_size <= 1024 * 1024:
        raise RuntimeError('Synthetic seed outside fixture byte bound')
    if args.negative_control != 'writable':
        os.chmod(selected, stat.S_IREAD)
    writable = False
    try:
        with selected.open('r+b') as writer:
            first_byte = writer.read(1)
            writer.seek(0)
            writer.write(first_byte)
            writer.flush()
            writable = True
    except PermissionError:
        pass
    result = 'WRITABLE_BACKING_REJECTED' if writable else 'READONLY_WRITE_REFUSED'
    consumer = None
    if args.negative_control == 'writable':
        if result != 'WRITABLE_BACKING_REJECTED':
            raise RuntimeError('Writable omission missed its intended assertion')
    elif writable:
        raise RuntimeError('WRITABLE_BACKING_REJECTED')
    else:
        expected = 'UNSUPPORTED: READ_VALUE_MATCH' if args.negative_control == 'value' else 'PASS'
        consumer = native('consumer', expected)
    receipt = {'scope': __doc__, 'negative_control': args.negative_control,
               'write_attempt': result, 'seed': seed, 'consumer': consumer,
               'cleanup': cleanup, 'host_custody_verified': False}
    (output / 'summary.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(f'PASS: readonly-open compatibility oracle ({args.negative_control or "positive"})')


if __name__ == '__main__':
    main()
