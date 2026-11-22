"""Source checks: a properly sleeping, logged-off character is safe off Gaia.

Val (2026-11-22): disconnected players are protected from harm while offline,
only if they went to sleep on a bed and waited the two-minute Sleep wait, and
only when not on Gaia. Reconnecting or an improper logout ends protection.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def proc(text, header):
    start = text.index(header)
    nxt = re.search(r"^/", text[start + len(header):], re.M)
    return text[start:start + len(header) + (nxt.start() if nxt else len(text))]


MODULE = "code/modules/persistence/offline_sleep_protection.dm"


class OfflineSleepProtection(unittest.TestCase):
    def setUp(self):
        self.mod = read(MODULE)

    def test_included(self):
        self.assertIn('#include "code\\modules\\persistence\\offline_sleep_protection.dm"', read("civ13.dme"))

    def test_condition(self):
        body = proc(self.mod, "/mob/living/human/offline_sleep_protected()")
        # Only the Sleep verb's completed wait sets inducedSSD; a client ends it.
        self.assertIn("if (!inducedSSD || client || offline_sleep_protection_lifted || stat == DEAD", body)
        self.assertIn("offline_sleep_protection_map_allowed()", body)
        self.assertIn("offline_sleep_province_owned()", body)
        owned = proc(self.mod, "/mob/living/human/proc/offline_sleep_province_owned()")
        self.assertIn('if (!civilization || civilization == "none" || !map)', owned)
        self.assertIn("var/holder = c ? province_holder_of(c) : null", owned)
        self.assertIn("return holder && holder == province_group_of(civilization)", owned)
        self.assertIn("for (var/obj/structure/bed/B in loc)", body)
        self.assertIn("B.anchored && B.buckle_lying", body)
        gaia = proc(self.mod, "/proc/offline_sleep_protection_map_allowed()")
        self.assertIn("map.ID != MAP_NOMADS_GAIA", gaia)
        # The base type is never protected.
        self.assertIn("return FALSE", proc(self.mod, "/mob/living/proc/offline_sleep_protected()"))

    def test_inducedssd_only_set_after_sleep_wait(self):
        helpers = read("code/game/mob/living/carbon/human/human_helpers.dm")
        verb = proc(helpers, "/mob/living/human/verb/mob_sleep()")
        wait = verb.index("do_after(src, 2 MINUTES")
        self.assertLess(wait, verb.index("enter_saved_bed_sleep()"))
        self.assertLess(wait, verb.index("enter_bed_sleep()"))
        self.assertIn("offline_sleep_protection_map_allowed()", verb)

    def test_never_blocks(self):
        body = proc(self.mod, "/mob/living/human/CanPass(")
        self.assertIn("if (mover && offline_sleep_protected())\n\t\treturn TRUE", body)

    def test_damage_choke_points(self):
        living = read("code/game/mob/living/living.dm")
        for name in ["adjustBruteLoss", "adjustBurnLoss", "adjustOxyLoss", "adjustToxLoss", "adjustCloneLoss", "adjustBrainLoss"]:
            body = proc(living, f"/mob/living/proc/{name}(var/amount)")
            # Harm is refused, healing stays open.
            self.assertIn("if (amount > 0 && offline_sleep_protected())", body, name)
        dmg = read("code/game/mob/living/carbon/human/human_damage.dm")
        self.assertIn("if (damage > 0 && offline_sleep_protected())", proc(dmg, "/mob/living/human/apply_damage("))
        self.assertIn("offline_sleep_protected()", proc(dmg, "/mob/living/human/take_overall_damage("))
        organ = read("code/modules/organs/organ_external.dm")
        self.assertIn("owner.offline_sleep_protected()", proc(organ, "/obj/item/organ/external/take_damage("))
        self.assertIn("owner.offline_sleep_protected()", proc(organ, "/obj/item/organ/external/proc/droplimb("))
        self.assertIn("owner.offline_sleep_protected()", proc(read("code/modules/organs/organ.dm"), "/obj/item/organ/proc/take_damage("))
        self.assertIn("offline_sleep_protected()", proc(read("code/modules/organs/blood.dm"), "/mob/living/human/proc/drip("))
        self.assertIn("offline_sleep_protected()", proc(read("code/game/mob/living/carbon/human/human.dm"), "/mob/living/human/ex_act("))

    def test_interactions_refused(self):
        self.assertIn("offline_sleep_refuses(user)", proc(read("code/_onclick/item_attack.dm"), "/mob/living/attackby("))
        self.assertIn("offline_sleep_refuses(user)", proc(read("code/game/objects/items/soap.dm"), "/mob/living/human/attackby("))
        self.assertIn("offline_sleep_refuses(M)", proc(read("code/game/mob/living/carbon/human/human_attackhand.dm"), "/mob/living/human/attack_hand("))
        self.assertIn("offline_sleep_refuses(M)", proc(read("code/game/mob/living/carbon/carbon.dm"), "/mob/living/human/attack_hand("))
        self.assertIn("offline_sleep_refuses(user)", proc(read("code/game/mob/living/carbon/human/stripping.dm"), "/mob/living/human/proc/handle_strip("))
        self.assertIn("offline_sleep_refuses(user)", proc(read("code/game/mob/living/carbon/human/human.dm"), "/mob/living/human/show_inv("))
        self.assertIn("offline_sleep_refuses(user)", proc(read("code/game/mob/living/carbon/carbon.dm"), "/mob/living/human/show_inv("))
        self.assertIn("M.offline_sleep_protected()", proc(read("code/_helpers/unsorted.dm"), "/proc/can_operate("))
        self.assertIn("sleeper.offline_sleep_refuses(src)", proc(read("code/game/mob/mob.dm"), "/mob/proc/start_pulling("))
        grab = read("code/game/mob/grab.dm")
        self.assertIn("sleeper.offline_sleep_refuses(user)", proc(grab, "/obj/item/weapon/grab/New("))
        self.assertIn("sleeper.offline_sleep_protected()", proc(grab, "/obj/item/weapon/grab/proc/confirm()"))
        buckling = read("code/game/objects/buckling.dm")
        self.assertIn("offline_sleep_refuses(user)", proc(buckling, "/obj/proc/user_buckle_mob("))
        self.assertIn("offline_sleep_refuses(user)", proc(buckling, "/obj/proc/user_unbuckle_mob("))

    def test_bed_cannot_be_taken_apart_under_sleeper(self):
        wait = proc(read("code/game/objects/items/stacks/craft_guards.dm"), "/proc/do_ship_fixture_after(")
        self.assertLess(wait.index("sleeper_bed.offline_sleeper_refuses(user)"), wait.index("do_after("))
        # The wrench and hammer branches both wait through it before acting.
        structure = proc(read("code/game/objects/structures.dm"), "/obj/structure/attackby(")
        self.assertIn("do_ship_fixture_after(user, 15, src)", structure)
        self.assertIn("do_ship_fixture_after(user, 25, src)", structure)

    def test_holds_released_on_logout(self):
        logout = proc(read("code/game/mob/living/logout.dm"), "/mob/living/human/Logout()")
        self.assertIn("addtimer(CALLBACK(src, PROC_REF(offline_sleep_release_holds)), 1)", logout)
        release = proc(self.mod, "/mob/living/human/proc/offline_sleep_release_holds()")
        self.assertIn("pulledby.stop_pulling()", release)
        self.assertIn("qdel(G)", release)

    def test_staff_and_gods_can_lift_it(self):
        body = proc(self.mod, "/mob/living/human/offline_sleep_protected()")
        self.assertIn("offline_sleep_protection_lifted", body)
        lift = proc(self.mod, "/client/proc/cmd_admin_lift_sleep_protection()")
        self.assertIn("if (!check_rights(R_ADMIN))", lift)
        self.assertIn("H.offline_sleep_protection_lifted = TRUE", lift)
        self.assertIn("log_admin(", lift)
        self.assertIn("/client/proc/cmd_admin_lift_sleep_protection,", read("code/modules/admin/admin_verbs.dm"))
        divine = proc(self.mod, "/mob/observer/ghost/proc/divine_lift_sleep_protection()")
        self.assertIn("if (!divine_allowed())", divine)
        self.assertIn("/mob/observer/ghost/proc/divine_lift_sleep_protection,", read("code/modules/divine/divine_sight.dm"))
        # Refused players are told how to ask.
        self.assertIn("adminhelp or pray", proc(self.mod, "/mob/living/proc/offline_sleep_refuses("))

    def test_next_sleep_restores_it(self):
        helpers = read("code/game/mob/living/carbon/human/human_helpers.dm")
        self.assertIn("offline_sleep_protection_lifted = FALSE", proc(helpers, "/mob/living/human/proc/enter_bed_sleep()"))
        self.assertIn("offline_sleep_protection_lifted = FALSE", proc(read("code/modules/persistence/bed_return.dm"), "/mob/living/human/proc/enter_saved_bed_sleep()"))


if __name__ == "__main__":
    unittest.main()
