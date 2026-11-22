"""Source checks: a faction's claimed island takes only those it lets land.

Val (2026-11-22): each faction can claim an island of its own that only it
decides who reaches. Leaders and officers open the border to visitors, keep it
to members and named guests, or close it to members only, and grant visitor
passes from a recruitment station. The world directory side is tested in
tests/transfer_storage/test_world_chart.py.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULE = "code/modules/naval/island_access.dm"


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def proc(text, header):
    start = text.index(header)
    nxt = re.search(r"^/", text[start + len(header):], re.M)
    return text[start:start + len(header) + (nxt.start() if nxt else len(text))]


class IslandAccess(unittest.TestCase):
    def setUp(self):
        self.mod = read(MODULE)

    def test_included_before_the_claim(self):
        dme = read("civ13.dme")
        self.assertIn('#include "code\\modules\\naval\\island_access.dm"', dme)

    def test_who_may_land(self):
        body = proc(self.mod, "/proc/island_access_admits(")
        # Members always; open admits all; closed admits only members.
        self.assertLess(body.index("island_access_member(H, claimant)"), body.index('if ("OPEN")'))
        self.assertIn('if ("MEMBERS")\n\t\t\treturn FALSE', body)
        self.assertIn("(account in people) || island_access_pass_hours(claimant, account) > 0", body)
        self.assertIn("colony_faction_id(H) == claimant", proc(self.mod, "/proc/island_access_member("))
        # A player's own land has no border.
        self.assertIn('findtext(claimant, "civ:") == 1', proc(self.mod, "/proc/island_access_claimant_at("))
        default = proc(self.mod, "/proc/island_access_policy(")
        self.assertIn('"mode" = "GUESTS"', default)

    def test_keepers_are_the_leader_and_papers_officers(self):
        self.assertIn('map.faction_power(H, H.civilization, "papers")', proc(self.mod, "/proc/island_access_keeper("))
        verb = proc(self.mod, "/obj/structure/recruitment_station/verb/grant_island_pass()")
        self.assertIn("H.civilization != faction || !island_access_keeper(H)", verb)
        self.assertIn('island_access_ask("pass"', verb)
        self.assertIn('island_access_ask("access"', proc(self.mod, "/mob/living/human/proc/island_access_menu("))

    def test_officers_send_only_the_selected_border_edit(self):
        menu = proc(self.mod, "/mob/living/human/proc/island_access_menu(")
        self.assertIn('change = list("mode" = mode)', menu)
        self.assertIn('change = list("add_guest" = account)', menu)
        self.assertIn('change = list("remove_guest" = account)', menu)
        self.assertNotIn('"people" =', menu)
        send = 'island_access_ask("access", claimant, faction_roster_account(src), change, incarnation)'
        self.assertIn(send, menu)
        self.assertLess(menu.rindex("island_access_claim_of(src) != claimant"), menu.index(send))
        self.assertIn("Request queued", menu)

    def test_every_way_there_is_guarded(self):
        travel = read("code/modules/persistence/region_travel.dm")
        party = proc(travel, "/obj/structure/region_gate/proc/depart_party(")
        self.assertIn("island_access_checks() && island_access_destination(destination)", party)
        self.assertIn("island_access_departure_refusal(destination, H)", party)
        crossing = proc(read("code/modules/naval/ship_crossing.dm"), "/obj/structure/hull_tiller/proc/cross_away(")
        self.assertIn("if (!problem && !admin_crossing)\n\t\t\tproblem = island_access_departure_refusal(id, H)", crossing)
        self.assertIn("gate.admin_sent = admin_crossing", crossing)
        voyage = read("code/modules/naval/ship_voyage.dm")
        self.assertIn("island && captain && !island_access_admits(captain, island)", proc(voyage, "/proc/voyage_destinations("))
        self.assertEqual(2, proc(voyage, "/obj/structure/hull_tiller/proc/voyage_menu(").count("voyage_island_refusal(land[1], land[2])"))
        # An admin's send is never stopped, nor is the island's own put-ashore gate.
        self.assertIn("return FALSE", proc(self.mod, "/obj/structure/region_gate/admin_send/island_access_checks()"))
        self.assertIn("return FALSE", proc(self.mod, "/obj/structure/region_gate/island_exile/island_access_checks()"))

    def test_ship_border_refusal_stops_the_whole_crew_before_escrow(self):
        travel = read("code/modules/persistence/region_travel.dm")
        party = proc(travel, "/obj/structure/region_gate/proc/depart_party(")
        batch = (
            "var/ship_border = island && ship_crossing()\n"
            "\tif(ship_border)\n"
            "\t\tvar/crew_border = null\n"
            "\t\tfor(var/mob/living/human/H in members)\n"
            "\t\t\tcrew_border = island_access_departure_refusal(destination, H)\n"
            "\t\t\tif(crew_border)\n"
            "\t\t\t\tbreak\n"
            "\t\tif(crew_border)\n"
            "\t\t\tfor(var/mob/living/human/H in members)\n"
            '\t\t\t\tstayed[H] = crew_border + "."\n'
            "\t\t\treturn"
        )
        self.assertIn(batch, party)
        self.assertLess(party.index("world_chart_refresh()"), party.index(batch))
        self.assertLess(party.index(batch), party.index("ready += H"))
        self.assertLess(party.index(batch), party.index("transfer_bridge.begin_escrow"))
        # Only ships have this cohort rule; other gates still decide per traveller.
        self.assertIn(
            "island && !ship_border ? island_access_departure_refusal(destination, H) : null",
            party,
        )

    def test_ship_refreshes_border_before_committing_crew_and_hull(self):
        crossing = proc(read("code/modules/naval/ship_crossing.dm"), "/obj/structure/hull_tiller/proc/cross_away(")
        refresh = "if (!admin_crossing && island_access_destination(id))\n\t\tworld_chart_refresh()"
        self.assertIn(refresh, crossing)
        self.assertLess(crossing.index(refresh), crossing.index("crossing_continues(hold, voyage)"))
        self.assertLess(crossing.index(refresh), crossing.index("island_access_departure_refusal(id, H)"))
        self.assertLess(crossing.index("island_access_departure_refusal(id, H)"), crossing.index("sea_crossing_strip("))

    def test_pass_messages_and_audit_wait_for_the_matching_directory_result(self):
        queue = proc(self.mod, "/proc/island_access_ask(")
        self.assertIn('return receipt["id"]', queue)
        wait = proc(self.mod, "/proc/island_pass_wait_for_result(")
        self.assertIn('"/chart/pass-result", list("id" = request_id, "actor" = actor)', wait)
        self.assertIn('return "unknown"', wait)
        verb = proc(self.mod, "/obj/structure/recruitment_station/verb/grant_island_pass()")
        before, after = verb.split('\n\tisland_guest_names()[account] = guest_name')
        self.assertIn('Visitor pass request queued.', before)
        self.assertIn('var/status = island_pass_wait_for_result(request_id, actor)', before)
        self.assertIn('if (status != "applied")', before)
        self.assertTrue(before.rstrip().endswith('return'))
        self.assertNotIn('map.recruitment_audit', before)
        self.assertNotIn('to_chat(M,', before)
        self.assertEqual(2, after.count('map.recruitment_audit'))
        self.assertEqual(2, after.count('to_chat(M,'))

    def test_the_island_puts_visitors_without_leave_ashore(self):
        claim = proc(read("code/modules/naval/island_claim.dm"), "/proc/island_claim_check()")
        self.assertIn("island_access_sweep(parent)", claim)
        sweep = proc(self.mod, "/proc/island_access_sweep(")
        self.assertIn("if (H.restrained())\n\t\t\tcontinue", sweep, "captives stay")
        self.assertIn("world.time - H.island_unwelcome_since < ISLAND_EXILE_GRACE", sweep)
        exile = proc(self.mod, "/proc/island_access_exile(")
        self.assertIn("gate.destination = shard_group.start_region", exile)
        self.assertIn("#define ISLAND_EXILE_GRACE 6000", self.mod)

    def test_exile_eligibility_is_checked_again_after_destination_poll(self):
        gate_refusal = proc(self.mod, "/obj/structure/region_gate/island_exile/departure_refused(")
        self.assertIn("H.loc != loc", gate_refusal)
        self.assertIn("!island_access_exile_needed(H, exile_claimant)", gate_refusal)
        eligibility = proc(self.mod, "/proc/island_access_exile_needed(")
        self.assertIn("H.persistence_owner_ckey != H.client.owner_key()", eligibility)
        self.assertIn("H.restrained() || H.travel_held()", eligibility)
        self.assertIn("island_claim_holds(claimant) && !island_access_admits(H, claimant)", eligibility)
        party = proc(read("code/modules/persistence/region_travel.dm"), "/obj/structure/region_gate/proc/depart_party(")
        self.assertLess(party.index("shard_group.poll_peer(destination)"), party.index("departure_refused(H)"))
        self.assertLess(party.index("departure_refused(H)"), party.index("departure_leave_behind(H)"))

    def test_failed_exile_keeps_body_and_belongings_in_place(self):
        exile = proc(self.mod, "/proc/island_access_exile(")
        self.assertIn("gate.depart(H)", exile)
        for mutation in ("leave_behind", "drop_from_inventory", "forceMove", "stop_pulling", "unbuckle_mob", "record_persistence_owner"):
            self.assertNotIn(mutation, exile)
        self.assertIn("return TRUE", proc(self.mod, "/obj/structure/region_gate/island_exile/departure_in_place()"))
        travel = read("code/modules/persistence/region_travel.dm")
        party = proc(travel, "/obj/structure/region_gate/proc/depart_party(")
        self.assertIn("else\n\t\tfor(var/mob/living/human/H in packed)\n\t\t\tH.forceMove(src)", party)
        refused = party.split("if(!result)", 1)[1].split("// Recorded:", 1)[0]
        self.assertIn("if(!in_place)\n\t\t\t\tH.forceMove(start)", refused)
        self.assertIn("travel_hold_end(hold)", refused)
        self.assertNotIn("depart_finish", refused)
        self.assertIn("hold = travel_hold_begin(packed, destination_name(), guarded, preserve_pull = TRUE)", party)
        hold_add = proc(read("code/modules/persistence/travel_hold.dm"), "/proc/travel_hold_add(")
        self.assertIn("if (!preserve_pull && M && !(M in hold.travellers))\n\t\tM.stop_pulling()", hold_add)

    def test_excluded_belongings_are_not_packed_or_dropped_early(self):
        plan = proc(self.mod, "/obj/structure/region_gate/island_exile/departure_leave_behind(")
        self.assertIn("return region_admin_send_left_behind(H)", plan)
        self.assertNotIn("region_admin_send_leave_behind(H)", plan)
        travel = read("code/modules/persistence/region_travel.dm")
        items = proc(travel, "/mob/living/human/proc/region_travel_items(")
        self.assertIn("if(!I || (length(leave_behind) && (I in leave_behind))) continue", items)
        payload = proc(travel, "/mob/living/human/proc/region_travel_payload(")
        self.assertIn("region_travel_worn_kind(I, leave_behind)", payload)
        gear = read("code/modules/persistence/region_travel_gear.dm")
        worn = proc(gear, "/proc/region_travel_worn_kind(")
        self.assertLess(worn.index("return region_travel_bag_kind(I, leave_behind)"), worn.index("return region_travel_generic_kind(I)"))
        bag = proc(gear, "/proc/region_travel_bag_kind(")
        self.assertIn("if(A != compartment && (A in leave_behind)) shown_count--", bag)
        self.assertIn("if(length(leave_behind) && (I in leave_behind)) continue", bag)

    def test_success_settles_only_the_planned_items_before_body_removal(self):
        travel = read("code/modules/persistence/region_travel.dm")
        party = proc(travel, "/obj/structure/region_gate/proc/depart_party(")
        self.assertIn("packed[H] = list(payload, items, H.client, leave_behind)", party)
        committed = party.split("// Recorded:", 1)[1]
        self.assertLess(committed.index("departure_before_finish(H, P[4], start)"), committed.index("depart_finish(H, P[1], P[2], P[3])"))
        self.assertLess(committed.index("depart_finish(H, P[1], P[2], P[3])"), committed.index("travel_hold_end(hold)"))
        settle = proc(self.mod, "/obj/structure/region_gate/island_exile/departure_before_finish(")
        self.assertIn("H.stop_pulling()", settle)
        self.assertIn("H.buckled.unbuckle_mob()", settle)
        self.assertIn("for (var/atom/movable/A in leave_behind)", settle)
        self.assertIn("S.loc == H", settle)
        self.assertIn("S.remove_from_storage(A, origin)", settle)
        self.assertIn("H.drop_from_inventory(A, origin)", settle)

    def test_members_sleep_safe_on_their_island(self):
        owned = proc(read("code/modules/persistence/offline_sleep_protection.dm"), "/mob/living/human/proc/offline_sleep_province_owned()")
        self.assertIn("var/island = island_claim_parent()", owned)
        self.assertIn("return colony_faction_id(src) == island", owned)

    def test_factions_can_find_it(self):
        factions = read("code/game/mob/groups/factions.dm")
        self.assertEqual(2, factions.count("verbs += /mob/living/human/proc/faction_island"))
        verb = proc(self.mod, "/mob/living/human/proc/faction_island()")
        self.assertIn("Every faction may claim one island across the sea", verb)
        self.assertIn("island_access_status_text(row[1])", read("code/game/mob/groups/colony_charter.dm"))

    def test_no_eager_global_lists(self):
        self.assertNotRegex(self.mod, r"var/global/list/\w+\s*=\s*list\(")


if __name__ == "__main__":
    unittest.main()
