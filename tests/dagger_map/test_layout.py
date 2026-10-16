"""Negative controls use actual serialized DMM and isolated manifest copies."""
import copy
import json
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch

import build_map
from validate_map import check_arrivals, parse_dmm, rectangle, validate


class LayoutTests(unittest.TestCase):
    def setUp(self):
        self.grid, self.layout = build_map.build()
        self.dmm = build_map.render_dmm(self.grid)

    def reject_layout(self, mutate, message):
        layout = copy.deepcopy(self.layout)
        mutate(layout)
        with self.assertRaisesRegex(ValueError, message):
            validate(layout, self.dmm)

    def reject_tile(self, xyz, kind, message):
        grid = self.grid.copy()
        grid[xyz] = kind, grid[xyz][1]
        with self.assertRaisesRegex(ValueError, message):
            validate(self.layout, build_map.render_dmm(grid))

    def local_world(self, point):
        slot = next(s for s in self.layout["slots"] if s["id"] == self.layout["prototype"]["slot"])
        x, y, z = slot["origin"]
        return x + point[0], y + point[1], z

    def test_generated_and_checked_in_artifacts(self):
        self.assertEqual(validate(self.layout, self.dmm)["raid_berths"], 2)
        self.assertEqual(build_map.MAP_PATH.read_text(encoding="utf-8"), self.dmm)
        self.assertEqual(json.loads(build_map.LAYOUT_PATH.read_text(encoding="utf-8")), self.layout)

    def test_unresolved_dmm_constants_even_in_source_palette(self):
        original = build_map.PALETTE["gate"]
        for value in ("TRUE", "FALSE", "NORTH"):
            with self.subTest(value=value):
                bad_gate = (original[0].replace("locked = 1", f"locked = {value}"), *original[1:])
                with patch.dict(build_map.PALETTE, {"gate": bad_gate}):
                    with self.assertRaisesRegex(ValueError, "literal values"):
                        parse_dmm(build_map.render_dmm(self.grid), self.layout["world"])

    def test_coordinate_orientation(self):
        grid = parse_dmm(self.dmm, self.layout["world"])
        self.assertEqual(grid[self.local_world(self.layout["protected"]["boundary_gates"][0])][0], "gate")
        self.assertEqual(grid[self.local_world(self.layout["exposed"]["boarding_ports"][0])][0], "door")
        self.assertEqual(grid[tuple(self.layout["slots"][2]["platform_anchors"][0])][0], "platform")

    def test_duplicate_berth_identity(self):
        self.reject_layout(lambda x: x["slots"][3].update(id="raid_west"), "duplicate slot ID")

    def test_exact_two_raid_berths(self):
        self.reject_layout(lambda x: x["slots"][3].update(kind="home"), "exactly two")

    def test_exactly_one_geometry_group(self):
        self.reject_layout(lambda x: x.update(berth_geometry_groups=[]), "exactly one named")
        self.reject_layout(lambda x: x["berth_geometry_groups"].append(copy.deepcopy(x["berth_geometry_groups"][0])), "exactly one named")
        self.reject_layout(lambda x: x["berth_geometry_groups"][0].update(id=""), "exactly one named")

    def test_geometry_group_membership(self):
        for members in (["raid_west"], ["raid_west", "raid_west"], ["raid_west", "home_west"], ["raid_west", "missing"]):
            with self.subTest(members=members):
                self.reject_layout(lambda x: x["berth_geometry_groups"][0].update(slot_ids=members), "both distinct raid berths only")

    def test_selected_berth_policy_literal_flags(self):
        for field, value, message in (("atomic_reservation_before_load_or_move", False, "must be atomic"),
                                     ("atomic_reservation_before_load_or_move", 1, "must be atomic"),
                                     ("other_berths_remain_available", False, "remain available"),
                                     ("other_berths_remain_available", 1, "remain available"),
                                     ("enforced_by_this_map", True, "must not claim runtime"),
                                     ("enforced_by_this_map", 0, "must not claim runtime")):
            with self.subTest(field=field, value=value):
                self.reject_layout(lambda x: x["reservation_policy"].update({field: value}), message)

    def test_no_exclusive_whole_pair_claim(self):
        for value in (True, 0):
            self.reject_layout(lambda x: x["berth_geometry_groups"][0].update(exclusive_reservation=value), "whole-pair exclusive")
        self.reject_layout(lambda x: x["reservation_policy"].update(scope="both_raid_berths"), "only one berth")
        self.reject_layout(lambda x: x.update(reservation_groups=[]), "whole-pair reservation")

    def test_padded_reservation_overlap(self):
        self.reject_layout(lambda x: x["slots"][3]["reserved_bounds"].__setitem__(0, x["slots"][2]["reserved_bounds"][2]), "padded reservations overlap")

    def test_offset_footprint_does_not_fit(self):
        self.reject_layout(lambda x: x["slots"][3]["origin"].__setitem__(0, x["world"]["width"]), "does not fit")

    def test_world_bounds(self):
        self.reject_layout(lambda x: x["slots"][3]["reserved_bounds"].__setitem__(2, x["world"]["width"] + 1), "out of bounds")

    def test_berth_mask_gap(self):
        def mutate(layout):
            rows = layout["slots"][2]["berth_mask_rows_south_to_north"]
            rows[0] = "0" + rows[0][1:]
        self.reject_layout(mutate, "berth mask gaps")

    def test_bridge_mask_gap(self):
        self.reject_layout(lambda x: x["slots"][2]["bridge_cells"].pop(), "bridge mask gaps")

    def test_platform_anchor_offset(self):
        self.reject_layout(lambda x: x["slots"][2]["platform_anchors"][0].__setitem__(0, 1), "anchor offset")

    def test_actual_empty_destination_cells(self):
        for coordinate in (tuple(s["origin"]) for s in self.layout["slots"][1:]):
            with self.subTest(coordinate=coordinate):
                self.reject_tile(coordinate, "crate", "destination DMM is occupied")

    def test_actual_bridge_blocked(self):
        shared = {(x, y, access["z"]) for access in self.layout["shared_access"] for x, y in rectangle(access["bounds"])}
        for raid in self.layout["slots"][2:]:
            # Include the outside edge of the entire three-wide boarding band.
            bridge = next(p for p in raid["bridge_cells"] if tuple(p) not in shared)
            self.reject_tile(tuple(bridge), "hull", "blocked anchor bridge")

    def test_unsafe_boarding_declaration(self):
        self.reject_layout(lambda x: x["exposed"]["boarding_ports"].append([0, 10]), "boarding ports")

    def test_actual_protected_exterior_open(self):
        self.reject_tile(self.local_world([0, 10]), "door", "protected exterior is open")

    def test_actual_gate_bypass(self):
        gate = self.layout["protected"]["boundary_gates"][0]
        self.reject_tile(self.local_world([gate[0] - 1, gate[1]]), "floor", "bypasses boundary gate")

    def test_actual_gate_removed(self):
        self.reject_tile(self.local_world(self.layout["protected"]["boundary_gates"][0]), "floor", "exactly two single door")

    def test_safe_compartment_sustenance_declaration(self):
        mutations = {"nutrition": "drain", "hydration": "drain", "cap": "unbounded", "rate": 1,
                     "requires_actual_occupancy": False, "requires_party_authorization": False,
                     "suppresses_ordinary_drain": False, "single_metabolism_update": False,
                     "resume_ordinary_on_exit": False, "enforced_by_this_map": True}
        for field, value in mutations.items():
            with self.subTest(field=field):
                self.reject_layout(lambda x: x["protected"]["sustenance"].update({field: value}), "sustenance")

    def test_protected_upgradeable_infrastructure(self):
        for name in ("helm_controls", "engine_room"):
            marker = self.layout["protected"]["infrastructure"][name]
            self.reject_tile(self.local_world(marker["marker"]), "table", "infrastructure marker")
            self.reject_layout(lambda x: x["protected"]["infrastructure"][name].update(marker=x["anchors"]["workshop"]), "infrastructure marker")
            self.reject_layout(lambda x: x["protected"]["infrastructure"][name].update(upgradeable=False), "declare upgrades")
        self.reject_layout(lambda x: x["protected"]["infrastructure"].update(upgrade_costs=100), "balance unspecified")
        self.reject_layout(lambda x: x["protected"]["infrastructure"].update(enforced_by_this_map=True), "runtime disabled")

    def test_boundary_protection_exact_scope(self):
        self.reject_layout(lambda x: x["protected"]["boundary_protection"]["wall_tiles"].pop(), "cover exact protected")
        self.reject_layout(lambda x: x["protected"]["boundary_protection"]["door_tiles"].pop(), "cover exact protected")
        for field, value in (("mode", "health_only"), ("denied_paths", ["damage"]),
                             ("preserve_on_transport_and_restore", False), ("exposed_walls_protected", True),
                             ("enforced_by_this_map", True)):
            with self.subTest(field=field):
                self.reject_layout(lambda x: x["protected"]["boundary_protection"].update({field: value}), "boundary protection")

    def test_raid_input_reward_and_target_door_declarations(self):
        self.reject_layout(lambda x: x["raid_access"].update(required_inputs=["loaded_fuel"]), "loaded fuel and target-section pass")
        self.reject_layout(lambda x: x["raid_access"]["front_sections"].update(entry_cost="same"), "front rewards/costs")
        self.reject_layout(lambda x: x["raid_access"].update(balance_values=100), "front rewards/costs")
        for field, value in (("breachable_without_pass", False), ("inherits_dagger_boundary_protection", True)):
            self.reject_layout(lambda x: x["raid_access"]["target_compartment_doors"].update({field: value}), "target doors")

    def test_raid_atomic_server_transaction(self):
        for field, value in (("authority", "client"), ("atomic_commit", False), ("atomic_refund", False),
                             ("idempotent", False), ("inputs", ["loaded_fuel"]), ("atomic_refund", 1)):
            with self.subTest(field=field):
                self.reject_layout(lambda x: x["raid_access"]["transaction"].update({field: value}), "server atomic idempotent")
        for field, value in (("commit_point", "arrival"), ("refund_policy", "never"),
                             ("failure_resolution", "duplicate"), ("enforced_by_this_map", True)):
            self.reject_layout(lambda x: x["raid_access"]["transaction"].update({field: value}), "policy unresolved")

    def test_raid_sequence_states_and_undefined_timings(self):
        self.reject_layout(lambda x: x["raid_access"]["extraction_sequence"]["states"].pop(), "all ordered states")
        self.reject_layout(lambda x: x["raid_access"]["extraction_sequence"]["requirements"].pop("boarding"), "all ordered states")
        self.reject_layout(lambda x: x["raid_access"]["extraction_sequence"]["requirements"].update(arrival=""), "all ordered states")
        for field, value in (("timings", 60), ("enforced_by_this_map", True)):
            self.reject_layout(lambda x: x["raid_access"]["extraction_sequence"].update({field: value}), "timings unspecified")

    def test_airlock_declarations_and_empty_interior(self):
        for field, value in (("interlocked", False), ("authorize_from_either_side", False),
                             ("enforced_by_this_map", True), ("safe_egress_policy", "invented"),
                             ("policy", "everyone")):
            with self.subTest(field=field):
                self.reject_layout(lambda x: x["protected"]["airlock"].update({field: value}), "airlock authorization")
        point = self.layout["protected"]["airlock"]["interior_bounds"][:2]
        self.reject_tile(self.local_world(point), "crate", "airlock interior must be empty")

    def test_inner_airlock_bypass(self):
        door = self.layout["protected"]["airlock"]["inner_door"]
        self.reject_tile(self.local_world([door[0] + 1, door[1]]), "safe", "closed airlock door")

    def test_sustenance_excludes_airlock(self):
        self.reject_layout(lambda x: x["protected"]["sustenance"].update(bounds=x["protected"]["bounds"]), "outside sustenance zone")

    def test_shared_access_exclusion_encroachment(self):
        self.reject_layout(lambda x: x["shared_access"][0]["bounds"].__setitem__(0, x["slots"][2]["reserved_bounds"][2]), "encroaches reservation exclusion")

    def test_build_pads_do_not_occupy_main_routes(self):
        self.reject_layout(lambda x: x["build_pads"][0].update(bounds=x["keep_clear"][0]["bounds"]), "build pads overlap main routes")

    def test_actual_dmm_two_arrival_routing_negative_control(self):
        parsed = parse_dmm(self.dmm, self.layout["world"])
        footprint = rectangle(self.layout["footprint"]["bounds"])
        actual = {p: parsed[self.local_world(p)][0] for p in footprint}
        ports = {tuple(p) for p in self.layout["exposed"]["boarding_ports"]}
        check_arrivals(self.layout, parsed, actual, ports)
        # Both source trains are composed with every real boarding cell blocked.
        blocked = {p: ("hull" if p in ports else kind) for p, kind in actual.items()}
        with self.assertRaisesRegex(ValueError, "simultaneous arrivals cannot route"):
            check_arrivals(self.layout, parsed, blocked, ports)

    def test_actual_anchor_and_pad_access(self):
        self.reject_tile(self.local_world(self.layout["anchors"]["workshop"]), "hull", "unreachable anchor")
        self.reject_tile(self.local_world(self.layout["build_pads"][0]["bounds"][:2]), "hull", "blocked build pad")

    def test_unreachable_room(self):
        self.reject_layout(lambda x: x["rooms"][0].update(bounds=[0, 0, 0, 0]), "unreachable room")

    def test_malformed_dmm_keys_and_rows(self):
        with self.assertRaisesRegex(ValueError, "mixed DMM key lengths"):
            validate(self.layout, self.dmm.replace('"aa" =', '"aaa" =', 1))
        lines = self.dmm.splitlines()
        index = next(i for i, line in enumerate(lines) if len(line) == self.layout["world"]["width"] * 2 and line.isalpha())
        lines[index] = lines[index][:-2]
        with self.assertRaisesRegex(ValueError, "DMM row width"):
            validate(self.layout, "\n".join(lines) + "\n")

    def test_no_active_atoms_or_area_behavior(self):
        for replacement in ("/area/teleport", "/area/controller", "/obj/map_metadata,/area", "/obj/effect/landmark,/area"):
            with self.subTest(replacement=replacement):
                with self.assertRaisesRegex(ValueError, "active"):
                    validate(self.layout, self.dmm.replace(",/area{", "," + replacement + "{", 1))
        with self.assertRaisesRegex(ValueError, "unknown, active or reordered"):
            validate(self.layout, self.dmm.replace("/obj/structure/bed,/turf/floor/wood", "/turf/floor/wood,/obj/structure/bed", 1))

    def test_inactive_dme(self):
        with tempfile.TemporaryDirectory() as directory:
            Path(directory, "civ13.dme").write_text('#include "maps/WIP/dagger_train_home.dmm"\n', encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "registered"):
                validate(self.layout, self.dmm, root=Path(directory))

    def test_non_geometric_dmm_tamper(self):
        self.reject_tile((1, 1, 1), "floor", "not reproducible")


if __name__ == "__main__":
    unittest.main()
