"""Current Linux headless fixture; the historical 1681 caller stays unchanged."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
VERSION = '516.1688'
CONTROLS = {
    'bypass': 'vision 45 coefficient 1',
    'ordinary': 'vision 0 coefficient 1',
    'coverage': 'explicit fullbright coverage',
    'area-change': 'ChangeArea dispatches turf hook',
    'area-owner': 'superseded away-and-back skips outer hook',
    'area-policy': 'superseding same-fullbright policy clears actual overlay',
    'area-policy-dynamic': 'superseding same-dynamic policy builds missing overlay',
}
DIAGNOSTICS = r'runtime error|Runtime in|BUG:|CRASH|Infinite loop|Cannot read null'


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


legacy = module('historical_plane_fixture', Path(__file__).with_name('run.py'))
runtime = module('plane_current_runtime', ROOT / 'scripts/byond_runtime.py')


def source_identity():
    def git(*args):
        return subprocess.check_output(['git', *args], cwd=ROOT, timeout=15)
    return {'head': git('rev-parse', 'HEAD').decode().strip(),
            'tree': git('rev-parse', 'HEAD^{tree}').decode().strip(),
            'tracked_dirty': bool(git('status', '--porcelain', '--untracked-files=no')),
            'patch_sha256': hashlib.sha256(git('diff', '--binary', 'HEAD')).hexdigest()}


def selected_runtime(args):
    if sys.platform != 'linux':
        raise ValueError('Current lighting fixture requires Linux')
    identity = runtime.verify_linux(args.byond_bin, args.byond_archive)
    if identity['version'] != VERSION:
        raise ValueError('Current lighting fixture requires the reviewed ' + VERSION + ' pin')
    return identity


def combined(result):
    return result.stdout + ('\n' if result.stdout and not result.stdout.endswith('\n') else '') + result.stderr


def validate_compiler(result):
    text = combined(result)
    banners = re.findall(r'^DM compiler version[^\r\n]*', text, re.M)
    if (banners != ['DM compiler version ' + VERSION] or result.returncode
            or re.search(r'invalid file|file not found|cannot open', text, re.I)
            or not re.search(r'^probe.dmb - 0 errors, 0 warnings \(.+\)$', text, re.M)):
        raise RuntimeError('Plane fixture compilation failed')


def validate_runtime(result, logs, control, disabled):
    if result.returncode or re.search(DIAGNOSTICS, logs, re.I):
        raise RuntimeError('Unexpected native diagnostic')
    if control:
        if 'FAIL checks=' not in logs or CONTROLS[control] not in logs or 'PASS checks=' in logs:
            raise RuntimeError('Wrong negative-control outcome')
    elif not re.search(r'^PASS checks=' + str(8 if disabled else 287) + r' area_change_checks=64\s*$', logs, re.M) or 'FAIL checks=' in logs:
        raise RuntimeError('Plane fixture assertions failed')


def run_logged(command, cwd, log_name, timeout, env):
    # Same subprocess deadline, partial-output and failure receipts as the frozen
    # startup seam, with an explicit child loader environment for verified members.
    started = time.monotonic()
    receipt = {'command': command, 'timeout_seconds': timeout, 'state': 'launching'}
    receipt_path = cwd / (Path(log_name).stem + '-execution.json')
    receipt_path.write_text(json.dumps(receipt, indent=2))
    stdout = stderr = ''
    def decode(value):
        return value.decode(errors='replace') if isinstance(value, bytes) else value or ''
    try:
        result = subprocess.run(command, cwd=cwd, capture_output=True, text=True,
                                timeout=timeout, creationflags=0, env=env)
        stdout, stderr = result.stdout, result.stderr
        receipt.update(state='returned', returncode=result.returncode)
        return result
    except Exception as error:
        stdout, stderr = decode(getattr(error, 'stdout', '')), decode(getattr(error, 'stderr', ''))
        receipt.update(state='timeout' if isinstance(error, subprocess.TimeoutExpired) else 'launch_error',
                       exception_type=type(error).__name__, error=str(error))
        raise
    finally:
        (cwd / log_name).write_text(stdout + stderr)
        receipt['elapsed_seconds'] = time.monotonic() - started
        receipt_path.write_text(json.dumps(receipt, indent=2))


def execute(args):
    args.byond_bin, args.byond_archive = args.byond_bin.absolute(), args.byond_archive.absolute()
    output = args.output.absolute()
    if output.exists() or output.is_symlink():
        raise ValueError('Preserve existing lighting evidence; use a fresh output directory')
    env = os.environ.copy()
    if env.get('LD_PRELOAD') or env.get('LD_AUDIT'):
        raise ValueError('Loader injection is incompatible with pinned lighting execution')
    identity = selected_runtime(args)
    source = source_identity()
    if source['tracked_dirty']:
        raise ValueError('Current lighting fixture requires unchanged tracked source')
    env['LD_LIBRARY_PATH'] = str(args.byond_bin)
    env['BYOND_SYSTEM'] = str(args.byond_bin.parent)
    output.mkdir(parents=True)
    receipt = dict(status='running', source=source, runtime_identity=identity,
                   disabled=args.disabled, negative_control=args.negative_control,
                   runtime_checks=['admission'], compile_timeout_seconds=60, daemon_timeout_seconds=20,
                   identity_scope='Pinned archive and four bundled members; not system loader closure, pixels or production lifecycle')
    def verify(phase):
        if selected_runtime(args) != identity:
            raise RuntimeError('Runtime identity changed: ' + phase)
        receipt['runtime_checks'].append(phase)
    try:
        with tempfile.TemporaryDirectory(prefix='civ13-light-plane-1688-') as temporary:
            out = Path(temporary)
            try:
                files = legacy.prepare(args.negative_control, not args.disabled)
                for name, text in files.items():
                    (out / name).write_text(text)
                asset = out / 'icons/effects/icon.png'
                asset.parent.mkdir(parents=True)
                shutil.copyfile(ROOT / 'icons/effects/icon.png', asset)
                receipt['generated_sha256'] = {name: hashlib.sha256((out / name).read_bytes()).hexdigest() for name in files}
                receipt['asset_sha256'] = hashlib.sha256(asset.read_bytes()).hexdigest()
                verify('before-compiler')
                result = run_logged([str(args.byond_bin / 'DreamMaker'), 'probe.dme'], out, 'compile.log', 60, env)
                print(combined(result))
                validate_compiler(result)
                receipt['compiler_version'] = VERSION
                verify('before-daemon')
                result = run_logged([str(args.byond_bin / 'DreamDaemon'), 'probe.dmb', '-trusted', '-close', '-log', 'runtime.log'], out, 'daemon.log', 20, env)
                logs = result.stdout + result.stderr + (out / 'runtime.log').read_text(errors='replace')
                print(logs)
                validate_runtime(result, logs, args.negative_control, args.disabled)
                verify('after-daemon')
                if source_identity() != source:
                    raise RuntimeError('Tracked source changed during lighting execution')
                receipt['status'] = 'passed'
                if args.negative_control:
                    print('PASS: expected ' + args.negative_control + ' control caught')
            finally:
                for name in ('compile.log', 'compile-execution.json', 'daemon.log', 'daemon-execution.json', 'runtime.log'):
                    if (out / name).is_file():
                        shutil.copyfile(out / name, output / name)
    except BaseException as error:
        receipt.update(status='failed', exception_type=type(error).__name__, error=str(error))
        raise
    finally:
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--byond-archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--negative-control', choices=tuple(CONTROLS))
    parser.add_argument('--disabled', action='store_true')
    execute(parser.parse_args())


if __name__ == '__main__':
    main()
