"""Offline source-projected waypoint selection; not a native BYOND test."""
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "code/game/mob/living/simple_animal/hostile/humans/human.dm"
DECLARATION = "/mob/living/simple_animal/hostile/human/proc/get_nearest_waypoint"
spec = spec_from_file_location("source_adapter", ROOT / "tests/save_movement/source_adapter.py")
adapter = module_from_spec(spec)
spec.loader.exec_module(adapter)


class Turf:
    def __init__(self, x, y, z=1):
        self.x, self.y, self.z = x, y, z


class DMList(list):
    def __getitem__(self, index):
        return super().__getitem__(index - 1)


def select(source, origin, destination, points, *, container=False, faction="blue", has_targets=True):
    """Inject only engine boundaries; execute the complete selected DM procedure."""
    adjustments = (
        ("var/best_dist = my_dist ? my_dist : INFINITY", "var/best_dist = (my_dist if my_dist else INFINITY)"),
        ("while(search_dist <= 80)", "while search_dist <= 80:"),
    )
    for old, new in adjustments:
        assert source.count(old) == 1, old
        source = source.replace(old, new, 1)
    # DM uninitialized variables default to null; Python requires an assignment.
    source = source.replace("var/dist_to_dest\n", "var/dist_to_dest = null\n")
    loc = SimpleNamespace(turf=origin) if container else origin
    mob = SimpleNamespace(loc=loc, faction=faction)
    coords = {(t.x, t.y, t.z): t for t, _, _ in points if t is not None}
    targets = [DMList([None, owner, *((t.x, t.y, t.z) if t is not None else (999, 999, 1))])
               for t, owner, _ in points]
    landmarks = [SimpleNamespace(loc=t, controller=controller)
                 for t, _, controller in points if t is not None and controller is not None]
    calls = []

    def get_turf(atom):
        if atom is mob:
            return origin
        if atom is loc and container:
            return origin
        return atom if isinstance(atom, Turf) else None

    def get_dist(left, right):
        left, right = get_turf(left), get_turf(right)
        assert left is not None and right is not None
        calls.append((left, right))
        return max(abs(left.x - right.x), abs(left.y - right.y)) if left.z == right.z else -1

    env = dict(src=mob, map=SimpleNamespace(faction_targets=targets if has_targets else None),
               get_turf=get_turf, get_dist=get_dist, INFINITY=10**10,
               locate=lambda x, y, z: coords.get((x, y, z)),
               landmarks_list=landmarks, typed_iter=lambda items, typ: iter(items))
    proc = adapter.project(source, DECLARATION, "destination", env, method=True)
    return proc(destination), calls


class WaypointSelection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding="utf-8-sig")

    def test_self_patrol_eligibility_distance_and_first_tie(self):
        origin = Turf(0, 0)
        near = Turf(5, 0)
        enemy = Turf(6, 0)
        a, b = Turf(7, 0), Turf(7, 1)
        wrong_faction = Turf(6, 1)
        points = [(None, "all", None), (near, "all", None), (wrong_faction, "red", None),
                  (enemy, "all", "red"), (a, "blue", None), (b, "all", None)]
        self.assertIs(select(self.source, origin, origin, points)[0], a)
        self.assertIs(select(self.source, origin, origin, points[::-1])[0], b)
        self.assertIsNone(select(self.source, origin, None, points)[0])
        self.assertIsNone(select(self.source, origin, origin, points, has_targets=False)[0])

    def test_patrol_skips_only_the_unused_destination_distance(self):
        origin, waypoint, destination = Turf(0, 0), Turf(7, 0), Turf(20, 0)
        points = [(waypoint, "all", None)]
        selected, calls = select(self.source, origin, origin, points)
        self.assertIs(selected, waypoint)
        self.assertEqual(len(calls), 3)
        selected, calls = select(self.source, origin, destination, points)
        self.assertIs(selected, waypoint)
        self.assertEqual(len(calls), 3)

        optimized = "var/dist_to_dest\n\t\t\tif(!self_targeting)\n\t\t\t\tdist_to_dest = get_dist(T, dest_turf)"
        original = "var/dist_to_dest = get_dist(T, dest_turf)"
        self.assertEqual(self.source.count(optimized), 1)
        mutant = self.source.replace(optimized, original, 1)
        selected, calls = select(mutant, origin, origin, points)
        self.assertIs(selected, waypoint)
        self.assertEqual(len(calls), 4)

    def test_normal_destination_and_container_location(self):
        origin, destination = Turf(0, 0), Turf(20, 0)
        a, b = Turf(9, 0), Turf(9, 1)
        points = [(a, "all", None), (b, "blue", None)]
        self.assertIs(select(self.source, origin, destination, points)[0], a)
        self.assertIs(select(self.source, origin, destination, points[::-1])[0], b)
        # loc is the container, not its turf; the fallback still admits that turf.
        self.assertIs(select(self.source, origin, destination, [(origin, "all", None)], container=True)[0], origin)
        self.assertIsNone(select(self.source, origin, destination, [(origin, "all", None)])[0])

    def test_fallback_and_five_tile_negative_control(self):
        origin, reached, enemy = Turf(0, 0), Turf(5, 0), Turf(6, 0)
        points = [(reached, "all", "red"), (enemy, "all", "red")]
        self.assertIs(select(self.source, origin, origin, points)[0], enemy)
        self.assertEqual(self.source.count("get_dist(T, loc) <= 5"), 2)
        mutant = self.source.replace("get_dist(T, loc) <= 5", "get_dist(T, loc) < 5")
        self.assertIs(select(mutant, origin, origin, points)[0], reached)
        self.assertIsNone(select(self.source, origin, origin, [(Turf(81, 0), "all", "red")])[0])


if __name__ == "__main__":
    unittest.main()
