"""Headless full-game Gaia acceptance run for generated ground snow (#3312).

Builds a temporary copy of civ13.dme with the Gaia map and
tests/snowfall_ground/full_game_probe.dm, runs it once in DreamDaemon from a
fresh evidence directory, samples the daemon's own CPU/RSS per probe phase and
validates result.json. No client, no live server files, no ports opened to
anything but the local daemon. Generated sources are removed afterwards.
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

MAP_DEFAULT = '#include "maps\\nomads\\nomads.dmm"'
MAP_GAIA = '#include "maps\\nomads\\nomads_gaia.dmm"'
SNOW_SOURCES = ('code/modules/1713/snowfall_ground.dm', 'code/processes/snowfall_ground.dm',
                'code/game/turfs/floor_attackby.dm', 'code/modules/1713/trench.dm',
                'code/game/turfs/floor_icon.dm', 'tests/snowfall_ground/full_game_probe.dm')
REQUIRED_CHECKS = ('registry_startup', 'season_WINTER', 'real_climate_accumulation', 'real_heat_sources_melt',
                   'weather_transitions', 'real_roof_exposure', 'connected_level_exposure',
                   'shovel_generated_grass', 'shovel_interrupted', 'melt_during_wait', 'concurrent_single_unit',
                   'spoon_generated', 'ant_generated', 'authored_transition', 'floor_update_icon',
                   'registry_lifecycle', 'qdel_destroy', 'disk_round_trip', 'registry_after_load',
                   'scale_accumulation', 'season_SPRING', 'seasonal_melt', 'registry_final')
RUNTIME = re.compile(r'runtime error: (.*)\nproc name: (.*)\n\s*source file: ([^,\n]+),(\d+)')


def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args], text=True)


def generate(repo, prefix):
    dme = (repo / 'civ13.dme').read_text(encoding='utf-8-sig')
    if dme.count(MAP_GAIA) == 1 and MAP_DEFAULT not in dme:
        pass  # Gaia is already the compiled default map.
    elif dme.count(MAP_DEFAULT) == 1 and MAP_GAIA not in dme:
        dme = dme.replace(MAP_DEFAULT, MAP_GAIA)
    else:
        raise RuntimeError('Expected exactly one Nomads or Gaia map include')
    dme += '\n#include "tests\\snowfall_ground\\full_game_probe.dm"\n'
    path = repo / (prefix + '.dme')
    path.write_text(dme, encoding='utf-8')
    return path


def sample(pid):
    try:
        status = (Path('/proc') / str(pid) / 'status').read_text().splitlines()
        memory = {row.split(':', 1)[0]: int(row.split()[1]) * 1024 for row in status if row.startswith(('VmRSS:', 'VmHWM:'))}
        fields = (Path('/proc') / str(pid) / 'stat').read_text().rsplit(')', 1)[1].split()
        cpu = (int(fields[11]) + int(fields[12])) / os.sysconf('SC_CLK_TCK')
        return {'rss_bytes': memory['VmRSS'], 'hwm_bytes': memory['VmHWM'], 'cpu_seconds': cpu}
    except (FileNotFoundError, ProcessLookupError, KeyError, ValueError, IndexError):
        return None


def run(command, output, deadline):
    samples = []
    started = time.monotonic()
    with (output / 'stdout.log').open('w') as out, (output / 'stderr.log').open('w') as err:
        process = subprocess.Popen(command, cwd=output, stdout=out, stderr=err)
        try:
            while process.poll() is None:
                elapsed = time.monotonic() - started
                if elapsed > deadline:
                    raise RuntimeError(f'Whole-daemon {deadline}-second deadline')
                row = sample(process.pid)
                if row:
                    try:
                        row['phase'] = json.loads((output / 'phase.json').read_text())['phase']
                    except (FileNotFoundError, json.JSONDecodeError, KeyError):
                        row['phase'] = 'startup'
                    row['elapsed_seconds'] = round(elapsed, 1)
                    samples.append(row)
                time.sleep(2)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=10)
            (output / 'os-samples.json').write_text(json.dumps(samples), encoding='utf-8')
    return process.returncode, time.monotonic() - started, samples


def phase_summary(samples):
    out = {}
    for phase in dict.fromkeys(row['phase'] for row in samples):
        rows = [row for row in samples if row['phase'] == phase]
        out[phase] = {'samples': len(rows), 'wall_seconds': rows[-1]['elapsed_seconds'] - rows[0]['elapsed_seconds'],
                      'cpu_seconds': round(rows[-1]['cpu_seconds'] - rows[0]['cpu_seconds'], 2),
                      'rss_first_mib': round(rows[0]['rss_bytes'] / 2**20, 1), 'rss_last_mib': round(rows[-1]['rss_bytes'] / 2**20, 1),
                      'rss_peak_mib': round(max(row['rss_bytes'] for row in rows) / 2**20, 1)}
    return out


def runtime_errors(output):
    text = ''
    for path in sorted(output.rglob('*')):
        if path.is_file() and (path.suffix in ('.log', '.txt')) and path.name not in ('compile.log', 'stdout.log'):
            text += path.read_text(errors='replace') + '\n'
    rows = {}
    for message, proc, source, line in RUNTIME.findall(text):
        source = source.replace('\\', '/')  # Windows daemons log backslash paths.
        key = f'{source}:{line}: {message.strip()} ({proc.strip()})'
        rows[key] = rows.get(key, 0) + 1
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--deadline', type=int, default=7200)
    parser.add_argument('--skip-persistence', action='store_true', help='development only; cannot pass')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    output = (args.output or Path(tempfile.gettempdir()) / ('civ13-snowfall-game-' + uuid.uuid4().hex)).resolve()
    if output.exists() and any(output.iterdir()):
        raise RuntimeError('Output evidence directory must be fresh')
    output.mkdir(parents=True, exist_ok=True)
    prefix = '.snowfall_game_' + uuid.uuid4().hex
    created = []
    head = git(repo, 'rev-parse', 'HEAD').strip()
    tree_status = git(repo, 'status', '--porcelain')  # Before the generated .dme exists.
    try:
        source = generate(repo, prefix)
        created += [source, source.with_suffix('.dmb'), source.with_suffix('.rsc'), source.with_suffix('.int')]
        manifest = {'tested_commit': head, 'working_tree_status': tree_status,
                    'map': 'maps/nomads/nomads_gaia.dmm',
                    'source_sha256': {name: hashlib.sha256((repo / name).read_bytes()).hexdigest() for name in SNOW_SOURCES + ('maps/nomads/nomads_gaia.dmm',)},
                    'adapters': ['Gaia map include (swapped in when not already the default)', 'probe appended', 'Linux global_init initialisers completed by the probe before world/New',
                                 'webhooks/ToRban off', 'round started via admin_started', 'weather process disabled; explicit production change_weather calls drive area weather', 'natural season timer cancelled after the forced WINTER; seasons are forced by the probe',
                                 'z-connection bit set only inside one connected-level check and restored']}
        (output / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
        compiler = args.byond_bin / 'DreamMaker'
        daemon = args.byond_bin / 'DreamDaemon'
        build = subprocess.run([str(compiler), '-max_errors', '0', source.name], cwd=repo, capture_output=True, text=True, timeout=600)
        log = build.stdout + build.stderr
        (output / 'compile.log').write_text(log, encoding='utf-8')
        if build.returncode or '0 errors, 0 warnings' not in log:
            raise RuntimeError('Probe compilation failed; see compile.log')
        shutil.copy2(source.with_suffix('.dmb'), output / 'probe.dmb')
        shutil.copy2(source.with_suffix('.rsc'), output / 'probe.rsc')
        for path in git(repo, 'ls-files', '--', 'config').splitlines():
            dest = output / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(repo / path, dest)
        command = [str(daemon), 'probe.dmb', '-trusted', '-ip', '127.0.0.1', '-params', 'tested_commit=' + head + ('&skip_persistence=1' if args.skip_persistence else ''), '-log', 'startup.log']
        code, wall, samples = run(command, output, args.deadline)
        (output / 'phase-summary.json').write_text(json.dumps(phase_summary(samples), indent=2), encoding='utf-8')
        errors = runtime_errors(output)
        (output / 'runtime-errors.json').write_text(json.dumps(errors, indent=2), encoding='utf-8')
        if not (output / 'result.json').exists():
            raise RuntimeError(f'No result.json (daemon exit {code}); see {output}')
        result = json.loads((output / 'result.json').read_text())
        passed = [row['check'] for row in result.get('checks', []) if row.get('passed')]
        missing = [name for name in REQUIRED_CHECKS if name not in passed]
        snow_errors = {key: count for key, count in errors.items() if any(name in key for name in SNOW_SOURCES)}
        summary = {'passed': bool(result.get('passed')) and not missing and not snow_errors, 'failure': result.get('failure'),
                   'failed_phase': result.get('failed_phase'), 'missing_checks': missing, 'snow_runtime_errors': snow_errors,
                   'other_runtime_error_sites': len(errors) - len(snow_errors), 'wall_seconds': round(wall), 'daemon_exit': code,
                   'tested_commit': head, 'output': str(output)}
        (output / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
        print(json.dumps(summary, indent=2))
        if not summary['passed']:
            raise SystemExit(1)
    finally:
        for path in created:
            if path.exists():
                path.unlink()


if __name__ == '__main__':
    main()
