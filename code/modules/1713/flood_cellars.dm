// Cellars, mines and seepage (docs/river-flood.md, "Cellars"). The level
// under the flood level is dug ground. When a river rises close under the
// surface above, groundwater seeps into the open tiles below it; where the
// surface above is under floodwater and a way down opens there, the flood
// pours down too. Bailing with a bucket keeps the tiles around you dry for a
// while; pumps (cellar_pumps) keep a cellar dry while they work.
//
// Like the flood itself, depth is worked out only when asked. Nothing ticks.

// Levels under the bank at which a rising river starts to seep into the
// ground below it, and how deep seepage can stand.
#define SEEP_REACH 2
#define SEEP_MAX 0.45
// Floodwater pouring down a way down stands at most this deep below.
#define POUR_MAX 1
#define BAIL_DRY_TIME 6000
#define CELLAR_Z_RECHECK 600

// Pumps that keep the cellar tiles within cellar_reach of them dry while
// cellar_pumping() is TRUE.
var/global/list/cellar_pumps = list()

/obj/structure/var/cellar_reach = 0

/obj/structure/proc/cellar_pumping()
	return FALSE

/datum/river_flood
	var/tmp/cellar_z_cache = 0
	var/tmp/cellar_z_checked = -CELLAR_Z_RECHECK
	// turf -> world.time until which bailing keeps it dry. Unsaved.
	var/list/cellar_dry = list()

// The dug level under the flood level, or 0.
/datum/river_flood/proc/cellar_z()
	if (world.time - cellar_z_checked >= CELLAR_Z_RECHECK)
		cellar_z_checked = world.time
		cellar_z_cache = z_level ? multiz_level_below(z_level) : 0
	return cellar_z_cache

// TRUE when a way down from surface tile S lets floodwater pour below.
/proc/flood_way_down(turf/S)
	// Open air (multiz/open_space.dm), a ladder, stairs or a tunnel mouth.
	if (istype(S, /turf/floor/broken_floor))
		return TRUE
	return locate(/obj/structure/multiz) in S

// Depth of water on cellar tile T. ignore_pumps: as if nothing kept it dry.
/datum/river_flood/proc/seep_depth_at(turf/T, ignore_pumps = FALSE)
	if (T.density || T.x < 1 || T.x > maxx || T.y < 1 || T.y > maxy)
		return 0
	var/r = reach_at(T.x, T.y)
	if (!r || stage[r] <= 0)
		return 0
	var/turf/S = locate(T.x, T.y, z_level)
	if (!S)
		return 0
	var/bank = effective_threshold(S)
	// Under the river, the lake or the sea: that is not a cellar.
	if (isnull(bank))
		return 0
	. = 0
	var/gap = stage[r] - (bank - SEEP_REACH)
	if (gap > 0)
		. = min(SEEP_MAX, gap * 0.25)
	if (stage[r] > bank && flood_way_down(S))
		. = max(., min(POUR_MAX, flood_depth_at(S)))
	if (. > 0 && !ignore_pumps && cellar_kept_dry(T))
		return 0

// Bailed lately, or near a working cellar pump.
/datum/river_flood/proc/cellar_kept_dry(turf/T)
	if (cellar_dry.len)
		var/until = cellar_dry[T]
		if (until && until > world.time)
			return TRUE
	for (var/obj/structure/P in cellar_pumps)
		if (P.z == T.z && get_dist(P, T) <= P.cellar_reach && P.cellar_pumping())
			return TRUE
	return FALSE

// Bailing at T keeps it and the tiles around it dry for a while.
/datum/river_flood/proc/bail_cellar(turf/T)
	if (cellar_dry.len > 200)
		for (var/turf/K in cellar_dry.Copy())
			if (cellar_dry[K] <= world.time)
				cellar_dry -= K
	for (var/turf/N in range(1, T))
		cellar_dry[N] = world.time + BAIL_DRY_TIME
	flood_draw_revision++

// Bail out seepage with an open container.
/obj/item/weapon/reagent_containers/glass/proc/try_bail(turf/T, mob/user)
	if (!istype(T) || !is_open_container() || istype(src, /obj/item/weapon/reagent_containers/glass/fire_extinguisher) || user.a_intent == I_HARM)
		return FALSE
	var/datum/river_flood/F = map ? map.river_flood() : null
	if (!F || T.z != F.cellar_z() || F.seep_depth_at(T) <= 0)
		return FALSE
	if (reagents.total_volume >= reagents.maximum_volume)
		to_chat(user, SPAN_WARNING("\The [src] is full. Empty it outside first."))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts bailing water with \the [src]."), SPAN_NOTICE("You start bailing out the water."))
	if (!do_after(user, 20, T))
		return TRUE
	reagents.add_reagent("water", min(amount_per_transfer_from_this, reagents.maximum_volume - reagents.total_volume))
	F.bail_cellar(T)
	playsound(user, 'sound/effects/watersplash.ogg', 60, TRUE)
	user.visible_message(SPAN_NOTICE("[user] bails out the water."), SPAN_NOTICE("You bail the water out around you. It will seep back while the river stays high."))
	return TRUE

#undef SEEP_REACH
#undef SEEP_MAX
#undef POUR_MAX
#undef BAIL_DRY_TIME
#undef CELLAR_Z_RECHECK
