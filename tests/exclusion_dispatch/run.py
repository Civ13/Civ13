"""Native comparison of production exclusion hooks and complete saved-var selection."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

BASE = '41e2d02fe1f9130e0987aee0efd2eba0ca7b3bf1'
PATH = 'code/modules/persistence/functions.dm'
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--byond-bin', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--negative-control', choices=['omit', 'parent', 'eager'])
p.add_argument('--benchmark', action='store_true')
p.add_argument('--calls', type=int, default=10000, choices=[10000, 20000, 40000])
a = p.parse_args()
repo = Path(__file__).resolve().parents[2]
old = subprocess.check_output(['git', 'show', BASE + ':' + PATH], cwd=repo, text=True)
current = (repo / PATH).read_text()
expected = old
for kind in ['atom', 'turf', 'mob']:
    pattern = rf'^/{kind}/persistence_runtime_var\(key\)\n\treturn \(key in list\((.*?)\)\) \|\| \.\.\(\)'
    m = re.search(pattern, expected, re.M)
    assert m, kind
    replacement = f'/{kind}/persistence_runtime_var(key)\n\tswitch(key)\n\t\tif ({m[1]})\n\t\t\treturn TRUE\n\treturn ..()'
    expected = expected[:m.start()] + replacement + expected[m.end():]
assert expected == current, 'Only the three approved hook transformations may differ'

def proc(text, path):
    return re.search(r'^' + re.escape(path) + r'\n(?:\t[^\n]*\n)+', text, re.M).group()

inherited = ''
for file, path in [
    ('code/processes/human_corpse_decay.dm', '/atom/movable/persistence_runtime_var(key)'),
    ('code/processes/abandoned_items.dm', '/obj/item/persistence_runtime_var(key)'),
    ('code/modules/1713/active_training.dm', '/mob/living/human/persistence_runtime_var(key)'),
]:
    inherited += proc((repo / file).read_text(), path) + '\n'
source = ''
for variant, text in [('baseline', old), ('candidate', current)]:
    hooks = '\n'.join(proc(text, f'/{kind}/persistence_runtime_var(key)') for kind in ['atom', 'turf', 'mob'])
    root = proc(text, '/datum/proc/persistence_runtime_var(key)')
    if variant == 'candidate':
        if a.negative_control == 'omit':
            hooks = hooks.replace('"appearance", ', '')
        elif a.negative_control == 'parent':
            hooks = hooks.replace('return ..()', 'return FALSE')
        elif a.negative_control == 'eager':
            hooks = hooks.replace('\tswitch(key)', '\t..()\n\tswitch(key)')
    for traced in [False, True]:
        suffix = variant + ('_traced' if traced else '_runtime')
        adapted_root = root
        if traced:
            adapted_root = root.replace('\treturn ', '\tparent_trace += "root"\n\tif(mutate_parent) value++\n\treturn ')
        source += (adapted_root + '\n' + hooks + '\n' + inherited).replace('persistence_runtime_var', suffix) + '\n'
    saved = re.search(r'^/datum/proc/get_saved_vars\(\)\n[\s\S]*?(?=^// The composite)', text, re.M).group()
    source += saved.replace('get_saved_vars', variant + '_saved').replace('persistence_runtime_var', variant + '_runtime')
    source += proc(text, '/turf/floor/dirt/get_saved_vars()').replace('get_saved_vars', variant + '_saved') + '\n'

probe = Path(__file__).with_name('probe.dm').read_text()
assert not a.output.exists(), 'Output must be fresh'
a.output.parent.mkdir(parents=True, exist_ok=True)
logs = a.output.with_suffix('.logs')
logs.mkdir(exist_ok=False)
flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
with tempfile.TemporaryDirectory(prefix='civ13-exclusion-') as temp:
    root = Path(temp)
    (root / 'production.dm').write_text(source)
    (root / 'probe.dm').write_text(probe)
    (root / 'probe.dme').write_text(f'#define BENCH_CALLS {a.calls}\n' + ('#define BENCHMARK\n' if a.benchmark else '') + '#include "probe.dm"\n#include "production.dm"\n')
    compiler = a.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = a.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=root, capture_output=True, text=True, timeout=30, creationflags=flags)
    log = build.stdout + build.stderr
    (logs / 'compile.log').write_text(log)
    assert build.returncode == 0 and '516.1681' in log and '0 errors, 0 warnings' in log, log
    run = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-close', '-safe', '-log', 'runtime.log'], cwd=root, capture_output=True, timeout=60, creationflags=flags)
    log = (root / 'runtime.log').read_text(errors='replace') + (run.stdout + run.stderr).decode(errors='replace')
    (logs / 'runtime.log').write_text(log)
    assert run.returncode == 0 and not re.search(r'runtime error|Bad ref|Bad loc|Cannot read null|Cannot execute null', log, re.I), log
    result = json.loads((root / 'result.json').read_text())
    result.update(head_sha=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip(), baseline_sha=BASE, negative_control=a.negative_control, benchmark=a.benchmark, calls=a.calls, byond='516.1681', platform=os.name,
                  source_sha256=hashlib.sha256(current.encode()).hexdigest(), compiled_sha256=hashlib.sha256(source.encode()).hexdigest(), probe_sha256=hashlib.sha256(probe.encode()).hexdigest())
    (logs / 'dirty.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=repo))
    a.output.write_text(json.dumps(result, indent=2) + '\n')
    assert result['cases'] >= 800, 'Incomplete fixture'
    assert (result['failures'] > 0) if a.negative_control else (result['failures'] == 0), result
    if a.benchmark:
        assert len(result['samples']) == 30 and all(row['calls'] == a.calls for row in result['samples'])
    print(json.dumps({key: result[key] for key in ['cases', 'failures', 'negative_control', 'benchmark']}))
