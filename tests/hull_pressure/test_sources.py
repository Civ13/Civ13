"""Offline dispatch and conservation contracts for salvage pressure pockets."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def source(path):
    return (ROOT / path).read_text(encoding="utf-8")


def proc(text, signature):
    return re.search(r"(?ms)^" + re.escape(signature) + r"\n(.*?)(?=^/|\Z)", text)[1]


PRESSURE = source("code/modules/naval/hull_pressure.dm")
LEDGER = source("code/modules/naval/hull_ledger.dm")
DEPTH = source("code/modules/naval/hull_depth.dm")
COMPARTMENTS = source("code/modules/naval/hull_compartments.dm")
HELPERS = source("code/game/mob/living/carbon/human/human_helpers.dm")
DIVES = source("code/modules/1713/machinery/modular_vehicles/ships/free_diving.dm")
SEABED = source("code/modules/1713/machinery/modular_vehicles/ships/seabed.dm")
SEA_LAYER = source("code/modules/1713/machinery/modular_vehicles/ships/sea_layer.dm")
SCUBA = source("code/modules/1713/machinery/modular_vehicles/ships/scuba.dm")


class PressureSource(unittest.TestCase):
    def test_actual_watertight_boundaries_and_both_faces(self):
        barrier = proc(PRESSURE, "/proc/hull_pressure_barrier(turf/T)")
        for guard in ("/obj/structure/hull_bulkhead", "/steel/watertight", "!D.state",
                      "D.health >= initial(D.health)", "W.health >= initial(W.health)"):
            self.assertIn(guard, barrier)
        shell = proc(PRESSURE, "/proc/hull_pressure_shell(turf/T, turf/top = null)")
        for guard in ("F.health < F.maxhealth", "F.loc != T", "/steelplating/hold/breach",
                      "C = R.building_floor()", "C = locate(/obj/covers/steelplating) in top",
                      "C.health < C.maxhealth"):
            self.assertIn(guard, shell)
        self.assertEqual(shell.count("locate(/obj/structure/multiz)"), 2)
        self.assertEqual(shell.count("locate(/obj/structure/cargo_hatch)"), 2)
        self.assertNotIn("iscovered()", shell)

    def test_geometry_monitors_both_decks_leaks_and_wet_bays(self):
        scan = proc(PRESSURE, "/datum/hull_ledger/proc/pressure_scan()")
        self.assertIn("B.offsets.len > SHIP_DRAUGHT_MAX_TILES", scan)
        self.assertIn("pressure_mapped_at == world.time", scan)
        self.assertIn("pressure_scan_deck(B.lower_cells(main), main)", scan)
        graph = proc(PRESSURE, "/datum/hull_ledger/proc/pressure_scan_deck(list/on_deck, list/above = null)")
        self.assertIn("!N || isnull(shell[N])", graph)
        self.assertIn("!shell[T] || wet[T]", graph)
        self.assertIn("bay_water[bay] >= cap * 0.98", graph)
        self.assertIn("if (walls[N])", graph)
        self.assertIn("if (!shell[N])", graph)
        self.assertIn("pressure_rooms[key] = keys", graph)
        self.assertIn("pressure_air -= key", scan)
        for state in ("opened", "closed"):
            self.assertIn("hull_compartments_changed", proc(COMPARTMENTS,
                "/obj/structure/simple_door/key_door/anyone/fire_door/steel/watertight/door_" + state + "()"))
        self.assertIn("hull_pressure_changed(T)", COMPARTMENTS)
        self.assertIn("L.pressure_mapped_at = -1\n\t\tL.pressure_scan()", PRESSURE)

    def test_ledger_vents_after_inflow_but_before_powered_pumping(self):
        step = proc(LEDGER, "/datum/hull_ledger/proc/step_ledger(seconds)")
        order = ("flood_holes(", "step_ports(", "step_load(", "step_storm(",
                 "if (depth_disabled && length(pressure_air))",
                 "pressure_mapped_at = -1", "pressure_scan()", "pump_bilge(seconds)")
        self.assertEqual([step.index(s) for s in order], sorted(step.index(s) for s in order))
        self.assertEqual(step.count("pressure_scan()"), 1)

    def test_budget_spent_by_active_breath_not_ambient_query_or_reclosing(self):
        breathe = proc(PRESSURE, "/datum/hull_ledger/proc/pressure_breath(turf/T, consume = FALSE)")
        self.assertIn("if (consume)\n\t\t\tpressure_air[key] = remaining - 1", breathe)
        current_room = proc(PRESSURE, "/datum/hull_ledger/proc/pressure_room_air(turf/T)")
        self.assertIn("water_at(T) >= bay_capacity(bay) * 0.98", current_room)
        self.assertEqual(PRESSURE.count("pressure_air[key] = HULL_PRESSURE_CELL_BREATHS"), 1)
        self.assertEqual(DEPTH.count("pressure_prepare_descent()"), 1)
        self.assertIn("if (!depth_disabled || !islist(record))", PRESSURE)
        self.assertIn('var/key = "[deck],[O[1]],[O[2]]"', PRESSURE)
        self.assertIn("clamp(round(record[key]), 0, HULL_PRESSURE_CELL_BREATHS)", PRESSURE)
        self.assertIn("return pressure_air.Copy()", PRESSURE)

    def test_existing_submarine_air_precedes_ordinary_ship_pressure_lookup(self):
        air = proc(SEABED, "/turf/floor/beach/water/deep/saltwater/underwater/sea_layer/outside_air_breathable()")
        self.assertLess(air.index("return B.air_breathable()"), air.index("sunken_hull_pressure_breath(src)"))
        drowning = proc(HELPERS, "/mob/living/human/proc/handle_drowning()")
        self.assertIn("on_sunken_deck && stat != DEAD && !seabed_diving_rating() && sunken_hull_pressure_breath(T, TRUE)", drowning)
        self.assertIn("var/exposed_seabed = on_sunken_deck || (sea_layer_cell(T) && !T.iscovered())", drowning)

    def test_dry_walking_belongs_to_one_connected_hull_pocket(self):
        sea_pass = proc(SEA_LAYER, "/turf/floor/beach/water/deep/saltwater/underwater/sea_layer/CanPass(atom/movable/mover)")
        self.assertIn("if (stepping && iscovered() && from.iscovered() && sunken_hull_pressure_same_shelter(from, src))\n\t\treturn ..()", sea_pass)
        self.assertLess(sea_pass.index("sunken_hull_pressure_same_shelter"), sea_pass.index("M.can_walk_seabed()"))
        same = proc(PRESSURE, "/proc/sunken_hull_pressure_same_shelter(turf/from, turf/destination)")
        self.assertIn("!L.deck_holds(destination)", same)
        self.assertIn("room != L.pressure_room_air(destination)", same)
        self.assertIn("isnum(L.pressure_air[key])", same)

    def test_underwater_hold_counts_for_cold_depth_and_scuba_but_not_ascent_through_deck(self):
        hold = proc(SEABED, "/turf/floor/plating/ship_hold/outside_ambient_c()")
        self.assertIn("!sunken_hull_pressure_sheltered(src)", hold)
        self.assertIn("sea_zone_temperature_c(hull_depth_zone(src))", hold)
        pressure = proc(SEABED, "/mob/living/human/proc/seabed_exposure_step(turf/T)")
        self.assertIn("var/zone = hull_depth_zone(T)", pressure)
        self.assertIn("submerged_hull && sunken_hull_pressure_sheltered(T)", pressure)
        self.assertIn("if (hull_depth_zone(T) >= SEA_ZONE_OPEN)", SCUBA)
        ascend = proc(DIVES, "/mob/living/human/proc/free_dive_surface(forced = FALSE)")
        self.assertIn("if (free_diving && submerged_built_hull_deck(T) && !sea_layer_cell(T))", ascend)
        self.assertLess(ascend.index("the hull first"), ascend.index("free_diving = FALSE"))


if __name__ == "__main__":
    unittest.main()
