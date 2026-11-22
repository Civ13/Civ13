// The seabed: divers, depth zones and the submarine's lock-out hatch.
//
// The sea layer (sea_layer.dm) is open water over the seabed. A person may
// walk it only sealed in a diving suit: the suit, its helmet and an air
// bottle with air in it (pressure_suits.dm does the sealing, breathing and
// wear). Out here the water stands in for vacuum through the outside
// exposure hooks (outside_exposure.dm): there is nothing to breathe, and the
// cold depends on how deep the water is.
//
// Depth comes from distance to the nearest rock, worked out once a round
// after the sea layer pass: the shelf near the coast, then open water, the
// deep and the abyss far from any land. A suit is built for a zone; deeper
// than that the water squeezes it until it tears, and a torn suit floods.
//
// Divers leave and board a submerged submarine only through a lock-out
// hatch amidships (the boat's side hatch sections), which floods or pumps dry
// first. A diver who cannot get back can drop the suit's weights and swim up
// to the open sea straight above, where the suit keeps them afloat while the
// bottle lasts.
//
// The crew can dog the outer hatch shut from inside: a dogged hatch keeps out
// anyone on the seabed, who can only hammer on it for the crew to hear. Whoever
// goes out through it undogs it on the way. The same chamber is the boat's
// escape trunk: a crew member without a suit floods it, opens the outer hatch
// and makes a free ascent to the surface. That is safe on the shelf, hurts in
// open water and kills deeper, so the hatch refuses it there
// (docs/vessel-entries.md).

// Sea zones: code/__defines/_submarine_definitions.dm
// The farthest distance from rock, in tiles, of each zone shallower than the abyss.
#define SEA_ZONE_SHELF_MAX 6
#define SEA_ZONE_OPEN_MAX 16
#define SEA_ZONE_DEEP_MAX 32
// Suit integrity lost per life tick for each zone deeper than its rating.
#define SEABED_CRUSH_WEAR 4
#define SEABED_LOCKOUT_TIME (5 SECONDS)
#define SEABED_ASCENT_TIME (15 SECONDS)
#define SEABED_REFILL_TIME (3 SECONDS)
#define SEABED_HAND_PUMP_TIME (20 SECONDS)
#define SEABED_DOG_TIME (2 SECONDS)
#define SEABED_KNOCK_COOLDOWN (5 SECONDS)
// Breath lost on a free ascent from each zone (shelf, open water).
#define SEABED_ESCAPE_OXYLOSS_SHELF 10
#define SEABED_ESCAPE_OXYLOSS_OPEN 45
#define SEABED_ESCAPE_BRUTE_OPEN 10

var/global/seabed_zones_ready = FALSE
// Cells of each zone after the last pass, for admins and tests.
var/global/list/seabed_zone_counts = list(0, 0, 0, 0)

// Runtime only: worked out again every round. 0 until the pass reaches it,
// which reads as the shelf.
/turf/floor/beach/water/deep/saltwater/underwater/sea_layer/var/depth_zone = 0

/proc/sea_zone_for_distance(distance)
	if (distance <= SEA_ZONE_SHELF_MAX)
		return SEA_ZONE_SHELF
	if (distance <= SEA_ZONE_OPEN_MAX)
		return SEA_ZONE_OPEN
	if (distance <= SEA_ZONE_DEEP_MAX)
		return SEA_ZONE_DEEP
	return SEA_ZONE_ABYSS

/proc/sea_zone_of(turf/T)
	var/turf/floor/beach/water/deep/saltwater/underwater/sea_layer/S = T
	if (!istype(S))
		return 0
	return S.depth_zone || SEA_ZONE_SHELF

/proc/sea_zone_name(zone)
	switch (zone)
		if (SEA_ZONE_SHELF)
			return "the shelf"
		if (SEA_ZONE_OPEN)
			return "open water"
		if (SEA_ZONE_DEEP)
			return "the deep"
		if (SEA_ZONE_ABYSS)
			return "the abyss"
	return "dry land"

/proc/sea_zone_temperature_c(zone)
	switch (zone)
		if (SEA_ZONE_SHELF)
			return 14
		if (SEA_ZONE_OPEN)
			return 8
		if (SEA_ZONE_DEEP)
			return 4
	return 2

// Marks every sea cell on level z with its depth zone, by distance (4-way)
// from the nearest cell that is not sea. Works ring by ring outward from the
// rock and yields in bounded batches. Returns the cells marked.
/proc/seabed_zone_pass(z)
	. = 0
	if (!z)
		return
	seabed_zones_ready = FALSE
	var/list/counts = list(0, 0, 0, 0)
	var/list/frontier = list()
	var/work = 0
	for (var/y = 1, y <= world.maxy, y++)
		for (var/x = 1, x <= world.maxx, x++)
			var/turf/floor/beach/water/deep/saltwater/underwater/sea_layer/S = locate(x, y, z)
			if (istype(S))
				S.depth_zone = 0
			if (environment_sweep_pause(++work))
				work = 0
	for (var/y = 1, y <= world.maxy, y++)
		for (var/x = 1, x <= world.maxx, x++)
			var/turf/floor/beach/water/deep/saltwater/underwater/sea_layer/S = locate(x, y, z)
			if (istype(S))
				for (var/d in cardinal)
					var/turf/N = get_step(S, d)
					if (N && !sea_layer_cell(N))
						S.depth_zone = SEA_ZONE_SHELF
						frontier += S
						break
			if (environment_sweep_pause(++work))
				work = 0
	var/distance = 1
	while (frontier.len)
		var/zone = sea_zone_for_distance(distance)
		counts[zone] += frontier.len
		. += frontier.len
		var/next_zone = sea_zone_for_distance(distance + 1)
		var/list/next = list()
		for (var/turf/S in frontier)
			for (var/d in cardinal)
				var/turf/floor/beach/water/deep/saltwater/underwater/sea_layer/N = get_step(S, d)
				if (istype(N) && !N.depth_zone)
					N.depth_zone = next_zone
					next += N
			if (environment_sweep_pause(++work))
				work = 0
		frontier = next
		distance++
	seabed_zone_counts = counts
	seabed_zones_ready = TRUE

// ---- The water ----

// Aboard a submarine the crew breathe its hull air (submarine_air.dm).
/turf/floor/beach/water/deep/saltwater/underwater/sea_layer/outside_air_breathable()
	if (!iscovered())
		return FALSE
	var/obj/structure/vehicleparts/axis/ship/submarine/B = submarine_at(src)
	return B ? B.air_breathable() : TRUE

/turf/floor/beach/water/deep/saltwater/underwater/sea_layer/outside_ambient_c()
	if (iscovered())
		return null
	return sea_zone_temperature_c(sea_zone_of(src))

// Whatever is dropped down here comes to rest on the seabed.
/turf/floor/beach/water/deep/saltwater/underwater/sea_layer/check_sinking(atom/movable/A)
	return

/turf/floor/beach/water/deep/saltwater/underwater/sea_layer/examine(mob/user)
	..()
	if (!iscovered())
		to_chat(user, SPAN_NOTICE("This is [sea_zone_name(sea_zone_of(src))]."))

// ---- Divers ----

/mob/proc/can_walk_seabed()
	return FALSE

/mob/living/human/can_walk_seabed()
	return seabed_diving_rating() > 0 || free_diving

// The depth zone a sealed diving suit stands up to, or 0 when not sealed in one.
/mob/living/human/proc/seabed_diving_rating()
	if (!pressure_suit_sealed())
		return 0
	var/obj/item/clothing/suit/pressure_suit/S = wear_suit
	return S.depth_rating

/mob/living/human/var/tmp/seabed_last_zone = 0

// One life tick out on the seabed: depth news and the squeeze on a suit
// that is not built for this deep.
/mob/living/human/proc/seabed_exposure_step(turf/T)
	if (!sea_layer_cell(T) || T.iscovered() || stat == DEAD)
		seabed_last_zone = 0
		return
	var/zone = sea_zone_of(T)
	if (zone != seabed_last_zone)
		if (seabed_last_zone)
			to_chat(src, zone > seabed_last_zone ? SPAN_WARNING("The seabed falls away: you are in [sea_zone_name(zone)] now.") : SPAN_NOTICE("The seabed rises: you are back in [sea_zone_name(zone)]."))
		else
			to_chat(src, SPAN_NOTICE("You are out on the seabed, in [sea_zone_name(zone)]."))
		seabed_last_zone = zone
	var/obj/item/clothing/suit/pressure_suit/S = wear_suit
	if (!istype(S) || S.integrity <= 0)
		return
	var/over = zone - S.depth_rating
	if (over <= 0)
		return
	if (S.wear_down(SEABED_CRUSH_WEAR * over))
		to_chat(src, SPAN_DANGER("The sea crushes \the [S] in and water floods your helmet!"))
	else if (prob(30))
		to_chat(src, SPAN_WARNING("\The [S] groans under the weight of the water. It is not built for [sea_zone_name(zone)]."))

// Drops the weights and swims up to the open sea straight above.
/mob/living/human/proc/seabed_ascend()
	var/turf/T = get_turf(src)
	if (!sea_layer_cell(T) || T.iscovered())
		to_chat(src, SPAN_WARNING("You are not out on the seabed."))
		return FALSE
	var/turf/up = locate(T.x, T.y, multiz_level_above(T.z))
	if (!sea_layer_open_surface(up) || up.iscovered())
		to_chat(src, SPAN_WARNING("Something floats on the water above you. Swim clear of it first."))
		return FALSE
	visible_message(SPAN_NOTICE("[src] drops a pair of lead weights and kicks for the surface."))
	if (!do_after(src, SEABED_ASCENT_TIME, src))
		return FALSE
	T = get_turf(src)
	up = sea_layer_cell(T) ? locate(T.x, T.y, multiz_level_above(T.z)) : null
	if (!sea_layer_open_surface(up) || up.iscovered())
		return FALSE
	forceMove(up)
	to_chat(src, SPAN_NOTICE("You break the surface. The suit keeps you afloat while your air lasts: find a boat or the shore."))
	return TRUE

// ---- Diving gear ----

/obj/item/clothing/suit/pressure_suit/diving
	name = "diving dress"
	desc = "A rubberised canvas suit with weighted boots and a breastplate for the helmet. Sealed with a diving helmet and an air bottle on your back it lets you walk the seabed outside a submarine, but only on the shelf near the coast: deeper water crushes it."
	icon = 'icons/obj/clothing/diving.dmi'
	icon_state = "diving_dress"
	item_state = "diving_dress"
	item_icons = list(slot_wear_suit_str = 'icons/mob/diving.dmi')
	has_heater = FALSE
	heater_charge = 0
	depth_rating = SEA_ZONE_SHELF
	slowdown = 2

/obj/item/clothing/suit/pressure_suit/diving/verb/emergency_ascent()
	set name = "Drop Weights and Ascend"
	set category = "IC"
	set src in usr
	var/mob/living/human/H = usr
	if (!istype(H) || H.wear_suit != src || H.stat || H.restrained())
		return
	H.seabed_ascend()

/obj/item/clothing/head/pressure_helmet/diving
	name = "diving helmet"
	desc = "A brass helmet with glass ports and a lamp. It locks onto a diving dress. Use it in hand to switch the lamp on or off."
	icon = 'icons/obj/clothing/diving.dmi'
	icon_state = "diving_helmet"
	item_state = "diving_helmet"
	// No held art of its own: in the hand it shows the generic helmet.
	item_state_slots = list(
		slot_l_hand_str = "helmet",
		slot_r_hand_str = "helmet",
		)
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_hats.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_hats.dmi',
		slot_head_str = 'icons/mob/diving.dmi',
		)
	brightness_on = 4

/obj/item/pressure_tank/diving
	name = "diving air bottle"
	desc = "Compressed air for a diving helmet. Wear it on your back. Refill it at a submarine's ballast station, a habitat module's core or a landed lander."
	icon = 'icons/obj/clothing/diving.dmi'
	icon_state = "diving_bottles"
	item_icons = list(slot_back_str = 'icons/mob/diving.dmi')

// The ballast station fills bottles from the boat's air bank.
/obj/structure/vehicleparts/sub_station/attackby(obj/item/W, mob/user)
	if (!istype(W, /obj/item/pressure_tank))
		return ..()
	var/obj/item/pressure_tank/A = W
	var/obj/structure/vehicleparts/axis/ship/submarine/B = boat()
	if (!B)
		to_chat(user, SPAN_WARNING("The station is not fitted to a submarine."))
		return
	if (A.refill_need() <= 0)
		to_chat(user, SPAN_NOTICE("\The [A] is already full."))
		return
	if (B.air_bank <= 0)
		to_chat(user, SPAN_WARNING("The air bank is empty. Surface to recharge it."))
		return
	to_chat(user, SPAN_NOTICE("You couple \the [A] to the air bank..."))
	if (!do_after(user, SEABED_REFILL_TIME, src) || QDELETED(A) || QDELETED(B))
		return
	A.refill(B.bank_oxygen(A.refill_need()))
	to_chat(user, SPAN_NOTICE("\The [A] now holds about [round(A.air_seconds / 60)] minute\s of air."))

// ---- The lock-out hatch ----

/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch
	desc = "A riveted steel pressure hull section with a side hatch. Submerged, it works as a lock-out chamber: a diver sealed in a diving suit uses it to flood out to the seabed and to pump back in. It is also the boat's escape trunk, and the crew can dog its outer hatch shut from inside."
	// TRUE while the crew have the outer hatch dogged shut from inside.
	var/outer_dogged = FALSE
	var/tmp/last_knock = -1000

/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch/proc/boat()
	var/obj/structure/vehicleparts/axis/ship/submarine/B = axis
	if (!istype(B) || QDELETED(B))
		return null
	return B

// The open seabed cell the outer hatch opens onto, or null.
/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch/proc/lockout_exit()
	var/turf/here = get_turf(src)
	if (!here)
		return null
	for (var/d in cardinal)
		var/turf/N = get_step(here, d)
		if (!sea_layer_cell(N) || N.iscovered() || N.density)
			continue
		var/blocked = FALSE
		for (var/atom/movable/A in N)
			if (A.density)
				blocked = TRUE
				break
		if (!blocked)
			return N
	return null

/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch/attack_hand(mob/living/human/user)
	var/obj/structure/vehicleparts/axis/ship/submarine/B = boat()
	if (!ishuman(user) || !B || !B.submerged)
		return ..()
	if (!Adjacent(user) || user.region_send_held())
		return
	var/turf/here = get_turf(user)
	if (here && here.iscovered())
		inside_menu(user)
	else if (outer_dogged)
		knock(user)
	else
		lock_in(user)

/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch/examine(mob/user)
	. = ..()
	var/obj/structure/vehicleparts/axis/ship/submarine/B = boat()
	if (B && B.submerged)
		to_chat(user, SPAN_NOTICE("Its outer hatch is [outer_dogged ? "dogged shut from inside" : "free to open from the seabed"]."))

// What the crew can do with the hatch from inside a submerged boat.
/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch/proc/inside_menu(mob/living/human/user)
	var/list/options = list("Lock out (diving suit)", "Escape to the surface", outer_dogged ? "Free the outer hatch" : "Dog the outer hatch", "Cancel")
	var/choice = WWinput(user, "The lock-out chamber. What do you do?", "Lock-out hatch", "Cancel", options)
	if (!choice || choice == "Cancel" || QDELETED(src) || !Adjacent(user) || user.incapacitated())
		return
	switch (choice)
		if ("Lock out (diving suit)")
			lock_out(user)
		if ("Escape to the surface")
			escape(user)
		if ("Dog the outer hatch", "Free the outer hatch")
			dog_hatch(user, choice == "Dog the outer hatch")

// Dogs the outer hatch shut (or frees it) from inside.
/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch/proc/dog_hatch(mob/living/human/user, dog)
	if (outer_dogged == dog)
		return FALSE
	if (user && !do_after(user, SEABED_DOG_TIME, src))
		return FALSE
	set_dogged(dog)
	if (user)
		user.visible_message(SPAN_NOTICE("[user] [dog ? "spins the wheel and dogs the outer hatch of the lock-out chamber shut" : "spins the wheel and frees the outer hatch of the lock-out chamber"]."))
	return TRUE

/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch/proc/set_dogged(dog)
	outer_dogged = !!dog
	playsound(loc, 'sound/effects/door_lock_unlock.ogg', 60)

// Why someone on the seabed cannot come in through this hatch, or null.
/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch/proc/lock_in_refusal()
	if (outer_dogged)
		return "The outer hatch is dogged shut from inside. Hammer on it for the crew to let you in."
	return null

// Someone outside hammers on a dogged hatch: the crew hear it.
/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch/proc/knock(mob/living/human/user)
	to_chat(user, SPAN_WARNING(lock_in_refusal()))
	if (world.time < last_knock + SEABED_KNOCK_COOLDOWN)
		return FALSE
	last_knock = world.time
	playsound(loc, 'sound/effects/clang.ogg', 60)
	var/obj/structure/vehicleparts/axis/ship/submarine/B = boat()
	if (B)
		B.crew_message(SPAN_WARNING("Someone hammers on the outer hatch of the lock-out chamber."))
	user.visible_message(SPAN_NOTICE("[user] hammers on the outer hatch."))
	return TRUE

// Why a crew member cannot make a free ascent from here, or null.
/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch/proc/escape_refusal()
	var/turf/exit = lockout_exit()
	if (!exit)
		return "Rock or wreckage presses against the outer hatch."
	if (sea_zone_of(exit) > SEA_ZONE_OPEN)
		return "The boat lies too deep for a free ascent: the sea would kill you on the way up. Wait for rescue, or go out in a suit built for this depth."
	var/turf/up = locate(exit.x, exit.y, multiz_level_above(exit.z))
	if (!sea_layer_open_surface(up) || up.iscovered())
		return "Something floats on the water above the hatch."
	return null

// The surface cell a free ascent comes up in.
/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch/proc/escape_surface()
	var/turf/exit = lockout_exit()
	return exit ? locate(exit.x, exit.y, multiz_level_above(exit.z)) : null

// The escape trunk: floods the chamber and lets a crew member without a suit
// make a free ascent to the surface.
/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch/proc/escape(mob/living/human/user)
	var/problem = escape_refusal()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	var/deep = sea_zone_of(lockout_exit()) == SEA_ZONE_OPEN
	user.visible_message(SPAN_WARNING("[user] climbs into the escape trunk and floods it."), SPAN_WARNING("You climb into the escape trunk and open the flood valve. The cold water rises past your chest[deep ? ". It is a long way up from here" : ""]..."))
	if (!do_after(user, SEABED_LOCKOUT_TIME, src))
		return FALSE
	var/obj/structure/vehicleparts/axis/ship/submarine/B = boat()
	if (QDELETED(src) || !B || !B.submerged || user.region_send_held() || escape_refusal())
		return FALSE
	var/turf/up = escape_surface()
	if (outer_dogged)
		set_dogged(FALSE)
	user.forceMove(up)
	if (deep)
		user.adjustOxyLoss(SEABED_ESCAPE_OXYLOSS_OPEN)
		user.adjustBruteLoss(SEABED_ESCAPE_BRUTE_OPEN)
		to_chat(user, SPAN_DANGER("You kick up through the dark, breathing out all the way, and break the surface gasping, ears and chest burning."))
	else
		user.adjustOxyLoss(SEABED_ESCAPE_OXYLOSS_SHELF)
		to_chat(user, SPAN_NOTICE("You kick up through the green water, breathing out all the way, and break the surface."))
	return TRUE

// Floods the chamber and lets a sealed diver out onto the seabed.
/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch/proc/lock_out(mob/living/human/user)
	if (!user.can_walk_seabed())
		to_chat(user, SPAN_WARNING("The chamber floods to the deckhead. You need a sealed diving suit: a diving dress, a diving helmet and an air bottle with air in it."))
		return FALSE
	if (!lockout_exit())
		to_chat(user, SPAN_WARNING("Rock or wreckage presses against the outer hatch."))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] climbs into the lock-out chamber and floods it."))
	if (!do_after(user, SEABED_LOCKOUT_TIME, src))
		return FALSE
	var/obj/structure/vehicleparts/axis/ship/submarine/B = boat()
	var/turf/exit = lockout_exit()
	if (QDELETED(src) || !B || !B.submerged || !exit || !user.can_walk_seabed() || user.region_send_held())
		return FALSE
	if (outer_dogged)
		set_dogged(FALSE)
	user.forceMove(exit)
	to_chat(user, SPAN_NOTICE("The outer hatch swings open and you step out onto the seabed."))
	return TRUE

// Lets a diver in from the seabed and blows the chamber dry with bank air,
// or pumps it out by hand when the bank is short.
/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch/proc/lock_in(mob/living/human/user)
	var/problem = lock_in_refusal()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	var/obj/structure/vehicleparts/axis/ship/submarine/B = boat()
	var/blow = B && B.air_bank >= SUB_AIR_LOCKIN_COST
	if (blow)
		to_chat(user, SPAN_NOTICE("You open the outer hatch and climb into the lock-out chamber..."))
	else
		to_chat(user, SPAN_WARNING("You climb into the lock-out chamber. The air bank is empty, so you work the hand pump..."))
	if (!do_after(user, blow ? SEABED_LOCKOUT_TIME : SEABED_HAND_PUMP_TIME, src))
		return FALSE
	B = boat()
	if (QDELETED(src) || !B || !B.submerged || !Adjacent(user) || user.region_send_held() || lock_in_refusal())
		return FALSE
	if (blow)
		B.blow_chamber()
	user.forceMove(get_turf(src))
	to_chat(user, SPAN_NOTICE("The chamber [blow ? "blows" : "pumps"] dry and you climb back aboard."))
	return TRUE

#undef SEA_ZONE_SHELF_MAX
#undef SEA_ZONE_OPEN_MAX
#undef SEA_ZONE_DEEP_MAX
#undef SEABED_CRUSH_WEAR
#undef SEABED_LOCKOUT_TIME
#undef SEABED_ASCENT_TIME
#undef SEABED_REFILL_TIME
#undef SEABED_HAND_PUMP_TIME
#undef SEABED_DOG_TIME
#undef SEABED_KNOCK_COOLDOWN
#undef SEABED_ESCAPE_OXYLOSS_SHELF
#undef SEABED_ESCAPE_OXYLOSS_OPEN
#undef SEABED_ESCAPE_BRUTE_OPEN
