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

#define SEA_ZONE_SHELF 1
#define SEA_ZONE_OPEN 2
#define SEA_ZONE_DEEP 3
#define SEA_ZONE_ABYSS 4
// The farthest distance from rock, in tiles, of each zone shallower than the abyss.
#define SEA_ZONE_SHELF_MAX 6
#define SEA_ZONE_OPEN_MAX 16
#define SEA_ZONE_DEEP_MAX 32
// Suit integrity lost per life tick for each zone deeper than its rating.
#define SEABED_CRUSH_WEAR 4
#define SEABED_LOCKOUT_TIME (5 SECONDS)
#define SEABED_ASCENT_TIME (15 SECONDS)
#define SEABED_REFILL_TIME (3 SECONDS)

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

/turf/floor/beach/water/deep/saltwater/underwater/sea_layer/outside_air_breathable()
	return iscovered()

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
	return seabed_diving_rating() > 0

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
	brightness_on = 4

/obj/item/pressure_tank/diving
	name = "diving air bottle"
	desc = "Compressed air for a diving helmet. Wear it on your back. Refill it at a submarine's ballast station, a habitat module's core or a landed lander."

// The boat's compressor tops bottles up at the ballast station.
/obj/structure/vehicleparts/sub_station/attackby(obj/item/W, mob/user)
	if (!istype(W, /obj/item/pressure_tank))
		return ..()
	var/obj/item/pressure_tank/A = W
	if (!boat())
		to_chat(user, SPAN_WARNING("The station is not fitted to a submarine."))
		return
	var/full = initial(A.air_seconds)
	if (A.air_seconds >= full)
		to_chat(user, SPAN_NOTICE("\The [A] is already full."))
		return
	to_chat(user, SPAN_NOTICE("You couple \the [A] to the boat's compressor..."))
	if (!do_after(user, SEABED_REFILL_TIME, src) || QDELETED(A))
		return
	A.air_seconds = full
	to_chat(user, SPAN_NOTICE("\The [A] is full."))

// ---- The lock-out hatch ----

/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch
	desc = "A riveted steel pressure hull section with a side hatch. Submerged, it works as a lock-out chamber: a diver sealed in a diving suit uses it to flood out to the seabed and to pump back in."

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
	if (!Adjacent(user))
		return
	var/turf/here = get_turf(user)
	if (here && here.iscovered())
		lock_out(user)
	else
		lock_in(user)

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
	if (QDELETED(src) || !B || !B.submerged || !exit || !user.can_walk_seabed())
		return FALSE
	user.forceMove(exit)
	to_chat(user, SPAN_NOTICE("The outer hatch swings open and you step out onto the seabed."))
	return TRUE

// Lets a diver in from the seabed and pumps the chamber dry.
/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch/proc/lock_in(mob/living/human/user)
	to_chat(user, SPAN_NOTICE("You open the outer hatch and climb into the lock-out chamber..."))
	if (!do_after(user, SEABED_LOCKOUT_TIME, src))
		return FALSE
	var/obj/structure/vehicleparts/axis/ship/submarine/B = boat()
	if (QDELETED(src) || !B || !B.submerged || !Adjacent(user))
		return FALSE
	user.forceMove(get_turf(src))
	to_chat(user, SPAN_NOTICE("The chamber pumps dry and you climb back aboard."))
	return TRUE

#undef SEA_ZONE_SHELF_MAX
#undef SEA_ZONE_OPEN_MAX
#undef SEA_ZONE_DEEP_MAX
#undef SEABED_CRUSH_WEAR
#undef SEABED_LOCKOUT_TIME
#undef SEABED_ASCENT_TIME
#undef SEABED_REFILL_TIME
