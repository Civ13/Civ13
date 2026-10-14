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
    parser.add_argument('--progress', action='store_true')
    parser.add_argument('--progress-fault-stage', choices=('save_entered', 'level_serialized', 'completion_marker'))
    parser.add_argument('--progress-fault-operation', choices=('delete', 'write', 'json'))
    parser.add_argument('--progress-negative-control', action='store_true')
    parser.add_argument('--progress-clock-probe', action='store_true')
    parser.add_argument('--progress-clock-negative-control', action='store_true')
    args = parser.parse_args()
    if args.progress_clock_probe and (not args.progress or args.progress_fault_stage or args.progress_negative_control):
        parser.error('Clock probe requires --progress and separate fault controls')
    if args.progress_clock_negative_control and not args.progress_clock_probe:
        parser.error('Clock negative control requires --progress-clock-probe')
    if bool(args.progress_fault_stage) != bool(args.progress_fault_operation):
        parser.error('Both progress fault stage and operation are required')
    if (args.progress_fault_stage or args.progress_negative_control) and not args.progress:
        parser.error('Progress fault controls require --progress')
    if args.progress_negative_control and not args.progress_fault_stage:
        parser.error('Progress negative control requires a fault')
    if args.progress and args.negative_control:
        parser.error('Keep metadata and diagnostic negative controls separate')
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
    progress_saving = None
    progress_helper_include = ''
    if args.progress:
        import importlib.util
        generator_path = fixture / 'build-progress-probe.py'
        spec = importlib.util.spec_from_file_location('progress_generator', generator_path)
        generator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(generator)
        function_path = root / 'code/modules/persistence/functions.dm'
        progress_saving, _ = generator.instrument(production.read_text(encoding='utf-8'),
                                                  function_path.read_text(encoding='utf-8'))
        hashes['tests/world_save/build-progress-probe.py'] = hashlib.sha256(generator_path.read_bytes()).hexdigest()
        helper_path = fixture / 'progress-probe.dm'
        helper_target = output / 'progress-probe.dm'
        helper_target.write_bytes(helper_path.read_bytes())
        hashes['tests/world_save/progress-probe.dm'] = hashlib.sha256(helper_path.read_bytes()).hexdigest()
        generated[helper_target.name] = hashlib.sha256(helper_target.read_bytes()).hexdigest()
        # Retain fixture mutation-on-tick controls; this is an IO-isolation test,
        # not a performance measurement of the real game tick threshold.
        environment = '#define WORLD_SAVE_PROGRESS_TICK_CHECK fixture_tick_check()\n' + environment
        if args.progress_fault_stage:
            environment = (f'#define WORLD_SAVE_PROGRESS_FAULT_STAGE "{args.progress_fault_stage}"\n'
                           f'#define WORLD_SAVE_PROGRESS_FAULT_OPERATION "{args.progress_fault_operation}"\n'
                           + environment)
        if args.progress_negative_control:
            environment = '#define WORLD_SAVE_PROGRESS_PROPAGATE_FAULT\n' + environment
        progress_helper_include = f'\n#include "{helper_target.as_posix()}"\n'
        if args.progress_clock_probe:
            environment = '#define WORLD_SAVE_PROGRESS_TEST_CLOCK\n' + environment
            if args.progress_clock_negative_control:
                environment = '#define WORLD_SAVE_PROGRESS_COMPONENT_CLOCK\n' + environment
            clock_path = fixture / 'progress-clock-probe.dm'
            clock_target = output / clock_path.name
            clock_target.write_bytes(clock_path.read_bytes())
            hashes['tests/world_save/progress-clock-probe.dm'] = hashlib.sha256(clock_path.read_bytes()).hexdigest()
            generated[clock_target.name] = hashlib.sha256(clock_target.read_bytes()).hexdigest()
            progress_helper_include += f'#include "{clock_target.as_posix()}"\n'

    def include(match):
        original = (fixture / match.group(1)).resolve(strict=True)
        source = original.read_text(encoding='utf-8')
        hashes[original.relative_to(root).as_posix()] = hashlib.sha256(original.read_bytes()).hexdigest()
        if original == production and progress_saving is not None:
            source = progress_saving
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
            if args.progress:
                before = '\t\tcheck(map_storage.Save_World(), "export failed")\n'
                if source.count(before) != 1:
                    raise RuntimeError('Progress fixture needs one first export')
                expected = 'TRUE' if args.progress_fault_stage else 'FALSE'
                source = source.replace(before, before +
                    '\t\tcheck(!world_save_progress_active, "progress retained active flag after success")\n'
                    '\t\tcheck(fexists("map_saves/save_complete.txt"), "diagnostic changed completion marker")\n'
                    f'\t\tcheck(world_save_progress_unavailable == {expected}, "wrong diagnostic fault availability")\n', 1)
                if args.progress_clock_probe:
                    anchor = f'\t\tcheck(world_save_progress_unavailable == {expected}, "wrong diagnostic fault availability")\n'
                    source = source.replace(anchor, anchor + '\t\tworld_save_progress_test_clock_contract()\n', 1)
                for label in ('failed marker deletion changed active completion or retained lock',
                              'failed export retained completion marker or lock'):
                    line = next((line for line in source.splitlines(keepends=True) if label in line), None)
                    if line is None:
                        raise RuntimeError('Progress fixture missing failed-save control')
                    source = source.replace(line, line + '\t\t\tcheck(!world_save_progress_active, "progress retained active flag after save throw")\n', 1)
        target = output / original.name
        if target.exists():
            raise RuntimeError('Ambiguous source basename')
        target.write_text(source, encoding='utf-8')
        generated[target.name] = hashlib.sha256(target.read_bytes()).hexdigest()
        return f'#include "{target.as_posix()}"'

    environment = re.sub(r'^#include "([^"]+)"', include, environment, flags=re.MULTILINE)
    environment += progress_helper_include
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
    if args.progress_clock_negative_control:
        failure = read(output / 'failure-name.txt').strip()
        if failure != 'periodic progress not emitted after ten seconds' or not actual.startswith('FAIL:'):
            raise RuntimeError(f'Wrong clock negative failure: {actual!r}, {failure!r}')
        if not (output / 'map_saves/save_complete.txt').exists():
            raise RuntimeError('Clock control changed completed save marker')
    elif args.progress_negative_control:
        failure = read(output / 'failure-name.txt').strip()
        expected = f'Injected progress {args.progress_fault_operation} failure at {args.progress_fault_stage}'
        if failure != expected or not actual.startswith('FAIL:'):
            raise RuntimeError(f'Wrong diagnostic negative failure: {actual!r}, {failure!r}')
        marker = (output / 'map_saves/save_complete.txt').exists()
        if marker != (args.progress_fault_stage == 'completion_marker'):
            raise RuntimeError('Diagnostic negative marker state mismatch')
    elif args.negative_control:
        failure = read(output / 'failure-name.txt').strip()
        if failure != 'Could not write world-save metadata' or not actual.startswith('FAIL:'):
            raise RuntimeError(f'Wrong negative failure: {actual!r}, {failure!r}')
        if (output / 'map_saves/save_complete.txt').exists():
            raise RuntimeError('Failed metadata export published completion marker')
    elif actual != 'PASS':
        raise RuntimeError(f'Positive regression failed: {actual!r}')
    (output / 'summary.json').write_text(json.dumps({
        'scope': __doc__, 'result': actual, 'negative_control': args.negative_control,
        'progress': args.progress, 'progress_fault_stage': args.progress_fault_stage,
        'progress_fault_operation': args.progress_fault_operation,
        'progress_negative_control': args.progress_negative_control,
        'progress_clock_probe': args.progress_clock_probe,
        'progress_clock_negative_control': args.progress_clock_negative_control,
        'sources_sha256': hashes, 'generated_sha256': generated, 'processes': processes,
        'opendream_verified': False, 'fresh_process_recovery_verified': False,
        'crash_rpo_verified': False, 'clean_shutdown_verified': False}, indent=2), encoding='utf-8')
    negative = args.negative_control or args.progress_negative_control or args.progress_clock_negative_control
    print(f'PASS: string-path regression {"negative" if negative else "positive"}')


if __name__ == '__main__':
    main()
