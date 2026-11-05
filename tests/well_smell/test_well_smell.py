"""Offline source projection; no BYOND world or real senses are simulated."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
TEXT = (ROOT / "code/game/objects/structures/watercloset.dm").read_text(encoding="utf-8")
WASTE = (ROOT / "code/game/mob/living/carbon/human/shit_piss.dm").read_text(encoding="utf-8")


def body(source, header):
    """Return the indented body of one top-level DM proc."""
    rest = source.split(header, 1)[1]
    lines = []
    for line in rest.splitlines()[1:]:
        if line and not line.startswith(("\t", " ")):
            break
        lines.append(line)
    return "\n".join(lines)


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


class PlumbedToiletContract(unittest.TestCase):
    def test_only_primitive_toilets_are_unplumbed(self):
        expected = {
            "/obj/structure/toilet/proc/is_plumbed()": "return TRUE",
            "/obj/structure/toilet/pit_latrine/is_plumbed()": "return FALSE",
            "/obj/structure/toilet/pit_latrine/floorgrate/is_plumbed()": "return TRUE",
            "/obj/structure/toilet/outhouse/is_plumbed()": "return FALSE",
        }
        for header, result in expected.items():
            with self.subTest(header=header):
                self.assertEqual(body(TEXT, header).strip(), result)

    def test_well_draw_uses_plumbing_aware_scan(self):
        draw = TEXT.split("if (istype(src, /obj/structure/sink/well) || istype(src, /obj/structure/sink/puddle))", 1)[1]
        draw = draw.split("RG.reagents.add_reagent(\"cholera\"", 1)[0]
        self.assertIn("if (has_nearby_fecal_waste())", draw)
        self.assertNotIn("range(", draw)

    def test_scan_skips_compost_and_plumbed_tiles_only(self):
        scan = body(TEXT, "/obj/structure/sink/proc/has_nearby_fecal_waste()")
        self.assertIn("in range(4,src)", scan)
        self.assertIn("/poo/fertilizer)", scan)
        self.assertIn("for (var/obj/structure/toilet/T in PP.loc)", scan)
        self.assertIn("if (T.is_plumbed())", scan)
        self.assertIn("if (!plumbed)\n\t\t\treturn TRUE", scan)
        self.assertTrue(scan.rstrip().endswith("return FALSE"))

    def test_plumbed_toilet_flushes_waste(self):
        loo = WASTE.split("//Poo in the loo.", 1)[1].split("else if(w_uniform)", 1)[0]
        self.assertIn("if (!in_outhouse && T.is_plumbed())\n\t\t\tqdel(V)", loo)
        self.assertIn("else if (!in_outhouse)\n\t\t\tV.forceMove(T)", loo)

    def test_outhouse_is_detected_by_location(self):
        # crap_inside is set only for mobs with a client and can go stale, and
        # a null tile mob used to runtime here, so emotes must not depend on it.
        for proc in ("/mob/living/human/proc/handle_shit()", "/mob/living/human/proc/handle_piss()"):
            code = body(WASTE, proc)
            self.assertIn("var/in_outhouse = istype(loc, /obj/structure/toilet/outhouse)", code)
            self.assertNotIn("crap_inside", code)


if __name__ == "__main__":
    unittest.main()
