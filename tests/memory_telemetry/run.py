"""Production bounded telemetry native regression; no game startup."""
import argparse, hashlib, json, os, re, subprocess
from pathlib import Path
p = argparse.ArgumentParser()
p.add_argument('--byond-bin', type=Path, required=True)
p.add_argument('--evidence-dir', type=Path, required=True)
p.add_argument('--negative-control', choices=('overflow', 'rate', 'retention'))
a = p.parse_args()
r = Path(__file__).resolve().parents[2]
source = (r/'code/_helpers/memory_lifetime_telemetry.dm').read_text()
head = subprocess.check_output(['git','rev-parse','HEAD'], cwd=r, text=True).strip()
dirty = subprocess.check_output(['git','status','--porcelain'], cwd=r, text=True)
patch = subprocess.check_output(['git','diff','HEAD','--'], cwd=r)
if a.evidence_dir.exists() and any(a.evidence_dir.iterdir()): p.error('Choose a fresh evidence directory')
a.evidence_dir.mkdir(parents=True, exist_ok=True)
original = source
if a.negative_control:
    old, new = {
        'overflow': ('if (rows.len < 120)', 'if (rows.len < 10000)'),
        'rate': (' / span : 0', ' / 1 : 0'),
        'retention': ('"gc_queued" = G ? G.destroyed.len : 0,', '"retained_owner" = G,\n\t\t"gc_queued" = G ? G.destroyed.len : 0,')
    }[a.negative_control]
    expected = 2 if a.negative_control == 'rate' else 1
    assert source.count(old) == expected, 'Control anchor drift'
    source = source.replace(old, new)
probe = Path(__file__).with_name('probe.dm').read_text()
for name, content in [('production.dm', source), ('probe.dm', probe), ('probe.dme', '#include "probe.dm"\n#include "production.dm"\n')]:
    (a.evidence_dir/name).write_text(content)
(a.evidence_dir/'dirty.patch').write_bytes(patch)
(a.evidence_dir/'metadata.json').write_text(json.dumps({'head':head, 'dirty':bool(dirty), 'status':dirty, 'control':a.negative_control, 'production_sha256':hashlib.sha256(original.encode()).hexdigest(), 'compiled_sha256':hashlib.sha256(source.encode()).hexdigest(), 'probe_sha256':hashlib.sha256(probe.encode()).hexdigest()}, indent=2))
flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
compiler = a.byond_bin/('dm.exe' if os.name == 'nt' else 'DreamMaker')
daemon = a.byond_bin/('dd.exe' if os.name == 'nt' else 'DreamDaemon')
build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=a.evidence_dir, text=True, capture_output=True, timeout=60, creationflags=flags)
compile_log = build.stdout+build.stderr
(a.evidence_dir/'compile.log').write_text(compile_log)
print(compile_log, flush=True)
if build.returncode or '516.1681' not in compile_log or '0 errors, 0 warnings' not in compile_log: raise SystemExit('Pinned native compile failed')
run = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-close', '-safe', '-log', 'runtime.log'], cwd=a.evidence_dir, capture_output=True, timeout=30, creationflags=flags)
(a.evidence_dir/'daemon.log').write_bytes(run.stdout+run.stderr)
log = (a.evidence_dir/'runtime.log').read_text(errors='replace')
combined = log + (run.stdout+run.stderr).decode(errors='replace')
print(log, flush=True)
if run.returncode or re.search(r'runtime error|RUNTIME|Bad ref|Bad loc|BUG:|## ERROR:|WARNING ', combined, re.I): raise SystemExit('Native diagnostics invalidate evidence')
result = json.loads((a.evidence_dir/'result.json').read_text())
if result['checks'] != 45: raise SystemExit('Incomplete native fixture')
expected_failures = {
    'overflow': ['snapshot ring bounded after wrap', 'chronological wrapped export'],
    'rate': ['rates use observed seconds'],
    'retention': ['snapshot retains only scalars', 'row retains only scalars', 'native observed scalar sample', 'uninitialized processes supported']
}
if a.negative_control:
    if re.findall(r'^FAIL (.*)$', log, re.M) != expected_failures[a.negative_control] or result['failures'] != len(expected_failures[a.negative_control]): raise SystemExit('Expected control failures changed')
else:
    if result['failures']: raise SystemExit('Native checks failed')
print('PASS expected control' if a.negative_control else 'PASS production bounded telemetry')
