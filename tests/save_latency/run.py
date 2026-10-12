"""Native isolated saver heartbeat and dense graph round-trip probe."""
import argparse, hashlib, json, os, re, shutil, subprocess, tempfile, time
from pathlib import Path

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--large', action='store_true')
    parser.add_argument('--dense', action='store_true')
    parser.add_argument('--interrupt', action='store_true')
    parser.add_argument('--benchmark-only', action='store_true')
    parser.add_argument('--scenario', choices=('movement','concurrent'))
    parser.add_argument('--negative-control', choices=('ownership','yield'))
    parser.add_argument('--baseline', help='Immutable Git commit for the saver and bookkeeping sources')
    args = parser.parse_args()
    if args.negative_control == 'yield': args.dense = True
    root = Path(__file__).resolve().parents[2]
    output = Path(tempfile.mkdtemp(prefix='civ13-save-latency-'))
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    print(f'Evidence: {output}', flush=True)
    files = ['code/predefines.dm', 'tests/world_save/stubs.dm', 'code/modules/persistence/functions.dm',
             'code/modules/persistence/saving.dm', 'code/modules/persistence/loading.dm', 'tests/save_latency/probe.dm']
    hashes = {}
    for relative in files:
        if args.baseline and relative.endswith(('functions.dm', 'saving.dm', 'loading.dm')):
            data = subprocess.check_output(['git', 'show', f'{args.baseline}:{relative}'], cwd=root)
        else:
            data = (root / relative).read_bytes()
        if relative.endswith('stubs.dm'):
            data += b'\n/proc/latency_copy(source, destination)\n\tvar/start = world.timeofday\n\t. = fcopy(source, destination)\n\tworld.log << "IO_METRICS copy=[source] ticks=[(world.timeofday-start+864000)%864000]"\n/proc/latency_flush(savefile/F)\n\tvar/start = world.timeofday\n\tF.Flush()\n\tworld.log << "IO_METRICS flush ticks=[(world.timeofday-start+864000)%864000]"\n'
        if relative.endswith('saving.dm'):
            data = data.replace(b'savefile.Flush()', b'latency_flush(savefile)')
        if args.negative_control and relative.endswith('saving.dm'):
            source = data.decode()
            if args.negative_control == 'ownership':
                source = source.replace('saving_owners[ref] = BuildVarDirectory(F, owner, 1, TRUE)', 'saving_owners[ref] = 0')
            else:
                source = source.replace('sleep(world.tick_lag)', '/* negative control: no yield */')
            data = source.encode()
        destination = output / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        hashes[relative] = hashlib.sha256(data).hexdigest()
    source = '#define TRUE 1\n#define FALSE 0\n#define TICK_CHECK fixture_tick_check()\n#define TICK_LIMIT_TO_RUN 100\n#define EXCEPTION(message) new /exception(message)\n'
    source += '#include "code/predefines.dm"\n#include "tests/world_save/stubs.dm"\n#define fdel(path) delete_file_adapter(path)\n#define fcopy(source, destination) latency_copy(source, destination)\n'
    source += ''.join(f'#include "{path}"\n' for path in files[2:])
    (output / 'probe.dme').write_text(source)
    (output / 'metadata.json').write_text(json.dumps({'baseline':args.baseline, 'large':args.large, 'dense':args.dense, 'scenario':args.scenario, 'interrupt':args.interrupt, 'benchmark_only':args.benchmark_only, 'negative_control':args.negative_control,
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
    parameters = ([] if not args.large else ['large=1']) + ([] if not args.scenario else ['scenario='+args.scenario])
    if args.benchmark_only: parameters += ['benchmark=1']
    if args.dense: parameters += ['dense=1']
    if args.interrupt: parameters += ['interrupt=1']
    if not args.baseline: parameters += ['bounded=1']
    if parameters: command += ['-params','&'.join(parameters)]
    if args.interrupt:
        with (output/'daemon.log').open('w') as daemon_log:
            process = subprocess.Popen(command,cwd=output,stdout=daemon_log,stderr=subprocess.STDOUT,creationflags=flags)
            try:
                deadline=time.monotonic()+180
                while not (output/'interruption_ready.txt').exists():
                    if process.poll() is not None or time.monotonic()>deadline:
                        raise RuntimeError('Interrupted-write synchronization failed')
                    time.sleep(0.02)
                process.kill()
                process.wait(timeout=10)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=10)
        base_command=command[:command.index('-params')]
        shutil.copy2(output/'runtime.log', output/'interrupted-writer.log')
        for phase in ('active','backup'):
            (output/'result.txt').unlink(missing_ok=True)
            (output/'runtime.log').unlink(missing_ok=True)
            if phase=='backup':
                active = (output/'map_saves').resolve()
                interrupted = (output/'interrupted-map_saves').resolve()
                if active.parent != output.resolve() or interrupted.parent != output.resolve():
                    raise RuntimeError('Recovery paths escape task temporary storage')
                active.rename(interrupted)
                shutil.copytree(output/'map_backups',active)
            recovery=subprocess.run(base_command+['-params','recovery='+phase],cwd=output,
                capture_output=True,text=True,timeout=120,creationflags=flags)
            log=(output/'runtime.log').read_text(errors='replace')
            (output/f'recovery-{phase}.log').write_text(log)
            if recovery.returncode or (output/'result.txt').read_text().strip()!='PASS' or re.search(r'runtime error:|bad ref|BUG:|RUNTIME:|infinite loop|fatal error',log,re.I):
                raise RuntimeError('Interrupted save recovery failed: '+phase)
        print('PASS: native interruption rejects incomplete active generation and restores completed backup',flush=True)
        return
    result=subprocess.run(command,cwd=output,capture_output=True,text=True,timeout=1800,creationflags=flags)
    (output / 'daemon.log').write_text(result.stdout+result.stderr)
    log=(output/'runtime.log').read_text(errors='replace')
    print(log,flush=True)
    expected = ('FAIL: dense graph prevented heartbeat progress' if args.negative_control == 'yield' else
                'FAIL: dense contents lost' if args.negative_control == 'ownership' else 'PASS')
    if result.returncode or not (output/'result.txt').read_text().strip().startswith(expected) or re.search(r'runtime error:|bad ref|BUG:|RUNTIME:|infinite loop|fatal error',log,re.I):
        raise RuntimeError('Native save probe failed')

if __name__=='__main__': main()
