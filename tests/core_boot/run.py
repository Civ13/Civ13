"""Boot the full production game headless and exercise base systems; fails on any runtime error.

No client connects and no port is opened. The world runs from a temporary copy of
the tracked config with webhooks, ToR bans and persistence saving disabled.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
DIAGNOSTICS = re.compile(r'Infinite loop suspected|switching proc to background|runtime error|\bBad ref\b|\bBad loc\b|Cannot read null|Cannot execute null|\bBUG:|##\s*ERROR:|uncaught exception|CORE BOOT exception:|CORE BOOT runtime control:|fatal error|segmentation|assertion failed|\bRUNTIME:', re.I)
EXPECTED = 'PASS: boot, round start, scheduler, mob, chemistry and object lifecycle without world errors'
RUNTIME_CONTROL_MESSAGE = 'CORE_BOOT_EXPECTED_RUNTIME_CONTROL'
# Generated-source controls; each must be caught by the named mechanism.
CONTROLS = {
    'runtime': ('code/modules/reagents/Chemistry-Holder.dm',
                '/datum/reagents/proc/process_reactions()\n',
                '/datum/reagents/proc/process_reactions()\n\tif (core_boot_probe && core_boot_probe.current_phase == "chemistry" && my_atom == core_boot_probe.beaker)\n\t\tthrow EXCEPTION("' + RUNTIME_CONTROL_MESSAGE + '")\n',
                'FAIL: ' + RUNTIME_CONTROL_MESSAGE),
    # With --lighting-restart: a restored round with no daylight application, as
    # legacy saves had before restored lighting moved out of durable metadata.
    'restored-lighting': ('code/modules/lighting/lighting_system.dm',
                '\tP.lighting_revision++\n\treturn P.apply_daylight(time_of_day, P.lighting_revision)',
                '\treturn FALSE',
                'FAIL: overlays are visible after the restart import'),
}
DEADLINE_SECONDS = 1500


def load_current_runtime():
    """Reuse the reviewed passive Linux archive/member and compiler contracts."""
    spec = importlib.util.spec_from_file_location(
        'core_boot_current_runtime', ROOT / 'tests/world_save/current_runtime.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], text=True, encoding='utf-8')


def scan_logs(work):
    hits = []
    for path in work.rglob('*'):
        if path.is_file() and path.suffix in ('.log', '.txt') and path.name not in ('compile.log', 'result.txt'):
            text = path.read_text(errors='replace')
            for line in text.splitlines():
                if DIAGNOSTICS.search(line):
                    hits.append(f'{path.relative_to(work)}: {line.strip()[:300]}')
    return hits


def phase_healthy(phase):
    return (phase['returncode'] == 0 and not phase['timed_out'] and
            phase['wall_seconds'] < phase['deadline_seconds'])


def run_phases(command, work, phases, timeout=DEADLINE_SECONDS):
    rows = []
    for name, expected in phases:
        (work / 'result.txt').unlink(missing_ok=True)
        started = time.monotonic()
        timed_out = False
        with (work / (name + '-stdout.log')).open('w') as stdout, (work / (name + '-stderr.log')).open('w') as stderr:
            process = subprocess.Popen(command + ['-log', name + '-startup.log'], cwd=work,
                                       stdout=stdout, stderr=stderr,
                                       creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            try:
                process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                process.kill()
                process.wait(timeout=10)
        wall = time.monotonic() - started
        result_path = work / 'result.txt'
        result = result_path.read_text(errors='replace').strip() if result_path.exists() else ''
        if result_path.exists():
            shutil.copy2(result_path, work / (name + '-result.txt'))
        row = {'phase': name, 'returncode': process.returncode, 'timed_out': timed_out,
               'wall_seconds': wall, 'deadline_seconds': timeout,
               'result': result, 'diagnostics': scan_logs(work)}
        rows.append(row)
        if not phase_healthy(row) or result != expected or row['diagnostics']:
            break
    return rows


def verify_results(rows, phases, control=None, runtime_site=None, runtime_receipt=None):
    if not rows or len(rows) > len(phases):
        raise RuntimeError('Core boot phase sequence incomplete')
    for index, row in enumerate(rows):
        if row['phase'] != phases[index][0] or not phase_healthy(row):
            raise RuntimeError('Core boot phase did not exit cleanly: ' + json.dumps(row))
        if index < len(rows) - 1 and (row['result'] != phases[index][1] or row['diagnostics']):
            raise RuntimeError('Earlier core boot phase failed: ' + json.dumps(row))
    last = rows[-1]
    if control == 'runtime':
        if not runtime_site or not isinstance(runtime_receipt, dict):
            raise RuntimeError('Runtime control has no source-bound exception receipt')
        source_name = Path(str(runtime_receipt.get('file', '')).replace('\\', '/')).name
        expected = {'message': RUNTIME_CONTROL_MESSAGE, 'phase': 'chemistry',
                    'file': runtime_site['file'], 'line': runtime_site['line']}
        actual = dict(runtime_receipt, file=source_name)
        diagnostic = re.compile(r'(?:\[[^\]\r\n]+\]\s*)?CORE BOOT runtime control: ' +
                                re.escape(RUNTIME_CONTROL_MESSAGE) + r' at (?:.*[/\\])?' +
                                re.escape(runtime_site['file']) + ':' + str(runtime_site['line']))
        if (actual != expected or last['result'] != CONTROLS[control][3] or
                not last['diagnostics'] or
                any(not diagnostic.fullmatch(hit.split(': ', 1)[-1]) for hit in last['diagnostics'])):
            raise RuntimeError('Runtime control failed outside its intended exception: ' + json.dumps(last))
    elif control:
        if (len(rows) != len(phases) or last['diagnostics'] or
                not last['result'].startswith(CONTROLS[control][3])):
            raise RuntimeError('Negative control failed outside its intended assertion: ' + json.dumps(last))
    elif len(rows) != len(phases) or last['result'] != phases[-1][1] or last['diagnostics']:
        raise RuntimeError('Core boot assertions incomplete: ' + json.dumps(last))


def generate(control, created, lighting_load=False, map_path=None, lighting_restart=False, diverge=False):
    dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8-sig')
    runtime_site = None
    if diverge:
        dme = '#define CORE_BOOT_DIVERGE_TURFS\n' + dme
    if map_path:
        if not (ROOT / map_path).is_file():
            raise RuntimeError('Map not found: ' + map_path)
        default = re.compile(r'^#include "maps[\\/]nomads[\\/]nomads\.dmm"$', re.M)
        if len(default.findall(dme)) != 1:
            raise RuntimeError('Expected one default map include')
        dme = default.sub('#include "' + map_path.replace('/', '\\\\') + '"', dme)
    if control:
        path, old, new, _ = CONTROLS[control]
        source = (ROOT / path).read_text(encoding='utf-8-sig')
        if source.count(old) != 1:
            raise RuntimeError('Control target missing or ambiguous: ' + control)
        generated = ROOT / ('.core_boot_' + uuid.uuid4().hex + '_control.dm')
        mutated = source.replace(old, new, 1)
        generated.write_text(mutated, encoding='utf-8')
        if control == 'runtime':
            throw = 'throw EXCEPTION("' + RUNTIME_CONTROL_MESSAGE + '")'
            runtime_site = {'file': generated.name, 'line': mutated[:mutated.index(throw)].count('\n') + 1}
        created.append(generated)
        include = '#include "' + path.replace('/', '\\') + '"'
        if dme.count(include) != 1:
            raise RuntimeError('Control include missing: ' + path)
        dme = dme.replace(include, '#include "' + generated.name + '"')
    if lighting_load or lighting_restart:
        define = 'CORE_BOOT_LIGHTING_RESTART' if lighting_restart else 'CORE_BOOT_LIGHTING_LOAD'
        dme = '#define ' + define + '\n' + dme + '\n#include "tests\\core_boot\\lighting_load.dm"\n'
    dme += '\n#include "tests\\core_boot\\probe.dm"\n'
    source = ROOT / ('.core_boot_' + uuid.uuid4().hex + '.dme')
    source.write_text(dme, encoding='utf-8')
    created += [source, source.with_suffix('.dmb'), source.with_suffix('.rsc')]
    return source, runtime_site


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--byond-archive', type=Path, required=True,
                        help='Reviewed canonical-pin Linux archive/member identity')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--negative-control', choices=CONTROLS)
    parser.add_argument('--compile-only', action='store_true', required=True,
                        help='Compile source variants only; no DreamDaemon admission')
    parser.add_argument('--lighting-load', action='store_true',
                        help='Compile the in-process lighting save/load source variant')
    parser.add_argument('--lighting-restart', action='store_true',
                        help='Compile the fresh-process lighting source variant')
    parser.add_argument('--diverge-turfs', action='store_true')
    parser.add_argument('--map', help='Repository-relative .dmm replacing the default Nomads map include')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    if any(args.output.iterdir()):
        parser.error('Preserve existing evidence; use an empty output directory')
    byond = args.byond_bin.absolute()  # Preserve links for the identity verifier.
    compiler = byond / 'DreamMaker'
    head = git('rev-parse', 'HEAD').strip()
    metadata = {
        'head_sha': head, 'checkout_commit_sha': head,
        'checkout_tree_sha': git('rev-parse', 'HEAD^{tree}').strip(),
        'ci_event_head_sha': os.environ.get('CORE_BOOT_CI_HEAD_SHA'),
        'control': args.negative_control, 'compile_only': True,
        'lighting_load': args.lighting_load, 'lighting_restart': args.lighting_restart,
        'toolchain_mode': 'canonical-linux-archive',
        'canonical_manifest_sha256': hashlib.sha256((ROOT / 'tools/byond/version.json').read_bytes()).hexdigest(),
        'probe_sha256': hashlib.sha256((ROOT / 'tests/core_boot/probe.dm').read_bytes()).hexdigest(),
        'scope': 'Generated full-source fixture compilation only; no DreamDaemon or runtime assertions',
    }
    metadata_path = args.output / 'metadata.json'
    metadata_path.write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    (args.output / 'tested.patch').write_text(git('diff', 'HEAD'), encoding='utf-8')
    created = []
    try:
        runtime = load_current_runtime().select(byond, args.byond_archive)
        if runtime is None:
            raise ValueError('Canonical archive identity is required; no fallback')
        metadata['expected_byond'] = runtime.identity['version']
        metadata_path.write_text(json.dumps(metadata, indent=2), encoding='utf-8')
        source, runtime_site = generate(args.negative_control, created, args.lighting_load,
                                        args.map, args.lighting_restart, args.diverge_turfs)
        inputs = ['civ13.dme', 'tests/core_boot/probe.dm', 'tests/core_boot/run.py',
                  'tests/world_save/current_runtime.py', 'scripts/byond_runtime.py',
                  'scripts/byond_toolchain.py', 'tools/byond/version.json',
                  'tests/new_z_budget/z_budget_evidence.py']
        if args.lighting_load or args.lighting_restart:
            inputs.append('tests/core_boot/lighting_load.dm')
        if args.negative_control:
            inputs.append(CONTROLS[args.negative_control][0])
        (args.output / 'compile-inputs.json').write_text(json.dumps({
            'checkout_commit_sha': head, 'runtime_control_site': runtime_site,
            'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'inputs_sha256': {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in inputs},
            'generated_controls_sha256': {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                                          for path in created if path.suffix == '.dm'},
            'scope': 'Input hashes and control location captured before compilation; no runtime assertion'}, indent=2), encoding='utf-8')
        try:
            runtime.before_launch('compiler', args.output)
            build = subprocess.run([str(compiler), '-max_errors', '0', str(source)], cwd=ROOT,
                                   capture_output=True, text=True, timeout=600, creationflags=0)
        except subprocess.TimeoutExpired as error:
            def decoded(value):
                return value.decode('utf-8', errors='replace') if isinstance(value, bytes) else (value or '')
            (args.output / 'compile.log').write_text(decoded(error.stdout) + decoded(error.stderr), encoding='utf-8')
            (args.output / 'compile-status.json').write_text(json.dumps({
                'returncode': None, 'timed_out': True, 'deadline_seconds': 600,
                'runtime_executed': False}, indent=2), encoding='utf-8')
            raise
        compile_log = build.stdout + build.stderr
        (args.output / 'compile.log').write_text(compile_log, encoding='utf-8')
        (args.output / 'compile-status.json').write_text(json.dumps({
            'returncode': build.returncode, 'timed_out': False, 'deadline_seconds': 600,
            'runtime_executed': False}, indent=2), encoding='utf-8')
        runtime.validate_compile(build.returncode, compile_log, source.with_suffix('.dmb').name)
        (args.output / 'compile-summary.json').write_text(json.dumps({
            'head_sha': head, 'returncode': build.returncode,
            'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'runtime_control_site': runtime_site, 'runtime_executed': False,
            'toolchain_mode': 'canonical-linux-archive', 'expected_byond': runtime.identity['version'],
            'runtime_identity_receipt': 'runtime-identity.json',
            'scope': 'Compilation only; no runtime or negative-control detection verified'}, indent=2), encoding='utf-8')
        print('PASS: generated core-boot fixture compiled only (no DreamDaemon)')
    finally:
        for path in created:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
