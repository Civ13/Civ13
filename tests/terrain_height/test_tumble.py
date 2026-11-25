"""Source contracts for completed slope movement and the owned tumble route."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MOVEMENT = (ROOT / "code/game/mob/mob_movement.dm").read_text(encoding="utf-8")
MODULE = (ROOT / "code/modules/1713/terrain_height.dm").read_text(encoding="utf-8")
PROCESSOR = (ROOT / "code/processes/throwing.dm").read_text(encoding="utf-8")


class TerrainTumbleWiring(unittest.TestCase):
    def test_steep_step_uses_post_move_actor_and_position(self):
        charge = MOVEMENT.index("terrain_completed_step(H, slope_origin, n")
        self.assertGreater(charge, MOVEMENT.index(". = mob.SelfMove(n, direct)"))
        self.assertIn("H.client == src", MOVEMENT[MOVEMENT.index("skipgrab:"):charge])
        self.assertNotIn("terrain_climb_effects(H, mob_loc", MOVEMENT)
        completed = MODULE.split("/proc/terrain_completed_step", 1)[1].split("/proc/terrain_trip_check", 1)[0]
        self.assertLess(completed.index("if (distance_fraction <= 0)"), completed.index("terrain_climb_effects"))
        self.assertIn("if (arrival == destination)", completed)

    def test_tumble_debits_only_confirmed_route_hops(self):
        tumble, hop = MODULE.split("/proc/terrain_tumble(mob", 1)[1].split("/proc/terrain_tumble_hop", 1)
        self.assertNotIn("TERRAIN_TUMBLE_DAMAGE * path.len", tumble)
        self.assertIn('H.throw_flight_token["terrain_path"] = path', tumble)
        self.assertIn("var/turf/target = path[1]", hop)
        self.assertLess(hop.index("if (!advanced || H.loc != target)"),
                        hop.index("H.adjustBruteLoss(TERRAIN_TUMBLE_DAMAGE)"))
        self.assertIn("H.hit_check(H.speed, TRUE)", hop)
        self.assertLess(PROCESSOR.index("terrain_tumble_hop(AM, flight_token)"),
                        PROCESSOR.index("switch (AM.throwmode)"))

    def test_delayed_trip_and_new_flight_have_independent_ownership(self):
        callback = MODULE.split("/proc/terrain_tumble_arrival", 1)[1].split("/proc/", 1)[0]
        self.assertIn("H.client != owner", callback)
        self.assertIn("H.loc != arrival", callback)
        self.assertIn("H.throwing", callback)
        hop = MODULE.split("/proc/terrain_tumble_hop", 1)[1].split("/proc/", 1)[0]
        self.assertIn("H.throw_flight_token != flight_token", hop)
        self.assertIn('origin != flight_token["terrain_arrival"]', hop)


if __name__ == "__main__":
    unittest.main()
