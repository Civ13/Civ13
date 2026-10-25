"""Pure in-memory process-controller tests. Never start or signal a real process.

All process, selector, signal, clock, output, and /proc operations are mocked.
Run: python -B -m unittest discover -s tools/winter_native_1688 -p test_owned_cleanup.py -v
"""
import contextlib
import io
import json
import signal
import subprocess
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from audit_offline import install
install()
import owned_process_1688 as owned


PID = 41001
CHILD = PID + 1
IDENTITY = {"pid": PID, "state": "S", "ppid": 41000, "pgrp": PID,
            "session": PID, "start_ticks": 123456}
CHILD_IDENTITY = {**IDENTITY, "pid": CHILD, "ppid": PID, "start_ticks": 123457}


class MemoryLog(io.BytesIO):
    def close(self):
        self.was_closed = True


class FakeSelector:
    def __init__(self, harness):
        self.harness = harness
        self.registered = {}
        self.closed = False

    def register(self, stream, events):
        self.registered[stream] = SimpleNamespace(fileobj=stream)

    def unregister(self, stream):
        self.registered.pop(stream)

    def select(self, timeout):
        self.harness.events.append(("select", timeout))
        return [(key, owned.selectors.EVENT_READ) for key in self.registered.values()]

    def get_map(self):
        return self.registered

    def close(self):
        self.closed = True


class Harness:
    def __init__(self):
        self.events = []
        self.clock = 0
        self.output = [b"ok\n", b""]
        self.log = MemoryLog()
        self.log_path = Mock()
        self.log_path.open.return_value = self.log
        self.stream = Mock()
        self.stream.fileno.return_value = 73
        self.proc = Mock(pid=PID, returncode=None, stdout=self.stream)
        self.proc.wait.side_effect = self.wait
        self.proc.poll.side_effect = AssertionError("poll could reap the retained leader")
        self.selector = FakeSelector(self)
        self.handlers = {signal.SIGINT: object(), signal.SIGTERM: object()}
        self.original_handlers = dict(self.handlers)
        self.identities = {PID: dict(IDENTITY)}
        self.children = {PID: ""}
        self.final_identities = {}
        self.wait_error = None
        self.signal_error = None
        self.group_present = False
        self.exited = True
        self.wait_code = 0

    def time(self):
        self.clock += 0.05
        return self.clock

    def signal(self, sig, handler):
        self.events.append(("handler", int(sig), handler))
        old = self.handlers[sig]
        self.handlers[sig] = handler
        return old

    def identity(self, pid):
        self.events.append(("identity", pid, self.proc.returncode is not None))
        source = self.final_identities if self.proc.returncode is not None else self.identities
        result = source.get(pid)
        if isinstance(result, BaseException):
            raise result
        return dict(result) if result is not None else None

    def read_children(self, path, *args, **kwargs):
        # This replacement must never read real files, including live /proc.
        name = str(path)
        for pid, value in self.children.items():
            if name == f"/proc/{pid}/task/{pid}/children":
                if isinstance(value, BaseException):
                    raise value
                return value
        raise AssertionError("Unexpected mocked path: " + name)

    def killpg(self, pid, sig):
        self.events.append(("killpg", pid, int(sig)))
        if pid != PID:
            raise AssertionError("Signaled an unowned process group")
        if sig:
            if self.proc.returncode is not None:
                raise AssertionError("Termination signal after reap")
            if self.signal_error is not None:
                raise self.signal_error
        elif not self.group_present:
            raise ProcessLookupError("Fake group absent")

    def wait(self, timeout):
        self.events.append(("wait", timeout))
        if self.wait_error is not None:
            if isinstance(self.wait_error, subprocess.TimeoutExpired):
                self.clock += timeout
            raise self.wait_error
        self.proc.returncode = self.wait_code
        return self.wait_code

    def waitid(self, which, pid, options):
        self.events.append(("waitid", which, pid, options))
        if which != owned.os.P_PID or pid != PID or not options & owned.os.WNOWAIT:
            raise AssertionError("Leader observation must retain the owned child")
        if self.exited:
            return SimpleNamespace(si_pid=PID, si_code=owned.os.CLD_EXITED, si_status=self.wait_code)
        return None

    def read(self, fd, count):
        if fd != 73:
            raise AssertionError("Read an unowned descriptor")
        return self.output.pop(0) if self.output else b""

    @contextlib.contextmanager
    def installed(self):
        with contextlib.ExitStack() as stack:
            # Guard every plausible route to live process, signal, or socket IO.
            for name in ("subprocess.run", "subprocess.call", "subprocess.check_call",
                         "subprocess.check_output", "os.kill", "os.waitpid", "socket.socket"):
                stack.enter_context(patch(name, side_effect=AssertionError("Forbidden live operation: " + name)))
            stack.enter_context(patch.object(owned.subprocess, "Popen", return_value=self.proc))
            stack.enter_context(patch.object(owned.signal, "signal", side_effect=self.signal))
            stack.enter_context(patch.object(owned.os, "killpg", side_effect=self.killpg))
            stack.enter_context(patch.object(owned.os, "waitid", side_effect=self.waitid))
            stack.enter_context(patch.object(owned.os, "set_blocking"))
            stack.enter_context(patch.object(owned.os, "read", side_effect=self.read))
            stack.enter_context(patch.object(owned.time, "monotonic", side_effect=self.time))
            stack.enter_context(patch.object(owned.time, "sleep", side_effect=lambda seconds: None))
            stack.enter_context(patch.object(owned.selectors, "DefaultSelector", return_value=self.selector))
            stack.enter_context(patch.object(owned, "proc_identity", side_effect=self.identity))
            stack.enter_context(patch.object(owned.Path, "read_text", lambda path, *args, **kwargs: self.read_children(path, *args, **kwargs)))
            stack.enter_context(patch.object(owned.Path, "open", side_effect=AssertionError("Unexpected real file IO")))
            stack.enter_context(patch.object(owned.resource, "setrlimit", side_effect=AssertionError("Unexpected resource mutation")))
            yield self

    def run(self, **kwargs):
        return owned.run_bounded(["fake-not-executable"], "/fake/cwd", self.log_path,
                                 kwargs.pop("hard_wall", 10), kwargs.pop("log_limit", 1024),
                                 {}, {}, **kwargs)


class OwnedCleanupTests(unittest.TestCase):
    def setUp(self):
        self.h = Harness()
        self.context = self.h.installed()
        self.context.__enter__()
        self.addCleanup(self.context.__exit__, None, None, None)

    def failed(self, **kwargs):
        with self.assertRaises(owned.BoundedProcessError) as caught:
            self.h.run(**kwargs)
        json.dumps(caught.exception.receipt, allow_nan=False)
        return caught.exception

    def assert_restored(self):
        self.assertEqual(self.h.handlers, self.h.original_handlers)

    def assert_signal_before_reap(self, attempts=1):
        events = self.h.events
        wait_indexes = [i for i, item in enumerate(events) if item[0] == "wait"]
        kills = [i for i, item in enumerate(events)
                 if item[:3] == ("killpg", PID, int(signal.SIGKILL))]
        self.assertEqual(len(kills), attempts)
        self.assertEqual(len(wait_indexes), attempts)
        for kill_index, wait_index in zip(kills, wait_indexes):
            self.assertLess(kill_index, wait_index)
        self.assertFalse(any(item[0] == "killpg" and item[2] != 0
                             for item in events[wait_indexes[-1] + 1:]))

    def test_normal_success_retains_leader_and_reports_actual_final_observations(self):
        receipt = self.h.run()
        json.dumps(receipt, allow_nan=False)
        self.assertTrue(receipt["cleanup_verified"])
        self.assertTrue(receipt["process_started"])
        self.assertTrue(receipt["owned_identity_established"])
        self.assertTrue(receipt["leader_reaped"])
        self.assertTrue(receipt["termination_observed"])
        self.assertEqual(receipt["exit_code"], 0)
        self.assertEqual(receipt["exit_observation"]["status"], 0)
        self.assertEqual(receipt["owned_final_states"][0]["state"], "absent_or_reused")
        self.assertEqual(receipt["signal_events"][0]["outcome"], "sent")
        self.assertFalse(receipt["global_process_census"])
        self.assertEqual(self.h.log.getvalue(), b"ok\n")
        self.assertTrue(self.h.log.was_closed)
        self.assertTrue(self.h.selector.closed)
        self.h.stream.close.assert_called_once()
        self.assertEqual(receipt["cleanup_errors"], [])
        self.assert_signal_before_reap()
        group_check = max(i for i, row in enumerate(self.h.events) if row[0] == "killpg" and row[2] == 0)
        last_identity = max(i for i, row in enumerate(self.h.events) if row[0] == "identity")
        self.assertLess(group_check, last_identity)
        self.assert_restored()

    def test_on_start_failure_carries_complete_cleanup_and_original_cause(self):
        original = ValueError("home/.byond inventory failure")
        callback = Mock(side_effect=original)
        error = self.failed(on_start=callback)
        callback.assert_called_once_with(PID, None)
        self.assertIs(error.original_error, original)
        self.assertIs(error.__cause__, original)
        self.assertTrue(error.receipt["process_started"])
        self.assertTrue(error.receipt["owned_identity_established"])
        self.assertTrue(error.receipt["cleanup_verified"])
        self.assertEqual(error.receipt["controller_error"]["stage"], "on_start")
        self.assertEqual(error.receipt["exit_code"], 0)
        self.assert_signal_before_reap()
        self.assert_restored()

    def test_on_sample_failure_carries_observed_descendant_final_state(self):
        self.h.identities[CHILD] = dict(CHILD_IDENTITY)
        self.h.children = {PID: str(CHILD), CHILD: ""}
        original = RuntimeError("sample failed")
        error = self.failed(on_sample=Mock(side_effect=original))
        self.assertIs(error.__cause__, original)
        self.assertTrue(error.receipt["cleanup_verified"])
        self.assertEqual({row["pid"] for row in error.receipt["owned_final_states"]}, {PID, CHILD})
        self.assert_signal_before_reap()
        self.assert_restored()

    def test_callback_cannot_mutate_retained_identity_evidence(self):
        def callback(pid, identity, observed):
            identity["start_ticks"] = -1
            observed[pid]["start_ticks"] = -1
        receipt = self.h.run(on_sample=callback)
        self.assertEqual(receipt["owned_leader_identity"]["start_ticks"], IDENTITY["start_ticks"])
        self.assertEqual(receipt["owned_processes"][0]["start_ticks"], IDENTITY["start_ticks"])
        self.assertTrue(receipt["cleanup_verified"])

    def test_missing_identity_still_signals_owned_retained_group_but_never_claims_cleanup(self):
        self.h.identities.clear()
        error = self.failed()
        receipt = error.receipt
        self.assertTrue(receipt["process_started"])
        self.assertFalse(receipt["owned_identity_established"])
        self.assertTrue(receipt["termination_attempted"])
        self.assertTrue(receipt["leader_reaped"])
        self.assertFalse(receipt["cleanup_verified"])
        self.assertFalse(receipt["cleanup_no_observed_live_descendants"])
        self.assertFalse(receipt["owned_final_observation_complete"])
        self.assertEqual(receipt["owned_final_states"], [])
        self.assert_signal_before_reap()
        self.assert_restored()

    def test_identity_lookup_error_preserved_after_best_effort_cleanup(self):
        original = PermissionError("fake /proc denied")
        self.h.identities[PID] = original
        error = self.failed()
        self.assertIs(error.__cause__, original)
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assertFalse(error.receipt["owned_identity_established"])
        self.assert_signal_before_reap()
        self.assert_restored()

    def test_pre_popen_log_failure_truthfully_reports_not_started(self):
        original = FileExistsError("log already exists")
        self.h.log_path.open.side_effect = original
        error = self.failed()
        self.assertIs(error.__cause__, original)
        for flag in ("process_started", "owned_identity_established", "termination_attempted",
                     "termination_observed", "leader_reaped", "cleanup_attempted", "cleanup_verified",
                     "cleanup_no_observed_live_descendants", "cleanup_process_group_absent"):
            self.assertIs(error.receipt[flag], False)
        owned.subprocess.Popen.assert_not_called()
        self.assertFalse(any(row[0] in ("killpg", "wait", "identity") for row in self.h.events))
        self.assert_restored()

    def test_popen_failure_truthfully_reports_not_started(self):
        original = OSError("fake exec failure")
        owned.subprocess.Popen.side_effect = original
        error = self.failed()
        self.assertIs(error.__cause__, original)
        self.assertFalse(error.receipt["process_started"])
        self.assertFalse(error.receipt["cleanup_attempted"])
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assertEqual(error.receipt["signal_events"], [])
        self.assertIsNone(error.receipt["pid"])
        self.assertTrue(self.h.log.was_closed)
        self.assert_restored()

    def test_callback_and_wait_failures_preserve_original_and_restore_handlers(self):
        original = ValueError("primary callback failure")
        self.h.wait_error = subprocess.TimeoutExpired("fake", 3)
        error = self.failed(on_start=Mock(side_effect=original))
        self.assertIs(error.__cause__, original)
        self.assertIs(error.original_error, original)
        self.assertFalse(error.receipt["leader_reaped"])
        self.assertIsNone(error.receipt["exit_code"])
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assertTrue(any(row["stage"] == "cleanup_wait" for row in error.receipt["cleanup_errors"]))
        self.assertEqual(error.receipt["owned_final_states"][0]["state"], "S")
        self.assertFalse(error.receipt["cleanup_no_observed_live_descendants"])
        self.assert_signal_before_reap(attempts=2)
        self.assert_restored()

    def test_signal_failure_does_not_skip_wait_final_observations_or_restoration(self):
        original = ValueError("callback failure")
        self.h.signal_error = PermissionError("fake killpg denied")
        error = self.failed(on_start=Mock(side_effect=original))
        self.assertIs(error.__cause__, original)
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assertTrue(error.receipt["termination_attempted"])
        self.assertTrue(error.receipt["leader_reaped"])
        self.assertTrue(error.receipt["owned_final_observation_complete"])
        self.assertEqual(error.receipt["signal_events"][0]["outcome"], "error")
        self.assert_signal_before_reap()
        self.assert_restored()

    def test_wait_failure_alone_is_wrapped_with_final_receipt(self):
        original = subprocess.TimeoutExpired("fake", 3)
        self.h.wait_error = original
        error = self.failed()
        self.assertIs(error.__cause__, original)
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assertEqual(error.receipt["cleanup_errors"][0]["stage"], "cleanup_wait")
        self.assert_signal_before_reap(attempts=2)
        self.assert_restored()

    def test_wait_sets_status_then_raises_keeps_status_but_does_not_verify_cleanup(self):
        original = RuntimeError("post-wait failure")
        def wait(timeout):
            self.h.events.append(("wait", timeout))
            self.h.proc.returncode = -9
            raise original
        self.h.proc.wait.side_effect = wait
        error = self.failed()
        self.assertIs(error.__cause__, original)
        self.assertTrue(error.receipt["leader_reaped"])
        self.assertEqual(error.receipt["exit_code"], -9)
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assert_signal_before_reap()
        self.assert_restored()

    def test_cleanup_close_failures_do_not_skip_other_stages(self):
        original = ValueError("callback failure")
        self.h.stream.close.side_effect = OSError("fake pipe close failure")
        error = self.failed(on_start=Mock(side_effect=original))
        self.assertIs(error.__cause__, original)
        self.assertTrue(self.h.log.was_closed)
        self.assertTrue(error.receipt["cleanup_process_group_absent"])
        self.assertTrue(error.receipt["owned_final_observation_complete"])
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assert_restored()

    def test_final_identity_failure_is_explicitly_unknown_and_fails_closed(self):
        self.h.final_identities[PID] = OSError("final observation denied")
        error = self.failed()
        receipt = error.receipt
        self.assertFalse(receipt["cleanup_verified"])
        self.assertFalse(receipt["owned_final_observation_complete"])
        self.assertFalse(receipt["cleanup_no_observed_live_descendants"])
        self.assertIsNone(receipt["owned_final_states"][0]["same_identity"])
        self.assertEqual(receipt["owned_final_states"][0]["state"], "unobserved")
        self.assert_restored()

    def test_final_observations_continue_after_one_identity_lookup_fails(self):
        self.h.identities[CHILD] = dict(CHILD_IDENTITY)
        self.h.children = {PID: str(CHILD), CHILD: ""}
        self.h.final_identities[PID] = PermissionError("denied")
        error = self.failed()
        self.assertEqual(len(error.receipt["owned_final_states"]), 2)
        self.assertEqual(error.receipt["owned_final_states"][1]["state"], "absent_or_reused")
        self.assertFalse(error.receipt["cleanup_verified"])

    def test_live_observed_descendant_prevents_verified_cleanup(self):
        self.h.identities[CHILD] = dict(CHILD_IDENTITY)
        self.h.children = {PID: str(CHILD), CHILD: ""}
        self.h.final_identities[CHILD] = dict(CHILD_IDENTITY)
        error = self.failed()
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assertFalse(error.receipt["cleanup_no_observed_live_descendants"])
        self.assertEqual(error.receipt["owned_final_states"][1]["state"], "S")

    def test_reused_pid_is_not_reported_as_the_owned_descendant(self):
        self.h.final_identities[PID] = {**IDENTITY, "start_ticks": 999999}
        receipt = self.h.run()
        self.assertTrue(receipt["cleanup_verified"])
        row = receipt["owned_final_states"][0]
        self.assertFalse(row["same_identity"])
        self.assertEqual(row["state"], "absent_or_reused")
        self.assertEqual(row["observed_start_ticks"], 999999)

    def test_missing_child_listing_never_verifies_cleanup(self):
        self.h.children[PID] = FileNotFoundError("fake children unavailable")
        error = self.failed()
        self.assertFalse(error.receipt["owned_child_listing_available"])
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assert_signal_before_reap()
        self.assert_restored()

    def test_group_still_present_exhausts_only_bounded_observation_and_fails_closed(self):
        self.h.group_present = True
        error = self.failed()
        self.assertFalse(error.receipt["cleanup_process_group_absent"])
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assertEqual(error.receipt["cleanup_group_observation"]["outcome"], "present")
        self.assertLess(error.receipt["cleanup_group_observation"]["checks"], 100)
        self.assertLess(error.receipt["elapsed_seconds"], 5)
        self.assert_signal_before_reap()
        self.assert_restored()

    def test_zero_signal_absence_is_not_confused_with_termination_delivery(self):
        def no_group(pid, sig):
            self.h.events.append(("killpg", pid, int(sig)))
            raise ProcessLookupError("fake absent group")
        owned.os.killpg.side_effect = no_group
        receipt = self.h.run()
        self.assertTrue(receipt["cleanup_verified"])
        self.assertEqual(receipt["signal_events"][0]["outcome"], "absent")
        self.assertTrue(receipt["cleanup_process_group_absent"])
        self.assert_signal_before_reap()

    def test_wall_limit_sends_term_then_kill_before_reap(self):
        self.h.exited = False
        self.h.wait_code = -9
        receipt = self.h.run(hard_wall=0)
        self.assertEqual(receipt["stop_reason"], "controller_wall_limit")
        self.assertEqual([row["signal"] for row in receipt["signal_events"]], [int(signal.SIGTERM), int(signal.SIGKILL)])
        self.assertEqual(receipt["exit_code"], -9)
        self.assertTrue(receipt["cleanup_verified"])
        self.assert_signal_before_reap()

    def test_log_limit_retains_fixed_cap_and_reports_reason(self):
        self.h.output = [b"123456789", b"abcd", b""]
        receipt = self.h.run(log_limit=4)
        self.assertEqual(receipt["log_bytes"], 4)
        self.assertEqual(self.h.log.getvalue(), b"1234")
        self.assertTrue(receipt["log_truncated"])
        self.assertEqual(receipt["stop_reason"], "log_limit")
        self.assertTrue(receipt["cleanup_verified"])
        self.assert_signal_before_reap()

    def test_keyboard_interrupt_callback_still_produces_receipt(self):
        original = KeyboardInterrupt("fake callback interruption")
        error = self.failed(on_start=Mock(side_effect=original))
        self.assertIs(error.__cause__, original)
        self.assertEqual(error.receipt["controller_error"]["type"], "KeyboardInterrupt")
        self.assertTrue(error.receipt["cleanup_verified"])
        self.assert_restored()

    def test_handler_install_failure_restores_already_installed_handler(self):
        original = ValueError("fake handler installation failure")
        def install(sig, handler):
            if sig == signal.SIGTERM:
                raise original
            return self.h.signal(sig, handler)
        owned.signal.signal.side_effect = install
        error = self.failed()
        self.assertIs(error.__cause__, original)
        self.assertFalse(error.receipt["process_started"])
        self.assertTrue(error.receipt["signal_handlers_restored"])
        self.assert_restored()

    def test_handler_restore_failure_does_not_skip_other_handler(self):
        original = ValueError("callback failure")
        def restore(sig, handler):
            if sig == signal.SIGINT and handler is self.h.original_handlers[sig]:
                raise RuntimeError("fake SIGINT restore failure")
            return self.h.signal(sig, handler)
        owned.signal.signal.side_effect = restore
        error = self.failed(on_start=Mock(side_effect=original))
        self.assertIs(error.__cause__, original)
        self.assertFalse(error.receipt["signal_handlers_restored"])
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assertIs(self.h.handlers[signal.SIGTERM], self.h.original_handlers[signal.SIGTERM])
        self.assertTrue(any(row["stage"] == "restore_signal:2" for row in error.receipt["cleanup_errors"]))

    def test_on_start_precedes_identity_lookup_even_on_callback_failure(self):
        def callback(pid, identity):
            self.assertFalse(any(row[0] == "identity" for row in self.h.events))
            raise ValueError("callback failure")
        self.assertTrue(self.failed(on_start=callback).receipt["cleanup_verified"])

    def test_nonzero_exit_keeps_actual_status_and_verified_cleanup(self):
        self.h.wait_code = 7
        receipt = self.h.run()
        self.assertEqual(receipt["exit_code"], 7)
        self.assertEqual(receipt["exit_observation"]["status"], 7)
        self.assertTrue(receipt["cleanup_verified"])
        self.assert_signal_before_reap()

    def test_waitid_failure_preserves_original_and_still_cleans_up(self):
        original = ChildProcessError("fake waitid failure")
        owned.os.waitid.side_effect = original
        error = self.failed()
        self.assertIs(error.__cause__, original)
        self.assertEqual(error.receipt["controller_error"]["stage"], "observe_exit")
        self.assertTrue(error.receipt["cleanup_verified"])
        self.assert_signal_before_reap()
        self.assert_restored()

    def test_selector_setup_failure_still_cleans_up_and_closes_resources(self):
        original = OSError("fake set_blocking failure")
        owned.os.set_blocking.side_effect = original
        error = self.failed()
        self.assertIs(error.__cause__, original)
        self.assertTrue(error.receipt["cleanup_verified"])
        self.assertTrue(self.h.selector.closed)
        self.assert_signal_before_reap()
        self.assert_restored()

    def test_output_read_failure_preserves_primary_and_records_drain_failure(self):
        original = OSError("fake read failure")
        owned.os.read.side_effect = original
        error = self.failed()
        self.assertIs(error.__cause__, original)
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assertTrue(any(row["stage"] == "cleanup_drain_output" for row in error.receipt["cleanup_errors"]))
        self.assertTrue(self.h.selector.closed)
        self.h.stream.close.assert_called_once()
        self.assert_signal_before_reap()
        self.assert_restored()

    def test_escaped_descendant_fails_closed_without_signaling_other_group(self):
        self.h.identities[CHILD] = {**CHILD_IDENTITY, "pgrp": CHILD, "session": CHILD}
        self.h.children[PID] = str(CHILD)
        error = self.failed()
        self.assertIn("escaped", str(error.original_error))
        self.assertFalse(error.receipt["owned_observation_trusted"])
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assertTrue(all(row[1] == PID for row in self.h.events if row[0] == "killpg"))
        self.assert_signal_before_reap()

    def test_changed_owned_identity_fails_closed(self):
        def callback(pid, identity, observed):
            self.h.identities[pid]["start_ticks"] += 1
        error = self.failed(on_sample=callback)
        self.assertFalse(error.receipt["owned_observation_trusted"])
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assertTrue(any("identity changed" in row["message"] for row in error.receipt["cleanup_errors"]))
        self.assert_signal_before_reap()
        self.assert_restored()

    def test_descendant_bound_still_applies_in_exception_cleanup(self):
        self.h.children[PID] = " ".join(str(PID + i) for i in range(1, 66))
        for i in range(1, 66):
            self.h.identities[PID + i] = {**CHILD_IDENTITY, "pid": PID + i, "start_ticks": 123456 + i}
            self.h.children[PID + i] = ""
        error = self.failed(on_start=Mock(side_effect=ValueError("callback failure")))
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assertFalse(error.receipt["owned_observation_trusted"])
        self.assertTrue(any("bound exceeded" in row["message"] for row in error.receipt["cleanup_errors"]))
        self.assertLessEqual(len(error.receipt["owned_processes"]), owned.LIMITS["owned_descendant_limit"] + 1)
        self.assert_signal_before_reap()
        self.assert_restored()

    def test_group_observation_failure_still_collects_final_identities(self):
        def denied_probe(pid, sig):
            if sig == 0:
                raise PermissionError("fake group probe denied")
            return self.h.killpg(pid, sig)
        owned.os.killpg.side_effect = denied_probe
        error = self.failed()
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assertFalse(error.receipt["cleanup_process_group_absent"])
        self.assertTrue(error.receipt["owned_final_observation_complete"])
        self.assertEqual(error.receipt["cleanup_group_observation"]["outcome"], "error")
        self.assert_restored()

    def test_exception_message_failure_cannot_erase_cleanup_receipt(self):
        class BrokenMessageError(Exception):
            def __str__(self):
                raise RuntimeError("broken formatting")
        original = BrokenMessageError()
        error = self.failed(on_start=Mock(side_effect=original))
        self.assertIs(error.original_error, original)
        self.assertIs(error.__cause__, original)
        self.assertTrue(error.receipt["cleanup_verified"])
        self.assertEqual(error.receipt["controller_error"]["message"], "<exception message unavailable>")
        self.assert_restored()

    def test_failed_wait_retries_owned_kill_then_reap_with_remaining_budget(self):
        original = RuntimeError("early fake wait failure")
        calls = []
        def wait(timeout):
            calls.append(timeout)
            if len(calls) == 1:
                self.h.events.append(("wait", timeout))
                raise original
            return self.h.wait(timeout)
        self.h.proc.wait.side_effect = wait
        error = self.failed()
        self.assertIs(error.__cause__, original)
        self.assertTrue(error.receipt["cleanup_retry_attempted"])
        self.assertTrue(error.receipt["leader_reaped"])
        self.assertEqual(error.receipt["exit_code"], 0)
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assertEqual(len(error.receipt["wait_events"]), 2)
        self.assertEqual(error.receipt["wait_events"][1]["outcome"], "reaped")
        self.assertLess(calls[1], calls[0])
        self.assertLessEqual(calls[0], 3)
        self.assert_signal_before_reap(attempts=2)
        self.assert_restored()

    def test_full_wait_timeout_retry_is_nonblocking_and_does_not_add_wait_budget(self):
        self.h.wait_error = subprocess.TimeoutExpired("fake", 3)
        error = self.failed()
        waits = error.receipt["wait_events"]
        self.assertEqual(len(waits), 2)
        self.assertGreater(waits[0]["timeout_seconds"], 0)
        self.assertLessEqual(waits[0]["timeout_seconds"], 3)
        self.assertEqual(waits[1]["timeout_seconds"], 0)
        self.assertFalse(error.receipt["cleanup_verified"])
        self.assertFalse(error.receipt["leader_reaped"])
        self.assert_signal_before_reap(attempts=2)
        self.assert_restored()

    def test_wait_that_reaps_then_raises_never_retries_group_signal(self):
        def wait(timeout):
            self.h.events.append(("wait", timeout))
            self.h.proc.returncode = -9
            raise RuntimeError("already reaped")
        self.h.proc.wait.side_effect = wait
        error = self.failed()
        self.assertFalse(error.receipt["cleanup_retry_attempted"])
        self.assertTrue(error.receipt["leader_reaped"])
        self.assertEqual(len(error.receipt["wait_events"]), 1)
        self.assertEqual(error.receipt["wait_events"][0]["exit_code"], -9)
        self.assert_signal_before_reap()
        self.assert_restored()


class ResourceLimitTests(unittest.TestCase):
    def test_fixed_limits_are_applied_without_real_resource_changes(self):
        profile = {"cpu": 30, "as": 1024**3, "file": 16*1024**2, "fds": 128}
        with patch.object(owned.resource, "setrlimit") as setter:
            owned.limits(profile)
        self.assertEqual(setter.call_args_list, [
            unittest.mock.call(owned.resource.RLIMIT_CPU, (30, 30)),
            unittest.mock.call(owned.resource.RLIMIT_AS, (1024**3, 1024**3)),
            unittest.mock.call(owned.resource.RLIMIT_FSIZE, (16*1024**2, 16*1024**2)),
            unittest.mock.call(owned.resource.RLIMIT_CORE, (0, 0)),
            unittest.mock.call(owned.resource.RLIMIT_NOFILE, (128, 128))])


if __name__ == "__main__":
    unittest.main()
