"""Characterize existing cross-level saver failures; this suite does not claim repair."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / 'tests/world_save'
sys.path.insert(0, str(ROOT / 'tests/new_z_budget'))
from z_budget_evidence import DIAGNOSTIC, validate_compile

CASES = ('move-direct', 'move-nested', 'same-level', 'field-direct', 'field-nested',
         'field-backward-direct', 'field-backward-nested', 'unplaced',
         'missing-target', 'binder', 'pins')
PRODUCTION = (
    'code/predefines.dm',
    'code/modules/multiz/world_z_budget.dm',
    'code/modules/persistence/functions.dm',
    'code/modules/persistence/player_reclaim.dm',
    'code/modules/persistence/saving.dm',
    'code/modules/persistence/loading.dm',
    'code/modules/persistence/durable_graph.dm',
)
BASELINE_DEFECTS = {
    'move-direct': {'pattern': r'FAIL: movement export rejected: Durable metadata atom was exported more than once: type=/obj/item/cross_target first_z=1 first_ref=[1-9][0-9]* current_z=2 current_ref=[1-9][0-9]* native_z=2 turf_z=2'},
    'move-nested': {'pattern': r'FAIL: movement export rejected: Durable metadata atom was exported more than once: type=/obj/item/cross_target first_z=1 first_ref=[1-9][0-9]* current_z=2 current_ref=[1-9][0-9]* native_z=0 turf_z=2'},
    'same-level': 'FAIL: movement serialized more than one spatial parent',
    'field-nested': 'FAIL: foreign-level saved-variable reference was accepted',
    'field-backward-direct': 'FAIL: foreign-level saved-variable reference was accepted',
    'field-backward-nested': 'FAIL: foreign-level saved-variable reference was accepted',
    'unplaced': 'FAIL: unplaced first capture was silently skipped or duplicated',
}
CONTROLS = {
    'binder': ('durable_graph.dm',
               'if(node["ref"] && (node["ref"] != ref || node["z"] != z))',
               'if(FALSE)', 'binder', 'FAIL: original graph binder accepted a true duplicate'),
    'missing-target': ('durable_graph.dm',
                       'if(node["kind"] == "entry" && !node["ref"])',
                       'if(FALSE)', 'missing-target', 'FAIL: missing durable target was accepted'),
    'field-level': ('saving.dm',
                    'if(movable.z && movable.z != saving_z)',
                    'if(FALSE)', 'field-direct', 'FAIL: foreign-level saved-variable reference was accepted'),
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def replace_once(source, before, after, label):
    if source.count(before) != 1:
        raise RuntimeError(f'{label} requires exactly one source anchor')
    return source.replace(before, after, 1)


def extract_proc(source, path):
    matches = list(re.finditer(r'^' + re.escape(path) + r'\([^\n]*\)\n', source, re.M))
    if len(matches) != 1:
        raise RuntimeError(f'Expected one production proc: {path}')
    start = matches[0].start()
    next_proc = re.search(r'^/', source[matches[0].end():], re.M)
    end = matches[0].end() + next_proc.start() if next_proc else len(source)
    return source[start:end].rstrip() + '\n'


def adapt_stubs(source):
    for path, body in (
        ('/datum/durable_save_graph/proc/bind_entry(datum/A, z, ref)', '\treturn\n'),
        ('/datum/durable_save_graph/proc/accept_entry(z, ref, datum/A)', '\treturn\n'),
        ('/datum/durable_save_graph/proc/finish_export()', '\treturn null\n'),
    ):
        source = replace_once(source, path + '\n' + body, '', 'graph stub removal')
    return source


def prepare(output, control=None, root=ROOT):
    """Copy the real sources into an independent, fully relocatable packet."""
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    receipt = {'scope': __doc__, 'prepared_only': True, 'native_verified': False,
               'negative_control': control, 'source_sha256': {},
               'source_projections': {}, 'generated_sha256': {}}
    for relative in PRODUCTION:
        raw = (root / relative).read_bytes()
        source = raw.decode('utf-8-sig')
        receipt['source_sha256'][relative] = sha(raw)
        if control and Path(relative).name == CONTROLS[control][0]:
            _, before, after, _, _ = CONTROLS[control]
            source = replace_once(source, before, after, 'negative control')
        (output / Path(relative).name).write_text(source, encoding='utf-8')
    raw = (root / 'tests/world_save/stubs.dm').read_bytes()
    receipt['source_sha256']['tests/world_save/stubs.dm'] = sha(raw)
    (output / 'stubs.dm').write_text(adapt_stubs(raw.decode()), encoding='utf-8')
    for relative, name, projector in (
        ('code/_macros.dm', 'list_macro.dm', lambda source: '\n'.join(re.findall(r'^#define islist\(A\) .+$', source, re.M)) + '\n'),
        ('code/modules/persistence/durable_world.dm', 'reachability.dm',
         lambda source: extract_proc(source, '/map_storage/proc/validate_durable_reachability')),
    ):
        raw = (root / relative).read_bytes()
        projected = projector(raw.decode('utf-8-sig'))
        if name == 'list_macro.dm' and len(projected.splitlines()) != 1:
            raise RuntimeError('Expected exactly one production islist macro')
        receipt['source_sha256'][relative] = sha(raw)
        receipt['source_projections'][name] = {'source': relative, 'sha256': sha(projected.encode())}
        (output / name).write_text(projected, encoding='utf-8')
    for source_name, output_name in (('cross_level.dme', 'probe.dme'), ('cross_level_probe.dm', 'cross_level_probe.dm')):
        raw = (root / 'tests/world_save' / source_name).read_bytes()
        receipt['source_sha256']['tests/world_save/' + source_name] = sha(raw)
        (output / output_name).write_bytes(raw)
    receipt['base_commit'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    (output / 'tested.patch').write_bytes(subprocess.check_output(['git', 'diff', '--', 'code'], cwd=root))
    refresh_receipt(output, receipt)
    return receipt


def refresh_receipt(output, receipt):
    receipt['generated_sha256'] = {p.name: sha(p.read_bytes()) for p in output.iterdir() if p.suffix in ('.dm', '.dme')}
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')


def read_bounded(path):
    if path.stat().st_size > 1024 * 1024:
        raise RuntimeError(f'Output exceeds bounded read size: {path.name}')
    return path.read_text(encoding='utf-8', errors='replace')


def owned_process(command, cwd, role, timeout=120):
    row = {'role': role, 'pid': None, 'exit': None, 'cancelled': False}
    process = None
    log_path = cwd / f'{role}-stdio.log'
    try:
        with log_path.open('w', encoding='utf-8') as log:
            process = subprocess.Popen(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT,
                                       creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            row['pid'] = process.pid
            try:
                process.wait(timeout=timeout)
            finally:
                if process.poll() is None:
                    row['cancelled'] = True
                    process.terminate()
                    try:
                        process.wait(timeout=4)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=4)
    finally:
        row['exit'] = process.poll() if process else None
        (cwd / f'{role}-process.json').write_text(json.dumps(row, indent=2), encoding='utf-8')
    text = read_bounded(log_path)
    if row['cancelled'] or row['exit'] != 0 or DIAGNOSTIC.search(text):
        raise RuntimeError(f'Invalid {role} process evidence: {row}; see {log_path}')
    return text


def adjudicate(result, log, case, expected='PASS', minimum=3):
    # Native DM json_encode emits its TRUE/FALSE constants as numeric 1/0.
    done, failed = result.get('done'), result.get('runtime_failed')
    if (result.get('case') != case or type(done) not in (bool, int) or done != 1
            or type(failed) not in (bool, int) or failed != 0 or result.get('checks', 0) < minimum
            or result.get('port') or DIAGNOSTIC.search(log)):
        raise RuntimeError(f'Incomplete or contaminated native fixture evidence: {result}')
    actual = result.get('result')
    matched = isinstance(actual, str) and re.fullmatch(expected['pattern'], actual) if isinstance(expected, dict) else actual == expected
    if not matched:
        raise RuntimeError(f'Wrong assertion for {case}: {result.get("result")!r}; expected {expected!r}')


def native(output, byond, cases, receipt, expected=None, compile_only=False):
    byond = byond.resolve(strict=True)
    compiler = byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    if not compiler.is_file():
        raise RuntimeError('Configured pinned native compiler missing')
    build = owned_process([str(compiler), '-max_errors', '0', 'probe.dme'], output, 'compile')
    validate_compile(0, build)
    receipt['compiled'] = True
    receipt['prepared_only'] = False
    refresh_receipt(output, receipt)
    if compile_only:
        return
    daemon = byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    if not daemon.is_file():
        raise RuntimeError('Configured pinned native daemon missing')
    receipt['results'] = {}
    for case in cases:
        cwd = output / case
        cwd.mkdir()
        for suffix in ('.dmb', '.rsc'):
            source = output / ('probe' + suffix)
            if source.exists():
                (cwd / source.name).write_bytes(source.read_bytes())
        logs = owned_process([str(daemon), 'probe.dmb', '-ip', '127.0.0.1', '-nowebclient', '-invisible', '-close', '-trusted',
                              '-ip', '127.0.0.1', '-params', f'case={case}', '-log', 'native.log'], cwd, 'daemon')
        logs += '\n' + read_bounded(cwd / 'native.log')
        result = json.loads(read_bounded(cwd / 'result.json'))
        adjudicate(result, logs, case, (expected or {}).get(case, 'PASS'),
                   receipt.get('minimum_checks', {}).get(case, 3))
        receipt['results'][case] = result
        refresh_receipt(output, receipt)
    receipt['native_verified'] = True
    refresh_receipt(output, receipt)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--prepare-only', action='store_true')
    mode.add_argument('--compile-only', action='store_true')
    mode.add_argument('--run-native', action='store_true', help='Requires maintainer approval; launches trusted DreamDaemon')
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--case', choices=CASES, action='append')
    parser.add_argument('--expect-current-defects', action='store_true', help='Characterize the unchanged saver; does not claim a fix')
    parser.add_argument('--negative-control', choices=tuple(CONTROLS))
    args = parser.parse_args()
    if not args.prepare_only and not args.byond_bin:
        parser.error('--byond-bin is required for native compilation/execution')
    if args.negative_control and (args.expect_current_defects or args.case):
        parser.error('Mutation controls select one exact case and cannot combine with other modes')
    output = Path(tempfile.mkdtemp(prefix='civ13-cross-level-'))
    receipt = prepare(output, args.negative_control)
    cases = args.case or CASES
    expected = BASELINE_DEFECTS if args.expect_current_defects else {}
    if args.negative_control:
        _, _, _, case, result = CONTROLS[args.negative_control]
        cases, expected = (case,), {case: result}
    receipt.update(cases=list(cases), expected_results=expected,
                   characterization_only=args.expect_current_defects)
    refresh_receipt(output, receipt)
    print(f'Retained evidence: {output}', flush=True)
    if not args.prepare_only:
        native(output, args.byond_bin, cases, receipt, expected, args.compile_only)


if __name__ == '__main__':
    main()
