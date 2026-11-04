"""Bounded synthetic full-source Nomads metadata fixture; no production saves."""
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

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--negative-control', choices=('profile', 'timer-restore', 'nuke-tail', 'calendar-failure', 'lava-tail', 'legacy-import'))
    parser.add_argument('--spatial', action='store_true', help='26 sequential fresh-process production world-save roundtrips')
    parser.add_argument('--events', action='store_true', help='owned delayed event completion and failure barriers')
    args = parser.parse_args()
    event_control = args.negative_control in ('nuke-tail', 'calendar-failure', 'lava-tail', 'legacy-import')
    if event_control: args.events = True
    if (args.spatial and args.negative_control) or (args.events and (args.spatial or (args.negative_control and not event_control))):
        parser.error('Spatial matrix and metadata mutation controls are separate runs')
    output = Path(tempfile.mkdtemp(prefix='civ13-nomads-'))
    prefix = '.nomads_' + output.name.removeprefix('civ13-nomads-')
    files = [ROOT/(prefix+s) for s in ('.dme', '_world.dm', '_module.dm', '.dmb', '.rsc')]
    print('Evidence: ' + str(output), flush=True)
    try:
        world = (ROOT/'code/world.dm').read_text(encoding='utf-8')
        anchor = '/datum/global_init/New()\n'
        assert world.count(anchor) == 1
        world = world.replace(anchor, anchor+'\treturn\n', 1)
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent]+world[parent:].replace('\n\t..()', '', 1)
        files[1].write_text(world.replace('/world/New()', '/world/proc/unused_nomads_startup()', 1), encoding='utf-8')
        module_path = {'timer-restore': 'code/modules/persistence/durable_timers.dm',
                       'nuke-tail': 'code/modules/1713/radiation.dm',
                       'calendar-failure': 'code/game/objects/map_metadata/_map_metadata.dm',
                       'lava-tail': 'code/modules/1713/natural_disasters.dm',
                       'legacy-import': 'code/modules/persistence/durable_world.dm'}.get(args.negative_control, 'code/modules/persistence/durable_nomads.dm')
        module = (ROOT/module_path).read_text(encoding='utf-8')
        if args.negative_control == 'profile':
            anchor = 'return list(/obj/map_metadata/nomads, '
            assert module.count(anchor) == 1
            module = module.replace(anchor, 'return list(', 1)
        elif args.negative_control == 'timer-restore':
            anchor = '\t\tschedule(key, state[key])'
            assert module.count(anchor) == 1
            module = module.replace(anchor, '\t\tcontinue', 1)
        elif args.negative_control == 'nuke-tail':
            anchor = '/proc/nuke_map(turf/epicenter, severity, duration, log, datum/durable_nomads_event/event = null)\n'
            assert module.count(anchor) == 1
            module = module.replace(anchor, anchor+'\tevent = null\n', 1)
        elif args.negative_control == 'calendar-failure':
            anchor = '\t\tseason_busy = FALSE\n\t\tthrow E'
            assert module.count(anchor) == 1
            module = module.replace(anchor, '\t\tseason_busy = FALSE\n\t\tnomads_event_busy = FALSE\n\t\tthrow E', 1)
        elif args.negative_control == 'lava-tail':
            anchor = 'T.ChangeTurf(/turf/floor/lava, TRUE, FALSE, event)'
            assert module.count(anchor) == 1
            module = module.replace(anchor, 'T.ChangeTurf(/turf/floor/lava)', 1)
        elif args.negative_control == 'legacy-import':
            anchor = '\tif(!durable_state && !map.uses_durable_metadata()) return'
            assert module.count(anchor) == 1
            module = module.replace(anchor, '\tif(!durable_state) return', 1)
        files[2].write_text(module, encoding='utf-8')
        source = (ROOT/'civ13.dme').read_text(encoding='utf-8')
        source = source.replace('code\\world.dm', files[1].name)
        source = source.replace(module_path.replace('/', '\\'), files[2].name)
        source = re.sub(r'^#include ".*\.dmm".*$', '', source, flags=re.M)
        files[0].write_text(source+'\n#include "tests/nomads_persistence/probe.dm"\n', encoding='utf-8')
        head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        inputs = [ROOT/p for p in subprocess.check_output(['git', 'ls-files', '*.dm', '*.dme', 'scripts/nomads-lifecycle/*.py'], cwd=ROOT, text=True).splitlines()]
        inputs += [ROOT/'code/modules/persistence/durable_nomads.dm', ROOT/'tests/nomads_persistence/probe.dm', Path(__file__), *files[:3]]
        (output/'sources.json').write_text(json.dumps({'head': head, 'control': args.negative_control,
            'dirty_diff': subprocess.check_output(['git', 'diff', '--binary'], cwd=ROOT, text=True),
            'scope': '4x4x2 synthetic world; actual metadata constructors, graph, contracts and timers; startup disabled',
            'sha256': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}}, indent=2), encoding='utf-8')
        binary = args.byond_bin.resolve(strict=True)
        compiler = binary/('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = binary/('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        runtime_hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (compiler, daemon)}
        (output/'runtime-files.json').write_text(json.dumps(runtime_hashes, indent=2))
        flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
        version = json.loads((ROOT/'tools/byond/version.json').read_text())['version']
        build = subprocess.run([str(compiler), '-max_errors', '0', files[0].name], cwd=ROOT, capture_output=True, text=True, timeout=120, creationflags=flags)
        log = build.stdout+build.stderr
        (output/'compile.log').write_text(log, encoding='utf-8')
        if build.returncode or f'DM compiler version {version}\n' not in log or '0 errors, 0 warnings' not in log:
            raise RuntimeError(log)
        for p in files[3:]: shutil.copy2(p, output/p.name)
        shutil.copytree(ROOT/'config/names', output/'config/names')
        (output/'config/config.txt').write_text('# Isolated synthetic fixture\n')
        deadline = time.monotonic()+900
        results = []
        for case in (range(1, 27) if args.spatial else [0]):
            if {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (compiler, daemon)} != runtime_hashes:
                raise RuntimeError('Native runtime changed during the fixture')
            folder = output
            if case:
                folder = output/f'case-{case:02d}'
                folder.mkdir()
                shutil.copytree(output/'config', folder/'config')
                for p in files[3:]: os.link(output/p.name, folder/p.name)
            remaining = deadline-time.monotonic()
            if remaining < 1: raise RuntimeError('Overall native matrix deadline exhausted')
            run = subprocess.run([str(daemon), files[3].name, '-ip', '127.0.0.1', '-nowebclient', *(['-invisible', '-close'] if os.name == 'nt' else []), '-trusted', '-log', 'runtime.log', '-params', f'spatial={case}&events={int(args.events)}'], cwd=folder, capture_output=True, text=True, timeout=min(180, remaining), creationflags=flags)
            (folder/'daemon.log').write_text(run.stdout+run.stderr, encoding='utf-8')
            logs = '\n'.join(p.read_text(errors='replace') for p in folder.glob('*.log'))
            result = (folder/'result.txt').read_text().strip()
            results.append({'case': case, 'result': result})
            (output/'results.json').write_text(json.dumps(results, indent=2))
            if run.returncode or re.search(r'runtime error:|BUG:|Bad ref|Unhandled exception', logs, re.I) or (folder/'errors.txt').exists():
                raise RuntimeError('Unexpected native diagnostic: '+str(folder))
            expected = {'profile': 'unsupported registered profile: /obj/map_metadata/nomads', 'timer-restore': 'restored callback deadline:',
                        'nuke-tail': 'nuke lost delayed or explosion work',
                        'calendar-failure': 'partial calendar transition flag',
                        'lava-tail': 'eruption returned with lava descendants flag',
                        'legacy-import': 'nuke returned with pending descendants legacy import'}
            if args.negative_control:
                if not result.startswith('FAIL: '+expected[args.negative_control]): raise RuntimeError(result)
                print('PASS: intended '+args.negative_control+' mutation detected', flush=True)
            elif not result.startswith('PASS:'): raise RuntimeError(result)
            else: print(result, flush=True)
        (output/'summary.json').write_text(json.dumps({'head': head, 'control': args.negative_control, 'spatial': args.spatial, 'events': args.events, 'results': results}), encoding='utf-8')
    finally:
        for p in files: p.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
