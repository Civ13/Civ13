"""Native production NPC cover parity, controls and paired benchmarks."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

BASELINE = '1627730ecec53f385cbf1956b7a9e4385dffa675'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--byond-bin', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--benchmark', action='store_true')
parser.add_argument('--negative-control', choices=['boundary', 'tie'])
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
path = 'code/game/mob/living/simple_animal/hostile/tactical_ai.dm'
baseline = subprocess.check_output(['git', 'show', BASELINE + ':' + path], cwd=repo, text=True)
current = (repo / path).read_text()
def cover(text):
    return re.search(r'^/mob/living/simple_animal/hostile/human/proc/find_best_cover\(atom/enemy\)\n[\s\S]*?(?=^// Checks if)', text, re.M).group()
candidate = cover(current)
if args.negative_control == 'boundary':
    assert 'get_dist(T, H) <= 5' in candidate
    candidate = candidate.replace('get_dist(T, H) <= 5', 'get_dist(T, H) < 5')
elif args.negative_control == 'tie':
    assert 'score > best_score' in candidate
    candidate = candidate.replace('score > best_score', 'score >= best_score')
def named(body, name, trace):
    body = body.replace('find_best_cover(', name + '(')
    if trace:
        assert '\t\tif(score >' in body or '\t\tif(score >=' in body
        body = body.replace('\t\tif(score >', '\t\tprobe_scores["[T.x],[T.y],[T.z]"] = score\n\t\tif(score >')
    return body
helpers = baseline[:baseline.index('// Finds the best nearby cover')]
assert helpers == current[:current.index('// Finds the best nearby cover')], 'Cover/LOS helper drift needs separate baseline handling'
unsorted = (repo / 'code/_helpers/unsorted.dm').read_text()
line = re.search(r'^/proc/getline2\([\s\S]*?(?=^#define LOCATE_COORDS)', unsorted, re.M).group()
macros = (repo / 'code/_macros.dm').read_text()
get_turf = re.search(r'^#define get_turf\(A\) .+$', macros, re.M).group()
source = get_turf + '\n' + helpers + line
for body, prefix in [(cover(baseline), 'baseline'), (candidate, 'candidate')]:
    source += named(body, prefix + '_cover', True)
    source += named(body, prefix + '_bench', False)
probe = Path(__file__).with_name('probe.dm').read_text()
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
args.output.parent.mkdir(parents=True, exist_ok=True)
if args.output.exists():
    parser.error('Output must be fresh')
logs = args.output.with_suffix('.logs')
logs.mkdir(exist_ok=False)
flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
with tempfile.TemporaryDirectory(prefix='civ13-npc-cover-') as temp:
    root = Path(temp)
    (root / 'probe.dm').write_text(probe)
    (root / 'production.dm').write_text(source)
    (root / 'probe.dme').write_text(('#define BENCHMARK\n' if args.benchmark else '') + '#include "probe.dm"\n#include "production.dm"\n')
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=root, capture_output=True, text=True, timeout=60, creationflags=flags)
    log = build.stdout + build.stderr
    (logs / 'compile.log').write_text(log)
    if build.returncode or '516.1681' not in log or '0 errors, 0 warnings' not in log:
        raise SystemExit(log)
    run = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-close', '-safe', '-log', 'runtime.log'], cwd=root, capture_output=True, timeout=180, creationflags=flags)
    log = (root / 'runtime.log').read_text(errors='replace') + (run.stdout + run.stderr).decode(errors='replace')
    (logs / 'runtime.log').write_text(log)
    if run.returncode or re.search(r'runtime error|Bad ref|Bad loc|Cannot read null|Cannot execute null', log, re.I):
        raise SystemExit(log)
    result = json.loads((root / 'result.json').read_text())
    result.update(head_sha=head, baseline_sha=BASELINE, source_sha256=hashlib.sha256(current.encode()).hexdigest(), compiled_sha256=hashlib.sha256(source.encode()).hexdigest(), probe_sha256=hashlib.sha256(probe.encode()).hexdigest(), platform=os.name, byond='516.1681', dimensions=[32,32,2], negative_control=args.negative_control, benchmark=args.benchmark)
    (logs / 'dirty.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=repo))
    args.output.write_text(json.dumps(result, indent=2))
    if result['scenarios'] != 100 or result['score_comparisons'] < 1000:
        raise SystemExit('Incomplete parity work')
    if args.negative_control:
        if not result['failures']:
            raise SystemExit('Negative control was not detected')
    elif result['failures']:
        raise SystemExit('Parity failed: ' + str(result['failures']) + '; see ' + str(args.output))
    if args.benchmark and (len(result['samples']) != 30 or any(row['calls'] != 1000 for row in result['samples'])):
        raise SystemExit('Incomplete benchmark')
    print(json.dumps({key: result[key] for key in ('scenarios', 'score_comparisons', 'failures', 'negative_control', 'benchmark')}))
    print('Evidence: ' + str(args.output))
