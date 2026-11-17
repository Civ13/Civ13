// Upper storeys as stores: a loft under a roof is dry and airy, so a
// dehydrator there dries food half again as fast. Mice never nest above the
// ground floor (mouse_nests.dm), and floods only reach the ground and the
// cellar (flood_effects.dm), so grain kept upstairs stays safe.

#define LOFT_DRY_STEP 225 // a dehydrator's pass is 150 on the ground

// A roofed room on a storey above the ground.
/proc/turf_in_loft(atom/A)
	var/turf/T = get_turf(A)
	if (!T || !turf_is_above_ground(T))
		return FALSE
	var/area/AR = get_area(T)
	return AR && AR.location == AREA_INSIDE

/obj/structure/dehydrator/dry_step()
	return turf_in_loft(src) ? LOFT_DRY_STEP : ..()

/obj/structure/dehydrator/examine(mob/user, distance = -1)
	..()
	if (get_dist(user, src) <= 2 && turf_in_loft(src))
		to_chat(user, SPAN_NOTICE("Up here under the roof the air is dry, and things dry faster."))

#undef LOFT_DRY_STEP
