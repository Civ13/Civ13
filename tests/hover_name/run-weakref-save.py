"""Disk-backed production weak-cache migration and restored own-hover regression."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

DIAGNOSTIC = re.compile(r'runtime error:|bad ref|BUG:|##\s*ERROR\s*:|RUNTIME:|assertion failed|infinite loop|segmentation|fatal error', re.I)

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--byond-bin', type=Path, required=True)
parser.add_argument('--negative-control', choices=['export', 'import'])
parser.add_argument('--prepare-only', action='store_true')
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
saver = repo / 'code/modules/persistence/saving.dm'
prepared = subprocess.run([
    sys.executable, '-B', str(repo / 'tests/world_save/run-string-path.py'),
    '--byond-bin', str(args.byond_bin), '--prepare-only',
    '--expected-saving-sha256', hashlib.sha256(saver.read_bytes()).hexdigest(),
], capture_output=True, text=True, check=True, timeout=30)
match = re.search(r'^Retained evidence: (.+)$', prepared.stdout, re.M)
if not match:
    raise RuntimeError('World-save preparation output unavailable')
root = Path(match.group(1).strip())
print(f'Retained evidence: {root}', flush=True)

def declaration(path, name):
    source = (repo / path).read_text()
    match = re.search('^' + re.escape(name) + r'[^\n]*\n(?:\t[^\n]*\n|\n)*', source, re.M)
    if not match:
        raise RuntimeError('Missing production declaration: ' + name)
    return match.group()

widget = (repo / 'code/_onclick/hud/hover_name.dm').read_text()
widget = widget.replace('/client/', '/datum/hover_client/')
widget = widget.replace('var/client/C', 'var/datum/hover_client/C')
widget = widget.replace('parentmob.client', 'parentmob.hover_client')
adapter = (Path(__file__).with_name('weakref_save_probe.dm').read_text() + '\n'
           + (repo / 'code/datums/weakref.dm').read_text() + '\n' + widget + '\n'
           + declaration('code/game/mob/living/carbon/human/human.dm',
                         '/mob/living/human/proc/get_visible_name('))
(root / 'weakref_save_adapter.dm').write_text(adapter)
roundtrip = root / 'roundtrip.dm'
source = roundtrip.read_text()
anchor = '\t\tcheck_datum_constructor()\n'
assert source.count(anchor) == 1
roundtrip.write_text(source.replace(anchor, '\t\tcheck_weakref_save()\n' + anchor, 1))
dme = root / 'probe.dme'
dme.write_text(dme.read_text() + '\n#include "weakref_save_adapter.dm"\n')

def replace_once(path, old, new):
    source = path.read_text()
    if source.count(old) != 1:
        raise RuntimeError('Mutation anchor changed: ' + path.name)
    path.write_text(source.replace(old, new, 1))

if args.negative_control == 'export':
    replace_once(root / 'functions.dm', 'if (persistence_runtime_var(key))',
                 'if (key != "weak_reference" && persistence_runtime_var(key))')
    replace_once(root / 'saving.dm', 'if(A.persistence_runtime_var(v))',
                 'if(v != "weak_reference" && A.persistence_runtime_var(v))')
elif args.negative_control == 'import':
    replace_once(root / 'loading.dm', 'if(object.persistence_runtime_var(v))',
                 'if(v != "weak_reference" && object.persistence_runtime_var(v))')

inputs = ['tests/hover_name/run-weakref-save.py', 'tests/hover_name/weakref_save_probe.dm',
          'tests/world_save/run-string-path.py', 'code/_onclick/hud/hover_name.dm',
          'code/datums/weakref.dm', 'code/game/mob/living/carbon/human/human.dm']
manifest = json.loads((root / 'source-inputs.json').read_text())
manifest['original'].update({name: hashlib.sha256((repo / name).read_bytes()).hexdigest() for name in inputs})
manifest['generated'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                         for p in root.iterdir() if p.suffix in ('.dm', '.dme')}
(root / 'source-inputs.json').write_text(json.dumps(manifest, indent=2) + '\n')
if args.prepare_only:
    print('PASS source preparation only; no native process launched')
    raise SystemExit(0)

flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=root,
                       capture_output=True, text=True, timeout=60, creationflags=flags)
print(build.stdout, build.stderr)
if build.returncode or '516.1681' not in build.stdout or '0 errors, 0 warnings' not in build.stdout:
    raise RuntimeError('Pinned clean compilation required')
run = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-safe', '-log', 'runtime.log'],
                     cwd=root, capture_output=True, text=True, timeout=60, creationflags=flags)
log = (root / 'runtime.log').read_text(errors='replace')
print(log)
if run.returncode or DIAGNOSTIC.search(log + '\n' + run.stdout + '\n' + run.stderr):
    raise RuntimeError('Invalid native execution')
actual = (root / 'result.txt').read_text().strip()
expected = {'export': 'weak reference cache exported', 'import': 'restored own hover lost public name'}
if args.negative_control:
    failure = (root / 'failure-name.txt').read_text().strip()
    if not actual.startswith('FAIL:') or failure != expected[args.negative_control]:
        raise RuntimeError('Mutation failed at an unexpected assertion: ' + failure)
    print('PASS weak reference negative control: ' + args.negative_control)
elif actual != 'PASS' or 'PASS weak reference save migration and restored own hover' not in log:
    raise RuntimeError('Weak-reference migration regression failed: ' + actual)
else:
    print('PASS weak reference disk migration and production hover')
