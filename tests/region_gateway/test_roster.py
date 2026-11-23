"""Source contracts for the optional, route-only Characters gateway."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2] / "code"
GATE = (ROOT / "modules/persistence/region_gateway.dm").read_text()
RELAY = (ROOT / "modules/persistence/region_relay.dm").read_text()
HOME = (ROOT / "modules/persistence/region_home.dm").read_text()


def proc(source, name):
    return source.split(name, 1)[1].split("\n/", 1)[0]


class GatewayRosterTests(unittest.TestCase):
    def test_connect_hint_does_not_change_credentials_or_admission(self):
        connect = proc(RELAY, "/client/New(TopicData)")
        self.assertIn('options["character_lobby"] == "1"', connect)
        self.assertNotIn('options["slot"]', connect)
        self.assertNotIn("ckey =", connect)
        self.assertNotIn("character_slot =", connect)
        enabled = proc(GATE, "/proc/region_gateway_roster_enabled(")
        for required in ("region_gateway_here()", "C.gateway_character_lobby",
                         "accolade_client_ckey(C)", "region_gateway_roster_address()"):
            self.assertIn(required, enabled)

    def test_roster_links_do_not_accept_owner_or_land_from_client(self):
        topic = proc(RELAY, "/client/Topic(href, href_list, hsrc)")
        choice = topic.split('if(href_list["gateway_character_slot"])', 1)[1].split('if(href_list["region_go"])', 1)[0]
        self.assertIn("usr != mob", choice)
        self.assertIn("next_region_go", choice)
        self.assertIn('region_gateway_choose_character(lobby, text2num(href_list["gateway_character_slot"]))', choice)
        handler = proc(GATE, "/proc/region_gateway_choose_character(")
        self.assertIn("character_slot_state(accolade_client_ckey(C))", handler)
        self.assertIn("region_gateway_roster_choice_allowed", handler)
        self.assertNotIn("character_slot_switch(", handler)
        self.assertNotIn("reclaim_saved_player", handler)

    def test_gateway_queries_exact_active_owner_and_refuses_incomplete_routes(self):
        forward = proc(GATE, "/proc/region_gateway_forward(")
        self.assertIn("var/slot = account ? region_gateway_active_slot(C", forward)
        self.assertIn("C.mob != lobby", forward)
        self.assertLess(forward.index("region_gateway_destination(C.key, slot, roster)"),
                        forward.index("slot != region_gateway_active_slot(C, state)"))
        self.assertIn("shard_group.send_player(C, home, !roster, roster ? slot : 0)", forward)
        self.assertLess(forward.index("if(slot_changed || choice_refused)"),
                        forward.index("region_home_summon(owner, parked)"))
        resolve = proc(GATE, "/proc/region_gateway_destination(")
        self.assertIn("owner_key_for(ckey(key), slot)", resolve)
        roster = resolve.split("if(roster)\n", 1)[1].split('request("/account"', 1)[0]
        self.assertIn('request("/lobby/home", list("ckey" = account))', roster)
        self.assertIn('status["state"] != "NO_HOME" || home == shard_group.start_region', roster)
        self.assertNotIn("region_home_summon", roster)
        self.assertIn('return list("wait" = "The character directory cannot confirm', roster)

    def test_sleep_departure_checks_and_escapes_roster_labels(self):
        self.assertIn("character_lobby_departure_refusal(C)", proc(GATE, "/proc/region_gateway_open_roster("))
        render = proc(GATE, "/proc/region_gateway_show_roster(")
        self.assertIn("C.mob != lobby", render)
        self.assertIn("html_encode(entry[1])", render)
        address = proc(GATE, "/proc/region_gateway_roster_address(")
        self.assertIn('front["kind"] != "GATEWAY"', address)
        self.assertIn("region_gateway_battle_peer()", address)

    def test_expected_slot_is_only_a_negative_gate(self):
        send = proc(RELAY, "/datum/shard_group/proc/send_player(")
        self.assertIn('character_expected_slot=[expected_slot]', send)
        self.assertIn('byond://[peer["address"]][slot_check]', send)
        self.assertIn('byond://[relay][slot_check]', send)
        connect = proc(RELAY, "/client/New(TopicData)")
        self.assertIn('gateway_expected_slot = (expected in list("1", "2", "3", "4"))', connect)
        self.assertNotIn("character_slot =", connect)
        check = proc(GATE, "/proc/region_gateway_expected_slot_ok(")
        self.assertIn("region_home_enabled()", check)
        self.assertIn("C.character_slot == C.gateway_expected_slot", check)
        self.assertIn("region_gateway_active_slot(C, character_slot_state(account)) == C.gateway_expected_slot", check)
        self.assertNotIn("C.character_slot =", check.replace("==", ""))
        admit = proc(HOME, "/proc/region_home_admit(")
        self.assertLess(admit.index("if(!region_gateway_expected_slot_ok(C))"),
                        admit.index("if(!region_home_enabled()) return TRUE"))
        self.assertEqual(admit.count("if(!region_gateway_expected_slot_ok(C))"), 2)
        self.assertIn("if(!region_gateway_expected_slot_ok(lobby?.client)) return FALSE",
                      proc(HOME, "/proc/region_home_reclaim_ok("))


if __name__ == "__main__":
    unittest.main()
