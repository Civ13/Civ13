"""Compare projected DM bodies with fake holder boundaries; this is not native BYOND."""
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests/save_movement"))
import source_adapter

DECL = "/datum/reagents/metabolism/proc/metabolize"
BEFORE = (ROOT / "tests/reagent_metabolism/metabolize_before.dm.txt").read_text(encoding="utf-8")
AFTER = (ROOT / "code/modules/reagents/Chemistry-Metabolism.dm").read_text(encoding="utf-8")
GUARD = "\tif (islist(reagent_list) && !reagent_list.len)\n\t\ttotal_volume = 0\n\t\treturn\n\n"


class ReagentList(list):
    def Copy(self):
        return self.copy()

    @property
    def len(self):
        return len(self)


class Human:
    def __init__(self, species):
        self.species = species


class Reagent:
    def __init__(self, label, volume):
        self.label = self.id = label
        self.ingest_met = None
        self.metabolism = 2 if label == 'water' else .2
        self.volume = volume
        self.trace = []

    def on_mob_life(self, parent, tag, location, amount=None):
        self.trace.append((tag, location))
        if location == "ingest":
            amount = min(self.volume, self.metabolism if amount is None else amount)
            self.holder.bite_trace.append((self.id, amount, self.holder.ingest_brine))
            self.volume -= amount
            self.holder.prune_trace()
        else:
            self.volume -= .25


class Holder:
    def __init__(self, reagents, total, parent):
        self.reagent_list = reagents
        self.total_volume = total
        self.parent = parent
        self.metabolism_class = "blood"
        self.updates = 0
        self.ingest_brine = None
        self.bite_trace = []
        for reagent in reagents or []:
            reagent.holder = self

    def get_reagent_amount(self, label):
        return next((r.volume for r in self.reagent_list if r.id == label), 0)

    def prune_trace(self):
        self.reagent_list[:] = [r for r in self.reagent_list if r.volume >= .01]

    def update_total(self):
        # Fake boundary for the current source: empty/null holder sets zero;
        # nonempty holder removes trace volume and sums the rest.
        self.updates += 1
        self.total_volume = 0
        for reagent in list(self.reagent_list or []):
            if reagent.volume < .01:
                self.reagent_list.remove(reagent)
            else:
                self.total_volume += reagent.volume


def run(source, values, total, parent, *, location="blood", ticks=1, trace=False):
    reagents = None if values is None else ReagentList(Reagent(*item) for item in values)
    holder = Holder(reagents, total, parent)
    holder.metabolism_class = location
    env = {"ishuman": lambda value: isinstance(value, Human),
           "islist": lambda value: isinstance(value, list),
           "typed_iter": lambda value, path: list(value or []),
           "CHEM_INGEST": "ingest",
           "MINIMUM_CHEMICAL_VOLUME": .01,
           "reagents_are_brine": lambda holder, water, tolerance:
               water > 0 and holder.get_reagent_amount("sodiumchloride") + tolerance >= water * .03}
    fields = source_adapter.FIELDS
    try:
        source_adapter.FIELDS = fields + ("parent", "reagent_list", "total_volume", "metabolism_class", "update_total",
                                          "ingest_brine", "get_reagent_amount")
        proc = source_adapter.project(source, DECL, "src", env, method=True)
    finally:
        source_adapter.FIELDS = fields
    for _ in range(ticks):
        result = proc(holder)
    if trace:
        return holder
    remaining = None if holder.reagent_list is None else [(r.label, r.volume, r.trace) for r in holder.reagent_list]
    return result, holder.total_volume, remaining, holder.updates


class EmptyMetabolismTests(unittest.TestCase):
    def test_empty_and_null_holders_preserve_totals(self):
        parent = Human(SimpleNamespace(reagent_tag="human"))
        for values in ([], None):
            for total in (0, 12):
                with self.subTest(values=values, total=total):
                    old = run(BEFORE, values, total, parent)
                    new = run(AFTER, values, total, parent)
                    self.assertEqual(old[:3], new[:3])
                    self.assertEqual(new[1], 0)
                    self.assertEqual(new[3], 0 if values == [] else 1)

    def test_nonempty_reagents_keep_callbacks_and_recount(self):
        parent = Human(SimpleNamespace(reagent_tag="human"))
        values = [("kept", 1), ("trace", .251)]
        old = run(BEFORE, values, 99, parent)
        new = run(AFTER, values, 99, parent)
        self.assertEqual(old, new)
        self.assertEqual(new[1], .75)
        self.assertEqual(new[2], [("kept", .75, [("human", "blood")])])
        self.assertEqual(new[3], 1)

    def test_missing_species_still_errors_before_empty_guard(self):
        for source in (BEFORE, AFTER):
            with self.assertRaises(AttributeError):
                run(source, [], 9, Human(None))

    def test_negative_control_detects_guard_before_species_lookup(self):
        self.assertEqual(AFTER.count(GUARD), 1)
        wrong = AFTER.replace(GUARD, "", 1)
        marker = "\tvar/metabolism_type = FALSE //non-human mobs\n"
        self.assertEqual(wrong.count(marker), 1)
        wrong = wrong.replace(marker, GUARD + marker, 1)
        with self.assertRaises(AttributeError):
            run(BEFORE, [], 9, Human(None))
        self.assertEqual(run(wrong, [], 9, Human(None))[1], 0)

    def test_seawater_and_boundary_keep_composition_in_either_order(self):
        parent = Human(SimpleNamespace(reagent_tag="human"))
        for salt, water in ((1, 24), (.75, 25), (.065, 2.15)):
            for order in ([("sodiumchloride", salt), ("water", water)],
                          [("water", water), ("sodiumchloride", salt)]):
                with self.subTest(order=order):
                    holder = run(AFTER, order, salt + water, parent, location="ingest", ticks=20, trace=True)
                    self.assertFalse(holder.total_volume)
                    self.assertIsNone(holder.ingest_brine)
                    for reagent, total in order:
                        doses = [a for r, a, brine in holder.bite_trace if r == reagent and brine is True]
                        self.assertAlmostEqual(sum(doses), total)

    def test_fresh_lightly_salted_and_dry_salt_take_normal_paths(self):
        parent = Human(SimpleNamespace(reagent_tag="human"))
        for contents in ([("water", 24)], [("sodiumchloride", .5), ("water", 24)], [("sodiumchloride", .5)]):
            holder = run(AFTER, contents, 99, parent, location="ingest", ticks=16, trace=True)
            self.assertTrue(holder.bite_trace)
            self.assertTrue(all(brine is False for _, _, brine in holder.bite_trace))

    def test_water_effect_reuses_snapshot_and_standalone_fallback(self):
        core = (ROOT / "code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Core.dm").read_text()
        source = core.split("/datum/reagent/water/affect_ingest(", 1)[1].split("\n/", 1)[0]
        self.assertIn('id == "water" && istype(stomach)', source)
        self.assertIn("!isnull(stomach.ingest_brine) ? stomach.ingest_brine : reagents_are_brine(holder, volume)", source)
        self.assertLess(source.index("brine_nausea(M)"), source.index("..()"))


if __name__ == "__main__":
    unittest.main()
