"""Production reconciliation bodies with explicit terrain/list/epoch adapters."""
import ast
from pathlib import Path
import re
import unittest

from test_flow import ROOT, META, body, defaults, supported, project as next_phase

FOREST = "/area/caribbean/nomads/forest"
DESERT = "/area/caribbean/nomads/desert"
ROOFED = "/area/caribbean/roofed"
DIRT = "/turf/floor/dirt"
GRASS = "/turf/floor/grass"
WATER = "/turf/floor/beach/water"
SINK = "/obj/structure/sink"
SNOW = ("/obj/structure/window/barrier/snowwall", "/obj/covers/snow_wall", "/obj/item/weapon/snowwall")


def subtype(value, root):
    return value == root or value.startswith(root + "/")


def project_proc(source, signature):
    instructions = {
        "var/season_work = 0": "season_work = 0",
        "for (var/turf/T in get_area_turfs(area_type, null, old_type, src, epoch))":
            "for T in world.area_candidates(area_type, old_type):",
        "if (!season_work_pause(epoch, ++season_work))":
            ("season_work += 1", "if not self.pause(epoch, season_work):"),
        "return FALSE": "return False",
        "return TRUE": "return True",
        "if (!season_candidate_valid(T, old_type))": "if not self.candidate(T, old_type):",
        "continue": "continue",
        "var/area/A = get_area(T)": "A = T.area",
        "if ((climate && A.climate != climate) || (upper_only && T.z <= 1))":
            "if (climate and A.climate != climate) or (upper_only and T.z <= 1):",
        "T.ChangeTurf(new_type)": "T.replace(new_type)",
        "return season_worker_valid(epoch)": "return self.valid(epoch)",
        "for (var/list/change in changes)": "for change in changes:",
        "if (!season_replace_terrain(change[1], change[2], change[3], epoch, change[4]))":
            "if not self.replace(change[0], change[1], change[2], epoch, change[3]):",
        "for (var/snow_type in list(/obj/structure/window/barrier/snowwall, /obj/covers/snow_wall, /obj/item/weapon/snowwall))":
            "for snow_type in SNOW:",
        "for (var/obj/S in season_world_candidates(snow_type, epoch))": "for S in world.candidates(snow_type):",
        "if (!season_candidate_valid(S, snow_type))": "if not self.candidate(S, snow_type):",
        "var/area/A = get_area(S)": "A = S.area",
        'if (A.climate != "tundra" && A.climate != "taiga")': 'if A.climate not in ("tundra", "taiga"):',
        "qdel(S)": "S.retire()",
        'var/wet = next_phase == "SPRING"': 'wet = next_phase == "SPRING"',
        "for (var/obj/structure/sink/S in season_world_candidates(/obj/structure/sink, epoch))": "for S in world.candidates(SINK):",
        "if (!season_candidate_valid(S, /obj/structure/sink))": "if not self.candidate(S, SINK):",
        "if (!istype(S, /obj/structure/sink/well) && !istype(S, /obj/structure/sink/puddle))":
            'if not subtype(S.kind, SINK + "/well") and not subtype(S.kind, SINK + "/puddle"):',
        "if (!wet && !istype(get_area(S), /area/caribbean/nomads/desert))": "if not wet and not subtype(S.area.kind, DESERT):",
        "S.dry = !wet": "S.dry = not wet",
        "S.update_icon()": "S.updates += 1",
        "var/list/changes": "changes = None",
        "if (wet)": "if wet:",
        "else": "else:",
        "if (!season_replace_terrain(change[1], change[2], change[3], epoch, null, !wet))":
            "if not self.replace(change[0], change[1], change[2], epoch, None, not wet):",
        "if (!season_worker_valid(epoch) || !season_edge_supported(previous_phase, next_phase))":
            "if not self.valid(epoch) or not self.supported(previous_phase, next_phase):",
        "if (season_edge_is_default(previous_phase, next_phase))": "if self.defaults.get(previous_phase) == next_phase:",
        "if (!season_reconcile_warm(epoch))": "if not self.warm(epoch):",
        "return season_reconcile_water(next_phase, epoch)": "return self.water(next_phase, epoch)",
        # Actual Asia completion body; only the parent no-op is adapted.
        "..(epoch)": "pass",
        "if (!season_worker_valid(epoch))": "if not self.valid(epoch):",
        "return": "return",
        'if (season ==  "SUMMER" || season == "FALL")': 'if self.season in ("SUMMER", "FALL"):',
        "for (var/turf/floor/beach/water/flooded/DF in season_world_candidates(/turf/floor/beach/water/flooded, epoch))":
            'for DF in world.candidates(WATER + "/flooded"):',
        "if (!season_candidate_valid(DF, /turf/floor/beach/water/flooded))":
            'if not self.candidate(DF, WATER + "/flooded"):',
        "DF.ChangeTurf(/turf/floor/dirt/flooded)": 'DF.replace(DIRT + "/flooded")',
        "for (var/turf/floor/dirt/flooded/DF in season_world_candidates(/turf/floor/dirt/flooded, epoch))":
            'for DF in world.candidates(DIRT + "/flooded"):',
        "if (!season_candidate_valid(DF, /turf/floor/dirt/flooded))": 'if not self.candidate(DF, DIRT + "/flooded"):',
        "DF.ChangeTurf(/turf/floor/beach/water/flooded)": 'DF.replace(WATER + "/flooded")',
    }
    raw_lines = body(source, signature).splitlines()
    lines = ["def execute(self, world, epoch, previous_phase=None, next_phase=None, area_type=None, old_type=None, new_type=None, climate=None, upper_only=False):"]
    i = 0
    while i < len(raw_lines):
        raw = raw_lines[i].split("//", 1)[0].rstrip()
        i += 1
        if not raw.strip():
            continue
        depth = len(raw) - len(raw.lstrip("\t"))
        code = raw.strip()
        if code in ("var/list/changes = list(", "changes = list("):
            rows = []
            while i < len(raw_lines) and raw_lines[i].strip().startswith("list("):
                entry = raw_lines[i].strip()
                i += 1
                args = entry[5:entry.index(")")].split(", ")
                row = []
                for token in args:
                    if token.startswith("/"):
                        row.append(token)
                    elif token == "null":
                        row.append(None)
                    else:
                        row.append(ast.literal_eval(token))
                rows.append(row)
            translated = "changes = " + repr(rows)
        else:
            translated = instructions[code]
        for line in (translated if isinstance(translated, tuple) else (translated,)):
            lines.append("    " * depth + line)
    env = dict(SNOW=SNOW, SINK=SINK, DESERT=DESERT, WATER=WATER, DIRT=DIRT, subtype=subtype)
    exec("\n".join(lines), env)
    return env["execute"]


class Area:
    def __init__(self, kind, climate="temperate"):
        self.kind, self.climate = kind, climate


class Atom:
    def __init__(self, world, name, kind, area, z=1, dry=False):
        self.world, self.name, self.kind, self.area, self.z = world, name, kind, area, z
        self.dry, self.updates, self.dead = dry, 0, False
        world.atoms.append(self)

    def replace(self, kind):
        if self.dead:
            raise AssertionError("stale terrain mutation")
        self.world.operations.append(("replace", self.name, kind))
        self.dead = True
        Atom(self.world, self.name, kind, self.area, self.z)

    def retire(self):
        if self.dead:
            raise AssertionError("duplicate retirement")
        self.dead = True
        self.world.operations.append(("qdel", self.name))


class World:
    def __init__(self):
        self.atoms, self.operations, self.queries = [], [], []
        self.clock = 17

    def area_candidates(self, area, kind):
        self.queries.append((area, kind))
        return [a for a in self.atoms if not a.dead and subtype(a.area.kind, area) and subtype(a.kind, kind)]

    def candidates(self, kind):
        self.queries.append(kind)
        return [a for a in self.atoms if not a.dead and subtype(a.kind, kind)]

    def get(self, name):
        return next((a for a in self.atoms if a.name == name and not a.dead), None)

    def snapshot(self):
        return sorted((a.name, a.kind, a.area.kind, a.area.climate, a.z, a.dry) for a in self.atoms if not a.dead)


class Map:
    def __init__(self, world, source=None):
        self.world, self.epoch, self.retired, self.current = world, 1, False, True
        self.pauses, self.on_pause, self.season = [], None, "SPRING"
        self.queue, self.busy, self.policy, self.seasons_on = [], False, None, True
        self.cancellations, self.completions, self.phase_calls = 0, 0, []
        text = source or (ROOT / META).read_text()
        self.source, self.lookup = text, next_phase(text)
        self.supported, self.defaults = supported(text), defaults(text)
        self.funcs = {name: project_proc(text, signature) for name, signature in {
            "replace": "/obj/map_metadata/proc/season_replace_terrain(area_type, old_type, new_type, epoch, climate = null, upper_only = FALSE)",
            "warm": "/obj/map_metadata/proc/season_reconcile_warm(epoch)",
            "water": "/obj/map_metadata/proc/season_reconcile_water(next_phase, epoch)",
            "edge": "/obj/map_metadata/proc/season_reconcile_edge(previous_phase, next_phase, epoch)",
        }.items()}
        asia = (ROOT / "code/game/objects/map_metadata/nomads/nomads_asia.dm").read_text()
        self.asia = project_proc(asia, "/obj/map_metadata/nomads/asia/season_transition_complete(var/epoch)")

    def valid(self, epoch):
        return self.current and not self.retired and self.epoch == epoch

    def pause(self, epoch, work):
        if not self.valid(epoch):
            return False
        self.pauses.append(work)
        if self.on_pause:
            self.on_pause(self)
        return self.valid(epoch)

    @staticmethod
    def candidate(atom, kind):
        return not atom.dead and subtype(atom.kind, kind)

    def replace(self, area, old, new, epoch, climate=None, upper_only=False):
        return self.funcs["replace"](self, self.world, epoch, area_type=area, old_type=old, new_type=new, climate=climate, upper_only=upper_only)

    def warm(self, epoch):
        return self.funcs["warm"](self, self.world, epoch)

    def water(self, target, epoch):
        return self.funcs["water"](self, self.world, epoch, next_phase=target)

    def edge(self, previous, target, epoch=1):
        return self.funcs["edge"](self, self.world, epoch, previous_phase=previous, next_phase=target)

    def finish_asia(self, epoch=1):
        return self.asia(self, self.world, epoch)

    def apply_prefix(self, force, advance_decay, epoch):
        # Boundary adapter: execute the actual selected destination's scalar
        # prefix; legacy terrain/RNG payloads are separately byte-parity checked.
        if not self.valid(epoch) or not (force or self.seasons_on):
            return
        target = self.lookup(self.policy, self.season)
        apply = body(self.source, "/obj/map_metadata/proc/season_apply(var/force, var/advance_decay, var/epoch)")
        pattern = r'(?:else )?if \(next_phase == "' + target + r'"\)\n\t\t\tseason = "' + target + r'"\n\t\t\trecord_abandonment_season_change\(advance_decay\)'
        if not re.search(pattern, apply):
            raise ValueError("destination prefix changed: " + target)
        self.season = target
        if advance_decay and self.current:
            self.world.clock += 1

    def complete(self, epoch):
        self.completions += 1


def queue_proc(source):
    instructions = {
        "if (season_busy)": "if self.busy:", "return": "return",
        "season_busy = TRUE": "self.busy = True", "try": "try:",
        "while (season_queue.len && !season_retired && map == src)": "while self.queue and not self.retired and self.current:",
        "var/kind = season_queue[1]": "kind = self.queue[0]",
        "var/value = season_queue[2]": "value = self.queue[1]",
        "var/force = season_queue[3]": "force = self.queue[2]",
        "var/advance_decay = season_queue[4]": "advance_decay = self.queue[3]",
        "season_queue.Cut(1, 5)": "del self.queue[:4]",
        'if (kind == "transition")': 'if kind == "transition":',
        "if (!isnull(season_cycle) && !season_next_phase())": "if self.policy is not None and not self.lookup(self.policy, self.season):",
        "continue": "continue", "var/epoch = season_epoch": "epoch = self.epoch",
        'if ((force || config.seasons_on) && (season in list("FALL", "WINTER", "SPRING", "SUMMER")))':
            'if (force or self.seasons_on) and self.season in ("FALL", "WINTER", "SPRING", "SUMMER"):',
        "var/previous_phase = season": "previous_phase = self.season",
        "season_epoch++": "self.epoch += 1",
        "durable_cancel_season_phases()": "self.cancellations += 1",
        "epoch = season_epoch": "epoch = self.epoch",
        "season_apply(force, advance_decay, epoch)": "self.apply_prefix(force, advance_decay, epoch)",
        "if (season_worker_valid(epoch) && !season_reconcile_edge(previous_phase, season, epoch))": "if self.valid(epoch) and not self.edge(previous_phase, self.season, epoch):",
        "if (season_worker_valid(epoch))": "if self.valid(epoch):",
        "season_transition_complete(epoch)": "self.complete(epoch)",
        "else if (season_worker_valid(value))": "elif self.valid(value):",
        "call(src, kind)(value)": "self.phase_calls.append((kind, value))",
        "catch (var/exception/E)": "except Exception:",
        "season_queue = list()": "self.queue = []",
        "season_busy = FALSE": "self.busy = False", "throw E": "raise",
        "if (season_retired || map != src)": "if self.retired or not self.current:",
    }
    lines = ["def execute(self):"]
    for raw in body(source, "/obj/map_metadata/proc/season_run_queue()").splitlines():
        code = raw.split("//", 1)[0].rstrip()
        if code.strip():
            depth = len(code) - len(code.lstrip("\t"))
            lines.append("    " * depth + instructions[code.strip()])
    env = {}
    exec("\n".join(lines), env)
    return env["execute"]


def fixture():
    w = World()
    forest, cold, roof, desert = Area(FOREST), Area(FOREST, "taiga"), Area(ROOFED), Area(DESERT, "desert")
    for name, kind, area, z in (
        ("winter dirt", DIRT + "/winter", forest, 1), ("winter grass", "/turf/floor/winter/grass", forest, 1),
        ("cold dirt", DIRT + "/winter", cold, 1), ("roof snow", "/turf/floor/winter", roof, 1),
        ("dry channel", "/turf/floor/beach/drywater", desert, 1),
        ("dry deep", "/turf/floor/beach/drywater2", desert, 2),
        ("wet upper", WATER + "/swamp", desert, 2), ("wet lower", WATER + "/swamp", desert, 1),
        ("deep upper", WATER + "/deep/swamp", desert, 2),
        ("flood upper", WATER + "/flooded", forest, 2), ("flood lower", WATER + "/flooded", forest, 1),
        ("land lower", DIRT + "/flooded", forest, 1), ("ploughed upper", DIRT + "/ploughed/flooded", forest, 2)):
        Atom(w, name, kind, area, z)
    for i, kind in enumerate(SNOW):
        Atom(w, "warm wall" + str(i), kind, forest)
        Atom(w, "cold wall" + str(i), kind, cold)
    for name, kind, area in (("well", SINK + "/well", desert), ("puddle", SINK + "/puddle", desert),
                             ("other sink", SINK, desert), ("forest well", SINK + "/well", forest)):
        Atom(w, name, kind, area, dry=True)
    return w, Map(w)


class EcologyTests(unittest.TestCase):
    def test_actual_queue_and_destination_prefix_charge_once_or_preserve_admin_age(self):
        for force, advance in ((False, True), (True, True), (True, False)):
            w, m = fixture()
            m.policy, m.season = ["SPRING", "SUMMER", "FALL"], "FALL"
            # Source lookup intentionally requires the same plain-list adapter.
            from test_flow import DMList
            m.policy = DMList(m.policy)
            m.queue = ["transition", False, force, advance]
            queue_proc(m.source)(m)
            self.assertEqual((m.season, w.clock, m.cancellations, m.completions), ("SPRING", 17 + int(advance), 1, 1))
            self.assertEqual((m.busy, m.queue), (False, []))
            self.assertEqual(w.get("winter dirt").kind, DIRT + "/winter")
            self.assertFalse(w.get("well").dry)

    def test_queued_reentry_stays_serialized_and_stale_phase_is_cancelled(self):
        from test_flow import DMList
        w, m = fixture()
        m.policy, m.season = DMList(["SPRING", "SUMMER", "FALL"]), "FALL"
        run = queue_proc(m.source)
        m.queue = ["transition", False, False, True]
        def enqueue(owner):
            owner.on_pause = None
            owner.queue += ["transition", False, False, True, "season_phase_5", owner.epoch, False, False]
            run(owner)  # Production busy guard must refuse recursive service.
        m.on_pause = enqueue
        run(m)
        self.assertEqual((m.season, w.clock, m.cancellations, m.completions), ("SUMMER", 19, 2, 2))
        self.assertEqual((m.phase_calls, m.queue, m.busy), ([], [], False))

    def test_invalid_later_edge_consumes_request_without_epoch_age_or_completion(self):
        from test_flow import DMList
        w, m = fixture()
        before = w.snapshot()
        m.policy = DMList(["SPRING", "SUMMER", "WINTER"])
        m.queue = ["transition", False, True, True]
        queue_proc(m.source)(m)
        self.assertEqual((m.season, m.epoch, w.clock, m.completions, m.cancellations), ("SPRING", 1, 17, 0, 0))
        self.assertEqual((w.snapshot(), w.operations, m.queue), (before, [], []))

    def test_default_edges_do_no_additional_ecology_work(self):
        w, m = fixture()
        for previous, target in m.defaults.items():
            before = w.snapshot()
            self.assertTrue(m.edge(previous, target))
            self.assertEqual(w.snapshot(), before)
        self.assertEqual((w.queries, w.operations, m.pauses, w.clock), ([], [], [], 17))

    def test_each_six_nondefault_edges_preserves_unmarked_ground_and_reconciles_structures_water(self):
        for previous, target in (("SPRING", "FALL"), ("SUMMER", "SPRING"), ("FALL", "SPRING"),
                                 ("FALL", "SUMMER"), ("WINTER", "SUMMER"), ("WINTER", "FALL")):
            with self.subTest(edge=(previous, target)):
                w, m = fixture()
                self.assertTrue(m.edge(previous, target))
                self.assertEqual(w.get("winter dirt").kind, DIRT + "/winter")
                self.assertEqual(w.get("winter grass").kind, "/turf/floor/winter/grass")
                self.assertEqual(w.get("roof snow").kind, "/turf/floor/winter")
                self.assertEqual(w.get("cold dirt").kind, DIRT + "/winter")
                for i in range(3):
                    self.assertIsNone(w.get("warm wall" + str(i)))
                    self.assertIsNotNone(w.get("cold wall" + str(i)))
                wet = target == "SPRING"
                self.assertEqual((w.get("well").dry, w.get("puddle").dry), (not wet, not wet))
                self.assertTrue(w.get("other sink").dry)
                self.assertEqual(w.get("forest well").dry, not wet)
                if wet:
                    self.assertEqual(w.get("dry channel").kind, WATER + "/swamp")
                    self.assertEqual(w.get("dry deep").kind, WATER + "/deep/swamp")
                    self.assertEqual(w.get("land lower").kind, WATER + "/flooded")
                    self.assertEqual(w.get("ploughed upper").kind, WATER + "/flooded")
                else:
                    self.assertEqual(w.get("wet upper").kind, "/turf/floor/beach/drywater")
                    self.assertEqual(w.get("deep upper").kind, "/turf/floor/beach/drywater2")
                    self.assertEqual(w.get("flood upper").kind, DIRT + "/flooded")
                    self.assertEqual(w.get("wet lower").kind, WATER + "/swamp")
                    self.assertEqual(w.get("flood lower").kind, WATER + "/flooded")
                self.assertEqual(w.clock, 17, "cleanup charged another season")

    def test_asia_completion_runs_actual_label_flood_rules_after_every_supported_edge(self):
        for previous in ("SPRING", "SUMMER", "FALL", "WINTER"):
            for target in ("SPRING", "SUMMER", "FALL", "WINTER"):
                w, m = fixture()
                if not m.supported(previous, target):
                    continue
                m.season = target
                self.assertTrue(m.edge(previous, target))
                m.finish_asia()
                expected = DIRT + "/flooded" if target in ("SUMMER", "FALL") else WATER + "/flooded"
                self.assertEqual(w.get("flood lower").kind, expected)
                self.assertEqual(w.get("land lower").kind, expected)
                self.assertEqual(w.clock, 17)

    def test_rejected_edges_and_retired_owner_leave_world_untouched(self):
        for previous, target in (("SPRING", "WINTER"), ("SUMMER", "WINTER"), ("EVENT", "SPRING"), ("FALL", "FALL")):
            w, m = fixture()
            before = w.snapshot()
            self.assertFalse(m.edge(previous, target))
            self.assertEqual((w.snapshot(), w.queries, w.operations, m.pauses), (before, [], [], []))
        w, m = fixture()
        m.retired = True
        self.assertFalse(m.edge("WINTER", "FALL"))
        self.assertEqual(w.operations, [])

    def test_epoch_cancellation_during_budget_pause_stops_before_next_mutation(self):
        w, m = fixture()
        before = w.snapshot()
        m.on_pause = lambda owner: setattr(owner, "epoch", owner.epoch + 1)
        self.assertFalse(m.edge("WINTER", "FALL"))
        self.assertEqual(w.snapshot(), before)
        self.assertEqual(w.operations, [])
        self.assertEqual(len(m.pauses), 1)

    def test_stale_candidate_is_rechecked_after_budget_pause(self):
        w, m = fixture()
        target = w.get("warm wall0")
        def retire_candidate(owner):
            target.dead = True
            owner.on_pause = None
        m.on_pause = retire_candidate
        self.assertTrue(m.edge("WINTER", "FALL"))
        self.assertNotIn(("qdel", "warm wall0"), w.operations)

    def test_repeated_reconciliation_is_state_idempotent_without_new_age_or_retirements(self):
        w, m = fixture()
        self.assertTrue(m.edge("WINTER", "FALL"))
        before = w.snapshot()
        operations = w.operations.copy()
        self.assertTrue(m.edge("WINTER", "FALL"))
        self.assertEqual(w.snapshot(), before)
        self.assertEqual(w.operations, operations)
        self.assertEqual(w.clock, 17)

    def test_worker_budget_and_phase_queue_ownership_remain_existing_contracts(self):
        source = (ROOT / META).read_text()
        replacement = body(source, "/obj/map_metadata/proc/season_replace_terrain(area_type, old_type, new_type, epoch, climate = null, upper_only = FALSE)")
        self.assertLess(replacement.index("season_work_pause"), replacement.index("season_candidate_valid"))
        self.assertLess(replacement.index("season_candidate_valid"), replacement.index("T.ChangeTurf"))
        self.assertIn("get_area_turfs(area_type, null, old_type, src, epoch)", replacement)
        self.assertNotIn("spawn(", replacement)
        queue = body(source, "/obj/map_metadata/proc/season_run_queue()")
        self.assertIn("if (season_worker_valid(epoch) && !season_reconcile_edge(previous_phase, season, epoch))\n\t\t\t\t\t\tcontinue", queue)


if __name__ == "__main__":
    unittest.main()
