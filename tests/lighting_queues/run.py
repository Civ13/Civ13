"""Native queue benchmark using unchanged production process bodies, offline."""
import argparse, hashlib, json, os, subprocess, tempfile, time
from pathlib import Path

BASELINE = '4e6211fe1a50519f91104fa32da32990baf0f4d4'
def main():
    p = argparse.ArgumentParser()
    p.add_argument('--byond-bin', type=Path, required=True)
    p.add_argument('--baseline', action='store_true')
    p.add_argument('--size', type=int, default=20000)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--negative-control', choices=('skip','retain'))
    a = p.parse_args()
    root = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix='civ13-lighting-') as tmp:
        out = Path(tmp)
        mutated = False
        for name in ('overlays', 'sources'):
            rel = f'code/processes/lighting/{name}.dm'
            text = subprocess.check_output(['git', 'show', f'{BASELINE}:{rel}'], cwd=root, text=True) if a.baseline else (root/rel).read_text()
            if a.negative_control == 'skip':
                text = text.replace('current_list[batch_index++] = null', 'current_list[batch_index] = null\n\t\tbatch_index += 2')
            if a.negative_control == 'retain':
                text = text.replace('current_list[batch_index++] = null','batch_index++')
            if a.negative_control and text != (root/rel).read_text(): mutated = True
            (out/f'{name}.dm').write_text(text)
        if a.negative_control and not mutated: raise RuntimeError('Mutation anchor changed')
        probe=(root/'tests/lighting_queues/probe.dm').read_text()
        if a.negative_control == 'skip': probe=probe.replace('if(active_process.current_list[i])','if(active_process.current_list[i] && world.params["retain_check"])')
        (out/'probe.dm').write_text(probe)
        (out/'probe.dme').write_text('#include "probe.dm"\n#include "overlays.dm"\n#include "sources.dm"\n')
        flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
        dm = a.byond_bin/('dm.exe' if os.name == 'nt' else 'DreamMaker')
        dd = a.byond_bin/('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        build = subprocess.run([str(dm), 'probe.dme'], cwd=out, capture_output=True, text=True, creationflags=flags)
        print(build.stdout)
        if build.returncode or '0 errors, 0 warnings' not in build.stdout: raise RuntimeError('Compilation failed')
        with (out/'daemon.log').open('w') as log:
            cmd=[str(dd),'probe.dmb']
            if os.name=='nt': cmd+=['-invisible','-close']
            cmd+=['-safe','-params',f'size={a.size}','-log','runtime.log']
            proc = subprocess.Popen(cmd, cwd=out, stdout=log, stderr=log, creationflags=flags)
            peak = 0
            samples = []
            try:
                import ctypes
                class Counters(ctypes.Structure):
                    _fields_ = [('cb',ctypes.c_ulong),('faults',ctypes.c_ulong),('peakws',ctypes.c_size_t),('ws',ctypes.c_size_t),('ppp',ctypes.c_size_t),('pp',ctypes.c_size_t),('pnp',ctypes.c_size_t),('np',ctypes.c_size_t),('page',ctypes.c_size_t),('peakpage',ctypes.c_size_t),('private',ctypes.c_size_t)]
                handle=None
                if os.name=='nt':
                    ctypes.windll.kernel32.OpenProcess.restype = ctypes.c_void_p
                    handle = ctypes.windll.kernel32.OpenProcess(0x410,False,proc.pid)
                deadline = time.monotonic()+120
                while proc.poll() is None:
                    if time.monotonic()>deadline: raise RuntimeError('Daemon timeout')
                    if os.name=='nt':
                        c = Counters(); c.cb=ctypes.sizeof(c)
                        if not ctypes.windll.psapi.GetProcessMemoryInfo(ctypes.c_void_p(handle),ctypes.byref(c),c.cb): raise RuntimeError('Memory sampling failed')
                        private=c.private
                    else:
                        try:
                            rows=Path(f'/proc/{proc.pid}/smaps_rollup').read_text().splitlines()
                            private=sum(int(x.split()[1])*1024 for x in rows if x.startswith(('Private_Clean:','Private_Dirty:')))
                        except (FileNotFoundError, ProcessLookupError): break
                    samples.append(private); peak=max(peak,private)
                    time.sleep(.02)
                cpu_seconds=None
                if handle:
                    times=(ctypes.c_ulonglong*4)()
                    if ctypes.windll.kernel32.GetProcessTimes(ctypes.c_void_p(handle),ctypes.byref(times,0),ctypes.byref(times,8),ctypes.byref(times,16),ctypes.byref(times,24)):
                        cpu_seconds=(times[2]+times[3])/10000000
                    ctypes.windll.kernel32.CloseHandle(ctypes.c_void_p(handle))
            finally:
                if proc.poll() is None: proc.kill(); proc.wait()
        log = (out/'runtime.log').read_text(errors='replace')
        failed = proc.returncode or 'PASS' not in log or any(s in log for s in ('FAIL','runtime error','Runtime in','Bad ref'))
        if a.negative_control:
            expected='Missing or duplicate work' if a.negative_control=='skip' else 'Consumed reference retained'
            if not failed or expected not in log: raise RuntimeError('Negative control failed wrong contract: '+log)
            print('PASS: negative control detected'); return
        if failed: raise RuntimeError(log)
        rows = [json.loads(x) for x in (out/'results.jsonl').read_text().splitlines()]
        patch=subprocess.check_output(['git','diff','HEAD'],cwd=root)
        report = dict(head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(), dirty_patch_sha256=hashlib.sha256(patch).hexdigest(), baseline=BASELINE if a.baseline else None, scope='production queue bodies with trivial callbacks', size=a.size, rows=rows, process_cpu_seconds=cpu_seconds, peak_private_bytes=peak, final_sample_private_bytes=samples[-1] if samples else None, runtime=log)
        a.output.parent.mkdir(parents=True,exist_ok=True); a.output.write_text(json.dumps(report,indent=2))
        print(json.dumps({k:v for k,v in report.items() if k not in ('rows','runtime')},indent=2))
if __name__ == '__main__': main()
