"""Bounded native differential checks for production get_saved_vars."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

BASELINE = '41e2d02fe1f9130e0987aee0efd2eba0ca7b3bf1'
PATH = 'code/modules/persistence/functions.dm'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--byond-bin', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--negative-control', choices=['order', 'exclusion', 'repeat'])
parser.add_argument('--benchmark', action='store_true')
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
baseline = subprocess.check_output(['git', 'show', BASELINE + ':' + PATH], cwd=repo, text=True)
current = (repo / PATH).read_text()
def body(text):
    return re.search(r'^/datum/proc/get_saved_vars\(\)\n[\s\S]*?(?=^// The composite)', text, re.M).group()
old, new = body(baseline), body(current)
expected = old.replace('\telse\n\t\tfor (var/key', '\telse\n\t\tvar/name_saved = FALSE\n\t\tfor (var/key').replace('\t\t\tto_save |= "name"', '\t\t\tif (!name_saved)\n\t\t\t\tto_save |= "name"\n\t\t\t\tname_saved = TRUE')
assert new == expected, 'Production drift requires fixture review'
if args.negative_control == 'order':
    new = new.replace('\t\tvar/name_saved = FALSE', '\t\tto_save |= "name"\n\t\tvar/name_saved = TRUE')
elif args.negative_control == 'exclusion':
    new = new.replace('if (persistence_runtime_var(key))', 'if (FALSE)')
elif args.negative_control == 'repeat':
    new = old

# Import production runtime-exclusion and dirt override bodies, with only names renamed.
helpers = '\n'.join(re.findall(r'^/(?:datum|atom|turf|mob)/persistence_runtime_var\(key\)\n(?:\t[^\n]*\n)+', current, re.M))
helpers = '/datum/proc/persistence_runtime_var(key)\n\treturn key == "persistence_export_frame"\n' + helpers
dirt = re.search(r'^/turf/floor/dirt/get_saved_vars\(\)\n(?:\t[^\n]*\n)+', current, re.M).group()
source = helpers
for name, production in [('baseline', old), ('candidate', new)]:
    for measured in [False, True]:
        suffix = name + ('_counted' if measured else '_saved')
        text = production.replace('get_saved_vars()', suffix + '()')
        if measured:
            text = re.sub(r'^(\s*)to_save \|= "name"$', r'\1probe_name_unions++\n\1to_save |= "name"', text, flags=re.M)
        source += '\n' + text + '\n' + dirt.replace('get_saved_vars()', suffix + '()')
probe = Path(__file__).with_name('probe.dm').read_text()
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
args.output.parent.mkdir(parents=True, exist_ok=True)
if args.output.exists():
    parser.error('Output must be fresh')
logs = args.output.with_suffix('.logs')
logs.mkdir(exist_ok=False)
flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
with tempfile.TemporaryDirectory(prefix='civ13-saved-vars-') as temp:
    root = Path(temp)
    (root / 'production.dm').write_text(source)
    (root / 'probe.dm').write_text(probe)
    (root / 'probe.dme').write_text(('#define BENCHMARK\n' if args.benchmark else '') + '#include "probe.dm"\n#include "production.dm"\n')
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=root, capture_output=True, text=True, timeout=45, creationflags=flags)
    log = build.stdout + build.stderr
    (logs / 'compile.log').write_text(log)
    if build.returncode or '516.1681' not in log or '0 errors, 0 warnings' not in log:
        raise SystemExit(log)
    run = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-close', '-safe', '-log', 'runtime.log'], cwd=root, capture_output=True, timeout=90, creationflags=flags)
    log = (root / 'runtime.log').read_text(errors='replace') + (run.stdout + run.stderr).decode(errors='replace')
    (logs / 'runtime.log').write_text(log)
    if run.returncode or re.search(r'runtime error|Bad ref|Bad loc|Cannot read null|Cannot execute null', log, re.I):
        raise SystemExit(log)
    result = json.loads((root / 'result.json').read_text())
    result.update(head_sha=head, baseline_sha=BASELINE, byond='516.1681', platform=os.name, negative_control=args.negative_control, benchmark=args.benchmark,
                  source_sha256=hashlib.sha256(current.encode()).hexdigest(), compiled_sha256=hashlib.sha256(source.encode()).hexdigest(), probe_sha256=hashlib.sha256(probe.encode()).hexdigest())
    (logs / 'dirty.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=repo))
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    assert result['cases'] >= 70 and len(result['counts']) >= 9, 'Incomplete fixture'
    if args.negative_control == 'repeat':
        assert result['failures'] == 0 and result['work_failures'] > 0, 'Repeated-work control not detected'
    elif args.negative_control:
        assert result['failures'] > 0, 'Behavior control not detected'
    else:
        assert result['failures'] == 0 and result['work_failures'] == 0, result
    if args.benchmark:
        assert len(result['samples']) == 30 and all(row['calls'] == 1000 for row in result['samples']), 'Incomplete benchmark'
    print(json.dumps({key: result[key] for key in ('cases', 'failures', 'work_failures', 'negative_control', 'benchmark')}))
