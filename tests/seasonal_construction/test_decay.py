"""Restricted production-body traces; engine list/GC/save behavior stays unverified."""
from pathlib import Path
import re
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "code/processes/seasonal_construction.dm"


def body(source, signature):
    match = re.search(r"^" + re.escape(signature) + r"\n(.*?)(?=^/|\Z)", source, re.M | re.S)
    if not match:
        raise ValueError(signature)
    return match.group(1)


def project(source, signature):
    """Reject unknown instructions, rather than guessing DM semantics."""
    instructions = {
        "if (src != map || construction_last_season == season)":
            "if self is not state.map or self.construction_last_season == state.season:",
        "construction_last_season = season": "self.construction_last_season = state.season",
        "if (advance_decay && persistence && !persistence_save_in_progress)":
            "if advance_decay and self.persistence and not state.saving:",
        "if (advance_decay && !persistence_save_in_progress)":
            "if advance_decay and not state.saving:",
        "if (src != map)": "if self is not state.map:",
        "construction_season_changes++": "state.clock += 1",
        "if (istype(src, /obj/roof))": "if self.is_roof:",
        "var/obj/roof/R = src": "R = self",
        "if (R.building_pair_id)": "if R.building_pair_id:",
        "switch (type)": "match self.kind:",
        "return 0": "return 0",
        "return": "return",
        "if (gc_destroyed || gcDestroyed || seasonal_construction_index || !seasonal_construction_lifetime())":
            "if self.gc_destroyed or self.gcDestroyed or self.seasonal_construction_index or not self.seasonal_construction_lifetime():",
        "seasonal_construction += src": "state.registry.append(self)",
        "seasonal_construction_index = seasonal_construction.len": "self.seasonal_construction_index = len(state.registry)",
        "seasonal_construction_last = construction_season_changes": "self.seasonal_construction_last = state.clock",
        "var/index = seasonal_construction_index": "index = self.seasonal_construction_index",
        "if (!index)": "if not index:",
        "var/obj/last = seasonal_construction[seasonal_construction.len]": "last = state.registry[-1]",
        "seasonal_construction[index] = last": "state.registry[index - 1] = last",
        "last.seasonal_construction_index = index": "last.seasonal_construction_index = index",
        "seasonal_construction.Cut(seasonal_construction.len, seasonal_construction.len + 1)": "state.registry.pop()",
        "seasonal_construction_index = 0": "self.seasonal_construction_index = 0",
        "return anchored && isturf(loc) && !gc_destroyed && !gcDestroyed":
            "return self.anchored and self.on_turf and not self.gc_destroyed and not self.gcDestroyed",
        "return wall && !incomplete && ..()":
            "return self.wall and not self.incomplete and self.base_exposed(self, state)",
        "var/elapsed = max(0, construction_season_changes - seasonal_construction_last)":
            "elapsed = max(0, state.clock - self.seasonal_construction_last)",
        "if (map && seasonal_construction_lifetime() && seasonal_construction_exposed())":
            "if state.map and self.seasonal_construction_lifetime() and self.seasonal_construction_exposed():",
        "seasonal_construction_due += elapsed": "self.seasonal_construction_due += elapsed",
        "return health": "return self.health",
        "return initial(health)": "return self.design_health",
        "health -= damage": "self.health -= damage",
        "if (health <= 0)": "if self.health <= 0:",
        'visible_message(SPAN_WARNING("The [name] falls apart from seasonal weathering!"))': "self.messages += 1",
        "qdel(src)": "self.qdel()",
        "if (persistence_save_in_progress)": "if state.saving:",
        "if (gc_destroyed || gcDestroyed)": "if self.gc_destroyed or self.gcDestroyed:",
        "unregister_seasonal_construction()": "self.unregister_seasonal_construction()",
        "register_seasonal_construction()": "self.register_seasonal_construction()",
        "accrue_seasonal_construction()": "self.accrue_seasonal_construction()",
        "if (!map || !map.persistence || !seasonal_construction_exposed())":
            "if not state.map or not state.map.persistence or not self.seasonal_construction_exposed():",
        "var/lifetime = seasonal_construction_lifetime()": "lifetime = self.seasonal_construction_lifetime()",
        "if (!lifetime)": "if not lifetime:",
        "if (seasonal_construction_due <= 0)": "if self.seasonal_construction_due <= 0:",
        "var/damage = seasonal_construction_design_health() * seasonal_construction_due / lifetime":
            "damage = self.seasonal_construction_design_health() * self.seasonal_construction_due / lifetime",
        "if (damage >= seasonal_construction_health() && contents.len)":
            "if damage >= self.seasonal_construction_health() and self.contents:",
        "if (damage >= seasonal_construction_health() && FALSE)":
            "if damage >= self.seasonal_construction_health() and False:",
        "seasonal_construction_due = 0": "self.seasonal_construction_due = 0",
        "damage_seasonal_construction(damage)": "self.damage_seasonal_construction(damage)",
        "if (seasonal_construction_index)": "if self.seasonal_construction_index:",
        "return ..()": "return",
        "..()": "pass",
        "if (persistence_save_in_progress || !map || !map.persistence)":
            "if state.saving or not state.map or not state.map.persistence:",
        "var/checks = min(CONSTRUCTION_DECAY_BATCH, seasonal_construction.len)":
            "checks = min(CONSTRUCTION_DECAY_BATCH, len(state.registry))",
        "while (checks-- > 0 && seasonal_construction.len)": "while checks > 0 and state.registry:",
        "if (seasonal_construction_cursor > seasonal_construction.len)": "if state.cursor > len(state.registry):",
        "seasonal_construction_cursor = 1": "state.cursor = 1",
        "var/obj/O = seasonal_construction[seasonal_construction_cursor]": "O = state.registry[state.cursor - 1]; checks -= 1; state.visits.append(O)",
        "var/index = seasonal_construction_cursor": "index = state.cursor",
        "O.check_seasonal_construction()": "O.check_seasonal_construction()",
        "if (O && O.seasonal_construction_index == index)": "if not O.gc_destroyed and O.seasonal_construction_index == index:",
        "seasonal_construction_cursor++": "state.cursor += 1",
        "if (world.tick_usage >= 20)": "if state.tick_usage >= 20:",
    }
    constants = {name: int(value) for name, value in re.findall(r"^#define (CONSTRUCTION_\w+) (\d+)$", source, re.M)}
    lines = ["def execute(self, state, advance_decay=True, damage=0):"]
    for raw in body(source, signature).splitlines():
        code = raw.split("//", 1)[0].rstrip()
        if not code.strip():
            continue
        depth = len(code) - len(code.lstrip("\t"))
        code = code.strip()
        if code.startswith("if (/obj/"):
            types = code[4:-1].split(", ")
            translated = "case " + " | ".join(repr(t) for t in types) + ":"
        elif code.startswith("return CONSTRUCTION_") and code[7:] in constants:
            translated = code
        else:
            translated = instructions.get(code)
            if translated is None:
                raise ValueError(code)
        lines.append("    " * depth + translated)
    env = dict(constants)
    exec(compile("\n".join(lines), "<production seasonal construction>", "exec"), env)
    return env["execute"]


class State:
    def __init__(self, source=None):
        self.source = source or SOURCE.read_text()
        self.clock, self.cursor, self.tick_usage = 0, 1, 0
        self.registry, self.visits = [], []
        self.saving = False
        self.season = "SPRING"
        self.map = NS(persistence=True, construction_last_season=None)
        self.record = project(self.source, "/obj/map_metadata/proc/record_construction_season_change(advance_decay)")
        self.fire = project(self.source, "/process/seasonal_construction/fire()")

    def transition(self, advance=True, season=None):
        seasons = ["SPRING", "SUMMER", "FALL", "WINTER"]
        self.season = season or seasons[(seasons.index(self.season) + 1) % 4]
        self.record(self.map, self, advance_decay=advance)

    def sweep(self):
        self.fire(None, self)


class Construction:
    def __init__(self, state, kind="/obj/covers/straw_wall", health=75, paired=False):
        self.state, self.kind = state, kind
        self.is_roof = kind.startswith("/obj/roof")
        self.building_pair_id = "pair" if paired else None
        self.health = self.design_health = health
        self.anchored = self.on_turf = self.wall = True
        self.incomplete = self.gc_destroyed = self.gcDestroyed = False
        self.seasonal_construction_due = self.seasonal_construction_last = self.seasonal_construction_index = 0
        self.contents, self.messages = [], 0
        prefix = "/obj/roof" if self.is_roof else "/obj/covers"
        shared = ["register_seasonal_construction", "unregister_seasonal_construction", "seasonal_construction_lifetime",
                  "accrue_seasonal_construction", "check_seasonal_construction"]
        for name in shared:
            fn = project(state.source, "/obj/proc/" + name + "()")
            setattr(self, name, lambda fn=fn: fn(self, state))
        self.base_exposed = project(state.source, "/obj/proc/seasonal_construction_exposed()")
        self.exposed = self.base_exposed if self.is_roof else project(state.source, "/obj/covers/seasonal_construction_exposed()")
        self.seasonal_construction_exposed = lambda: self.exposed(self, state)
        for name in ["seasonal_construction_health", "seasonal_construction_design_health", "before_save", "after_load"]:
            fn = project(state.source, prefix + "/" + name + "()")
            setattr(self, name, lambda fn=fn: fn(self, state))
        damage = project(state.source, prefix + "/damage_seasonal_construction(damage)")
        self.damage_seasonal_construction = lambda value: damage(self, state, damage=value)
        self.register_seasonal_construction()

    def qdel(self):
        if self.contents:
            raise AssertionError("native destruction would delete contents")
        self.gc_destroyed = True
        self.unregister_seasonal_construction()


class DecayTests(unittest.TestCase):
    def test_exact_material_designs_and_rates(self):
        cases = [("/obj/covers/straw_wall", 75, 16), ("/obj/roof/thatch", 100, 16),
                 ("/obj/roof/palm", 100, 16), ("/obj/covers/dirt_wall", 90, 32),
                 ("/obj/covers/wood_wall", 300, 64), ("/obj/covers/wood_wall/bamboo", 230, 64),
                 ("/obj/covers/wood_wall/log", 330, 64), ("/obj/roof/wood", 100, 64)]
        for kind, health, lifetime in cases:
            with self.subTest(kind=kind):
                s = State()
                item = Construction(s, kind, health)
                for i in range(1, lifetime):
                    s.transition()
                    s.sweep()
                    self.assertEqual(item.health, health * (1 - i / lifetime))
                    self.assertFalse(item.gc_destroyed)
                s.transition()
                s.sweep()
                self.assertTrue(item.gc_destroyed)
                self.assertEqual(item.messages, 1)
                self.assertEqual(s.registry, [])

    def test_world_year_and_research_never_choose_the_rate(self):
        for year in ("5000 B.C.", "1943", "2023"):
            s = State()
            s.map.age, s.map.ordinal_age = year, 8
            item = Construction(s)
            s.transition()
            s.sweep()
            self.assertEqual(item.health, 75 * 15 / 16)

    def test_modern_unknown_children_floors_and_paired_slabs_do_not_register(self):
        for kind in ("/obj/covers/vault", "/obj/covers/steel_wall", "/obj/covers/stone_wall",
                     "/obj/covers/wood_wall/medieval", "/obj/covers/wood_wall/log/corner",
                     "/obj/covers", "/obj/roof", "/obj/roof/concrete", "/obj/roof/glass",
                     "/obj/roof/clay", "/obj/roof/canopy", "/obj/item/trash"):
            s = State()
            item = Construction(s, kind)
            self.assertFalse(item.seasonal_construction_index, kind)
        s = State()
        for kind in ("/obj/roof/wood", "/obj/roof/thatch", "/obj/roof/palm"):
            item = Construction(s, kind, paired=True)
            self.assertFalse(item.seasonal_construction_index)
        self.assertEqual(s.registry, [])

    def test_repeated_callbacks_and_age_preserving_admin_transitions(self):
        s = State()
        item = Construction(s)
        s.transition()
        for _ in range(20):
            s.record(s.map, s)
        s.sweep()
        self.assertEqual(item.health, 75 * 15 / 16)
        s.transition(advance=False)
        s.sweep()
        self.assertEqual(item.health, 75 * 15 / 16)
        s.transition(advance=True)
        s.sweep()
        self.assertEqual(item.health, 75 * 14 / 16)

    def test_mode_toggle_counts_only_persistence_transitions(self):
        s = State()
        item = Construction(s)
        s.map.persistence = False
        for _ in range(8):
            s.transition()
        s.sweep()
        self.assertEqual(s.clock, 0)
        self.assertEqual(item.health, 75)
        s.map.persistence = True
        s.transition()
        s.map.persistence = False
        s.sweep()
        self.assertEqual(item.health, 75)
        s.map.persistence = True
        s.sweep()
        self.assertEqual(item.health, 75 * 15 / 16)

    def test_missed_sweeps_catch_up_once_and_new_construction_has_no_backlog(self):
        s = State()
        old = Construction(s)
        for _ in range(4):
            s.transition()
        new = Construction(s)
        s.sweep()
        self.assertEqual(old.health, 75 * 12 / 16)
        self.assertEqual(new.health, 75)
        for _ in range(20):
            s.sweep()
        self.assertEqual(old.health, 75 * 12 / 16)

    def test_before_save_persists_unapplied_debt_without_damage_or_double_charge(self):
        for kind, hp in (("/obj/covers/straw_wall", 75), ("/obj/roof/thatch", 100)):
            s = State()
            item = Construction(s, kind, hp)
            for _ in range(3):
                s.transition()
            s.saving = True
            item.before_save()
            item.before_save()
            s.sweep()
            item.check_seasonal_construction()
            self.assertEqual((item.health, item.seasonal_construction_due), (hp, 3))
            # Only durable health/debt cross a process restart; real codec is native coverage.
            fresh = State()
            fresh.clock = 57
            restored = Construction(fresh, kind, hp)
            restored.seasonal_construction_due = item.seasonal_construction_due
            restored.after_load()
            fresh.sweep()
            fresh.sweep()
            self.assertEqual(restored.health, hp * 13 / 16)
            self.assertEqual(restored.seasonal_construction_due, 0)
            fresh.transition()
            fresh.sweep()
            self.assertEqual(restored.health, hp * 12 / 16)

    def test_legacy_load_rebases_without_retroactive_age(self):
        s = State()
        s.clock = 200
        item = Construction(s)
        item.after_load()
        s.sweep()
        self.assertEqual((item.health, item.seasonal_construction_due), (75, 0))
        s.transition()
        s.sweep()
        self.assertEqual(item.health, 75 * 15 / 16)

    def test_repairs_restore_health_and_future_wear_keeps_its_material_rate(self):
        s = State()
        item = Construction(s)
        for _ in range(8):
            s.transition()
        s.sweep()
        item.health = 75
        s.sweep()
        self.assertEqual(item.health, 75)
        s.transition()
        s.sweep()
        self.assertEqual(item.health, 75 * 15 / 16)

    def test_existing_combat_damage_is_preserved(self):
        s = State()
        item = Construction(s)
        item.health = 12
        s.transition()
        s.sweep()
        self.assertEqual(item.health, 12 - 75 / 16)

    def test_terminal_decay_waits_for_contents_without_consuming_debt(self):
        s = State()
        item = Construction(s)
        child = object()
        item.contents.append(child)
        for _ in range(16):
            s.transition()
        s.sweep()
        self.assertEqual((item.health, item.seasonal_construction_due), (75, 16))
        self.assertEqual(item.contents, [child])
        item.contents.clear()
        s.sweep()
        self.assertTrue(item.gc_destroyed)
        self.assertEqual(item.messages, 1)

    def test_storage_unanchored_and_incomplete_observations_do_not_accrue(self):
        for attr in ("on_turf", "anchored", "wall", "incomplete"):
            s = State()
            item = Construction(s)
            setattr(item, attr, attr == "incomplete")
            s.transition()
            item.check_seasonal_construction()
            self.assertEqual(item.health, 75)
            self.assertEqual(item.seasonal_construction_due, 0)
            setattr(item, attr, attr != "incomplete")
            s.transition()
            s.sweep()
            self.assertEqual(item.health, 75 * 15 / 16)

    def test_batch_cursor_handles_swap_deletions_and_retains_tail(self):
        s = State()
        items = [Construction(s) for _ in range(160)]
        for _ in range(16):
            s.transition()
        s.sweep()
        self.assertEqual(len(s.visits), 64)
        self.assertEqual(len(s.registry), 96)
        s.sweep()
        self.assertEqual(len(s.registry), 32)
        s.sweep()
        self.assertEqual(len(s.registry), 0)
        self.assertEqual(len(s.visits), 160)
        self.assertEqual(len(set(s.visits)), 160)
        self.assertTrue(all(x.gc_destroyed for x in items))

    def test_tick_budget_resumes_without_duplicate_debit(self):
        s = State()
        items = [Construction(s) for _ in range(5)]
        s.transition()
        s.tick_usage = 20
        for _ in range(5):
            s.sweep()
        self.assertEqual(s.visits, items)
        self.assertTrue(all(x.health == 75 * 15 / 16 for x in items))
        s.sweep()
        self.assertEqual(items[0].health, 75 * 15 / 16)

    def test_retired_and_duplicate_registration_release_slots(self):
        s = State()
        a, b, c = (Construction(s) for _ in range(3))
        a.register_seasonal_construction()
        b.unregister_seasonal_construction()
        b.unregister_seasonal_construction()
        self.assertEqual(s.registry, [a, c])
        self.assertEqual(c.seasonal_construction_index, 2)
        a.gc_destroyed = True
        s.sweep()
        self.assertEqual(s.registry, [c])

    def test_clock_does_not_count_other_map_or_save_phase(self):
        s = State()
        foreign = NS(persistence=True, construction_last_season=None)
        s.record(foreign, s)
        s.saving = True
        s.transition()
        self.assertEqual(s.clock, 0)

    def test_named_mutations_reproduce_wrong_behavior(self):
        source = SOURCE.read_text()
        mutants = {
            "mode": ("advance_decay && persistence && !persistence_save_in_progress", "advance_decay && !persistence_save_in_progress"),
            "replay": ("src != map || construction_last_season == season", "src != map"),
            "save-debt": ("seasonal_construction_due += elapsed", "seasonal_construction_due = 0"),
            "contents": ("damage >= seasonal_construction_health() && contents.len", "damage >= seasonal_construction_health() && FALSE"),
        }
        # Mutation errors are only accepted through the named assertion below.
        for name, (before, after) in mutants.items():
            self.assertEqual(source.count(before), 1)
            changed = source.replace(before, after)
            s = State(changed)
            item = Construction(s)
            if name == "mode":
                s.map.persistence = False
                s.transition()
                self.assertEqual(s.clock, 1, "mode mutant did not count an excluded transition")
            elif name == "replay":
                s.transition()
                s.record(s.map, s)
                self.assertEqual(s.clock, 2, "replay mutant did not duplicate a transition")
            elif name == "contents":
                item.contents.append(object())
                for _ in range(16):
                    s.transition()
                with self.assertRaisesRegex(AssertionError, "native destruction would delete contents"):
                    s.sweep()
                self.assertEqual(item.health, 0)
            else:
                s.transition()
                item.before_save()
                self.assertEqual(item.seasonal_construction_due, 0)

    def test_disable_then_save_keeps_debt_from_preceding_persistence_season(self):
        s = State()
        item = Construction(s)
        s.transition()
        s.map.persistence = False
        s.saving = True
        item.before_save()
        self.assertEqual((item.health, item.seasonal_construction_due), (75, 1))
        s.saving = False
        s.sweep()
        self.assertEqual(item.health, 75)
        s.map.persistence = True
        s.sweep()
        self.assertEqual(item.health, 75 * 15 / 16)


if __name__ == "__main__":
    unittest.main()
