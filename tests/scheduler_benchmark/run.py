"""Comparative native process admission CPU/private-memory benchmark (Windows)."""
import argparse, ctypes, hashlib, json, os, random, re, statistics, subprocess, time
from pathlib import Path
from ctypes import wintypes
BASELINE = '7cfa850bd9d2788dcbb9fd35f5c5915ccb528dd2'
ROOT = Path(__file__).resolve().parents[2]
class Memory(ctypes.Structure):
    _fields_ = [('cb', wintypes.DWORD), ('PageFaultCount', wintypes.DWORD)] + [(x, ctypes.c_size_t) for x in ('PeakWorkingSetSize','WorkingSetSize','QuotaPeakPagedPoolUsage','QuotaPagedPoolUsage','QuotaPeakNonPagedPoolUsage','QuotaNonPagedPoolUsage','PagefileUsage','PeakPagefileUsage','PrivateUsage')]
def sample(proc):
    memory = Memory(); memory.cb = ctypes.sizeof(memory)
    api = ctypes.WinDLL('psapi', use_last_error=True).GetProcessMemoryInfo
    api.argtypes = [wintypes.HANDLE, ctypes.POINTER(Memory), wintypes.DWORD]
    if not api(wintypes.HANDLE(proc._handle), ctypes.byref(memory), memory.cb):
        raise ctypes.WinError(ctypes.get_last_error())
    return memory.PrivateUsage

def cpu(proc):
    times = [wintypes.FILETIME() for _ in range(4)]
    api = ctypes.WinDLL('kernel32', use_last_error=True).GetProcessTimes
    api.argtypes = [wintypes.HANDLE] + [ctypes.POINTER(wintypes.FILETIME)] * 4
    if not api(wintypes.HANDLE(proc._handle), *[ctypes.byref(t) for t in times]):
        raise ctypes.WinError(ctypes.get_last_error())
    return sum((t.dwHighDateTime << 32) + t.dwLowDateTime for t in times[2:]) / 10_000_000

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--byond-bin', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--repetitions', type=int, default=5)
    a = p.parse_args()
    if os.name != 'nt': p.error('Owned-process CPU and private memory sampler requires Windows')
    if a.repetitions < 5 or a.repetitions > 10: p.error('Use 5 to 10 repetitions')
    if a.output.exists() and any(a.output.iterdir()): p.error('Use fresh output')
    a.output.mkdir(parents=True, exist_ok=True)
    head = subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT,text=True).strip()
    metadata = dict(head_sha=head, baseline=BASELINE, byond='516.1681', platform=os.name, repetitions=a.repetitions, sampling_seconds=0.01, random_seed=3091, scope='Isolated unmodified production may_run; total process CPU includes startup, admission, waiting callbacks and shutdown; private bytes sampled separately', dirty_status=subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True))
    (a.output/'metadata.json').write_text(json.dumps(metadata, indent=2))
    (a.output/'tested.patch').write_bytes(subprocess.check_output(['git','diff','HEAD'],cwd=ROOT))
    variants = {}
    for name in ('baseline','fixed'):
        raw = subprocess.check_output(['git','show',BASELINE+':code/processes/_process.dm'],cwd=ROOT,text=True) if name == 'baseline' else (ROOT/'code/processes/_process.dm').read_text()
        body = re.search(r'/process/proc/may_run\([^\n]*\)[\s\S]*?(?=/datum/subsystem_module)',raw).group()
        folder = a.output/name; folder.mkdir()
        (folder/'production.dm').write_text(body)
        (folder/'probe.dm').write_bytes(Path(__file__).with_name('probe.dm').read_bytes())
        (folder/'probe.dme').write_text('#include "probe.dm"\n#include "production.dm"\n')
        build = subprocess.run([str(a.byond_bin/'dm.exe'),'-max_errors','0','probe.dme'],cwd=folder,text=True,capture_output=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
        log = build.stdout+build.stderr; (folder/'compile.log').write_text(log)
        if build.returncode or 'DM compiler version 516.1681' not in log or '0 errors, 0 warnings' not in log: raise RuntimeError(log)
        variants[name] = folder
        metadata[name+'_source_sha256'] = hashlib.sha256(raw.encode()).hexdigest()
    (a.output/'metadata.json').write_text(json.dumps(metadata,indent=2))
    def run(name, healthy, count, run_id, warmup=False):
        folder = a.output/run_id; folder.mkdir()
        source = variants[name]
        for suffix in ('dmb','rsc'):
            if (source/('probe.'+suffix)).exists(): (folder/('probe.'+suffix)).write_bytes((source/('probe.'+suffix)).read_bytes())
        rows=[]; pending_seen=False; settled=[]; start=time.monotonic()
        with (folder/'daemon.log').open('wb') as log:
            proc = subprocess.Popen([str(a.byond_bin/'dd.exe'),'probe.dmb','-invisible','-close','-safe','-log','runtime.log','-params',f'count={count}&healthy={int(healthy)}'],cwd=folder,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
            try:
                while proc.poll() is None:
                    elapsed=time.monotonic()-start
                    if elapsed > 20: raise TimeoutError('Bounded benchmark exceeded 20 seconds')
                    private=sample(proc)
                    if private > 512*1024*1024: raise RuntimeError('Private-memory ceiling exceeded')
                    phase='settled' if (folder/'result.json').exists() else 'pending' if (folder/'pending.json').exists() else 'admitting'
                    rows.append(dict(elapsed_seconds=elapsed, private_bytes=private, phase=phase))
                    if phase == 'settled': settled.append(private)
                    if phase == 'pending': pending_seen=True
                    time.sleep(0.01)
                total_cpu=cpu(proc)
                if proc.returncode: raise RuntimeError('Native process failed')
            finally:
                if proc.poll() is None: proc.kill(); proc.wait()
        logtext=(folder/'runtime.log').read_text(errors='replace')+(folder/'daemon.log').read_text(errors='replace')
        if re.search(r'runtime error|RUNTIME|Bad ref|Bad loc|BUG:|## ERROR:|Cannot read null|Cannot execute null|infinite loop',logtext,re.I): raise RuntimeError('Native diagnostics invalidate evidence')
        result=json.loads((folder/'result.json').read_text())
        if result['failures'] or not settled or not pending_seen: raise RuntimeError('Admission, expiry or sampling precondition failed')
        row=dict(variant=name,healthy=healthy,count=count,warmup=warmup,total_cpu_seconds=total_cpu,wall_seconds=time.monotonic()-start,peak_private_bytes=max(x['private_bytes'] for x in rows),settled_private_bytes=statistics.median(settled),native=result)
        (folder/'os-samples.json').write_text(json.dumps(rows))
        (folder/'summary.json').write_text(json.dumps(row,indent=2))
        return row
    results=[]
    for name in ('baseline','fixed'): results.append(run(name,True,1000,'warmup-'+name,True))
    rng=random.Random(3091)
    workloads=[(True,50000),(False,1000),(False,10000),(False,50000)]
    for healthy,count in workloads:
        for rep in range(a.repetitions):
            names=['baseline','fixed']; rng.shuffle(names)
            for name in names:
                results.append(run(name,healthy,count,f'{"healthy" if healthy else "denied"}-{count}-{rep}-{name}'))
        print(f'PASS {"healthy" if healthy else "denied"} {count}: {a.repetitions} paired repetitions',flush=True)
    aggregate=[]
    for healthy,count in workloads:
        for name in variants:
            matched=[x for x in results if not x['warmup'] and x['variant']==name and x['healthy']==healthy and x['count']==count]
            row=dict(variant=name,healthy=healthy,count=count,repetitions=len(matched))
            for metric in ('total_cpu_seconds','peak_private_bytes','settled_private_bytes','wall_seconds'):
                values=[x[metric] for x in matched]; row[metric]=dict(median=statistics.median(values),minimum=min(values),maximum=max(values))
            aggregate.append(row)
    report=dict(metadata=metadata,runs=results,aggregate=aggregate,limits=['CPU includes native startup and shutdown; no admission-only precision claim','Sampled private bytes are not retained-reference counts; peaks can fall between polls','Isolated admission histories do not prove client experience or production OOM stability','Raw may_run bodies are unmodified; no callback instrumentation contributes timing overhead'])
    (a.output/'report.json').write_text(json.dumps(report,indent=2))
    print('PASS scheduler benchmark; report '+str(a.output/'report.json'))
if __name__ == '__main__': main()

