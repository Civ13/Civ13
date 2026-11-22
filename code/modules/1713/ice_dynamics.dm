// Ice that forms and melts (docs/fishing-grounds.md, "Ice that forms and melts").
//
// On persistent maps ice is not fixed terrain. In hard frost open water
// freezes from its edges, against the shore or the ice already there, a tile
// at a time; in a thaw the ice rots and melts from its edges back. Shallow
// still water freezes first, flowing or deep water and the sea need harder
// cold. Fresh ice is thin (ice_breaking.dm) until it has frozen an hour.
//
// Salt scattered on ice softens it and breaks it up; scattered on water it
// keeps the water open, both for a couple of hours unless the cold is bitter.
// A channel boats use stays open while they keep using it. Thin ice cracks
// under carts, vehicles and anyone dragging a load or carrying something
// heavy.
//
// Cost: there is no timer on any tile. One looping timer walks the map's
// registered water turfs (water_turf_list) a batch at a time, a full sweep
// every ten minutes or so, and only tiles at the edge of the ice can change.
// The air temperature is taken once per area per sweep. Tiles changed in a
// sweep do not count as the edge again until the next sweep, so ice moves at
// most a tile per sweep.

#define ICE_FRONT_STEP (5 SECONDS)
#define ICE_FRONT_BATCH 750    // water tiles looked at per step
#define ICE_FRONT_TICK_LIMIT 20 // stop a step early above this world.tick_usage
#define ICE_CHANNEL_MINUTES 30 // real minutes a boat's passing keeps the water open
#define ICE_SALT_UNITS 5       // salt a handful takes
#define ICE_SALT_TIME 20

// Ice that froze over deep water, so it melts deep again.
/turf/floor/beach/water/ice/deep
/turf/floor/beach/water/ice/salty/deep

/proc/ice_type_for(salty, shallow)
	if (salty)
		return shallow ? /turf/floor/beach/water/ice/salty : /turf/floor/beach/water/ice/salty/deep
	return shallow ? /turf/floor/beach/water/ice : /turf/floor/beach/water/ice/deep

// TRUE where the weather moves the ice: persistent maps, except the Ice Age
// map, whose sea freezes and thaws with its own seasons (durable_nomads.dm).
/proc/ice_dynamics_on()
	return map && map.persistence && !istype(map, /obj/map_metadata/nomads/ice_age)

// ---- Shared state, all filled lazily ----

var/global/list/ice_area_temps     // area = air temperature, taken once a sweep
var/global/list/ice_front_changed  // turf = TRUE for tiles a sweep has changed
var/global/list/ice_kept_open      // turf = real minute until which boats keep it open
var/global/ice_front_cursor = 1
var/global/ice_front_timer = 0
var/global/ice_front_sweeps = 0

// The air over T, once per area per sweep.
/proc/ice_area_temp(turf/T)
	var/area/A = T ? T.loc : null
	if (!A)
		return 20
	if (ice_area_temps)
		var/cached = ice_area_temps[A]
		if (!isnull(cached))
			return cached
	var/temp = get_temp(T)
	if (!ice_area_temps)
		ice_area_temps = list()
	ice_area_temps[A] = temp
	return temp

// A boat on or heading onto T keeps it open for a while.
/proc/ice_keep_open(turf/T)
	if (!T || !ice_dynamics_on())
		return
	if (!ice_kept_open)
		ice_kept_open = list()
	ice_kept_open[T] = trap_now_minutes() + ICE_CHANNEL_MINUTES

/proc/ice_is_kept_open(turf/T, now = trap_now_minutes())
	return ice_kept_open && ice_kept_open[T] > now

// ---- The front ----

/proc/ice_front_start()
	if (ice_front_timer || !ice_dynamics_on())
		return FALSE
	ice_front_timer = addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(ice_front_step)), ICE_FRONT_STEP, TIMER_LOOP | TIMER_STOPPABLE)
	return TRUE

/hook/roundstart/proc/ice_front_begin()
	ice_front_start()
	return TRUE

// One step of the sweep. Returns how many tiles it looked at.
/proc/ice_front_step(budget = ICE_FRONT_BATCH)
	. = 0
	if (!ice_dynamics_on() || persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return
	var/now = trap_now_minutes()
	while (budget-- > 0 && water_turf_list.len)
		if (ice_front_cursor > water_turf_list.len)
			ice_front_wrap(now)
		var/turf/floor/beach/water/T = water_turf_list[ice_front_cursor++]
		if (T)
			ice_front_look(T, now)
		.++
		if (world.tick_usage >= ICE_FRONT_TICK_LIMIT)
			break

// The end of a sweep: forget the weather and the changes, drop stale channels.
/proc/ice_front_wrap(now = trap_now_minutes())
	ice_front_cursor = 1
	ice_front_sweeps++
	ice_area_temps = null
	ice_front_changed = null
	if (ice_kept_open)
		for (var/turf/T in ice_kept_open.Copy())
			if (ice_kept_open[T] <= now)
				ice_kept_open -= T
		if (!ice_kept_open.len)
			ice_kept_open = null

// The coldest air in which still water of T's kind stays open, or null for
// water that never freezes here (swamps, floods, coasts drawn as surf).
/proc/ice_freeze_threshold(turf/T)
	switch (T.type)
		if (/turf/floor/beach/water)
			return ICE_FREEZE_TEMP
		if (/turf/floor/beach/water/shallowsaltwater)
			return -6
		if (/turf/floor/beach/water/deep)
			return -8
		if (/turf/floor/beach/water/deep/saltwater)
			return -15
	return null

// A current keeps water open in colder air.
#define ICE_CURRENT_EXTRA -4

/proc/ice_front_changed_here(turf/T)
	return ice_front_changed && ice_front_changed[T]

/proc/ice_front_note(turf/T)
	if (!ice_front_changed)
		ice_front_changed = list()
	ice_front_changed[T] = TRUE

// What a tile of the front does this sweep.
/proc/ice_front_look(turf/floor/beach/water/T, now = trap_now_minutes())
	if (ice_front_changed_here(T))
		return
	var/temp = ice_area_temp(T)
	if (istype(T, /turf/floor/beach/water/ice))
		if (temp <= ICE_MELT_TEMP || (locate(/obj/structure/broken_ice) in T))
			return
		var/edges = ice_front_melt_edges(T)
		if (edges && prob(min(80, 15 + 10 * edges + 5 * (temp - ICE_MELT_TEMP))))
			ice_front_melt(T)
		return
	if (temp > ICE_FREEZE_TEMP)
		return
	var/threshold = ice_freeze_threshold(T)
	if (isnull(threshold) || temp > threshold)
		return
	// Cheapest first: most open water has no shore or ice beside it.
	var/edges = ice_front_freeze_edges(T)
	if (!edges || !prob(min(85, 20 + 20 * edges)))
		return
	if (temp > threshold + ICE_CURRENT_EXTRA && river_current_direction(T))
		return
	if ((locate(/obj/structure/broken_ice) in T) || ice_is_kept_open(T, now) || !ice_water_still(T))
		return
	ice_front_freeze(T)

// Nothing floats or stands in the water, and nothing is built over it.
/proc/ice_water_still(turf/T)
	if (T.iscovered())
		return FALSE
	for (var/atom/movable/M in T)
		if (ismob(M) || istype(M, /obj/structure/vehicle) || istype(M, /obj/structure/vehicleparts))
			return FALSE
	return TRUE

// Shore and old ice beside open water: what it freezes from.
/proc/ice_front_freeze_edges(turf/T)
	. = 0
	for (var/dir in cardinal)
		var/turf/N = get_step(T, dir)
		if (!N || ice_front_changed_here(N))
			continue
		if (istype(N, /turf/floor/beach/water/ice) || !istype(N, /turf/floor/beach/water))
			.++

// Open water and shore beside ice: what it melts from.
/proc/ice_front_melt_edges(turf/T)
	. = 0
	for (var/dir in cardinal)
		var/turf/N = get_step(T, dir)
		if (!N || ice_front_changed_here(N))
			continue
		if (!istype(N, /turf/floor/beach/water/ice))
			.++

/proc/ice_front_freeze(turf/floor/beach/water/T)
	var/salty = T.salty || istype(T, /turf/floor/beach/water/shallowsaltwater) || istype(T, /turf/floor/beach/water/deep/saltwater)
	var/shallow = !istype(T, /turf/floor/beach/water/deep)
	var/turf/I = T.ChangeTurf(ice_type_for(salty, shallow))
	if (!I)
		return null
	ice_front_note(I)
	var/obj/structure/broken_ice/M = new(I)
	M.salty = salty
	M.shallow = shallow
	M.thin = TRUE
	I.name = "thin ice"
	return I

/proc/ice_front_melt(turf/floor/beach/water/ice/T)
	var/water_type = ice_open_water_type(T)
	for (var/obj/structure/ice_hole/hole in T)
		qdel(hole)
	var/turf/W = T.ChangeTurf(water_type)
	if (W)
		ice_front_note(W)
	return W

// ---- Salt ----

/proc/ice_salt_ok(obj/item/I)
	if (!istype(I, /obj/item/weapon/reagent_containers/food/condiment) || !I.reagents)
		return FALSE
	return I.reagents.get_reagent_amount("sodiumchloride") >= ICE_SALT_UNITS

// H scatters a handful of salt from C over the ice or water at T.
/proc/ice_salt(turf/floor/beach/water/T, obj/item/weapon/reagent_containers/C, mob/living/human/H)
	if (!ishuman(H) || !istype(T) || !ice_salt_ok(C))
		return null
	var/iced = istype(T, /turf/floor/beach/water/ice)
	if (!iced && !is_liquid_water(T))
		return null
	if (!do_after(H, ICE_SALT_TIME, T) || QDELETED(C) || C.loc != H || !ice_salt_ok(C))
		return null
	if (iced != istype(T, /turf/floor/beach/water/ice))
		return null
	C.reagents.remove_reagent("sodiumchloride", ICE_SALT_UNITS)
	var/obj/structure/broken_ice/M = locate() in T
	if (!M)
		M = new(T)
		if (iced)
			var/water_type = ice_open_water_type(T)
			M.salty = istype(T, /turf/floor/beach/water/ice/salty)
			M.shallow = !ispath(water_type, /turf/floor/beach/water/deep)
		else
			M.salty = T.salty || istype(T, /turf/floor/beach/water/shallowsaltwater) || istype(T, /turf/floor/beach/water/deep/saltwater)
			M.shallow = !istype(T, /turf/floor/beach/water/deep)
	M.salted_until = trap_now_minutes() + ICE_SALT_MINUTES
	if (iced)
		H.visible_message(SPAN_NOTICE("[H] scatters salt over the ice."), SPAN_NOTICE("You scatter salt over the ice. It will soften and break up unless the cold is bitter."))
	else
		H.visible_message(SPAN_NOTICE("[H] scatters salt on the water."), SPAN_NOTICE("You scatter salt on the water. It will not freeze here for a couple of hours unless the cold is bitter."))
	return M

// ---- Cracking under a load ----

// TRUE when A is heavy enough to go through thin ice.
/proc/ice_load_cracks(atom/movable/A)
	if (istype(A, /obj/structure/vehicle))
		return TRUE
	if (istype(A, /obj/structure))
		return !A.anchored && A.density // carts, crates and the like dragged on
	var/mob/living/human/H = A
	if (!istype(H))
		var/mob/living/simple_animal/animal = A
		return istype(animal) && animal.rider // a ridden animal (riding.dm)
	if (H.pulling && (ismob(H.pulling) || H.pulling.density))
		return TRUE
	for (var/obj/item/I in list(H.l_hand, H.r_hand, H.back))
		if (I.heavy)
			return TRUE
	return FALSE

// Thin ice without asking the weather per step: salted or newly frozen, or
// rotting by the sweep's reading of the air.
/proc/ice_thin_underfoot(turf/T)
	var/obj/structure/broken_ice/B = locate() in T
	if (B && (B.thin || B.salted()))
		return TRUE
	return ice_dynamics_on() && ice_area_temp(T) > ICE_MELT_TEMP

/turf/floor/beach/water/ice/Entered(atom/movable/A, atom/old_loc)
	. = ..()
	if (!ice_load_cracks(A) || !ice_thin_underfoot(src))
		return
	var/turf/floor/beach/water/W = ice_break_turf(src)
	if (!W)
		return
	W.visible_message(SPAN_DANGER("The thin ice cracks and gives way under \the [A]!"))
	if (istype(W, /turf/floor/beach/water/deep))
		W.check_sinking(A)

#undef ICE_FRONT_STEP
#undef ICE_FRONT_BATCH
#undef ICE_FRONT_TICK_LIMIT
#undef ICE_CHANNEL_MINUTES
#undef ICE_SALT_UNITS
#undef ICE_SALT_TIME
#undef ICE_CURRENT_EXTRA
