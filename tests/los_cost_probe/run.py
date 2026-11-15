#!/usr/bin/env python3
"""Build and run the line-of-sight cost probe (see README.md).

Manual native tool for a maintainer PC; CI never runs it. It compiles a copy
of civ13.dme with probe.dm appended, starts Dream Daemon on a loopback port,
connects guest Dream Seeker clients through a byte-counting loopback relay,
samples process CPU and memory once a second and writes one result file.
Only the processes it started are stopped at the end.
"""
import argparse
import csv
import ctypes
import json
import os
import pathlib
import shutil
import socket
import subprocess
import sys
import threading
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]
WINDOWS = os.name == "nt"
GAIA = '#include "maps\\nomads\\nomads_gaia.dmm"'
MAPS = {"gaia": GAIA, "small": '#include "maps\\nomads\\nomads.dmm"'}
LOS_OFF = "#define CIV13_GEOMETRIC_LOS_CORE 0\n#define CIV13_ROOT_TREE_PRESENTATION 0\n"


class Relay:
    """Loopback TCP relay that counts the bytes each way."""

    def __init__(self, listen_port, target_port):
        self.target_port = target_port
        self.to_clients = 0
        self.to_server = 0
        self.connections = 0
        self.lock = threading.Lock()
        self.server = socket.socket()
        self.server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server.bind(("127.0.0.1", listen_port))
        self.server.listen(32)
        threading.Thread(target=self.accept, daemon=True).start()

    def accept(self):
        while True:
            try:
                client, _ = self.server.accept()
            except OSError:
                return
            try:
                upstream = socket.create_connection(("127.0.0.1", self.target_port), timeout=10)
                upstream.settimeout(None)
            except OSError:
                client.close()
                continue
            for sock in (client, upstream):
                sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            with self.lock:
                self.connections += 1
            threading.Thread(target=self.pump, args=(client, upstream, "to_server"), daemon=True).start()
            threading.Thread(target=self.pump, args=(upstream, client, "to_clients"), daemon=True).start()

    def pump(self, source, sink, counter):
        try:
            while True:
                data = source.recv(65536)
                if not data:
                    break
                sink.sendall(data)
                with self.lock:
                    setattr(self, counter, getattr(self, counter) + len(data))
        except OSError:
            pass
        for sock in (source, sink):
            try:
                sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            sock.close()


if WINDOWS:
    from ctypes import wintypes

    class _Memory(ctypes.Structure):
        _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD)] + [
            (name, ctypes.c_size_t)
            for name in (
                "PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage", "QuotaPagedPoolUsage",
                "QuotaPeakNonPagedPoolUsage", "QuotaNonPagedPoolUsage", "PagefileUsage", "PeakPagefileUsage",
                "PrivateUsage",
            )
        ]

    def process_stats(process):
        """(cpu seconds, private bytes, working set bytes) of a Popen child."""
        handle = wintypes.HANDLE(int(process._handle))
        times = [wintypes.FILETIME() for _ in range(4)]
        if not ctypes.windll.kernel32.GetProcessTimes(handle, *[ctypes.byref(t) for t in times]):
            return None
        cpu = sum(((t.dwHighDateTime << 32) | t.dwLowDateTime) for t in times[2:]) / 1e7
        memory = _Memory()
        memory.cb = ctypes.sizeof(memory)
        ctypes.windll.psapi.GetProcessMemoryInfo(handle, ctypes.byref(memory), memory.cb)
        return cpu, memory.PrivateUsage, memory.WorkingSetSize
else:

    def process_stats(process):
        try:
            fields = pathlib.Path(f"/proc/{process.pid}/stat").read_text().rsplit(") ", 1)[1].split()
            status = pathlib.Path(f"/proc/{process.pid}/status").read_text()
        except OSError:
            return None
        cpu = (int(fields[11]) + int(fields[12])) / os.sysconf("SC_CLK_TCK")
        sizes = {line.split(":")[0]: int(line.split()[1]) * 1024 for line in status.splitlines() if line.startswith(("RssAnon", "VmRSS"))}
        return cpu, sizes.get("RssAnon", 0), sizes.get("VmRSS", 0)


def tool(byond_bin, windows_name, linux_name):
    name = windows_name if WINDOWS else linux_name
    return str(pathlib.Path(byond_bin) / name) if byond_bin else name


def build(args, out):
    dme = (ROOT / "civ13.dme").read_text(encoding="utf-8-sig")
    if GAIA not in dme:
        raise SystemExit("civ13.dme no longer includes the Gaia map by that line")
    dme = dme.replace(GAIA, MAPS[args.map])
    dme = (LOS_OFF if args.los == "off" else "") + dme + '\n#include "tests\\los_cost_probe\\probe.dm"\n'
    stem = f"losprobe_{args.map}_{args.los}"
    source = ROOT / f"{stem}.dme"
    source.write_text(dme, encoding="utf-8")
    try:
        log = subprocess.run([tool(args.byond_bin, "dm.exe", "DreamMaker"), "-max_errors", "0", source.name], cwd=ROOT, capture_output=True, text=True, errors="replace")
        (out / "compile.log").write_text(log.stdout + log.stderr, encoding="utf-8")
        if " 0 errors" not in log.stdout:
            raise SystemExit(f"compile failed, see {out / 'compile.log'}")
        shutil.move(str(ROOT / f"{stem}.dmb"), out / "probe.dmb")
        shutil.move(str(ROOT / f"{stem}.rsc"), out / "probe.rsc")
    finally:
        for suffix in (".dme", ".dmb", ".rsc", ".int", ".lk", ".dyn.rsc"):
            (ROOT / f"{stem}{suffix}").unlink(missing_ok=True)
    shutil.copytree(ROOT / "config", out / "config")
    for library in ("rust_g.dll", "librust_g.so"):
        if (ROOT / library).exists():
            shutil.copy(ROOT / library, out / library)


def read_phase(out):
    try:
        return (out / "probe-phase.txt").read_text().strip()
    except OSError:
        return "none"


def summarize(out, args, samples):
    marks = json.loads((out / "probe-marks.json").read_text())
    phases = {}
    for previous, row in zip(samples, samples[1:]):
        if row["phase"] != previous["phase"]:
            continue
        bucket = phases.setdefault(row["phase"], {"seconds": 0, "daemon_cpu_s": 0, "seeker_cpu_s": 0, "bytes_to_clients": 0, "bytes_to_server": 0, "private_mb": []})
        bucket["seconds"] += row["time"] - previous["time"]
        for key in ("daemon_cpu_s", "seeker_cpu_s", "bytes_to_clients", "bytes_to_server"):
            bucket[key] += row[key] - previous[key]
        bucket["private_mb"].append(row["daemon_private_mb"])
    for mark in marks:
        bucket = phases.get(mark["phase"])
        if not bucket or bucket["seconds"] <= 0:
            continue
        seconds = bucket["seconds"]
        private = sorted(bucket["private_mb"])
        mark["host"] = {
            "sampled_seconds": round(seconds, 1),
            "daemon_cpu_pct": round(100 * bucket["daemon_cpu_s"] / seconds, 1),
            "seekers_cpu_pct": round(100 * bucket["seeker_cpu_s"] / seconds, 1),
            "kb_per_s_to_clients": round(bucket["bytes_to_clients"] / seconds / 1024, 1),
            "kb_per_s_to_server": round(bucket["bytes_to_server"] / seconds / 1024, 2),
            "daemon_private_mb_median": private[len(private) // 2],
            "daemon_private_mb_last": bucket["private_mb"][-1],
        }
    result = {"map": args.map, "los": args.los, "clients": args.clients, "phase_seconds": args.seconds, "platform": sys.platform, "commit": args.commit, "marks": marks}
    target = pathlib.Path(args.result) if args.result else out / "result.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(result, indent=1) + "\n", encoding="utf-8")
    print(f"wrote {target}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--map", choices=sorted(MAPS), required=True)
    parser.add_argument("--los", choices=("on", "off"), default="on")
    parser.add_argument("--clients", type=int, default=8)
    parser.add_argument("--seconds", type=int, default=12, help="length of each measured phase")
    parser.add_argument("--port", type=int, default=17582, help="Dream Daemon port; the relay listens on the next one")
    parser.add_argument("--out", required=True, help="new scratch folder for this run, outside the repository")
    parser.add_argument("--result", help="where to write the result JSON (default: <out>/result.json)")
    parser.add_argument("--byond-bin", default=r"C:\Program Files (x86)\BYOND\bin" if WINDOWS else "")
    parser.add_argument("--client-wait", type=int, default=600, help="seconds the probe waits for clients")
    parser.add_argument("--timeout", type=int, default=3600)
    parser.add_argument("--no-clients", action="store_true", help="do not start Dream Seeker (connect by hand to the relay port)")
    args = parser.parse_args()
    out = pathlib.Path(args.out).resolve()
    if out.exists():
        raise SystemExit(f"{out} already exists; give a new folder")
    out.mkdir(parents=True)
    args.commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    build(args, out)
    relay = Relay(args.port + 1, args.port)
    params = f"los_clients={args.clients}&los_seconds={args.seconds}&los_wait={args.client_wait}"
    owned = []
    daemon = subprocess.Popen([tool(args.byond_bin, "dreamdaemon.exe", "DreamDaemon"), "probe.dmb", str(args.port), "-trusted", "-invisible", "-params", params, "-log", "daemon.log"], cwd=out)
    owned.append(daemon)
    seekers = []
    samples = []
    started = time.time()
    try:
        with open(out / "samples.csv", "w", newline="") as handle:
            writer = None
            while time.time() - started < args.timeout and daemon.poll() is None:
                time.sleep(1)
                phase = read_phase(out)
                if phase == "waiting for clients" and not seekers and not args.no_clients and WINDOWS:
                    for _ in range(args.clients):
                        seekers.append(subprocess.Popen([tool(args.byond_bin, "dreamseeker.exe", ""), f"byond://127.0.0.1:{args.port + 1}##guest"]))
                        time.sleep(4)
                    owned.extend(seekers)
                stats = process_stats(daemon)
                if not stats:
                    break
                seeker_cpu = sum((process_stats(seeker) or (0, 0, 0))[0] for seeker in seekers if seeker.poll() is None)
                if samples and seeker_cpu < samples[-1]["seeker_cpu_s"]:
                    seeker_cpu = samples[-1]["seeker_cpu_s"]  # a client left; keep the total monotonic
                with relay.lock:
                    row = {"time": round(time.time() - started, 2), "phase": phase, "daemon_cpu_s": round(stats[0], 3), "daemon_private_mb": round(stats[1] / 2**20, 1), "daemon_working_mb": round(stats[2] / 2**20, 1), "seeker_cpu_s": round(seeker_cpu, 3), "bytes_to_clients": relay.to_clients, "bytes_to_server": relay.to_server, "connections": relay.connections}
                if not writer:
                    writer = csv.DictWriter(handle, fieldnames=list(row))
                    writer.writeheader()
                writer.writerow(row)
                handle.flush()
                samples.append(row)
                if phase == "done":
                    break
    finally:
        for process in owned:
            if process.poll() is None:
                process.kill()
        relay.server.close()
    if read_phase(out) != "done":
        raise SystemExit(f"the probe did not finish (last phase: {read_phase(out)}); see {out}")
    summarize(out, args, samples)


if __name__ == "__main__":
    main()
