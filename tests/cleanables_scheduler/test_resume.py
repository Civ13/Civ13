"""Offline source-derived phase traces; native iteration/qdel remain unverified."""
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
BASE = "9db2b2f42a5fbbb0bdd49d50a2672da6111a7709"
EARLY = 1234


def body(source, signature):
    match = re.search(r"^" + re.escape(signature) + r"\n(.*?)(?=^/|\Z)", source, re.M | re.S)
    if not match:
        raise ValueError(signature)
    return match.group(1)


def translate(source):
    operations = {
        "if (!deleting)": "if not ctx.deleting:",
        "for (current in current_list)": "for ctx.current in ctx.pending.copy():",
        "var/obj/effect/decal/cleanable/C = current": "C = ctx.current; ctx.visits.append(C)",
        "if (!isDeleted(C))": "if not retired(C):",
        "if (!turf2cleanables[C.loc])": "if not ctx.counts.get(C.loc):",
        "turf2cleanables[C.loc] = 0": "ctx.counts[C.loc] = 0",
        "++turf2cleanables[C.loc]": "ctx.counts[C.loc] += 1",
        "else": "else:",
        "catchBadType(C)": "pass",
        "cleanables -= C": "ctx.remove(ctx.live, C)",
        "PROCESS_LIST_CHECK": "ctx.remove(ctx.pending, ctx.current)",
        "if (!current_list.len)": "if not ctx.pending:",
        "current_list = turf2cleanables.Copy()": "ctx.pending = list(ctx.counts)",
        "deleting = current_list.len > 0": "ctx.deleting = len(ctx.pending) > 0",
        "turf2cleanables = null": "ctx.counts = None",
        "PROCESS_TICK_CHECK": "if ctx.budget(): return EARLY",
        "return": "return",
        "var/atom/place = current": "place = ctx.current",
        "if (isDeleted(place) || turf2cleanables[place] < 2)":
            "if retired(place) or ctx.counts[place] < 2:",
        "finish_location()": "ctx.finish_location(ctx)",
        "continue": "continue",
        "if (isnull(location_contents))": "if ctx.contents is None:",
        "location_contents = place.contents.Copy()": "ctx.contents = place.contents.copy()",
        "while (location_contents.len && turf2cleanables[place] >= 2)":
            "while ctx.contents and ctx.counts[place] >= 2:",
        "var/atom/A = location_contents[1]": "A = ctx.contents[0]; ctx.candidates.append(A)",
        "location_contents -= A": "ctx.remove(ctx.contents, A)",
        "if (istype(A, /obj/effect/decal/cleanable) && !isDeleted(A) && A.loc == place)":
            "if A is not None and A.cleanable and not retired(A) and A.loc is place:",
        "if (!isDeleted(kept_cleanable) && kept_cleanable.loc == place)":
            "if not retired(ctx.kept) and ctx.kept.loc is place:",
        "cleanables -= kept_cleanable": "ctx.remove(ctx.live, ctx.kept)",
        "qdel(kept_cleanable)": "ctx.retire(ctx.kept)",
        "--turf2cleanables[place]": "ctx.counts[place] -= 1",
        "kept_cleanable = A": "ctx.kept = A",
        "if (!location_contents.len || turf2cleanables[place] < 2)":
            "if not ctx.contents or ctx.counts[place] < 2:",
        "break": "break",
        "if (!isnull(location_contents))": "if ctx.contents is not None:",
        "turf2cleanables -= current": "ctx.counts.pop(ctx.current, None)",
        "location_contents = null": "ctx.contents = None",
        "kept_cleanable = null": "ctx.kept = None",
        "deleting = FALSE": "ctx.deleting = False",
        "turf2cleanables = list()": "ctx.counts = {}",
        "PROCESS_USE_FASTEST_LIST(cleanables)": "ctx.pending = ctx.live.copy()",
        "ticks++": "pass",
        "idle()": "pass",
        "main.processFinished(src)": "pass",
        "onFinish()": "pass",
        "if (fire_result == PROCESS_TICK_CHECK_RETURNED_EARLY && !length(current_list))":
            "if fire_result == EARLY and not ctx.pending:",
        "fire_result = null": "fire_result = None",
        "if (fire_result != PROCESS_TICK_CHECK_RETURNED_EARLY || !length(current_list))":
            "if fire_result != EARLY or not ctx.pending:",
        "current = null": "ctx.current = None",
        "current_list = null": "ctx.pending = None",
        "return fire_result": "return fire_result",
        ". = ..(fire_result)": "result = ctx.shared_finish(ctx, fire_result)",
        "if (isnull(current_list))": "if ctx.pending is None:",
        # Immutable baseline vocabulary, for reproducing aggregation/tail loss.
        "var/list/turf2cleanables = list()": "ctx.counts = {}",
        "for (var/loc in turf2cleanables)": "for loc in ctx.counts.copy():",
        "if (turf2cleanables[loc] >= 2)": "if ctx.counts[loc] >= 2:",
        "var/deleted = 0": "deleted = 0",
        "for (var/obj/effect/decal/cleanable/C in loc)":
            "for C in [x for x in loc.contents.copy() if x.cleanable]:",
        "qdel(C)": "ctx.retire(C)",
        "++deleted": "deleted += 1",
        "if (deleted >= turf2cleanables[loc]-1)": "if deleted >= ctx.counts[loc] - 1:",
    }
    lines = ["def execute(ctx, fire_result=None):", "    result = None"]
    for raw in source.splitlines():
        instruction = raw.strip()
        if not instruction or instruction.startswith("//"):
            continue
        if instruction not in operations:
            raise ValueError(instruction)
        depth = len(raw) - len(raw.lstrip("\t"))
        if not depth:
            raise ValueError(raw)
        lines.append("    " * depth + operations[instruction])
    lines.append("    return result")
    namespace = {"EARLY": EARLY, "retired": retired}
    exec(compile("\n".join(lines), "<restricted cleanables source>", "exec"), namespace)
    return namespace["execute"]


def retired(atom):
    return atom is None or atom.deleted


class Atom:
    def __init__(self, name, loc=None, cleanable=False):
        self.name, self.loc, self.cleanable = name, loc, cleanable
        self.deleted = False
        self.contents = []
        if loc is not None:
            loc.contents.append(self)


class Trace:
    def __init__(self, source, live):
        self.live = live.copy()
        self.pending = self.contents = self.kept = self.counts = None
        self.current = None
        self.deleting = False
        self.visits, self.candidates, self.deletions = [], [], []
        self.fire = translate(body(source, "/process/cleanables/fire()"))
        self.reset = translate(body(source, "/process/cleanables/reset_current_list()"))
        if "/process/cleanables/proc/finish_location()" in source:
            self.finish_location = translate(body(source, "/process/cleanables/proc/finish_location()"))
        shared = (ROOT / "code/processes/_process.dm").read_text()
        self.shared_finish = translate(body(shared, "/process/proc/finished(fire_result = null)"))
        signature = "/process/cleanables/finished(fire_result = null)"
        self.finish = translate(body(source, signature)) if signature in source else self.shared_finish

    @staticmethod
    def remove(items, value):
        for i in range(len(items) - 1, -1, -1):
            if items[i] is value:
                del items[i]
                return

    def retire(self, atom):
        if retired(atom):
            raise AssertionError("duplicate/stale qdel")
        self.deletions.append(atom.name)
        atom.deleted = True
        self.remove(self.live, atom)
        if atom.loc:
            self.remove(atom.loc.contents, atom)
        atom.loc = None

    def budget(self):
        self.checks += 1
        return self.limit is not None and self.checks >= self.limit

    def dispatch(self, limit=None):
        if self.pending is None:
            self.reset(self)
        self.limit, self.checks = limit, 0
        self.last_result = self.fire(self)
        return self.finish(self, self.last_result)

    def complete(self, limit=1):
        for _ in range(100):
            result = self.dispatch(limit)
            if result != EARLY:
                return
        raise AssertionError("tail did not finish in bounded dispatch count")


class CleanablesTests(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / "code/processes/cleanables.dm").read_text()
        self.place = Atom("place")
        self.decals = [Atom(name, self.place, True) for name in "abc"]

    def assert_released(self, t):
        self.assertEqual((t.pending, t.counts, t.contents, t.kept, t.deleting),
                         (None, None, None, None, False))

    def test_one_entry_budgets_preserve_counts_tail_and_release_all_state(self):
        t = Trace(self.source, self.decals)
        for count in (1, 2, 3):
            self.assertEqual(t.dispatch(1), EARLY)
            self.assertEqual(t.counts[self.place], count)
        self.assertTrue(t.deleting)
        self.assertEqual(t.pending, [self.place])
        t.complete()
        self.assertEqual(t.visits, self.decals)
        self.assertEqual(t.deletions, ["a", "b"])
        self.assertEqual(self.place.contents, [self.decals[2]])
        self.assertEqual(t.last_result, EARLY)
        self.assert_released(t)

    def test_final_count_budget_installs_removal_work_before_return(self):
        t = Trace(self.source, self.decals)
        self.assertEqual(t.dispatch(3), EARLY)
        self.assertEqual(t.counts, {self.place: 3})
        self.assertEqual(t.pending, [self.place])
        self.assertEqual(t.deletions, [])
        t.complete()
        self.assert_released(t)

    def test_uninterrupted_locations_preserve_original_deletion_order_and_quota(self):
        other = Atom("other")
        more = [Atom(name, other, True) for name in "de"]
        t = Trace(self.source, self.decals + more)
        t.dispatch()
        self.assertEqual(t.deletions, ["a", "b", "d"])
        self.assertEqual(t.live, [self.decals[2], more[1]])
        self.assert_released(t)

    def test_pending_deletion_does_not_consume_last_survivor(self):
        t = Trace(self.source, self.decals)
        t.dispatch(3)
        t.retire(self.decals[1])
        t.complete()
        self.assertEqual(t.deletions, ["b", "a"])
        self.assertEqual(self.place.contents, [self.decals[2]])
        self.assert_released(t)

    def test_retained_survivor_deleted_between_resumes_is_revalidated(self):
        t = Trace(self.source, self.decals)
        t.dispatch(3)
        t.dispatch(1)
        self.assertIs(t.kept, self.decals[0])
        t.retire(self.decals[0])
        t.complete()
        self.assertEqual(t.deletions, ["a", "b"])
        self.assertEqual(self.place.contents, [self.decals[2]])
        self.assert_released(t)

    def test_moved_pending_candidate_is_not_deleted_at_old_location(self):
        other = Atom("other")
        t = Trace(self.source, self.decals)
        t.dispatch(3)
        t.dispatch(1)
        t.remove(self.place.contents, self.decals[1])
        self.decals[1].loc = other
        other.contents.append(self.decals[1])
        t.complete()
        self.assertEqual(t.deletions, ["a"])
        self.assertFalse(self.decals[1].deleted)
        self.assertEqual(self.place.contents, [self.decals[2]])

    def test_new_entries_wait_for_next_pass_and_original_quota_caps_deletion(self):
        t = Trace(self.source, self.decals)
        t.dispatch(3)
        added = Atom("new", self.place, True)
        t.live.append(added)
        t.complete()
        self.assertEqual(t.visits, self.decals)
        self.assertEqual(t.deletions, ["a", "b"])
        self.assertEqual(self.place.contents, [self.decals[2], added])
        t.complete()
        self.assertEqual(t.deletions, ["a", "b", "c"])
        self.assertEqual(self.place.contents, [added])

    def test_contents_added_after_location_copy_are_not_admitted_mid_pass(self):
        t = Trace(self.source, self.decals)
        t.dispatch(3)
        t.dispatch(1)
        added = Atom("new", self.place, True)
        t.live.append(added)
        t.complete()
        self.assertNotIn(added, t.candidates)
        self.assertFalse(added.deleted)

    def test_noncleanables_have_budget_checkpoints_and_are_not_deleted(self):
        extras = [Atom("object" + str(i), self.place) for i in range(4)]
        self.place.contents = extras + self.decals
        t = Trace(self.source, self.decals)
        t.dispatch(3)
        for extra in extras:
            self.assertEqual(t.dispatch(1), EARLY)
            self.assertIs(t.candidates[-1], extra)
            self.assertEqual(t.deletions, [])
        t.complete()
        self.assertTrue(all(not x.deleted for x in extras))
        self.assert_released(t)

    def test_empty_and_all_deleted_snapshots_release_without_cleanup_phase(self):
        for entries in ([], [None], [Atom("dead", cleanable=True)]):
            if entries and entries[0] is not None:
                entries[0].deleted = True
            t = Trace(self.source, entries)
            self.assertIsNone(t.dispatch(1))
            self.assertEqual(t.deletions, [])
            self.assert_released(t)

    def test_destroyed_pending_location_is_consumed_without_deleting_contents(self):
        t = Trace(self.source, self.decals)
        t.dispatch(3)
        self.place.deleted = True
        t.complete()
        self.assertEqual(t.deletions, [])
        self.assert_released(t)

    def test_normal_finish_cancels_both_partial_phases_and_releases_references(self):
        for phase in ("count", "delete"):
            with self.subTest(phase=phase):
                t = Trace(self.source, self.decals)
                t.dispatch(1 if phase == "count" else 3)
                if phase == "delete":
                    t.dispatch(1)
                    self.assertIs(t.kept, self.decals[0])
                t.finish(t)
                self.assert_released(t)
                self.assertEqual(t.deletions, [])

    def test_audited_baseline_loses_aggregate_across_budget_returns(self):
        old = subprocess.check_output(["git", "show", BASE + ":code/processes/cleanables.dm"], cwd=ROOT, text=True)
        t = Trace(old, self.decals)
        t.complete()
        self.assertEqual(t.visits, self.decals)
        self.assertEqual(t.deletions, [])
        self.assertEqual(t.counts, {self.place: 1})
        self.assertEqual(self.place.contents, self.decals)

    def test_reset_aggregate_mutant_loses_counts_without_runtime_error(self):
        mutant = self.source.replace("\tif (!deleting)\n", "\tif (!deleting)\n\t\tturf2cleanables = list()\n", 1)
        t = Trace(mutant, self.decals)
        t.complete()
        self.assertEqual(t.deletions, [])
        self.assertEqual(self.place.contents, self.decals)
        self.assert_released(t)

    def test_late_phase_transition_mutant_drops_cleanup_at_final_count_budget(self):
        mutant = self.source.replace("\t\t\t// Install deletion work before a final-entry budget return.\n", "\t\t\tPROCESS_TICK_CHECK\n")
        mutant = mutant.replace("\t\t\t\t\tturf2cleanables = null\n\t\t\tPROCESS_TICK_CHECK", "\t\t\t\t\tturf2cleanables = null")
        t = Trace(mutant, self.decals)
        self.assertIsNone(t.dispatch(3))
        self.assertIsNone(t.pending)
        self.assertFalse(t.deleting)
        self.assertEqual(t.deletions, [])
        self.assertIsNone(t.counts)


if __name__ == "__main__":
    unittest.main()
