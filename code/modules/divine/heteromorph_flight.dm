// ============================================================
// Heteromorph flight (phase 3 of the Dragonoid plan). Hidden mechanic: keep
// it out of changelog lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// A winged true form can take off and fly low over the land: walls, trees,
// water and crowds pass beneath it, and it lands only where its 2x2 body
// fits. Flight follows the world rule for aircraft: only on Gaia among the
// persistent worlds. Art: gold_fly and shadow_fly in
// icons/mob/heteromorph_dragon.dmi, drawn by Fable 5.2.
// ============================================================

#define HETEROMORPH_FLY_LIFT 20

/mob/living/simple_animal/heteromorph_form
	var/heteromorph_can_fly = FALSE
	var/tmp/heteromorph_flying = FALSE
	var/tmp/heteromorph_busy = FALSE
	var/tmp/image/heteromorph_shadow = null

/mob/living/simple_animal/heteromorph_form/dragon
	heteromorph_can_fly = TRUE

// Persistent worlds keep flight to Gaia, as for aircraft. Event maps allow it.
/proc/heteromorph_flight_allowed()
	if (!map)
		return FALSE
	if (map.persistence && map.ID != MAP_NOMADS_GAIA)
		return FALSE
	return TRUE

// Whether the 2x2 body fits on the ground with T as its south-west tile.
/proc/heteromorph_footprint_clear(turf/T, atom/movable/ignore = null)
	if (!T)
		return FALSE
	for (var/dx in 0 to 1)
		for (var/dy in 0 to 1)
			var/turf/S = locate(T.x + dx, T.y + dy, T.z)
			if (!S || S.density)
				return FALSE
			for (var/atom/movable/A in S)
				if (A != ignore && A.density && !(ignore && A.loc == ignore))
					return FALSE
	return TRUE

// Where a body coming down from the air may stand: here if open, else the
// nearest open tile within four.
/mob/living/simple_animal/heteromorph_form/proc/heteromorph_landing_turf(turf/T)
	if (!T)
		return null
	if (heteromorph_tile_open(T))
		return T
	for (var/r in 1 to 4)
		for (var/turf/S in range(r, T))
			if (get_dist(S, T) == r && heteromorph_tile_open(S))
				return S
	return T

/mob/living/simple_animal/heteromorph_form/proc/heteromorph_tile_open(turf/S)
	if (!S || S.density)
		return FALSE
	for (var/atom/movable/A in S)
		if (A != src && A.density)
			return FALSE
	return TRUE

// One step in the air: straight over whatever is below. The whole body must
// stay inside the map.
/mob/living/simple_animal/heteromorph_form/proc/heteromorph_fly_step(turf/NewLoc, Dir)
	if (heteromorph_leaving || heteromorph_busy || stat != CONSCIOUS || !isturf(NewLoc) || !isturf(loc))
		return FALSE
	if (NewLoc.z != z || NewLoc.x + 1 > world.maxx || NewLoc.y + 1 > world.maxy)
		return FALSE
	set_dir(Dir ? Dir : get_dir(loc, NewLoc))
	return forceMove(NewLoc)

/mob/living/simple_animal/heteromorph_form/movement_delay()
	. = ..()
	if (heteromorph_flying)
		. += heteromorph_balance_num(heteromorph_kind_id(), "fly_speed", -1)

/mob/living/simple_animal/heteromorph_form/proc/heteromorph_set_flying(on)
	heteromorph_flying = on
	flying = on
	density = !on
	if (heteromorph_shadow)
		underlays -= heteromorph_shadow
		heteromorph_shadow = null
	if (on)
		icon_living = "[heteromorph_colour_state()]_fly"
		icon_state = icon_living
		layer = FLY_LAYER
		heteromorph_shadow = image(icon, "shadow_fly", dir = dir)
		heteromorph_shadow.pixel_y = -HETEROMORPH_FLY_LIFT
		heteromorph_shadow.appearance_flags = RESET_COLOR | RESET_ALPHA
		underlays += heteromorph_shadow
		animate(src, pixel_y = HETEROMORPH_FLY_LIFT, time = 8)
	else
		icon_living = heteromorph_colour_state()
		icon_state = icon_living
		layer = initial(layer)
		animate(src, pixel_y = 0, time = 8)
	icon_dead = icon_living

/mob/living/simple_animal/heteromorph_form/proc/heteromorph_colour_state()
	return (heteromorph_body && heteromorph_body.heteromorph_colour) ? heteromorph_body.heteromorph_colour : initial(icon_state)

/mob/living/simple_animal/heteromorph_form/set_dir(new_dir)
	. = ..()
	if (heteromorph_shadow)
		underlays -= heteromorph_shadow
		heteromorph_shadow.dir = dir
		underlays += heteromorph_shadow

/mob/living/simple_animal/heteromorph_form/proc/heteromorph_takeoff_verb()
	set name = "Take Wing"
	set category = "IC"
	set desc = "Rise into the air, or come down to land."
	if (usr != src || heteromorph_leaving || heteromorph_busy || stat != CONSCIOUS)
		return
	var/kind = heteromorph_kind_id()
	if (heteromorph_flying)
		if (!heteromorph_footprint_clear(loc, src))
			to_chat(src, SPAN_WARNING("There is no room to land here."))
			return
		heteromorph_set_flying(FALSE)
		visible_message(SPAN_WARNING("\The [src] comes down to land with a great rush of wind."))
		heteromorph_log("[key_name(src)] landed at [x],[y],[z].")
		return
	if (!heteromorph_flight_allowed())
		to_chat(src, SPAN_WARNING("The sky here will not carry you."))
		return
	heteromorph_busy = TRUE
	visible_message(SPAN_WARNING("\The [src] spreads its wings."))
	var/ok = do_after(src, heteromorph_balance_num(kind, "takeoff_seconds", 3) * 10, src, needhand = FALSE)
	heteromorph_busy = FALSE
	if (!ok || heteromorph_leaving || QDELETED(src) || heteromorph_flying || stat != CONSCIOUS)
		return
	heteromorph_set_flying(TRUE)
	visible_message(SPAN_DANGER("\The [src] beats its wings and rises into the air!"))
	heteromorph_log("[key_name(src)] took flight at [x],[y],[z].")

#undef HETEROMORPH_FLY_LIFT
