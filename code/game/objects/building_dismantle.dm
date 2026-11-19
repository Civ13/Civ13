// ---- taking down walls and supports that hold nothing up ----------------------
//
// A built wall, pillar or buttress comes down with a hammer (not on harm intent,
// which strikes it instead) as long as nothing rests on it. Before the work
// starts and again when it ends, building_load_held() lifts the part out of the
// world for a moment and counts the roofs, beside it and on every storey above,
// that stand now and would not stand without it. A part that holds anything up
// is refused with that count, so load-bearing walls and pillars stay put until
// another support is put up. A wall gives back what any wall does when it comes
// down (covers.dm drop_dismantle_refund), never more than it cost.

// How long a wall takes to come down, by material, before strength.
#define WALL_DISMANTLE_WOOD 60
#define WALL_DISMANTLE_STONE 120
#define WALL_DISMANTLE_METAL 160

// How many standing roofs would lose their support without S. Roofs within
// radius of center on S's own level are checked, and on each storey above the
// search widens, since an upper slab can rest on a pillar that rests on a slab
// that S holds.
/proc/building_load_held(atom/movable/S, turf/center = null, radius = 3)
	. = 0
	var/turf/T = get_turf(S)
	if (!T)
		return
	if (!center)
		center = T
	var/list/standing = list()
	for (var/obj/roof/R in range(radius, center))
		if (!QDELETED(R) && R.is_supported())
			standing += R
	var/z = building_upper_z(center.z)
	var/levels = 0
	while (z && levels++ < 32)
		var/turf/U = locate(center.x, center.y, z)
		if (!U)
			break
		for (var/obj/roof/R in range(min(radius * (levels + 1), radius * 3), U))
			if (!QDELETED(R) && R.is_supported())
				standing |= R
		z = building_upper_z(z)
	if (!standing.len)
		return
	S.loc = null
	try
		for (var/obj/roof/R in standing)
			if (!R.is_supported())
				.++
	catch (var/exception/E)
		S.loc = T
		throw E
	S.loc = T

// The refusal shown for a part that holds held roofs up.
/proc/building_load_refusal(atom/A, held, what = "another support or a wall")
	return "\The [A] is holding up the roof: [held == 1 ? "a stretch of roof" : "[held] stretches of roof"] would fall without it. Put up [what] nearby first."

// ---- walls --------------------------------------------------------------------

/obj/covers/proc/wall_dismantle_tool(obj/item/W, mob/user)
	if (!wall || incomplete || !user || user.a_intent == I_HARM || !is_tool(W, TOOL_HAMMER))
		return FALSE
	// Map-only hull plating and windscreens cannot be broken at all; hull
	// walls of a commissioned ship and storey slabs come up their own ways.
	if (initial(health) >= 10000 || afloat || building_slab_face())
		return FALSE
	return TRUE

/obj/covers/proc/wall_dismantle_time(mob/user)
	. = WALL_DISMANTLE_WOOD
	switch (lowertext(material))
		if ("stone", "clay", "concrete")
			. = WALL_DISMANTLE_STONE
		if ("steel", "iron", "metal")
			. = WALL_DISMANTLE_METAL
	if (ishuman(user))
		var/mob/living/human/H = user
		. /= H.getStatCoeff("strength")

/obj/covers/proc/wall_dismantle_check(mob/user)
	var/held = building_load_held(src)
	if (!held)
		return TRUE
	to_chat(user, SPAN_WARNING(building_load_refusal(src, held, "a pillar or another wall")))
	return FALSE

/obj/covers/proc/wall_dismantle(obj/item/W, mob/user)
	if (!wall_dismantle_check(user))
		return FALSE
	playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
	user.visible_message(SPAN_NOTICE("[user] starts taking \the [src] down."), SPAN_NOTICE("You start taking \the [src] down. Nothing rests on it."))
	if (!do_after(user, wall_dismantle_time(user), src) || QDELETED(src) || QDELETED(W) || W.loc != user || !wall_dismantle_check(user))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] takes \the [src] down."), SPAN_NOTICE("You take \the [src] down."))
	log_game("[user.name] ([user.ckey]) took down [name] at ([x],[y],[z])")
	qdel(src)
	return TRUE

// ---- buttresses and corbels ---------------------------------------------------

// A brace comes down like any built structure (structures.dm), but not while
// a roof stands only because it braces its wall.
/obj/structure/building_brace/proc/brace_dismantle_check(mob/user)
	var/atom/W = building_brace_wall()
	if (!W)
		return TRUE
	var/held = building_load_held(src, get_turf(W), 4)
	if (!held)
		return TRUE
	to_chat(user, SPAN_WARNING(building_load_refusal(src, held, "a pillar or another wall")))
	return FALSE

#undef WALL_DISMANTLE_WOOD
#undef WALL_DISMANTLE_STONE
#undef WALL_DISMANTLE_METAL
