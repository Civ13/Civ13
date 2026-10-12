"""Native production scheduler-loop and deferred history lifecycle regression."""
import argparse, hashlib, json, os, re, subprocess, tempfile
from pathlib import Path
BASELINE = '7cfa850bd9d2788dcbb9fd35f5c5915ccb528dd2'
p = argparse.ArgumentParser()
p.add_argument('--byond-bin', type=Path, required=True)
p.add_argument('--baseline', action='store_true')
p.add_argument('--negative-control', choices=('token', 'deadline', 'successful-run', 'exhausted-snapshot', 'relay-result'))
p.add_argument('--evidence-dir', type=Path)
a = p.parse_args()
if a.baseline and a.negative_control: p.error('Choose one control')
r = Path(__file__).resolve().parents[2]
paths = ['code/processes/__processScheduler.dm', 'code/processes/_process.dm']
raw = [subprocess.check_output(['git','show',BASELINE+':'+x], cwd=r, text=True) if a.baseline else (r/x).read_text() for x in paths]
head = subprocess.check_output(['git','rev-parse','HEAD'], cwd=r, text=True).strip()
dirty = subprocess.check_output(['git','status','--porcelain'], cwd=r, text=True)
patch = subprocess.check_output(['git','diff','HEAD','--'], cwd=r)
scheduler_patterns = [r'/processScheduler/proc/relayProcess\([^\n]*\)[\s\S]*?(?=/processScheduler/proc/addProcess\()', r'/processScheduler/proc/start\(\)[\s\S]*?(?=/processScheduler/proc/process\()', r'/processScheduler/proc/process\([^\n]*\)[\s\S]*?(?=/processScheduler/proc/stop\()', r'/processScheduler/proc/stop\(\)[\s\S]*?(?=/processScheduler/proc/checkRunningProcesses\()', r'/processScheduler/proc/recordRunTime\([^\n]*\)[\s\S]*?(?=/\*\*)']
process_patterns = [r'/process/proc/process\(\)[\s\S]*?(?=/process/proc/running\()', r'/process/proc/fire_as_member\(\)[\s\S]*?(?=/process/proc/setup\()', r'/process/proc/finished\([^\n]*\)[\s\S]*?(?=/process/proc/fire\()', r'/process/proc/started\(\)[\s\S]*?(?=/process/proc/finished\()', r'/process/proc/may_run\([^\n]*\)[\s\S]*?(?=/datum/subsystem_module)']
source = '\n'.join(re.search(pattern, raw[index]).group() for index, patterns in enumerate([scheduler_patterns, process_patterns]) for pattern in patterns)
defines = (r/'code/processes/___defines.dm').read_text()
macros = '\n'.join(line for line in defines.splitlines() if line.startswith(('#define PROCESS_TICK_CHECK_RETURNED_EARLY ', '#define PROCESS_LIST_CHECK ', '#define PROCESS_TICK_CHECK ')))
assert len(macros.splitlines()) == 3
if a.negative_control == 'relay-result':
    old = '\tif (fire_result == PROCESS_TICK_CHECK_RETURNED_EARLY && !length(current_list))\n\t\tfire_result = null\n'
    assert source.count(old) == 1
    source = source.replace(old, '')
elif a.negative_control == 'exhausted-snapshot':
    old = 'if (fire_result != PROCESS_TICK_CHECK_RETURNED_EARLY || !length(current_list))'
    assert source.count(old) == 1
    source = source.replace(old, 'if (fire_result != PROCESS_TICK_CHECK_RETURNED_EARLY)')
    source = source.replace('\tif (fire_result == PROCESS_TICK_CHECK_RETURNED_EARLY && !length(current_list))\n\t\tfire_result = null\n', '')
elif a.negative_control == 'token':
    for old,new in [('if (!isRunning || run_token != token)', 'if (!isRunning)'), ('while (isRunning && run_token == token)', 'while (isRunning)')]:
        assert source.count(old) == 1
        source = source.replace(old,new)
elif a.negative_control == 'deadline':
    old = 'if (!. && !runtime_history_reset_at)'
    assert source.count(old) == 1
    source = source.replace(old,'if (!.)')
elif a.negative_control == 'successful-run':
    old = '/process/proc/started()\n\t// A newly admitted run must not lose its history to an old denial.\n\truntime_history_reset_at = 0'
    assert source.count(old) == 1
    source = source.replace(old,'/process/proc/started()')
# Count actual scheduled callbacks in generated historical code without changing timing.
old = '\t\tspawn (schedule_interval)\n\t\t\tmain.last_twenty_run_times[src]:Cut()'
if a.baseline:
    assert source.count(old) == 1
    source = source.replace(old, '\t\tsleepers_pending++\n\t\tsleepers_peak = max(sleepers_peak, sleepers_pending)\n\t\tspawn (schedule_interval)\n\t\t\tsleepers_pending--\n\t\t\tmain.last_twenty_run_times[src]:Cut()')
else:
    assert old not in source
expected = {
    'baseline': ['repeated start has one scheduler cadence', 'stop restart cancels previous sleeping chain', 'watchdog start replaces active scheduler chain', 'repeated denial creates no callback backlog', 'successful bypass run history survives old deadline', 'final-entry budget return releases exhausted snapshot', 'exhausted process returns normal completion', 'exhausted relay dispatches only once', 'exhausted member returns normal completion'],
    'exhausted-snapshot': ['final-entry budget return releases exhausted snapshot', 'exhausted process returns normal completion', 'exhausted relay dispatches only once', 'exhausted member returns normal completion'],
    'relay-result': ['exhausted process returns normal completion', 'exhausted relay dispatches only once', 'exhausted member returns normal completion'],
    'token': ['repeated start has one scheduler cadence', 'stop restart cancels previous sleeping chain', 'watchdog start replaces active scheduler chain'],
    'deadline': ['denials do not postpone original expiry', 'expired history clears only on admission query'],
    'successful-run': ['successful bypass run history survives old deadline'],
}
probe = Path(__file__).with_name('probe.dm').read_text()
flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
compiler = a.byond_bin/('dm.exe' if os.name == 'nt' else 'DreamMaker')
daemon = a.byond_bin/('dd.exe' if os.name == 'nt' else 'DreamDaemon')
with tempfile.TemporaryDirectory(prefix='civ13-process-loops-') as directory:
    out = a.evidence_dir or Path(directory)
    if out.exists() and any(out.iterdir()): p.error('Evidence directory must be fresh')
    out.mkdir(parents=True, exist_ok=True)
    for name, content in [('scheduler-source.dm',raw[0]),('process-source.dm',raw[1]),('production-defines.dm',defines),('fixture-macros.dm',macros),('production.dm',source),('probe.dm',probe),('probe.dme','#include "fixture-macros.dm"\n#include "probe.dm"\n#include "production.dm"\n')]:
        (out/name).write_text(content)
    (out/'dirty.patch').write_bytes(patch)
    metadata = {'head':head,'source_commit':BASELINE if a.baseline else head,'dirty':False if a.baseline else bool(dirty),'checkout_status':dirty,'baseline':a.baseline,'control':a.negative_control,'source_sha256':[hashlib.sha256(x.encode()).hexdigest() for x in raw],'compiled_sha256':hashlib.sha256(source.encode()).hexdigest(),'probe_sha256':hashlib.sha256(probe.encode()).hexdigest(),'callback_instrumentation':bool(a.baseline),'production_defines_sha256':hashlib.sha256(defines.encode()).hexdigest()}
    (out/'metadata.json').write_text(json.dumps(metadata,indent=2))
    build = subprocess.run([str(compiler),'-max_errors','0','probe.dme'],cwd=out,text=True,capture_output=True,timeout=60,creationflags=flags)
    compile_log = build.stdout+build.stderr
    (out/'compile.log').write_text(compile_log)
    print(compile_log,flush=True)
    if build.returncode or '516.1681' not in compile_log or '0 errors, 0 warnings' not in compile_log: raise SystemExit('Pinned native compilation failed')
    run = subprocess.run([str(daemon),'probe.dmb','-invisible','-close','-safe','-log','runtime.log'],cwd=out,capture_output=True,timeout=20,creationflags=flags)
    (out/'daemon.log').write_bytes(run.stdout+run.stderr)
    log = (out/'runtime.log').read_text(errors='replace')
    print(log,flush=True)
    combined = log + (run.stdout+run.stderr).decode(errors='replace')
    if run.returncode or re.search(r'runtime error|RUNTIME|Bad ref|Bad loc|BUG:|## ERROR:|WARNING |Cannot read null|Cannot execute null',combined,re.I): raise SystemExit('Native diagnostics invalidate lifecycle evidence')
    result = json.loads((out/'native-result.json').read_text())
    errors = re.findall(r'^FAIL (.+)$',log,re.M)
    control = 'baseline' if a.baseline else a.negative_control
    if result['checks'] != 23 or errors != (expected[control] if control else []) or result['failures'] != len(errors): raise SystemExit('Unexpected native lifecycle assertions')
    print('PASS expected historical/mutation control' if control else 'PASS production loop lifecycle')
    if a.evidence_dir: print('Retained evidence: '+str(out))
