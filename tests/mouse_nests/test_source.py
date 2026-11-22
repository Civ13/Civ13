"""Source contracts for the mouse rework: rot creates no pests, mice are timid."""
from pathlib import Path
import re
import zlib
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def block(source, header):
    """Text of one DM proc/type block: from its header to the next top-level line."""
    start = source.index(header)
    rest = source[start + len(header):]
    match = re.search(r"\n(?=/[a-z])", rest)
    return header + (rest[:match.start()] if match else rest)


PEST_SPAWN = re.compile(r"new\s*/mob/living/simple_animal/(mouse|cockroach|fly)\b")


class RotSpawnsNothing(unittest.TestCase):
    def test_food_rot_creates_no_pests(self):
        rot = block(read("code/modules/reagents/reagent_containers/food.dm"), "/obj/item/weapon/reagent_containers/food/proc/rot()")
        self.assertIsNone(PEST_SPAWN.search(rot))

    def test_chicken_carcass_creates_no_pests(self):
        source = read("code/modules/1713/complex_production.dm")
        self.assertIsNone(PEST_SPAWN.search(source))

    def test_cockroaches_are_short_lived(self):
        source = read("code/game/mob/living/simple_animal/friendly/cockroach.dm")
        life = block(source, "/mob/living/simple_animal/cockroach/New()")
        self.assertIn("PROC_REF(expire)), 10 MINUTES", life)
        self.assertIn("qdel(src)", block(source, "/mob/living/simple_animal/cockroach/proc/expire()"))


class TimidMouse(unittest.TestCase):
    def setUp(self):
        self.source = read("code/game/mob/living/simple_animal/friendly/mouse.dm")

    def test_mouse_never_attacks(self):
        base = block(self.source, "/mob/living/simple_animal/mouse\n")
        self.assertIn('behaviour = "scared"', base)
        self.assertIn("melee_damage_upper = 0", base)
        crossed = block(self.source, "/mob/living/simple_animal/mouse/Crossed(")
        self.assertNotIn("HOSTILE_STANCE", crossed)
        self.assertNotIn("npc_set_combat_target", crossed)

    def test_no_contact_or_birth_plague(self):
        crossed = block(self.source, "/mob/living/simple_animal/mouse/Crossed(")
        self.assertNotIn("disease", crossed)
        birth = block(self.source, "/mob/living/simple_animal/mouse/New()")
        self.assertNotIn("plaguemouse = TRUE", birth)

    def test_mice_eat_only_through_their_nest(self):
        base = block(self.source, "/mob/living/simple_animal/mouse\n")
        self.assertIn("granivore = 0", base)
        self.assertIn("scavenger = 0", base)

    def test_clay_jars_keep_mice_out(self):
        nests = read("code/modules/ecology/mouse_nests.dm")
        self.assertIn("/obj/structure/storage_container/storage_jar\n\trodent_access = RODENT_PROOF", nests)

    def test_butchering_gives_plain_meat(self):
        harvest = block(self.source, "/mob/living/simple_animal/mouse/harvest_products(")
        self.assertNotIn("meat/human", harvest)
        self.assertIn("/obj/item/weapon/reagent_containers/food/snacks/meat,", harvest)


class NestsAreTheSource(unittest.TestCase):
    def test_ecology_cycle_places_burrows(self):
        cycle = block(read("code/modules/ecology/ecology_spawning.dm"), "/datum/ecology_spawner/proc/cycle()")
        self.assertIn("mouse_burrow_cycle()", cycle)

    def test_process_settles_a_few_nests_per_fire(self):
        process = read("code/processes/mouse_nests.dm")
        self.assertIn("#define MOUSE_PROCESS_SETTLES 2", process)
        self.assertIn("schedule_interval = 10 SECONDS", process)

    def test_emitted_mice_are_not_saved(self):
        nests = read("code/modules/ecology/mouse_nests.dm")
        self.assertIn("should_save = FALSE // the nest's population already counts this mouse", nests)
        self.assertIn('return key == "out_mice" || key == "scan_traps" || key == "scan_baits" || ..()', nests)

    def test_nest_sprites_exist(self):
        data = (ROOT / "icons/obj/mouse_nests.dmi").read_bytes()
        start = data.index(b"zTXtDescription\x00\x00") + len(b"zTXtDescription\x00\x00")
        length = int.from_bytes(data[start - len(b"zTXtDescription\x00\x00") - 4:start - len(b"zTXtDescription\x00\x00")], "big")
        meta = zlib.decompress(data[start:start - len(b"Description\x00\x00") + length]).decode()
        for state in ("burrow", "nest_light", "nest_used", "nest_overrun"):
            self.assertIn(f'state = "{state}"', meta)



class CrowdingProjection(unittest.TestCase):
    """Project the non-yielding DM site guard into a bounded offline model."""

    @staticmethod
    def project(source):
        body = block(source, "/proc/mouse_nest_site_error(turf/T)").splitlines()[1:]
        translations = {
            "if (!mouse_nest_floor_ok(T))": "if not T.floor:",
            'return "floor"': 'return "floor"',
            "if (turf_is_above_ground(T))": "if T.upstairs:",
            'return "upstairs"': 'return "upstairs"',
            "if (locate(/obj/structure/mouse_nest) in T)": "if T.has_nest:",
            'return "nest"': 'return "nest"',
            "for (var/atom/movable/A in T)": "for A in T.contents:",
            "if (A.density)": "if A.density:",
            'return "blocked"': 'return "blocked"',
            "var/near = 0": "near = 0",
            "for (var/obj/structure/mouse_nest/N in mouse_nest_list)": "for N in nests:",
            "if (N.z == T.z && get_dist(N, T) <= MOUSE_NEST_CROWD_RANGE)": "if N.z == T.z and distance(N, T) <= 15:",
            "near++": "near += 1",
            "if (near >= MOUSE_NEST_CROWD)": "if near >= 3:",
            "if (near > MOUSE_NEST_CROWD)": "if near > 3:",
            'return "crowded"': 'return "crowded"',
            "if (ecology_visible_to_players(T, 7))": "if visible(T):",
            'return "seen"': 'return "seen"',
            "return null": "return None",
        }
        lines = ["def run(T, nests, distance, visible):"]
        for line in body:
            code = line.strip().split(" //", 1)[0]
            if not code or code.startswith("//"):
                continue
            if code not in translations:
                raise AssertionError(f"unrecognized site guard: {code}")
            lines.append("    " * (len(line) - len(line.lstrip("\t"))) + translations[code])
        namespace = {}
        exec("\n".join(lines), namespace)
        return namespace["run"]

    def test_site_guard_matches_full_count_and_skips_remaining_work(self):
        from types import SimpleNamespace as Obj
        source = read("code/modules/ecology/mouse_nests.dm")
        self.assertIn("#define MOUSE_NEST_CROWD 3", source)
        self.assertIn("#define MOUSE_NEST_CROWD_RANGE 15", source)
        run = self.project(source)
        def target(**values):
            defaults = dict(floor=True, upstairs=False, has_nest=False,
                            contents=[], z=1, seen=False)
            defaults.update(values)
            return Obj(**defaults)
        def nest(z=1, distance=1):
            return Obj(z=z, distance=distance)
        def reference(T, nests):
            if not T.floor: return "floor"
            if T.upstairs: return "upstairs"
            if T.has_nest: return "nest"
            if any(A.density for A in T.contents): return "blocked"
            near = sum(N.z == T.z and N.distance <= 15 for N in nests)
            if near >= 3: return "crowded"
            return "seen" if T.seen else None
        cases = [
            (target(), []), (target(), [nest(), nest()]),
            (target(), [nest(), nest(), nest()]),
            (target(), [nest(), nest(), nest(), nest()]),
            (target(), [nest(), nest(), nest(z=2), nest(distance=16)]),
            (target(seen=True), [nest(), nest()]),
            (target(seen=True), [nest(), nest(), nest()]),
            (target(floor=False, upstairs=True, has_nest=True), [nest()] * 4),
            (target(upstairs=True, has_nest=True), [nest()] * 4),
            (target(has_nest=True, contents=[Obj(density=True)]), [nest()] * 4),
            (target(contents=[Obj(density=True)]), [nest()] * 4),
        ]
        def invoke(fn, T, nests):
            calls = []
            def distance(N, unused):
                calls.append("distance")
                return N.distance
            def visible(unused):
                calls.append("visible")
                return T.seen
            return fn(T, nests, distance, visible), calls
        for T, nests in cases:
            actual, calls = invoke(run, T, nests)
            self.assertEqual(actual, reference(T, nests))
            if actual in {"floor", "upstairs", "nest", "blocked"}:
                self.assertEqual(calls, [])
            elif actual == "crowded":
                self.assertNotIn("visible", calls)
            else:
                self.assertEqual(calls[-1], "visible")
        self.assertEqual(invoke(run, target(), [nest()] * 4)[1], ["distance"] * 3)
        mutant = source.replace("if (near >= MOUSE_NEST_CROWD)",
                                "if (near > MOUSE_NEST_CROWD)", 1)
        self.assertNotEqual(mutant, source)
        mutant_run = self.project(mutant)
        T, nests = target(), [nest()] * 3
        self.assertNotEqual(invoke(mutant_run, T, nests)[0], reference(T, nests))


if __name__ == "__main__":
    unittest.main()
