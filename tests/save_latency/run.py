"""Native isolated saver heartbeat and dense graph round-trip probe."""
import argparse, hashlib, json, os, re, shutil, subprocess, tempfile, time
import importlib.util
from pathlib import Path
# Compile checks follow the canonical compiler pin.
PINNED_BYOND = __import__('json').loads((__import__('pathlib').Path(__file__).resolve().parents[2] / 'tools/byond/version.json').read_text(encoding='utf-8'))['version']

def selected_runtime(bin_dir, archive):
    if archive is None: return None
    spec = importlib.util.spec_from_file_location('latency_current_runtime', Path(__file__).parents[1]/'world_save/current_runtime.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module.select(bin_dir, archive)


def current_ci_case(args):
    options = {key: value for key, value in vars(args).items() if value and
               key not in ('byond_bin', 'byond_archive')}
    cases = [{'verify_backup': True}, {'verify_backup': True, 'dense': True}, {'interrupt': True},
             {'negative_control': 'yield', 'dense': True}]
    cases += [{'scenario': name} for name in ('movement', 'concurrent', 'parent-deletion')]
    return options in cases


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--byond-archive', type=Path)
    parser.add_argument('--large', action='store_true')
    parser.add_argument('--dimension', type=int, help='Bounded scaled large fixture side length')
    parser.add_argument('--timeout-seconds', type=int, help='Native runtime limit for a bounded offline lease')
    parser.add_argument('--dense', action='store_true')
    parser.add_argument('--prepare-only', action='store_true', help='Generate source without compiling or starting BYOND')
    parser.add_argument('--interrupt', action='store_true')
    parser.add_argument('--benchmark-only', action='store_true')
    parser.add_argument('--verify-backup', action='store_true', help='Restore the completed backup after the active roundtrip')
    parser.add_argument('--scenario', choices=('movement','concurrent','parent-deletion'))
    parser.add_argument('--negative-control', choices=('yield',))
    args = parser.parse_args()
    if args.timeout_seconds is not None and not 1 <= args.timeout_seconds <= 3600:
        parser.error('--timeout-seconds must be between 1 and 3600')
    if args.verify_backup and (args.benchmark_only or args.interrupt or args.scenario or args.negative_control):
        parser.error('--verify-backup requires a normal complete roundtrip')
    if args.dimension is not None and (not args.large or not 2 <= args.dimension <= 500):
        parser.error('--dimension requires --large and a value from 2 to 500')
    if args.negative_control == 'yield': args.dense = True
    if args.byond_archive and not current_ci_case(args):
        parser.error('Current runtime admits only the selected bounded save CI cases')
    runtime = selected_runtime(args.byond_bin, args.byond_archive)
    root = Path(__file__).resolve().parents[2]
    output = Path(tempfile.mkdtemp(prefix='civ13-save-latency-'))
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    print(f'Evidence: {output}', flush=True)
    files = ['code/predefines.dm', 'tests/world_save/stubs.dm', 'code/modules/multiz/world_z_budget.dm', 'code/modules/persistence/functions.dm', 'code/modules/persistence/debug_lossy.dm',
             'code/modules/persistence/player_reclaim.dm', 'code/modules/persistence/saving.dm', 'code/modules/persistence/loading.dm', 'tests/save_latency/probe.dm']
    hashes = {}
    for relative in files:
        data = (root / relative).read_bytes()
        if relative.endswith('stubs.dm'):
            data += b'\n/proc/latency_copy(source, destination)\n\tvar/start = world.timeofday\n\t. = fcopy(source, destination)\n\tworld.log << "IO_METRICS copy=[source] ticks=[(world.timeofday-start+864000)%864000]"\n/proc/latency_flush(savefile/F)\n\tvar/start = world.timeofday\n\tF.Flush()\n\tworld.log << "IO_METRICS flush ticks=[(world.timeofday-start+864000)%864000]"\n'
        if relative.endswith('saving.dm'):
            data = data.replace(b'savefile.Flush()', b'latency_flush(savefile)')
        if args.negative_control == 'yield' and relative.endswith('saving.dm'):
            source = data.decode()
            source, count = re.subn(r'(?m)^([ \t]*)(?:latency_)?sleep\((?:world.tick_lag|0)\)$',
                r'\1saving_work = 0 // negative control: no yield', source)
            if count < 2: raise RuntimeError('Yield mutation anchors missing')
            data = source.encode()
        destination = output / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        hashes[relative] = hashlib.sha256(data).hexdigest()
    source = '#define TRUE 1\n#define FALSE 0\n#define TICK_CHECK fixture_tick_check()\n#define TICK_LIMIT_TO_RUN 100\n#define EXCEPTION(message) new /exception(message)\n'
    source += '#include "code/predefines.dm"\n#include "tests/world_save/stubs.dm"\n#define fdel(path) delete_file_adapter(path)\n#define fcopy(source, destination) latency_copy(source, destination)\n'
    source += ''.join(f'#include "{path}"\n' for path in files[2:])
    (output / 'probe.dme').write_text(source)
    (output / 'metadata.json').write_text(json.dumps({ 'large':args.large, 'dense':args.dense, 'scenario':args.scenario, 'interrupt':args.interrupt, 'benchmark_only':args.benchmark_only, 'negative_control':args.negative_control,  'timeout_seconds':args.timeout_seconds, 'verify_backup':args.verify_backup, 'dimension':args.dimension,
        'head': subprocess.check_output(['git','rev-parse','HEAD'], cwd=root, text=True).strip(), 'sources':hashes}, indent=2))
    (output / 'checkout.patch').write_text(subprocess.check_output(['git','diff','HEAD'],cwd=root,text=True))
    if args.prepare_only: return
    byond = args.byond_bin.absolute() if runtime else args.byond_bin
    compiler = byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    if runtime: runtime.before_launch('compile', output)
    build = subprocess.run([str(compiler), '-max_errors','0','probe.dme'], cwd=output, capture_output=True,text=True,timeout=120,creationflags=flags)
    log = build.stdout+build.stderr
    (output / 'compile.log').write_text(log)
    print(log,flush=True)
    if runtime: runtime.validate_compile(build.returncode, log, 'probe.dmb')
    elif build.returncode or PINNED_BYOND not in log or '0 errors, 0 warnings' not in log:
        raise RuntimeError('Pinned compilation failed')
    command=[str(daemon),'probe.dmb']+(['-invisible','-close'] if os.name=='nt' else [])+['-trusted','-log','runtime.log']
    parameters = ([] if not args.large else ['large=1']) + ([] if not args.scenario else ['scenario='+args.scenario])
    if args.benchmark_only: parameters += ['benchmark=1']
    if args.dense: parameters += ['dense=1']
    if args.verify_backup: parameters += ['verify_backup=1']
    if args.dimension is not None: parameters += ['dimension='+str(args.dimension)]
    if args.interrupt: parameters += ['interrupt=1']
    parameters += ['bounded=1']
    if parameters: command += ['-params','&'.join(parameters)]
    if args.interrupt:
        if runtime: runtime.before_launch('daemon:interrupted-writer', output)
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
            if runtime: runtime.before_launch('daemon:recovery-'+phase, output)
            recovery=subprocess.run(base_command+['-params','recovery='+phase],cwd=output,
                capture_output=True,text=True,timeout=120,creationflags=flags)
            log=(output/'runtime.log').read_text(errors='replace')
            (output/f'recovery-{phase}.log').write_text(log)
            if recovery.returncode or (output/'result.txt').read_text().strip()!='PASS' or re.search(r'runtime error:|bad ref|BUG:|RUNTIME:|infinite loop|fatal error',log,re.I):
                raise RuntimeError('Interrupted save recovery failed: '+phase)
        print('PASS: native interruption rejects incomplete active generation and restores completed backup',flush=True)
        return
    runtime_limit=args.timeout_seconds or (3600 if args.large else 1800)
    runtime_started=time.monotonic()
    run_timeout=runtime_limit
    if runtime:
        runtime.before_launch('daemon', output)
        run_timeout=runtime_limit-(time.monotonic()-runtime_started)
        if run_timeout <= 0: raise RuntimeError('Save runtime budget exhausted before launch')
    result=subprocess.run(command,cwd=output,capture_output=True,text=True,timeout=run_timeout,creationflags=flags)
    (output / 'daemon.log').write_text(result.stdout+result.stderr)
    log=(output/'runtime.log').read_text(errors='replace')
    print(log,flush=True)
    expected = 'FAIL: dense graph prevented heartbeat progress' if args.negative_control == 'yield' else 'PASS'
    if result.returncode or not (output/'result.txt').read_text().strip().startswith(expected) or re.search(r'runtime error:|bad ref|BUG:|RUNTIME:|infinite loop|fatal error',log,re.I):
        raise RuntimeError('Native save probe failed')
    if args.verify_backup:
        shutil.copy2(output/'runtime.log', output/'active-roundtrip.log')
        (output/'result.txt').unlink()
        (output/'runtime.log').unlink()
        active=(output/'map_saves').resolve()
        completed=(output/'completed-map_saves').resolve()
        backup=(output/'map_backups').resolve()
        if any(path.parent != output.resolve() for path in (active,completed,backup)):
            raise RuntimeError('Backup verification paths escape temporary storage')
        active.rename(completed)
        shutil.copytree(backup,active)
        if runtime: runtime.before_launch('daemon:backup', output)
        remaining=runtime_limit-(time.monotonic()-runtime_started)
        if remaining <= 0:
            raise RuntimeError('Backup verification runtime budget exhausted')
        recovery_parameters=['recovery=backup']
        if args.large: recovery_parameters.append('large=1')
        if args.dimension is not None: recovery_parameters.append('dimension='+str(args.dimension))
        if args.dense: recovery_parameters.append('dense=1')
        recovery_command=command[:command.index('-params')] if '-params' in command else command
        recovery=subprocess.run(recovery_command+['-params','&'.join(recovery_parameters)],cwd=output,
            capture_output=True,text=True,timeout=remaining,creationflags=flags)
        (output/'backup-daemon.log').write_text(recovery.stdout+recovery.stderr)
        recovery_log=(output/'runtime.log').read_text(errors='replace')
        (output/'backup-roundtrip.log').write_text(recovery_log)
        print(recovery_log,flush=True)
        if recovery.returncode or (output/'result.txt').read_text().strip() != 'PASS' or re.search(r'runtime error:|bad ref|BUG:|RUNTIME:|infinite loop|fatal error',recovery_log,re.I):
            raise RuntimeError('Completed backup roundtrip failed')
        print('PASS: active and completed backup generations restored',flush=True)


if __name__=='__main__': main()
