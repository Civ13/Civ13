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
        send = 'island_access_ask("access", claimant, faction_roster_account(src), change)'
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

    def test_the_island_puts_visitors_without_leave_ashore(self):
        claim = proc(read("code/modules/naval/island_claim.dm"), "/proc/island_claim_check()")
        self.assertIn("island_access_sweep(parent)", claim)
        sweep = proc(self.mod, "/proc/island_access_sweep(")
        self.assertIn("if (H.restrained())\n\t\t\tcontinue", sweep, "captives stay")
        self.assertIn("world.time - H.island_unwelcome_since < ISLAND_EXILE_GRACE", sweep)
        exile = proc(self.mod, "/proc/island_access_exile(")
        self.assertIn("gate.destination = shard_group.start_region", exile)
        self.assertIn("#define ISLAND_EXILE_GRACE 6000", self.mod)

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
