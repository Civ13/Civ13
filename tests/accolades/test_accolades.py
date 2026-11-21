"""Source checks for lifetime accolades (code/modules/accolades/accolades.dm)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "code/modules/accolades/accolades.dm").read_text()


def read(path):
    return (ROOT / path).read_text()


class AccoladeSourceTest(unittest.TestCase):
    def catalog_ids(self):
        block = SOURCE[SOURCE.index("/proc/accolade_catalog()"):SOURCE.index("return catalog")]
        return re.findall(r'^\t\t"([a-z_]+)" = list\(', block, re.M)

    def test_catalog_has_unique_ids_and_points(self):
        block = SOURCE[SOURCE.index("/proc/accolade_catalog()"):SOURCE.index("return catalog")]
        ids = self.catalog_ids()
        self.assertEqual(len(ids), len(set(ids)))
        self.assertGreaterEqual(len(ids), 12)
        for entry in re.findall(r'= list\("[^"]+", (\d+), "', block):
            self.assertGreater(int(entry), 0)

    def test_no_accolade_rewards_killing_dying_or_magic(self):
        block = SOURCE[SOURCE.index("/proc/accolade_catalog()"):SOURCE.index("return catalog")].lower()
        for word in ("kill a player", "murder", "die ", "death", "magic", "divine", "spell", "ritual"):
            self.assertNotIn(word, block)

    def test_every_accolade_has_a_trigger(self):
        trigger_files = [SOURCE] + [read(p) for p in (
            "code/modules/client/player_tutorial.dm", "code/modules/naval/ship_voyage.dm",
            "code/modules/persistence/bed_return.dm")]
        text = "\n".join(trigger_files)
        for accolade in self.catalog_ids():
            self.assertTrue(re.search(r'accolade_meet(_mob)?\(.*"%s"' % accolade, text), accolade)

    def test_hooks_are_wired(self):
        self.assertIn('accolade_meet(accolade_client_ckey(owner), "first_steps")', read("code/modules/client/player_tutorial.dm"))
        self.assertIn("accolade_check_knowledge()", read("code/modules/research_tree/character_knowledge.dm"))
        self.assertIn("accolade_era_research(faction)", read("code/modules/research_tree/research_faction.dm"))
        travel = read("code/modules/persistence/region_travel.dm")
        self.assertIn('accolade_note_land(accolade_account_ckey(P["owner"]))', travel)
        self.assertIn('P["accolades"] = progress', travel)
        self.assertIn('H.accolade_progress = progress', travel)
        self.assertIn('accolade_meet_mob(H, "sailor")', read("code/modules/naval/ship_voyage.dm"))
        self.assertIn('accolade_meet_mob(src, "settled")', read("code/modules/persistence/bed_return.dm"))
        self.assertIn("/client/proc/accolades_admin", read("code/modules/admin/admin_verbs.dm"))
        dme = read("civ13.dme")
        self.assertIn('code\\modules\\accolades\\accolades.dm', dme)
        self.assertIn('code\\modules\\admin\\accolades_admin.dm', dme)
        self.assertIn('code\\processes\\accolades.dm', dme)

    def test_claims_are_once_per_account(self):
        claim = SOURCE[SOURCE.index("/proc/accolade_claim("):SOURCE.index("// Records a land")]
        self.assertIn('id = accolade_record_id("accolade", ckey, id)', claim)
        meet = SOURCE[SOURCE.index("/proc/accolade_meet(ckey, id)"):SOURCE.index("/proc/accolade_meet_mob")]
        self.assertIn('id = accolade_record_id("accolade_met", ckey, id)', meet)
        self.assertIn('id != "first_steps" && !accolades_earned_here()', meet)

    def test_non_persistent_lands_and_guests_do_not_earn(self):
        here = SOURCE[SOURCE.index("/proc/accolades_earned_here()"):SOURCE.index("// The land name")]
        for kind in ("BARRACKS", "BATTLE", "EVENT", "TUTORIAL", "RAID"):
            self.assertIn('"%s"' % kind, here)
        who = SOURCE[SOURCE.index("/proc/accolade_account_ckey("):SOURCE.index("/proc/accolade_mob_ckey(")]
        self.assertIn("is_agent_account(account)", who)
        self.assertIn("IsGuestKey(C.key)", who)

    def test_minutes_count_only_awake_and_played(self):
        minute = SOURCE[SOURCE.index("/mob/living/human/proc/accolade_minute()"):SOURCE.index("/mob/living/human/proc/accolade_check_knowledge(")]
        self.assertIn("if(!client || stat != CONSCIOUS || inducedSSD || sleeping)", minute)

    def test_window_guards_and_actions(self):
        self.assertIn('return list("claim")', SOURCE)
        guard = SOURCE[SOURCE.index("/datum/topic_state/accolades/can_use_topic"):SOURCE.index("/datum/accolade_window/ui_actions")]
        self.assertIn("user.client != W.owner", guard)
        act = SOURCE[SOURCE.index("/datum/accolade_window/ui_act("):]
        self.assertIn("user.client != owner", act)
        self.assertIn("accolade_catalog()[id]", act)
        for action in re.findall(r'panel_button\([^,]+, "([a-z_]+)"', SOURCE):
            self.assertEqual(action, "claim")

    def test_staff_changes_need_admin_rights_and_a_reason(self):
        admin = read("code/modules/admin/accolades_admin.dm")
        self.assertIn("check_rights(R_ADMIN)", admin)
        self.assertIn("if(!length(reason))", admin)
        self.assertIn('"grant" = 1', admin)


if __name__ == "__main__":
    unittest.main()
