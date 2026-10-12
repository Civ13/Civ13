"""Native isolated saver heartbeat and dense graph round-trip probe."""
import argparse, hashlib, json, os, re, shutil, subprocess, tempfile
from pathlib import Path

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--large', action='store_true')
    parser.add_argument('--baseline', help='Immutable Git commit for the saver and bookkeeping sources')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = Path(tempfile.mkdtemp(prefix='civ13-save-latency-'))
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    print(f'Evidence: {output}', flush=True)
    files = ['code/predefines.dm', 'tests/world_save/stubs.dm', 'code/modules/persistence/functions.dm',
             'code/modules/persistence/saving.dm', 'code/modules/persistence/loading.dm', 'tests/save_latency/probe.dm']
    hashes = {}
    for relative in files:
        if args.baseline and relative.endswith(('functions.dm', 'saving.dm')):
            data = subprocess.check_output(['git', 'show', f'{args.baseline}:{relative}'], cwd=root)
        else:
            data = (root / relative).read_bytes()
        destination = output / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        hashes[relative] = hashlib.sha256(data).hexdigest()
    source = '#define TRUE 1\n#define FALSE 0\n#define TICK_CHECK fixture_tick_check()\n#define TICK_LIMIT_TO_RUN 100\n#define EXCEPTION(message) new /exception(message)\n'
    source += '#include "code/predefines.dm"\n#include "tests/world_save/stubs.dm"\n#define fdel(path) delete_file_adapter(path)\n'
    source += ''.join(f'#include "{path}"\n' for path in files[2:])
    (output / 'probe.dme').write_text(source)
    (output / 'metadata.json').write_text(json.dumps({'baseline':args.baseline, 'large':args.large,
        'head': subprocess.check_output(['git','rev-parse','HEAD'], cwd=root, text=True).strip(), 'sources':hashes}, indent=2))
    (output / 'checkout.patch').write_text(subprocess.check_output(['git','diff','HEAD'],cwd=root,text=True))
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    build = subprocess.run([str(compiler), '-max_errors','0','probe.dme'], cwd=output, capture_output=True,text=True,timeout=120,creationflags=flags)
    log = build.stdout+build.stderr
    (output / 'compile.log').write_text(log)
    print(log,flush=True)
    if build.returncode or '516.1681' not in log or '0 errors, 0 warnings' not in log:
        raise RuntimeError('Pinned compilation failed')
    command=[str(daemon),'probe.dmb']+(['-invisible','-close'] if os.name=='nt' else [])+['-safe','-log','runtime.log']
    if args.large: command += ['-params','large=1']
    result=subprocess.run(command,cwd=output,capture_output=True,text=True,timeout=1800,creationflags=flags)
    (output / 'daemon.log').write_text(result.stdout+result.stderr)
    log=(output/'runtime.log').read_text(errors='replace')
    print(log,flush=True)
    if result.returncode or (output/'result.txt').read_text().strip()!='PASS' or re.search(r'runtime error:|bad ref|BUG:|RUNTIME:|infinite loop|fatal error',log,re.I):
        raise RuntimeError('Native save probe failed')

if __name__=='__main__': main()
