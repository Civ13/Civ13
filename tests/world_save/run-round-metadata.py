"""Ordinary world-save controls: historical 516.1681 by default, current Linux CI by opt-in.

The default retains Windows dm.exe/dd.exe support without claiming archive
identity. --current-linux-toolchain requires Linux and the existing CI layout:
BYOND/byond/bin/{DreamMaker,DreamDaemon} with BYOND/pinned.zip.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
import fixture_toolchain as current
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "new_z_budget"))
from z_budget_evidence import validate_compile as validate_historical_compile

DIAGNOSTIC = re.compile(r'runtime error:|bad ref|BUG:|##\s*ERROR\s*:|RUNTIME:|assertion failed|infinite loop|segmentation|fatal error', re.I)


def selected_runtime(bin_dir, archive):
    if archive is None: return None  # Preserve the historical 516.1681 path.
    spec = importlib.util.spec_from_file_location('round_current_runtime', Path(__file__).with_name('current_runtime.py'))
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module.select(bin_dir, archive)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--byond-archive', type=Path, help='Opt in to exact current Linux archive/member identity')
    parser.add_argument('--negative-control', choices=('restore', 'preflight', 'integrity'))
    parser.add_argument('--current-linux-toolchain', action='store_true',
                        help='Use the central current pin and BYOND/pinned.zip; Linux only. Default retains historical 516.1681.')
    args = parser.parse_args()
    if args.current_linux_toolchain and args.byond_archive:
        parser.error('Choose only one current toolchain mode')
    if args.current_linux_toolchain and sys.platform != 'linux':
        parser.error('--current-linux-toolchain requires Linux; omit it for the historical 516.1681 runner')
    root = Path(__file__).resolve().parents[2]
    fixture = root / 'tests/world_save'
    byond = args.byond_bin.absolute() if args.byond_archive else args.byond_bin.resolve(strict=True)
    runtime = selected_runtime(byond, args.byond_archive)
    windows = os.name == 'nt' and not args.current_linux_toolchain and not args.byond_archive
    compiler = byond / ('dm.exe' if windows else 'DreamMaker')
    daemon = byond / ('dd.exe' if windows else 'DreamDaemon')
    if not compiler.is_file() or not daemon.is_file():
        raise RuntimeError('Missing configured compiler or daemon')
    output = Path(tempfile.mkdtemp(prefix='civ13-round-metadata-'))
    print(f'Evidence: {output}', flush=True)
    loader = root / ('code/modules/persistence/functions.dm' if args.negative_control == 'integrity'
                     else 'code/modules/persistence/loading.dm')
    source = loader.read_text(encoding='utf-8')
    expected = 'PASS'
    if args.negative_control == 'restore':
        before = 'for(var/key in round_modes) map.vars[key] = round_modes[key]'
        after = 'for(var/key in round_modes) if(FALSE) map.vars[key] = round_modes[key]'
        expected = 'FAIL: round-mode flag lost: persistence'
    elif args.negative_control == 'preflight':
        before = 'if(isnull(round_mode_metadata(meta)))'
        after = 'if(FALSE && isnull(round_mode_metadata(meta)))'
        expected = 'FAIL: invalid round extension passed preflight: partial'
    elif args.negative_control == 'integrity':
        before = 'state["metadata"] != md5(file2text("map_saves/map.txt")) || '
        after = ''
        expected = 'FAIL: modern metadata tamper passed preflight'
    if args.negative_control:
        if source.count(before) != 1:
            raise RuntimeError('Control requires one unique production guard')
        source = source.replace(before, after, 1)
    (output / loader.name).write_text(source, encoding='utf-8')
    environment = (fixture / 'roundtrip.dme').read_text(encoding='utf-8')
    environment = environment.replace('#define FILE_DIR "../.."', f'#define FILE_DIR "{root.as_posix()}"')
    hashes = {}

    def include(match):
        original = (fixture / match.group(1)).resolve(strict=True)
        target = output / loader.name if original == loader else original
        hashes[original.relative_to(root).as_posix()] = hashlib.sha256(target.read_bytes()).hexdigest()
        return f'#include "{target.as_posix()}"'

    environment = re.sub(r'^#include "([^"]+)"', include, environment, flags=re.MULTILINE)
    (output / 'roundtrip.dme').write_text(environment, encoding='utf-8')
    hashes['generated_environment'] = hashlib.sha256(environment.encode()).hexdigest()
    processes = []

    def read(path):
        if path.stat().st_size > 1024 * 1024:
            raise RuntimeError(f'Output limit: {path.name}')
        return path.read_text(encoding='utf-8', errors='replace')

    def owned(role, command):
        row = {'role': role, 'pid': None, 'exit': None, 'cancelled': False}
        processes.append(row)
        process = None
        try:
            if runtime: runtime.before_launch(role, output)
            with (output / f'{role}-stdio.log').open('w', encoding='utf-8') as stream:
                if args.current_linux_toolchain:
                    row['runtime_identity'] = current.verify(command[0])
                process = subprocess.Popen(command, cwd=output, stdout=stream, stderr=subprocess.STDOUT,
                                           creationflags=subprocess.CREATE_NO_WINDOW if windows else 0)
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

    build = owned('compile', [str(compiler), '-max_errors', '0', 'roundtrip.dme'])
    if runtime:
        runtime.validate_compile(0, build, 'roundtrip.dmb')
    elif args.current_linux_toolchain:
        current.validate_compiler(subprocess.CompletedProcess([], 0, build, ''))
    else:
        validate_historical_compile(0, build, 'roundtrip.dmb')
    owned('daemon', [str(daemon), 'roundtrip.dmb', '-ip', '127.0.0.1', '-nowebclient', '-invisible', '-close', '-trusted', '-log', 'runtime.log'])
    actual = read(output / 'result.txt').strip()
    if actual != expected:
        raise RuntimeError(f'Unexpected round metadata result: {actual!r}; expected {expected!r}')
    (output / 'summary.json').write_text(json.dumps({'scope': __doc__, 'result': actual,
        'negative_control': args.negative_control, 'sources_sha256': hashes, 'processes': processes,
        'toolchain_mode': 'current-archive' if runtime else ('current-linux' if args.current_linux_toolchain else 'historical-516.1681'),
        'archive_identity_verified': bool(runtime or args.current_linux_toolchain),
        'opendream_verified': False, 'rpo_verified': False}, indent=2), encoding='utf-8')
    print(f'PASS: ordinary round metadata {args.negative_control or "positive"}')


if __name__ == '__main__':
    main()
