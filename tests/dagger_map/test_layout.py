"""Negative controls use actual serialized DMM and isolated manifest copies."""
import copy
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch

import build_map
from validate_map import parse_dmm, validate


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

    def test_generated_and_checked_in_artifacts(self):
        self.assertEqual(validate(self.layout, self.dmm)["raid_berths"], 2)
        self.assertEqual(build_map.MAP_PATH.read_text(encoding="utf-8"), self.dmm)

    def test_unresolved_dmm_constants_even_in_source_palette(self):
        original = build_map.PALETTE["gate"]
        for value in ("TRUE", "FALSE", "NORTH"):
            with self.subTest(value=value):
                bad_gate = (original[0].replace("locked = 1", f"locked = {value}"), *original[1:])
                with patch.dict(build_map.PALETTE, {"gate": bad_gate}):
                    with self.assertRaisesRegex(ValueError, "literal values"):
                        parse_dmm(build_map.render_dmm(self.grid), self.layout["world"])
        import json
        self.assertEqual(json.loads(build_map.LAYOUT_PATH.read_text(encoding="utf-8")), self.layout)

    def test_coordinate_orientation(self):
        grid = parse_dmm(self.dmm, self.layout["world"])
        self.assertEqual(grid[27, 44, 1][0], "gate")
        self.assertEqual(grid[20, 50, 1][0], "door")
        self.assertEqual(grid[54, 62, 2][0], "platform")

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
        self.reject_layout(lambda x: x["slots"][3].update(reserved_bounds=[52, 33, 82, 89]), "padded reservations overlap")

    def test_offset_footprint_does_not_fit(self):
        self.reject_layout(lambda x: x["slots"][3].update(origin=[70, 36, 2]), "does not fit")

    def test_world_bounds(self):
        self.reject_layout(lambda x: x["slots"][3].update(reserved_bounds=[62, 33, 129, 89]), "out of bounds")

    def test_berth_mask_gap(self):
        def mutate(layout):
            layout["slots"][2]["berth_mask_rows_south_to_north"][0] = "0" + "1" * 14
        self.reject_layout(mutate, "berth mask gaps")

    def test_bridge_mask_gap(self):
        self.reject_layout(lambda x: x["slots"][2]["bridge_cells"].pop(), "bridge mask gaps")

    def test_platform_anchor_offset(self):
        self.reject_layout(lambda x: x["slots"][2]["platform_anchors"][0].__setitem__(0, 55), "anchor offset")

    def test_actual_empty_destination_cells(self):
        for coordinate in ((84, 24, 1), (36, 36, 2), (79, 86, 2)):
            with self.subTest(coordinate=coordinate):
                self.reject_tile(coordinate, "crate", "destination DMM is occupied")

    def test_actual_bridge_blocked(self):
        self.reject_tile((52, 62, 2), "hull", "blocked anchor bridge")

    def test_unsafe_boarding_declaration(self):
        self.reject_layout(lambda x: x["exposed"]["boarding_ports"].append([0, 10]), "boarding ports")

    def test_actual_protected_exterior_open(self):
        self.reject_tile((20, 34, 1), "door", "protected exterior is open")

    def test_actual_gate_bypass(self):
        self.reject_tile((26, 44, 1), "floor", "bypasses boundary gate")

    def test_actual_gate_removed(self):
        self.reject_tile((27, 44, 1), "floor", "missing boundary gate")

    def test_actual_anchor_and_pad_access(self):
        self.reject_tile((27, 54, 1), "hull", "unreachable anchor")
        self.reject_tile((22, 52, 1), "hull", "blocked build pad")

    def test_unreachable_room(self):
        self.reject_tile((25, 28, 1), "hull", "disconnected internal floor")

    def test_malformed_dmm_keys_and_rows(self):
        with self.assertRaisesRegex(ValueError, "mixed DMM key lengths"):
            validate(self.layout, self.dmm.replace('"aa" =', '"aaa" =', 1))
        lines = self.dmm.splitlines()
        index = next(i for i, line in enumerate(lines) if len(line) == 256 and line.isalpha())
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
