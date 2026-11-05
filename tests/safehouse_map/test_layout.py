"""Negative controls use actual serialized DMM and isolated manifest copies."""
import copy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_map  # noqa: E402
from validate_map import parse_dmm, validate, validate_template  # noqa: E402


class LayoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.grid, cls.layout = build_map.build()
        cls.dmm = build_map.render_dmm(cls.grid)
        cls.template = build_map.template_descriptor(cls.layout)

    def reject_layout(self, mutate, message):
        layout = copy.deepcopy(self.layout)
        mutate(layout)
        with self.assertRaisesRegex(ValueError, message):
            validate(layout, self.dmm)

    def reject_tile(self, xyz, kind, message):
        self.reject_tiles([(xyz, kind)], message)

    def reject_tiles(self, changes, message):
        grid = self.grid.copy()
        for xyz, kind in changes:
            grid[xyz] = kind, grid[xyz][1]
        with self.assertRaisesRegex(ValueError, message):
            validate(self.layout, build_map.render_dmm(grid))

    def world(self, point, slot=None):
        slot = slot or self.layout["prototype"]["slot"]
        x, y, z = next(s for s in self.layout["slots"] if s["id"] == slot)["origin"]
        return x + point[0], y + point[1], z + point[2]

    def test_generated_and_checked_in_artifacts(self):
        result = validate(self.layout, self.dmm, self.template)
        self.assertEqual(result["slots"], 2)
        self.assertEqual(build_map.MAP_PATH.read_text(encoding="utf-8"), self.dmm)
        self.assertEqual(json.loads(build_map.LAYOUT_PATH.read_text(encoding="utf-8")), self.layout)
        self.assertEqual(json.loads(build_map.TEMPLATE_PATH.read_text(encoding="utf-8")), self.template)

    def test_dmm_is_restricted_and_literal(self):
        grid = parse_dmm(self.dmm, self.layout["world"])
        self.assertEqual(len(grid), build_map.SIZE * build_map.SIZE * build_map.WORLD_LEVELS)
        self.assertNotIn("TRUE", self.dmm)
        self.assertNotIn("FALSE", self.dmm)
        with self.assertRaisesRegex(ValueError, "literal values"):
            parse_dmm(self.dmm.replace("locked = 1", "locked = TRUE", 1), self.layout["world"])
        with self.assertRaisesRegex(ValueError, "unknown, active or reordered"):
            parse_dmm(self.dmm.replace("/obj/structure/bed,", "/obj/structure/bed/roller,", 1), self.layout["world"])

    def test_template_descriptor_is_exact(self):
        self.assertEqual(self.template, {
            "schema": 1, "template_id": "safehouse_draft_v1", "revision": 1, "width": 40, "height": 48,
            "decks": [{"layer": 1, "id": "ground"}, {"layer": 2, "id": "upper"}], "berths": []})
        for mutate in (lambda t: t.update(revision=2), lambda t: t.update(berths=["raid_west"]),
                       lambda t: t.update(origin=[1, 1, 1]), lambda t: t.pop("decks")):
            template = copy.deepcopy(self.template)
            mutate(template)
            with self.assertRaisesRegex(ValueError, "template descriptor differs"):
                validate_template(self.layout, template)
        layout = copy.deepcopy(self.layout)
        layout["template_revision"] = "1"
        with self.assertRaisesRegex(ValueError, "explicit positive integer template_revision"):
            build_map.template_descriptor(layout)

    def test_airlock_is_the_only_boundary_opening(self):
        airlock = self.layout["protected"]["airlock"]
        self.reject_tile(self.world((airlock["inner_door"][0], airlock["inner_door"][1], 0)), "safe", "airlock gate placeholders")
        self.reject_tile(self.world((airlock["outer_door"][0], airlock["outer_door"][1], 0)), "door", "airlock gate placeholders")
        self.reject_tile(self.world((5, 0, 0)), "door", "ground hull breach")
        self.reject_tile(self.world((0, 20, 0)), "safe", "ground hull breach")
        self.reject_tile(self.world((39, 20, 1)), "safe", "upper hull breach")
        # A gap in the vestibule enclosure would connect the vestibule past a closed door.
        self.reject_tile(self.world((16, 3, 0)), "safe", "airlock enclosure")
        self.reject_tile(self.world((18, 3, 0)), "crate", "airlock interior clear")

    def test_rooms_markers_and_clear_zones(self):
        self.reject_tiles([(self.world((14, 22, 0)), "wall"), (self.world((14, 23, 0)), "wall")], "room unreachable: stash")
        self.reject_tile(self.world((20, 12, 0)), "hull", "room contains hull: entry_hall")
        self.reject_tile(self.world((30, 30, 0)), "dirt", "prototype volume differs from the generator")
        self.reject_tile(self.world((7, 22, 0)), "rack", "account marker missing: house_marker")
        self.reject_tile(self.world((31, 3, 0)), "crate", "keep clear obstructed: vehicle_bay")
        self.reject_tile(self.world((5, 40, 1)), "rack", "build pad not clear: west_upgrade")
        self.reject_tile(self.world((19, 20, 0)), "table", "keep clear obstructed: ground_spine")
        self.reject_tile(self.world((17, 29, 1)), "safe", "stair endpoints")
        self.reject_layout(lambda l: l["account_markers"].update(secure_crate=[9, 25, 0]), "account marker missing: secure_crate")
        self.reject_layout(lambda l: l["protected"]["sustenance"].update(rooms=["garage", "nowhere"]), "sustenance rooms exist")
        self.reject_layout(lambda l: l["stairs"].pop(), "two stair routes")

    def test_demo_slots_are_bounded_and_empty(self):
        self.reject_tile(self.world((10, 10, 0), "home_east"), "crate", "empty demonstration slot")
        self.reject_tile(self.world((10, 10, 1), "home_east"), "rack", "empty demonstration slot")
        self.reject_layout(lambda l: l["slots"][1].update(reserved_bounds=[60, 34, 117, 93]), "overlapping slot reservations")
        self.reject_layout(lambda l: l["slots"][1].update(reserved_bounds=[66, 34, 140, 93]), "slot inside world")
        self.reject_layout(lambda l: l["slots"][0].update(reserved_z=[1, 3]), "slot z interval")

    def test_declared_protection_matches_source(self):
        self.reject_layout(lambda l: l["structure_protection"]["wall_tiles"].pop(), "structure protection list stale: wall_tiles")
        self.reject_layout(lambda l: l["structure_protection"].update(enforced_by_this_map=True), "map claims enforcement")
        self.reject_layout(lambda l: l["structure_protection"].update(player_built_contents_inherit_protection=True),
                           "player-built contents must not inherit protection")
        self.reject_layout(lambda l: l["protected"]["airlock"].update(interlocked=False), "airlock requirement flag: interlocked")
        self.reject_layout(lambda l: l["levels"][1].update(protected=False), "every deck is protected")
        self.reject_layout(lambda l: l.update(kind="dagger"), "layout schema")


if __name__ == "__main__":
    unittest.main()
