"""Offline instance descriptor and projection contracts; no DM or game startup."""
import copy
import json
import unittest

import build_map
from validate_map import extrude, rectangle, translated, validate_template


class TemplateTests(unittest.TestCase):
    def setUp(self):
        self.layout = build_map.manifest()
        # Literal consumer contract agreed with instance ABI v1, not copied
        # from the exporter. Schema 2 and the name's v4 are not revision values.
        self.expected = {
            "schema": 1, "template_id": "dagger_home_draft_v4", "revision": 1,
            "width": 30, "height": 102,
            "decks": [{"layer": 1, "id": "ground"}, {"layer": 2, "id": "upper_1"},
                      {"layer": 3, "id": "upper_2"}, {"layer": 4, "id": "roof"}],
            "berths": ["raid_west", "raid_east"],
        }

    def test_exact_consumer_contract_and_generated_file(self):
        self.assertEqual(build_map.template_descriptor(self.layout), self.expected)
        self.assertEqual(json.loads(build_map.TEMPLATE_PATH.read_text(encoding="utf-8")), self.expected)
        validate_template(self.layout, self.expected)

    def test_revision_must_be_explicit(self):
        del self.layout["template_revision"]
        with self.assertRaisesRegex(ValueError, "template_revision"):
            build_map.template_descriptor(self.layout)
        for value in (None, True, 0, -1, 1.5, "1", 16777216):
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "template_revision"):
                self.layout["template_revision"] = value
                build_map.template_descriptor(self.layout)
        self.layout["template_revision"] = 3
        self.assertEqual(build_map.template_descriptor(self.layout)["revision"], 3)
        self.assertEqual(self.layout["schema_version"], 2)

    def test_descriptor_drift_is_rejected(self):
        mutations = [
            lambda t: t.pop("revision"), lambda t: t.update(origin=[72, 72, 5]),
            lambda t: t.update(schema=2), lambda t: t.update(revision=2),
            lambda t: t.update(revision=True), lambda t: t.update(template_id="other"),
            lambda t: t.update(width=102, height=30), lambda t: t.update(width=42, height=114),
            lambda t: t.update(width=256, height=256), lambda t: t["decks"].pop(),
            lambda t: t["decks"].reverse(), lambda t: t["decks"][0].update(layer=0),
            lambda t: t["decks"][1].update(id="ground"), lambda t: t["berths"].pop(),
            lambda t: t.update(berths=["raid_west", "raid_west"]),
            lambda t: t.update(berths=["raid_west", "home_east"]),
        ]
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index):
                template = copy.deepcopy(self.expected)
                mutate(template)
                with self.assertRaisesRegex(ValueError, "template descriptor"):
                    validate_template(self.layout, template)

    def test_both_berths_project_all_four_decks_without_extra_origin_offset(self):
        footprint = extrude(rectangle(self.layout["footprint"]["bounds"]), range(4))
        expected_bounds = {"raid_west": (72, 72, 5, 101, 173, 8),
                           "raid_east": (130, 72, 5, 159, 173, 8)}
        placements = []
        for slot in self.layout["slots"]:
            if slot["kind"] != "raid_berth":
                continue
            points = translated(footprint, slot["origin"])
            self.assertEqual(len(points), 12240)
            actual_bounds = tuple(min(p[i] for p in points) for i in range(3)) + tuple(
                max(p[i] for p in points) for i in range(3))
            self.assertEqual(actual_bounds, expected_bounds[slot["id"]])
            for z in range(5, 9):
                self.assertEqual(sum(p[2] == z for p in points), 3060)
            # Padded clearance stays separate from the strict template fields.
            clearance = extrude(rectangle(slot["reserved_bounds"]), range(5, 9))
            self.assertEqual(len(clearance), 19152)
            self.assertLess(points, clearance)
            placements.append(points)
        self.assertEqual(len(placements), 2)
        self.assertFalse(placements[0] & placements[1])

    def test_projection_rejects_malformed_origin_even_with_no_points(self):
        for origin in ((1, 2), (1, 2, 3, 4), (1, 2, True), (1, 2, 3.0), "123", None):
            with self.subTest(origin=origin), self.assertRaisesRegex(ValueError, "integer XYZ"):
                translated([], origin)

    def test_projection_rejects_malformed_points(self):
        for point in ((0, 0), (0, 0, 0, 0), (0, False, 0), (0, 0, 0.0), "000", None):
            with self.subTest(point=point), self.assertRaisesRegex(ValueError, "integer XYZ"):
                translated([point], [72, 72, 5])


if __name__ == "__main__":
    unittest.main()
