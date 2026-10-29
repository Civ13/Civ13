"""Offline source-driven traces, not a DM compiler or native iterator test.

Translate only an explicit vocabulary from production fire/reset/finished bodies.
Unknown instructions fail closed. External callbacks, list iteration/removal and
budget reads are Python adapters; validate those separately with native BYOND.
"""
from pathlib import Path
import hashlib
import re
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
EARLY = 1234


def historical_source():
    data = Path(__file__).with_name('historical-research.txt').read_bytes()
    if hashlib.sha256(data).hexdigest() != '462d5363b8b9d7944957097bb7db3f0e4c631ece28a3b70d2fcd33f755f564fc':
        raise ValueError('Historical research control differs from the reviewed fixture')
    return data.decode('utf-8')


def proc(source, signature):
    match = re.search(r"^" + re.escape(signature) + r"\n(.*?)(?=^/|\Z)",
                      source, re.M | re.S)
    if not match:
        raise ValueError(f"Missing production procedure: {signature}")
    return match.group(1)


def translate(body):
    """Preserve production control flow, replacing only these named operations."""
    vocabulary = {
        "for (current in current_list)": "for current in ctx.pending_copy():",
        "for (current in research_benches.Copy())": "for current in ctx.live.copy():",
        "var/obj/structure/research_bench/B = current": "B = current",
        "if (QDELETED(B))": "if B is None or B.deleted:",
        "research_benches -= B": "ctx.remove_last(ctx.live, B)",
        "continue": "continue",
        "else": "else:",
        "try": "try:",
        "B.analysis_tick()": "ctx.analyse(B)",
        "catch (var/exception/e)": "except RuntimeError as e:",
        "catchException(e, B)": "ctx.errors.append(B.name)",
        "PROCESS_LIST_CHECK": "ctx.remove_last(ctx.pending, current)",
        "PROCESS_TICK_CHECK": "if ctx.check_budget(): return EARLY",
        "PROCESS_USE_FASTEST_LIST(research_benches)": "ctx.pending = ctx.live.copy()",
        "if (priority != PROCESS_PRIORITY_IRRELEVANT)": "if ctx.priority != 6:",
        "PROCESS_USE_FASTEST_LIST(list())": "ctx.pending = []",
        "ticks++": "ctx.ticks += 1",
        "idle()": "pass",
        "main.processFinished(src)": "pass",
        "onFinish()": "pass",
        "if (fire_result == PROCESS_TICK_CHECK_RETURNED_EARLY && !length(current_list))":
            "if fire_result == EARLY and not ctx.pending:",
        "fire_result = null": "fire_result = None",
        "if (fire_result != PROCESS_TICK_CHECK_RETURNED_EARLY || !length(current_list))":
            "if fire_result != EARLY or not ctx.pending:",
        "current = null": "pass",
        "current_list = null": "ctx.pending = None",
        "return fire_result": "return fire_result",
    }
    lines = ["def execute(ctx, fire_result=None):"]
    for raw in body.splitlines():
        instruction = raw.strip()
        if not instruction or instruction.startswith("//"):
            continue
        if instruction not in vocabulary:
            raise ValueError(f"Unsupported production instruction: {instruction}")
        depth = len(raw) - len(raw.lstrip("\t"))
        if depth < 1:
            raise ValueError("Expected DM tab indentation")
        lines.append("    " * depth + vocabulary[instruction])
    namespace = {"EARLY": EARLY}
    exec(compile("\n".join(lines), "<restricted production translation>", "exec"),
         namespace)
    return namespace["execute"]


class Bench:
    def __init__(self, name, *, deleted=False, raises=False):
        self.name = name
        self.deleted = deleted
        self.raises = raises


class Trace:
    def __init__(self, source, benches):
        self.live = benches.copy()
        self.pending = None
        self.visits = []
        self.errors = []
        self.ticks = 0
        self.checks = 0
        self.limit = None
        self.callback = lambda bench: None
        self.priority = 4  # production research setup is LOW; contract below pins it
        self.fire = translate(proc(source, "/process/research_tree/fire()"))
        process = (ROOT / "code/processes/_process.dm").read_text()
        signature = "/process/research_tree/reset_current_list()"
        reset_body = proc(source, signature) if signature in source else proc(
            process, "/process/proc/reset_current_list()")
        self.reset = translate(reset_body)
        self.finish = translate(proc(process, "/process/proc/finished(fire_result = null)"))

    @staticmethod
    def remove_last(items, item):
        # Existing native subtraction contract; no proposed shared macro change.
        for index in range(len(items) - 1, -1, -1):
            if items[index] is item:
                del items[index]
                return

    def pending_copy(self):
        return self.pending.copy()

    def analyse(self, bench):
        self.visits.append(bench.name)
        self.callback(bench)
        if bench.raises:
            raise RuntimeError("injected analysis failure")

    def check_budget(self):
        self.checks += 1
        return self.limit is not None and self.checks >= self.limit

    def dispatch(self, limit=None):
        if self.pending is None:
            self.reset(self)
        self.limit = limit
        self.checks = 0
        self.last_fire_result = self.fire(self)
        return self.finish(self, self.last_fire_result)


class ResearchResumeTests(unittest.TestCase):
    def test_historical_control_rejects_fixture_drift(self):
        with patch.object(Path, 'read_bytes', return_value=b'altered historical source'):
            with self.assertRaisesRegex(ValueError, 'Historical research control'):
                historical_source()

    def setUp(self):
        self.source = (ROOT / "code/processes/research_tree.dm").read_text()
        self.a, self.b, self.c = [Bench(name) for name in "abc"]

    def trace(self, benches=None, source=None):
        return Trace(source or self.source, benches if benches is not None
                     else [self.a, self.b, self.c])

    def test_early_returns_eventually_service_tail_once(self):
        trace = self.trace()
        self.assertEqual(trace.dispatch(1), EARLY)
        self.assertEqual(trace.visits, ["a"])
        self.assertEqual(trace.pending, [self.b, self.c])
        self.assertEqual(trace.dispatch(1), EARLY)
        self.assertIsNone(trace.dispatch(1))
        self.assertEqual(trace.visits, ["a", "b", "c"])
        self.assertIsNone(trace.pending)

    def test_last_entry_budget_is_complete_and_next_pass_is_fresh(self):
        trace = self.trace()
        self.assertIsNone(trace.dispatch(3))
        self.assertEqual(trace.last_fire_result, EARLY)
        self.assertIsNone(trace.pending)
        trace.live = [self.c]
        self.assertIsNone(trace.dispatch(1))
        self.assertEqual(trace.visits, ["a", "b", "c", "c"])

    def test_additions_wait_and_live_removal_does_not_discard_snapshot_tail(self):
        trace = self.trace()
        trace.dispatch(1)
        new = Bench("new")
        trace.live = [self.a, self.b, new]
        self.assertIsNone(trace.dispatch())
        self.assertEqual(trace.visits, ["a", "b", "c"])
        trace.dispatch()
        self.assertEqual(trace.visits, ["a", "b", "c", "a", "b", "new"])

    def test_deletion_between_resumes_is_consumed_before_budget_check(self):
        trace = self.trace()
        trace.dispatch(1)
        self.b.deleted = True
        self.assertEqual(trace.dispatch(1), EARLY)
        self.assertEqual(trace.checks, 1)
        self.assertNotIn(self.b, trace.live)
        self.assertEqual(trace.pending, [self.c])
        self.assertIsNone(trace.dispatch(1))
        self.assertEqual(trace.visits, ["a", "c"])

    def test_null_and_deleted_only_snapshots_finish(self):
        for entries in ([None], [None, Bench("dead", deleted=True)]):
            with self.subTest(entries=entries):
                trace = self.trace(entries)
                for _ in entries:
                    trace.dispatch(1)
                self.assertIsNone(trace.pending)
                self.assertEqual(trace.live, [])
                self.assertEqual(trace.visits, [])

    def test_empty_snapshot_finishes_and_later_population_is_discovered(self):
        trace = self.trace([])
        self.assertIsNone(trace.dispatch(1))
        self.assertEqual(trace.checks, 0)
        trace.live.append(self.a)
        trace.dispatch(1)
        self.assertEqual(trace.visits, ["a"])

    def test_callback_deletion_and_exception_do_not_repeat_prefix(self):
        self.b.raises = True
        trace = self.trace()
        trace.callback = lambda bench: setattr(bench, "deleted", True)
        for _ in range(3):
            trace.dispatch(1)
        self.assertEqual(trace.visits, ["a", "b", "c"])
        self.assertEqual(trace.errors, ["b"])
        self.assertIsNone(trace.pending)

    def test_ephemeral_copy_control_repeats_prefix(self):
        mutant = self.source.replace("for (current in current_list)",
                                     "for (current in research_benches.Copy())")
        trace = self.trace(source=mutant)
        for _ in range(3):
            trace.dispatch(1)
        self.assertEqual(trace.visits, ["a", "a", "a"])
        self.assertEqual(trace.pending, [self.b, self.c])

    def test_audited_immutable_baseline_falsely_finishes_and_loses_tail(self):
        baseline = historical_source()
        trace = self.trace(source=baseline)
        for _ in range(3):
            self.assertIsNone(trace.dispatch(1))
            self.assertEqual(trace.last_fire_result, EARLY)
            self.assertIsNone(trace.pending)
        self.assertEqual(trace.visits, ["a", "a", "a"])

    def test_missing_consume_control_repeats_prefix(self):
        mutant = self.source.replace("\t\tPROCESS_LIST_CHECK\n", "")
        trace = self.trace(source=mutant)
        for _ in range(3):
            trace.dispatch(1)
        self.assertEqual(trace.visits, ["a", "a", "a"])

    def test_deleted_continue_control_skips_consumption_and_budget(self):
        mutant = self.source.replace("\t\t\tresearch_benches -= B\n",
                                     "\t\t\tresearch_benches -= B\n\t\t\tcontinue\n")
        trace = self.trace([Bench("dead", deleted=True), self.a], source=mutant)
        self.assertEqual(trace.dispatch(1), EARLY)
        self.assertEqual(len(trace.pending), 1)
        self.assertTrue(trace.pending[0].deleted)
        self.assertEqual(trace.visits, ["a"])

    def test_shared_semantics_and_entry_points_stay_compatible(self):
        defines = (ROOT / "code/processes/___defines.dm").read_text()
        self.assertIn("#define PROCESS_LIST_CHECK if (priority != PROCESS_PRIORITY_VERY_HIGH) current_list -= current\n", defines)
        self.assertIn("return PROCESS_TICK_CHECK_RETURNED_EARLY\n", defines)
        self.assertIn("current_list = list:Copy();", defines)
        process = (ROOT / "code/processes/_process.dm").read_text()
        for signature in ("/process/proc/process()", "/process/proc/fire_as_member()"):
            self.assertIn(". = finished(.)", proc(process, signature))
        scheduler = (ROOT / "code/processes/__processScheduler.dm").read_text()
        relay = proc(scheduler, "/processScheduler/proc/relayProcess(var/process/p, var/list/queue)")
        self.assertIn("if (isnull(p.current_list))\n\t\tp.reset_current_list()", relay)
        self.assertIn("if (p.process() != PROCESS_TICK_CHECK_RETURNED_EARLY)", relay)
        setup = proc(self.source, "/process/research_tree/setup()")
        self.assertIn("priority = PROCESS_PRIORITY_LOW", setup)


if __name__ == "__main__":
    unittest.main()
