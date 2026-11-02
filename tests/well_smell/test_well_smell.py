"""Offline source projection; no BYOND world or real senses are simulated."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
TEXT = (ROOT / "code/game/objects/structures/watercloset.dm").read_text(encoding="utf-8")


def project(source=TEXT, **state):
    """Evaluate each actual production predicate using synthetic observations."""
    start = source.index("/obj/structure/sink/well/proc/has_observable_fecal_odor(")
    line = source[start:].splitlines()[1].strip()
    assert line.startswith("return "), line
    clauses = line[7:].split(" && ")
    values = {
        "dirty": state.get("dirty", False),
        "isliving(user)": state.get("living", True),
        "isturf(loc)": state.get("well_on_turf", True),
        "isturf(user.loc)": state.get("actor_on_turf", True),
        "user.z == z": state.get("same_z", True),
        "get_dist(src, user) <= 1": state.get("near", True),
    }
    assert set(clauses) == set(values), clauses
    return all(values[clause] for clause in clauses)


class WellSmellContract(unittest.TestCase):
    def test_fecal_flag_near_living_observer_has_cue(self):
        self.assertTrue(project(dirty=True))

    def test_clean_or_not_reachable_has_no_cue(self):
        self.assertFalse(project())
        # Nearby waste alone is not the sticky dirty state until a draw observes it.
        self.assertFalse(project(nearby_waste=True))
        for condition in ("living", "well_on_turf", "actor_on_turf", "same_z", "near"):
            with self.subTest(condition=condition):
                self.assertFalse(project(dirty=True, **{condition: False}))

    def test_mutation_removing_each_scope_guard_is_detected(self):
        start = TEXT.index("/obj/structure/sink/well/proc/has_observable_fecal_odor(")
        for clause in ("dirty && ", " && isliving(user)", " && isturf(loc)",
                       " && isturf(user.loc)", " && user.z == z", " && get_dist(src, user) <= 1"):
            with self.subTest(clause=clause):
                altered = TEXT[:start] + TEXT[start:].replace(clause, "", 1)
                self.assertNotEqual(altered, TEXT)
                with self.assertRaises(AssertionError):
                    project(source=altered, dirty=True)

    def test_parent_examine_and_flag_only_no_safety_claim(self):
        section = TEXT.split("/obj/structure/sink/well/examine(mob/user, distance = -1)", 1)[1].split("\n/obj/", 1)[0]
        self.assertIn(". = ..()", section)
        self.assertIn("if (. && has_observable_fecal_odor(user))", section)
        self.assertIn("A foul smell rises from the well.", section)
        for unsupported in ("safe", "cholera", "radiation", "reagents"):
            self.assertNotIn(unsupported, section.lower())


if __name__ == "__main__":
    unittest.main()
