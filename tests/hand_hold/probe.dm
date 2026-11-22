// Full-source probe: body-part grabs and holding hands. A grab on an empty hand
// holds it and gives both people a hand to drop; either drop lets go. A firm
// grip can't be dropped by the held person, and trying counts as a resist.
// Full hands, sleepers and other parts take an ordinary grab.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/hand_hold_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/hand_hold_probe/New()
	map = src

/turf/floor/plating/hand_hold_probe

var/hand_hold_probe_checks = 0
var/hand_hold_runtime = null

/world/Error(exception/e)
	if (!hand_hold_runtime)
		hand_hold_runtime = "runtime [e] ([e.file]:[e.line])"

/proc/hand_hold_assert(ok, label)
	hand_hold_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/hand_hold_actor(tx, ty, name)
	var/mob/living/human/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.real_name = name
	H.name = name
	H.hand = 0
	return H

// Grabber takes hold of target at zone; returns the grab in the grabber's hand.
/proc/hand_hold_grab(mob/living/human/grabber, mob/living/human/target, zone)
	grabber.a_intent = I_GRAB
	grabber.targeted_organ = zone
	target.attack_hand(grabber)
	return grabber.r_hand

/proc/hand_hold_reinforce(obj/item/weapon/grab/G)
	G.last_action = -1000
	G.assailant.next_move = 0
	G.s_click(G.hud)

/proc/hand_hold_clear(mob/living/human/grabber, mob/living/human/target)
	for (var/obj/item/weapon/grab/G in target.grabbed_by)
		qdel(G)
	for (var/obj/item/I in list(grabber.l_hand, grabber.r_hand, target.l_hand, target.r_hand))
		qdel(I)
	target.canmove = TRUE
	target.stat = CONSCIOUS

/proc/hand_hold_probe_run()
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
	map = new /obj/map_metadata/hand_hold_probe

	var/mob/living/human/A = hand_hold_actor(5, 5, "Alice")
	var/mob/living/human/B = hand_hold_actor(6, 5, "Bob")

	// Messages name the part; a full hand is taken by the wrist.
	hand_hold_assert(grab_zone_description("chest", B) == null && grab_zone_description("eyes", B) == "head" && grab_zone_description("l_arm", B) == "left arm" && grab_zone_description("r_hand", B) == "right hand", "zone_descriptions")

	// An empty hand: both hold hands.
	var/obj/item/weapon/grab/G = hand_hold_grab(A, B, "l_hand")
	hand_hold_assert(istype(G) && G.grabbed_zone == "l_hand" && G.affecting == B, "grab_records_zone")
	var/obj/item/hand_hold/P = B.l_hand
	hand_hold_assert(istype(P) && G.hand_partner == P && P.grab == G && P.holder == B, "both_get_a_hand")
	hand_hold_assert(!P.player_drop_refused(B), "loose_hold_drops")

	// The held person drops theirs: both let go.
	B.drop_l_hand()
	hand_hold_assert(!B.l_hand && !A.r_hand && !B.grabbed_by.len && QDELETED(G) && QDELETED(P), "held_person_lets_go")

	// The grabber drops theirs: both let go.
	G = hand_hold_grab(A, B, "l_hand")
	P = B.l_hand
	hand_hold_assert(istype(P), "hold_again")
	A.drop_r_hand()
	hand_hold_assert(!B.l_hand && !A.r_hand && !B.grabbed_by.len && QDELETED(P), "grabber_lets_go")

	// Resisting a loose hold frees the hand.
	G = hand_hold_grab(A, B, "r_hand")
	P = B.r_hand
	hand_hold_assert(istype(P) && G.hand_partner == P, "right_hand_hold")
	hand_hold_assert(!B.hand_hold_leash_blocks(locate(8, 5, 1)), "loose_hold_no_leash")
	B.resist_grab()
	hand_hold_assert(!B.r_hand && !A.r_hand && QDELETED(P), "resist_frees_loose_hold")

	// Reinforcing: a firm grip, no further, and the other hand stays free.
	var/obj/item/weapon/W = new /obj/item/weapon/wrench(null)
	B.put_in_r_hand(W)
	G = hand_hold_grab(A, B, "l_hand")
	P = B.l_hand
	hand_hold_reinforce(G)
	hand_hold_assert(G.state == GRAB_AGGRESSIVE && P.firm(), "reinforce_firms_grip")
	hand_hold_reinforce(G)
	hand_hold_assert(G.state == GRAB_AGGRESSIVE, "hand_grip_goes_no_further")
	G.process()
	B.update_canmove()
	hand_hold_assert(B.r_hand == W && B.l_hand == P && B.canmove, "firm_grip_other_hand_free_can_move")
	// The firm grip keeps them beside the grabber at (5,5).
	hand_hold_assert(B.hand_hold_leash_blocks(locate(7, 5, 1)) == A && B.hand_hold_leash_blocks(locate(6, 7, 1)) == A, "firm_grip_blocks_stepping_away")
	hand_hold_assert(!B.hand_hold_leash_blocks(locate(6, 6, 1)) && !B.hand_hold_leash_blocks(locate(5, 6, 1)) && !B.hand_hold_leash_blocks(locate(4, 4, 1)), "firm_grip_allows_tiles_beside_grabber")

	// A firm grip can't be dropped; trying is a resist that eventually frees them.
	hand_hold_assert(!B.drop_l_hand() && B.l_hand == P, "firm_grip_wont_drop")
	var/freed = FALSE
	for (var/i in 1 to 400)
		B.next_move = 0
		hand_hold_assert(P.player_drop_refused(B), "firm_drop_refused")
		if (QDELETED(G))
			freed = TRUE
			break
	hand_hold_assert(freed && !B.l_hand && !A.r_hand && B.r_hand == W, "drop_attempts_resist_free")
	hand_hold_clear(A, B)

	// Passing out lets go of a firm grip.
	G = hand_hold_grab(A, B, "l_hand")
	P = B.l_hand
	hand_hold_reinforce(G)
	B.stat = UNCONSCIOUS
	hand_hold_assert(B.drop_l_hand() && !A.r_hand && QDELETED(P), "unconscious_lets_go")
	hand_hold_clear(A, B)

	// A full hand is grabbed by the wrist like an ordinary grab.
	var/obj/item/weapon/W2 = new /obj/item/weapon/wrench(null)
	B.put_in_l_hand(W2)
	G = hand_hold_grab(A, B, "l_hand")
	hand_hold_assert(istype(G) && !G.hand_partner && B.l_hand == W2, "full_hand_ordinary_grab")
	hand_hold_clear(A, B)

	// Someone asleep can't hold hands.
	B.stat = UNCONSCIOUS
	G = hand_hold_grab(A, B, "r_hand")
	hand_hold_assert(istype(G) && !G.hand_partner && !B.r_hand, "sleeper_ordinary_grab")
	hand_hold_clear(A, B)

	// Other parts take an ordinary grab on that part, which reinforces as before.
	G = hand_hold_grab(A, B, "l_arm")
	hand_hold_assert(istype(G) && !G.hand_partner && G.grabbed_zone == "l_arm" && !B.l_hand && !B.r_hand, "arm_grab")
	hand_hold_reinforce(G)
	hand_hold_reinforce(G)
	hand_hold_assert(G.state == GRAB_NECK, "ordinary_grab_still_upgrades")
	G.process()
	B.update_canmove()
	hand_hold_assert(!B.canmove, "ordinary_reinforced_grab_still_holds_in_place")
	hand_hold_clear(A, B)

	// A missing part can't be grabbed; a random target falls back to the chest.
	B.organs_by_name -= "l_foot"
	hand_hold_assert(B.grab_target_zone("l_foot") == null && B.grab_target_zone("l_foot", TRUE) == "chest" && B.grab_target_zone("l_arm") == "l_arm", "missing_part")
	G = hand_hold_grab(A, B, "l_foot")
	hand_hold_assert(!A.r_hand && !B.grabbed_by.len, "missing_part_not_grabbed")

	// Strength and dexterity tilt contests; equals keep the old odds.
	A.mood_modifier = 1
	B.mood_modifier = 1
	A.stats["strength"] = list(100, 100)
	B.stats["strength"] = list(100, 100)
	A.stats["dexterity"] = list(100, 100)
	B.stats["dexterity"] = list(100, 100)
	hand_hold_assert(physical_contest_ratio(A, B, 0.6, 0.4) == 1 && physical_contest_chance(19, 1) == 19, "equals_keep_old_odds")
	G = hand_hold_grab(A, B, "l_arm")
	hand_hold_assert(G.grab_upgrade_cooldown() == 40, "equal_upgrade_cooldown")
	A.stats["strength"] = list(300, 300)
	A.stats["dexterity"] = list(300, 300)
	hand_hold_assert(physical_contest_ratio(A, B, 0.6, 0.4) == 2 && physical_contest_ratio(B, A, 0.6, 0.4) == 0.5, "ratio_bounded")
	hand_hold_assert(G.grab_upgrade_cooldown() == 20 && physical_contest_chance(19, 2) == 38 && physical_contest_chance(60, 2) == 95 && physical_contest_chance(1, 0.5) == 1, "strong_grabber_and_bounds")
	A.stats["strength"] = list(150, 150)
	A.stats["dexterity"] = list(100, 100)
	hand_hold_assert(physical_contest_ratio(A, B, 1, 0) == 1.5 && physical_contest_ratio(A, B, 0, 1) == 1, "stats_weighted")
	hand_hold_clear(A, B)

/world/New()
	OpenPort("none")
	var/error = null
	try
		hand_hold_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && hand_hold_runtime)
		error = hand_hold_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = hand_hold_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
