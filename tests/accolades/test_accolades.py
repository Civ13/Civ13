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
        self.assertGreaterEqual(len(ids), 25)
        for entry in re.findall(r'= list\("[^"]+", (\d+), "', block):
            self.assertGreater(int(entry), 0)

    def test_no_accolade_rewards_killing_dying_or_magic(self):
        block = SOURCE[SOURCE.index("/proc/accolade_catalog()"):SOURCE.index("return catalog")].lower()
        for word in ("kill a player", "murder", "die ", "death", "magic", "divine", "spell", "ritual"):
            self.assertNotIn(word, block)

    def test_every_accolade_has_a_trigger(self):
        trigger_files = [SOURCE] + [read(p) for p in (
            "code/modules/client/player_tutorial.dm", "code/modules/naval/ship_voyage.dm",
            "code/modules/persistence/bed_return.dm", "code/game/objects/items/cartography_notes.dm",
            "code/game/objects/structures/blacksmithing/refining.dm", "code/modules/research_tree/field_work.dm",
            "code/modules/1713/domestication.dm", "code/modules/1713/machinery/modular_vehicles/aircraft/aircraft.dm",
            "code/modules/nomad_raids/nomad_visit.dm")]
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

    def test_second_list_hooks_are_wired(self):
        self.assertIn('accolade_meet_mob(H, "copyist")', read("code/modules/research_tree/book_research.dm"))
        self.assertIn('accolade_meet_mob(user, "copyist")', read("code/modules/1713/book.dm"))
        self.assertIn("H.accolade_crafted(recipe.result_type)", read("code/game/objects/items/stacks/stack.dm"))
        self.assertIn('accolade_meet_mob(H, "smelter")', read("code/modules/1713/tatara.dm"))
        self.assertIn('accolade_meet_mob(H, "herder")', read("code/modules/1713/complex_animal/_backend.dm"))
        self.assertIn("accolade_animal_killed(src)", read("code/game/mob/living/simple_animal/simple_animal.dm"))
        self.assertIn('accolade_meet_mob(driver, "aviator")', read("code/modules/1713/machinery/modular_vehicles/aircraft/helicopter.dm"))
        self.assertIn("owner.accolade_founded(newname)", read("code/game/mob/groups/faction_creation.dm"))
        self.assertIn("accolade_siege_held(province_seat(c, holder), holder)", read("code/modules/provinces/province_siege.dm"))
        research = read("code/modules/research_tree/book_research.dm")
        self.assertIn("record_chapter_author(node_id, writer)", research)
        self.assertIn("accolade_learned_from(H, source, node_id)", research)

    def test_crafting_targets_match_the_catalog_and_docs(self):
        self.assertIn("#define ACCOLADE_MAKER_RECIPES 100\n", SOURCE)
        self.assertIn("#define ACCOLADE_ARTISAN_RECIPES 500\n", SOURCE)
        docs = read("docs/accolades.md")
        for key, name, points, goal in (
            ("maker", "Maker", 10, 100), ("artisan", "Artisan", 30, 500)
        ):
            description = f"Craft [ACCOLADE_{key.upper()}_RECIPES] different things with one character."
            self.assertIn(f'"{key}" = list("{name}", {points}, "Making", "{description}")', SOURCE)
            self.assertIn(f"| {name} | One character crafts {goal} different things | {points} |", docs)

    def test_group_accolades_need_other_real_players(self):
        other = SOURCE[SOURCE.index("/proc/accolade_other_counts("):SOURCE.index("// A crafted recipe result")]
        self.assertIn("other != ckey", other)
        self.assertIn("shared_records.playtime_hours(other) >= ACCOLADE_OTHERS_MIN_HOURS", other)
        self.assertIn("accolade_other_counts(account, ckey)", SOURCE)
        self.assertIn("accolade_other_counts(reader_ckey, author)", SOURCE)
        hunter = SOURCE[SOURCE.index("/proc/accolade_animal_killed("):SOURCE.index("// Founder:")]
        self.assertIn("if(A.domesticable && !A.wild)", hunter)
        self.assertIn("if(C.tamed || C.owner)", hunter)

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
