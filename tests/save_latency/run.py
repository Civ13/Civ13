"""Native isolated saver heartbeat and dense graph round-trip probe."""
import argparse, hashlib, json, os, re, shutil, subprocess, tempfile, time
from pathlib import Path

OLD_READER_COMMIT = '75890d883190355e430f9958fd102864ee88429a'


def old_reader_helpers(loading, existing):
    """Current compile dependencies for a historical refusal control, not an old build."""
    start = ('// Only roof transformations backed by direct saved turf contents are projected.\n'
             '// No save bytes or world areas change during this preflight.\n/map_storage\n')
    end = '\n/map_storage/proc/Load_Entry('
    if not loading.startswith(start) or loading.count(start) != 1 or loading.count(end) != 1:
        raise RuntimeError('Old-reader roof compatibility anchors changed')
    roof = loading[:loading.index(end)]
    procedures = ('clear_saved_roof_areas', 'saved_roof_area_type', 'find_saved_roof_area',
                  'unique_saved_roof_area', 'prepare_saved_roof_areas',
                  'materialize_saved_roof_areas', 'restore_validated_roof',
                  'is_loaded_validated_roof', 'verify_restored_roof_areas')
    members = ('validated_roof_areas', 'validated_roof_entries', 'validated_roof_types',
               'validated_roof_instances', 'validated_roof_absent', 'restoring_roof_areas')
    if re.findall(r'^/map_storage/proc/(\w+)\(', roof, re.M) != list(procedures):
        raise RuntimeError('Old-reader roof compatibility procedures changed')
    declarations = roof.split('\n/map_storage/proc/', 1)[0]
    if re.findall(r'^\tvar/(?:list/)?(\w+) = ', declarations, re.M) != list(members):
        raise RuntimeError('Old-reader roof compatibility members changed')
    patterns = [r'^/map_storage/proc/' + name + r'\(' for name in procedures]
    patterns += [r'^\tvar/(?:list/)?' + name + r'\b' for name in members]
    marker = '/map_storage/proc/saved_content_refs(value, version)\n'
    if loading.count(marker) != 1 or marker in existing:
        raise RuntimeError('Old-reader content compatibility anchor changed or duplicated')
    if any(re.search(pattern, existing, re.M) for pattern in patterns):
        raise RuntimeError('Old-reader roof compatibility dependencies duplicated')
    begin = loading.index(marker)
    finish = loading.find('\n/map_storage/proc/', begin + len(marker))
    return roof, loading[begin:finish if finish >= 0 else len(loading)]


def require_old_reader_preflight(result, log):
    refusal = r'World-save preflight rejected: Unsupported save version 3 on code[/\\]modules[/\\]persistence[/\\]loading\.dm:\d+\b'
    if result != 'FAIL: save preflight failed' or not re.search(refusal, log):
        raise RuntimeError('Old reader did not reject format 3 during historical preflight')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--large', action='store_true')
    parser.add_argument('--dimension', type=int, help='Bounded scaled large fixture side length')
    parser.add_argument('--timeout-seconds', type=int, help='Native runtime limit for a bounded offline lease')
    parser.add_argument('--dense', action='store_true')
    parser.add_argument('--prepare-only', action='store_true', help='Generate source without compiling or starting BYOND')
    parser.add_argument('--interrupt', action='store_true')
    parser.add_argument('--benchmark-only', action='store_true')
    parser.add_argument('--verify-backup', action='store_true', help='Restore the completed backup after the active roundtrip')
    parser.add_argument('--scenario', choices=('movement','concurrent','parent-deletion'))
    parser.add_argument('--negative-control', choices=('yield', 'old-reader'))
    args = parser.parse_args()
    if args.timeout_seconds is not None and not 1 <= args.timeout_seconds <= 3600:
        parser.error('--timeout-seconds must be between 1 and 3600')
    if args.verify_backup and (args.benchmark_only or args.interrupt or args.scenario or args.negative_control):
        parser.error('--verify-backup requires a normal complete roundtrip')
    if args.dimension is not None and (not args.large or not 2 <= args.dimension <= 500):
        parser.error('--dimension requires --large and a value from 2 to 500')
    if args.negative_control == 'yield': args.dense = True
    root = Path(__file__).resolve().parents[2]
    output = Path(tempfile.mkdtemp(prefix='civ13-save-latency-'))
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    print(f'Evidence: {output}', flush=True)
    files = ['code/predefines.dm', 'tests/world_save/stubs.dm', 'code/modules/multiz/world_z_budget.dm', 'code/modules/persistence/functions.dm',
             'code/modules/persistence/player_reclaim.dm', 'code/modules/persistence/saving.dm', 'code/modules/persistence/loading.dm', 'tests/save_latency/probe.dm']
    old_reader = None
    compatibility = {}
    if args.negative_control == 'old-reader':
        old_reader = subprocess.check_output(['git', 'show', OLD_READER_COMMIT + ':code/modules/persistence/loading.dm'], cwd=root)
        compatibility = {'commit': OLD_READER_COMMIT, 'loader_sha256': hashlib.sha256(old_reader).hexdigest()}
    hashes = {}
    for relative in files:
        data = (root / relative).read_bytes()
        if old_reader is not None and relative.endswith('loading.dm'):
            data = old_reader
        if old_reader is not None and relative.endswith('functions.dm'):
            # Keep the immutable loader/refusal intact; add only current roof
            # compile dependencies to this mixed fixture's functions copy.
            loading = (root / 'code/modules/persistence/loading.dm').read_text(encoding='utf-8')
            roof, codec = old_reader_helpers(loading, data.decode('utf-8') + '\n' + old_reader.decode('utf-8'))
            data += ('\n' + roof + '\n' + codec).encode('utf-8')
            compatibility.update(roof_helpers_sha256=hashlib.sha256(roof.encode()).hexdigest(),
                                 content_helper_sha256=hashlib.sha256(codec.encode()).hexdigest())
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
        'head': subprocess.check_output(['git','rev-parse','HEAD'], cwd=root, text=True).strip(), 'sources':hashes,
        'old_reader_compatibility':compatibility}, indent=2))
    (output / 'checkout.patch').write_text(subprocess.check_output(['git','diff','HEAD'],cwd=root,text=True))
    if args.prepare_only: return
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    build = subprocess.run([str(compiler), '-max_errors','0','probe.dme'], cwd=output, capture_output=True,text=True,timeout=120,creationflags=flags)
    log = build.stdout+build.stderr
    (output / 'compile.log').write_text(log)
    print(log,flush=True)
    if build.returncode or '516.1681' not in log or '0 errors, 0 warnings' not in log:
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
    runtime_limit=args.timeout_seconds or (3600 if args.large else 1800)
    runtime_started=time.monotonic()
    result=subprocess.run(command,cwd=output,capture_output=True,text=True,timeout=runtime_limit,creationflags=flags)
    (output / 'daemon.log').write_text(result.stdout+result.stderr)
    log=(output/'runtime.log').read_text(errors='replace')
    print(log,flush=True)
    expected = ('FAIL: dense graph prevented heartbeat progress' if args.negative_control == 'yield' else
                'FAIL: save preflight failed' if args.negative_control == 'old-reader' else 'PASS')
    if result.returncode or not (output/'result.txt').read_text().strip().startswith(expected) or re.search(r'runtime error:|bad ref|BUG:|RUNTIME:|infinite loop|fatal error',log,re.I):
        raise RuntimeError('Native save probe failed')
    if args.negative_control == 'old-reader':
        require_old_reader_preflight((output/'result.txt').read_text().strip(), log)
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
