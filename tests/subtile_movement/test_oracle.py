"""Offline arithmetic/receipt contracts; never compiles or runs DreamDaemon."""
from pathlib import Path
import re
import unittest

HERE = Path(__file__).resolve().parent


def target(x, y, sx, sy, dx, dy):
    """Independent Euclidean-division oracle for a cardinal physical request."""
    if any(type(v) is not int for v in (x, y, sx, sy, dx, dy)):
        raise ValueError("integer input")
    if not (0 <= sx < 32 and 0 <= sy < 32):
        raise ValueError("canonical offsets")
    if (dx and dy) or not 1 <= abs(dx) + abs(dy) <= 4:
        raise ValueError("cardinal step")
    qx, rx = divmod(sx + dx, 32)
    qy, ry = divmod(sy + dy, 32)
    return x + qx, y + qy, rx, ry


def displacement(before, after):
    if before["z"] != after["z"]:
        raise ValueError("cross-z is not planar travel")
    return tuple((after[k] - before[k]) * 32 + after[s] - before[s]
                 for k, s in (("x", "sx"), ("y", "sy")))


def exact_motion(row, expected):
    measured = displacement(row["before"], row["after"])
    if measured != expected:
        raise AssertionError("physical_east_four_pixels")
    return measured


def same_position(a, b):
    keys = {"x", "y", "z", "sx", "sy"}
    return (type(a) is dict and type(b) is dict and a.keys() == b.keys() == keys
            and all(type(v) in (int, float) and v == int(v)
                    for row in (a, b) for v in row.values()) and a == b)


def receipt_contract(row, control):
    if (row["byond_version"], row["byond_build"], row["port"]) != (516, 1681, 0):
        raise ValueError("engine or port")
    if row["control"] != control or not 1 <= row["checks"] <= 100:
        raise ValueError("profile or bounds")
    first = row["observations"][0]
    if first["name"] != "first_east":
        raise ValueError("missing first observation")
    if control == "none":
        if row["failed"] or row["error"] is not None or row["checks"] != 42:
            raise ValueError("positive failure")
        exact_motion(first, (4, 0))
    elif control == "cosmetic":
        if row["failed"] != ["physical_east_four_pixels"] or row["error"] != "physical_east_four_pixels" or row["checks"] != 3:
            raise ValueError("wrong control failure")
        if displacement(first["before"], first["after"]) != (0, 0):
            raise ValueError("control physically moved")
    else:
        raise ValueError("unknown profile")


class OfflineOracle(unittest.TestCase):
    def test_scalar_equality_ignores_order_but_rejects_type_or_value_loss(self):
        original = dict(x=2, y=2, z=1, sx=28, sy=0)
        self.assertTrue(same_position(original, dict(reversed(list(original.items())))))
        for bad in (dict(original, sy=None), dict(original, sy="0"),
                    dict(original, sx=28.5), dict(original, sx=27),
                    dict(original, extra=1), {k: v for k, v in original.items() if k != "sy"}):
            self.assertFalse(same_position(original, bad))

    def test_all_offsets_and_cardinal_directions(self):
        for sx in range(32):
            for sy in range(32):
                for dx, dy in ((4, 0), (-4, 0), (0, 4), (0, -4)):
                    x, y, rx, ry = target(3, 3, sx, sy, dx, dy)
                    self.assertEqual(((x - 3) * 32 + rx - sx,
                                      (y - 3) * 32 + ry - sy), (dx, dy))

    def test_reverse_is_exact(self):
        for sx in range(32):
            for sy in range(32):
                for dx, dy in ((4, 0), (-4, 0), (0, 4), (0, -4)):
                    out = target(3, 3, sx, sy, dx, dy)
                    self.assertEqual(target(*out, -dx, -dy), (3, 3, sx, sy))

    def test_malformed_or_out_of_scope_requests(self):
        for dx, dy in ((0, 0), (4, 4), (5, 0), (0.5, 0), ("4", 0), (None, 0)):
            with self.assertRaises(ValueError):
                target(2, 2, 0, 0, dx, dy)
        for sx in (-1, 32, "4"):
            with self.assertRaises(ValueError):
                target(2, 2, sx, 0, 4, 0)

    def test_one_tile_distance_budget_is_eight_four_pixel_substeps(self):
        # Arithmetic comparison only: no claim about real server cadence/cost.
        state = (2, 2, 0, 0)
        for _ in range(8):
            state = target(*state, 4, 0)
        self.assertEqual(state, (3, 2, 0, 0))
        self.assertEqual(8 * 4, 32)
        self.assertNotEqual(4, 32)  # Old whole-step cooldown at4px loses7/8 speed.

    def test_partial_return_is_not_full_success(self):
        before = dict(x=3, y=3, z=1, sx=0, sy=0)
        after = dict(before, sx=2)
        self.assertEqual(displacement(before, after), (2, 0))
        self.assertTrue(2)  # Merely testing truthiness would accept a short slide.
        with self.assertRaises(AssertionError):
            exact_motion(dict(before=before, after=after, engine_return=2), (4, 0))

    def test_cosmetic_control_rejected_even_if_return_claims_success(self):
        before = dict(x=2, y=2, z=1, sx=0, sy=0)
        row = dict(before=before, after=dict(before), engine_return=1, pixel_x=4)
        with self.assertRaisesRegex(AssertionError, "^physical_east_four_pixels$"):
            exact_motion(row, (4, 0))

    def test_cross_z_not_misreported_as_zero_displacement(self):
        before = dict(x=2, y=2, z=1, sx=0, sy=0)
        with self.assertRaises(ValueError):
            displacement(before, dict(before, z=2))

    def test_receipt_profiles_and_wrong_failure_controls(self):
        before = dict(x=2, y=2, z=1, sx=0, sy=0)
        first = dict(name="first_east", before=before, after=dict(before, sx=4))
        good = dict(byond_version=516, byond_build=1681, port=0, checks=42,
                    failed=[], control="none", error=None, observations=[first])
        receipt_contract(good, "none")
        cosmetic = dict(good, control="cosmetic", checks=3,
                        failed=["physical_east_four_pixels"], error="physical_east_four_pixels",
                        observations=[dict(first, after=dict(before))])
        receipt_contract(cosmetic, "cosmetic")
        for bad in (dict(good, port=1234), dict(good, byond_build=1688),
                    dict(cosmetic, failed=["unexpected_exception"]),
                    dict(cosmetic, observations=[first]), dict(good, checks=101)):
            with self.assertRaises(ValueError):
                receipt_contract(bad, bad["control"])

    def test_source_native_seam_has_no_physical_assignment_bypass(self):
        source = (HERE / "kernel.dm").read_text()
        self.assertIn("actor.Move(destination, direction, sx, sy)", source)
        self.assertNotRegex(source, r"actor\.(?:loc|step_x|step_y)\s*=(?!=)")
        self.assertIn("if (cosmetic_control)", source)
        self.assertIn("actor.pixel_x +=", source)
        self.assertIn("calls >= 8", source)
        self.assertIn("deadline < world.time", source)
        self.assertIn("deadline > world.time + 1", source)
        self.assertIn("saved[\"z\"] != actor.z", source)

    def test_fixture_is_opt_in_resource_free_closed_and_exactly_controlled(self):
        dme = (HERE / "prototype.dme").read_text()
        fixture = (HERE / "fixture.dm").read_text()
        self.assertEqual(re.findall(r'#include "([^"]+)"', dme), ["kernel.dm", "fixture.dm"])
        self.assertIn('#define SUBTILE_FEASIBILITY', dme)
        self.assertIn('text2file("closed", "port-closed.txt")', fixture)
        self.assertNotIn('text2file("closed\\n", "port-closed.txt")', fixture)
        self.assertIn('"scalar_roundtrip_values"', fixture)
        self.assertIn('var/present = (key in L)', fixture)
        self.assertNotIn('var/present = key in L', fixture)
        self.assertNotIn('json_encode(a) == json_encode(b)', fixture)
        self.assertEqual(fixture.count('F.Flush()'), 1)
        self.assertLess(fixture.index('F["position"] >> loaded'), fixture.index('F["/position"] >> absolute_loaded'))
        self.assertIn('probe_assert(probe_same(saved, loaded), "scalar_disk_roundtrip")', fixture)
        self.assertNotIn('probe_same(saved, absolute_loaded)', fixture)
        self.assertIn('copytext(exported, 1, 4097)', fixture)
        self.assertIn('movement_mode = LEGACY_MOVEMENT_MODE', fixture)
        self.assertIn('hub = ""', fixture)
        self.assertIn('visibility = 0', fixture)
        self.assertIn('/client/New()\n\tdel(src)', fixture)
        self.assertIn('/world/Topic()\n\treturn null', fixture)
        self.assertIn('"physical_east_four_pixels"', fixture)
        self.assertIn('"partial_success_is_not_full_success"', fixture)
        self.assertIn('"blocked_placement_never_forces_loc"', fixture)
        self.assertNotRegex(dme + fixture, r"(?:shell\(|browse\(|new /client|https?://)")
        for name in ("kernel.dm", "fixture.dm"):
            self.assertNotRegex((HERE / name).read_text(), r"'[^'\n]+\.(?:dmi|png|ogg|wav)'" )


if __name__ == "__main__":
    unittest.main(verbosity=2)
