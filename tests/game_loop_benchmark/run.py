"""Finite Windows native full-game comparison; no client or production deployment."""
import argparse, ctypes, hashlib, json, os, pathlib, re, shutil, subprocess, time, uuid, statistics
from ctypes import wintypes
BASELINE = '7cfa850bd9d2788dcbb9fd35f5c5915ccb528dd2'
PATHS = ['code/processes/garbage.dm', 'code/processes/__processScheduler.dm', 'code/processes/_process.dm']
class Memory(ctypes.Structure):
    _fields_ = [('cb',wintypes.DWORD),('PageFaultCount',wintypes.DWORD)] + [(n,ctypes.c_size_t) for n in ['PeakWorkingSetSize','WorkingSetSize','QuotaPeakPagedPoolUsage','QuotaPagedPoolUsage','QuotaPeakNonPagedPoolUsage','QuotaNonPagedPoolUsage','PagefileUsage','PeakPagefileUsage','PrivateUsage']]
def git(repo,*args):
    return subprocess.check_output(['git','-C',str(repo),*args],text=True,encoding='utf-8')
def snapshot(handle):
    mem=Memory(); mem.cb=ctypes.sizeof(mem)
    if not ctypes.windll.psapi.GetProcessMemoryInfo(handle,ctypes.byref(mem),mem.cb): raise ctypes.WinError()
    creation=wintypes.FILETIME(); exit_time=wintypes.FILETIME(); kernel=wintypes.FILETIME(); user=wintypes.FILETIME()
    if not ctypes.windll.kernel32.GetProcessTimes(handle,ctypes.byref(creation),ctypes.byref(exit_time),ctypes.byref(kernel),ctypes.byref(user)): raise ctypes.WinError()
    cpu=sum((v.dwHighDateTime<<32)+v.dwLowDateTime for v in [kernel,user])/1e7
    return {'private_memory_bytes':mem.PrivateUsage,'working_set_bytes':mem.WorkingSetSize,'cpu_seconds':cpu}
def run(repo,byond,out,variant,head):
    out.mkdir(parents=True)
    prefix='.game_loop_'+uuid.uuid4().hex
    created=[]
    try:
        dme=(repo/'civ13.dme').read_text(encoding='utf-8-sig')
        replacements={}
        for index,path in enumerate(PATHS):
            content=git(repo,'show',BASELINE+':'+path) if variant=='baseline' else (repo/path).read_text(encoding='utf-8-sig')
            if variant == 'baseline' and path == 'code/processes/_process.dm':
                # Keep the unrelated current interval helper shared with current obj sources.
                current=(repo/path).read_text(encoding='utf-8-sig')
                helper=re.search(r'/process/proc/configured_interval_seconds\(\)\n\treturn [^\n]+',current)
                if not helper or '/process/proc/configured_interval_seconds()' in content: raise RuntimeError('Unexpected shared interval helper')
                content+='\n'+helper.group()+'\n'
            dest=repo/(prefix+str(index)+'.dm'); dest.write_text(content,encoding='utf-8'); created.append(dest)
            replacements[path]=dest.name
            (out/pathlib.Path(path).name).write_text(content,encoding='utf-8')
        defines=(repo/'code/processes/___defines.dm').read_text(encoding='utf-8-sig')
        old='#define PROCESS_TICK_CHECK if (priority != PROCESS_PRIORITY_VERY_HIGH && world.tick_usage - run_time_tick_usage >= run_time_tick_usage_allowance) return PROCESS_TICK_CHECK_RETURNED_EARLY'
        new='#define PROCESS_TICK_CHECK game_loop_tick_checks++; if (priority != PROCESS_PRIORITY_VERY_HIGH && world.tick_usage - run_time_tick_usage >= run_time_tick_usage_allowance) { game_loop_early_returns++; return PROCESS_TICK_CHECK_RETURNED_EARLY; }'
        if defines.count(old)!=1: raise RuntimeError('Unexpected tick-check macro')
        dest=repo/(prefix+'defines.dm'); dest.write_text(defines.replace(old,new),encoding='utf-8'); created.append(dest)
        replacements['code/processes/___defines.dm']=dest.name
        shutil.copy2(dest,out/'instrumented-defines.dm')
        for old_path,new_path in replacements.items():
            token='"'+old_path.replace('/','\\')+'"'
            if token not in dme: token='"'+old_path+'"'
            if dme.count(token)!=1: raise RuntimeError('Include absent: '+old_path)
            dme=dme.replace(token,'"'+new_path+'"')
        dme+='\n#include "tests/game_loop_benchmark/game_probe.dm"\n'
        source=repo/(prefix+'.dme'); source.write_text(dme,encoding='utf-8'); created.append(source)
        for suffix in ['.dmb','.rsc']: created.append(source.with_suffix(suffix))
        pending=[source]; hashes={}
        while pending:
            file=pending.pop(); key=str(file.relative_to(repo)).replace('\\','/')
            if key in hashes: continue
            data=file.read_bytes(); hashes[key]=hashlib.sha256(data).hexdigest()
            if file.suffix in ['.dm','.dme']:
                clean=re.sub(r'/\*.*?\*/','',data.decode('utf-8-sig'),flags=re.S)
                for inc in re.findall(r'^\s*#include\s+"([^"]+)"',clean,re.M): pending.append((file.parent/inc).resolve())
        (out/'source-hashes.json').write_text(json.dumps(hashes,indent=2))
        for f in ['game_probe.dm','run.py']: shutil.copy2(repo/'tests/game_loop_benchmark'/f,out/f)
        (out/'generated.dme').write_text(dme)
        build=subprocess.run([str(byond/'dm.exe'),'-max_errors','0',str(source)],capture_output=True,text=True,timeout=120)
        log=build.stdout+build.stderr; (out/'compile.log').write_text(log)
        if build.returncode or 'DM compiler version 516.1681' not in log or '0 errors, 0 warnings' not in log: raise RuntimeError(log[-3000:])
        for suffix in ['.dmb','.rsc']: shutil.copy2(source.with_suffix(suffix),out/source.with_suffix(suffix).name)
        for path in git(repo,'ls-files','--','config').splitlines():
            dest=out/path; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(repo/path,dest)
        rows=[]; started=time.perf_counter(); handle=None
        with (out/'stdout.log').open('w') as stdout,(out/'stderr.log').open('w') as stderr:
            proc=subprocess.Popen([str(byond/'dd.exe'),str(out/source.with_suffix('.dmb').name),'-invisible','-close','-trusted','-params','tested_commit='+head+'&variant='+variant,'-log','startup.log'],cwd=out,stdout=stdout,stderr=stderr,creationflags=subprocess.CREATE_NO_WINDOW)
            ctypes.windll.kernel32.OpenProcess.restype=wintypes.HANDLE
            handle=ctypes.windll.kernel32.OpenProcess(0x1000|0x10,False,proc.pid)
            ctypes.windll.psapi.GetProcessMemoryInfo.argtypes=[wintypes.HANDLE,ctypes.POINTER(Memory),wintypes.DWORD]
            ctypes.windll.kernel32.GetProcessTimes.argtypes=[wintypes.HANDLE]+[ctypes.POINTER(wintypes.FILETIME)]*4
            ctypes.windll.kernel32.CloseHandle.argtypes=[wintypes.HANDLE]
            try:
                while proc.poll() is None:
                    elapsed=time.perf_counter()-started
                    row=snapshot(handle); row['elapsed_seconds']=elapsed; row['phase']='restart' if (out/'restart.json').exists() else ('natural' if (out/'ready.json').exists() else 'startup'); rows.append(row)
                    if elapsed>90 or row['private_memory_bytes']>1024**3 or row['cpu_seconds']>60: raise RuntimeError('Finite resource limit')
                    time.sleep(.25)
            finally:
                if proc.poll() is None: proc.terminate(); proc.wait(timeout=10)
                ctypes.windll.kernel32.CloseHandle(handle)
                (out/'os-samples.json').write_text(json.dumps(rows))
        logs='\n'.join(p.read_text(errors='replace') for p in out.rglob('*.log') if p.name!='compile.log')
        if re.search(r'runtime error|\bBad ref\b|\bBad loc\b|Cannot read null|Cannot execute null|\bBUG:|##\s*ERROR:',logs,re.I): raise RuntimeError('Native diagnostics invalidate run')
        if not (out/'result.json').exists(): raise RuntimeError((out/'result.txt').read_text() if (out/'result.txt').exists() else 'Native result absent')
        result=json.loads((out/'result.json').read_text())
        if proc.returncode or not result['passed'] or result['tested_commit']!=head or result['variant']!=variant: raise RuntimeError('Result/exit provenance failure')
        summaries={}
        for phase in ['natural','restart']:
            samples=[r for r in rows if r['phase']==phase]
            native=[r for r in result['rows'] if r['phase']==phase]
            if len(samples)<2: raise RuntimeError('Missing OS phase samples')
            summaries[phase]={'sampled_cpu_seconds':samples[-1]['cpu_seconds']-samples[0]['cpu_seconds'],'sampled_elapsed_seconds':samples[-1]['elapsed_seconds']-samples[0]['elapsed_seconds'],'private_median_bytes':statistics.median(r['private_memory_bytes'] for r in samples),'private_peak_bytes':max(r['private_memory_bytes'] for r in samples),'awake_gap_median_deciseconds':statistics.median(r['awake_gap_deciseconds'] for r in native),'awake_gap_max_deciseconds':max(r['awake_gap_deciseconds'] for r in native),'native_samples':len(native),'os_samples':len(samples),'boundary_uncertainty':'Up to 0.25 seconds each plus file/write scheduling delay; CPU delta excludes first and last partial intervals'}
        (out/'phase-summary.json').write_text(json.dumps(summaries,indent=2))
        print(variant,out.name,'PASS',flush=True)
        return result
    finally:
        for file in created:
            if file.exists(): file.unlink()
def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--byond-bin',type=pathlib.Path,required=True); parser.add_argument('--output',type=pathlib.Path,required=True); parser.add_argument('--pairs',type=int,default=3); parser.add_argument('--variant',choices=['baseline','current']); args=parser.parse_args()
    if os.name!='nt' or not 1<=args.pairs<=3: raise RuntimeError('Windows only; 1-3 bounded pairs')
    repo=pathlib.Path(__file__).resolve().parents[2]; out=args.output.resolve()
    if out.exists() and any(out.iterdir()): raise RuntimeError('Evidence directory must be empty')
    out.mkdir(parents=True,exist_ok=True); head=git(repo,'rev-parse','HEAD').strip()
    (out/'metadata.json').write_text(json.dumps({'tested_commit':head,'baseline_commit':BASELINE,'baseline_replaced_paths':PATHS,'shared_baseline_helper':'Current configured_interval_seconds retained for shared current obj sources; copied into saved baseline _process.dm','working_tree_status':git(repo,'status','--porcelain'),'clock':'OS perf_counter seconds; native world.time/timeofday deciseconds; awake gaps are scheduling cadence, not tick execution duration','scope':'Normal Nomads server with 8 instrumented production humans with ssd_check=False adapter, 20 native steps/pickup/drop cycles, 20 scheduled callbacks, 400 effect constructions/qdel calls, 600 natural awake cadences plus 50 rapid-restart cadences (actual elapsed duration recorded); no human/client acceptance'},indent=2))
    (out/'tested.patch').write_text(git(repo,'diff','HEAD'))
    for i in range(args.pairs):
        for variant in ([args.variant] if args.variant else (['baseline','current'] if i%2==0 else ['current','baseline'])): run(repo,args.byond_bin,out/(str(i+1)+'-'+variant),variant,head)
if __name__=='__main__': main()
