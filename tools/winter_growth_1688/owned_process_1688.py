"""Owned process-tree controller with receipts on success and failure.

Retain the session leader with waitid(WNOWAIT) until the final group signal.
Only the child created here and its observed descendants are inspected.
"""
import os
import resource
import selectors
import signal
import subprocess
import time
from pathlib import Path

LIMITS = {"owned_descendant_limit": 64}


def limits(profile):
    for key, value in ((resource.RLIMIT_CPU, profile["cpu"]),
                       (resource.RLIMIT_AS, profile["as"]),
                       (resource.RLIMIT_FSIZE, profile["file"]),
                       (resource.RLIMIT_CORE, 0),
                       (resource.RLIMIT_NOFILE, profile["fds"])):
        resource.setrlimit(key, (value, value))


def proc_identity(pid):
    try:
        text = Path(f"/proc/{pid}/stat").read_text()
    except FileNotFoundError:
        return None
    fields = text.rsplit(")", 1)[1].split()
    return {"pid": pid, "state": fields[0], "ppid": int(fields[1]),
            "pgrp": int(fields[2]), "session": int(fields[3]), "start_ticks": int(fields[19])}


def _error_record(error, stage):
    # A broken exception __str__ must not interrupt cleanup or erase its receipt.
    try:
        message = str(error)
    except BaseException:
        message = "<exception message unavailable>"
    return {"stage": stage, "type": type(error).__name__, "message": message}


class BoundedProcessError(RuntimeError):
    """A failed invocation, with its completed, JSON-serializable receipt.

    ``original_error`` and exception chaining preserve the primary failure;
    subsequent failures are recorded separately in ``receipt['cleanup_errors']``.
    A receipt is evidence, not a success indication: check its cleanup flags.
    """

    def __init__(self, original_error, receipt):
        summary = _error_record(original_error, "failure")
        super().__init__(f'{summary["type"]}: {summary["message"]}')
        self.original_error = original_error
        self.receipt = receipt


def run_bounded(command, cwd, log_path, hard_wall, log_limit, environment, profile,
                on_sample=None, on_start=None):
    """Run one owned session; finish cleanup and its receipt before returning/raising.

    No polling/reaping is allowed before the final killpg. Cleanup retains the
    existing bounds: aggregate waits 3 seconds, drain 1 second, group observation
    2 seconds. A failed wait gets one final kill/wait retry using only the same
    remaining wait budget, and never after returncode proves the leader reaped.
    Even a callback failure or a failure before Popen gets a truthful receipt.
    """
    start = time.monotonic()
    observed = {}
    interrupted = []
    prior = {}
    proc = selector = log = identity = None
    primary_error = None
    first_cleanup_error = None
    observation_trusted = True
    sampling_started = False
    stage = "install_signal_handlers"
    term_at = None
    receipt = {
        "spawn_attempted": False, "process_started": False, "pid": None,
        "owned_identity_established": False, "owned_leader_identity": None,
        "termination_attempted": False, "termination_observed": False,
        "leader_reaped": False, "exit_code": None, "exit_observation": None,
        "elapsed_seconds": 0, "stop_reason": None,
        "log_bytes": 0, "log_truncated": False,
        "owned_processes": [], "owned_final_states": [],
        "owned_final_observation_complete": False,
        "owned_child_listing_available": False, "owned_observation_trusted": False,
        "cleanup_attempted": False, "cleanup_verified": False,
        "cleanup_no_observed_live_descendants": False,
        "cleanup_process_group_absent": False,
        "cleanup_group_observation": None, "cleanup_errors": [],
        "controller_error": None, "signal_events": [], "wait_events": [],
        "cleanup_retry_attempted": False,
        "signal_handlers_restored": False, "global_process_census": False,
    }

    def cleanup_step(name, operation):
        nonlocal first_cleanup_error
        try:
            return True, operation()
        except BaseException as error:
            if first_cleanup_error is None:
                first_cleanup_error = error
            receipt["cleanup_errors"].append(_error_record(error, name))
            return False, None

    def establish_identity():
        nonlocal identity
        identity = proc_identity(proc.pid)
        if identity is None or identity["pgrp"] != proc.pid or identity["session"] != proc.pid:
            raise RuntimeError("Owned session identity not established")
        observed[proc.pid] = dict(identity)
        receipt["owned_identity_established"] = True
        receipt["owned_leader_identity"] = dict(identity)

    def sample_owned():
        nonlocal sampling_started, observation_trusted
        if not sampling_started:
            sampling_started = True
            receipt["owned_child_listing_available"] = True
        pending = [proc.pid]
        visited = set()
        try:
            while pending:
                pid = pending.pop()
                if pid in visited:
                    continue
                visited.add(pid)
                current = proc_identity(pid)
                if current is None:
                    if pid == proc.pid:
                        raise RuntimeError("Retained owned session leader disappeared")
                    continue
                previous = observed.get(pid)
                if previous and previous["start_ticks"] != current["start_ticks"]:
                    raise RuntimeError("Owned PID identity changed")
                if current["pgrp"] != proc.pid or current["session"] != proc.pid:
                    raise RuntimeError("Owned descendant escaped its session")
                observed[pid] = dict(current)
                if len(observed) > LIMITS["owned_descendant_limit"]:
                    raise RuntimeError("Owned descendant bound exceeded")
                try:
                    children = Path(f"/proc/{pid}/task/{pid}/children").read_text().split()
                except FileNotFoundError:
                    receipt["owned_child_listing_available"] = False
                    children = []
                except BaseException:
                    receipt["owned_child_listing_available"] = False
                    raise
                pending.extend(int(child) for child in children)
        except BaseException:
            observation_trusted = False
            raise

    def group_signal(sig):
        # Popen(start_new_session=True) created this group. Its original child
        # remains unreaped, including after callback or /proc failures. Never
        # move this signal after wait(), or replace waitid(WNOWAIT) with poll().
        if proc.returncode is not None:
            raise RuntimeError("Refusing group signal after owned leader was reaped")
        receipt["termination_attempted"] = True
        event = {"signal": int(sig), "target": "owned_process_group",
                 "pid": proc.pid, "elapsed": time.monotonic() - start,
                 "outcome": "attempted"}
        receipt["signal_events"].append(event)
        try:
            os.killpg(proc.pid, sig)
            event["outcome"] = "sent"
        except ProcessLookupError:
            event["outcome"] = "absent"
        except BaseException as error:
            event["outcome"] = "error"
            event["error"] = _error_record(error, "group_signal")
            raise

    def read_ready(timeout):
        for key, _ in selector.select(timeout):
            data = os.read(key.fileobj.fileno(), 65536)
            if not data:
                selector.unregister(key.fileobj)
                continue
            keep = data[:max(0, log_limit - receipt["log_bytes"])]
            log.write(keep)
            receipt["log_bytes"] += len(keep)
            if len(keep) != len(data):
                receipt["log_truncated"] = True
                receipt["stop_reason"] = receipt["stop_reason"] or "log_limit"

    def reap_leader(timeout):
        event = {"timeout_seconds": timeout, "elapsed": time.monotonic() - start,
                 "outcome": "attempted"}
        receipt["wait_events"].append(event)
        try:
            proc.wait(timeout=timeout)
            receipt["exit_code"] = proc.returncode
            receipt["leader_reaped"] = proc.returncode is not None
            if not receipt["leader_reaped"]:
                raise RuntimeError("Owned leader wait returned without an exit status")
            receipt["termination_observed"] = True
            event["outcome"] = "reaped"
        except BaseException as error:
            event["outcome"] = "error"
            event["error"] = _error_record(error, "wait")
            raise
        finally:
            event["exit_code"] = proc.returncode

    def drain_log():
        until = time.monotonic() + 1
        while selector.get_map() and time.monotonic() < until:
            read_ready(0.02)

    def observe_group():
        observation = {"outcome": "unobserved", "checks": 0}
        receipt["cleanup_group_observation"] = observation
        until = time.monotonic() + 2
        while time.monotonic() < until:
            observation["checks"] += 1
            observation["elapsed"] = time.monotonic() - start
            try:
                os.killpg(proc.pid, 0)
            except ProcessLookupError:
                observation["outcome"] = "absent"
                receipt["cleanup_process_group_absent"] = True
                return
            except BaseException:
                observation["outcome"] = "error"
                raise
            observation["outcome"] = "present"
            time.sleep(0.02)

    def observe_final_states():
        # Final observations happen AFTER the bounded group observation, not
        # before cleanup. PID reuse is never attributed to the original owner.
        complete = bool(observed) and receipt["owned_identity_established"]
        survivors = []
        for pid, old in observed.items():
            row = {"pid": pid, "expected_start_ticks": old["start_ticks"],
                   "same_identity": None, "state": "unobserved"}
            receipt["owned_final_states"].append(row)
            ok, current = cleanup_step(f"final_identity:{pid}", lambda pid=pid: proc_identity(pid))
            if not ok:
                complete = False
                continue
            same = current is not None and current["start_ticks"] == old["start_ticks"]
            row.update({"same_identity": same,
                        "state": current["state"] if same else "absent_or_reused",
                        "observed_start_ticks": current["start_ticks"] if current else None})
            if same and current["state"] not in ("Z", "X"):
                survivors.append(current)
        receipt["owned_final_observation_complete"] = complete
        receipt["cleanup_no_observed_live_descendants"] = complete and not survivors

    try:
        for sig in (signal.SIGINT, signal.SIGTERM):
            prior[sig] = signal.signal(sig, lambda number, frame: interrupted.append(number))
        stage = "open_log"
        log = log_path.open("xb")
        stage = "spawn"
        receipt["spawn_attempted"] = True
        proc = subprocess.Popen(command, cwd=cwd, env=environment, stdin=subprocess.DEVNULL,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                start_new_session=True, close_fds=True, preexec_fn=lambda: limits(profile))
        receipt["process_started"] = True
        receipt["pid"] = proc.pid
        stage = "on_start"
        if on_start is not None:
            on_start(proc.pid, None)
        stage = "establish_identity"
        establish_identity()
        stage = "configure_output"
        selector = selectors.DefaultSelector()
        os.set_blocking(proc.stdout.fileno(), False)
        selector.register(proc.stdout, selectors.EVENT_READ)
        while True:
            stage = "sample_owned"
            sample_owned()
            stage = "on_sample"
            if on_sample is not None:
                on_sample(proc.pid, dict(identity), {pid: dict(row) for pid, row in observed.items()})
            stage = "observe_exit"
            exited = os.waitid(os.P_PID, proc.pid, os.WEXITED | os.WNOHANG | os.WNOWAIT)
            if exited:
                receipt["exit_observation"] = {"pid": exited.si_pid, "code": exited.si_code,
                                               "status": exited.si_status}
                receipt["termination_observed"] = True
            stage = "read_output"
            read_ready(0.05)
            elapsed = time.monotonic() - start
            if interrupted:
                receipt["stop_reason"] = receipt["stop_reason"] or "controller_interrupted"
            if elapsed >= hard_wall:
                receipt["stop_reason"] = receipt["stop_reason"] or "controller_wall_limit"
            if receipt["stop_reason"] and term_at is None:
                stage = "terminate_group"
                group_signal(signal.SIGTERM)
                term_at = time.monotonic()
            if exited or (term_at is not None and time.monotonic() - term_at >= 1):
                break
    except BaseException as error:
        primary_error = error
        receipt["controller_error"] = _error_record(error, stage)
        receipt["stop_reason"] = receipt["stop_reason"] or "controller_error"
    finally:
        # No cleanup failure is permitted to bypass another cleanup stage or
        # restoration of any successfully installed signal handler.
        try:
            if proc is not None:
                receipt["cleanup_attempted"] = True
                if not receipt["owned_identity_established"]:
                    cleanup_step("cleanup_establish_identity", establish_identity)
                if receipt["owned_identity_established"]:
                    # One last owned-tree sample while the leader is retained;
                    # callback errors must not bypass descendant discovery.
                    cleanup_step("cleanup_sample_owned", sample_owned)
                reap_deadline = time.monotonic() + 3
                cleanup_step("cleanup_kill_group", lambda: group_signal(signal.SIGKILL))
                waited, _ = cleanup_step("cleanup_wait", lambda: reap_leader(
                    max(0, reap_deadline - time.monotonic())))
                if not waited and proc.returncode is None:
                    # Retain the original best-effort exceptional kill/wait,
                    # but share the existing budget rather than adding 3s.
                    receipt["cleanup_retry_attempted"] = True
                    cleanup_step("cleanup_retry_kill_group", lambda: group_signal(signal.SIGKILL))
                    cleanup_step("cleanup_retry_wait", lambda: reap_leader(
                        max(0, reap_deadline - time.monotonic())))
                # wait() may set returncode and then raise: preserve actual state.
                receipt["exit_code"] = proc.returncode
                receipt["leader_reaped"] = proc.returncode is not None
                receipt["termination_observed"] |= receipt["leader_reaped"]
                if selector is not None and log is not None:
                    cleanup_step("cleanup_drain_output", drain_log)
            if selector is not None:
                cleanup_step("cleanup_close_selector", selector.close)
            if proc is not None and proc.stdout is not None:
                cleanup_step("cleanup_close_stdout", proc.stdout.close)
            if log is not None:
                cleanup_step("cleanup_close_log", log.close)
            if proc is not None:
                cleanup_step("cleanup_observe_group", observe_group)
                cleanup_step("cleanup_observe_final_states", observe_final_states)
        finally:
            restored = True
            for sig, handler in prior.items():
                ok, _ = cleanup_step(f"restore_signal:{int(sig)}",
                                     lambda sig=sig, handler=handler: signal.signal(sig, handler))
                restored &= ok
            receipt["signal_handlers_restored"] = restored

    receipt["owned_processes"] = list(observed.values())
    receipt["owned_observation_trusted"] = bool(observation_trusted and sampling_started)
    receipt["elapsed_seconds"] = time.monotonic() - start
    receipt["cleanup_verified"] = bool(
        receipt["process_started"] and receipt["owned_identity_established"]
        and observation_trusted and receipt["owned_child_listing_available"]
        and receipt["leader_reaped"] and receipt["owned_final_observation_complete"]
        and receipt["cleanup_no_observed_live_descendants"]
        and receipt["cleanup_process_group_absent"]
        and receipt["signal_handlers_restored"] and not receipt["cleanup_errors"])
    error = primary_error if primary_error is not None else first_cleanup_error
    if error is None and not receipt["cleanup_verified"]:
        error = RuntimeError("Owned process cleanup was not verified")
        receipt["controller_error"] = _error_record(error, "cleanup_verification")
    if error is not None:
        raise BoundedProcessError(error, receipt) from error
    return receipt
