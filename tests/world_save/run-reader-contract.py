"""Pinned savefile primitive observations in two isolated cooperating worlds."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

DIAGNOSTIC = re.compile(r'runtime error:|bad ref|BUG:|##\s*ERROR\s*:|RUNTIME:|infinite loop|segmentation|assertion failed|fatal error', re.IGNORECASE)


def bounded_text(path):
    if path.stat().st_size > 1024 * 1024:
        raise RuntimeError(f'Fixture output limit exceeded: {path.name}')
    return path.read_text(encoding='utf-8', errors='replace')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--negative-control', choices=('binding', 'close'))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    byond = args.byond_bin.resolve(strict=True)
    compiler = byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    for executable in (compiler, daemon):
        if not executable.is_file():
            raise RuntimeError(f'Missing configured executable: {executable}')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    output = Path(tempfile.mkdtemp(prefix='civ13-reader-contract-'))
    print(f'Evidence: {output}', flush=True)
    source = (root / 'tests/world_save/reader_contract.dm').read_text(encoding='utf-8')
    intended = None
    intended_role = None
    if args.negative_control == 'binding':
        before = 'request == operation && member && member.operation == operation'
        after = 'request && member && member.operation == operation'
        intended, intended_role = 'UNSUPPORTED: WRONG_OPERATION_REJECTED', 'owner'
    elif args.negative_control == 'close':
        before = '\t\tnative_reader = null'
        after = '\t\t// Omission: retain the native savefile after logical close.'
        intended, intended_role = 'UNSUPPORTED: PEER_LOCK_AFTER_OWNER_CLOSE', 'peer'
    if args.negative_control:
        if source.count(before) != 1:
            raise RuntimeError('Control must alter exactly one fixture boundary')
        source = source.replace(before, after, 1)
    (output / 'probe.dm').write_text(source, encoding='utf-8')
    (output / 'probe.dme').write_text('#include "probe.dm"\n', encoding='utf-8')
    build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=output,
                           capture_output=True, text=True, timeout=60, creationflags=flags)
    compile_log = build.stdout + build.stderr
    (output / 'compile.log').write_text(compile_log, encoding='utf-8')
    if build.returncode or '516.1681' not in compile_log or '0 errors, 0 warnings' not in compile_log:
        print(compile_log)
        raise RuntimeError('Reader-contract compilation failed')
    processes = {}
    streams = {}
    cancelled = []
    cleanup_errors = []
    runtime_deadline = time.monotonic() + 45

    def launch(role):
        stream = (output / f'{role}-stdio.log').open('w', encoding='utf-8')
        streams[role] = stream
        processes[role] = subprocess.Popen(
            [str(daemon), 'probe.dmb', '-invisible', '-close', '-safe', '-log',
             f'{role}-runtime.log', '-params', f'role={role}'], cwd=output,
            stdout=stream, stderr=subprocess.STDOUT, creationflags=flags)

    try:
        launch('owner')
        while not (output / 'owner_locked.txt').exists():
            if (output / 'owner.result').exists() or processes['owner'].poll() is not None:
                break
            if time.monotonic() >= runtime_deadline:
                raise TimeoutError('Owner startup exceeded runtime deadline')
            time.sleep(0.05)
        if (output / 'owner_locked.txt').exists():
            launch('peer')
        while any(process.poll() is None for process in processes.values()):
            outcomes = [bounded_text(output / f'{role}.result').strip()
                        for role in processes if (output / f'{role}.result').exists()]
            if any(value != 'PASS' for value in outcomes):
                break
            if time.monotonic() >= runtime_deadline:
                raise TimeoutError('Reader-contract runtime exceeded 45 seconds')
            time.sleep(0.05)
    finally:
        for role, process in processes.items():
            try:
                if process.poll() is None and (output / f'{role}.result').exists():
                    try:
                        process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        pass
                if process.poll() is None:
                    cancelled.append(role)
                    try:
                        process.terminate()
                        process.wait(timeout=4)
                    except (OSError, subprocess.TimeoutExpired):
                        process.kill()
                        process.wait(timeout=2)
            except (OSError, subprocess.TimeoutExpired) as error:
                cleanup_errors.append(f'{role}: {error}')
        for stream in streams.values():
            try:
                stream.close()
            except OSError as error:
                cleanup_errors.append(f'log close: {error}')
        cleanup = {role: {'pid': process.pid, 'exit_code': process.poll(),
                          'terminated_by_runner': role in cancelled}
                   for role, process in processes.items()}
        (output / 'cleanup.json').write_text(
            json.dumps({'processes': cleanup, 'errors': cleanup_errors}, indent=2), encoding='utf-8')
    if cleanup_errors:
        raise RuntimeError(f'Owned-process cleanup failed: {cleanup_errors}')
    receipts = {}
    for role, process in processes.items():
        diagnostics = bounded_text(output / f'{role}-stdio.log')
        runtime_log = output / f'{role}-runtime.log'
        if runtime_log.exists():
            diagnostics += '\n' + bounded_text(runtime_log)
        if DIAGNOSTIC.search(diagnostics):
            print(diagnostics)
            raise RuntimeError(f'Unexpected engine diagnostic in {role}')
        receipt = output / f'{role}.json'
        if receipt.exists():
            receipts[role] = json.loads(bounded_text(receipt))
            if receipts[role].get('byond_version') != 516 or receipts[role].get('byond_build') != 1681:
                raise RuntimeError('Runtime receipt is not BYOND 516.1681')
    if intended:
        receipt = receipts.get(intended_role, {})
        result_file = output / f'{intended_role}.result'
        if receipt.get('result') != intended or not result_file.exists() or bounded_text(result_file).strip() != intended:
            raise RuntimeError(f'Control missed intended assertion: {receipts}')
        if processes[intended_role].returncode != 0 or intended_role in cancelled:
            raise RuntimeError('Intended assertion world did not exit cleanly')
        for role, process in processes.items():
            if role == intended_role:
                continue
            result_file = output / f'{role}.result'
            receipt_present = role in receipts
            result_present = result_file.exists()
            if receipt_present != result_present:
                raise RuntimeError(f'Counterpart receipt/result disagreement: {role}')
            if result_present:
                if (receipts[role].get('result') != 'PASS'
                        or bounded_text(result_file).strip() != 'PASS'
                        or process.returncode != 0 or role in cancelled):
                    raise RuntimeError(f'Unrelated counterpart failure: {role}')
            elif role not in cancelled:
                raise RuntimeError(f'Counterpart exited without a result: {role}')
        print(f'PASS: {args.negative_control} omission caught by {intended}')
    else:
        if set(receipts) != {'owner', 'peer'} or cancelled:
            raise RuntimeError(f'Incomplete primitive receipts: {receipts}')
        for role, process in processes.items():
            if process.returncode != 0 or receipts[role].get('result') != 'PASS' or bounded_text(output / f'{role}.result').strip() != 'PASS':
                raise RuntimeError(f'Unsupported primitive outcome: {receipts}')
        print('PASS: native cooperating-world lock receipts and fixture binding guards')
    summary = {'scope': 'cooperating BYOND savefile API and fixture guards only',
               'host_exclusion_verified': False, 'production_provider_available': False,
               'negative_control': args.negative_control, 'receipts': receipts, 'cleanup': cleanup}
    (output / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
