// An upstairs lob uses one visible edge or window, never a generic cross-level
// throw. The same flight mechanism handles all eligible held items.
#define WINDOW_LOB_MAX_RANGE 7
/proc/window_lob_range(strength, size)
	return clamp(round(5 + 3 * (strength - 1)) - max(0, size - ITEM_SIZE_SMALL), 2, WINDOW_LOB_MAX_RANGE)

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
	return window_lob_sky_clear(sky)

/proc/window_lob_sky_clear(turf/T)
	return building_open_turf(T) && !(locate(/obj/covers) in T) && !(locate(/obj/roof) in T) && !trapdoor_shut_at(T) && window_lob_clear(T)

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
	if (!(direction in cardinal) || get_step(upper_outside, direction) != opening)
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

// An exposed ledge is entered directly from adjacent open air. A window
// opening stays a separate route; a shut fitting can never act as a ledge.
/proc/window_lob_exposed_floor(turf/T, mob/living/human/H)
	if (!window_lob_floor(T) || los_turf_roofed(T) || (locate(/obj/roof) in T) || window_lob_has_opening(T, H))
		return FALSE
	var/above_z = building_upper_z(T.z)
	return !above_z || window_lob_open_column(T, above_z)

/proc/window_lob_exposed_clear(mob/living/human/H, turf/T)
	return window_lob_exposed_floor(T, H) && window_lob_clear(T) && !window_lob_grace_blocked(H, T)

/proc/window_lob_landing(mob/living/human/H, turf/outside, turf/target, direction, via_window)
	if (via_window)
		return window_lob_inside(H, outside, target, direction)
	if (QDELETED(H) || !outside || !target || building_upper_z(outside.z) != target.z || !window_lob_open_column(outside, target.z))
		return null
	var/turf/upper_outside = locate(outside.x, outside.y, target.z)
	var/distance = get_dist(upper_outside, target)
	if (!distance || distance > WINDOW_LOB_MAX_RANGE || window_lob_grace_blocked(H, upper_outside))
		return null
	var/turf/previous = upper_outside
	for (var/turf/T in getline2(upper_outside, target, FALSE))
		if (!window_lob_exposed_clear(H, T))
			return null
		var/step_dir = get_dir(previous, T)
		if (step_dir in cornerdirs)
			if (!window_lob_upper_corner_clear(H, get_step(previous, step_dir & (NORTH|SOUTH))) && !window_lob_upper_corner_clear(H, get_step(previous, step_dir & (EAST|WEST))))
				return null
		previous = T
	return target

/proc/window_lob_upper_corner_clear(mob/living/human/H, turf/T)
	return !window_lob_grace_blocked(H, T) && (window_lob_exposed_clear(H, T) || window_lob_sky_clear(T))

/mob/living/human/proc/window_lob_can_hold(obj/item/I, turf/ground)
	if (QDELETED(I) || I.nothrow || I.anchored || I.wrist_looped || I.lanyard_tied || istype(I, /obj/item/weapon/grab))
		return FALSE
	// Lit bottles keep their dedicated direct-throw and grace-period rules.
	var/obj/item/weapon/reagent_containers/food/drinks/bottle/B = I
	if (istype(B) && B.rag && B.rag.on_fire)
		return FALSE
	return loc == ground && I.loc == src && get_active_hand() == I && !incapacitated() && can_use_hands() && !buckled && !riding && !lying && !throwing && look_up_can_see() && canUnEquip(I)

// Keep both aim and resolution bounded. A failed attempt lands on the last
// clear exterior tile rather than crossing the first obstruction.
/proc/window_lob_exterior_hop_clear(mob/living/human/H, turf/origin, turf/destination, upper_z)
	var/step_dir = get_dir(origin, destination)
	if (!step_dir || get_step(origin, step_dir) != destination || !window_lob_exterior_step(H, destination, upper_z))
		return FALSE
	if (step_dir in cornerdirs)
		if (!window_lob_exterior_step(H, get_step(origin, step_dir & (NORTH|SOUTH)), upper_z) && !window_lob_exterior_step(H, get_step(origin, step_dir & (EAST|WEST)), upper_z))
			return FALSE
	return TRUE

/proc/window_lob_approach(mob/living/human/H, turf/ground, turf/target, reach)
	var/list/path = list()
	if (!ground || !target || max(abs(target.x - ground.x), abs(target.y - ground.y)) > reach)
		return path
	var/turf/previous = ground
	for (var/turf/step in getline2(ground, target, FALSE))
		if ((step.x == target.x && step.y == target.y) || !window_lob_exterior_hop_clear(H, previous, step, target.z))
			break
		path += step
		previous = step
	return path

/mob/living/human/proc/window_lob_release(obj/item/I, turf/ground, turf/target, direction, list/path, can_land, via_window)
	if (!window_lob_can_hold(I, ground) || !window_lob_floor(ground) || !persistence_movement_allowed(I, ground))
		return FALSE
	if (!unEquip(I, Target = ground) || QDELETED(I) || I.loc != ground)
		return FALSE
	body_motion_throw(target)
	throw_mode_off()
	playsound(src, 'sound/effects/throw.ogg', 50, TRUE)
	visible_message(SPAN_WARNING("[src] lobs \the [I] upstairs!"), SPAN_WARNING("You lob \the [I] upstairs!"))
	adaptStat("throwing", 0.05)
	return I.start_window_lob(src, target, direction, path, can_land, via_window)

// Directly clicking the tile just inside an aimed window is equivalent to
// clicking its frame. Never treat a deeper room tile as a window target.
/proc/window_lob_clicked_window(mob/living/human/H, turf/eye, turf/target)
	if (!eye || !target || eye.z != target.z)
		return null
	var/distance = get_dist(eye, target)
	if (distance < 2 || distance > WINDOW_LOB_MAX_RANGE)
		return null
	var/list/line = getline2(eye, target, FALSE)
	var/turf/frame = line[length(line) - 1]
	if (window_lob_has_opening(frame, H) && (get_dir(frame, target) in cardinal))
		return frame
	return null

// An unmodified click in Throw mode while using the actual Look Up eye aims
// at the turf, never the item, mob, or inventory that happened to be clicked.
/mob/living/human/proc/window_lob_click(atom/A, right_click)
	var/turf/target = isturf(A) ? A : A.loc
	if (!in_throw_mode || !looking_up_at || !isturf(target) || target.z != looking_up_at.z)
		return FALSE
	// Own this cross-level input even when refused; never fall through to
	// weapon use or the ordinary XY throw on the lower level.
	if (right_click || !canClick())
		return TRUE
	var/turf/ground = loc
	var/turf/upper_eye = looking_up_at
	var/obj/item/I = get_active_hand()
	if (!client || client.eye != upper_eye || !isturf(ground) || !window_lob_can_hold(I, ground) || look_up_target() != upper_eye || !window_lob_open_column(ground, upper_eye.z) || orbit_world() || underground_added(ground.z))
		to_chat(src, SPAN_WARNING("You can only throw a loose item upstairs from under open sky."))
		return TRUE
	for (var/obj/structure/noose/N in ground)
		if (N.hanging == src)
			return TRUE
	var/reach = window_lob_range(getStatCoeff("strength"), I.w_class)
	var/distance = get_dist(upper_eye, target)
	if (!distance || distance > reach || !(target in view(reach, upper_eye)))
		to_chat(src, SPAN_WARNING("That upstairs tile is not visible and within reach."))
		return TRUE
	var/via_window = window_lob_has_opening(target, src)
	if (!via_window)
		var/turf/frame = window_lob_clicked_window(src, upper_eye, target)
		if (frame)
			target = frame
			via_window = TRUE
			distance = get_dist(upper_eye, target)
		else if (!window_lob_exposed_floor(target, src))
			to_chat(src, SPAN_WARNING("Aim at an exposed upper floor, a window, or the first tile just inside it."))
			return TRUE
	var/list/path = window_lob_approach(src, ground, target, reach)
	var/turf/outside = length(path) ? path[length(path)] : ground
	var/direction = get_dir(locate(outside.x, outside.y, target.z), target)
	var/turf/landing = window_lob_landing(src, outside, target, direction, via_window)
	window_lob_release(I, ground, target, direction, path, landing && prob(window_lob_accuracy(getStat("throwing"), distance)), via_window)
	return TRUE

/mob/living/human/verb/lob_upstairs()
	set name = "Lob Upstairs"
	set category = "IC"
	set desc = "Aim the item in your active hand at an exposed upper floor or a window from outdoors."
	var/turf/ground = loc
	var/obj/item/I = get_active_hand()
	if (!client || !isturf(ground) || !istype(I) || !window_lob_floor(ground) || !window_lob_can_hold(I, ground))
		to_chat(src, SPAN_WARNING("You need a free-standing stance and a throwable item in your active hand."))
		return
	var/upper_z = building_upper_z(ground.z)
	if (orbit_world() || underground_added(ground.z) || !window_lob_open_column(ground, upper_z))
		to_chat(src, SPAN_WARNING("You need open sky above you to lob upstairs."))
		return
	if (!looking_up_at && !start_looking_up())
		return
	var/turf/upper_eye = looking_up_at
	if (!upper_eye || upper_eye.z != upper_z || look_up_target() != upper_eye)
		return
	var/reach = window_lob_range(getStatCoeff("strength"), I.w_class)
	var/list/choices = list()
	var/list/visible_upper = view(reach, upper_eye)
	for (var/direction in cardinal)
		var/turf/target = upper_eye
		for (var/distance in 1 to reach)
			var/turf/previous = target
			target = get_step(target, direction)
			if (!target)
				break
			if (target.density || !(target in visible_upper))
				continue
			var/turf/below_previous = locate(previous.x, previous.y, ground.z)
			if (!window_lob_open_column(below_previous, upper_z))
				continue
			var/via_window = window_lob_has_opening(target, src)
			if (via_window ? !window_lob_floor(get_step(target, direction)) : !window_lob_exposed_floor(target, src))
				continue
			var/label = via_window ? "Window" : "Exposed floor"
			choices["[label] [dir2text(direction)] - [distance] tile[distance == 1 ? "" : "s"]"] = list("target" = target, "via_window" = via_window)
	if (!length(choices))
		to_chat(src, SPAN_WARNING("No upstairs target is in reach on a straight line. Line up with an exposed edge or window."))
		return
	var/fuse_note = istype(I, /obj/item/weapon/grenade) ? " The fuse keeps running once lit." : ""
	var/picked = player_input(src, "Choose a visible upstairs target.[fuse_note]", "Lob Upstairs", null, "anything", choices, TRUE)
	var/list/choice = choices[picked]
	if (!islist(choice))
		return
	var/turf/target = choice["target"]
	var/via_window = choice["via_window"]
	if (!target || !window_lob_can_hold(I, ground) || looking_up_at != upper_eye || look_up_target() != upper_eye)
		return
	var/direction = get_dir(upper_eye, target)
	var/distance = get_dist(upper_eye, target)
	var/list/path = window_lob_approach(src, ground, target, distance)
	var/turf/outside = length(path) ? path[length(path)] : ground
	var/turf/landing = window_lob_landing(src, outside, target, direction, via_window)
	var/aim = landing ? "[via_window ? "Just inside the window" : "On the exposed upper floor"] ([landing.x], [landing.y], level [landing.z]). A miss falls outside." : "Stops outside at ([outside.x], [outside.y], level [outside.z]); the path is blocked."
	var/accuracy = window_lob_accuracy(getStat("throwing"), distance)
	if (player_alert(src, "[aim] [landing ? "Chance to reach the target: [accuracy]%." : ""][fuse_note]", "Lob preview", list("Lob", "Cancel")) != "Lob")
		return
	if (!window_lob_can_hold(I, ground) || looking_up_at != upper_eye || look_up_target() != upper_eye || window_lob_range(getStatCoeff("strength"), I.w_class) < distance)
		return
	var/list/current_path = window_lob_approach(src, ground, target, distance)
	var/turf/current_outside = length(current_path) ? current_path[length(current_path)] : ground
	if (outside != current_outside || landing != window_lob_landing(src, current_outside, target, direction, via_window))
		to_chat(src, SPAN_WARNING("The path changed. Aim again to see the new landing spot."))
		return
	window_lob_release(I, ground, target, direction, current_path, landing && prob(accuracy), via_window)

/obj/item/proc/start_window_lob(mob/living/human/H, turf/opening, direction, list/path, can_enter, via_window = TRUE)
	var/list/previous = throw_flight_token
	throw_at(opening, length(path) + 1, max(1, throw_speed - 1), H)
	// Some item overrides start the inherited flight without returning its value.
	if (!throwing || !throw_flight_token || throw_flight_token == previous)
		return FALSE
	throw_flight_token["window_lob_path"] = path
	throw_flight_token["window_lob_opening"] = opening
	throw_flight_token["window_lob_direction"] = direction
	throw_flight_token["window_lob_arrival"] = loc
	throw_flight_token["window_lob_can_enter"] = can_enter
	throw_flight_token["window_lob_via_window"] = via_window
	throw_flight_token["window_lob_next_tick"] = world.time + 2
	return TRUE

/obj/item/proc/window_lob_hop(list/flight)
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
		if (!window_lob_exterior_hop_clear(H, here, target, opening.z) || !forceMove_nondenseturf(target))
			if (!QDELETED(src) && throw_flight_token == flight)
				finished_throwing()
			return
		if (!QDELETED(src) && throw_flight_token == flight)
			path.Cut(1, 2)
			flight["window_lob_arrival"] = target
			flight["window_lob_next_tick"] = world.time + 2
		return
	var/turf/inside = flight["window_lob_can_enter"] ? window_lob_landing(H, here, opening, direction, flight["window_lob_via_window"]) : null
	if (inside)
		original_target = null // Never fall back to the generic XY flight on this hop.
		// Cross-level forceMove clears the old token. Never finish a new
		// flight that an Entered/Crossed callback has just started.
		var/advanced = forceMove_nondenseturf(inside)
		if (!QDELETED(src) && (isnull(throw_flight_token) || (!advanced && throw_flight_token == flight)))
			finished_throwing()
	else
		finished_throwing()

#undef WINDOW_LOB_MAX_RANGE
