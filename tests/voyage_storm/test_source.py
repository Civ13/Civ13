"""Source boundaries around the production Voyage squall decision."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def dm(file, proc):
    source = (ROOT / f"code/modules/naval/{file}.dm").read_text(encoding="utf-8")
    return re.search(r"^/obj/structure/hull_tiller/proc/" + re.escape(proc)
                     + r"\(.*?(?=^/|\Z)", source, re.M | re.S).group()


class VoyageStorm(unittest.TestCase):
    def test_warning_does_not_remove_cargo_or_immediately_delay_voyage(self):
        event = dm("voyage_provisions", "voyage_event")
        self.assertIn('!("storm" in done) && prob(VOYAGE_STORM_CHANCE)', event)
        self.assertLess(event.index('done += "storm"'), event.index("voyage_storm(mine)"))
        warning = dm("voyage_provisions", "voyage_storm")
        self.assertIn('mine["storm_until"] = world.time + VOYAGE_STORM_DECISION', warning)
        self.assertNotIn("qdel(", warning)
        self.assertNotIn('mine["ends"]', warning)

    def test_only_valid_crew_of_exact_voyage_can_answer_sleeping_prompt(self):
        chooser = dm("voyage_provisions", "voyage_storm_can_choose")
        for guard in ("H.incapacitated()", "voyage == mine", 'mine["storm_until"] > world.time',
                      "H.z == z", "get_dist(H, src) <= 1", "H in voyage_crew()",
                      "craft.helm_access(H) == CRAFT_HELM_FREE", "!crossing_hold_text()",
                      "persistence_save_in_progress"):
            self.assertIn(guard, chooser)
        menu = dm("ship_voyage", "voyage_status_menu")
        prompt = menu.index("var/choice = WWinput(")
        self.assertGreater(menu.index("voyage != mine", prompt), prompt)
        self.assertLess(menu.index("if (voyage_storm_can_choose(H, mine))", prompt),
                        menu.index("voyage_storm_resolve(", prompt))

    def test_timeout_resolves_before_any_landfall_transfer(self):
        tick = dm("ship_voyage", "voyage_tick")
        self.assertIn('if (world.time < mine["ends"] || mine["storm_until"])', tick)
        self.assertIn('if (world.time >= mine["storm_until"])\n\t\t\t\tvoyage_storm_resolve(mine)', tick)
        self.assertLess(tick.index("voyage_storm_resolve(mine)"), tick.index("voyage_lane_landfall"))

    def test_resolution_is_consumed_before_any_effect(self):
        resolve = dm("voyage_provisions", "voyage_storm_resolve")
        self.assertIn('voyage != mine || !mine["storm_until"]', resolve)
        self.assertLess(resolve.index('mine["storm_until"] = null'), resolve.index("if (!press_on)"))
        self.assertIn('max(mine["ends"], world.time) + mine["tile"]', resolve)
        self.assertLess(resolve.index("return TRUE", resolve.index("if (!press_on)")),
                        resolve.index("voyage_loose_cargo()"))
        self.assertEqual(resolve.count("qdel(lost)"), 1)

    def test_only_exposed_loose_objects_are_at_risk(self):
        cargo = dm("voyage_provisions", "voyage_loose_cargo")
        self.assertIn("in B.aboard()", cargo)
        self.assertIn("I.anchored || !isturf(I.loc) || I.z < B.z", cargo)
        self.assertIn("!(locate(/obj/roof) in T)", cargo)
