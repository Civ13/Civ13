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
DIAGNOSTICS = re.compile(r'Infinite loop suspected|switching proc to background|runtime error|\bBad ref\b|\bBad loc\b|Cannot read null|Cannot execute null|\bBUG:|##\s*ERROR:', re.I)
EXPECTED = 'PASS: boot, round start, scheduler, mob, chemistry and object lifecycle without world errors'
# Generated-source controls; each must be caught by the named mechanism.
CONTROLS = {
    'runtime': ('code/modules/reagents/Chemistry-Holder.dm',
                '/datum/reagents/proc/process_reactions()\n',
                '/datum/reagents/proc/process_reactions()\n\tif (my_atom && istype(my_atom, /obj/item/weapon/reagent_containers/glass/beaker/large))\n\t\tvar/list/core_boot_control = null\n\t\tcore_boot_control.Cut()\n',
                'runtime diagnostic'),
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


def generate(control, created, lighting_load=False, map_path=None, lighting_restart=False):
    dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8-sig')
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
        generated.write_text(source.replace(old, new, 1), encoding='utf-8')
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
    return source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--negative-control', choices=CONTROLS)
    parser.add_argument('--lighting-load', action='store_true',
                        help='Also save and load the world, comparing turf lighting overlays')
    parser.add_argument('--lighting-restart', action='store_true',
                        help='Save in one process, then compare lighting after a fresh process imports the save')
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
        'scope': 'Headless full-source boot of the default map with processes running; no clients, round start, rendering or long-term memory'}, indent=2), encoding='utf-8')
    (args.output / 'tested.patch').write_text(git('diff', 'HEAD'), encoding='utf-8')
    created = []
    try:
        source = generate(args.negative_control, created, args.lighting_load, args.map, args.lighting_restart)
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
            summary = {'phases': []}
            hits = []
            result = ''
            wall = 0
            for name, phase_expected in phases:
                (work / 'result.txt').unlink(missing_ok=True)
                command = [str(daemon), 'probe.dmb']
                if os.name == 'nt':
                    command += ['-invisible', '-close']
                command += ['-trusted', '-log', name + '-startup.log']
                started = time.monotonic()
                with (work / (name + '-stdout.log')).open('w') as stdout, (work / (name + '-stderr.log')).open('w') as stderr:
                    process = subprocess.Popen(command, cwd=work, stdout=stdout, stderr=stderr, creationflags=flags)
                    try:
                        process.wait(timeout=DEADLINE_SECONDS)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=10)
                wall = time.monotonic() - started
                hits = scan_logs(work)
                result = (work / 'result.txt').read_text(errors='replace').strip() if (work / 'result.txt').exists() else ''
                shutil.copy2(work / 'result.txt', work / (name + '-result.txt')) if (work / 'result.txt').exists() else None
                summary['phases'].append({'phase': name, 'returncode': process.returncode, 'wall_seconds': round(wall, 1), 'result': result})
                if result != phase_expected or hits:
                    break
            for path in work.rglob('*'):
                if path.is_file() and path.suffix in ('.log', '.txt', '.json') and path.stat().st_size < 8 * 1024 * 1024:
                    destination = args.output / 'runtime' / path.relative_to(work)
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, destination)
            summary['diagnostics'] = hits[:200]
            (args.output / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
            expected_final = phases[-1][1]
        if args.negative_control:
            expected = CONTROLS[args.negative_control][3]
            detected = bool(hits) if expected == 'runtime diagnostic' else result.startswith(expected)
            if not detected:
                raise RuntimeError(f'Negative control {args.negative_control} was not detected: {summary}')
            print(f'PASS expected mutation: {args.negative_control} detected ({result or hits[0]})')
            return
        if hits or result != expected_final or wall >= DEADLINE_SECONDS:
            raise RuntimeError('Core boot failed: ' + json.dumps(summary, indent=2)[:6000])
        print(f'{result} ({wall:.0f}s)')
    finally:
        for path in created:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
