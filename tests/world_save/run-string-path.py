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
    parser.add_argument('--datum-constructor-negative-control', action='store_true')
    parser.add_argument('--appearance-negative-control', action='store_true')
    parser.add_argument('--hud-negative-control', choices=('export', 'import', 'constructor'))
    parser.add_argument('--matrix-trace', action='store_true')
    parser.add_argument('--progress', action='store_true')
    parser.add_argument('--progress-fault-stage', choices=('save_entered', 'level_serialized', 'completion_marker'))
    parser.add_argument('--progress-fault-operation', choices=('delete', 'write', 'json'))
    parser.add_argument('--progress-negative-control', action='store_true')
    args = parser.parse_args()
    if args.hud_negative_control and any((args.negative_control, args.datum_constructor_negative_control,
                                         args.appearance_negative_control, args.matrix_trace, args.progress)):
        parser.error('Keep HUD controls separate from other mutations')
    if args.matrix_trace and (args.appearance_negative_control or args.datum_constructor_negative_control or args.negative_control or args.progress):
        parser.error('Keep matrix trace separate from other controls')
    if args.appearance_negative_control and (args.datum_constructor_negative_control or args.negative_control or args.progress):
        parser.error('Keep matrix field controls separate from constructor/metadata/progress controls')
    if args.datum_constructor_negative_control and (args.negative_control or args.progress):
        parser.error('Keep datum constructor controls separate from metadata/progress controls')
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

    def include(match):
        original = (fixture / match.group(1)).resolve(strict=True)
        source = original.read_text(encoding='utf-8')
        hashes[original.relative_to(root).as_posix()] = hashlib.sha256(original.read_bytes()).hexdigest()
        if original.name == 'functions.dm' and args.hud_negative_control == 'export':
            before = ('/mob/persistence_runtime_var(key)\n'
                      '\treturn (key in list("hud_used", "HUDneed", "HUDinventory", "HUDfrippery", "HUDprocess", "HUDtech", "hands", "pullin", "purged", "i_select", "m_select", "zone_sel")) || ..()\n')
            if source.count(before) != 1:
                raise RuntimeError('HUD export mutation target changed')
            source = source.replace(before, '', 1)
        if original.name == 'loading.dm' and args.hud_negative_control == 'import':
            before = 'if(object.persistence_runtime_var(v))'
            if source.count(before) != 1:
                raise RuntimeError('HUD import mutation target changed')
            source = source.replace(before, 'if(object.persistence_runtime_var(v) && v != "HUDneed" && v != "hud_used")', 1)
        if original.name == 'loading.dm' and args.hud_negative_control == 'constructor':
            before = '\t\tif(ispath(type, /obj/screen) || ispath(type, /datum/hud))\n\t\t\treturn null\n'
            if source.count(before) != 1:
                raise RuntimeError('HUD constructor mutation target changed')
            source = source.replace(before, '', 1)
        if original.name == 'functions.dm' and args.appearance_negative_control:
            before = ('/atom/persistence_runtime_var(key)\n'
                      '\treturn key == "appearance" || ..()\n')
            if source.count(before) != 1:
                raise RuntimeError('Appearance control needs exactly one composite exclusion')
            source = source.replace(before, '', 1)
        if original.name == 'loading.dm' and args.matrix_trace:
            before = '\t\t\t\tobject.vars[v] = decode_saved_value(savefile, savefile[v])\n'
            if source.count(before) != 1:
                raise RuntimeError('Matrix trace needs exactly one typed field assignment')
            after = ('\t\t\t\tvar/decoded = decode_saved_value(savefile, savefile[v])\n'
                     '\t\t\t\tif(v == "transform" || istype(object, /matrix) || "[ind]" == "2")\n'
                     '\t\t\t\t\tworld.log << "MATRIX_TRACE entry=[ind] field=[v] decoded=[decoded]"\n'
                     '\t\t\t\tif(v == "transform" && istype(decoded, /matrix))\n'
                     '\t\t\t\t\tvar/matrix/M = decoded\n'
                     '\t\t\t\t\tworld.log << "MATRIX_TRACE decoded coefficients=[M.a],[M.b],[M.c],[M.d],[M.e],[M.f]"\n'
                     '\t\t\t\t\tif(M.a == 8 && istype(object, /atom))\n'
                     '\t\t\t\t\t\tworld_save_matrix_trace_target = object\n'
                     '\t\t\t\tobject.vars[v] = decoded\n'
                     '\t\t\t\tif((v == "transform" || "[ind]" == "2") && istype(object, /atom))\n'
                     '\t\t\t\t\tvar/atom/AT = object\n'
                     '\t\t\t\t\tvar/matrix/M = AT.transform\n'
                     '\t\t\t\t\tworld.log << "MATRIX_TRACE entry=[ind] after=[v] assigned coefficients=[M.a],[M.b],[M.c],[M.d],[M.e],[M.f]"\n')
            source = source.replace(before, after, 1)
            traced = []
            for line_number, line in enumerate(source.splitlines(keepends=True), 1):
                if line.strip() and not line.lstrip().startswith('//'):
                    indent = line[:len(line) - len(line.lstrip('\t'))]
                    if len(indent) >= 3 and not line.lstrip().startswith(('else', 'catch')):
                        traced.append(indent + f'world_save_matrix_trace_state("before loading line {line_number}")\n')
                traced.append(line)
            source = ('var/atom/world_save_matrix_trace_target\n'
                      'var/world_save_matrix_trace_last\n'
                      '/proc/world_save_matrix_trace_state(stage)\n'
                      '\tif(!world_save_matrix_trace_target) return\n'
                      '\tvar/matrix/M = world_save_matrix_trace_target.transform\n'
                      '\tvar/current = "[M.a],[M.b],[M.c],[M.d],[M.e],[M.f]"\n'
                      '\tif(current != world_save_matrix_trace_last)\n'
                      '\t\tworld.log << "MATRIX_STATE [stage] ref=\\ref[world_save_matrix_trace_target] loc=[world_save_matrix_trace_target.x],[world_save_matrix_trace_target.y],[world_save_matrix_trace_target.z] coefficients=[current]"\n'
                      '\t\tworld_save_matrix_trace_last = current\n'
                      + ''.join(traced))
        if original == production and progress_saving is not None:
            source = progress_saving
        if original == production and args.negative_control:
            before = 'var/F0 = "map_saves/map.txt"'
            if source.count(before) != 1:
                raise RuntimeError('Negative control needs exactly one corrected metadata path')
            source = source.replace(before, 'var/F0 = file("map_saves/map.txt")', 1)
        if original.name == 'loading.dm' and args.datum_constructor_negative_control:
            before = ('\t\telse if(ispath(type, /atom))\n\t\t\tobject = new type(starting_loc)\n'
                      '\t\telse\n\t\t\t// Non-atom datums have no location argument. In particular, matrix\n'
                      '\t\t\t// construction must use its no-argument identity initializer.\n'
                      '\t\t\tobject = new type()\n')
            if source.count(before) != 1:
                raise RuntimeError('Datum control needs exactly one corrected constructor branch')
            source = source.replace(before, '\t\telse\n\t\t\tobject = new type(starting_loc)\n', 1)
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
    if args.hud_negative_control:
        expected = {'export': 'HUD runtime field exported', 'import': 'HUD runtime field imported',
                    'constructor': 'ownerless HUD constructor reached'}[args.hud_negative_control]
        failure = read(output / 'failure-name.txt').strip()
        if failure != expected or not actual.startswith('FAIL:'):
            raise RuntimeError(f'Wrong HUD negative failure: {actual!r}, {failure!r}')
    elif args.progress_negative_control:
        failure = read(output / 'failure-name.txt').strip()
        expected = f'Injected progress {args.progress_fault_operation} failure at {args.progress_fault_stage}'
        if failure != expected or not actual.startswith('FAIL:'):
            raise RuntimeError(f'Wrong diagnostic negative failure: {actual!r}, {failure!r}')
        marker = (output / 'map_saves/save_complete.txt').exists()
        if marker != (args.progress_fault_stage == 'completion_marker'):
            raise RuntimeError('Diagnostic negative marker state mismatch')
    elif args.appearance_negative_control:
        failure = read(output / 'failure-name.txt').strip()
        if failure != 'transform matrix coefficient a changed' or not actual.startswith('FAIL:'):
            raise RuntimeError(f'Wrong matrix field failure: {actual!r}, {failure!r}')
        if not (output / 'map_saves/save_complete.txt').exists():
            raise RuntimeError('Matrix control must complete export before restoration fails')
    elif args.datum_constructor_negative_control:
        failure = read(output / 'failure-name.txt').strip()
        if failure != 'datum constructor received location argument' or not actual.startswith('FAIL:'):
            raise RuntimeError(f'Wrong datum constructor failure: {actual!r}, {failure!r}')
        if (output / 'map_saves/save_complete.txt').exists():
            raise RuntimeError('Constructor control should fail before world export')
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
        'datum_constructor_negative_control': args.datum_constructor_negative_control,
        'appearance_negative_control': args.appearance_negative_control,
        'hud_negative_control': args.hud_negative_control,
        'matrix_trace': args.matrix_trace,
        'progress': args.progress, 'progress_fault_stage': args.progress_fault_stage,
        'progress_fault_operation': args.progress_fault_operation,
        'progress_negative_control': args.progress_negative_control,
        'sources_sha256': hashes, 'generated_sha256': generated, 'processes': processes,
        'opendream_verified': False, 'fresh_process_recovery_verified': False,
        'crash_rpo_verified': False, 'clean_shutdown_verified': False}, indent=2), encoding='utf-8')
    print(f'PASS: string-path regression {"negative" if args.negative_control else "positive"}')


if __name__ == '__main__':
    main()
