// Using a bathtub (docs/hygiene.md).
//
// - Click an empty tub to fill it. On Persistence maps that takes a tubful
//   from its tank (bathing.dm); on barren worlds nothing comes out.
// - Click a full tub, or drag yourself onto it, to climb in and soak: 10
//   seconds, then an undressed bather is washed like under a shower (200,
//   soap 250). Dragging someone else onto it bathes them.
// - A small tub holds one bather lying down. A public tub holds one on each
//   of its four tiles.
// - Click the tub again, or press a direction, to climb out. Alt-click (or
//   Pull the Plug) empties it; the water runs into a floor drain or slops
//   onto the floor (floor_drains.dm).
// - While full it keeps anyone in it from burning and brings them toward the
//   water's temperature, without repeating the hot or cold warning.

#define TUB_SOAK_TIME 100
#define TUB_HEAT_WARN_GAP 600

/obj/structure/shower/bathtub/var/tmp/list/heat_warned = null

/obj/structure/shower/bathtub/persistence_runtime_var(key)
	return key == "heat_warned" || ..()

// ---- where the tub is -------------------------------------------------------

/obj/structure/shower/bathtub/proc/tub_turfs()
	return list(get_turf(src))

/obj/structure/shower/bathtub/big/tub_turfs()
	. = list()
	for (var/dx in 0 to 1)
		for (var/dy in 0 to 1)
			var/turf/T = locate(x + dx, y + dy, z)
			if (T)
				. += T

/obj/structure/shower/bathtub/proc/in_tub(mob/M)
	return M && (get_turf(M) in tub_turfs())

/obj/structure/shower/bathtub/proc/near_tub(mob/M)
	var/turf/MT = get_turf(M)
	if (!MT || MT.z != z)
		return FALSE
	for (var/turf/T in tub_turfs())
		if (get_dist(T, MT) <= 1)
			return TRUE
	return FALSE

// Where M would settle in the tub, or null when there is no room.
/obj/structure/shower/bathtub/proc/tub_spot_for(mob/living/M)
	if (buckled_mob && buckled_mob != M)
		return null
	return get_turf(src)

/obj/structure/shower/bathtub/big/tub_spot_for(mob/living/M)
	var/turf/MT = get_turf(M)
	var/turf/best = null
	for (var/turf/T in tub_turfs())
		if (T == MT)
			return T
		if (T.density)
			continue
		var/taken = FALSE
		for (var/mob/living/L in T)
			if (L != M)
				taken = TRUE
				break
		if (!taken && (!best || get_dist(T, MT) < get_dist(best, MT)))
			best = T
	return best

/obj/structure/shower/bathtub/proc/water_word()
	switch (watertemp)
		if ("boiling")
			return "scalding hot"
		if ("freezing")
			return "icy"
	return "warm"

// ---- clicking -----------------------------------------------------------------

/obj/structure/shower/bathtub/attack_hand(mob/living/user)
	if (!isliving(user) || user.stat || user.restrained())
		return
	if (in_tub(user))
		climb_out(user)
		return
	if (!near_tub(user))
		return
	if (!on)
		fill_tub(user)
		return
	climb_in(user, user)

/obj/structure/shower/bathtub/MouseDrop_T(atom/movable/O, mob/living/user)
	if (!isliving(O) || !istype(user))
		return ..()
	climb_in(O, user)

/obj/structure/shower/bathtub/AltClick(mob/living/user)
	if (!isliving(user) || user.stat || user.restrained() || !near_tub(user))
		return ..()
	drain_tub(user)
	return TRUE

/obj/structure/shower/bathtub/verb/pull_plug()
	set name = "Pull the Plug"
	set category = null
	set src in view(1)
	var/mob/living/user = usr
	if (!isliving(user) || user.stat || user.restrained() || !near_tub(user))
		return
	drain_tub(user)

/obj/structure/shower/bathtub/examine(mob/user, distance = -1)
	. = ..()
	if (on)
		to_chat(user, SPAN_NOTICE("It is full of [water_word()] water."))
	else
		to_chat(user, SPAN_NOTICE("It is empty."))

// ---- filling and emptying -----------------------------------------------------

/obj/structure/shower/bathtub/proc/fill_tub(mob/living/user)
	if (on)
		return TRUE
	if (barren_world())
		to_chat(user, SPAN_WARNING("Nothing comes out of \the [src]. There is no ground water here."))
		return FALSE
	if (needs_tank_water() && !station_take_water(user))
		return FALSE
	on = TRUE
	reagents.add_reagent("water", reagents.get_free_space())
	update_icon()
	playsound(loc, 'sound/effects/sink.ogg', 40, TRUE)
	user.visible_message(SPAN_NOTICE("[user] fills \the [src]."), SPAN_NOTICE("You fill \the [src] with [water_word()] water."))
	return TRUE

/obj/structure/shower/bathtub/proc/drain_tub(mob/living/user)
	if (!on)
		to_chat(user, SPAN_NOTICE("\The [src] is already empty."))
		return FALSE
	on = FALSE
	update_icon()
	playsound(loc, 'sound/effects/watersplash.ogg', 30, TRUE)
	user.visible_message(SPAN_NOTICE("[user] pulls the plug on \the [src]."), SPAN_NOTICE("You pull the plug and \the [src] drains."))
	bath_water_turned_off()
	return TRUE

// ---- getting in and out -------------------------------------------------------

/obj/structure/shower/bathtub/proc/climb_in(mob/living/M, mob/living/user)
	if (!istype(M) || !istype(user) || user.stat || user.restrained())
		return FALSE
	if (M != user && !user.Adjacent(M))
		return FALSE
	if (!near_tub(user) || !near_tub(M))
		return FALSE
	if (M == user && M.buckled && M.buckled != src)
		return FALSE
	if (!on)
		to_chat(user, SPAN_WARNING("\The [src] is empty. Click it to fill it first."))
		return FALSE
	var/turf/T = tub_spot_for(M)
	if (!T)
		to_chat(user, SPAN_WARNING("There is no room in \the [src]."))
		return FALSE
	if (get_turf(M) != T)
		if (M.buckled)
			M.buckled.unbuckle_mob()
		M.forceMove(T)
	if (can_buckle && buckled_mob != M)
		buckle_mob(M)
	if (M == user)
		M.visible_message(SPAN_NOTICE("[M] climbs into \the [src]."), SPAN_NOTICE("You climb into \the [src]."))
	else
		M.visible_message(SPAN_NOTICE("[user] puts [M] into \the [src]."), SPAN_NOTICE("[user] puts you into \the [src]."))
	playsound(loc, 'sound/effects/watersplash.ogg', 40, TRUE)
	M.ExtinguishMob()
	warn_heat(M)
	soak(M, user)
	return TRUE

/obj/structure/shower/bathtub/proc/climb_out(mob/living/M, direction = null)
	if (!istype(M) || M.stat || M.restrained())
		return FALSE
	if (buckled_mob == M)
		unbuckle_mob()
	var/turf/T = direction ? get_step(get_turf(M), direction) : null
	if (!T || (T in tub_turfs()))
		T = tub_exit_turf(M)
	M.visible_message(SPAN_NOTICE("[M] climbs out of \the [src]."), SPAN_NOTICE("You climb out of \the [src]."))
	if (T)
		M.Move(T)
	return TRUE

// A free floor tile next to the tub, nearest to the bather.
/obj/structure/shower/bathtub/proc/tub_exit_turf(mob/living/M)
	var/list/inside = tub_turfs()
	var/turf/MT = get_turf(M)
	var/turf/best = null
	for (var/turf/T in inside)
		for (var/d in cardinal)
			var/turf/N = get_step(T, d)
			if (!N || (N in inside) || N.density)
				continue
			var/blocked = FALSE
			for (var/obj/O in N)
				if (O.density)
					blocked = TRUE
					break
			if (!blocked && (!best || get_dist(N, MT) < get_dist(best, MT)))
				best = N
	return best

// ---- soaking ------------------------------------------------------------------

/obj/structure/shower/bathtub/proc/soak(mob/living/M, mob/living/user)
	if (!ishuman(M))
		return
	if (M == user)
		to_chat(M, SPAN_NOTICE("You settle into the water and start to scrub."))
	if (!do_after(user, TUB_SOAK_TIME, M, needhand = FALSE, incapacitation_flags = INCAPACITATION_DISABLED))
		return
	if (QDELETED(src) || !on || !in_tub(M))
		return
	var/mob/living/human/H = M
	wash(H)
	playsound(loc, 'sound/effects/watersplash.ogg', 40, TRUE)
	if (!H.is_nude())
		to_chat(H, SPAN_NOTICE("You soak your clothes. Undress to get clean."))
		return
	H.mark_bare_parts_washed()
	switch (watertemp)
		if ("boiling")
			to_chat(H, SPAN_WARNING("You scrub yourself clean in the scalding water."))
		if ("freezing")
			to_chat(H, SPAN_NOTICE("You scrub yourself clean in the icy water, teeth chattering."))
		else
			to_chat(H, SPAN_NOTICE("You soak in the warm water and scrub yourself clean."))

/obj/structure/shower/bathtub/proc/warn_heat(mob/living/M)
	if (!ishuman(M))
		return
	var/mob/living/human/H = M
	var/temperature = temperature_settings[watertemp]
	var/text = null
	if (temperature >= H.species.heat_level_1)
		text = "The water is searing hot!"
	else if (temperature <= H.species.cold_level_1)
		text = "The water is freezing cold!"
	if (!text)
		return
	var/key = "\ref[H]"
	if (heat_warned && world.time - heat_warned[key] < TUB_HEAT_WARN_GAP)
		return
	LAZYSET(heat_warned, key, world.time)
	to_chat(H, SPAN_DANGER(text))

// ---- while full ---------------------------------------------------------------

/obj/structure/shower/bathtub/process()
	if (!on)
		return
	if (barren_world())
		on = FALSE
		update_icon()
		return
	bath_water_running()
	reagents.add_reagent("water", reagents.get_free_space())
	for (var/turf/T in tub_turfs())
		for (var/mob/living/L in T)
			L.ExtinguishMob()
			L.fire_stacks = min(L.fire_stacks, -20)
			var/temperature = temperature_settings[watertemp]
			L.bodytemperature += between(BODYTEMP_COOLING_MAX, temperature - L.bodytemperature, BODYTEMP_HEATING_MAX)
			warn_heat(L)

// Pressing a direction while lying in a tub climbs out that way.
/obj/structure/shower/bathtub/relaymove(mob/user, direction)
	if (isliving(user) && user.buckled == src)
		return climb_out(user, direction)
	return ..()

// ---- soap ---------------------------------------------------------------------

// Whether there is running or standing wash water where someone stands: a
// shower that is on, or a full tub over that tile.
/proc/bath_water_at(turf/T)
	if (!T)
		return FALSE
	for (var/obj/structure/shower/S in T)
		if (S.on)
			return TRUE
	for (var/d in list(WEST, SOUTH, SOUTHWEST))
		var/turf/N = get_step(T, d)
		for (var/obj/structure/shower/bathtub/big/B in N)
			if (B.on && (T in B.tub_turfs()))
				return TRUE
	return FALSE

#undef TUB_SOAK_TIME
#undef TUB_HEAT_WARN_GAP
