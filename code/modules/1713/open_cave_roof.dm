// ============================================================
// Opening dug-out rock to the sky (docs/open-cave-roof.md)
// ------------------------------------------------------------
// Mountain rock on the surface lies in a cave area, so a mined tile used to
// stay roofed for good: no weather, no sun, no outdoor crops, and pillars to
// hold up the rest. A pickaxe on a mined tile that touches open sky clears the
// rock overhead, and the tile joins that neighbour's outdoor area. The roof is
// cleared from an open edge inward, one tile at a time. The per-cell area
// membership is saved with the level, so the opening survives a restart.
// ============================================================

#define OPEN_CAVE_ROOF_TIME 120 // deciseconds, before strength and pickaxe speed

/turf/var/tmp/open_cave_roof_busy = FALSE

// The outdoor area an orthogonal neighbour offers, or null.
/turf/proc/open_cave_roof_sky_area()
	for (var/d in cardinal)
		var/turf/N = get_step(src, d)
		if (!N)
			continue
		var/area/caribbean/A = get_area(N)
		if (istype(A) && A.location == AREA_OUTSIDE && !A.is_void_area)
			return A
	return null

// Why this tile's rock cover cannot be opened, or null when it can.
// Only a mined, open tile still inside a cave area on ground that has open
// air (or nothing) above it qualifies.
/turf/proc/open_cave_roof_refusal(mob/user)
	if (!istype(src, /turf/floor) || density || istype(src, /turf/floor/dirt/underground) || istype(src, /turf/floor/mining))
		return "Mine the rock out first."
	if (!istype(get_area(src), /area/caribbean/void/caves))
		return "There is no rock overhead here."
	var/dug = dug_underground_z()
	if (dug && z == dug)
		return "There is solid ground above you here."
	var/up = multiz_level_above(z)
	if (up)
		var/turf/above = locate(x, y, up)
		if (above && (!building_open_turf(above) || (locate(/obj/covers) in above) || (locate(/obj/roof) in above)))
			return "There is solid ground above you here."
	for (var/obj/structure/S in src)
		if (!istype(S, /obj/structure/mine_support))
			return "Clear \the [S] away from under the rock first."
	if (locate(/obj/covers) in src)
		return "Clear the floor away from under the rock first."
	for (var/mob/living/L in src)
		if (L != user)
			return "Someone is standing under the rock there."
	if (!open_cave_roof_sky_area())
		return "Clear the rock overhead from an edge already open to the sky."
	return null

// Pickaxe on a mined cave tile. Returns TRUE when it handled the click.
/turf/proc/open_cave_roof_attempt(mob/living/human/user, obj/item/weapon/material/pickaxe/P)
	if (!istype(user) || !istype(P) || !istype(get_area(src), /area/caribbean/void/caves))
		return FALSE
	if (!istype(src, /turf/floor) || density || istype(src, /turf/floor/dirt/underground) || istype(src, /turf/floor/mining))
		return FALSE
	var/refusal = open_cave_roof_refusal(user)
	if (refusal)
		to_chat(user, SPAN_WARNING(refusal))
		return TRUE
	if (open_cave_roof_busy)
		to_chat(user, SPAN_WARNING("Someone is already breaking away the rock overhead here."))
		return TRUE
	open_cave_roof_busy = TRUE
	user.visible_message(SPAN_NOTICE("[user] starts to break away the rock overhead with \the [P]."), SPAN_NOTICE("You start to break away the rock overhead with \the [P]. Once it is open to the sky, the rock cover will not grow back."))
	playsound(src, 'sound/effects/pickaxe.ogg', 100, 1)
	var/done = do_after(user, work_delay_per_speed(user, OPEN_CAVE_ROOF_TIME, WORK_MINE, P), src)
	open_cave_roof_busy = FALSE
	if (!done)
		return TRUE
	// Anything may have changed during the wait: ask again.
	refusal = open_cave_roof_refusal(user)
	if (refusal)
		to_chat(user, SPAN_WARNING(refusal))
		return TRUE
	open_cave_roof(open_cave_roof_sky_area())
	playsound(src, 'sound/effects/rocksfalling.ogg', 60, 0, 2)
	user.visible_message(SPAN_NOTICE("[user] breaks the rock overhead away, opening the ground to the sky."), SPAN_NOTICE("You break the rock overhead away. This spot is open to the sky now."))
	return TRUE

// Moves the tile into an outdoor area. ChangeArea handles lighting and
// occupant notifications; the weather mask is drawn per area.
/turf/proc/open_cave_roof(area/sky)
	if (!istype(sky))
		return FALSE
	ChangeArea(src, sky)
	return get_area(src) == sky

#undef OPEN_CAVE_ROOF_TIME
