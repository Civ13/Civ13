// Full-source probe: carrying a handful of rounds or arrows in one hand, the
// tightened grip, spilling it on a fall and blows to the hand. Real humans,
// rounds and magazines; random outcomes are retried until they happen.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/held_grip_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/held_grip_probe/New()
	map = src

/turf/floor/plating/held_grip_probe

var/held_grip_probe_checks = 0
var/held_grip_runtime = null

/world/Error(exception/e)
	if (!held_grip_runtime)
		held_grip_runtime = "runtime [e] ([e.file]:[e.line])"

/proc/held_grip_assert(ok, label)
	held_grip_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/held_grip_actor(tx, ty)
	var/mob/living/human/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.real_name = "Archer"
	H.name = H.real_name
	return H

/proc/held_grip_stand(mob/living/human/H)
	H.weakened = 0
	H.stunned = 0
	H.paralysis = 0
	H.lying = FALSE
	H.update_canmove()

/proc/held_grip_count(turf/center, path)
	. = 0
	for (var/turf/T in range(1, center))
		for (var/obj/item/ammo_casing/C in T)
			if (C.type == path)
				.++

/proc/held_grip_handful(mob/living/human/H, path, n)
	var/obj/item/ammo_casing/first = new path(H.loc)
	var/obj/item/ammo_casing/second = new path(H.loc)
	H.hand = 0 // right hand active
	held_grip_assert(H.put_in_r_hand(first), "first_round_in_hand")
	held_grip_assert(first.resolve_attackby(second, H), "round_on_round_makes_handful")
	var/obj/item/ammo_handful/HF = H.r_hand
	held_grip_assert(istype(HF) && HF.round_count() == 2, "handful_of_two_in_active_hand")
	for (var/i in 3 to n)
		HF.attackby(new path(H.loc), H)
	return HF

/proc/held_grip_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	map = new /obj/map_metadata/held_grip_probe
	held_grip_assert(world.byond_version == 516 && world.byond_build == 1688, "pinned_native_engine")

	// Sensible amounts per hand.
	var/obj/item/ammo_casing/arrow/iron/A = new(null)
	var/obj/item/ammo_casing/a65x50/R = new(null)
	var/obj/item/ammo_casing/atlatl_dart/D = new(null)
	var/obj/item/ammo_casing/rocket/K = new(null)
	held_grip_assert(A.handful_capacity() == 6 && R.handful_capacity() == 10 && D.handful_capacity() == 3, "capacities")
	held_grip_assert(!K.handful_capacity(), "rockets_never_handful")
	held_grip_assert(!A.handful_compatible(new /obj/item/ammo_casing/arrow/flint(null)), "kinds_do_not_mix")
	R.expend()
	held_grip_assert(!R.handful_compatible(new /obj/item/ammo_casing/a65x50(null)), "spent_brass_not_held")
	held_grip_assert(issaved(A.grip_tightened) == FALSE, "grip_not_saved")

	// Gathering from the floor stops at the cap and leaves the rest.
	var/mob/living/human/H = held_grip_actor(5, 5)
	var/obj/item/ammo_handful/HF = held_grip_handful(H, /obj/item/ammo_casing/arrow/iron, 2)
	var/turf/floor = locate(6, 5, 1)
	var/obj/item/ammo_casing/arrow/iron/first_floor
	for (var/i in 1 to 6)
		var/obj/item/ammo_casing/arrow/iron/F = new(floor)
		if (!first_floor)
			first_floor = F
	HF.resolve_attackby(first_floor, H)
	held_grip_assert(HF.round_count() == 6, "gathered_up_to_six")
	var/left_on_floor = 0
	for (var/obj/item/ammo_casing/arrow/iron/F in floor)
		left_on_floor++
	held_grip_assert(left_on_floor == 2, "rest_left_on_floor")
	HF.attackby(new /obj/item/ammo_casing/arrow/iron(H.loc), H)
	held_grip_assert(HF.round_count() == 6, "full_handful_refuses_more")
	held_grip_assert(findtext(HF.name, "(6)"), "name_shows_count")

	// A tight grip keeps the handful closed and in hand.
	HF.attack_self(H)
	held_grip_assert(HF.grip_tightened, "use_in_hand_tightens")
	H.hand = 1 // left hand active and empty
	HF.attack_hand(H)
	held_grip_assert(!H.l_hand && HF.round_count() == 6, "tight_grip_blocks_taking")
	for (var/i in 1 to 30)
		held_grip_stand(H)
		H.Weaken(3)
	held_grip_assert(H.r_hand == HF && HF.round_count() == 6, "tight_grip_survives_falls")
	held_grip_stand(H)
	var/broke = FALSE
	for (var/i in 1 to 200)
		H.hand_struck("r_hand", 100)
		if (!HF.grip_tightened)
			broke = TRUE
			break
	held_grip_assert(broke && H.r_hand == HF, "blow_breaks_grip_first")

	// Loose, one item at a time comes out into the empty hand.
	held_grip_stand(H)
	H.hand = 1
	HF.attack_hand(H)
	held_grip_assert(istype(H.l_hand, /obj/item/ammo_casing/arrow/iron) && HF.round_count() == 5, "take_one_out")
	var/obj/item/taken = H.l_hand
	H.drop_from_inventory(taken)
	qdel(taken)

	// Tighten, drop, pick up: the grip does not come back on its own.
	HF.toggle_grip(H)
	H.drop_from_inventory(HF)
	held_grip_assert(!HF.grip_tightened, "dropping_loosens")
	H.hand = 0
	H.put_in_r_hand(HF)

	// Knocked down with a loose grip: the arrows scatter, none are lost.
	var/total_before = held_grip_count(H.loc, /obj/item/ammo_casing/arrow/iron) + HF.round_count()
	var/spilled = FALSE
	for (var/i in 1 to 100)
		held_grip_stand(H)
		H.Weaken(3)
		if (H.r_hand != HF)
			spilled = TRUE
			break
	held_grip_assert(spilled && QDELETED(HF), "loose_handful_spills_on_fall")
	held_grip_assert(held_grip_count(H.loc, /obj/item/ammo_casing/arrow/iron) == total_before, "spill_keeps_every_arrow")
	for (var/turf/T in range(1, H.loc))
		for (var/obj/item/ammo_casing/C in T)
			qdel(C)

	// Down to one: the handful turns back into a plain round in that hand.
	held_grip_stand(H)
	HF = held_grip_handful(H, /obj/item/ammo_casing/a65x50, 2)
	H.hand = 1
	HF.attack_hand(H)
	held_grip_assert(istype(H.r_hand, /obj/item/ammo_casing/a65x50) && istype(H.l_hand, /obj/item/ammo_casing/a65x50), "last_round_back_to_plain")
	H.drop_from_inventory(H.l_hand)
	H.drop_from_inventory(H.r_hand)

	// Loading a clip from a handful fills it and keeps the rest.
	HF = held_grip_handful(H, /obj/item/ammo_casing/a65x50, 7)
	var/obj/item/ammo_magazine/emptyclip/clip = new(H.loc)
	HF.toggle_grip(H)
	HF.resolve_attackby(clip, H)
	held_grip_assert(!clip.stored_ammo.len && HF.round_count() == 7, "tight_grip_blocks_loading")
	HF.toggle_grip(H)
	HF.resolve_attackby(clip, H)
	held_grip_assert(clip.stored_ammo.len == clip.max_ammo && HF.round_count() == 7 - clip.max_ammo, "clip_filled_from_handful")

	// A blow to a hand holding a plain item can knock it away.
	var/mob/living/human/V = held_grip_actor(8, 8)
	var/obj/item/weapon/W = new /obj/item/weapon/material/kitchen/utensil/knife(V.loc)
	V.put_in_l_hand(W)
	var/knocked = FALSE
	for (var/i in 1 to 200)
		V.hand_struck("l_hand", 100)
		if (V.l_hand != W)
			knocked = TRUE
			break
	held_grip_assert(knocked && W.loc == V.loc, "hand_blow_disarms")
	held_grip_assert(!V.hand_struck("l_hand", 100), "empty_hand_nothing_to_knock")
	held_grip_assert(hand_strike_drop_chance(2) == 5 && hand_strike_drop_chance(1000) == 40, "hand_blow_chance_bounded")

/world/New()
	OpenPort("none")
	var/error = null
	try
		held_grip_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && held_grip_runtime)
		error = held_grip_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = held_grip_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
