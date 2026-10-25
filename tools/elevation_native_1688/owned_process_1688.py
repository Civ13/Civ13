"""Owned process-tree controller adapted from reviewed compiler controller.
Retains session leader using waitid(WNOWAIT) until last group signal.
"""
import os, selectors, signal, subprocess, time, resource
from pathlib import Path
LIMITS = {"owned_descendant_limit":64}
def limits():
    for key,value in ((resource.RLIMIT_CPU,20),(resource.RLIMIT_AS,512*1024**2),(resource.RLIMIT_FSIZE,2*1024*1024),(resource.RLIMIT_CORE,0),(resource.RLIMIT_NOFILE,64)):
        resource.setrlimit(key,(value,value))

def proc_identity(pid):
    try:
        text = Path(f"/proc/{pid}/stat").read_text()
    except FileNotFoundError:
        return None
    fields = text.rsplit(")", 1)[1].split()
    return {"pid": pid, "state": fields[0], "ppid": int(fields[1]),
            "pgrp": int(fields[2]), "session": int(fields[3]), "start_ticks": int(fields[19])}

def run_bounded(command, cwd, log_path, hard_wall, log_limit, environment):
    """Observe only our PID tree. Retain the session leader unreaped until group cleanup."""
    start = time.monotonic()
    observed = {}
    reason = None
    term_at = None
    signal_events = []
    interrupted = []
    prior = {}
    for sig in (signal.SIGINT, signal.SIGTERM):
        prior[sig] = signal.signal(sig, lambda number, frame: interrupted.append(number))
    proc = None
    retained = 0
    truncated = False
    child_listing_available = True
    try:
        with log_path.open("xb") as log:
            proc = subprocess.Popen(command, cwd=cwd, env=environment, stdin=subprocess.DEVNULL,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    start_new_session=True, close_fds=True, preexec_fn=limits)
            identity = proc_identity(proc.pid)
            if identity is None or identity["pgrp"] != proc.pid or identity["session"] != proc.pid:
                raise RuntimeError("Owned session identity not established")
            observed[proc.pid] = identity
            selector = selectors.DefaultSelector()
            os.set_blocking(proc.stdout.fileno(), False)
            selector.register(proc.stdout, selectors.EVENT_READ)

            def sample_owned():
                nonlocal child_listing_available
                pending = [proc.pid]
                visited = set()
                while pending:
                    pid = pending.pop()
                    if pid in visited:
                        continue
                    visited.add(pid)
                    current = proc_identity(pid)
                    if current is None:
                        continue
                    previous = observed.get(pid)
                    if previous and previous["start_ticks"] != current["start_ticks"]:
                        raise RuntimeError("Owned PID identity changed")
                    if current["pgrp"] != proc.pid or current["session"] != proc.pid:
                        raise RuntimeError("Owned descendant escaped its session")
                    observed[pid] = current
                    if len(observed) > LIMITS["owned_descendant_limit"]:
                        raise RuntimeError("Owned descendant bound exceeded")
                    try:
                        children = Path(f"/proc/{pid}/task/{pid}/children").read_text().split()
                    except FileNotFoundError:
                        child_listing_available = False
                        children = []
                    pending.extend(int(child) for child in children)

            def group_signal(sig):
                # waitid WNOWAIT below keeps this original leader unreaped, so
                # its PID/session identity cannot be recycled before this killpg.
                try:
                    os.killpg(proc.pid, sig)
                    signal_events.append({"signal": int(sig), "elapsed": time.monotonic() - start})
                except ProcessLookupError:
                    pass

            while True:
                sample_owned()
                exited = os.waitid(os.P_PID, proc.pid, os.WEXITED | os.WNOHANG | os.WNOWAIT)
                for key, _ in selector.select(0.05):
                    data = os.read(key.fileobj.fileno(), 65536)
                    if not data:
                        selector.unregister(key.fileobj)
                        continue
                    keep = data[:max(0, log_limit - retained)]
                    log.write(keep)
                    retained += len(keep)
                    if len(keep) != len(data):
                        truncated = True
                        reason = reason or "log_limit"
                elapsed = time.monotonic() - start
                if interrupted:
                    reason = reason or "controller_interrupted"
                if elapsed >= hard_wall:
                    reason = reason or "controller_wall_limit"
                if reason and term_at is None:
                    group_signal(signal.SIGTERM)
                    term_at = time.monotonic()
                if exited:
                    group_signal(signal.SIGKILL)
                    break
                if term_at is not None and time.monotonic() - term_at >= 1:
                    group_signal(signal.SIGKILL)
                    break
            proc.wait(timeout=3)
            # Pipes should now reach EOF. Retain at most the fixed log cap.
            until = time.monotonic() + 1
            while selector.get_map() and time.monotonic() < until:
                for key, _ in selector.select(0.02):
                    data = os.read(key.fileobj.fileno(), 65536)
                    if not data:
                        selector.unregister(key.fileobj)
                        continue
                    keep = data[:max(0, log_limit - retained)]
                    log.write(keep)
                    retained += len(keep)
                    truncated |= len(keep) != len(data)
            selector.close()
            proc.stdout.close()
        survivors = []
        final_states = []
        for pid, old in observed.items():
            current = proc_identity(pid)
            same = current is not None and current["start_ticks"] == old["start_ticks"]
            final_states.append({"pid": pid, "same_identity": same,
                                 "state": current["state"] if same else "absent_or_reused"})
            if same and current["state"] not in ("Z", "X"):
                survivors.append(current)
        group_absent = False
        until = time.monotonic() + 2
        while time.monotonic() < until:
            try:
                os.killpg(proc.pid, 0)
            except ProcessLookupError:
                group_absent = True
                break
            time.sleep(0.02)
        return {"exit_code": proc.returncode, "elapsed_seconds": time.monotonic() - start,
                "stop_reason": reason, "log_bytes": retained, "log_truncated": truncated,
                "owned_processes": list(observed.values()), "owned_final_states": final_states,
                "cleanup_no_observed_live_descendants": not survivors,
                "cleanup_process_group_absent": group_absent,
                "owned_child_listing_available": child_listing_available,
                "signal_events": signal_events,
                "global_process_census": False}
    finally:
        if proc is not None and proc.returncode is None:
            # The child has not been reaped, so its session/PID cannot be reused.
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            proc.wait(timeout=3)
        for sig, handler in prior.items():
            signal.signal(sig, handler)
