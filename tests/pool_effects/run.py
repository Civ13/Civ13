"""Compile real game effect constructors with isolated startup and native pooling."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import uuid

p = argparse.ArgumentParser()
p.add_argument('--byond-bin', required=True, type=Path)
p.add_argument('--output', required=True, type=Path)
p.add_argument('--negative-control', nargs='?', const='lighting', choices=('lighting','fallback','chem'))
a = p.parse_args()
root = Path(__file__).resolve().parents[2]
if a.output.exists() and any(a.output.iterdir()):
    raise SystemExit('Preserve existing evidence: choose a fresh output directory')
a.output.mkdir(parents=True, exist_ok=True)
head = subprocess.check_output(['git','rev-parse','HEAD'], cwd=root, text=True).strip()
dirty = subprocess.check_output(['git','status','--porcelain'], cwd=root, text=True)
(a.output/'dirty.patch').write_bytes(subprocess.check_output(['git','diff','HEAD'], cwd=root))
manifest = {str(p.relative_to(root)).replace('\\','/'): hashlib.sha256(p.read_bytes()).hexdigest() for p in [root/'civ13.dme', *root.glob('code/**/*.dm'), *root.glob('tests/pool_effects/*')] if p.is_file()}
(a.output/'source-hashes.json').write_text(json.dumps(manifest, indent=2))
prefix = '.pool_effects_' + uuid.uuid4().hex
created = []
flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
def save(suffix, text):
    path = root / (prefix + suffix)
    if path.exists(): raise RuntimeError('Generated source collision')
    created.append(path)
    path.write_text(text, encoding="utf-8")
    return path
try:
    world = (root / 'code/world.dm').read_text(encoding="utf-8")
    start = world.index('/world/New()')
    parent = world.index('\n\t..()', start)
    world = world[:parent] + world[parent + 6:]
    world = world.replace('/world/New()', '/world/proc/unused_pool_effects_startup()')
    world = world.replace('/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n')
    world_path = save('_world.dm', world)
    globals_source = (root / 'code/controllers/mc/globals.dm').read_text(encoding="utf-8")
    globals_source = globals_source.replace('/datum/controller/global_vars/New()\n', '/datum/controller/global_vars/New()\n\treturn\n')
    globals_path = save('_globals.dm', globals_source)
    source = (root / 'civ13.dme').read_text(encoding="utf-8")
    source = source.replace('code\\world.dm', world_path.name).replace('code\\controllers\\mc\\globals.dm', globals_path.name)
    source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
    if a.negative_control == "lighting":
        lighting = (root / 'code/modules/lighting/lighting_overlay.dm').read_text(encoding="utf-8")
        before = '\tlighting_update_overlays -= src'
        if before not in lighting: raise RuntimeError('Lighting mutation anchor missing')
        lighting = lighting.replace(before, '\t// negative control retains update ownership', 1)
        altered = save('_lighting.dm', lighting)
        source = source.replace('code\\modules\\lighting\\lighting_overlay.dm', altered.name)
    if a.negative_control == 'fallback':
        effect = (root/'code/game/objects/effects/effect_system.dm').read_text(encoding='utf-8')
        before = 'retire_effect_lifetime(src, lifetime)'
        if before not in effect: raise RuntimeError('Fallback mutation anchor missing')
        effect = effect.replace(before, 'qdel(src)', 1)
        effect = effect.replace('\tvar/list/lifetime = effect_lifetime\n\t..()\n', '\t..()\n', 1)
        altered = save('_effects.dm', effect)
        source = source.replace('code\\game\\objects\\effects\\effect_system.dm', altered.name)
    chem = (root/'code/game/objects/effects/chem/chemsmoke.dm').read_text(encoding='utf-8')
    before = 'walk_to(src,destination,0,rand(2,3))'
    if chem.count(before) != 1: raise RuntimeError('Chemical walk adapter anchor changed')
    chem = chem.replace(before, 'pool_effect_walk_observed(src,destination,0,rand(2,3))')
    if a.negative_control == 'chem':
        guard = '!QDELETED(src) && effect_lifetime == lifetime && destination && !dontmove'
        if guard not in chem: raise RuntimeError('Chemical token mutation anchor missing')
        chem = chem.replace(guard, 'destination && !dontmove', 1)
        chem = chem.replace('\tvar/list/lifetime = effect_lifetime\n\tspawn (1)', '\tspawn (1)', 1)
    altered = save('_chemsmoke.dm', chem)
    source = source.replace('code\\game\\objects\\effects\\chem\\chemsmoke.dm', altered.name)
    source += '\n#include "tests/pool_effects/probe.dm"\n'
    dme = save('.dme', source)
    (a.output/'metadata.json').write_text(json.dumps({'head':head,'dirty':bool(dirty),'byond':'516.1681','negative_control':a.negative_control,'scope':'actual game constructors, qdel, ResetVars and pool; isolated startup, no normal process scheduler'}, indent=2))
    compiler = a.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = a.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    result = subprocess.run([str(compiler), '-max_errors','0',str(dme)], cwd=root, capture_output=True, text=True, timeout=180, creationflags=flags)
    log = result.stdout + result.stderr
    (a.output/'compile.log').write_text(log)
    print(log[-1800:], flush=True)
    if result.returncode or 'DM compiler version 516.1681' not in log or '0 errors, 0 warnings' not in log:
        raise RuntimeError('Pinned compilation failed')
    import shutil
    for extension in ('.dmb','.rsc'):
        compiled = root/(prefix+extension)
        created.append(compiled)
        shutil.copy2(compiled, a.output/('probe'+extension))
    shutil.copytree(root/'config', a.output/'config')
    run = subprocess.run([str(daemon),'probe.dmb','-invisible','-close','-trusted','-log','runtime.log'], cwd=a.output, capture_output=True, timeout=60, creationflags=flags)
    runtime = (a.output/'runtime.log').read_text(encoding="utf-8")
    (a.output/'daemon.log').write_bytes(run.stdout+run.stderr)
    print(runtime[-3500:], flush=True)
    failure_lines = re.findall(r'^FAIL (.+)$', runtime, re.M)
    if run.returncode or re.search(r'runtime error|RUNTIME |bad ref|bad loc|## ERROR:', runtime, re.I):
        raise RuntimeError('Native engine errors invalidate pool evidence')
    if a.negative_control:
        expected = {'lighting':['lighting cleanup releases both registries'], 'fallback':['fallback smoke old expiry cannot retire reused identity'], 'chem':['chemical smoke only current lifetime starts walking']}[a.negative_control]
        if failure_lines != expected or 'PASS pool effects' in runtime:
            raise RuntimeError('Mutation did not fail only the intended release assertion')
        print('PASS negative control: ' + a.negative_control)
    elif failure_lines or 'PASS pool effects' not in runtime:
        raise RuntimeError('Actual production pooling assertions failed')
    (a.output/'result.json').write_text(json.dumps({'passed':True,'negative_control':a.negative_control,'failures':failure_lines,'source_sha256':hashlib.sha256(source.encode()).hexdigest(),'fixture_sha256':hashlib.sha256((root/'tests/pool_effects/probe.dm').read_bytes()).hexdigest()}, indent=2))
finally:
    for path in created:
        path.unlink(missing_ok=True)
