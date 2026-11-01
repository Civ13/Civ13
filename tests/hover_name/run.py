"""Exercise production hover callbacks and widget with an injected client boundary."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--byond-bin', type=Path, required=True)
parser.add_argument('--negative-control', choices=['identity', 'exit', 'stale', 'parent'])
parser.add_argument('--compile-only', action='store_true')
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]

def proc(path, declaration):
    text = (repo / path).read_text(encoding='utf-8')
    match = re.search('^' + re.escape(declaration) + r'[^\n]*\n(?:\t[^\n]*\n|\n)*', text, re.M)
    if not match:
        raise RuntimeError('Missing production declaration: ' + declaration)
    return match.group()

widget = (repo / 'code/_onclick/hud/hover_name.dm').read_text()
events = ''.join(proc('code/modules/client/client_procs.dm', name) for name in [
    '/client/MouseEntered(', '/client/MouseMove(', '/client/MouseDrag('])
identity = proc('code/game/mob/living/carbon/human/human.dm', '/mob/living/human/proc/get_visible_name(')
weakref = (repo / 'code/datums/weakref.dm').read_text()
runtime = proc('code/modules/persistence/functions.dm', '/datum/proc/persistence_runtime_var(')

def mutate(old, new):
    global widget
    assert widget.count(old) == 1, ('Mutation drift', old)
    widget = widget.replace(old, new)

if args.negative_control == 'identity':
    mutate('label = H.get_visible_name()', 'label = H.real_name')
elif args.negative_control == 'exit':
    mutate('label && label.hover_origin?.resolve() == object', 'label')
elif args.negative_control == 'stale':
    mutate('if (!origin || pointer_target(origin) != target || (hover_inventory && !inventory_target_current(target)) || !target_visible(target))\n\t\tclear_target()', 'if (!target)\n\t\tclear_target()')
elif args.negative_control == 'parent':
    mutate('|| ..()', '|| FALSE')

# Only the unavailable network-client boundary is adapted. All event and widget
# decisions, native view/loc/screen objects, weakrefs and visible names are real DM.
production = widget + events + identity + weakref + runtime
production = production.replace('/client/', '/datum/hover_client/')
production = production.replace('var/client/C', 'var/datum/hover_client/C')
production = production.replace('parentmob.client', 'parentmob.hover_client')

# Keep attachment, life dispatch and both persistence entry guards connected to
# production paths. These are wiring assertions, separate from the runtime cases.
hud = (repo / 'code/game/mob/living/carbon/human/human_hud.dm').read_text()
assert 'H.HUDneed["hover name"] = hover_label' in hud
assert 'H.HUDprocess += hover_label' in hud
life = (repo / 'code/game/mob/living/carbon/human/human_life.dm').read_text()
assert re.search(r'for \(var/obj/screen/H in HUDprocess\)\n(?:[^\n]*\n)?\s+H.process\(\)', life)
assert 'client?.clear_hover_name()' in (repo / 'code/game/mob/logout.dm').read_text()
assert 'clear_hover_name()' in proc('code/modules/client/client_procs.dm', '/client/Del(')
for path, guard in [('saving.dm', 'A.persistence_runtime_var(v)'), ('loading.dm', 'object.persistence_runtime_var(v)')]:
    assert guard in (repo / 'code/modules/persistence' / path).read_text()

flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
with tempfile.TemporaryDirectory(prefix='civ13-hover-name-') as temp:
    root = Path(temp)
    (root / 'production.dm').write_text(production)
    (root / 'fixture.dm').write_text(Path(__file__).with_name('fixture.dm').read_text() + '\n' + Path(__file__).with_name('own_body_probe.dm').read_text())
    (root / 'probe.dme').write_text('#include "fixture.dm"\n#include "production.dm"\n')
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    build = subprocess.run([str(compiler), 'probe.dme'], cwd=root, capture_output=True, text=True, timeout=30, creationflags=flags)
    print(build.stdout, build.stderr)
    if build.returncode or 'DM compiler version 516.1681' not in build.stdout or '0 errors, 0 warnings' not in build.stdout:
        raise RuntimeError('Pinned fixture compilation failed')
    if args.compile_only:
        print('PASS compile only; runtime not run')
        raise SystemExit(0)
    try:
        run = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-trusted', '-log', 'runtime.log'], cwd=root, capture_output=True, text=True, timeout=20, creationflags=flags)
    except subprocess.TimeoutExpired:
        print((root / 'runtime.log').read_text(errors='replace'))
        raise
    log = (root / 'runtime.log').read_text(errors='replace')
    print(log)
    if run.returncode or re.search(r'runtime error|bad ref|bad index', log, re.I):
        raise RuntimeError('Invalid native execution')
    expected = {'identity': 'masked identity', 'exit': 'late exit', 'stale': 'hidden target', 'parent': 'parent exclusion'}
    if args.negative_control:
        if 'FAIL ' + expected[args.negative_control] not in log:
            raise RuntimeError('Negative control did not fail the intended assertion')
        print('PASS negative control:', args.negative_control)
    elif 'FAIL ' in log or 'PASS hover name' not in log:
        raise RuntimeError('Hover-name regression failed')
