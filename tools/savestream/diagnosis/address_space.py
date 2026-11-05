#!/usr/bin/env python3
"""Address-space sampler for Dream Daemon (a scriptable VMMap summary).

Samples a running process every --interval seconds and writes one JSON line
per sample: committed private memory, image and mapped sizes, reserved but
uncommitted space, free space, the largest free block and the number of free
fragments inside the 4 GB a 32-bit process can address. Fragmentation, not
RAM, is what ends a 32-bit process near 3.5 GB, so "largest_free_mb" is the
number to watch.

Windows uses VirtualQueryEx and GetProcessMemoryInfo (run from any Python,
32- or 64-bit). Linux reads /proc/<pid>/maps and /proc/<pid>/status.

    py -3 address_space.py --pid 1234 --out samples.jsonl
    py -3 address_space.py --name dd.exe --phases bench_phases.log --out samples.jsonl

With --phases, a full region map is also written whenever a new line appears
in that phase log (bench.dm writes one per phase), to <out>.<n>.regions.json.
Read-only: it never writes to the target process.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

LIMIT = 1 << 32  # a 32-bit (LAA) process on a 64-bit OS


def summarize(regions: list[dict]) -> dict:
    out = {"private_committed_mb": 0.0, "image_mb": 0.0, "mapped_mb": 0.0, "reserved_mb": 0.0,
           "free_mb": 0.0, "largest_free_mb": 0.0, "free_fragments": 0, "free_fragments_over_64mb": 0}
    for r in regions:
        size = r["size"] / 1048576
        if r["state"] == "free":
            out["free_mb"] += size
            out["free_fragments"] += 1
            if size >= 64:
                out["free_fragments_over_64mb"] += 1
            out["largest_free_mb"] = max(out["largest_free_mb"], size)
        elif r["state"] == "reserve":
            out["reserved_mb"] += size
        elif r["type"] == "image":
            out["image_mb"] += size
        elif r["type"] == "mapped":
            out["mapped_mb"] += size
        else:
            out["private_committed_mb"] += size
    return {k: round(v, 1) if isinstance(v, float) else v for k, v in out.items()}


# ---------------------------------------------------------------- Windows
if os.name == "nt":
    import ctypes
    from ctypes import wintypes

    class MBI(ctypes.Structure):
        _fields_ = [("BaseAddress", ctypes.c_void_p), ("AllocationBase", ctypes.c_void_p),
                    ("AllocationProtect", wintypes.DWORD), ("PartitionId", wintypes.WORD),
                    ("RegionSize", ctypes.c_size_t), ("State", wintypes.DWORD),
                    ("Protect", wintypes.DWORD), ("Type", wintypes.DWORD)]

    class PMC(ctypes.Structure):
        _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD),
                    ("PeakWorkingSetSize", ctypes.c_size_t), ("WorkingSetSize", ctypes.c_size_t),
                    ("QuotaPeakPagedPoolUsage", ctypes.c_size_t), ("QuotaPagedPoolUsage", ctypes.c_size_t),
                    ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t), ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                    ("PagefileUsage", ctypes.c_size_t), ("PeakPagefileUsage", ctypes.c_size_t)]

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    psapi = ctypes.WinDLL("psapi", use_last_error=True)
    kernel32.OpenProcess.restype = wintypes.HANDLE
    kernel32.VirtualQueryEx.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.POINTER(MBI), ctypes.c_size_t]
    kernel32.VirtualQueryEx.restype = ctypes.c_size_t
    MEM_COMMIT, MEM_RESERVE, MEM_FREE = 0x1000, 0x2000, 0x10000
    MEM_IMAGE, MEM_MAPPED = 0x1000000, 0x40000

    def open_process(pid: int):
        handle = kernel32.OpenProcess(0x0400 | 0x0010, False, pid)  # QUERY_INFORMATION | VM_READ
        if not handle:
            raise OSError(ctypes.get_last_error(), f"OpenProcess({pid}) failed")
        return handle

    def regions(handle) -> list[dict]:
        out, address, mbi = [], 0, MBI()
        while address < LIMIT:
            if not kernel32.VirtualQueryEx(handle, ctypes.c_void_p(address), ctypes.byref(mbi), ctypes.sizeof(mbi)):
                break
            size = min(mbi.RegionSize, LIMIT - address)
            state = {MEM_COMMIT: "commit", MEM_RESERVE: "reserve"}.get(mbi.State, "free")
            kind = {MEM_IMAGE: "image", MEM_MAPPED: "mapped"}.get(mbi.Type, "private")
            out.append({"base": address, "size": size, "state": state, "type": kind})
            address += mbi.RegionSize
        return out

    def counters(handle) -> dict:
        pmc = PMC()
        pmc.cb = ctypes.sizeof(pmc)
        psapi.GetProcessMemoryInfo(handle, ctypes.byref(pmc), pmc.cb)
        return {"working_set_mb": round(pmc.WorkingSetSize / 1048576, 1),
                "peak_working_set_mb": round(pmc.PeakWorkingSetSize / 1048576, 1),
                "private_bytes_mb": round(pmc.PagefileUsage / 1048576, 1),
                "peak_private_bytes_mb": round(pmc.PeakPagefileUsage / 1048576, 1)}

    def find_pid(name: str) -> int | None:
        import subprocess
        out = subprocess.run(["tasklist", "/FI", f"IMAGENAME eq {name}", "/FO", "CSV", "/NH"], capture_output=True, text=True).stdout
        for line in out.splitlines():
            parts = [p.strip('"') for p in line.split('","')]
            if len(parts) > 1 and parts[0].lower() == name.lower():
                return int(parts[1])
        return None

    def alive(handle) -> bool:
        code = wintypes.DWORD()
        kernel32.GetExitCodeProcess(handle, ctypes.byref(code))
        return code.value == 259  # STILL_ACTIVE

# ---------------------------------------------------------------- Linux
else:
    def open_process(pid: int):
        if not Path(f"/proc/{pid}").exists():
            raise OSError(f"no process {pid}")
        return pid

    def regions(pid) -> list[dict]:
        out, last = [], 0
        for line in Path(f"/proc/{pid}/maps").read_text().splitlines():
            parts = line.split()
            start, end = (int(x, 16) for x in parts[0].split("-"))
            if start >= LIMIT:
                break
            if start > last:
                out.append({"base": last, "size": start - last, "state": "free", "type": "free"})
            path = parts[5] if len(parts) > 5 else ""
            perms = parts[1]
            state = "reserve" if perms.startswith("---") else "commit"
            kind = "image" if path.startswith("/") and (".so" in path or path.endswith(("DreamDaemon", "dreamdaemon"))) else \
                "mapped" if path.startswith("/") else "private"
            out.append({"base": start, "size": min(end, LIMIT) - start, "state": state, "type": kind, "path": path})
            last = end
        if last < LIMIT:
            out.append({"base": last, "size": LIMIT - last, "state": "free", "type": "free"})
        return out

    def counters(pid) -> dict:
        out = {}
        for line in Path(f"/proc/{pid}/status").read_text().splitlines():
            key, _, value = line.partition(":")
            if key in ("VmPeak", "VmSize", "VmHWM", "VmRSS"):
                out[key] = round(int(value.split()[0]) / 1024, 1)
        return out

    def find_pid(name: str) -> int | None:
        for proc in Path("/proc").iterdir():
            if proc.name.isdigit():
                try:
                    if (proc / "comm").read_text().strip() == name:
                        return int(proc.name)
                except OSError:
                    continue
        return None

    def alive(pid) -> bool:
        return Path(f"/proc/{pid}").exists()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pid", type=int)
    ap.add_argument("--name", help="process name to wait for (dd.exe, DreamDaemon)")
    ap.add_argument("--out", required=True)
    ap.add_argument("--interval", type=float, default=1.0)
    ap.add_argument("--phases", help="phase log to watch; a full region map is saved per new line")
    ap.add_argument("--wait", type=float, default=120.0, help="seconds to wait for --name to appear")
    args = ap.parse_args()
    pid = args.pid
    deadline = time.time() + args.wait
    while not pid and time.time() < deadline:
        pid = find_pid(args.name) if args.name else None
        if not pid:
            time.sleep(0.2)
    if not pid:
        print("process not found", file=sys.stderr)
        return 1
    handle = open_process(pid)
    seen_phases = 0
    snapshots = 0
    started = time.time()
    peak = {}
    with open(args.out, "w") as out:
        while alive(handle):
            try:
                regs = regions(handle)
                sample = {"t": round(time.time() - started, 2), "pid": pid, **counters(handle), **summarize(regs)}
            except OSError:
                break
            phase = None
            if args.phases and Path(args.phases).exists():
                lines = Path(args.phases).read_text().splitlines()
                if len(lines) > seen_phases:
                    phase = lines[-1]
                    seen_phases = len(lines)
                    snapshots += 1
                    Path(f"{args.out}.{snapshots}.regions.json").write_text(json.dumps({"phase": phase, "regions": regs}))
            if phase:
                sample["phase"] = phase
            for key in ("private_committed_mb", "largest_free_mb"):
                if key == "largest_free_mb":
                    peak["min_largest_free_mb"] = min(peak.get("min_largest_free_mb", 1e9), sample[key])
                else:
                    peak["max_" + key] = max(peak.get("max_" + key, 0), sample[key])
            out.write(json.dumps(sample) + "\n")
            out.flush()
            time.sleep(args.interval)
    print(json.dumps({"pid": pid, "samples_file": args.out, **peak}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
