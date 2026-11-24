"""Source contracts for the scheduled flight safety predicate."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def source(path):
    return (ROOT / path).read_text()


def proc(text, signature):
    return re.search(r"(?ms)^" + re.escape(signature) + r"\n(.*?)(?=^/|\Z)", text)[1]


RISK = source("code/modules/naval/flight_save_risk.dm")
HULL = source("code/modules/naval/air_hull.dm")
RESTORE = source("code/modules/1713/machinery/modular_vehicles/aircraft/aircraft_view.dm")


class FlightRiskSources(unittest.TestCase):
    def test_provider_only_checks_live_flight_registries(self):
        body = proc(RISK, "/proc/any_flight_at_disconnect_risk()")
        self.assertIn("in airborne_aircraft", body)
        self.assertIn("in air_hull_crafts", body)
        self.assertNotIn(" in world", body)
        self.assertNotIn("crewed_lander", body)
        self.assertEqual(body.count("scheduled_save_flight_risk()"), 2)

    def test_current_connected_operator(self):
        body = proc(RISK, "/proc/flight_save_fit_operator(mob/living/human/H)")
        self.assertIn("istype(H) && !QDELETED(H) && H.client && H.client.mob == H", body)
        self.assertIn("!H.incapacitated(INCAPACITATION_DISABLED|INCAPACITATION_RESTRAINED)", body)

    def test_aircraft_requires_real_controls_and_hard_restore_landing(self):
        body = proc(RISK, "/obj/structure/vehicleparts/axis/aircraft/proc/scheduled_save_flight_risk()")
        for guard in ("!airborne()", "air_crossing_asking", "air_crossing_hold > world.time",
                      "!flight_save_fit_operator(H)", "seat.axis != src", "seat.buckled_mob != H", "H.buckled != seat",
                      "wheel.loc != H", "!aloft_over_open_air()"):
            self.assertIn(guard, body)
        self.assertIn("return !down || !!clear_at_level(down)", body)
        restore = proc(RESTORE, "/obj/structure/vehicleparts/axis/aircraft/proc/set_down_after_restore()")
        self.assertIn("clear_footprint_offset(down)", restore)
        self.assertIn("var/hard = !offset || offset[1] || offset[2]", restore)

    def test_airship_requires_live_helm_handoff_and_recoverable_lift_loss(self):
        body = proc(RISK, "/datum/craft/air/proc/scheduled_save_flight_risk()")
        for guard in ("!changing_level", "world.time >= last_helm_operator_until",
                      "!flight_save_fit_operator(H)", "B.landed()", "helm.z != seat.z",
                      "get_dist(seat, helm) > 1", "!B.contains(seat)"):
            self.assertIn(guard, body)
        self.assertIn("return have < need && have * 2 >= need", body)
        self.assertIn("var/tmp/mob/living/human/last_helm_operator", RISK)
        self.assertIn("var/tmp/last_helm_operator_until", RISK)
        self.assertIn("last_helm_operator_until = world.time + FLIGHT_HELM_ACTIVITY", RISK)

    def test_airship_records_only_completed_commands(self):
        body = proc(HULL, "/obj/structure/airship_helm/attack_hand(mob/living/human/H)")
        self.assertEqual(body.count("craft.note_flight_helm(H)"), 2)
        self.assertIn('if (!choice || choice == "Cancel" || !craft', body)
        self.assertIn("\t\t\t\treturn\n\t\t\tcraft.note_flight_helm(H)\n\t\t\treturn", body)
        self.assertIn("\tif (craft)\n\t\tcraft.note_flight_helm(H)\n\t\tcraft.crew_message", body)
