"""Native production NanoUI constructor/close ownership with injected effects."""
import argparse, hashlib, json, os, re, subprocess, tempfile
from pathlib import Path
BASELINE = 'f556e39b93fc97f41020b2d8c5f2abed63fab497'
SOURCE = 'code/modules/nano/_nanoui.dm'
EXPECTED = {'independent close releases master ownership'}
p = argparse.ArgumentParser()
p.add_argument('--byond-bin', type=Path, required=True)
p.add_argument('--baseline', action='store_true')
p.add_argument('--evidence-dir', type=Path)
a = p.parse_args()
repo = Path(__file__).resolve().parents[2]
raw = subprocess.check_output(['git', 'show', BASELINE + ':' + SOURCE], cwd=repo, text=True) if a.baseline else (repo / SOURCE).read_text()
source = raw.split(' /**', 1)[0]
for anchor in ('/datum/nanoui/New(', '/datum/nanoui/proc/close()', '/datum/nanoui/proc/reinitialise(', '/datum/nanoui/proc/set_initial_data('):
    pattern = r'(?ms)^' + re.escape(anchor) + r'.*?(?=^ /\*\*)'
    match = re.search(pattern, raw)
    if not match: raise RuntimeError('Production extraction anchor missing: ' + anchor)
    source += '\n' + match.group()
browse = '\tuser << browse(null, "window=[window_id]")'
if source.count(browse) != 1: raise RuntimeError('Browser adapter anchor changed')
source = source.replace(browse, '\tfixture_browse_close(src)')
probe = Path(__file__).with_name('probe.dm').read_text()
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
dirty = subprocess.check_output(['git', 'status', '--porcelain'], cwd=repo, text=True)
flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
with tempfile.TemporaryDirectory(prefix='civ13-nanoui-ownership-') as directory:
    temp = Path(directory)
    (temp/'production.dm').write_text(source)
    (temp/'probe.dm').write_text(probe)
    (temp/'probe.dme').write_text('#include "probe.dm"\n#include "production.dm"\n')
    win = os.name == 'nt'
    compiler = a.byond_bin / ('dm.exe' if win else 'DreamMaker')
    daemon = a.byond_bin / ('dd.exe' if win else 'DreamDaemon')
    build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=temp, capture_output=True, text=True, timeout=60, creationflags=flags)
    print(build.stdout + build.stderr)
    if build.returncode or 'DM compiler version 516.1681' not in build.stdout or '0 errors, 0 warnings' not in build.stdout:
        raise SystemExit('Pinned compilation failed')
    command = [str(daemon), 'probe.dmb'] + (['-invisible', '-close'] if win else []) + ['-safe', '-log', 'runtime.log']
    run = subprocess.run(command, cwd=temp, capture_output=True, text=True, timeout=30, creationflags=flags)
    log = (temp/'runtime.log').read_text()
    print(log)
    failures = set(re.findall(r'^FAIL (.+)$', log, re.M))
    engine_error = bool(re.search(r'runtime error|bad ref|bad loc|assertion failed', log, re.I))
    success = run.returncode == 0 and not engine_error
    marker = 'PASS nanoui ownership'
    success = success and (failures == EXPECTED and marker not in log if a.baseline else not failures and marker in log)
    if a.evidence_dir:
        dest = a.evidence_dir / ('nanoui-ownership-baseline' if a.baseline else 'nanoui-ownership-fixed')
        dest.mkdir(parents=True, exist_ok=True)
        for name, text in [('compile.log', build.stdout+build.stderr), ('runtime.log', log), ('source.dm',raw), ('production.dm',source), ('probe.dm',probe)]:
            (dest/name).write_text(text)
        (dest/'result.json').write_text(json.dumps({'baseline':a.baseline, 'source_commit':BASELINE if a.baseline else head, 'working_tree_dirty':bool(dirty) if not a.baseline else False, 'checkout_status':dirty, 'source_sha256':hashlib.sha256(raw.encode()).hexdigest(), 'adapted_source_sha256':hashlib.sha256(source.encode()).hexdigest(), 'fixture_sha256':hashlib.sha256(probe.encode()).hexdigest(), 'byond':'516.1681', 'observed_failures':sorted(failures), 'expected_baseline_failures':sorted(EXPECTED) if a.baseline else [], 'runtime_error':engine_error, 'passed':bool(success)}, indent=2))
    if not success: raise SystemExit('NanoUI ownership regression or baseline control failed')
    if a.baseline: print('PASS baseline control: exact expected ownership failure detected')
