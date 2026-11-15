"""Headless full-game walkthrough of the natural crop bootstrap (#3048).

Builds a temporary copy of civ13.dme with the North America map and
tests/natural_bootstrap/full_game_probe.dm, then runs DreamDaemon twice from one
fresh evidence directory configured as a persistent book research world:

  write  a fresh agent-autospawned Nomad walks to fresh water, founds a faction,
         studies Basic Toolmaking, knaps a flint knife, makes a digging stick,
         ploughs, forages seed from wild bushes, plants it and the world is saved
  read   a new daemon restores that save by itself; crop stage, soil and the
         character are compared with the write stage's manifest, the crop grows
         on, is harvested, eaten and replanted from its own seed

No client, no live server files, no ports opened to anything but the local
daemon. Generated sources are removed afterwards.
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

MAP_INCLUDE = re.compile(r'^#include "maps\\nomads\\[a-z_]+\.dmm"$', re.M)
MAP = 'maps/nomads/nomads_americas_north.dmm'
MAP_LINE = '#include "maps\\nomads\\nomads_americas_north.dmm"'
PROBE = 'tests/natural_bootstrap/full_game_probe.dm'
SOURCES = (PROBE, MAP, 'code/game/objects/farming.dm', 'code/game/turfs/floor_attackby.dm', 'code/game/objects/structures/wild.dm',
           'code/modules/1713/flint_mining.dm', 'code/modules/research_tree/book_research.dm', 'code/modules/agent_control/agent_characters.dm')
WRITE_CHECKS = ('fresh_character', 'walked_to_fresh_water', 'founded_and_studied', 'flint_knife', 'digging_stick', 'ploughed_plots',
                'foraged_seed_planted', 'crop_growing_before_save', 'world_saved')
READ_CHECKS = ('character_restored', 'crop_and_soil_restored', 'growth_continued_after_restore', 'harvested', 'replanted_from_own_seed')
RUNTIME = re.compile(r'runtime error: (.*)\nproc name: (.*)\n\s*source file: ([^,\n]+),(\d+)')
AGENT_TOKEN = 'natural-bootstrap-walkthrough-local-token-0001'


def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args], text=True)


def generate(repo, prefix):
    dme = (repo / 'civ13.dme').read_text(encoding='utf-8-sig')
    if len(MAP_INCLUDE.findall(dme)) != 1:
        raise RuntimeError('Expected exactly one Nomads map include')
    dme = MAP_INCLUDE.sub(lambda _: MAP_LINE, dme)
    dme += '\n#include "tests\\natural_bootstrap\\full_game_probe.dm"\n'
    path = repo / (prefix + '.dme')
    path.write_text(dme, encoding='utf-8')
    return path


def configure(repo, output):
    """The repository's config, set to a persistent world with one autospawned agent character."""
    for path in git(repo, 'ls-files', '--', 'config').splitlines():
        dest = output / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(repo / path, dest)
    config = output / 'config' / 'config.txt'
    text = config.read_text(encoding='utf-8', errors='replace')
    if text.count('\nALLOWED_GAMEMODES ALL') != 1 or text.count('\nPERSISTENCE_REBOOT_HOUR ') != 1:
        raise RuntimeError('config.txt no longer has the expected gamemode and reboot-hour lines')
    text = text.replace('\nALLOWED_GAMEMODES ALL', '\nALLOWED_GAMEMODES PERSISTENCE')
    text = text.replace('\nPERSISTENCE_REBOOT_HOUR ', '\n#PERSISTENCE_REBOOT_HOUR ')
    config.write_text(text, encoding='utf-8')
    (output / 'config' / 'agent-control.txt').write_text(
        f'agent bootstrap {AGENT_TOKEN} characters\nautospawn bootstrap Rowan\n', encoding='utf-8')


def sample(pid):
    try:
        status = (Path('/proc') / str(pid) / 'status').read_text().splitlines()
        memory = {row.split(':', 1)[0]: int(row.split()[1]) * 1024 for row in status if row.startswith(('VmRSS:', 'VmHWM:'))}
        fields = (Path('/proc') / str(pid) / 'stat').read_text().rsplit(')', 1)[1].split()
        cpu = (int(fields[11]) + int(fields[12])) / os.sysconf('SC_CLK_TCK')
        return {'rss_bytes': memory['VmRSS'], 'hwm_bytes': memory['VmHWM'], 'cpu_seconds': cpu}
    except (FileNotFoundError, ProcessLookupError, KeyError, ValueError, IndexError):
        return None


def run(command, output, stage, deadline, stall):
    samples = []
    started = time.monotonic()
    with (output / f'stdout-{stage}.log').open('w') as out, (output / f'stderr-{stage}.log').open('w') as err:
        process = subprocess.Popen(command, cwd=output, stdout=out, stderr=err)
        try:
            while process.poll() is None:
                elapsed = time.monotonic() - started
                if elapsed > deadline:
                    raise RuntimeError(f'{stage} stage passed its {deadline}-second deadline')
                try:
                    quiet = time.time() - (output / 'phase.json').stat().st_mtime
                except FileNotFoundError:
                    quiet = elapsed
                if quiet > stall:
                    raise RuntimeError(f'{stage} stage made no phase progress for {stall} seconds')
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
            (output / f'os-samples-{stage}.json').write_text(json.dumps(samples), encoding='utf-8')
    return process.returncode, time.monotonic() - started, samples


def phase_summary(samples):
    out = {}
    for phase in dict.fromkeys(row['phase'] for row in samples):
        rows = [row for row in samples if row['phase'] == phase]
        out[phase] = {'wall_seconds': round(rows[-1]['elapsed_seconds'] - rows[0]['elapsed_seconds'], 1),
                      'cpu_seconds': round(rows[-1]['cpu_seconds'] - rows[0]['cpu_seconds'], 2),
                      'rss_peak_mib': round(max(row['rss_bytes'] for row in rows) / 2**20, 1)}
    return out


def runtime_errors(output, stage):
    text = ''
    for name in (f'startup-{stage}.log', f'stderr-{stage}.log'):
        path = output / name
        if path.exists():
            text += path.read_text(errors='replace') + '\n'
    rows = {}
    for message, proc, source, line in RUNTIME.findall(text):
        source = source.replace('\\', '/')
        key = f'{source}:{line}: {message.strip()} ({proc.strip()})'
        rows[key] = rows.get(key, 0) + 1
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--deadline', type=int, default=3600, help='seconds allowed for each daemon run')
    parser.add_argument('--stall', type=int, default=1500, help='seconds one probe phase may take before the run is stopped')
    parser.add_argument('--seed', type=int, default=3048, help='random seed: fixes the start tile the production picker draws')
    parser.add_argument('--stage', choices=('both', 'write', 'read'), default='both',
                        help='development only: read reuses the save in an existing --output directory')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    output = (args.output or Path(tempfile.gettempdir()) / ('civ13-natural-bootstrap-' + uuid.uuid4().hex)).resolve()
    if args.stage != 'read' and output.exists() and any(output.iterdir()):
        raise RuntimeError('Output evidence directory must be fresh')
    output.mkdir(parents=True, exist_ok=True)
    prefix = '.natural_bootstrap_' + uuid.uuid4().hex
    created = []
    head = git(repo, 'rev-parse', 'HEAD').strip()
    tree_status = git(repo, 'status', '--porcelain')  # Before the generated .dme exists.
    try:
        source = generate(repo, prefix)
        created += [source, source.with_suffix('.dmb'), source.with_suffix('.rsc'), source.with_suffix('.int')]
        manifest = {'tested_commit': head, 'working_tree_status': tree_status, 'map': MAP, 'seed': args.seed,
                    'source_sha256': {name: hashlib.sha256((repo / name).read_bytes()).hexdigest() for name in SOURCES},
                    'adapters': ['North America map include swapped in', 'probe appended',
                                 'Linux global_init initialisers completed by the probe before world/New', 'webhooks/ToRban off',
                                 'config: ALLOWED_GAMEMODES PERSISTENCE, daily reboot hour off, one agent with an autospawn line',
                                 'round started via admin_started', 'weather process disabled and the natural season timer held',
                                 'the agent body follows the player chapter rules (recipe_knowledge_exempt is FALSE)',
                                 'fixed random seed']}
        (output / 'run-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
        compiler = args.byond_bin / 'DreamMaker'
        daemon = args.byond_bin / 'DreamDaemon'
        build = subprocess.run([str(compiler), '-max_errors', '0', source.name], cwd=repo, capture_output=True, text=True, timeout=900)
        log = build.stdout + build.stderr
        (output / 'compile.log').write_text(log, encoding='utf-8')
        if build.returncode or '0 errors, 0 warnings' not in log:
            raise RuntimeError('Probe compilation failed; see compile.log')
        shutil.copy2(source.with_suffix('.dmb'), output / 'probe.dmb')
        shutil.copy2(source.with_suffix('.rsc'), output / 'probe.rsc')
        if args.stage != 'read':
            configure(repo, output)
        summary = {'passed': True, 'tested_commit': head, 'seed': args.seed, 'output': str(output), 'stages': {}}
        for stage, required in (('write', WRITE_CHECKS), ('read', READ_CHECKS)):
            if args.stage not in ('both', stage):
                continue
            (output / 'phase.json').unlink(missing_ok=True)
            command = [str(daemon), 'probe.dmb', '-trusted', '-ip', '127.0.0.1', '-params',
                       f'tested_commit={head}&stage={stage}&seed={args.seed}', '-log', f'startup-{stage}.log']
            code, wall, samples = run(command, output, stage, args.deadline, args.stall)
            (output / f'phase-summary-{stage}.json').write_text(json.dumps(phase_summary(samples), indent=2), encoding='utf-8')
            errors = runtime_errors(output, stage)
            (output / f'runtime-errors-{stage}.json').write_text(json.dumps(errors, indent=2), encoding='utf-8')
            result_path = output / f'result-{stage}.json'
            if not result_path.exists():
                raise RuntimeError(f'No result-{stage}.json (daemon exit {code}); see {output}')
            result = json.loads(result_path.read_text())
            for step in result.get('journal', []):
                print(f"[{stage} {step['t']:>8} {step['phase']}] {step['step']}: {step['detail']}", flush=True)
            for line in result.get('last_messages', []):
                print(f'[{stage} heard] {line}', flush=True)
            passed = [row['check'] for row in result.get('checks', []) if row.get('passed')]
            missing = [name for name in required if name not in passed]
            probe_errors = {key: count for key, count in errors.items() if PROBE in key}
            row = {'passed': bool(result.get('passed')) and not missing and not probe_errors, 'failure': result.get('failure'),
                   'failed_phase': result.get('failed_phase'), 'missing_checks': missing, 'probe_runtime_errors': probe_errors,
                   'other_runtime_error_sites': len(errors) - len(probe_errors), 'adapters': result.get('adapters'),
                   'wall_seconds': round(wall), 'daemon_exit': code,
                   'rss_peak_mib': round(max((s['hwm_bytes'] for s in samples), default=0) / 2**20, 1)}
            summary['stages'][stage] = row
            summary['passed'] = summary['passed'] and row['passed']
            if not row['passed']:
                break
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
