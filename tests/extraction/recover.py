"""Offline, exact-revision native extraction journal recovery. Never starts the game."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
import fixture_toolchain as current



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--store-root', required=True, type=Path)
    parser.add_argument('--owner', required=True)
    parser.add_argument('--action', choices=('inspect', 'complete-snapshot', 'retire-delivery', 'retire-vehicle', 'settle-loss'), default='inspect')
    parser.add_argument('--generation', type=int)
    parser.add_argument('--digest')
    parser.add_argument('--item')
    parser.add_argument('--offline-confirmation', choices=('sole-server-stopped',))
    parser.add_argument('--loss-confirmation', choices=('discard-account-stash', 'forfeit-paid-car'))
    args = parser.parse_args()
    if args.action != 'inspect' and (not args.offline_confirmation or not args.generation or args.generation < 1):
        parser.error('Mutation requires an exact generation and sole-server-stopped attestation')
    if args.action in ('complete-snapshot', 'settle-loss') and not args.digest:
        parser.error('Snapshot completion requires the inspected intent digest')
    if args.action == 'settle-loss' and not args.loss_confirmation:
        parser.error('Loss settlement permanently discards the entire account stash; explicit loss confirmation required')
    if args.action == 'retire-vehicle' and args.loss_confirmation != 'forfeit-paid-car':
        parser.error('Vehicle retirement permanently forfeits paid construction without refund; explicit loss confirmation required')
    if args.action in ('retire-delivery', 'retire-vehicle') and not args.item:
        parser.error('Retirement requires the inspected pending item identity')
    # Parameters use BYOND's delimiter grammar; do not accept delimiter injection.
    for value in (args.owner, args.digest, args.item):
        if value is not None and (not value or len(value) > 80 or not value.isascii() or not value.isalnum()):
            parser.error('Owner, digest and item must contain only bounded ASCII letters/digits')
    store = args.store_root.resolve(strict=True)
    if not store.is_dir():
        parser.error('Store root must be an existing directory')
    root = Path(__file__).resolve().parents[2]
    binary = args.byond_bin.resolve(strict=True)
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    report_name = 'recovery_report_' + uuid.uuid4().hex + '.json'
    log_name = report_name + '.log'
    binary_name = report_name + '.dmb'
    params = {'owner': args.owner, 'action': args.action, 'report': report_name}
    for key, value in (('generation', args.generation), ('digest', args.digest), ('item', args.item), ('offline', args.offline_confirmation), ('loss', args.loss_confirmation)):
        if value is not None:
            params[key] = str(value)
    try:
        with tempfile.TemporaryDirectory(prefix='civ13-offline-recovery-') as temporary:
            target = Path(temporary)
            (target / 'tests/extraction').mkdir(parents=True)
            (target / 'code/modules/1713/extraction').mkdir(parents=True)
            shutil.copy2(root / 'tests/extraction/recovery_operator.dm', target / 'tests/extraction/recovery_operator.dm')
            shutil.copy2(root / 'code/modules/1713/extraction/account_store.dm', target / 'code/modules/1713/extraction/account_store.dm')
            (target / 'recovery.dme').write_text('#include "tests/extraction/recovery_operator.dm"\n', encoding='utf-8')
            built = current.run_compiler([str(compiler), '-max_errors', '0', 'recovery.dme'], cwd=target, capture_output=True, text=True, timeout=60, creationflags=flags)
            if built.returncode or current.VERSION not in built.stdout or '0 errors, 0 warnings' not in built.stdout:
                raise RuntimeError('Pinned recovery compile failed: ' + built.stdout + built.stderr)
            # DreamDaemon uses the DMB directory as its runtime directory. A
            # unique temporary binary beside the store keeps fixture paths local.
            shutil.copy2(target / 'recovery.dmb', store / binary_name)
            platform = ['-invisible', '-close'] if os.name == 'nt' else []
            ran = current.run_daemon([str(daemon), binary_name, '-ip', '127.0.0.1', '-nowebclient', *platform, '-trusted', '-params', '&'.join(f'{k}={v}' for k, v in params.items()), '-log', log_name], cwd=store, capture_output=True, text=True, timeout=30, creationflags=flags)
            log = (store / log_name).read_text(errors='replace') if (store / log_name).exists() else ''
            if ran.returncode or any(marker in log.lower() for marker in ('runtime error', 'bad ref', '## error')):
                raise RuntimeError('Native recovery diagnostics: ' + log + ran.stdout + ran.stderr)
            if not (store / report_name).exists():
                raise RuntimeError('Native recovery did not complete: ' + log + ran.stdout + ran.stderr)
            report = json.loads((store / report_name).read_text(encoding='utf-8'))
            print(json.dumps(report, indent=2))
            return 0 if report['success'] else 1
    finally:
        # Only this invocation's generated report/log; journal/receipt untouched.
        (store / report_name).unlink(missing_ok=True)
        (store / log_name).unlink(missing_ok=True)
        (store / binary_name).unlink(missing_ok=True)


if __name__ == '__main__':
    raise SystemExit(main())
