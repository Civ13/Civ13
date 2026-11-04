"""Compile and run the synthetic zone-topology fixture in fresh native processes.

The preparer (run-durable-world.py --zone-topology --prepare-only) builds the
isolated full-source DME. This runner compiles it once with the pinned compiler,
then runs every mode in its own DreamDaemon process and working directory. A
reader receives only disk files copied from its writer, never shared memory.

Synthetic 8x8x2 evidence only: no map file, production save, player, client or
network listener is used. It does not measure real-map capacity.
"""
import argparse
import hashlib
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
PIN = json.loads((ROOT / 'tools/byond/version.json').read_text(encoding='utf-8'))['version']
DIAGNOSTIC = re.compile(r'runtime error:|bad ref|bad loc|BUG:|##\s*ERROR\s*:|assertion failed|infinite loop|'
                        r'segmentation|fatal error|unexpected runtime|\bOOM\b|out of memory|access violation|'
                        r'\bCRASH(?:ED)?\b', re.I)

# (mode, writer whose disk files the mode reads, exact assertion count,
#  expected named failure or None). Exact counts catch silently skipped checks.
# Negative readers must reject before ClearMap with unchanged saved files.
MALFORMED = ('duplicate-spawn', 'duplicate-zone', 'stale-zone', 'wrong-z', 'fractional',
             'incomplete', 'overlong', 'unsupported-schema', 'unsupported-topology')
CASES = (
    ('write', None, 3, None),
    ('read', 'write', 12, None),
    ('absent-zone', 'write', 14, None),
    *((mode, 'write', 12, None) for mode in MALFORMED),
    ('legacy-write', None, 3, None),
    ('legacy-read', 'legacy-write', 4, None),
    ('write-sequence', None, 76, None),
    ('read-sequence', 'write-sequence', 152, None),
    # #3311 item 1: switched roofs under topology schema 2 and the unique base type.
    ('roof-write', None, 6, None),
    ('roof-read', 'roof-write', 25, None),
    ('roof-omitted-settings', 'roof-write', 13, None),
    ('roof-absent-base', 'roof-write', 12, None),
    ('ambiguous-base-write', None, 10, None),
    ('ambiguous-base-read', 'roof-write', 14, None),
    # Item 3: local weather/intensity/icon state and lighting policy.
    ('weather-write', None, 3, None),
    ('weather-read', 'weather-write', 290, None),
    # Item 2: constructor admission, surprise constructor and retirement failure.
    ('surprise-write', None, 4, None),
    ('surprise-read', 'surprise-write', 18, None),
    ('retire-read', 'write', 17, None),
    ('admission', 'write', 22, None),
    # Item 4: late-join after intentionally empty or removed spawn groups.
    ('latejoin-read', 'write', 10, None),
)

# Source omission controls: each removes one production step and must fail at
# its named assertion, proving the positive reader would notice the omission.
CONTROLS = {
    'roof-projection': ('code/modules/persistence/loading.dm',
                        '\t\t\t\t\t\tprepare_zone_roof(level_entry_file(F, child), x, y, z, child, type)\n',
                        '\t\t\t\t\t\t// Omission control: skip schema-2 roof validation.\n',
                        'roof-absent-base', 'Malformed topology was accepted'),
    'roof-ambiguity': ('code/modules/persistence/zone_topology.dm',
                       '\t\tif(found) throw EXCEPTION("Ambiguous saved roof base zone")\n',
                       '\t\tif(found) return found\n',
                       'ambiguous-base-read', 'Malformed topology was accepted'),
    'zone-fields': ('code/modules/persistence/zone_topology.dm',
                    '\t\tdurable_metadata_restore_fields(A, row["fields"], persistence_zone_schema())\n', '',
                    'weather-read', 'Saved lighting policy differs'),
    'lighting-import': ('code/modules/persistence/zone_topology.dm',
                        '\t\t\t\telse T.lighting_clear_overlay()\n', '',
                        'weather-read', 'Imported turf lighting overlay differs from its zone policy'),
    'retire-check': ('code/modules/persistence/zone_topology.dm',
                     '\t\tif(A && !A.gc_destroyed && !A.gcDestroyed) throw EXCEPTION("Stale zone retirement failed")\n', '',
                     'retire-read', 'Failed staged topology was published'),
}


def need(value, message):
    if not value:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def prepare(control):
    prepared = subprocess.run([sys.executable, '-I', '-B', str(ROOT / 'tests/world_save/run-durable-world.py'),
                               '--zone-topology', '--prepare-only'], cwd=ROOT, capture_output=True, text=True,
                              timeout=60, check=True)
    source = Path(prepared.stdout.split('Retained evidence: ', 1)[1].splitlines()[0])
    dme = (source / 'probe.dme').read_text(encoding='utf-8')
    names = [p.name for p in source.glob('.durable_world_*.dm')]
    need(names, 'Preparation produced no generated sources')
    if control:
        relative, before, after = CONTROLS[control][:3]
        include = relative.replace('/', '\\')
        text = (ROOT / relative).read_text(encoding='utf-8')
        need(text.count(before) == 1 and dme.count(include) == 1, 'Omission control anchor changed: ' + control)
        generated = '.zone_control_' + control.replace('-', '_') + '.dm'
        (source / generated).write_text(text.replace(before, after, 1), encoding='utf-8', newline='\n')
        dme = dme.replace(include, generated)
        names.append(generated)
    return source, dme, names


def compile_fixture(byond, source, dme, names, output):
    prefix = '.zone_native_' + hashlib.sha256(os.urandom(16)).hexdigest()[:16]
    target = ROOT / (prefix + '.dme')
    staged = [ROOT / name for name in names]
    try:
        for name in names:
            need(not (ROOT / name).exists(), 'Generated source collision')
            shutil.copy2(source / name, ROOT / name)
        target.write_text(dme, encoding='utf-8', newline='\n')
        build = subprocess.run([str(byond / 'DreamMaker'), '-max_errors', '0', target.name], cwd=ROOT,
                               capture_output=True, text=True, timeout=300,
                               env=dict(os.environ, LD_LIBRARY_PATH=str(byond)))
        log = build.stdout + build.stderr
        (output / 'compile.log').write_text(log, encoding='utf-8')
        need(build.returncode == 0 and re.search(r' - 0 errors, 0 warnings', log), 'Fixture compile failed; see compile.log')
        need(re.search(r'DM compiler version ' + re.escape(PIN) + r'\b', log), 'Compiler is not the pinned ' + PIN)
        for suffix in ('.dmb', '.rsc'):
            shutil.copy2(target.with_suffix(suffix), output / ('fixture' + suffix))
    finally:
        for path in (target, target.with_suffix('.dmb'), target.with_suffix('.rsc'),
                     target.with_suffix('.int'), *staged):
            path.unlink(missing_ok=True)
    return dict(dmb_sha256=sha(output / 'fixture.dmb'), compile='0 errors, 0 warnings')


def run_case(byond, output, mode, writer, timeout):
    case = output / 'cases' / mode
    case.mkdir(parents=True)
    for suffix in ('.dmb', '.rsc'):
        shutil.copy2(output / ('fixture' + suffix), case / ('fixture' + suffix))
    (case / 'config').mkdir()
    shutil.copy2(ROOT / 'config/tips.txt', case / 'config/tips.txt')
    shutil.copytree(ROOT / 'config/names', case / 'config/names')
    if writer:
        origin = output / 'cases' / writer
        for folder in ('map_saves', 'zone-fixtures'):
            if (origin / folder).is_dir():
                shutil.copytree(origin / folder, case / folder)
        need((case / 'map_saves/save_complete.txt').is_file(), 'Writer left no completed generation for ' + mode)
    else:
        (case / 'map_saves').mkdir()
        for stage in ('baseline', 'changed', 'deleted'):
            (case / 'zone-fixtures' / stage).mkdir(parents=True)
    env = dict(PATH=str(byond) + ':/usr/bin:/bin', LD_LIBRARY_PATH=str(byond), HOME=str(case), LANG='C.UTF-8')
    started = time.monotonic()
    process = subprocess.Popen([str(byond / 'DreamDaemon'), 'fixture.dmb', '-ip', '127.0.0.1', '-nowebclient',
                                '-trusted', '-params', 'profile=gaia;zone_mode=' + mode, '-log', 'runtime.log'],
                               cwd=case, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               text=True, env=env, start_new_session=True)
    acknowledged = False
    try:
        while process.poll() is None:
            need(time.monotonic() - started < timeout, 'Native case timed out: ' + mode)
            marker = case / 'probe-port-closed.txt'
            if not acknowledged and marker.is_file() and marker.read_text().strip() == 'closed':
                (case / 'probe-port-closed.ack').write_text('closed\n')
                acknowledged = True
            time.sleep(0.02)
        stdout, stderr = process.communicate(timeout=10)
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=10)
    log = (case / 'runtime.log').read_text(encoding='utf-8', errors='replace') if (case / 'runtime.log').exists() else ''
    (case / 'daemon.log').write_text(stdout + stderr, encoding='utf-8')
    result_path = case / 'zone-result.json'
    failure = (case / 'zone-failure.txt').read_text(encoding='utf-8', errors='replace') if (case / 'zone-failure.txt').exists() else None
    result = json.loads(result_path.read_text(encoding='utf-8')) if result_path.is_file() else None
    return dict(mode=mode, writer=writer, exit=process.returncode, seconds=round(time.monotonic() - started, 3),
                acknowledged=acknowledged, result=result, failure=failure,
                diagnostics=[line for line in (log + stdout + stderr).splitlines() if DIAGNOSTIC.search(line)][:20])


def accept(row, expected_checks, expected_failure):
    result = row['result']
    if expected_failure:
        need(result is None and row['failure'] and expected_failure in row['failure'],
             f"{row['mode']} control did not fail at its named assertion: {row['failure']!r}")
        return
    need(row['acknowledged'], row['mode'] + ' never closed its listener')
    need(result and result.get('mode') == row['mode'] and not result.get('failed'),
         f"{row['mode']} failed: {row['failure'] or result}")
    need(result.get('checks') == expected_checks, f"{row['mode']} made {result.get('checks')} assertions, expected {expected_checks}")
    need(not row['diagnostics'], f"{row['mode']} native diagnostics: {row['diagnostics']}")


def run_suite(byond, output, control, only):
    output.mkdir(parents=True, exist_ok=True)
    source, dme, names = prepare(control)
    receipt = dict(pin=PIN, control=control, head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                   probe_sha256=sha(ROOT / 'tests/zone_persistence/probe.dm'),
                   production_sha256={p.relative_to(ROOT).as_posix(): sha(p) for p in sorted((ROOT / 'code/modules/persistence').glob('*.dm'))},
                   cases=[])
    try:
        receipt['build'] = compile_fixture(byond, source, dme, names, output)
    finally:
        shutil.copytree(source, output / 'prepared')
        shutil.rmtree(source, ignore_errors=True)
    if control:
        target = CONTROLS[control][3]
        writers = {mode: writer for mode, writer, _, _ in CASES}
        chain = [target]
        while writers[chain[0]]:
            chain.insert(0, writers[chain[0]])
        selected = [(mode, writer, checks, CONTROLS[control][4] if mode == target else None)
                    for mode, writer, checks, _ in CASES if mode in chain]
    else:
        selected = [case for case in CASES if not only or case[0] in only]
    try:
        for mode, writer, checks, expected in selected:
            row = run_case(byond, output, mode, writer, 120)
            receipt['cases'].append(row)
            accept(row, checks, expected)
            print(f"PASS {mode}: {row['result']['checks'] if row['result'] else 'named failure'} "
                  f"assertions in {row['seconds']}s", flush=True)
        receipt['success'] = True
    finally:
        receipt.setdefault('success', False)
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--control', choices=sorted(CONTROLS))
    parser.add_argument('--all-controls', action='store_true', help='Run the positive suite, then every omission control')
    parser.add_argument('--mode', action='append', default=[], help='Run only these modes (and nothing else)')
    args = parser.parse_args()
    byond = args.byond_bin.resolve(strict=True)
    output = args.output or Path(tempfile.mkdtemp(prefix='civ13-zone-native-'))
    output.mkdir(parents=True, exist_ok=True)
    print('Retained evidence: ' + str(output), flush=True)
    if args.all_controls:
        run_suite(byond, output / 'positive', None, None)
        for control in sorted(CONTROLS):
            run_suite(byond, output / control, control, None)
            print('CONTROL ' + control + ': failed at its named assertion', flush=True)
    else:
        run_suite(byond, output, args.control, set(args.mode))


if __name__ == '__main__':
    main()
