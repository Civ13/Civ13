// An aimed grenade lob is an explicit outside-to-window route, never a
// generic cross-level throw. Look Up supplies the visible upper openings.
/proc/window_lob_range(strength, size)
	return clamp(round(5 + 3 * (strength - 1)) - max(0, size - ITEM_SIZE_SMALL), 2, 7)

/proc/window_lob_accuracy(skill, distance)
	return clamp(93 + round((skill - 100) / 2) - 4 * (distance - 1), 50, 100)

/proc/window_lob_clear(turf/T, aperture = FALSE)
	if (!T || T.density)
		return FALSE
	for (var/obj/O in T)
		if (QDELETED(O) || O.loc != T)
			continue
		if (istype(O, /obj/structure/simple_door))
			var/obj/structure/simple_door/D = O
			if (D.is_window_door())
				if (!aperture || !D.state || D.isSwitchingStates || D.door_barred())
					return FALSE
				continue // Even open casements stay dense for walking mobs.
		if (istype(O, /obj/structure/window) || (istype(O, /obj/structure/grille) && O.density))
			return FALSE
		if (istype(O, /obj/covers))
			var/obj/covers/C = O
			if (!C.passable)
				return FALSE
		if (O.density && !O.throwpass)
			return FALSE
	return TRUE

/proc/window_lob_has_opening(turf/T, mob/living/human/H)
	if (!T)
		return FALSE
	for (var/obj/O in T)
		if (QDELETED(O) || O.loc != T || O.invisibility > H.see_invisible)
			continue
		if (istype(O, /obj/structure/window_frame) || istype(O, /obj/structure/window))
			return TRUE
		if (istype(O, /obj/structure/simple_door))
			var/obj/structure/simple_door/D = O
			if (D.is_window_door())
				return TRUE
	return FALSE

/proc/window_lob_open_column(turf/ground, upper_z)
	if (!ground || !upper_z || los_turf_roofed(ground) || (locate(/obj/roof) in ground))
		return FALSE
	var/turf/sky = locate(ground.x, ground.y, upper_z)
	return building_open_turf(sky) && !(locate(/obj/covers) in sky) && !(locate(/obj/roof) in sky) && !trapdoor_shut_at(sky) && window_lob_clear(sky)

/proc/window_lob_floor(turf/T)
	if (!T)
		return FALSE
	if (!building_open_turf(T) || trapdoor_shut_at(T))
		return TRUE
	for (var/obj/covers/C in T)
		if (!QDELETED(C) && C.loc == T && C.passable)
			return TRUE
	return FALSE

/proc/window_lob_grace_blocked(mob/living/human/H, turf/T)
	return map && map.check_caribbean_block(H, T)

/proc/window_lob_exterior_step(mob/living/human/H, turf/step, upper_z)
	if (!window_lob_floor(step) || !window_lob_clear(step) || !window_lob_open_column(step, upper_z))
		return FALSE
	return !window_lob_grace_blocked(H, step) && !window_lob_grace_blocked(H, locate(step.x, step.y, upper_z))

// The last hop uses the exact frame and its immediate interior. It cannot
// tunnel through a wall, closed fitting, or an intervening solid object.
/proc/window_lob_inside(mob/living/human/H, turf/outside, turf/opening, direction)
	if (QDELETED(H) || !outside || !opening || building_upper_z(outside.z) != opening.z)
		return null
	if (!window_lob_open_column(outside, opening.z) || !window_lob_has_opening(opening, H) || !window_lob_clear(opening, TRUE))
		return null
	var/turf/upper_outside = locate(outside.x, outside.y, opening.z)
	if (get_step(upper_outside, direction) != opening)
		return null
	var/turf/inside = get_step(opening, direction)
	if (!window_lob_floor(inside) || !window_lob_clear(inside))
		return null
	for (var/obj/structure/simple_door/D in opening)
		if (!QDELETED(D) && D.is_window_door() && D.inner_dir > 0 && D.inner_dir != direction)
			return null
	if (window_lob_grace_blocked(H, upper_outside) || window_lob_grace_blocked(H, opening) || window_lob_grace_blocked(H, inside))
		return null
	return inside

/mob/living/human/proc/window_lob_can_hold(obj/item/weapon/grenade/G, turf/ground)
	return !QDELETED(G) && !G.nothrow && !G.wrist_looped && !G.lanyard_tied && loc == ground && G.loc == src && get_active_hand() == G && !incapacitated() && can_use_hands() && !buckled && !riding && !lying && !throwing && look_up_can_see() && canUnEquip(G)

// Keep both aim and resolution bounded. A failed attempt lands on the last
// clear exterior tile rather than crossing the first obstruction.
/proc/window_lob_approach(mob/living/human/H, turf/ground, turf/opening, direction, reach)
	var/list/path = list()
	var/turf/step = ground
	for (var/i in 1 to reach)
		if (step.x == opening.x && step.y == opening.y)
			break
		var/turf/next = get_step(step, direction)
		if (!next || (next.x == opening.x && next.y == opening.y) || !window_lob_exterior_step(H, next, opening.z))
			break
		path += next
		step = next
	return path

/mob/living/human/verb/lob_at_upper_window()
	set name = "Lob at Upper Window"
	set category = "IC"
	set desc = "Aim the grenade in your active hand at an upper window from outdoors."
	var/turf/ground = loc
	var/obj/item/weapon/grenade/G = get_active_hand()
	if (!client || !isturf(ground) || !istype(G) || !window_lob_floor(ground) || !window_lob_can_hold(G, ground))
		to_chat(src, SPAN_WARNING("You need a grenade in your active hand and both feet on the ground."))
		return
	var/upper_z = building_upper_z(ground.z)
	if (orbit_world() || underground_added(ground.z) || !window_lob_open_column(ground, upper_z))
		to_chat(src, SPAN_WARNING("You need open sky above you to lob at a window."))
		return
	if (!looking_up_at && !start_looking_up())
		return
	var/turf/upper_eye = looking_up_at
	if (!upper_eye || upper_eye.z != upper_z || look_up_target() != upper_eye)
		return
	var/reach = window_lob_range(getStatCoeff("strength"), G.w_class)
	var/list/choices = list()
	var/list/visible_upper = view(reach, upper_eye)
	for (var/direction in cardinal)
		var/turf/target = upper_eye
		for (var/distance in 1 to reach)
			target = get_step(target, direction)
			if (!target)
				break
			if (target in visible_upper)
				var/turf/beyond = get_step(target, direction)
				if (window_lob_floor(beyond) && window_lob_has_opening(target, src))
					choices["[dir2text(direction)] - [distance] tile[distance == 1 ? "" : "s"]"] = target
	if (!length(choices))
		to_chat(src, SPAN_WARNING("No upper window is in reach straight ahead, behind, or to either side. Line up with the window from outside."))
		return
	var/picked = player_input(src, "Choose a visible window. The fuse keeps running while you aim.", "Lob at Upper Window", null, "anything", choices, TRUE)
	var/turf/opening = choices[picked]
	if (!opening || !window_lob_can_hold(G, ground) || looking_up_at != upper_eye || look_up_target() != upper_eye)
		return
	var/direction = get_dir(upper_eye, opening)
	var/distance = get_dist(upper_eye, opening)
	var/list/path = window_lob_approach(src, ground, opening, direction, distance)
	var/turf/outside = length(path) ? path[length(path)] : ground
	var/turf/inside = window_lob_inside(src, outside, opening, direction)
	var/aim = inside ? "Just inside the window ([inside.x], [inside.y], level [inside.z]). A miss falls outside." : "Stops outside at ([outside.x], [outside.y], level [outside.z]); the path is blocked."
	var/accuracy = window_lob_accuracy(getStat("throwing"), distance)
	if (player_alert(src, "[aim]\n[inside ? "Chance to hit the opening: [accuracy]%. " : ""]The fuse keeps running.", "Lob preview", list("Lob", "Cancel")) != "Lob")
		return
	if (!window_lob_can_hold(G, ground) || looking_up_at != upper_eye || look_up_target() != upper_eye || window_lob_range(getStatCoeff("strength"), G.w_class) < distance)
		return
	var/list/current_path = window_lob_approach(src, ground, opening, direction, distance)
	var/turf/current_outside = length(current_path) ? current_path[length(current_path)] : ground
	if (outside != current_outside || inside != window_lob_inside(src, current_outside, opening, direction))
		to_chat(src, SPAN_WARNING("The path changed. Aim again to see the new landing spot."))
		return
	if (!window_lob_floor(ground) || !persistence_movement_allowed(G, ground))
		return
	if (!unEquip(G, Target = ground) || QDELETED(G) || G.loc != ground)
		return
	body_motion_throw(opening)
	throw_mode_off()
	playsound(src, 'sound/effects/throw.ogg', 50, TRUE)
	visible_message(SPAN_WARNING("[src] lobs \the [G] toward an upper window!"), SPAN_WARNING("You lob \the [G] toward the upper window!"))
	adaptStat("throwing", 0.05)
	G.start_window_lob(src, opening, direction, current_path, inside && prob(accuracy))

/obj/item/weapon/grenade/proc/start_window_lob(mob/living/human/H, turf/opening, direction, list/path, can_enter)
	if (!throw_at(opening, length(path) + 1, max(1, throw_speed - 1), H))
		return FALSE
	throw_flight_token["window_lob_path"] = path
	throw_flight_token["window_lob_opening"] = opening
	throw_flight_token["window_lob_direction"] = direction
	throw_flight_token["window_lob_arrival"] = loc
	throw_flight_token["window_lob_can_enter"] = can_enter
	throw_flight_token["window_lob_next_tick"] = world.time + 2
	return TRUE

/obj/item/weapon/grenade/proc/window_lob_hop(list/flight)
	if (!flight || throw_flight_token != flight)
		return
	var/turf/here = loc
	var/mob/living/human/H = thrower
	var/turf/opening = flight["window_lob_opening"]
	if (!throwing || QDELETED(H) || !isturf(here) || here != flight["window_lob_arrival"] || !opening || building_upper_z(here.z) != opening.z || !window_lob_open_column(here, opening.z))
		finished_throwing()
		return
	if (world.time < flight["window_lob_next_tick"])
		return
	var/direction = flight["window_lob_direction"]
	var/list/path = flight["window_lob_path"]
	if (length(path))
		var/turf/target = path[1]
		if (get_step(here, direction) != target || !window_lob_exterior_step(H, target, opening.z) || !forceMove_nondenseturf(target))
			if (!QDELETED(src) && throw_flight_token == flight)
				finished_throwing()
			return
		if (!QDELETED(src) && throw_flight_token == flight)
			path.Cut(1, 2)
			flight["window_lob_arrival"] = target
			flight["window_lob_next_tick"] = world.time + 2
		return
	var/turf/inside = flight["window_lob_can_enter"] ? window_lob_inside(H, here, opening, direction) : null
	if (inside)
		original_target = null // Never fall back to the generic XY flight on this hop.
		// Cross-level forceMove clears the old token. Never finish a new
		// flight that an Entered/Crossed callback has just started.
		var/advanced = forceMove_nondenseturf(inside)
		if (!QDELETED(src) && (isnull(throw_flight_token) || (!advanced && throw_flight_token == flight)))
			finished_throwing()
	else
		finished_throwing()
