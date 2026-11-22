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

    def test_nothing_leaves_for_a_land_whose_agent_is_on_hold(self):
        bridge = read('code/modules/persistence/transfer_bridge.dm')
        group = read('code/modules/persistence/shard_group.dm')
        # Every departure records its escrow here, so one check covers them all.
        escrow = body(bridge, '/datum/transfer_bridge/proc/begin_escrow(peer, list/payloads, fast = FALSE)')
        self.assertLess(escrow.index('if(shard_group.peer_transfers_held(peer)) return null'), escrow.index('begin_effect('))
        # A held land says so, and its peers remember it.
        self.assertIn('.["transfers_held"] = 1', body(group, '/datum/shard_group/proc/describe()'))
        self.assertIn('peer["transfers_held"] = reply["transfers_held"] ? TRUE : FALSE', body(group, '/datum/shard_group/proc/record(id, answer, now)'))
        self.assertIn('if(shard_group.peer_transfers_held(id)) return', body(SEND, '/proc/region_admin_send_destination_refusal(id, wake = TRUE)'))
        self.assertIn('if(shard_group.peer_transfers_held(destination))', body(TRAVEL, '/obj/structure/region_gate/proc/closed_reason()'))
        self.assertIn('shard_group.peer_transfers_held(id)', SHIP)
        # The lobby warns before a second character replaces one still on its way.
        home = read('code/modules/persistence/region_home.dm')
        self.assertIn('transfer_bridge.held() && !lobby.transfer_hold_warned && !region_home_living_body(C.owner_key())', home)
        self.assertIn("seen.get('transfers_held')", HOST)

    def test_a_shore_landing_looks_on_the_surface_level(self):
        # Gaia's surface is level 2; the edge-crossing level defaults to 1.
        self.assertIn('region_admin_send_shore(sea_crossing_sides(P["from"]), region_admin_send_surface_z())', SEND)
        self.assertIn('if(istype(N) && N.new_player_start_z) return N.new_player_start_z', body(SEND, '/proc/region_admin_send_surface_z()'))

    def test_sends_use_the_gate_departure_one_at_a_time(self):
        one = body(SEND, '/proc/region_admin_send_one(mob/living/human/H, id, list/landing)')
        self.assertIn('. = gate.depart(H)', one)
        # The record is kept on disk before the body leaves.
        self.assertLess(one.index('region_admin_send_checked_landing(H, id, landing)'), one.index('gate.depart(H)'))
        self.assertIn('region_admin_send_snapshot(H, id, landing, print)', body(SEND, '/proc/region_admin_send_checked_landing(mob/living/human/H, id, list/landing)'))
        self.assertIn('qdel(gate)', one)
        gate = SEND.split('/obj/structure/region_gate/admin_send\n', 1)[1].split('\n\n', 1)[0]
        self.assertIn('should_save = FALSE', gate)
        self.assertIn('return FALSE', body(SEND, '/obj/structure/region_gate/admin_send/accepts_arrivals()'))
        run = body(SEND, '/proc/region_admin_send_run(list/bodies, id, list/landing, ship, by, mob/requester)')
        self.assertIn('if(region_admin_send_running)', run)
        # A runtime part way through never leaves every later send refused.
        self.assertLess(run.index('try'), run.index('region_admin_send_each('))
        self.assertLess(run.index('catch'), run.rindex('region_admin_send_running = FALSE'))
        self.assertIn('sleep(ADMIN_SEND_GAP)', body(SEND, '/proc/region_admin_send_each(list/bodies, id, list/landing, ship, by)'))
        # Event regions keep their own transfer, which stashes the home character.
        self.assertIn('region_admin_send_kind_refusal(peer)', body(SEND, '/proc/region_admin_send_destination_refusal(id, wake = TRUE)'))

    def test_every_send_is_checked_one_to_one(self):
        one = body(SEND, '/proc/region_admin_send_one(mob/living/human/H, id, list/landing)')
        self.assertIn('.["check"] = md5(json_encode(print))', body(SEND, '/proc/region_admin_send_checked_landing(mob/living/human/H, id, list/landing)'))
        arrived = body(SEND, '/proc/region_admin_send_arrived(mob/living/human/H, list/P, incoming, turf/at)')
        self.assertIn('var/list/print = region_admin_send_fingerprint(H, TRUE)\n\t\tif(md5(json_encode(print)) == S["check"])', arrived)
        print_ = body(SEND, '/proc/region_admin_send_fingerprint(mob/living/human/H, arrived = FALSE)')
        for field in ('"skills"', '"research"', '"scholarship"', '"reading"', '"tongues"', '"faction"', '"items"', '"wounds"', '"tox"'):
            self.assertIn(field, print_)
        # Skills are compared as the record carries them, and the faction as the arrival keeps it.
        self.assertIn('json_decode(json_encode(pair))', print_)
        self.assertIn('arrived ? H.colony_origin : colony_faction_id(H)', print_)
        # Ship crews are checked 1:1 too.
        self.assertIn('extra["admin_send"] = region_admin_send_crew_landing(H, id, admin_crossing_by)', SHIP)
        # A mismatch names the parts that differ (sent as one check per part).
        self.assertIn('region_admin_send_checks_diff(S["checks"], region_admin_send_checks(print))', arrived)
        self.assertIn('.["checks"] = region_admin_send_checks(print)', body(SEND, '/proc/region_admin_send_checked_landing(mob/living/human/H, id, list/landing)'))
        self.assertIn('region_admin_send_probe_roundtrip()', read('tests/region_admin_send/probe.dm'))

    def test_ship_override_only_skips_the_map_edge(self):
        refusal = body(SHIP, '/obj/structure/hull_tiller/proc/crossing_refusal(mob/living/human/H)')
        self.assertIn('if (!admin_crossing && !B.at_map_edge())', refusal)
        self.assertIn('if (craft.speed || craft.turning_to)', refusal)
        self.assertIn('var/tmp/admin_crossing = FALSE', SHIP)
        # A ship goes only where a crossing could anchor her.
        self.assertIn('region_admin_send_ship_destinations()', body(SEND, '/proc/region_admin_send_preflight(list/bodies, id, list/landing, ship = FALSE)'))

    def test_wounds_travel_limb_by_limb(self):
        build = body(TRAVEL, '/proc/region_travel_build(list/P, turf/T)')
        self.assertIn('H.region_travel_restore_limbs(P["limbs"])', build)
        # A travel wound is never a sharp blow that could break or sever more.
        self.assertIn('H.take_overall_damage(brute, burn, FALSE, FALSE, "travel")', build)
        restore = body(TRAVEL, '/mob/living/human/proc/region_travel_restore_limbs(list/limbs)')
        self.assertIn('E.createwound(BRUISE, V[1])', restore)
        self.assertNotIn('take_damage', restore)
        self.assertIn('region_travel_limbs_valid(P["limbs"])', body(TRAVEL, '/proc/region_travel_decode(payload)'))

    def test_admin_send_never_strands_anyone(self):
        run = body(SEND, '/proc/region_admin_send_run(list/bodies, id, list/landing, ship, by, mob/requester)')
        # The lock is always released, even when a send fails part way.
        self.assertIn('try\n\t\tregion_admin_send_each(', run)
        self.assertLess(run.index('catch'), run.index('region_admin_send_running = FALSE'))
        self.assertIn('region_admin_send_wait_for_save()', body(SEND, '/proc/region_admin_send_each(list/bodies, id, list/landing, ship, by)'))
        kinds = body(SEND, '/proc/region_admin_send_kind_refusal(list/peer)')
        for kind in ('"EVENT"', '"BARRACKS", "BATTLE", "TUTORIAL"', '"A New Land"'):
            self.assertIn(kind, kinds)
        # What cannot travel is left on the tile, logged, and the rest goes.
        one = body(SEND, '/proc/region_admin_send_one(mob/living/human/H, id, list/landing)')
        self.assertLess(one.index('region_admin_send_leave_behind(H)'), one.index('gate.depart(H)'))

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

    def test_an_arrival_never_takes_an_account_already_playing_here(self):
        # A handover passed an admin through the lobby and gave them the body
        # they had sent over, in place of the character they were playing.
        waiting = body(TRAVEL, '/proc/region_travel_waiting_body(account)')
        self.assertIn('other != found && other.persistence_owner_ckey == account && other.stat != DEAD', waiting)
        self.assertIn('!other.region_arrival_pending) return null', waiting)
        self.assertIn('this body waits for an admin', SEND)

    def test_send_holds_players_still_until_they_leave(self):
        # Val (2026-11-22): pressing Send freezes the chosen players, checks
        # them again while frozen, and keeps them frozen until they leave.
        host = body(SEND, '/proc/region_admin_send_host(list/input)')
        self.assertLess(host.index('region_admin_send_running'), host.index('region_admin_send_hold_and_check('))
        check = body(SEND, '/proc/region_admin_send_hold_and_check(list/bodies, id, list/landing, ship)')
        self.assertLess(check.index('travel_hold_begin('), check.index('region_admin_send_preflight('))
        self.assertIn('travel_hold_release(region_admin_send_hold, M)', check)
        run = body(SEND, '/proc/region_admin_send_run(list/bodies, id, list/landing, ship, by, mob/requester)')
        self.assertLess(run.index('region_admin_send_running = FALSE'), run.index('travel_hold_end(region_admin_send_hold)'))
        each = body(SEND, '/proc/region_admin_send_each(list/bodies, id, list/landing, ship, by)')
        self.assertIn('travel_hold_release(region_admin_send_hold, H)', each)
        self.assertIn('travel_hold_renew(region_admin_send_hold)', each)
        self.assertIn('"held" = istype(H) && H.travel_held()', SEND)
        verb = body(PANEL, '/datum/admins/proc/send_player_to_region()')
        self.assertLess(verb.index('region_admin_send_hold_and_check('), verb.index('region_admin_send_run('))

    def test_every_way_of_acting_checks_the_hold(self):
        hooks = {
            'code/modules/persistence/restart_transaction.dm': '/client/Click(atom/object, location, control, params)',
            'code/game/mob/mob_movement.dm': '/client/Move(n, direct, ordinal = FALSE, fine_step = FALSE)',
            'code/_onclick/click.dm': '/mob/proc/ClickOn(var/atom/A, var/params)',
            'code/_onclick/hud/hud_layout.dm': '/client/MouseDrop(src_object, over_object, src_location, over_location, src_control, over_control, params)',
            'code/game/mob/living/carbon/human/inventory.dm': '/mob/living/human/verb/quick_equip()',
        }
        for path, header in hooks.items():
            self.assertIn('travel_hold_input(', body(read(path), header), path)
        movement = read('code/game/mob/mob_movement.dm')
        for header in ('/client/verb/attack_self()', '/client/verb/toggle_throw_mode()', '/client/verb/drop_item()'):
            self.assertIn('travel_hold_input(mob)', body(movement, header), header)
        self.assertIn('travel_hold_bars_step(mob, get_step(mob, direct))', body(movement, '/client/Move(n, direct, ordinal = FALSE, fine_step = FALSE)'))
        click = body(read('code/_onclick/click.dm'), '/mob/proc/ClickOn(var/atom/A, var/params)')
        self.assertIn('travel_hold_refuses(src, A)', click)
        drop = body(read('code/_onclick/hud/hud_layout.dm'), '/client/MouseDrop(src_object, over_object, src_location, over_location, src_control, over_control, params)')
        self.assertIn('travel_hold_refuses(mob, src_object)', drop)
        self.assertIn('travel_hold_refuses(mob, over_object)', drop)
        mob = read('code/game/mob/mob.dm')
        self.assertIn('travel_held()', body(mob, '/mob/proc/incapacitated(var/incapacitation_flags = INCAPACITATION_DEFAULT)'))
        self.assertIn('travel_hold_input(src)', body(mob, '/mob/verb/mode()'))
        self.assertIn('travel_held()', body(read('code/_onclick/click.dm'), '/mob/proc/canClick()'))
        self.assertIn('#include "code\\modules\\persistence\\travel_hold.dm"', DME)

    def test_every_trip_holds_its_travellers(self):
        # Val (2026-11-22): trails, land edges, voyages, flights and landers too,
        # with everyone going together and their vessel guarded.
        travel = body(TRAVEL, '/obj/structure/region_gate/proc/travel(mob/living/human/H)')
        self.assertLess(travel.index('player_alert('), travel.index('travel_hold_begin(list(H), destination_name(), travel_hold_belongings(H))'))
        self.assertLess(travel.index('travel_confirmed(H)'), travel.index('travel_hold_end(hold)'))
        cross = body(SHIP, '/obj/structure/hull_tiller/proc/cross(id, mob/living/human/notify = null, voyage = null, list/sea_edge = null)')
        self.assertLess(cross.index('crossing_travel_hold('), cross.index('cross_on('))
        self.assertLess(cross.index('cross_on('), cross.index('travel_hold_end(held)'))
        self.assertIn('travel_hold_begin(aboard, where, list(src), decks)', body(SHIP, '/obj/structure/hull_tiller/proc/crossing_travel_hold(where)'))
        air = read('code/modules/1713/machinery/modular_vehicles/aircraft/aircraft_crossing.dm')
        flight = body(air, '/obj/structure/vehicleparts/axis/aircraft/proc/air_cross(id, tiles, mob/living/human/pilot)')
        self.assertLess(flight.index('travel_hold_begin(aboard'), flight.index('air_cross_on('))
        self.assertLess(flight.index('air_cross_on('), flight.index('travel_hold_end(held)'))
        lander = read('code/modules/space/lander.dm')
        for header, inner in (('/obj/structure/crewed_lander/proc/launch(obj/structure/region_gate/trail_marker/launch_pad/pad, lx = null, ly = null, mob/living/human/notify = null)', 'launch_on('),
                              ('/obj/structure/landed_lander/proc/deorbit(mob/living/human/notify = null)', 'deorbit_on(')):
            proc = body(lander, header)
            self.assertLess(proc.index('travel_hold_begin(crew()'), proc.index(inner))
            self.assertLess(proc.index(inner), proc.index('travel_hold_end(held)'))

if __name__ == '__main__':
    unittest.main()
