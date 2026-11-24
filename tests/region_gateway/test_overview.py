"""Offline source and public-atlas boundary checks; not a BYOND rendering test."""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PERSISTENCE = ROOT / "code/modules/persistence"
ATLAS = (PERSISTENCE / "region_gateway_overview.dm").read_text()
GATE = (PERSISTENCE / "region_gateway.dm").read_text()
RELAY = (PERSISTENCE / "region_relay.dm").read_text()
STATIC = json.loads((ROOT / "tools/world_links/world_links.json").read_text())
AGE_SECONDS = int(re.search(r"GATEWAY_PUBLIC_STATUS_AGE \((\d+) SECONDS\)", ATLAS)[1])


def proc(source, name):
    return source.split(name, 1)[1].split("\n/", 1)[0]


def public_status(peer, now):
    checked = peer.get("checked")
    if type(checked) not in (float, int) or not 0 <= now - checked <= AGE_SECONDS:
        return "Unknown", None
    state = {"UP": "Online", "ASLEEP": "Asleep", "COLD": "Asleep", "WAKING": "Starting",
             "STOPPED": "Offline"}.get(peer.get("state"), "Unknown")
    count = peer.get("players")
    if state != "Online" or type(count) not in (float, int) or not 0 <= count <= 10000 or count != int(count):
        count = None
    return state, count


class WorldOverview(unittest.TestCase):
    def test_names_go_only_in_html_text_and_only_public_fields_are_projected(self):
        render = proc(ATLAS, "/proc/region_gateway_overview_html(")
        self.assertIn('html_encode(peer["name"])', render)
        self.assertIn('html_encode(land_stage_column(id, "SURFACE"))', render)
        self.assertEqual({"name", "kind"}, set(re.findall(r'peer\["([^"]+)"\]', render)))
        self.assertEqual({"checked", "state", "players", "ordinal_age", "kind", "name"},
                         set(re.findall(r'peer\["([^"]+)"\]', ATLAS)))
        self.assertNotIn("title='[name]'", render)

    def test_fixed_static_ids_require_compatible_config_kind(self):
        position = proc(ATLAS, "/proc/region_gateway_atlas_position(")
        self.assertIn('if(kind == "SURFACE")\n\t\tvar/list/land = continent_layout[id]', position)
        self.assertIn('if(kind == "OCEANIC")\n\t\tvar/list/ocean = world_oceans[id]', position)
        self.assertTrue(position.rstrip().endswith("return null"))
        self.assertTrue({"gaia", "antarctica"} <= STATIC["lands"].keys())
        self.assertTrue({"atlantic", "arctic"} <= STATIC["oceans"].keys())
        self.assertFalse({"event", "gateway", "rail_yard", "tutorial", "far1"} &
                         (STATIC["lands"].keys() | STATIC["oceans"].keys()))

    def test_age_and_zero_are_distinct_from_unconfirmed_status(self):
        self.assertIn('now - checked > GATEWAY_PUBLIC_STATUS_AGE', ATLAS)
        self.assertIn('state != "Online"', ATLAS)
        self.assertEqual(("Online", 0), public_status({"checked": 5, "state": "UP", "players": 0}, 5 + AGE_SECONDS))
        self.assertEqual(("Unknown", None), public_status({"checked": 5, "state": "UP", "players": 70}, 6 + AGE_SECONDS))
        self.assertEqual(("Unknown", None), public_status({"checked": 5, "state": "MISMATCH", "players": 70}, 6))
        self.assertEqual(("Asleep", None), public_status({"checked": 5, "state": "ASLEEP", "players": 0}, 6))
        self.assertEqual(("Online", None), public_status({"checked": 5, "state": "UP"}, 6))

    def test_public_epoch_uses_canonical_labels_only_for_confirmed_land_state(self):
        epoch = proc(ATLAS, "/proc/region_gateway_public_epoch(")
        self.assertIn('state != "Online"', epoch)
        self.assertIn('!isnum(age) || age != round(age) || !ordinal_age_year(age)', epoch)
        self.assertIn('return ordinal_age_name(age)', epoch)
        self.assertIn('kind == "Land" ? region_gateway_public_epoch(peer, state)', ATLAS)

    def test_overview_never_polls_wakes_mutates_or_reads_private_data(self):
        for forbidden in ("world_chart", '"/chart"', "refresh_peer", "refresh_now(", "poll_once",
                          "wake_peer", "send_player", "region_go", "owner_key", "character_slot_state",
                          "public_address", 'peer["address"]', "doorman", "transfer_bridge", "world.Export"):
            self.assertNotIn(forbidden, ATLAS.lower() if forbidden.islower() else ATLAS)
        # Existing authenticated roster is presented only after its own guard.
        self.assertIn("region_gateway_roster_enabled(C) && !region_gateway_overview_session(C)", ATLAS)

    def test_standalone_view_only_is_opt_in_and_topic_cannot_route(self):
        connect = proc(RELAY, "/client/New(TopicData)")
        self.assertIn('gateway_public_overview = options["world_overview"] == "1" && region_gateway_overview_allowed(src)', connect)
        allowed = proc(ATLAS, "/proc/region_gateway_overview_allowed(")
        self.assertIn("region_gateway_roster_address()", allowed)
        self.assertNotIn("accolade_client_ckey", allowed)  # guests may view public data
        forward = proc(GATE, "/proc/region_gateway_forward(")
        self.assertLess(forward.index("region_gateway_overview_session(C)"), forward.index("region_gateway_destination("))
        topic = proc(RELAY, "/client/Topic(href, href_list, hsrc)")
        cut = topic.index("if(region_gateway_overview_session(src))")
        tabs = topic[:cut]
        self.assertIn("usr != mob", tabs)
        self.assertIn("next_gateway_tab > world.time", tabs)
        self.assertIn('href_list["gateway_tab"] == "characters" && !region_gateway_overview_session(src)', tabs)
        self.assertLess(cut, topic.index('if(href_list["region_go"])'))


if __name__ == "__main__":
    unittest.main()
