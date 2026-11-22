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
	C.armor_family = null // the flat list below, the same against every kind of hit
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

// A fixed rank for the probe, in place of earned school points.
var/combat_stance_probe_rank = 0
/mob/living/human/martial_rank(school_id)
	return school_id == martial_school ? combat_stance_probe_rank : 0

// Fires a ready reaction up to `tries` times; TRUE if it ever stops the action.
/proc/combat_stance_react(mob/living/human/D, mob/living/human/A, trigger, zone, obj/item/W, tries = 40)
	for (var/i in 1 to tries)
		D.next_combat_reaction = 0
		D.next_martial_reflex = 0
		D.stats["stamina"] = list(100, 100)
		D.next_click = world.time - 100
		A.loc = locate(D.x - 1, D.y, D.z) // a landed counter may knock them back
		if (D.combat_reaction_try(A, trigger, zone, W))
			return TRUE
	return FALSE

/proc/combat_stance_probe_reactions()
	var/mob/living/human/A = combat_stance_actor(5, 7, "Swinger")
	var/mob/living/human/D = combat_stance_actor(6, 7, "Fighter")
	D.dir = SOUTH

	// Martial reflexes: Wing Chun Bong Sau turns a chest punch aside.
	D.martial_school = "wing_chun"
	combat_stance_probe_rank = MARTIAL_RANK_NOVICE
	combat_stance_assert(!combat_stance_react(D, A, COMBAT_TRIGGER_INCOMING, "chest", null), "novice_no_reflex")
	combat_stance_probe_rank = MARTIAL_RANK_MASTER
	D.stats["dexterity"] = list(300, 300)
	combat_stance_assert(combat_stance_react(D, A, COMBAT_TRIGGER_INCOMING, "chest", null), "bong_sau_chest_punch")
	combat_stance_assert(D.next_martial_reflex > world.time, "reflex_cooldown_set")
	combat_stance_assert(!combat_stance_react(D, A, COMBAT_TRIGGER_INCOMING, "head", null), "bong_sau_only_chest")
	var/obj/item/weapon/W = new /obj/item/weapon/wrench(null)
	combat_stance_assert(!combat_stance_react(D, A, COMBAT_TRIGGER_INCOMING, "chest", W), "bong_sau_not_against_weapons")
	D.a_intent = I_HELP
	combat_stance_assert(!combat_stance_react(D, A, COMBAT_TRIGGER_INCOMING, "chest", null), "help_intent_no_reflex")
	D.a_intent = I_HARM
	var/obj/item/weapon/DW = new /obj/item/weapon/wrench(null)
	D.put_in_active_hand(DW)
	combat_stance_assert(!combat_stance_react(D, A, COMBAT_TRIGGER_INCOMING, "chest", null), "held_weapon_no_hand_reflex")
	D.drop_from_inventory(DW)
	D.dir = EAST
	combat_stance_assert(!combat_stance_react(D, A, COMBAT_TRIGGER_INCOMING, "chest", null), "never_from_behind")
	D.dir = SOUTH
	A.in_combat_reaction = TRUE
	combat_stance_assert(!combat_stance_react(D, A, COMBAT_TRIGGER_INCOMING, "chest", null), "reaction_never_answers_reaction")
	A.in_combat_reaction = FALSE
	// Busy clicking: no reflex.
	D.next_martial_reflex = 0
	D.next_click = world.time
	combat_stance_assert(!D.combat_reaction_try(A, COMBAT_TRIGGER_INCOMING, "chest", null), "busy_no_reflex")
	D.martial_school = "pugilism"
	combat_stance_assert(combat_stance_react(D, A, COMBAT_TRIGGER_INCOMING, "head", null) && !combat_stance_react(D, A, COMBAT_TRIGGER_INCOMING, "chest", null), "pugilism_slips_head_punch")
	D.martial_school = "grappling"
	combat_stance_assert(combat_stance_react(D, A, COMBAT_TRIGGER_GRAB_REACH, "chest", null), "grappling_sprawls_grab")
	D.martial_school = null

	// Stance reactions need training: average skill never reacts.
	D.stats["dexterity"] = list(100, 100)
	D.set_combat_stance(COMBAT_STANCE_MEASURED, TRUE)
	D.put_in_active_hand(DW)
	combat_stance_assert(!combat_stance_react(D, A, COMBAT_TRIGGER_INCOMING, "chest", W), "untrained_no_stance_reaction")
	// A trained Measured fighter stop-hits the swinging arm.
	D.stats["dexterity"] = list(200, 200)
	A.note_struck_by(D, "chest", "r_arm")
	A.last_struck_time = -1000
	combat_stance_assert(combat_stance_react(D, A, COMBAT_TRIGGER_INCOMING, "chest", W), "measured_stop_hit")
	combat_stance_assert(D.next_move <= world.time, "stop_hit_keeps_click_cooldown")
	combat_stance_assert(D.next_combat_reaction > world.time, "stance_cooldown_set")
	// A winded fighter can't pay for the swing, so the incoming swing is not stopped.
	D.next_combat_reaction = 0
	D.stats["stamina"] = list(COMBAT_REACTION_STAMINA, 100)
	A.loc = locate(D.x - 1, D.y, D.z)
	combat_stance_assert(!D.combat_reaction_try(A, COMBAT_TRIGGER_INCOMING, "chest", W), "winded_no_stop_hit")
	// A sword answers to sword skill: high dexterity alone does not unlock it.
	var/obj/item/weapon/material/sword/S = new(null)
	combat_stance_assert(D.combat_reactions_unlocked(null) && !D.combat_reactions_unlocked(S), "weapon_skill_not_dexterity")
	D.stats["swords"] = list(200, 200)
	combat_stance_assert(D.combat_reactions_unlocked(S), "weapon_skill_unlocks")
	// Guarded ripostes after a parry and counters after a hit; it can't stop a swing.
	D.set_combat_stance(COMBAT_STANCE_GUARDED, TRUE)
	combat_stance_assert(!combat_stance_react(D, A, COMBAT_TRIGGER_INCOMING, "chest", W), "guarded_no_stop_hit")
	var/fired = FALSE
	var/stopped = FALSE
	for (var/i in 1 to 40)
		D.next_combat_reaction = 0
		D.stats["stamina"] = list(100, 100)
		A.loc = locate(D.x - 1, D.y, D.z)
		if (D.combat_reaction_try(A, COMBAT_TRIGGER_AFTER_HIT, "chest", W))
			stopped = TRUE
		if (D.next_combat_reaction > world.time)
			fired = TRUE
	combat_stance_assert(fired && !stopped, "guarded_counter_fires_without_stopping")
	// Disarming strikes the reaching arm and stops the grab.
	D.set_combat_stance(COMBAT_STANCE_DISARMING, TRUE)
	combat_stance_assert(combat_stance_react(D, A, COMBAT_TRIGGER_GRAB_REACH, "chest", null), "disarming_stops_grab")
	// Manual has no stance reactions.
	D.set_combat_stance(COMBAT_STANCE_MANUAL, TRUE)
	combat_stance_assert(!combat_stance_react(D, A, COMBAT_TRIGGER_GRAB_REACH, "chest", null), "manual_no_reactions")
	// A forced zone wins over the stance.
	A.forced_attack_zone = "l_foot"
	combat_stance_assert(A.resolve_attack_zone(D, W) == "l_foot", "forced_zone")
	A.forced_attack_zone = null

// Steps a Restrain-stance grab click; clears the grab's wait between clicks.
/proc/combat_stance_restrain_click(mob/living/human/A, mob/living/human/T, obj/item/weapon/grab/G)
	G.last_action = world.time - 1000
	A.may_do_after = TRUE
	A.a_intent = I_GRAB
	G.attack(T, A)

/proc/combat_stance_probe_restrain()
	var/mob/living/human/A = combat_stance_actor(3, 3, "Arrester")
	var/mob/living/human/T = combat_stance_actor(4, 3, "Suspect")
	A.dir = EAST
	T.dir = WEST
	var/obj/item/weapon/TW = new /obj/item/weapon/wrench(null)
	T.put_in_active_hand(TW)
	A.set_combat_stance(COMBAT_STANCE_RESTRAIN, TRUE)
	combat_stance_assert(A.combat_stance == COMBAT_STANCE_RESTRAIN, "restrain_is_a_stance")
	combat_stance_assert(A.resolve_attack_zone(T, null, COMBAT_ATTACK_GRAB) == "r_hand", "restrain_grabs_weapon_wrist")
	var/obj/item/weapon/grab/G = new /obj/item/weapon/grab(A, T)
	A.put_in_active_hand(G)
	G.synch()
	G.grabbed_zone = "r_hand"
	// Untrained: the click is the ordinary grab-intent jointlock, which needs a firm hold.
	combat_stance_restrain_click(A, T, G)
	combat_stance_assert(G.state < GRAB_AGGRESSIVE && !G.restrain_locked, "untrained_no_restrain_flow")
	A.stats["dexterity"] = list(200, 200)
	combat_stance_assert(A.restrain_lock_zone(G) == "r_arm", "lock_bends_grabbed_arm")
	var/obj/item/organ/external/right_arm = T.get_organ("r_arm")
	right_arm.dislocated = -1 // cannot be locked
	combat_stance_assert(A.restrain_lock_zone(G) == "l_arm", "lock_falls_back_to_other_arm")
	right_arm.dislocated = 0
	combat_stance_restrain_click(A, T, G)
	combat_stance_assert(G.state == GRAB_AGGRESSIVE, "restrain_firm_hold")
	combat_stance_restrain_click(A, T, G)
	combat_stance_assert(G.restrain_locked && !T.lying, "restrain_jointlock")
	combat_stance_restrain_click(A, T, G)
	combat_stance_assert(T.lying && G.force_down, "restrain_pin_down")
	combat_stance_restrain_click(A, T, G)
	combat_stance_assert(!T.handcuffed, "restrain_needs_restraints")
	var/obj/item/weapon/handcuffs/rope/R = new(null)
	A.equip_to_slot(R, slot_l_store)
	combat_stance_assert(A.restrain_find_item(/obj/item/weapon/handcuffs) == R, "restrain_finds_pocket_rope")
	var/obj/item/weapon/wrench/busy = new(null)
	A.put_in_inactive_hand(busy)
	combat_stance_assert(!A.restrain_take_in_hand(R) && A.l_store == R, "restrain_needs_free_hand")
	A.drop_from_inventory(busy)
	combat_stance_restrain_click(A, T, G)
	combat_stance_assert(T.handcuffed == R && !A.l_store, "restrain_binds_hands")
	var/obj/item/weapon/legcuffs/L = new(null)
	A.put_in_inactive_hand(L)
	combat_stance_restrain_click(A, T, G)
	combat_stance_assert(T.legcuffed == L, "restrain_binds_legs")
	var/obj/item/clothing/mask/muzzle/tape/gag = new(null)
	A.equip_to_slot(gag, slot_r_store)
	var/obj/item/clothing/glasses/sunglasses/blindfold/fold = new(null)
	A.equip_to_slot(fold, slot_l_store)
	combat_stance_restrain_click(A, T, G)
	combat_stance_assert(T.wear_mask == gag && !T.eyes, "restrain_gags_first")
	combat_stance_restrain_click(A, T, G)
	combat_stance_assert(T.eyes == fold, "restrain_blindfolds")
	combat_stance_restrain_click(A, T, G)
	combat_stance_assert(!QDELETED(G) && G.state == GRAB_AGGRESSIVE, "restrain_never_past_firm_hold")
	combat_stance_assert(findtext(A.combat_stance_examine_line(new /datum/gender/neuter), "grapple"), "restrain_examine_line")

/world/New()
	OpenPort("none")
	var/error = null
	try
		combat_stance_probe_run()
		combat_stance_probe_reactions()
		combat_stance_probe_restrain()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && combat_stance_runtime)
		error = combat_stance_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = combat_stance_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
