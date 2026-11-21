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
        state = body("/proc/character_slot_state(ckey)")
        self.assertIn("shared_records.unix_after", state)
        self.assertNotIn("at < active_at", state)

    def test_window_keeps_the_rules_plain(self):
        window = body("/datum/character_slot_window/proc/window_sections()")
        self.assertIn("Splitting one group into several factions, or using kin, to get around claim limits is structuring. "
                      "It is not allowed, and admins will step in to break it up.", window)
        self.assertIn("Discord-verified", window)
        self.assertNotIn("Persistence", SOURCE.replace("persistence", ""))
        self.assertNotIn("—", SOURCE)

    def test_staff_can_lock_a_slot(self):
        admin = (ROOT / "code/modules/admin/accolades_admin.dm").read_text()
        self.assertIn('"Lock slot"', admin)
        self.assertIn("shared_records.revoke(open[pick]", admin)


if __name__ == "__main__":
    unittest.main()
