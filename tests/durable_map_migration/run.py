"""Compile full production sources in an isolated synthetic metadata world."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', choices=('migration', 'strict-version'))
    args = parser.parse_args()
    output = Path(tempfile.mkdtemp(prefix='civ13-map-schema-'))
    prefix = '.map_schema_' + output.name.removeprefix('civ13-map-schema-')
    files = [ROOT/(prefix+s) for s in ('.dme', '_world.dm', '_contract.dm', '.dmb', '.rsc')]
    print(f'Evidence: {output}', flush=True)
    try:
        world = (ROOT/'code/world.dm').read_text(encoding='utf-8')
        anchor = '/datum/global_init/New()\n'
        assert world.count(anchor) == 1
        world = world.replace(anchor, anchor+'\treturn\n', 1)
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        files[1].write_text(world.replace('/world/New()', '/world/proc/unused_migration_startup()', 1), encoding='utf-8')
        contract = (ROOT/'code/modules/persistence/durable_contract.dm').read_text(encoding='utf-8')
        if args.negative_control == 'migration':
            before = 'if(version == 1) schema -= "faction_renames"'
            assert contract.count(before) == 1
            contract = contract.replace(before, 'if(FALSE) schema -= "faction_renames"')
        elif args.negative_control == 'strict-version':
            before = 'if(!("map_fields_version" in state))'
            assert contract.count(before) == 1
            contract = contract.replace(before, 'if(TRUE)')
        files[2].write_text(contract, encoding='utf-8')
        source = (ROOT/'civ13.dme').read_text(encoding='utf-8')
        source = source.replace('code\\world.dm', files[1].name)
        source = source.replace('code\\modules\\persistence\\durable_contract.dm', files[2].name)
        source = re.sub(r'^#include ".*\.dmm".*$', '', source, flags=re.M)
        files[0].write_text(source+'\n#include "tests/durable_map_migration/probe.dm"\n', encoding='utf-8')
        head = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
        inputs = [ROOT/'code/modules/persistence/durable_contract.dm', ROOT/'code/modules/persistence/durable_world.dm',
                  ROOT/'tests/durable_map_migration/probe.dm', Path(__file__), *files[:3]]
        (output/'sources.json').write_text(json.dumps({'head':head,'control':args.negative_control,
            'dirty_diff':subprocess.check_output(['git','diff','--binary'],cwd=ROOT,text=True),
            'world':'4x4x1 synthetic metadata; actual graph/capture/preflight/restore, no production saves',
            'sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}},indent=2),encoding='utf-8')
        binary=args.byond_bin.resolve(strict=True)
        flags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0
        compiler=binary/('dm.exe' if os.name=='nt' else 'DreamMaker')
        daemon=binary/('dd.exe' if os.name=='nt' else 'DreamDaemon')
        version=json.loads((ROOT/'tools/byond/version.json').read_text())['version']
        build=subprocess.run([str(compiler),'-max_errors','0',files[0].name],cwd=ROOT,capture_output=True,text=True,timeout=120,creationflags=flags)
        log=build.stdout+build.stderr
        (output/'compile.log').write_text(log,encoding='utf-8')
        if build.returncode or f'DM compiler version {version}\n' not in log or '0 errors, 0 warnings' not in log:
            raise RuntimeError(log)
        for p in files[3:]: shutil.copy2(p,output/p.name)
        shutil.copytree(ROOT/'config/names',output/'config/names')
        (output/'config/config.txt').write_text('# Offline fixture\n',encoding='utf-8')
        for p in (ROOT/'tests/durable_map_migration').glob('map-schema-*.json'): shutil.copy2(p,output/p.name)
        run=subprocess.run([str(daemon),files[3].name,'-ip','127.0.0.1','-nowebclient',
                            *(['-invisible','-close'] if os.name=='nt' else []),'-trusted','-log','runtime.log'],
                           cwd=output,capture_output=True,text=True,timeout=90,creationflags=flags)
        (output/'daemon.log').write_text(run.stdout+run.stderr,encoding='utf-8')
        logs='\n'.join(p.read_text(errors='replace') for p in output.glob('*.log'))
        result=(output/'result.txt').read_text().strip()
        if run.returncode or re.search(r'runtime error:|BUG:|Bad ref|Unhandled exception',logs,re.I) or (output/'errors.txt').exists():
            raise RuntimeError('Unexpected native diagnostic: '+str(output))
        expected={'migration':'Durable map field inventory differs at code/modules/persistence/durable_world.dm:',
                  'strict-version':'versioned missing required field faction_renames'}
        if args.negative_control:
            if not result.startswith('FAIL: '+expected[args.negative_control]): raise RuntimeError(result)
            print('PASS: intended '+args.negative_control+' mutation detected')
        elif not result.startswith('PASS:'): raise RuntimeError(result)
        else: print(result)
        (output/'summary.json').write_text(json.dumps({'head':head,'result':result,'control':args.negative_control}),encoding='utf-8')
    finally:
        for p in files: p.unlink(missing_ok=True)


if __name__=='__main__':
    main()
