"""Negative controls use actual serialized DMM and isolated manifest copies."""
import copy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_map as home  # noqa: E402
import build_raid_train  # noqa: E402
from validate_raid_train import parse_dmm, validate  # noqa: E402


class RaidTrainTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.grid, cls.layout = build_raid_train.build()
        cls.dmm = build_raid_train.render_dmm(cls.grid)

    def reject_layout(self, mutate, message):
        layout = copy.deepcopy(self.layout)
        mutate(layout)
        with self.assertRaisesRegex(ValueError, message):
            validate(layout, self.dmm)

    def reject_tiles(self, changes, message):
        grid = self.grid.copy()
        for xyz, kind in changes:
            grid[xyz] = kind, grid[xyz][1]
        with self.assertRaisesRegex(ValueError, message):
            validate(self.layout, build_raid_train.render_dmm(grid))

    def train(self, x, y):
        ox, oy, oz = build_raid_train.TRAIN_ORIGIN
        return ox + x, oy + y, oz

    def test_generated_and_checked_in_artifacts(self):
        result = validate(self.layout, self.dmm)
        self.assertEqual(result["sections"], 6)
        self.assertEqual(result["berths"], 2)
        self.assertEqual(build_raid_train.MAP_PATH.read_text(encoding="utf-8"), self.dmm)
        self.assertEqual(json.loads(build_raid_train.LAYOUT_PATH.read_text(encoding="utf-8")), self.layout)
        # The raid study binds to the current home draft, so a template change is visible here.
        self.assertEqual(self.layout["home_template"]["template_id"], home.manifest()["template_id"])

    def test_dmm_is_restricted_and_literal(self):
        grid = parse_dmm(self.dmm, self.layout["world"])
        self.assertEqual(len(grid), build_raid_train.SIZE ** 2 * build_raid_train.WORLD_LEVELS)
        self.assertNotIn("TRUE", self.dmm)
        self.assertNotIn("locked = 1", self.dmm)
        with self.assertRaisesRegex(ValueError, "literal values"):
            parse_dmm(self.dmm.replace("dir = 1", "dir = NORTH", 1) if "dir = 1" in self.dmm
                      else self.dmm.replace('location = 0', 'location = FALSE', 1), self.layout["world"])
        with self.assertRaisesRegex(ValueError, "unknown, active or reordered"):
            parse_dmm(self.dmm.replace("/obj/structure/closet/crate,", "/obj/structure/closet/crate/secure,", 1), self.layout["world"])

    def test_target_doors_stay_breachable(self):
        self.reject_tiles([(self.train(11, 53), "locked_door")], "target compartment door locked")
        self.reject_tiles([(self.train(11, 53), "hull"), (self.train(12, 53), "hull")], "coupling row must be hull with breach doors")
        self.reject_tiles([(self.train(5, 53), "floor")], "coupling row must be hull with breach doors")
        self.reject_tiles([(self.train(0, 150), "door")], "undeclared hull opening")
        self.reject_tiles([(self.train(0, 62), "hull")], "declared side opening is blocked")
        self.reject_layout(lambda l: l["target_train"].update(locked_doors_permitted=True), "target door policy")
        self.reject_layout(lambda l: l["target_train"].update(inherits_dagger_boundary_protection=True), "must not inherit Dagger protection")

    def test_sections_are_ordered_reachable_and_separated(self):
        self.reject_layout(lambda l: l["sections"][4].update(tier=2), "tiers must not fall toward the front")
        self.reject_layout(lambda l: l["sections"][0].update(loot_anchor_count=0), "every section needs loot anchors")
        self.reject_layout(lambda l: l["sections"][0].update(loot_anchor_count=9), "loot anchor count stale")
        self.reject_layout(lambda l: l["sections"][0]["loot_anchors"].pop(), "loot anchors stale")
        self.reject_layout(lambda l: l["sections"][2].update(loot_table="workshop"), "must not choose loot tables")
        # Sealing the vault cage door leaves its interior unreachable.
        self.reject_tiles([(self.train(11, 139), "cage"), (self.train(12, 139), "cage")], "loot anchor unreachable: vault")
        # A breach in the partition between two sections defeats closed-door separation.
        self.reject_tiles([(self.train(5, 94), "floor")], "coupling row must be hull with breach doors")
        self.reject_tiles([(self.train(11, 73), "floor")], "structure list stale: breach_doors")
        self.reject_tiles([(self.train(3, 70), "dirt")], "target train differs from the generator")

    def test_berths_bridges_and_arrivals(self):
        west = next(s for s in self.layout["slots"] if s["id"] == "raid_west")
        x, y, z = west["origin"]
        self.reject_tiles([((x + 5, y + 5, z), "crate")], "berth footprint must be empty on every deck")
        self.reject_tiles([((x + 5, y + 5, z + 3), "rack")], "berth footprint must be empty on every deck")
        bx, by, bz = west["bridge_cells"][0]
        self.reject_tiles([((bx, by, bz), "hull")], "bridge cells missing")
        self.reject_tiles([((bx + 3, by, bz), "hull"), ((bx + 3, by + 1, bz), "hull"), ((bx + 3, by + 2, bz), "hull")], "bridge cells missing")
        self.reject_layout(lambda l: l["slots"][1].update(reserved_bounds=[100, 72, 186, 185]), "berth reservation overlaps shared space")
        self.reject_layout(lambda l: l["slots"][0].update(reserved_z=[1, 3]), "berth z interval")
        self.reject_layout(lambda l: l["slots"][0]["boarding_ports"].pop(), "boarding ports follow the Dagger boarding bands")
        self.reject_layout(lambda l: l["berth_geometry_groups"][0].update(exclusive_reservation=True), "berth pair geometry")
        self.reject_layout(lambda l: l["slots"].pop(), "berth pair geometry")

    def test_platform_connectivity(self):
        head = next(e for e in self.layout["platforms"] if e["id"] == "head_south")
        hx0, hy0, hx1, hy1 = head["bounds"]
        self.reject_tiles([((x, y, 1), "hull") for x in range(hx0, hx1 + 1) for y in range(hy0, hy1 + 1)
                           if x in (120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130)] +
                          [((x, y, 1), "hull") for x in range(120, 131) for y in range(229, 237)], "platforms and heads must connect")

    def test_declarations_match_source(self):
        self.reject_layout(lambda l: l["structure"]["breach_doors"].pop(), "structure list stale: breach_doors")
        self.reject_layout(lambda l: l["structure"].update(enforced_by_this_map=True), "map claims enforcement")
        self.reject_layout(lambda l: l["raid_access"].update(pass_prices={"vault": 5}), "must not choose pass_prices")
        self.reject_layout(lambda l: l["raid_access"].update(required_inputs=["loaded_fuel"]), "raid inputs")
        self.reject_layout(lambda l: l["home_template"].update(width=31), "home template binding")
        self.reject_layout(lambda l: l.update(study_id="other"), "layout schema")


if __name__ == "__main__":
    unittest.main()
