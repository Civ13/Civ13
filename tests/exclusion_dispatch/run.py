"""Native comparison of production exclusion hooks and complete saved-var selection."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
from resources import Budget, DIAGNOSTIC, binary_info
from source_contract import validate

BASE = '5a4b911a2ced3700fe19bd524b6c04046755e679'
PATH = 'code/modules/persistence/functions.dm'
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--byond-bin', type=Path)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--source-only', action='store_true')
p.add_argument('--expected-inputs', type=Path)
p.add_argument('--lease-receipt', type=Path)
p.add_argument('--negative-control', choices=['omit', 'parent', 'eager'])
p.add_argument('--benchmark', action='store_true')
p.add_argument('--calls', type=int, default=10000, choices=[10000, 20000, 40000])
a = p.parse_args()
repo = Path(__file__).resolve().parents[2]
old = subprocess.check_output(['git', 'show', BASE + ':' + PATH], cwd=repo, text=True)
current = (repo / PATH).read_text()
validate(old, current)

def proc(text, path):
    return re.search(r'^' + re.escape(path) + r'\n(?:\t[^\n]*\n)+', text, re.M).group()

inherited = ''
for file, path in [
    ('code/processes/human_corpse_decay.dm', '/atom/movable/persistence_runtime_var(key)'),
    ('code/processes/abandoned_items.dm', '/obj/item/persistence_runtime_var(key)'),
    ('code/modules/1713/active_training.dm', '/mob/living/human/persistence_runtime_var(key)'),
]:
    helper = (repo / file).read_text()
    pinned = subprocess.check_output(['git', 'show', BASE + ':' + file], cwd=repo, text=True)
    assert helper == pinned, f'Inherited helper drift: {file}'
    inherited += proc(helper, path) + '\n'
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
header = f'#define BENCH_CALLS {a.calls}\n' + ('#define BENCHMARK\n' if a.benchmark else '') + '#include "probe.dm"\n#include "production.dm"\n'
inputs = {name: hashlib.sha256(content.encode()).hexdigest() for name, content in {
    'production.dm': source, 'probe.dm': probe, 'probe.dme': header,
    'source_contract.py': Path(__file__).with_name('source_contract.py').read_text(),
    'runner.py': Path(__file__).read_text(), 'resources.py': Path(__file__).with_name('resources.py').read_text(),
}.items()}
compiler = a.byond_bin.resolve() / ('dm.exe' if os.name == 'nt' else 'DreamMaker') if a.byond_bin else None
daemon = a.byond_bin.resolve() / ('dd.exe' if os.name == 'nt' else 'DreamDaemon') if a.byond_bin else None
compiler_args = ['-max_errors', '0', 'probe.dme']
daemon_args = ['probe.dmb', '-ip', '127.0.0.1', '-invisible', '-close', '-trusted', '-log', 'runtime.log']
binaries = {name: binary_info(path)
            for name, path in [('compiler', compiler), ('daemon', daemon)] if path}
commands = dict(compiler=compiler_args, daemon=daemon_args)
assert not a.output.exists(), 'Output must be fresh'
a.output.parent.mkdir(parents=True, exist_ok=True)
if a.source_only:
    generated = a.output.with_suffix('.sources')
    generated.mkdir(exist_ok=False)
    for name, content in [('production.dm', source), ('probe.dm', probe), ('probe.dme', header)]:
        (generated / name).write_text(content)
    a.output.write_text(json.dumps(dict(status='source-only; native not run',
        head_sha=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip(),
        baseline_sha=BASE, compiled_sha256=hashlib.sha256(source.encode()).hexdigest(),
        probe_sha256=hashlib.sha256(probe.encode()).hexdigest(), inputs=inputs, binaries=binaries,
        commands=commands, required_version='516.1681', native_execution=False,
        execution_authorization='HELD: fresh maintainer approval and exact-head review required; old leases invalid'), indent=2) + '\n')
    sys.exit(0)
raise SystemExit('Native execution held: fresh maintainer approval and exact-head review required; old leases invalid')
# A lease receipt is recorded only after the core owner explicitly grants a slot.
# It is an audit guard, not a substitute for that authorization.
if not a.lease_receipt:
    raise SystemExit('Native execution held: reviewed core lease receipt required')
lease = json.loads(a.lease_receipt.read_text())
assert lease['head'] == subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
issued = datetime.fromisoformat(lease['issued_utc'])
expires = datetime.fromisoformat(lease['expires_utc'])
assert 0 < (expires - issued).total_seconds() <= 90, 'All commands share at most one 90-second lease'
assert issued <= datetime.now(timezone.utc) < expires
assert 0 < lease['deadline_monotonic'] - lease['issued_monotonic'] <= 90
assert lease['issued_monotonic'] <= time.monotonic() < lease['deadline_monotonic']
mode = 'benchmark' if a.benchmark else (a.negative_control or 'parity')
assert mode in lease['modes'] and a.calls <= lease['max_calls']
frozen = json.loads(a.expected_inputs.read_text()) if a.expected_inputs else {}
assert frozen.get('inputs') == inputs, 'Frozen inputs differ'
assert binaries and frozen['binaries'] == binaries == lease['binaries'], 'Trusted binaries differ'
assert commands == frozen['commands'] == lease['commands'], 'Frozen argv differs'
assert lease['required_version'] == frozen['required_version'] == '516.1681'
assert a.byond_bin, '--byond-bin required for native execution'
logs = a.output.with_suffix('.logs')
logs.mkdir(exist_ok=False)
budget = Budget(lease['issued_monotonic'], lease['deadline_monotonic'])
with tempfile.TemporaryDirectory(prefix='civ13-exclusion-') as temp:
    root = Path(temp)
    (root / 'production.dm').write_text(source)
    (root / 'probe.dm').write_text(probe)
    (root / 'probe.dme').write_text(header)
    assert binary_info(compiler) == binaries['compiler']
    build = budget.run([str(compiler)] + compiler_args, cwd=root, receipt=logs / 'compile-resource.json')
    log = (build.stdout + build.stderr).decode(errors='replace')
    (logs / 'compile.log').write_text(log)
    assert build.returncode == 0 and '516.1681' in log and '0 errors, 0 warnings' in log, log
    assert binary_info(daemon) == binaries['daemon']
    try:
        run = budget.run([str(daemon)] + daemon_args, cwd=root, receipt=logs / 'runtime-resource.json', wall_limit=60, diagnostic_file=root / 'runtime.log')
    finally:
        # Preserve failure diagnostics before TemporaryDirectory removes them.
        for name in ['runtime.log', 'network-failure.json', 'result.json']:
            if (root / name).exists():
                (logs / name).write_bytes((root / name).read_bytes())
    log = (root / 'runtime.log').read_text(errors='replace') + (run.stdout + run.stderr).decode(errors='replace')
    (logs / 'runtime.log').write_text(log)
    if (root / 'network-failure.json').exists():
        (logs / 'network-failure.json').write_bytes((root / 'network-failure.json').read_bytes())
    assert run.returncode == 0 and '516.1681' in log and not DIAGNOSTIC.search(log), log
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
