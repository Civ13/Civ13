"""Offline checks for the scripted Voyage chart lifecycle. See the native probe."""
from pathlib import Path
import unittest

SOURCE = (Path(__file__).resolve().parents[2]
          / "code/game/objects/map_metadata/voyage.dm").read_text(encoding="utf-8")


def block(path):
    start = SOURCE.index("\n" + path)
    end = SOURCE.find("\n/", start + 2)
    return SOURCE[start:] if end < 0 else SOURCE[start:end]


class VoyageNavigation(unittest.TestCase):
    def test_wheel_revalidates_snapshot_and_access_on_both_sides_of_wait(self):
        wheel = block("/obj/structure/voyage/shipwheel\n")
        prompt = wheel.index("var/choice = choose_course(")
        wait = wheel.index("if (!turn_wheel(H)")
        commit = wheel.index("nmap.nav_approach = offered")
        self.assertLess(wheel.index("var/list/offered = nmap.current_approach()"), prompt)
        for bounds in ((prompt, wait), (wait, commit)):
            self.assertIn("!steering_is_allowed(H, nmap)", wheel[slice(*bounds)])
            self.assertIn("!can_approach(H, nmap, offered)", wheel[slice(*bounds)])
        self.assertIn("!(choice in options)", wheel[prompt:wait])
        allowance = block("/obj/structure/voyage/shipwheel/proc/steering_is_allowed")
        self.assertIn("!nmap.ship_anchored && !nmap.inzone && can_use_wheel(H)", allowance)
        self.assertIn("Adjacent(H)", block("/obj/structure/voyage/shipwheel/proc/can_use_wheel"))

    def test_navigation_dispatches_only_exact_current_order_before_cardinal_travel(self):
        snapshot = block("/obj/map_metadata/voyage/proc/approach_is_current")
        for guard in ("order[1] != latitude", "order[2] != longitude", "cell[3] == order[4]"):
            self.assertIn(guard, snapshot)
        nav = block("/obj/map_metadata/voyage/proc/nav()")
        self.assertIn("if (approach_is_current(nav_approach) && !approach_is_on_cooldown(nav_approach))", nav)
        self.assertIn("enter_event(nav_approach[3], nav_approach[4])", nav)
        self.assertIn("nav_approach = null\n\t\t\t\t\tswitch(navdirection)", nav)
        self.assertIn("load_map(destination)", block("/obj/map_metadata/voyage/proc/enter_event"))

    def test_departure_clears_order_retiring_only_matching_nested_ship_rows(self):
        depart = block("/obj/map_metadata/voyage/proc/abandon_event")
        self.assertLess(depart.index("nav_approach = null"), depart.index("navmoving = TRUE"))
        self.assertIn("for (var/i = ships.len, i >= 1, i--)", depart)
        self.assertIn("if (encounter[3] == latitude && encounter[4] == longitude)", depart)
        self.assertIn("ships.Cut(i, i + 1)", depart)
        self.assertIn('if (retired_ship && cell && approach_kind(cell[3]) == "ship")', depart)
        self.assertIn('cell[3] = "sea"', depart)
        self.assertIn("L1[4] = world.time + 18000", depart)
        self.assertIn("L2[4] = world.time + 18000", depart)


if __name__ == "__main__":
    unittest.main()
