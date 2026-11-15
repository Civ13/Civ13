"""Measure zone persistence on a real production map (#3590).

Compiles a temporary copy of civ13.dme with one production map selected and
tests/zone_persistence/real_map_probe.dm appended, then runs fresh DreamDaemon
processes, each in its own directory:

  write   a fresh Persistence world: a roof in every climate zone, two spawn
          groups (one deliberately empty), one production save
  read    a copy of that save: the startup restore, then admin-style reloads in
          the same process, the spawn-group checks and a second save
  reject  a copy whose world_state.schema is 3: startup must refuse it before
          the map is cleared and leave every file byte-identical

Every run works on a copy made by this script inside --output. It never reads
or writes a server's map_saves/. The synthetic 8x8x2 cases stay in
run_native.py; this runner measures scale and real-map behaviour.

  source <byond>/bin/byondsetup
  python3 -B tests/zone_persistence/real_map.py --byond-bin <byond>/bin \
      --map maps/nomads/nomads_americas_north.dmm --output <fresh dir>
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
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts' / 'shard-group'))
from shard_map_selection import select_map_block  # noqa: E402

PROBE = 'tests/zone_persistence/real_map_probe.dm'
# The zone work inside a save, a preflight and a restore (zone_topology.dm and
# the roof validation in loading.dm), plus the whole operations for scale.
ZONE_PROCS = ('begin_zone_export', 'capture_zone_turf', 'capture_zone_descriptor', 'capture_zone_spawns',
              'finalize_zone_export', 'prepare_saved_zones', 'validate_zone_spawns', 'validate_current_zone_identities',
              'prepare_saved_roof_areas', 'prepare_zone_roof', 'unique_saved_zone_type', 'begin_zone_restore',
              'restore_zone_topology', 'verify_zone_topology', 'restore_zone_spawns', 'resolve_zone_spawns',
              'reconcile_saved_zone_weather')
WHOLE_PROCS = ('savemap', 'loadmap', 'Save_World', 'validate_world_save', 'validate_captured_world_save', 'ClearMap')
CONFIG_OFF = ('SKIP_PERSISTENCE_SAVING', 'HUB', 'PERSISTENCE_REBOOT_HOUR', 'WEBHOOK_CAN_FIRE')
RUNTIME = re.compile(r'runtime error: (.*)\nproc name: (.*)\n\s*source file: ([^,\n]+),(\d+)')
# The engine's loop check: a proc ran a very long loop without yielding.
LOOP = re.compile(r'Infinite loop suspected[^\n]*\n[^\n]*\nproc name: (.*)\n\s*source file: ([^,\n]+),(\d+)')
PHASE_LINE = re.compile(r'World (save|load): (.+?) took ([0-9.]+) s\.')
MIB = 2 ** 20


def need(value, message):
    if not value:
        raise RuntimeError(message)


def sha(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as handle:
        for block in iter(lambda: handle.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


def tree(folder):
    return {p.relative_to(folder).as_posix(): {'bytes': p.stat().st_size, 'sha256': sha(p)}
            for p in sorted(folder.rglob('*')) if p.is_file()}


def compile_probe(byond, include, output):
    prefix = '.zone_real_' + uuid.uuid4().hex[:16]
    target = ROOT / (prefix + '.dme')
    dme = select_map_block((ROOT / 'civ13.dme').read_text(encoding='utf-8-sig'), include.replace('/', '\\'), 'civ13.dme')
    dme += '\n#include "' + PROBE.replace('/', '\\') + '"\n'
    try:
        target.write_text(dme, encoding='utf-8')
        build = subprocess.run([str(byond / 'DreamMaker'), '-max_errors', '0', target.name], cwd=ROOT,
                               capture_output=True, text=True, timeout=900)
        log = build.stdout + build.stderr
        (output / 'compile.log').write_text(log, encoding='utf-8')
        need(build.returncode == 0 and ' - 0 errors, 0 warnings' in log, 'Probe compile failed; see compile.log')
        for suffix in ('.dmb', '.rsc'):
            shutil.copy2(target.with_suffix(suffix), output / ('probe' + suffix))
    finally:
        for suffix in ('.dme', '.dmb', '.rsc', '.int', '.lk'):
            target.with_suffix(suffix).unlink(missing_ok=True)
    return re.search(r'DM compiler version (\S+)', log).group(1)


def stage(output, name, savestream, saves=None):
    case = output / name
    need(not case.exists(), 'Run directory already exists: ' + name)
    case.mkdir()
    for suffix in ('.dmb', '.rsc'):
        try:
            os.link(output / ('probe' + suffix), case / ('probe' + suffix))
        except OSError:
            shutil.copy2(output / ('probe' + suffix), case / ('probe' + suffix))
    for path in subprocess.check_output(['git', '-C', str(ROOT), 'ls-files', '--', 'config', 'maps/heights'], text=True).splitlines():
        dest = case / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / path, dest)
    config = case / 'config/config.txt'
    lines = []
    for line in config.read_text(encoding='utf-8', errors='replace').splitlines():
        key = line.split(' ', 1)[0].strip()
        if key == 'ALLOWED_GAMEMODES':
            line = 'ALLOWED_GAMEMODES PERSISTENCE'
        elif key in CONFIG_OFF:
            line = '#' + line
        lines.append(line)
    config.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    if savestream:
        for binary in ('libsavestream.so', 'savestream_helper'):
            shutil.copy2(savestream / binary, case / binary)
    if saves:
        shutil.copytree(saves, case / 'map_saves')
    return case


def sample(pid):
    try:
        status = (Path('/proc') / str(pid) / 'status').read_text().splitlines()
        memory = {row.split(':', 1)[0]: int(row.split()[1]) * 1024 for row in status if row.startswith(('VmRSS:', 'VmHWM:'))}
        return {'rss': memory['VmRSS'], 'hwm': memory['VmHWM']}
    except (FileNotFoundError, ProcessLookupError, KeyError, ValueError, IndexError):
        return None


def run(byond, case, params, deadline):
    samples = []
    started = time.monotonic()
    env = dict(os.environ, HOME=str(case), LD_LIBRARY_PATH=str(byond) + ':' + str(case))
    command = [str(byond / 'DreamDaemon'), 'probe.dmb', '-trusted', '-ip', '127.0.0.1', '-nowebclient',
               '-params', '&'.join(key + '=' + str(value) for key, value in params.items()), '-log', 'world.log']
    with (case / 'stdout.log').open('w') as out:
        process = subprocess.Popen(command, cwd=case, stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT,
                                   env=env, start_new_session=True)
        try:
            while process.poll() is None:
                elapsed = time.monotonic() - started
                need(elapsed < deadline, f'{case.name}: {deadline}-second deadline; see {case}')
                row = sample(process.pid)
                if row:
                    try:
                        row['phase'] = json.loads((case / 'phase.json').read_text())['phase']
                    except (FileNotFoundError, json.JSONDecodeError, KeyError):
                        row['phase'] = 'startup'
                    row['t'] = round(elapsed, 1)
                    samples.append(row)
                time.sleep(1)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=10)
            (case / 'os-samples.json').write_text(json.dumps(samples), encoding='utf-8')
    for suffix in ('.dmb', '.rsc'):
        (case / ('probe' + suffix)).unlink(missing_ok=True)
    need((case / 'result.json').is_file(), f'{case.name}: no result.json (daemon exit {process.returncode}); see {case}')
    result = json.loads((case / 'result.json').read_text(encoding='utf-8'))
    phases = {}
    for phase in dict.fromkeys(row['phase'] for row in samples):
        rows = [row for row in samples if row['phase'] == phase]
        phases[phase] = {'seconds': round(rows[-1]['t'] - rows[0]['t'], 1), 'rss_end_mib': round(rows[-1]['rss'] / MIB),
                         'rss_peak_mib': round(max(row['rss'] for row in rows) / MIB)}
    # The game moves its world log, with the runtime errors, under data/logs/runtime.
    logs = [case / 'world.log'] + sorted((case / 'data/logs/runtime').glob('*.txt'))
    log = '\n'.join(path.read_text(encoding='utf-8', errors='replace') for path in logs if path.is_file())
    errors = {}
    for message, proc, source, line in RUNTIME.findall(log):
        key = f"{source.replace(chr(92), '/')}:{line}: {message.strip()} ({proc.strip()})"
        errors[key] = errors.get(key, 0) + 1
    loops = {}
    for proc, source, line in LOOP.findall(log):
        source = source.replace(chr(92), '/')
        if source.startswith('code/'):  # The probe's own whole-world counts trip it too.
            key = f'{source}:{line} ({proc.strip()})'
            loops[key] = loops.get(key, 0) + 1
    return {'result': result, 'phases': phases, 'peak_mib': round(max((row['hwm'] for row in samples), default=0) / MIB),
            'wall_seconds': round(time.monotonic() - started), 'runtime_errors': errors,
            'phase_lines': [f'{kind}: {phase} {seconds} s' for kind, phase, seconds in PHASE_LINE.findall(log)],
            'loop_warnings': loops}


def profile(case, name):
    """Seconds by proc from one world.Profile dump: each zone proc and the whole operations."""
    path = case / f'profile-{name}.json'
    if not path.is_file():
        return None
    rows = json.loads(path.read_text(encoding='utf-8', errors='replace'))
    found = {}
    for row in rows:
        short = row['name'].rsplit('/', 1)[-1]
        if short in ZONE_PROCS or short in WHOLE_PROCS:
            entry = found.setdefault(short, {'self_s': 0, 'total_s': 0, 'calls': 0})
            entry['self_s'] = round(entry['self_s'] + row['self'], 2)
            entry['total_s'] = round(entry['total_s'] + row['total'], 2)
            entry['calls'] += row['calls']
    zone_self = round(sum(found[name]['self_s'] for name in ZONE_PROCS if name in found), 2)
    all_self = round(sum(row['self'] for row in rows), 2)
    return {'zone_self_s': zone_self, 'all_procs_self_s': all_self,
            'zone_share_percent': round(100 * zone_self / all_self, 1) if all_self else None, 'procs': found}


def inventory(case, name):
    return json.loads((case / f'inventory-{name}.json').read_text(encoding='utf-8'))


def comparable(document):
    def rows(items, key):
        return sorted((json.dumps(item, sort_keys=True) for item in items), key=key)
    spawns = document['spawns']
    return {'zones': rows(document['zones'], str), 'roofs': rows(document['roofs'], str),
            'spawns': {'latejoin': {group: sorted(turfs) for group, turfs in spawns['latejoin'].items()},
                       **{key: sorted(spawns[key]) for key in ('start', 'join', 'paradrop', 'supply')}}}


def differences(before, after):
    a, b = comparable(before), comparable(after)
    return [key for key in ('zones', 'roofs', 'spawns') if a[key] != b[key]]


def roof_ambiguity(saves, saved_inventory):
    """Zone types saved more than once, and switched roofs standing on one of them."""
    state = json.loads((saves / 'round.json').read_text(encoding='utf-8'))
    world_state = state['world_state']
    zones = world_state['topology']['zones']
    counts = {}
    for zone in zones:
        counts[zone['type']] = counts.get(zone['type'], 0) + 1
    repeated = {kind: count for kind, count in counts.items() if count > 1}
    switched = [roof for roof in saved_inventory['roofs'] if roof['switch']]
    return {'world_state_schema': world_state['schema'], 'topology_schema': world_state['topology']['schema'],
            'saved_zones': len(zones), 'zone_types_saved_more_than_once': repeated, 'switched_roofs': len(switched),
            'switched_roofs_on_a_repeated_base_type': sum(1 for roof in switched if roof['base'] in repeated),
            'roof_bases_absent_from_saved_zones': sorted({roof['base'] for roof in switched} - set(counts))}


def rewrite_schema(saves, schema):
    path = saves / 'round.json'
    text = path.read_text(encoding='utf-8')
    state = json.loads(text)
    need(state['world_state']['schema'] == 2, 'The saved world state is not schema 2')
    # Change the one number and nothing else in the file.
    start = text.index('"world_state":{')
    match = re.compile(r'"schema":2\b').search(text, start)
    need(match, 'world_state.schema not found in round.json')
    edited = text[:match.start()] + f'"schema":{schema}' + text[match.end():]
    need(json.loads(edited)['world_state']['schema'] == schema, 'The schema edit changed another field')
    path.write_text(edited, encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--map', default='maps/nomads/nomads_americas_north.dmm')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--savestream-bin', type=Path, help='folder holding libsavestream.so and savestream_helper '
                        '(tools/savestream/build.sh linux); without it levels are saved through BYOND savefiles')
    parser.add_argument('--loads', type=int, default=3, help='loads in the read process, the startup restore included')
    parser.add_argument('--settle', type=int, default=60, help='seconds a fresh world runs before the roofs are built')
    parser.add_argument('--deadline', type=int, default=5400, help='seconds allowed for each process')
    args = parser.parse_args()
    byond = args.byond_bin.resolve(strict=True)
    need((ROOT / args.map).is_file(), 'No such map: ' + args.map)
    output = args.output.resolve()
    need(not output.exists() or not any(output.iterdir()), 'The output directory must be fresh')
    output.mkdir(parents=True, exist_ok=True)
    savestream = args.savestream_bin.resolve(strict=True) if args.savestream_bin else None
    summary = {'map': args.map, 'head': subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip(),
               'working_tree_changes': subprocess.check_output(['git', '-C', str(ROOT), 'status', '--porcelain'], text=True).splitlines(),
               'stream_helper': bool(savestream), 'failures': []}
    summary['compiler'] = compile_probe(byond, args.map, output)

    def finish(name, case, outcome):
        result = outcome['result']
        summary[name] = {key: outcome[key] for key in ('phases', 'peak_mib', 'wall_seconds', 'runtime_errors', 'phase_lines', 'loop_warnings')}
        summary[name]['result'] = {key: value for key, value in result.items() if key != 'checks'}
        summary[name]['checks'] = len(result.get('checks', []))
        if not result.get('passed'):
            summary['failures'].append(f"{name}: {result.get('failure') or result.get('failed_checks')}")
        if outcome['runtime_errors']:
            summary['failures'].append(f"{name}: {sum(outcome['runtime_errors'].values())} runtime errors")
        (output / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
        print(f"{'PASS' if result.get('passed') else 'FAIL'} {name}: {summary[name]['checks']} checks, "
              f"{outcome['wall_seconds']} s, peak {outcome['peak_mib']} MiB", flush=True)
        return result.get('passed')

    try:
        write = stage(output, 'write', savestream)
        outcome = run(byond, write, {'real_mode': 'write', 'settle_ds': args.settle * 10}, args.deadline)
        if not finish('write', write, outcome):
            raise RuntimeError('The write run failed; later runs need its save')
        saves = write / 'map_saves'
        need((saves / 'save_complete.txt').is_file(), 'The write run left no completed save')
        original = tree(saves)
        saved = inventory(write, 'saved')
        summary['save_files'] = {name: row['bytes'] for name, row in original.items()}
        summary['save_bytes'] = sum(row['bytes'] for row in original.values())
        summary['write']['profile'] = {'save': profile(write, 'save')}
        summary['write']['census'] = {name: inventory(write, name)['census'] for name in ('before-save', 'saved')}
        summary['roofs'] = roof_ambiguity(saves, saved)
        if summary['roofs']['switched_roofs_on_a_repeated_base_type'] or summary['roofs']['roof_bases_absent_from_saved_zones']:
            summary['failures'].append('A switched roof stands on an ambiguous or absent saved base zone')

        read = stage(output, 'read', savestream, saves)
        outcome = run(byond, read, {'real_mode': 'read', 'loads': args.loads}, args.deadline)
        finish('read', read, outcome)
        names = ['load-%d' % number for number in range(1, args.loads + 1)]
        present = [name for name in names + ['resaved'] if (read / f'inventory-{name}.json').is_file()]
        summary['read']['profile'] = {name: profile(read, name) for name in ['startup-load'] + names[1:] + ['resave']}
        summary['read']['census'] = {name: inventory(read, name)['census'] for name in present}
        summary['read']['differs_from_saved'] = {name: differences(saved, inventory(read, name)) for name in present}
        if len(present) != len(names) + 1:
            summary['failures'].append('read: not every load and the second save were inventoried')
        for name in present:
            # The spawn-group checks add one turf to the emptied group before the second save.
            ignore = ['spawns'] if name == 'resaved' else []
            changed = [key for key in summary['read']['differs_from_saved'][name] if key not in ignore]
            if changed:
                summary['failures'].append(f'read: {name} differs from the saved inventory in {changed}')
        loads = [summary['read']['census'][name] for name in names if name in summary['read']['census']]
        if len({(row['world_areas'], row['area_list']) for row in loads}) > 1:
            summary['failures'].append('read: the area count or area_list length changed between loads')
        settled = [summary['read']['phases'].get(name + '-settle', {}).get('rss_end_mib') for name in names[1:]]
        summary['read']['rss_after_each_reload_mib'] = settled
        if len(settled) > 1 and all(settled) and settled[-1] > settled[0] * 1.15:
            summary['failures'].append(f'read: memory kept growing between reloads ({settled} MiB)')
        need(tree(saves) == original, 'The write run\'s save changed while its copies were read')

        rejected = stage(output, 'reject', savestream, saves)
        rewrite_schema(rejected / 'map_saves', 3)
        before = tree(rejected / 'map_saves')
        outcome = run(byond, rejected, {'real_mode': 'reject', 'reason': 'Unsupported zone metadata revision'}, args.deadline)
        finish('reject', rejected, outcome)
        after = tree(rejected / 'map_saves')
        summary['reject']['files_byte_identical'] = before == after
        summary['reject']['files_changed'] = sorted(name for name in set(before) | set(after) if before.get(name) != after.get(name))
        if before != after:
            summary['failures'].append('reject: the refused save\'s files changed')
    except RuntimeError as error:
        summary['failures'].append(str(error))
    summary['passed'] = not summary['failures']
    (output / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print(json.dumps({key: summary[key] for key in ('map', 'head', 'passed', 'failures')}, indent=2))
    print('Evidence: ' + str(output))
    raise SystemExit(0 if summary['passed'] else 1)


if __name__ == '__main__':
    main()
