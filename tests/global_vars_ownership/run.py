"""Native production global-controller vars snapshot check; no game startup."""
import argparse, hashlib, json, os, re, subprocess, tempfile
from pathlib import Path
BASELINE = 'f6d769d3751275f63a4481db61290dde79e9cbb4'
p = argparse.ArgumentParser()
p.add_argument('--byond-bin', type=Path, required=True)
p.add_argument('--baseline', action='store_true')
p.add_argument('--evidence-dir', type=Path, required=True)
a = p.parse_args()
if a.baseline and os.name != "nt":
    p.error("Historical native diagnostic control is verified only on Windows BYOND 516.1681; run the fixed-source check on this platform")
r = Path(__file__).resolve().parents[2]
relative = 'code/controllers/mc/globals.dm'
source = subprocess.check_output(['git','show',BASELINE+':'+relative], cwd=r, text=True) if a.baseline else (r/relative).read_text()
head = subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip()
baseline = subprocess.check_output(['git','rev-parse',BASELINE],cwd=r,text=True).strip()
dirty = subprocess.check_output(['git','status','--porcelain'],cwd=r,text=True)
probe = Path(__file__).with_name('probe.dm').read_text()
if a.evidence_dir.exists() and any(a.evidence_dir.iterdir()): raise SystemExit('Choose fresh retained evidence directory')
a.evidence_dir.mkdir(parents=True,exist_ok=True)
for name, content in [('production.dm',source),('probe.dm',probe),('probe.dme','#include "probe.dm"\n#include "production.dm"\n')]:
    (a.evidence_dir/name).write_text(content)
(a.evidence_dir/'metadata.json').write_text(json.dumps({'head':head,'source_commit':baseline if a.baseline else head,'dirty':False if a.baseline else bool(dirty),'baseline':a.baseline,'source_sha256':hashlib.sha256(source.encode()).hexdigest()},indent=2))
flags = subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0
compiler = a.byond_bin/('dm.exe' if os.name=='nt' else 'DreamMaker')
daemon = a.byond_bin/('dd.exe' if os.name=='nt' else 'DreamDaemon')
build = subprocess.run([str(compiler),'probe.dme'],cwd=a.evidence_dir,text=True,capture_output=True,timeout=60,creationflags=flags)
compile_log = build.stdout+build.stderr
(a.evidence_dir/'compile.log').write_text(compile_log)
print(compile_log,flush=True)
if build.returncode or 'DM compiler version 516.1681' not in compile_log or '0 errors, 0 warnings' not in compile_log: raise SystemExit('Pinned fixture compile failed')
run = subprocess.run([str(daemon),'probe.dmb','-invisible','-close','-safe','-log','runtime.log'],cwd=a.evidence_dir,capture_output=True,timeout=20,creationflags=flags)
log = (a.evidence_dir/'runtime.log').read_text()
(a.evidence_dir/'daemon.log').write_bytes(run.stdout+run.stderr)
print(log,flush=True)
engine_log = log + '\n' + (run.stdout + run.stderr).decode('utf-8', errors='replace')
errors = bool(re.search(r'runtime error|RUNTIME|Bad ref|Bad loc|BUG:|## ERROR:|WARNING ',engine_log,re.I))
if run.returncode or 'FAIL ' in log or 'PASS globals name snapshot' not in log: raise SystemExit('Native fixture failed')
if a.baseline:
    if not re.findall(r'^BUG: Bad ref.*DecRefCount\(DM New\)',log,re.M): raise SystemExit('Expected historical native Bad ref diagnostic was absent')
    remainder = re.sub(r'^BUG: (?:Bad ref.*DecRefCount\(DM New\)|Call stack:.*)\n?', '', engine_log, flags=re.M)
    if re.search(r'runtime error|RUNTIME|Bad ref|Bad loc|BUG:|## ERROR:|WARNING ',remainder,re.I): raise SystemExit('Unexpected baseline diagnostics invalidate control')
    print('PASS baseline diagnostic control: native Bad ref detected; baseline is invalid production evidence')
else:
    if errors: raise SystemExit('Native diagnostics invalidate fixed acceptance')
    print('PASS fixed global-controller production snapshot without native diagnostics')
(a.evidence_dir/'result.json').write_text(json.dumps({'passed':True,'baseline_control':a.baseline,'native_diagnostics_present':errors},indent=2))
