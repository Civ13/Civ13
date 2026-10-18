"""Boot the full production game headless and exercise base systems; fails on any runtime error.

No client connects and no port is opened. The world runs from a temporary copy of
the tracked config with webhooks, ToR bans and persistence saving disabled.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
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
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--negative-control', choices=CONTROLS)
    parser.add_argument('--lighting-load', action='store_true',
                        help='Also save and load the world, comparing turf lighting overlays')
    parser.add_argument('--lighting-restart', action='store_true',
                        help='Save in one process, then compare lighting after a fresh process imports the save')
    parser.add_argument('--diverge-turfs', action='store_true',
                        help='With --lighting-restart, change alternate sampled turfs before saving so the import replaces them')
    parser.add_argument('--map', help='Repository-relative .dmm replacing the default Nomads map include')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    if any(args.output.iterdir()):
        parser.error('Preserve existing evidence; use an empty output directory')
    byond = args.byond_bin.resolve()
    compiler = byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    head = git('rev-parse', 'HEAD').strip()
    (args.output / 'metadata.json').write_text(json.dumps({
        'head_sha': head, 'control': args.negative_control,
        'probe_sha256': hashlib.sha256((ROOT / 'tests/core_boot/probe.dm').read_bytes()).hexdigest(),
        'scope': 'Headless full-source boot and round start with processes running; no clients, rendering or long-term memory'}, indent=2), encoding='utf-8')
    (args.output / 'tested.patch').write_text(git('diff', 'HEAD'), encoding='utf-8')
    created = []
    try:
        source, runtime_site = generate(args.negative_control, created, args.lighting_load, args.map, args.lighting_restart, args.diverge_turfs)
        build = subprocess.run([str(compiler), '-max_errors', '0', str(source)], cwd=ROOT,
                               capture_output=True, text=True, timeout=600, creationflags=flags)
        compile_log = build.stdout + build.stderr
        (args.output / 'compile.log').write_text(compile_log, encoding='utf-8')
        if build.returncode or '516.1681' not in compile_log or '0 errors, 0 warnings' not in compile_log:
            raise RuntimeError('Pinned zero-error/zero-warning compilation failed:\n' + compile_log[-4000:])
        with tempfile.TemporaryDirectory(prefix='civ13-core-boot-') as temporary:
            work = Path(temporary)
            for suffix in ('.dmb', '.rsc'):
                shutil.copy2(source.with_suffix(suffix), work / ('probe' + suffix))
            for path in git('ls-files', '--', 'config').splitlines():
                destination = work / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / path, destination)
            if args.lighting_restart:
                config_path = work / 'config/config.txt'
                text = config_path.read_text(encoding='utf-8')
                if text.count('ALLOWED_GAMEMODES ALL') != 1:
                    raise RuntimeError('Expected ALLOWED_GAMEMODES ALL in config')
                config_path.write_text(text.replace('ALLOWED_GAMEMODES ALL', 'ALLOWED_GAMEMODES PERSISTENCE'), encoding='utf-8')
            phases = [('save', 'PASS: restart save phase'), ('load', 'PASS: restart import lighting')] if args.lighting_restart else [('boot', EXPECTED)]
            command = [str(daemon), 'probe.dmb'] + (['-invisible', '-close'] if os.name == 'nt' else []) + ['-trusted']
            rows = run_phases(command, work, phases)
            summary = {'phases': rows, 'diagnostics': rows[-1]['diagnostics'][:200],
                       'runtime_control_site': runtime_site}
            for path in work.rglob('*'):
                if path.is_file() and path.suffix in ('.log', '.txt', '.json') and path.stat().st_size < 8 * 1024 * 1024:
                    destination = args.output / 'runtime' / path.relative_to(work)
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, destination)
            (args.output / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
            receipt_path = work / 'runtime-control.json'
            runtime_receipt = json.loads(receipt_path.read_text(encoding='utf-8')) if receipt_path.exists() else None
        verify_results(rows, phases, args.negative_control, runtime_site, runtime_receipt)
        if args.negative_control:
            print(f'PASS expected mutation: {args.negative_control} detected ({rows[-1]["result"]})')
            return
        print(f'{rows[-1]["result"]} ({sum(row["wall_seconds"] for row in rows):.0f}s)')
    finally:
        for path in created:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
