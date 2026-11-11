"""Headless production qdel/ownership regression with isolated storage."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import os

parser = argparse.ArgumentParser()
parser.add_argument('--byond-bin', required=True, type=Path)
parser.add_argument('--negative-control', action='store_true', help='Remove retirement guards from a generated source copy')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
logs = Path(tempfile.mkdtemp(prefix='civ13-retired-owner-'))
print(f'Evidence: {logs}', flush=True)
prefix = '.retired_owner'
generated = [root / (prefix + suffix) for suffix in ('.dme', '_world.dm', '_globals.dm', '.dmb', '.rsc', '_reclaim.dm')]
if any(path.exists() for path in generated):
    raise RuntimeError('Existing generated files must be preserved')
flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
try:
    world = (root / 'code/world.dm').read_text(encoding='utf-8')
    world = world.replace('/world/New()', '/world/proc/unused_owner_startup()', 1)
    start = world.index('/world/proc/unused_owner_startup()')
    parent = world.index('\n\t..()', start)
    world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
    world = world.replace('/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n', 1)
    generated[1].write_text(world, encoding='utf-8')
    globals_source = (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
    marker = '/datum/controller/global_vars/New()\n'
    assert globals_source.count(marker) == 1
    generated[2].write_text(globals_source.replace(marker, marker + '\treturn\n'), encoding='utf-8')
    source = (root / 'civ13.dme').read_text(encoding='utf-8')
    source = source.replace('code\\world.dm', prefix + '_world.dm')
    source = source.replace('code\\controllers\\mc\\globals.dm', prefix + '_globals.dm')
    source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
    reclaim = (root / 'code/modules/persistence/player_reclaim.dm').read_text(encoding='utf-8')
    if args.negative_control:
        guard = '\t\tif(QDELETED(H) || H.gcDestroyed) continue\n'
        assert reclaim.count(guard) == 3
        reclaim = reclaim.replace(guard, '')
    generated[5].write_text(reclaim, encoding='utf-8')
    source = source.replace('code\\modules\\persistence\\player_reclaim.dm', prefix + '_reclaim.dm')
    generated[0].write_text(source + '\n#include "tests/world_save/retired_owner_probe.dm"\n', encoding='utf-8')
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    compile_result = subprocess.run([str(compiler), str(generated[0])], cwd=root, capture_output=True, text=True, timeout=240, creationflags=flags)
    (logs / 'compile.log').write_text(compile_result.stdout + compile_result.stderr)
    print(compile_result.stdout + compile_result.stderr, flush=True)
    if compile_result.returncode or '0 errors, 0 warnings' not in compile_result.stdout: raise RuntimeError('Compile failed')
    for path in generated:
        shutil.copy2(path, logs / path.name)
    shutil.copy2(root / 'tests/world_save/retired_owner_probe.dm', logs / 'probe.dm')
    shutil.copy2(root / 'code/modules/persistence/player_reclaim.dm', logs / 'player_reclaim.dm')
    shutil.copytree(root / 'config/names', logs / 'config/names')
    runtime = subprocess.run([str(daemon), str(logs / (prefix + '.dmb')), *(['-invisible', '-close'] if os.name == 'nt' else []), '-trusted', '-log', 'runtime.log'], cwd=logs, capture_output=True, text=True, timeout=120, creationflags=flags)
    (logs / 'daemon.log').write_text(runtime.stdout + runtime.stderr)
    diagnostics = (logs / 'runtime.log').read_text(errors='replace') if (logs / 'runtime.log').exists() else ''
    if re.search(r'runtime error:|bad ref|BUG:|##\s*ERROR:|RUNTIME:|infinite loop|segmentation|fatal error', diagnostics, re.I):
        raise RuntimeError('Unexpected engine diagnostic; see runtime.log')
    (logs / 'revision.txt').write_text(subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True) + subprocess.check_output(['git', 'diff'], cwd=root, text=True))
    result = (logs / 'result.txt').read_text()
    print(result, flush=True)
    expected = 'FAIL: Invalid or duplicate durable player ownership' if args.negative_control else 'PASS:'
    if runtime.returncode or expected not in result or (not args.negative_control and 'FAIL:' in result):
        raise RuntimeError('Unexpected fixture result')
finally:
    for path in generated:
        path.unlink(missing_ok=True)
