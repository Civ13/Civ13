"""Bounded native fixture, no production world or network effects."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--byond-bin', type=Path, required=True)
    p.add_argument('--case', choices=('callback', 'turf', 'lifecycle', 'pool'))
    p.add_argument('--output', type=Path)
    a = p.parse_args()
    root = Path(__file__).resolve().parents[2]
    out = a.output or Path(tempfile.mkdtemp(prefix='civ13-memory-ownership-'))
    if out.exists() and any(out.iterdir()):
        raise RuntimeError('Use fresh evidence storage')
    out.mkdir(parents=True, exist_ok=True)
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    (out/'metadata.json').write_text(json.dumps({'head_sha': head, 'case': a.case, 'byond': '516.1681', 'scope': 'isolated production GC/pool/callproc'}))
    (out/'dirty.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=root))
    source = (root/'tests/memory_ownership/probe.dm').read_text().replace('../../code/', root.as_posix()+'/code/')
    probe = out/'probe.dme'
    probe.write_text(source)
    win = os.name == 'nt'
    flags = subprocess.CREATE_NO_WINDOW if win else 0
    build = subprocess.run([str(a.byond_bin/('dm.exe' if win else 'DreamMaker')), '-max_errors', '0', str(probe)], cwd=out, capture_output=True, text=True, timeout=60, creationflags=flags)
    text = build.stdout + build.stderr
    (out/'compile.log').write_text(text)
    print(text, flush=True)
    if build.returncode or '516.1681' not in text or '0 errors, 0 warnings' not in text:
        raise RuntimeError('Pinned clean compile failed')
    command = [str(a.byond_bin/('dd.exe' if win else 'DreamDaemon')), str(out/'probe.dmb')]
    if win:
        command += ['-invisible', '-close']
    command += ['-safe', '-log', 'runtime.log']
    if a.case:
        command += ['-params', 'case='+a.case]
    with (out/'daemon.log').open('w') as log:
        run = subprocess.run(command, cwd=out, stdout=log, stderr=subprocess.STDOUT, timeout=60, creationflags=flags)
    result = (out/'result.txt').read_text()
    runtime = (out/'runtime.log').read_text(errors='replace')
    print(result.strip())
    print('Evidence:', out)
    if run.returncode or not result.startswith('PASS:') or 'runtime error:' in runtime:
        raise RuntimeError('Native assertions failed')


if __name__ == '__main__':
    main()
