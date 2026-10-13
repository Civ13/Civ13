"""Bounded OS observations; phase CPU remains engine-measured in the DM probe."""
import ctypes
import os
import time
from pathlib import Path

class Counters(ctypes.Structure):
    _fields_=[('cb',ctypes.c_ulong),('faults',ctypes.c_ulong),('peakws',ctypes.c_size_t),('ws',ctypes.c_size_t),('ppp',ctypes.c_size_t),('pp',ctypes.c_size_t),('pnp',ctypes.c_size_t),('np',ctypes.c_size_t),('page',ctypes.c_size_t),('peakpage',ctypes.c_size_t),('private',ctypes.c_size_t)]

def observe(proc, timeout):
    handle=None; peak=0; last=None; cpu=None
    if os.name=='nt':
        ctypes.windll.kernel32.OpenProcess.restype=ctypes.c_void_p
        handle=ctypes.windll.kernel32.OpenProcess(0x410,False,proc.pid)
        if not handle: raise RuntimeError('Process observation unavailable')
    try:
        deadline=time.monotonic()+timeout
        while proc.poll() is None:
            if time.monotonic()>deadline: raise RuntimeError('Daemon timeout')
            if handle:
                c=Counters(); c.cb=ctypes.sizeof(c)
                if not ctypes.windll.psapi.GetProcessMemoryInfo(ctypes.c_void_p(handle),ctypes.byref(c),c.cb):
                    if proc.poll() is not None: break
                    raise RuntimeError('Memory sampling failed')
                last=c.private
            else:
                try:
                    rows=Path(f'/proc/{proc.pid}/smaps_rollup').read_text().splitlines()
                    last=sum(int(x.split()[1])*1024 for x in rows if x.startswith(('Private_Clean:','Private_Dirty:')))
                except (FileNotFoundError,ProcessLookupError): break
            peak=max(peak,last)
            time.sleep(.02)
        proc.wait(timeout=5)
        if handle:
            times=(ctypes.c_ulonglong*4)()
            if ctypes.windll.kernel32.GetProcessTimes(ctypes.c_void_p(handle),ctypes.byref(times,0),ctypes.byref(times,8),ctypes.byref(times,16),ctypes.byref(times,24)):
                cpu=(times[2]+times[3])/10000000
        return dict(peak_private_bytes=peak,final_sample_private_bytes=last,process_cpu_seconds=cpu)
    finally:
        if handle: ctypes.windll.kernel32.CloseHandle(ctypes.c_void_p(handle))
        if proc.poll() is None: proc.kill(); proc.wait()
