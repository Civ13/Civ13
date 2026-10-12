"""Run isolated native queue representation benchmarks with no game startup."""
import argparse, json, os, subprocess, tempfile
from pathlib import Path
p = argparse.ArgumentParser()
p.add_argument('--byond-bin', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
with tempfile.TemporaryDirectory(prefix='civ13-gc-queue-') as directory:
    temp = Path(directory)
    (temp / 'probe.dm').write_text(Path(__file__).with_name('probe.dm').read_text(), encoding='utf-8')
    (temp / 'probe.dme').write_text('#include "probe.dm"\n')
    compiler = a.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = a.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=temp, capture_output=True, text=True, timeout=60, creationflags=flags)
    print(build.stdout + build.stderr)
    assert build.returncode == 0 and '516.1681' in build.stdout and '0 errors, 0 warnings' in build.stdout
    run = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-close', '-safe', '-log', 'runtime.log'], cwd=temp, capture_output=True, text=True, timeout=240, creationflags=flags)
    logs = run.stdout + run.stderr + (temp / 'runtime.log').read_text(errors='replace')
    assert run.returncode == 0 and 'FAIL:' not in logs and 'runtime error' not in logs.lower(), logs
    result = json.loads((temp / 'result.json').read_text())
    for row in result['results']:
        index = row['sequence']
        row['elapsed_ms'] = ((temp / f'end-{index}.txt').stat().st_mtime_ns - (temp / f'start-{index}.txt').stat().st_mtime_ns) / 1_000_000
    result['compiler'] = build.stdout.strip()
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=2))
    print(f'Passed; evidence: {a.output}')
