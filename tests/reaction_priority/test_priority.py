"""Offline source projection with fake chemistry boundaries, not a BYOND runtime."""
from collections import defaultdict
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests/save_movement"))
import source_adapter

DECL = "/datum/reagents/proc/process_reactions"
BEFORE = (ROOT / "tests/reaction_priority/before.dm.txt").read_text(encoding="utf-8")
AFTER = (ROOT / "code/modules/reagents/Chemistry-Holder.dm").read_text(encoding="utf-8")
GUARD = "\t\tif (!eligible_reactions.len)\n\t\t\tbreak\n"

class DMList(list):
    @property
    def len(self):
        return len(self)

    def __ior__(self, values):
        if values is None:
            return self
        if not isinstance(values, (list, tuple)):
            values = [values]
        for value in values:
            if value not in self:
                self.append(value)
        return self

    def Cut(self):
        self.clear()

class Reaction:
    def __init__(self, label, priority, can=True, outcome=False, replace=None):
        self.label, self.priority, self.can, self.outcome, self.replace = label, priority, can, outcome, replace

    def can_happen(self, holder):
        holder.trace.append(("can", self.label))
        return self.can

    def process(self, holder):
        holder.trace.append(("process", self.label))
        if self.replace is not None:
            holder.reagent_list = DMList(SimpleNamespace(id=x) for x in self.replace)
        return self.outcome

    def post_reaction(self, holder):
        holder.trace.append(("post", self.label))

class Holder:
    def __init__(self, ids, atom):
        self.reagent_list = DMList(SimpleNamespace(id=x) for x in ids)
        self.my_atom = atom
        self.trace = []

    def update_total(self):
        self.trace.append(("update_total", tuple(r.id for r in self.reagent_list)))

def execute(source, ids, specifications, atom="normal"):
    calls = []
    def dm_list(*items):
        calls.append("list")
        return DMList(items)
    index = defaultdict(lambda: None)
    for reagent_id, reactions in specifications.items():
        index[reagent_id] = DMList(Reaction(*reaction) if isinstance(reaction, tuple) else reaction for reaction in reactions)
    holder = Holder(ids, None if atom == "missing" else SimpleNamespace(loc=atom != "unlocated", flags=1 if atom == "noreact" else 0))
    source = source.replace("for (var/i in TRUE to PROCESS_REACTION_ITER)", "for (i in dm_range(TRUE, PROCESS_REACTION_ITER))")
    source = source.replace("var/reaction_occured\n", "var/reaction_occured = null\n")
    source = source.replace("list()", "dm_list()").replace("list(C)", "dm_list(C)")
    env = {"chemical_reactions_list": index, "PROCESS_REACTION_ITER": 5, "NOREACT": 1,
           "dm_range": lambda first, last: range(first, last + 1), "dm_list": dm_list,
           "typed_iter": lambda values, path: [v for v in (values or []) if isinstance(v, Reaction) or (path == "/datum/reagent" and isinstance(v, SimpleNamespace))]}
    fields = source_adapter.FIELDS
    try:
        source_adapter.FIELDS = fields + ("my_atom", "reagent_list", "update_total")
        proc = source_adapter.project(source, DECL, "src", env, method=True)
    finally:
        source_adapter.FIELDS = fields
    result = proc(holder)
    return result, holder.trace, len(calls)

class ReactionPriorityTests(unittest.TestCase):
    def compare(self, ids, specs, atom="normal"):
        before = execute(BEFORE, ids, specs, atom)
        after = execute(AFTER, ids, specs, atom)
        self.assertEqual(before[:2], after[:2])
        return before, after

    def test_no_candidates_and_inactive_guards(self):
        before, after = self.compare(["water"], {})
        self.assertEqual(after[:2], (False, [("update_total", ("water",))]))
        self.assertEqual(before[2] - after[2], 1)
        for atom in ("missing", "unlocated", "noreact"):
            with self.subTest(atom=atom):
                before, after = self.compare(["water"], {}, atom)
                self.assertEqual(after, (False, [], 0))
                self.assertEqual(before, after)

    def test_eligible_but_impossible_and_priority_order(self):
        for specs in ({"a": [("no", 1, False, False, None)]},
                      {"a": [("low", 1, True, False, None), ("high", 2, True, False, None)]},
                      {"a": [("first", 2, True, False, None), ("second", 2, True, False, None)]}):
            with self.subTest(specs=specs):
                before, after = self.compare(["a"], specs)
                self.assertEqual(before[2], after[2])

    def test_nonreaction_candidate_and_iteration_cap(self):
        # A non-reaction value has length, so the guard must not skip its pass.
        before, after = self.compare(["a"], {"a": ["not a reaction"]})
        self.assertEqual(after[:2], (False, [("update_total", ("a",))]))
        self.assertEqual(before[2], after[2])
        # Reactions that keep succeeding still run the existing five-pass cap.
        before, after = self.compare(["a"], {"a": [("repeat", 1, True, True, None)]})
        self.assertTrue(after[0])
        self.assertEqual(sum(event == ("process", "repeat") for event in after[1]), 5)
        self.assertEqual(sum(event == ("post", "repeat") for event in after[1]), 1)
        self.assertEqual(before[2], after[2])

    def test_reaction_then_empty_still_posts_and_updates(self):
        specs = {"a": [("consume", 1, True, True, ["water"])]}
        before, after = self.compare(["a"], specs)
        self.assertEqual(after[:2], (False, [("can", "consume"), ("process", "consume"),
                         ("post", "consume"), ("update_total", ("water",))]))
        self.assertEqual(before[2] - after[2], 1)

    def test_empty_return_mutation_loses_final_callbacks(self):
        self.assertEqual(AFTER.count(GUARD), 1)
        wrong = AFTER.replace(GUARD, "\t\tif (!eligible_reactions.len)\n\t\t\treturn FALSE\n", 1)
        specs = {"a": [("consume", 1, True, True, ["water"])]}
        self.assertNotEqual(execute(BEFORE, ["a"], specs)[:2], execute(wrong, ["a"], specs)[:2])

if __name__ == "__main__":
    unittest.main()
