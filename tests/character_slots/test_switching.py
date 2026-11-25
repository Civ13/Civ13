"""Source checks for buying and switching characters (code/modules/accolades/character_slots.dm)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "code/modules/accolades/character_slots.dm").read_text()


def body(name):
    start = SOURCE.index(name)
    end = re.search(r"^/(?!/)", SOURCE[start + len(name):], re.M)
    return SOURCE[start:start + len(name) + (end.start() if end else len(SOURCE))]


class CharacterSlotSourceTest(unittest.TestCase):
    def test_slots_cost_100_200_300_and_stop_at_four(self):
        cost = body("/proc/character_slot_cost(slot)")
        for slot, points in ((2, 100), (3, 200), (4, 300)):
            self.assertIn(f"if({slot}) return {points}", cost)
        self.assertIn("var/global/const/character_slots_max = 4", (ROOT / "code/modules/persistence/player_reclaim.dm").read_text())

    def test_only_verified_accounts_unlock_or_play_extra_slots(self):
        self.assertIn("return account_verified(C.ckey) || is_discord_id(C.discord_id)", body("/proc/character_slots_verified(client/C)"))
        self.assertIn("if(!character_slots_verified(C))", body("/proc/character_slot_unlock(client/C)"))
        self.assertIn("if(slot > 1 && !character_slots_verified(C))", body("/proc/character_slot_switch_refusal(client/C, slot)"))
        # Losing verification fails closed to slot 1 at the next lobby login.
        restore = body("/client/proc/character_slot_restore()")
        self.assertIn("!character_slots_verified(src)", restore)
        self.assertIn("slot = 1", restore)
        login = (ROOT / "code/game/mob/new_player/login.dm").read_text()
        self.assertLess(login.index("client.character_slot_restore()"), login.index("map_storage.reclaim_saved_player(src)"))

    def test_slots_are_bought_once_with_a_shared_id(self):
        buy = body("/proc/character_slot_buy(ckey)")
        self.assertIn('character_slot_record_id("character_slot", ckey, slot)', buy)
        self.assertIn("if(balance < cost)", buy)

    def test_switching_needs_rest_and_no_trouble(self):
        leave = body("/proc/character_slot_leave_refusal(client/C)")
        self.assertIn("character_slot_resting(owner)", leave)
        self.assertIn("character_idle_minutes < CHARACTER_SLOT_IDLE_MINUTES", leave)
        trouble = body("/mob/living/human/proc/character_slot_body_refusal()")
        for needle in ("handcuffed || legcuffed", "justice_examine_lines(src)", "cell_sentence_left > 0", "round_fact_hit_time"):
            self.assertIn(needle, trouble)
        self.assertIn("#define CHARACTER_SLOT_RETURN_WAIT 3600", SOURCE)
        self.assertIn("#define CHARACTER_SLOT_IDLE_MINUTES 30", SOURCE)
        self.assertIn("#define CHARACTER_SLOT_HURT_WAIT 6000", SOURCE)

    def test_record_times_compare_as_digit_strings(self):
        state = body("/proc/character_slot_state(ckey, fresh = FALSE)")
        self.assertIn("shared_records.unix_after", state)
        self.assertNotIn("at < active_at", state)

    def test_window_keeps_the_rules_plain(self):
        window = body("/datum/character_slot_window/proc/window_sections()")
        self.assertIn("Splitting one group into several factions, or using kin, to get around claim limits is structuring. "
                      "It is not allowed, and admins will step in to break it up.", window)
        self.assertIn("Discord-verified", window)
        self.assertNotIn("Persistence", SOURCE.replace("persistence", ""))
        self.assertNotIn("—", SOURCE)

    def test_sleep_picker_opens_only_after_confirmed_assigned_bed_sleep(self):
        helper = (ROOT / "code/game/mob/living/carbon/human/human_helpers.dm").read_text()
        flow = helper[helper.index("/mob/living/human/verb/mob_sleep"):helper.index("/mob/living/human/verb/mob_wakeup")]
        self.assertIn("if (!sleeping_client || client != sleeping_client || sleeping_client.mob != src)", flow)
        self.assertIn("if (!enter_saved_bed_sleep())", flow)
        self.assertLess(flow.index('to_chat(src, SPAN_WARNING(refusal))'), flow.index("sleeping_client.open_character_sleep_picker()"))
        self.assertLess(flow.index("sleeping_client.open_character_sleep_picker()"), flow.index("if (!enter_bed_sleep())"))

    def test_picker_requires_own_living_sleeping_body_in_valid_assigned_bed(self):
        admission = body("/proc/character_lobby_sleep_body(client/C)")
        for gate in ("accolade_client_ckey(C)", "persistence_bed_return_enabled()", "H.client != C",
                     "H.persistence_owner_ckey != owner", "H.character_lobby_assigned_bed(owner)"):
            self.assertIn(gate, admission)
        bed = body("/mob/living/human/proc/character_lobby_assigned_bed(owner)")
        for gate in ("stat == DEAD", "!inducedSSD", "sleeping <= 0", "!isturf(loc)",
                     "B.persistence_bed_owner_ckey == owner", "B.valid_sleep_bed(src)"):
            self.assertIn(gate, bed)
        self.assertIn("!!character_lobby_assigned_bed(owner)", body("/mob/living/human/proc/character_slot_resting(owner)"))
        leaving = body("/proc/character_lobby_departure_refusal(client/C)")
        for gate in ("character_lobby_sleep_body(C)", "H.character_picker_waking",
                     "persistence_sleep_transfer_blocked()", "character_recovery_unready()",
                     "H.character_slot_body_refusal()"):
            self.assertIn(gate, leaving)

    def test_picker_does_not_turn_browser_values_into_another_body_or_slot(self):
        action = body("/datum/character_slot_window/ui_act(")
        picker = action[action.index("if(sleep_picker_body)"):action.index('if("unlock")')]
        self.assertIn("user.client != owner", action)
        self.assertIn("character_lobby_sleep_body(C) != user", picker)
        self.assertLess(picker.index("character_lobby_departure_refusal(C)"), picker.index("region_gateway_open_roster(C)"))
        for unsafe in ("character_slot_switch(", "params[", ".key =", "new /mob/"):
            self.assertNotIn(unsafe, picker)
        self.assertIn("if(region_gateway_here())", body("/proc/character_slot_switch_refusal(client/C, slot)"))

    def test_private_cards_use_exact_owner_keys_and_refuse_ambiguity(self):
        cards = body("/datum/character_slot_window/proc/sleep_picker_sections()")
        self.assertIn("H.persistence_owner_ckey != owner_key_for(C.ckey, slot)", cards)
        self.assertIn('ambiguous["[slot]"] = TRUE', cards)
        self.assertIn('ambiguous["[slot]"] ? null : bodies["[slot]"]', cards)
        self.assertIn("slot > 1 && !character_slots_verified(C)", cards)
        self.assertIn("character_local_body_summary(H)", cards)

    def test_wake_timer_is_one_per_body_and_uses_existing_finish(self):
        helper = (ROOT / "code/game/mob/living/carbon/human/human_helpers.dm").read_text()
        wake = helper[helper.index("/mob/living/human/proc/request_character_picker_wake"):helper.index("//to keep the character sleeping")]
        self.assertIn("if(character_picker_waking || character_lobby_sleep_body(C) != src)", wake)
        before, after = wake.split("addtimer(CALLBACK(src, PROC_REF(complete_character_picker_wake), C), 30 SECONDS)", 1)
        self.assertIn("character_picker_waking = TRUE", before)
        self.assertLess(after.index("character_lobby_sleep_body(C) != src"), after.index("finish_wake_up()"))
        self.assertNotIn("inducedSSD = FALSE", wake)
        self.assertIn('key == "character_picker_waking"', helper)

    def test_reconnect_shows_picker_after_unique_authenticated_handoff_only(self):
        reclaim = (ROOT / "code/modules/persistence/player_reclaim.dm").read_text()
        flow = reclaim[reclaim.index("/map_storage/proc/reclaim_saved_player("):reclaim.index("/map_storage/proc/player_restoration_blocked()")]
        offer = flow.index("C.open_character_sleep_picker()")
        for step in ("length(current_bodies) != 1 || current_bodies[1] != H",
                     "H.key = C.key", "if(C.mob != H)", "finish_character_return(H)", "qdel(lobby)"):
            self.assertLess(flow.index(step), offer)
        release = flow.rindex("persistence_player_claims.Remove(owner)", 0, offer)
        self.assertLess(release, flow.index("qdel(lobby)"))
        self.assertLess(flow.rindex("region_gateway_expected_slot_ok(C)"), flow.index("H.key = C.key"))
        self.assertGreater(flow.index("C.gateway_expected_slot = 0"), flow.index("if(C.mob != H)"))
        self.assertIn("if(H.inducedSSD && C.mob == H)\n\t\tC.open_character_sleep_picker()", flow)
        picker = body("/client/proc/open_character_sleep_picker()")
        self.assertIn("if(!H)\n\t\treturn FALSE", picker)

    def test_staff_can_lock_a_slot(self):
        admin = (ROOT / "code/modules/admin/accolades_admin.dm").read_text()
        self.assertIn('"Lock slot"', admin)
        self.assertIn("shared_records.revoke(open[pick]", admin)


LOBBY = (ROOT / "code/game/mob/new_player/new_player.dm").read_text()
JOBS = (ROOT / "code/game/jobs/job_controller.dm").read_text()


def admission_body(source, signature):
    match = re.search(r"^" + re.escape(signature) + r"\n((?:[ \t].*\n|\n)*)", source, re.M)
    if not match:
        raise AssertionError("Missing procedure: " + signature)
    return match.group(1)


class CharacterSlotNameAdmission(unittest.TestCase):
    def test_name_gate_is_after_reclaim_and_preferences_but_before_control_transfer(self):
        create = admission_body(LOBBY, "/mob/new_player/proc/create_character(mobtype)")
        gate = "character_slot_name_conflict(account, client.character_slot, new_character.real_name)"
        guarded = create.index(gate)
        for earlier in ("map_storage.allow_new_character(src)", "client.prefs.copy_to(new_character)",
                        "if (client && client.prefs.be_random_body)", "if (persistence_bed_return_enabled() && client)",
                        "var/account = accolade_client_ckey(client)"):
            self.assertLess(create.index(earlier), guarded)
        for later in ("mind.transfer_to(new_character)", "new_character.key = key"):
            self.assertLess(guarded, create.index(later))
        refusal = create[guarded:create.index("src << sound", guarded)]
        for required in ("if (other_slot)", "qdel(new_character)", "release_new_character_job()",
                         "Choose a different name in Character Setup and try Join again.", "return null"):
            self.assertIn(required, refusal)

    def test_refusal_releases_role_without_deleting_or_moving_the_lobby(self):
        release = admission_body(LOBBY, "/mob/new_player/proc/release_new_character_job()")
        for required in ("original_job.current_positions = max(0, original_job.current_positions - 1)",
                         "original_job = null", "original_job_title = null", "mind.assigned_role = null",
                         "mind.assigned_job = null", "spawning = FALSE", "ready = FALSE"):
            self.assertIn(required, release)
        self.assertNotIn("key =", release)
        self.assertNotIn("qdel", release)
        self.assertNotIn("transfer_to", release)

    def test_new_writes_follow_equipped_name_and_unlocked_siblings_only(self):
        conflict = admission_body(SOURCE, "/proc/character_slot_name_conflict(account, slot, name)")
        self.assertIn("character_slot_state(account, TRUE)", conflict)
        self.assertIn("other == slot || !character_slot_open(state, other)", conflict)
        self.assertIn("region_home_living_body(owner_key_for(account, other))", conflict)
        self.assertIn("H ? H.real_name", conflict)
        equip = admission_body(JOBS, "/datum/controller/occupations/proc/EquipRank(var/mob/living/human/H, var/rank, var/joined_late = FALSE)")
        self.assertIn("H.character_slot_admitted_name = null", equip)
        self.assertIn("if (admitted_name && H.client)", equip)
        gate = equip.index("character_slot_name_conflict(")
        self.assertLess(equip.index("job.give_random_name(H)"), gate)
        self.assertLess(equip.index("if (job.rank_abbreviation)"), gate)
        self.assertLess(equip.index("H.real_name = admitted_name", gate), equip.index("H.character_slot_note_name()"))


if __name__ == "__main__":
    unittest.main()
