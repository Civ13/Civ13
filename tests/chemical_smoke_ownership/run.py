"""Production smoke lifecycle fixture. --prepare-only never starts BYOND."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import uuid

BASE_SHA = '450eadc7a7090082d1a60fdaf91fe0d9339f930f6a2450b4210afed3446192af'
EXPECTED = ['automatic systems release hidden holders']
ROOT = Path(__file__).resolve().parents[2]

def prepare(root, prefix, historical=False):
    world = (root/'code/world.dm').read_text(encoding='utf-8')
    start = world.index('/world/New()')
    parent = world.index('\n\t..()', start)
    world = world[:parent] + world[parent + 6:]
    world = world.replace('/world/New()', '/world/proc/unused_smoke_startup()')
    anchor = '/datum/global_init/New()\n'
    if world.count(anchor) != 1: raise ValueError('World isolation anchor changed')
    world = world.replace(anchor, anchor+'\treturn\n')
    globals_source = (root/'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
    anchor = '/datum/controller/global_vars/New()\n'
    if globals_source.count(anchor) != 1: raise ValueError('Globals isolation anchor changed')
    globals_source = globals_source.replace(anchor, anchor+'\treturn\n')
    if historical:
        raw = (root/'tests/chemical_smoke_ownership/baseline.dm').read_bytes()
        if hashlib.sha256(raw).hexdigest() != BASE_SHA: raise ValueError('Historical oracle bytes changed')
        chem = raw.decode('utf-8')
    else:
        chem = (root/'code/game/objects/effects/chem/chemsmoke.dm').read_text(encoding='utf-8')
    anchor = '\t//Kinda ugly, but needed unless the system is reworked\n'
    if chem.count(anchor) != 1: raise ValueError('Emission observation anchor changed')
    chem = chem.replace(anchor, '\tsmoke_fixture_observe(smoke, smoke_duration, dist)\n\n'+anchor)
    dme = (root/'civ13.dme').read_text(encoding='utf-8')
    replacements = {'code\\world.dm': '_world.dm', 'code\\controllers\\mc\\globals.dm': '_globals.dm',
                    'code\\game\\objects\\effects\\chem\\chemsmoke.dm': '_chem.dm'}
    for old, suffix in replacements.items():
        if dme.count('"'+old+'"') != 1: raise ValueError('Include anchor changed: '+old)
        dme = dme.replace('"'+old+'"', '"'+prefix+suffix+'"')
    dme = re.sub(r'^#include ".*\.dmm"\s*$', '', dme, flags=re.M)
    dme += '\n#include "tests/chemical_smoke_ownership/probe.dm"\n'
    return {prefix+'_world.dm': world, prefix+'_globals.dm': globals_source,
            prefix+'_chem.dm': chem, prefix+'.dme': dme}

def verify(runtime, exit_code, historical=False):
    if exit_code or re.search(r'runtime error|RUNTIME |bad ref|bad loc|## ERROR:', runtime, re.I):
        raise ValueError('Runtime/engine diagnostics invalidate evidence')
    failures = re.findall(r'^FAIL (.+)$', runtime, re.M)
    if runtime.count('DONE chemical smoke ownership') != 1:
        raise ValueError('Missing/duplicate completion')
    if historical:
        if failures != EXPECTED or 'PASS chemical smoke ownership' in runtime:
            raise ValueError('Historical source did not fail only the release assertion')
    elif failures or runtime.count('PASS chemical smoke ownership') != 1:
        raise ValueError('Production lifecycle assertions failed')

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--byond-bin', type=Path)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--negative-control', action='store_true')
    p.add_argument('--prepare-only', action='store_true')
    a = p.parse_args()
    if not a.prepare_only and not a.byond_bin: p.error('--byond-bin is required for native execution')
    if a.output.exists(): raise ValueError('Preserve existing evidence; choose a new output path')
    a.output.mkdir(parents=True)
    prefix = '.chemical_smoke_' + uuid.uuid4().hex
    sources = prepare(ROOT, prefix, a.negative_control)
    for name, source in sources.items():
        (a.output/name).write_text(source, encoding='utf-8', newline='\n')
    metadata = {'head': subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip(),
                'dirty': subprocess.check_output(['git','status','--porcelain'], cwd=ROOT, text=True),
                'historical_base': '3ce4ece2327a9a80bb94a6752138ceb48188ea22',
                'historical_sha256': BASE_SHA, 'negative_control': a.negative_control,
                'native_run': False, 'source_sha256': {name: hashlib.sha256(source.encode()).hexdigest() for name, source in sources.items()}}
    metadata['inputs_sha256'] = {str(path.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted([ROOT/'civ13.dme', *ROOT.glob('code/**/*.dm'), *ROOT.glob('tests/chemical_smoke_ownership/*')]) if path.is_file()}
    (a.output/'metadata.json').write_text(json.dumps(metadata, indent=2))
    if a.prepare_only: return
    created = []
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    try:
        for name, source in sources.items():
            path = ROOT/name
            if path.exists(): raise ValueError('Generated source collision')
            path.write_text(source, encoding='utf-8', newline='\n')
            created.append(path)
        for suffix in ('.dmb', '.rsc'): created.append(ROOT/(prefix+suffix))
        binary = a.byond_bin.resolve()
        compiler = binary/('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = binary/('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        result = subprocess.run([str(compiler), '-max_errors','0', prefix+'.dme'], cwd=ROOT,
                                capture_output=True, text=True, timeout=180, creationflags=flags)
        log = result.stdout+result.stderr
        (a.output/'compile.log').write_text(log)
        if result.returncode or 'DM compiler version 516.1681' not in log or '0 errors, 0 warnings' not in log:
            raise ValueError('Pinned compiler failed')
        for suffix in ('.dmb', '.rsc'): shutil.copy2(ROOT/(prefix+suffix), a.output/('probe'+suffix))
        (a.output/'binary-hashes.json').write_text(json.dumps({name: hashlib.sha256((a.output/name).read_bytes()).hexdigest() for name in ('probe.dmb', 'probe.rsc')}, indent=2))
        shutil.copytree(ROOT/'config/names', a.output/'config/names')
        (a.output/'config/config.txt').write_text('tts_on 0\n')
        run = subprocess.run([str(daemon),'probe.dmb','-invisible','-close','-trusted','-params',
                              'historical='+str(int(a.negative_control)), '-log','runtime.log'],
                             cwd=a.output, capture_output=True, timeout=180, creationflags=flags)
        (a.output/'daemon.log').write_bytes(run.stdout+run.stderr)
        runtime = (a.output/'runtime.log').read_text(encoding='utf-8')
        print(runtime[-3000:])
        verify(runtime, run.returncode, a.negative_control)
        (a.output/'result.json').write_text(json.dumps({'native_run': True, 'passed': True,
                                                      'negative_control': a.negative_control}))
    finally:
        for path in created: path.unlink(missing_ok=True)

if __name__ == '__main__': main()
