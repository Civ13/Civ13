"""Source checks for the anti-structuring rules (docs/character-slots.md, "Structuring")."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text()


class StructuringSourceTest(unittest.TestCase):
    def test_one_leadership_seat_per_player(self):
        membership = read("code/game/mob/groups/faction_membership.dm")
        change = membership[membership.index("/obj/map_metadata/proc/change_faction_leader"):]
        self.assertLess(change.index("if (faction_kin_leads_elsewhere(next, faction))"), change.index("civ_data[4] = next"))
        # The helper stays inside faction_membership.dm, which fixtures compile alone.
        self.assertIn("/proc/faction_leader_person(mob/living/human/H)", membership)
        creation = read("code/game/mob/groups/faction_creation.dm")
        self.assertLess(creation.index("map.faction_kin_leads_elsewhere(owner, draft_name)"), creation.index("owner.civilization = newname"))

    def test_province_cap_counts_the_bloc_and_never_half(self):
        holding = read("code/modules/provinces/province_holding.dm")
        self.assertIn("if (province_cap_refusal(contender))", holding)
        self.assertIn("var/held = province_bloc_holdings(group)", holding)
        self.assertIn("(held + 1) * 2 > length(P.names)", holding)
        self.assertIn("province_claims_frozen(group)", holding)
        blocs = read("code/modules/provinces/province_blocs.dm")
        self.assertIn("length(mine & theirs)", blocs)  # groups led by the same player

    def test_court_marks_reach_kin(self):
        justice = read("code/game/mob/groups/faction_justice.dm")
        self.assertIn("for (var/account in justice_kin_accounts(own))", justice)
        self.assertIn("accolade_judged(A)", justice)

    def test_staff_actions_need_a_reason_and_are_logged(self):
        admin = read("code/modules/admin/province_blocs_admin.dm")
        for action in ("Mark as one bloc", "Clear a bloc mark", "Freeze claims", "Unfreeze claims", "Release a province"):
            self.assertIn(f'"{action}"', admin)
        self.assertEqual(admin.count("if(!length(reason))"), 4)  # freeze and unfreeze share one prompt
        self.assertIn("log_admin(", admin)
        self.assertIn("message_admins(", admin)
        self.assertIn("/client/proc/province_blocs_admin,", read("code/modules/admin/admin_verbs.dm"))

    def test_magistrate_counts_other_players_once(self):
        source = read("code/modules/accolades/accolades.dm")
        self.assertIn('"magistrate" = list("Magistrate", 20,', source)
        self.assertIn('accolade_record_id("accolade_judged", judge, other)', source)
        self.assertIn("accolade_other_counts(other, judge)", source)


if __name__ == "__main__":
    unittest.main()
