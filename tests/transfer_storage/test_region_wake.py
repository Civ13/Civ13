"""Source contracts for sleeping regions. Never launches BYOND.

A frozen region wakes on any connection to its port, so peers ask the host's
doorman which regions sleep instead of polling them, and a trail wakes its
destination through the doorman before sending a traveller.
"""
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def read(path):
    with open(os.path.join(ROOT, path), encoding='utf-8-sig') as f:
        return f.read().replace('\r\n', '\n')


def proc(source, name):
    start = source.index('\n' + name + '(') + 1
    end = re.search(r'\n(?=[^\s#])', source[start + 1:])
    return source[start:start + 1 + end.start()] if end else source[start:]


GROUP = read('code/modules/persistence/shard_group.dm')
TRAVEL = read('code/modules/persistence/region_travel.dm')
GATE = '/obj/structure/region_gate'


class RegionWakeTests(unittest.TestCase):
    def test_sleeping_peers_are_never_polled_directly(self):
        body = proc(GROUP, '/datum/shard_group/proc/poll_once')
        self.assertLess(body.index('doorman_states()'), body.index('poll_peer(id)'))
        self.assertIn('entry["state"] != "awake"', body)
        self.assertIn('record_sleeping(id, entry, world.time)\n\t\t\tcontinue', body)

    def test_awake_peers_on_this_host_are_read_from_the_doorman(self):
        # world.Export blocks the asking world for the round trip even inside
        # spawn(); the doorman already asks every hosted world every 30 s.
        body = proc(GROUP, '/datum/shard_group/proc/poll_once')
        self.assertIn('record(id, entry["region"], world.time)\n\t\t\tcontinue', body)
        self.assertLess(body.index('record(id, entry["region"]'), body.index('poll_peer(id)\n'))
        self.assertIn('entry["cached_age"] <= SHARD_DOORMAN_FRESH_SECONDS', body)
        record = proc(GROUP, '/datum/shard_group/proc/record')
        self.assertIn('if(islist(answer))', record)
        door = read('scripts/gaia-host/doorman.py')
        self.assertIn("self.platform.region_topic(instance.port)", door)
        self.assertIn("entry['region'] = dict(instance.region)", door)

    def test_peers_on_this_host_are_polled_over_loopback(self):
        # world/Topic bans a non-loopback caller that asks more than once every
        # two minutes; the once-a-minute poll through the public host got the
        # rail yard banned from Gaia for the round (2026-11-05).
        body = proc(GROUP, '/datum/shard_group/proc/poll_peer')
        self.assertIn('byond://[peer_address(peer)]?shard_region=1', body)
        self.assertNotIn('byond://[peer["address"]]', body)
        helper = proc(GROUP, '/datum/shard_group/proc/peer_address')
        self.assertIn('"127.0.0.1:[shard_address_port(target)]"', helper)
        self.assertIn('copytext(address, 1, findlasttext(address, ":"))', helper)
        world = read('code/world.dm')
        self.assertIn('lasttimeaddr[addr] = world.time + 1200', world)

    def test_regions_follow_the_mainland_epoch_forward_only(self):
        # A fresh region started at the 1943 persistence floor while Gaia was
        # in 2013 (2026-11-05); every region keeps the mainland's epoch.
        self.assertIn('.["ordinal_age"] = map.ordinal_age', proc(GROUP, '/datum/shard_group/proc/describe'))
        record = proc(GROUP, '/datum/shard_group/proc/record')
        self.assertIn('if(id == mainland)\n\t\tfollow_mainland_epoch(reply["ordinal_age"])', record)
        follow = proc(GROUP, '/datum/shard_group/proc/follow_mainland_epoch')
        self.assertIn('region == mainland', follow)
        self.assertIn('ordinal <= map.ordinal_age', follow)
        self.assertIn('map.set_epoch(ordinal)', follow)
        configure = proc(GROUP, '/datum/shard_group/proc/configure')
        self.assertIn('mainland = first["id"]', configure)
        self.assertIn('settings["mainland"] in found', configure)
        epochs = read('code/modules/persistence/functions.dm')
        self.assertIn('var/global/list/epoch_names = list("5000 B.C.", "313 B.C.", "1013", "1713", "1873", "1903", "1943", "1969", "2013", "2026")', epochs)
        self.assertIn('map.set_epoch(epoch_names.Find(customage) - 1)', read('code/modules/admin/admin.dm'))

    def test_doorman_states_name_cold_worlds(self):
        body = proc(GROUP, '/datum/shard_group/proc/record_sleeping')
        self.assertIn('entry["cold"] ? "COLD" : "ASLEEP"', body)
        self.assertIn('"WAKING"', body)

    def test_a_stopped_world_is_not_shown_as_asleep_or_unreachable(self):
        body = proc(GROUP, '/datum/shard_group/proc/record_sleeping')
        self.assertIn('if("stopped")', body)
        self.assertIn('peer["state"] = "STOPPED"', body)
        text = proc(GROUP, '/proc/shard_state_text')
        self.assertIn('if("STOPPED") return "stopped"', text)
        self.assertIn('if("COLD") return "asleep, slow to wake"', text)

    def test_a_silent_doorman_is_logged_once(self):
        body = proc(GROUP, '/datum/shard_group/proc/poll_once')
        self.assertIn('(hosted ? !doorman_answering : doorman_answering)', body)
        self.assertLess(body.index('doorman_answering = !!hosted'), body.index('for(var/id in order.Copy())'))

    def test_the_regions_panel_is_a_whole_page(self):
        # A bare HTML fragment sent with browse() showed as raw text in the
        # 516 client (2026-11-08); /datum/browser wraps it in a document.
        verb = proc(GROUP, '/client/verb/view_regions')
        self.assertIn('new(mob, "shard_regions"', verb)
        self.assertIn('popup.open(FALSE)', verb)
        self.assertNotIn('src << browse(html', verb)
        panel = proc(GROUP, '/datum/shard_group/proc/panel_html')
        self.assertIn("<tr class='here'>", panel)
        self.assertIn('shard_kind_text(peer["kind"], id)', panel)
        kind = proc(GROUP, '/proc/shard_kind_text')
        self.assertIn('return "off-world"', kind)
        self.assertIn('if("RAILYARD") return "rail yard"', kind)

    def test_the_regions_panel_refreshes_in_place(self):
        # Val (2026-11-08): the Regions window needs a way to refresh it.
        panel = proc(GROUP, '/datum/shard_group/proc/panel_html')
        self.assertIn("byond://?region_refresh=1", panel)
        self.assertIn('Checked [round((world.time - last_poll) / 10)] seconds ago.', panel)
        refresh = proc(GROUP, '/datum/shard_group/proc/refresh_now')
        self.assertIn('world.time - last_poll < SHARD_REFRESH_FLOOR', refresh)
        self.assertLess(refresh.index('SHARD_REFRESH_FLOOR'), refresh.index('poll_once()'))
        self.assertIn('last_poll = world.time', proc(GROUP, '/datum/shard_group/proc/poll_once'))
        relay = read('code/modules/persistence/region_relay.dm')
        topic = relay[relay.index('if(href_list["region_refresh"])'):]
        self.assertLess(topic.index('next_region_refresh = world.time'), topic.index('shard_group.refresh_now()'))
        self.assertLess(topic.index('shard_group.refresh_now()'), topic.index('view_regions()'))

    def test_players_going_to_the_gate_join_its_public_port(self):
        # 2026-11-16: with Gaia as the gate, North America to Gaia through the
        # relay left players waiting for a manual reconnect.
        relay = read('code/modules/persistence/region_relay.dm')
        send = relay[relay.index('/datum/shard_group/proc/send_player('):relay.index('/datum/shard_group/proc/send_player_soon')]
        self.assertIn('if(id == gate)', send)
        self.assertLess(send.index('if(id == gate)'), send.index('ask_relay(route)'))
        self.assertLess(send.index('if(id == gate)'), send.index('if(!public)'))

    def test_the_doorman_address_is_validated(self):
        body = proc(GROUP, '/datum/shard_group/proc/configure')
        self.assertIn('shard_address_valid(settings["doorman"])', body)

    def test_a_trail_to_a_sleeping_region_stays_open(self):
        body = proc(TRAVEL, GATE + '/proc/closed_reason')
        self.assertIn('!shard_group.peer_wakeable(destination)', body)

    def test_a_trail_to_a_stopped_region_says_it_is_stopped(self):
        # 2026-11-13: an approved trail to a stopped Europe said "Nobody seems
        # to be coming back", which read as a broken trail. Since 2026-11-22 a
        # traveller starts a stopped land (Val); only one kept down on purpose
        # stays closed, and the traveller hears it is closed.
        body = proc(TRAVEL, GATE + '/proc/closed_reason')
        stopped = body.index('shard_group.peer_closed(destination)')
        self.assertLess(stopped, body.index('Nobody seems to be coming back'))
        self.assertIn('is closed for now: its land is not running', body)
        wake = proc(GROUP, '/datum/shard_group/proc/wake_peer')
        self.assertIn('ask_wake(id)', wake)
        ask = proc(GROUP, '/datum/shard_group/proc/ask_wake')
        stopped = ask.index('if(peer_closed(id))')
        refused = ask.index('"result" = "refused"', stopped)
        self.assertLess(stopped, refused)
        self.assertLess(refused, ask.index('if(!peer_wakeable(id))'))
        self.assertLess(refused, ask.index('ask_doorman('))
        # A stopped land is wakeable only when the doorman says it may be started.
        self.assertIn('peer["state"] == "STOPPED" && peer["startable"]', proc(GROUP, '/datum/shard_group/proc/peer_wakeable'))
        self.assertIn('&start=1', ask)
        closed = proc(GROUP, '/datum/shard_group/proc/peer_closed')
        self.assertIn('peer["state"] == "STOPPED" && !peer_wakeable(id)', closed)
        sleeping = proc(GROUP, '/datum/shard_group/proc/record_sleeping')
        self.assertIn('peer["startable"] = entry["startable"] ? TRUE : FALSE', sleeping)

    def test_travellers_hear_a_land_is_being_prepared(self):
        notice = proc(GROUP, '/datum/shard_group/proc/wake_notice')
        self.assertIn('is not ready yet: it is [peer_wait_state(id)] for you.', notice)
        ask = proc(GROUP, '/datum/shard_group/proc/ask_wake')
        self.assertIn('peer["preparing"] = reply["preparing"] ? TRUE : FALSE', ask)
        self.assertLess(ask.index('peer["preparing"] = reply'), ask.index('"result" = "accepted"'))
        # A start that failed reads stopped again, so travellers stop waiting.
        self.assertIn('peer_start_ended(id)', proc(GROUP, '/datum/shard_group/proc/await_peer'))
        self.assertIn('could not be made ready', proc(GROUP, '/datum/shard_group/proc/wake_peer'))

    def test_admins_hear_when_a_stopped_land_turns_travellers_back(self):
        travel = proc(TRAVEL, GATE + '/proc/travel')
        refused = travel.index('to_chat(H, SPAN_WARNING(reason))')
        self.assertLess(refused, travel.index('alert_stopped_destination(H)'))
        alert = proc(TRAVEL, GATE + '/proc/alert_stopped_destination')
        self.assertIn('!shard_group.peer_closed(destination)', alert)
        self.assertLess(alert.index('world.time < region_stopped_alerted[destination]'), alert.index('message_admins('))
        trails = read('code/modules/persistence/region_trails.dm')
        approve = proc(trails, '/obj/structure/region_gate/trail_marker/proc/admin_approve')
        self.assertIn('shard_group.peer_closed(destination)', approve)

    def test_travel_wakes_the_destination_then_checks_again(self):
        # travel() asks and holds the traveller still; travel_confirmed() wakes and checks again.
        body = proc(TRAVEL, GATE + '/proc/travel_confirmed')
        wake = body.index('shard_group.wake_peer(destination, H)')
        self.assertLess(wake, body.index('reason = travel_refusal(H)', wake))
        self.assertLess(wake, body.index('H.record_persistence_owner()'))

    def test_departure_needs_an_awake_destination(self):
        body = proc(TRAVEL, GATE + '/proc/depart_party')
        self.assertLess(body.index('shard_group.poll_peer(destination)'), body.index('begin_escrow'))

    def test_departure_rechecks_the_trail_after_the_poll(self):
        body = proc(TRAVEL, GATE + '/proc/depart_party')
        expected = body.index('var/expected = destination')
        poll = body.index('shard_group.poll_peer(destination)')
        recheck = body.index('destination != expected || closed_reason()', poll)
        self.assertLess(expected, poll)
        self.assertLess(recheck, body.index('region_travel_payload('))
        self.assertLess(recheck, body.index('begin_escrow'))

    def test_waking_is_bounded(self):
        ask = proc(GROUP, '/datum/shard_group/proc/ask_wake')
        wake = proc(GROUP, '/datum/shard_group/proc/wake_peer')
        await_peer = proc(GROUP, '/datum/shard_group/proc/await_peer')
        self.assertIn('var/eta_cap = peer["preparing"] ? 1800 : 900', ask)
        self.assertIn('Clamp(reply["eta"], 0, eta_cap)', ask)
        self.assertIn('var/list/asked = ask_wake(id)', wake)
        self.assertIn('var/eta = asked["eta"]', wake)
        self.assertIn('await_peer(id, world.time + (eta + 60) * 10, null, notify, eta, started)', wake)
        # Waiting players hear the land's state and time left, and that it is ready.
        self.assertLess(wake.index('await_peer('), wake.index('ready_notice(id, notify, world.time - started)'))
        self.assertIn('wait_status(id, eta, started)', await_peer)
        status = proc(GROUP, '/datum/shard_group/proc/peer_wait_state')
        for words in ('being built', 'starting up', 'waking from a deep sleep', 'waking up'):
            self.assertIn(words, status)
        self.assertIn('while(world.time < deadline)', await_peer)

    def test_a_direct_poll_that_never_returns_does_not_hold_the_poll_loop(self):
        # 2026-11-22: one missed doorman answer sent the gateway's poll loop to
        # world.Export a frozen world, which never answers; the loop hung for
        # ten hours and a player bound for North America was turned away.
        body = proc(GROUP, '/datum/shard_group/proc/poll_peer')
        self.assertIn('poll.ask(', body)
        self.assertIn('world.time + SHARD_POLL_TIMEOUT', body)
        self.assertIn('if(waiting && !waiting.done)\n\t\treturn FALSE', body)
        self.assertLess(body.index('if(!poll.done)'), body.index('record(id, poll.answer'))
        timed_out = body[body.index('if(!poll.done)'):body.index('LAZYREMOVE(polls_waiting, id)')]
        self.assertNotIn('record(', timed_out)
        ask = proc(GROUP, '/datum/shard_peer_poll/proc/ask')
        self.assertIn('set waitfor = FALSE', ask)
        self.assertIn('world.Export(target)', ask)
        self.assertIn('#undef SHARD_POLL_TIMEOUT', GROUP)

    def test_a_player_sent_to_a_land_asks_the_doorman_first(self):
        relay = read('code/modules/persistence/region_relay.dm')
        send = relay[relay.index('/datum/shard_group/proc/send_player('):relay.index('/datum/shard_group/proc/send_player_soon')]
        self.assertIn('if(!peer_wakeable(id))\n\t\t\trefresh_peer(id)', send)
        self.assertLess(send.index('refresh_peer(id)'), send.index('wake_peer(id, C.mob)'))
        body = proc(GROUP, '/datum/shard_group/proc/refresh_peer')
        self.assertLess(body.index('doorman_states()'), body.index('poll_peer(id)'))
        self.assertIn('record_sleeping(id, entry, world.time)\n\t\treturn FALSE', body)

    def test_an_unstaged_land_is_not_shown_as_unexplored(self):
        # 2026-11-23: North America read "unexplored" to a player who lived there.
        lands = read('code/modules/persistence/land_stage.dm')
        column = proc(lands, '/proc/land_stage_column')
        self.assertIn('if(id != shard_group.mainland && !land_stages[id])\n\t\treturn ""', column)
        self.assertLess(column.index('!land_stages[id]'), column.index('land_stage_text('))

    def test_a_login_the_relay_had_no_route_for_rejoins_the_front_door(self):
        # 2026-11-23: a direct rejoin of the relay port reached nobody. The relay now
        # sends it to the gateway, which names its port to the relay every minute and
        # links such a player (no public address) to its own public port.
        relay = read('code/modules/persistence/region_relay.dm')
        send = relay[relay.index('/datum/shard_group/proc/send_player('):relay.index('/datum/shard_group/proc/send_player_soon')]
        front = send.index('if(kind == "GATEWAY" && gate == region && (!C.address || region_relay_ip_loopback(C.address))')
        self.assertIn('!C.local_connection() && gate_address())', send)
        self.assertLess(send.index('if(id == gate)'), front)
        self.assertLess(front, send.index('ask_relay(route)'))
        self.assertLess(front, send.index('if(!public)'))
        self.assertIn('C << link("byond://[gate_address()]")', send)
        gateway = read('code/modules/persistence/region_gateway.dm')
        loop = proc(gateway, '/proc/region_gateway_status_loop')
        self.assertIn('region_gateway_tell_relay()', loop)
        tell = proc(gateway, '/proc/region_gateway_tell_relay')
        self.assertIn('ask_relay("gate=1&port=[shard_address_port(shard_group.address)]")', tell)


if __name__ == '__main__':
    unittest.main()
