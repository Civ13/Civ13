// Full-source probe: combat stances pick the body part an attack goes for.
// Manual keeps the doll's zone and random keeps the random toggle; each stance
// scores zones by armour, weapon, intent and what the opponent just did.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/combat_stance_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/combat_stance_probe/New()
	map = src

/turf/floor/plating/combat_stance_probe

var/combat_stance_probe_checks = 0
var/combat_stance_runtime = null

/world/Error(exception/e)
	if (!combat_stance_runtime)
		combat_stance_runtime = "runtime [e] ([e.file]:[e.line])"

/proc/combat_stance_assert(ok, label)
	combat_stance_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/combat_stance_actor(tx, ty, name)
	var/mob/living/human/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.real_name = name
	H.name = name
	H.hand = 0
	H.mood_modifier = 1
	H.stats["strength"] = list(100, 100)
	H.stats["dexterity"] = list(100, 100)
	H.a_intent = I_HARM
	return H

/proc/combat_stance_best(list/scores)
	var/best = null
	for (var/zone in scores)
		if (!best || scores[zone] > scores[best])
			best = zone
	return best

/proc/combat_stance_armour(mob/living/human/H, path, slot, melee)
	var/obj/item/clothing/C = new path(null)
	C.armor = list("melee" = melee, "arrow" = 0, "gun" = 0, "energy" = 0, "bomb" = 0, "bio" = 0, "rad" = 0)
	H.equip_to_slot(C, slot)
	return C

/proc/combat_stance_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.global_listen_count = list()
	GLOB.event_sources_count = list()
	GLOB.event_listen_count = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	map = new /obj/map_metadata/combat_stance_probe
	var/mob/living/human/A = combat_stance_actor(5, 5, "Attacker")
	var/mob/living/human/B = combat_stance_actor(6, 5, "Defender")
	var/obj/item/weapon/W = new /obj/item/weapon/wrench(null)
	A.put_in_r_hand(W)

	// Manual and help intent keep the doll's zone; random keeps its 13 zones.
	A.targeted_organ = "l_leg"
	combat_stance_assert(A.combat_stance == COMBAT_STANCE_MANUAL && A.resolve_attack_zone(B, W) == "l_leg", "manual_keeps_doll")
	A.set_combat_stance(COMBAT_STANCE_AGGRESSIVE, TRUE)
	A.a_intent = I_HELP
	combat_stance_assert(A.resolve_attack_zone(B, W) == "l_leg", "help_intent_never_auto")
	A.a_intent = I_HARM
	combat_stance_assert(A.resolve_attack_zone(A, W) == "l_leg", "self_never_auto")
	A.targeted_organ = "random"
	combat_stance_assert((A.resolve_attack_zone(B, W) in combat_random_zones) && A.resolve_attack_zone(B, null, COMBAT_ATTACK_SHOVE) == "random", "random_toggle_kept")
	A.set_combat_stance(COMBAT_STANCE_MEASURED, TRUE)
	combat_stance_assert(A.targeted_organ != "random", "stance_leaves_random")
	A.set_combat_stance(COMBAT_STANCE_AGGRESSIVE, TRUE)
	A.targeted_organ = "chest"

	// Aggressive goes for the head; a picked zone flashes nothing without a client.
	var/list/scores = A.combat_zone_scores(B, W, COMBAT_ATTACK_WEAPON)
	combat_stance_assert(combat_stance_best(scores) == "head", "aggressive_head")
	combat_stance_assert(!("eyes" in scores), "eyes_never_auto")
	var/zone = A.resolve_attack_zone(B, W)
	combat_stance_assert((zone in combat_auto_zones) && A.last_auto_zone == zone && !A.combat_doll_flash, "auto_pick_recorded")

	// Measured finds the gap: a helmet and armoured body leave the legs best.
	A.set_combat_stance(COMBAT_STANCE_MEASURED, TRUE)
	combat_stance_assert(combat_stance_best(A.combat_zone_scores(B, W, COMBAT_ATTACK_WEAPON)) == "head", "measured_open_head")
	combat_stance_armour(B, /obj/item/clothing/head/helmet, slot_head, 90)
	scores = A.combat_zone_scores(B, W, COMBAT_ATTACK_WEAPON)
	combat_stance_assert(scores["head"] < scores["chest"] && combat_stance_best(scores) == "chest", "measured_avoids_helmet")
	combat_stance_armour(B, /obj/item/clothing/suit/armor/ancient/chainmail, slot_wear_suit, 90)
	scores = A.combat_zone_scores(B, W, COMBAT_ATTACK_WEAPON)
	var/best = combat_stance_best(scores)
	combat_stance_assert(!(best in list("head", "mouth", "chest", "groin", "l_arm", "r_arm")), "measured_finds_uncovered_part")

	// A sharp reader nearly always takes the best zone; a poor one spreads out.
	var/hits_sharp = 0
	var/hits_poor = 0
	for (var/i in 1 to 300)
		if (pick_combat_zone(scores, 3) == best)
			hits_sharp++
		if (pick_combat_zone(scores, 0.25) == best)
			hits_poor++
	combat_stance_assert(hits_sharp > hits_poor && hits_sharp > 60, "read_skill_sharpens")
	qdel(B.head)
	qdel(B.wear_suit)

	// Disarming goes for the weapon hand, less for a tightened grip.
	A.set_combat_stance(COMBAT_STANCE_DISARMING, TRUE)
	var/obj/item/weapon/BW = new /obj/item/weapon/wrench(null)
	B.put_in_l_hand(BW)
	scores = A.combat_zone_scores(B, W, COMBAT_ATTACK_WEAPON)
	combat_stance_assert(combat_stance_best(scores) == "l_hand", "disarming_weapon_hand")
	var/loose = scores["l_hand"]
	BW.grip_tightened = TRUE
	combat_stance_assert(A.combat_zone_scores(B, W, COMBAT_ATTACK_WEAPON)["l_hand"] < loose, "tight_grip_harder")
	BW.grip_tightened = FALSE

	// Grab and shove: a held item draws the hand, otherwise the chest.
	combat_stance_assert(A.resolve_attack_zone(B, null, COMBAT_ATTACK_GRAB) == "l_hand" && A.resolve_attack_zone(B, null, COMBAT_ATTACK_SHOVE) == "l_hand", "grab_and_shove_weapon_hand")
	A.set_combat_stance(COMBAT_STANCE_MEASURED, TRUE)
	combat_stance_assert(A.resolve_attack_zone(B, null, COMBAT_ATTACK_SHOVE) == "chest", "measured_shove_chest")
	B.drop_from_inventory(BW)
	combat_stance_assert(A.resolve_attack_zone(B, null, COMBAT_ATTACK_GRAB) == "chest", "grab_empty_handed_chest")

	// Low line goes for the legs.
	A.set_combat_stance(COMBAT_STANCE_LOW, TRUE)
	best = combat_stance_best(A.combat_zone_scores(B, W, COMBAT_ATTACK_WEAPON))
	combat_stance_assert(best == "l_leg" || best == "r_leg", "low_line_legs")

	// Guarded keeps to the chest, then answers the arm that struck.
	A.set_combat_stance(COMBAT_STANCE_GUARDED, TRUE)
	combat_stance_assert(combat_stance_best(A.combat_zone_scores(B, W, COMBAT_ATTACK_WEAPON)) == "chest", "guarded_chest")
	A.note_struck_by(B, "chest", "l_arm")
	combat_stance_assert(A.recently_struck_by(B) && combat_stance_best(A.combat_zone_scores(B, W, COMBAT_ATTACK_WEAPON)) == "l_arm", "guarded_counters_striking_arm")
	A.last_struck_time = world.time - COMBAT_READ_WINDOW - 1
	combat_stance_assert(!A.recently_struck_by(B) && combat_stance_best(A.combat_zone_scores(B, W, COMBAT_ATTACK_WEAPON)) == "chest", "read_expires")

	// Reading where they aim: a low attack opens the head.
	A.set_combat_stance(COMBAT_STANCE_MEASURED, TRUE)
	var/head_before = A.combat_zone_scores(B, W, COMBAT_ATTACK_WEAPON)["head"]
	A.note_struck_by(B, "l_leg", "r_arm")
	combat_stance_assert(A.combat_zone_scores(B, W, COMBAT_ATTACK_WEAPON)["head"] > head_before, "low_attack_opens_head")
	A.last_struck_time = -1000

	// A shield covers its arm and hand.
	var/arm_before = A.combat_zone_scores(B, W, COMBAT_ATTACK_WEAPON)["r_arm"]
	var/obj/item/weapon/shield/S = new /obj/item/weapon/shield(null)
	B.put_in_r_hand(S)
	combat_stance_assert(A.combat_zone_scores(B, W, COMBAT_ATTACK_WEAPON)["r_arm"] < arm_before, "shield_covers_arm")
	B.drop_from_inventory(S)

	// Kicks can't reach the head of someone standing.
	scores = A.combat_zone_scores(B, null, COMBAT_ATTACK_KICK)
	combat_stance_assert(!("head" in scores) && !("mouth" in scores) && ("chest" in scores), "kick_not_high")
	B.lying = TRUE
	combat_stance_assert(("head" in A.combat_zone_scores(B, null, COMBAT_ATTACK_KICK)), "kick_head_when_down")
	B.lying = FALSE

	// A missing limb is never picked.
	B.organs_by_name -= "l_leg"
	combat_stance_assert(!("l_leg" in A.combat_zone_scores(B, W, COMBAT_ATTACK_WEAPON)), "missing_limb_skipped")

	// Picking a zone by doll or hotkey takes manual control back.
	A.combat_stance_doll_clicked()
	combat_stance_assert(A.combat_stance == COMBAT_STANCE_MANUAL, "doll_click_manual")
	combat_stance_assert(!A.set_combat_stance("flying", TRUE) && A.combat_stance == COMBAT_STANCE_MANUAL, "bad_stance_refused")

	// A real swing records who struck and with which arm.
	A.set_combat_stance(COMBAT_STANCE_MEASURED, TRUE)
	A.next_move = 0
	B.attackby(W, A)
	combat_stance_assert(B.recently_struck_by(A) && B.last_struck_limb == "r_arm" && (B.last_struck_zone in combat_auto_zones) && A.last_auto_zone == B.last_struck_zone, "swing_recorded")

	// Agents see and set it.
	combat_stance_assert(agent_stance_row(A)["combat"] == COMBAT_STANCE_MEASURED, "agent_row")

	// Examine shows the stance.
	var/datum/gender/T = new /datum/gender/neuter
	combat_stance_assert(findtext(A.combat_stance_examine_line(T), "opening"), "examine_line")

/world/New()
	OpenPort("none")
	var/error = null
	try
		combat_stance_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && combat_stance_runtime)
		error = combat_stance_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = combat_stance_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
