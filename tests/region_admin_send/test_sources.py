"""Send Player to Region: offline seam checks.

The native probe (probe.dm, run.py) checks the landing, the payload check, the
refusals and the audit in a real build. These checks keep the hooks it cannot
reach in place: the verb offered to admins, the travel payload and arrival
chain, the ship override, the host request and the launcher dialog.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


SEND = read('code/modules/persistence/region_admin_send.dm')
TRAVEL = read('code/modules/persistence/region_travel.dm')
SHIP = read('code/modules/naval/ship_crossing.dm')
LIFECYCLE = read('code/modules/persistence/nomads_lifecycle.dm')
VERBS = read('code/modules/admin/admin_verbs.dm')
PANEL = read('code/modules/admin/send_player_to_region.dm')
DME = read('civ13.dme')
HOST = read('scripts/shard-group/shard_group.py')
LAUNCHER = read('tools/opendream-client/native/Gui/LauncherWindow.cs')
PROJECT = read('tools/opendream-client/native/Civ13.Launcher.csproj')


def body(text, header):
    return text.split(header, 1)[1].split('\n/', 1)[0]


class RegionAdminSendSeams(unittest.TestCase):
    def test_included_and_offered_to_admins(self):
        self.assertIn('#include "code\\modules\\persistence\\region_admin_send.dm"', DME)
        self.assertIn('#include "code\\modules\\admin\\send_player_to_region.dm"', DME)
        self.assertIn('/datum/admins/proc/send_player_to_region,', VERBS)
        verb = body(PANEL, '/datum/admins/proc/send_player_to_region()')
        self.assertIn('if(!check_rights(R_ADMIN)) return', verb)
        # Rights are checked again after the confirmation, which sleeps.
        self.assertRegex(verb, r'"Send", "No"\)\) != "Send"\) return\n\tif\(!check_rights\(R_ADMIN\)\) return')
        # The dry run is always shown before anything is sent.
        self.assertLess(verb.index('region_admin_send_preflight('), verb.index('region_admin_send_run('))

    def test_the_landing_travels_in_the_ordinary_payload(self):
        self.assertIn('else if(key == "admin_send")\n\t\t\tP[key] = extra[key]', TRAVEL)
        self.assertIn('if(!region_admin_send_payload_ok(P)) return null', body(TRAVEL, '/proc/region_travel_decode(payload)'))
        arrive = body(TRAVEL, '/proc/region_travel_arrive(list/payloads, incoming, turf/T, replayed = FALSE)')
        # A ship's crew still come aboard her; the admin's landing comes before the trail back.
        self.assertLess(arrive.index('sea_crossing_arrival_turf(P, incoming)'), arrive.index('region_admin_send_arrival_turf(P, incoming)'))
        self.assertLess(arrive.index('region_admin_send_arrival_turf(P, incoming)'), arrive.index('region_travel_return_trail_turf(P)'))
        self.assertIn('region_admin_send_arrived(H, P, incoming,', arrive)
        self.assertIn('region_admin_send_claimed(H)', body(TRAVEL, '/proc/region_travel_claim(mob/new_player/lobby, wait = TRUE)'))

    def test_sends_use_the_gate_departure_one_at_a_time(self):
        one = body(SEND, '/proc/region_admin_send_one(mob/living/human/H, id, list/landing)')
        self.assertIn('. = gate.depart(H)', one)
        # The record is kept on disk before the body leaves.
        self.assertLess(one.index('region_admin_send_snapshot(H, id, landing, print)'), one.index('gate.depart(H)'))
        self.assertIn('qdel(gate)', one)
        gate = SEND.split('/obj/structure/region_gate/admin_send\n', 1)[1].split('\n\n', 1)[0]
        self.assertIn('should_save = FALSE', gate)
        self.assertIn('return FALSE', body(SEND, '/obj/structure/region_gate/admin_send/accepts_arrivals()'))
        run = body(SEND, '/proc/region_admin_send_run(list/bodies, id, list/landing, ship, by, mob/requester)')
        self.assertIn('if(region_admin_send_running)', run)
        self.assertIn('sleep(ADMIN_SEND_GAP)', run)
        # Event regions keep their own transfer, which stashes the home character.
        self.assertIn('peer["kind"] == "EVENT"', body(SEND, '/proc/region_admin_send_destination_refusal(id, wake = TRUE)'))

    def test_every_send_is_checked_one_to_one(self):
        one = body(SEND, '/proc/region_admin_send_one(mob/living/human/H, id, list/landing)')
        self.assertIn('gate.landing["check"] = md5(json_encode(print))', one)
        arrived = body(SEND, '/proc/region_admin_send_arrived(mob/living/human/H, list/P, incoming, turf/at)')
        self.assertIn('md5(json_encode(region_admin_send_fingerprint(H))) == S["check"]', arrived)
        print_ = body(SEND, '/proc/region_admin_send_fingerprint(mob/living/human/H)')
        for field in ('"skills"', '"research"', '"scholarship"', '"reading"', '"tongues"', '"faction"', '"items"'):
            self.assertIn(field, print_)
        self.assertIn('region_admin_send_probe_roundtrip()', read('tests/region_admin_send/probe.dm'))

    def test_ship_override_only_skips_the_map_edge(self):
        refusal = body(SHIP, '/obj/structure/hull_tiller/proc/crossing_refusal(mob/living/human/H)')
        self.assertIn('if (!admin_crossing && !B.at_map_edge())', refusal)
        self.assertIn('if (craft.speed || craft.turning_to)', refusal)
        self.assertIn('var/tmp/admin_crossing = FALSE', SHIP)
        self.assertIn('gate.pending["admin_send"] = list("landing" = "arrival", "by" = admin_crossing_by)', SHIP)

    def test_host_request_and_launcher(self):
        handle = body(LIFECYCLE, '/datum/nomads_lifecycle_control/proc/handle(list/input, addr)')
        self.assertIn('"set_epoch", "players", "send_players")))', handle)
        self.assertIn('region_admin_send_host(input)', handle)
        # The loopback token check comes before any action.
        self.assertLess(handle.index('input["token"] != token'), handle.index('region_admin_send_host(input)'))
        self.assertIn("'players', 'send-players'", HOST)
        self.assertIn("'dry_run': '1' if dry_run else '0'", HOST)
        self.assertIn('<Compile Include="RegionPlayers.cs" />', PROJECT)
        self.assertIn('new PlayersDialog(control, chosen.Id, chosen.Name, HostLine)', LAUNCHER)


if __name__ == '__main__':
    unittest.main()
