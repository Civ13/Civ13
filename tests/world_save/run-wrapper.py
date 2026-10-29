"""Actual loadmap wrapper controls in temporary offline BYOND storage."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
import fixture_toolchain as current



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--negative-control', choices=('metadata', 'recovery'))
    parser.add_argument('--roundtrip', action='store_true', help='Also execute ordinary legacy/v2 disk round trips')
    args = parser.parse_args()
    if args.roundtrip and args.negative_control:
        parser.error('Omission controls require the focused wrapper-only fixture')
    root = Path(__file__).resolve().parents[2]
    fixture = root / 'tests/world_save'
    if not args.prepare_only and not args.byond_bin:
        parser.error('--byond-bin is required for native execution')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    output = Path(tempfile.mkdtemp(prefix='civ13-restore-wrapper-'))
    print(f'Evidence: {output}', flush=True)
    source = (root / 'code/modules/persistence/functions.dm').read_text(encoding='utf-8')
    expected_failure = None
    if args.negative_control == 'metadata':
        before = 'if(storage.load_map_metadata() != TRUE)'
        after = 'if((storage.load_map_metadata() != TRUE) && FALSE)'
        expected_failure = 'metadata exact TRUE required'
    elif args.negative_control == 'recovery':
        before = '(operation.mutation_started && outcome.recovery_retained != TRUE)'
        after = '(operation.mutation_started && outcome.recovery_retained != TRUE && FALSE)'
        expected_failure = 'failed cleanup remains separately visible'
    if args.negative_control:
        if source.count(before) != 1:
            raise RuntimeError('Control must replace exactly one production guard')
        source = source.replace(before, after, 1)
    (output / 'functions.dm').write_text(source, encoding='utf-8')
    environment = (fixture / 'roundtrip.dme').read_text(encoding='utf-8')
    environment = environment.replace('#define FILE_DIR "../.."', f'#define FILE_DIR "{root.as_posix()}"')

    def include(match):
        original = (fixture / match.group(1)).resolve(strict=True)
        target = output / 'functions.dm' if original == root / 'code/modules/persistence/functions.dm' else original
        return f'#include "{target.as_posix()}"'

    environment = re.sub(r'^#include "([^"]+)"', include, environment, flags=re.MULTILINE)
    (output / 'wrapper.dme').write_text(environment, encoding='utf-8')
    if args.prepare_only:
        print('PASS: wrapper sources prepared; native compile/runtime not run')
        return
    byond = args.byond_bin.resolve(strict=True)
    compiler = byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    build = current.run_compiler([str(compiler), '-max_errors', '0', 'wrapper.dme'], cwd=output,
                           capture_output=True, text=True, timeout=120, creationflags=flags)
    compile_log = build.stdout + build.stderr
    (output / 'compile.log').write_text(compile_log, encoding='utf-8')
    if build.returncode or '0 errors, 0 warnings' not in compile_log or current.VERSION not in compile_log:
        print(compile_log)
        raise RuntimeError(f'Wrapper compile failed; see {output / "compile.log"}')
    daemon_args = [str(daemon), 'wrapper.dmb', '-ip', '127.0.0.1', '-nowebclient', '-invisible', '-close', '-trusted', '-log', 'runtime.log']
    if not args.roundtrip:
        daemon_args += ['-params', 'wrapper_only=1']
    runtime = current.run_daemon(daemon_args,
                             cwd=output, capture_output=True, text=True, timeout=120,
                             creationflags=flags)
    (output / 'daemon.log').write_text(runtime.stdout + runtime.stderr, encoding='utf-8')
    if runtime.returncode:
        print(runtime.stdout + runtime.stderr)
        raise RuntimeError('Wrapper daemon failed')
    runtime_log = (output / 'runtime.log').read_text(encoding='utf-8', errors='replace')
    runtime_diagnostics = runtime_log + '\n' + runtime.stdout + '\n' + runtime.stderr
    if re.search(r'runtime error:|bad ref|BUG:|##\s*ERROR\s*:|RUNTIME:|infinite loop|segmentation|assertion failed|fatal error', runtime_diagnostics, re.IGNORECASE):
        print(runtime_diagnostics)
        raise RuntimeError('Unexpected wrapper engine diagnostic')
    result = (output / 'result.txt').read_text(encoding='utf-8').strip()
    if expected_failure:
        if not result.startswith('FAIL:') or expected_failure not in result:
            raise RuntimeError(f'Control did not hit its intended assertion: {result}')
        print(f'PASS: {args.negative_control} omission caught by {expected_failure}')
    elif result != 'PASS':
        raise RuntimeError(f'Wrapper regression failed: {result}')
    else:
        print('PASS: actual restore wrapper and ordinary disk round trips' if args.roundtrip else 'PASS: actual restore wrapper fixture')


if __name__ == '__main__':
    main()
