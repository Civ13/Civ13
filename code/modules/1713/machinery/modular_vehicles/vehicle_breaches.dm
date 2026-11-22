// ============================================================
// Breaches and breakable glass (docs/vessel-entries.md, phase 2)
// ------------------------------------------------------------
// A vehicle wall shot or blown down to nothing is a hole: people climb in and
// out through it until someone welds it shut again (breach_wall(), called by
// try_destroy() in frame.dm). A door that is wrecked still swings open, as
// before. Submarine hulls keep their own leak rules and never open this way.
//
// Glass (windows, windshields, glazed doors) can be smashed out with anything
// heavy enough. From inside it takes a moment, because every bus and car
// window is an emergency exit; from outside it takes longer. Smashed glass is
// a breach like any other.
//
// Welding a breach shut: stand by it with steel in one hand and a welding
// tool in the other and use the steel on the frame. It takes
// VEHICLE_BREACH_STEEL sheets and VEHICLE_BREACH_TIME, and gives the wall back
// what it was before it broke, at VEHICLE_BREACH_MENDED health.
// ============================================================

#define VEHICLE_BREACH_STEEL 2
#define VEHICLE_BREACH_TIME (8 SECONDS)
#define VEHICLE_BREACH_MENDED 20
#define VEHICLE_GLASS_FORCE 5
#define VEHICLE_GLASS_INSIDE_TIME (1.5 SECONDS)
#define VEHICLE_GLASS_OUTSIDE_TIME (5 SECONDS)

// side ("front", "back", "left", "right") = the wall as it was before it broke.
/obj/structure/vehicleparts/frame/var/list/breached_walls = null

// FALSE for frames whose wrecked walls stay shut (submarine pressure hulls).
/obj/structure/vehicleparts/frame/proc/breach_passable()
	return TRUE

/obj/structure/vehicleparts/frame/ship/steel/submarine/breach_passable()
	return FALSE

// What a wall becomes once its health is gone: a wrecked door hangs open, a
// wrecked wall is a hole (or stays shut on a pressure hull).
/obj/structure/vehicleparts/frame/proc/breach_wall(side, list/wall)
	var/door = wall[6] || findtext(wall[1], "door")
	var/opens = door || breach_passable()
	if (opens && !door && wall[1] != "")
		LAZYINITLIST(breached_walls)
		if (!breached_walls[side])
			breached_walls[side] = wall.Copy()
	return list(wall[1], FALSE, FALSE, 0, 0, FALSE, opens)

/obj/structure/vehicleparts/frame/proc/wall_list(side)
	switch (side)
		if ("front")
			return w_front
		if ("back")
			return w_back
		if ("left")
			return w_left
		if ("right")
			return w_right
	return null

/obj/structure/vehicleparts/frame/proc/set_wall_list(side, list/wall)
	switch (side)
		if ("front")
			w_front = wall
		if ("back")
			w_back = wall
		if ("left")
			w_left = wall
		if ("right")
			w_right = wall

// The side of this frame a mover leaving it toward world direction d passes
// (the same table as CheckExit).
/obj/structure/vehicleparts/frame/proc/side_toward(d)
	var/list/order = list("front", "right", "back", "left")
	var/list/headings = list(NORTH, EAST, SOUTH, WEST)
	var/facing = headings.Find(dir)
	var/going = headings.Find(d)
	if (!facing || !going)
		return null
	return order[((going - facing + 4) % 4) + 1]

// TRUE for a wall of glass that can be smashed out.
/proc/vehicle_wall_glass(list/wall)
	if (!wall || wall[1] == "" || wall[5] <= 0 || wall[7])
		return FALSE
	var/name = wall[1]
	if (findtext(name, "armored") || findtext(name, "sub_"))
		return FALSE
	return findtext(name, "window") || findtext(name, "windshield") || findtext(name, "glass")

/obj/structure/vehicleparts/frame/proc/glass_sides()
	. = list()
	for (var/side in list("front", "back", "left", "right"))
		if (vehicle_wall_glass(wall_list(side)))
			. += side

// The sides of this frame that are holes, mended or not yet.
/obj/structure/vehicleparts/frame/proc/breach_sides()
	. = list()
	for (var/side in breached_walls)
		var/list/wall = wall_list(side)
		if (wall && wall[5] <= 0)
			. += side

// Smashes the glass on side out of its frame.
/obj/structure/vehicleparts/frame/proc/smash_glass(side)
	var/list/wall = wall_list(side)
	if (!vehicle_wall_glass(wall))
		return FALSE
	set_wall_list(side, breach_wall(side, wall))
	playsound(loc, 'sound/effects/Glassbr3.ogg', 70, TRUE)
	update_icon()
	return TRUE

// Welds the breach on side shut, as the wall was before it broke.
/obj/structure/vehicleparts/frame/proc/mend_breach(side)
	var/list/was = breached_walls ? breached_walls[side] : null
	if (!was)
		return FALSE
	var/list/wall = was.Copy()
	wall[5] = VEHICLE_BREACH_MENDED
	wall[7] = FALSE
	set_wall_list(side, wall)
	breached_walls -= side
	if (!breached_walls.len)
		breached_walls = null
	if (broken && (w_left[5] + w_right[5] + w_back[5] + w_front[5] > 0))
		broken = FALSE
	update_icon()
	return TRUE

// Which of sides the user means: the one facing them from outside, or one
// they pick from inside.
/obj/structure/vehicleparts/frame/proc/pick_side(mob/user, list/sides, verb_text)
	if (!sides.len)
		return null
	if (get_turf(user) != get_turf(src))
		var/side = side_toward(get_dir(src, user))
		return (side in sides) ? side : null
	if (sides.len == 1)
		return sides[1]
	return WWinput(user, "Which side do you [verb_text]?", "Vehicle", sides[1], sides)

// The frame's attackby hook (frame.dm): smashing glass and welding breaches.
/obj/structure/vehicleparts/frame/proc/breach_attackby(obj/item/I, mob/living/human/H)
	if (!istype(H) || !I || H.travel_held() || !(Adjacent(H) || get_turf(H) == get_turf(src)))
		return FALSE
	if (istype(I, /obj/item/stack/material/steel) && breached_walls)
		var/obj/item/W = H.get_inactive_hand()
		if (!W || !is_tool(W, TOOL_WELDER))
			return FALSE
		var/side = pick_side(H, breach_sides(), "weld shut")
		if (!side)
			return FALSE
		var/obj/item/stack/material/steel/S = I
		if (S.amount < VEHICLE_BREACH_STEEL)
			to_chat(H, SPAN_WARNING("You need [VEHICLE_BREACH_STEEL] sheets of steel to weld the hole shut."))
			return TRUE
		H.visible_message(SPAN_NOTICE("[H] starts welding a plate over the hole in \the [src]."))
		if (!do_after(H, trade_time(H, VEHICLE_BREACH_TIME, "mechanic"), src) || QDELETED(S) || !(side in breach_sides()))
			return TRUE
		if (!S.use(VEHICLE_BREACH_STEEL))
			return TRUE
		mend_breach(side)
		H.visible_message(SPAN_NOTICE("[H] welds the hole in \the [src] shut."))
		return TRUE
	if (H.a_intent != I_HARM || I.force < VEHICLE_GLASS_FORCE)
		return FALSE
	var/list/glass = glass_sides()
	var/side = pick_side(H, glass, "smash out")
	if (!side)
		return FALSE
	var/inside = get_turf(H) == get_turf(src)
	H.visible_message(SPAN_WARNING("[H] starts smashing out the glass of \the [src] with \the [I]!"))
	if (!do_after(H, inside ? VEHICLE_GLASS_INSIDE_TIME : VEHICLE_GLASS_OUTSIDE_TIME, src) || H.travel_held())
		return TRUE
	if (smash_glass(side))
		H.visible_message(SPAN_DANGER("[H] smashes the glass out of \the [src]!"))
	return TRUE

#undef VEHICLE_BREACH_STEEL
#undef VEHICLE_BREACH_TIME
#undef VEHICLE_BREACH_MENDED
#undef VEHICLE_GLASS_FORCE
#undef VEHICLE_GLASS_INSIDE_TIME
#undef VEHICLE_GLASS_OUTSIDE_TIME
