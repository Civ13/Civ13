// Shooting down from an upper storey. Someone seen below through open air is
// clicked as the open-air cell over them (open_air_view.dm), so a shot aimed
// at that cell flies across the upper floor as usual and, on reaching it,
// drops to whoever stands below. Firing down is steadier than firing level:
// the range counts as three quarters of the flat distance. Nobody below can
// aim up through a floor, so an upper storey is the better place to hold.

#define STOREY_FIRE_RANGE_SHARE 0.75

/obj/item/projectile/handleTurf(var/turf/T, forced = 0, var/list/untouchable = list())
	if (!forced && storey_drop_shot(T))
		return FALSE
	return ..()

// TRUE when this shot was aimed at open air T and has dropped through it.
/obj/item/projectile/proc/storey_drop_shot(turf/T)
	if (lobbed || !T || T == starting || !original || get_turf(original) != T || !building_open_turf(T))
		return FALSE
	if (castle_trapdoor_holds(T, src) || trapdoor_shut_at(T) || (locate(/obj/covers) in T))
		return FALSE
	var/below_z = multiz_level_below(T.z)
	var/turf/below = below_z ? locate(T.x, T.y, below_z) : null
	if (!below || below.density)
		return FALSE
	permutated += T
	var/flat = starting ? get_dist(starting, T) : 0
	var/aim = round(flat * STOREY_FIRE_RANGE_SHARE)
	forceMove(below)
	for (var/mob/living/L in below)
		if (L == firer || L.stat == DEAD || isobserver(L))
			continue
		L.pre_bullet_act(src)
		if (attack_mob(L, aim))
			bumped = TRUE
			on_impact(L, FALSE)
			if (!QDELETED(src))
				qdel(src)
			return TRUE
	on_impact(below)
	if (!QDELETED(src))
		qdel(src)
	return TRUE

#undef STOREY_FIRE_RANGE_SHARE
