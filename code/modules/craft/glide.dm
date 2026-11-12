// ============================================================
// Gliding (docs/craft-core.md): a craft step shown as one unbroken motion
// ------------------------------------------------------------
// A body made of objects can move a tile at a time. The server still moves
// everything aboard from one tile to the next in a single call; this file only
// tells clients how to draw that step, so that the deck, the things on it,
// the crew and the cameras of the crew all travel together for exactly as
// long as the step lasts.
//
// Two cases, because the engine only glides things that stand square on
// their tile:
//  - a thing square on its tile is glided by the engine at glide_size;
//  - a thing with a step offset or unusual bounds (a free-moving human) is not
//    glided by the engine, so it is drawn one tile back and animated forward
//    over the same time, and so is the view of a player who is that mob.
//
// Appearance only: nothing here moves anything or owns a timer of the craft.
// ============================================================

/datum/craft_body
	var/glides = FALSE            // TRUE when a one-tile step can be shown as a glide.
	var/tmp/glide_time = 0        // Ticks the step now being made should take on screen.
	var/tmp/list/glide_was = null // Things whose glide_size she holds: atom = list(before, applied).

// TRUE when the engine itself will glide this thing over a one-tile move.
/proc/craft_glides_natively(atom/movable/M)
	return !M.step_x && !M.step_y && !M.bound_x && !M.bound_y && M.bound_width == world.icon_size && M.bound_height == world.icon_size

// The glide_size that carries a thing one tile in this many ticks.
/proc/craft_glide_size(time)
	return world.icon_size * world.tick_lag / max(time, world.tick_lag)

// Shows the move M has just made, by (dx, dy) tiles, as a glide lasting time.
// was is the mover's own record of the glides it holds (atom = list(before,
// applied)), kept so that each thing gets its own glide back afterwards.
/proc/glide_show(list/was, atom/movable/M, dx, dy, time)
	if (craft_glides_natively(M))
		var/size = craft_glide_size(time)
		var/list/held = was[M]
		if (!held)
			was[M] = list(M.glide_size, size)
		else
			// Something else set its glide since; that is the value to give back.
			if (M.glide_size != held[2])
				held[1] = M.glide_size
			held[2] = size
		M.glide_size = size
		return
	glide_slide(M, dx, dy, time)

// Draws A (a thing or a tile) where it was, (dx, dy) tiles back, and slides it
// to where it now is over time, with the view of a player who is that mob.
/proc/glide_slide(atom/A, dx, dy, time, easing = LINEAR_EASING)
	var/shift_x = dx * world.icon_size
	var/shift_y = dy * world.icon_size
	var/rest_x = A.pixel_x
	var/rest_y = A.pixel_y
	A.pixel_x = rest_x - shift_x
	A.pixel_y = rest_y - shift_y
	animate(A, pixel_x = rest_x, pixel_y = rest_y, time = time, easing = easing)
	if (ismob(A))
		var/mob/rider = A
		var/client/C = rider.client
		if (C && C.eye == rider)
			rest_x = C.pixel_x
			rest_y = C.pixel_y
			C.pixel_x = rest_x - shift_x
			C.pixel_y = rest_y - shift_y
			animate(C, pixel_x = rest_x, pixel_y = rest_y, time = time, easing = easing)

// How long a turn is shown swinging round, in ticks.
/proc/glide_turn_time()
	return 5

// Shows the place M has just taken in a turn, (dx, dy) tiles from where it
// was. One tile is an ordinary glide; the engine does not glide a longer
// move, so that is slid, easing in and out like a hull swinging round.
/proc/glide_swing(list/was, atom/movable/M, dx, dy, time)
	if (!dx && !dy)
		return
	if (abs(dx) <= 1 && abs(dy) <= 1)
		glide_show(was, M, dx, dy, time)
	else
		glide_slide(M, dx, dy, time, SINE_EASING)

// Gives back the glide of whatever in was is no longer in aboard. With null,
// of everything.
/proc/glide_give_back(list/was, list/aboard)
	if (!was || !was.len)
		return
	var/list/still = list()
	if (aboard)
		for (var/atom/movable/M in aboard)
			still[M] = TRUE
	for (var/atom/movable/M in was.Copy())
		if (still[M])
			continue
		var/list/held = was[M]
		was -= M
		if (M && !QDELETED(M) && M.glide_size == held[2])
			M.glide_size = held[1]

/datum/craft_body/proc/craft_glide(atom/movable/M, dx, dy, time)
	if (!glide_was)
		glide_was = list()
	glide_show(glide_was, M, dx, dy, time)

// After a step: gives back the glide of whatever she no longer carries. With
// null, of everything.
/datum/craft_body/proc/glide_keep(list/aboard)
	glide_give_back(glide_was, aboard)

// She has stopped: once her last step has been drawn, everything aboard
// glides at its own pace again.
/datum/craft_body/proc/glide_rest(after)
	if (!glide_was || !glide_was.len)
		return
	addtimer(CALLBACK(src, PROC_REF(glide_rest_now)), after + 1)

/datum/craft_body/proc/glide_rest_now()
	if (craft && craft.hop_timer)
		return
	glide_keep(null)

/datum/craft_body/Destroy()
	glide_keep(null)
	return ..()

// ---- Modular vehicles (axis.do_move()) ----
// A vehicle of frames moves a tile every vehicle_m_delay + 1 ticks. Each
// step is shown the same way, for the frames, wheels, everything stood on
// them and the crew, so the vehicle rolls instead of hopping.

/obj/structure/vehicleparts/axis
	var/tmp/list/glide_was = null // Things whose glide_size it holds.

// How long one step of this vehicle lasts on screen, in ticks.
/obj/structure/vehicleparts/axis/proc/glide_step_time()
	return vehicle_m_delay + 1

// After do_move(): moved maps each thing carried to the tile it left.
/obj/structure/vehicleparts/axis/proc/glide_step(list/moved)
	var/time = glide_step_time()
	if (time <= world.tick_lag)
		glide_give_back(glide_was, null)
		return
	if (!glide_was)
		glide_was = list()
	var/list/carried = list()
	for (var/atom/movable/M in moved)
		var/turf/from = moved[M]
		if (QDELETED(M) || !isturf(M.loc) || !istype(from) || M.loc == from)
			continue
		var/dx = M.x - from.x
		var/dy = M.y - from.y
		if (M.z != from.z || abs(dx) > 1 || abs(dy) > 1)
			continue
		glide_show(glide_was, M, dx, dy, time)
		carried += M
	glide_give_back(glide_was, carried)

// After do_matrix(): was_at maps each thing carried to the tile it left. The
// turn is shown swinging round instead of snapping.
/obj/structure/vehicleparts/axis/proc/glide_turn(list/was_at)
	var/time = glide_turn_time()
	if (!glide_was)
		glide_was = list()
	for (var/atom/movable/M in was_at)
		var/turf/from = was_at[M]
		if (QDELETED(M) || !isturf(M.loc) || !istype(from) || M.z != from.z || M.invisibility >= 101)
			continue
		glide_swing(glide_was, M, M.x - from.x, M.y - from.y, time)
	if (!moving)
		glide_rest()

// The vehicle has stopped: once its last step has been drawn, everything
// aboard glides at its own pace again.
/obj/structure/vehicleparts/axis/proc/glide_rest()
	if (!glide_was || !glide_was.len)
		return
	addtimer(CALLBACK(src, PROC_REF(glide_rest_now)), max(glide_step_time(), glide_turn_time()) + 1)

/obj/structure/vehicleparts/axis/proc/glide_rest_now()
	if (moving)
		return
	glide_give_back(glide_was, null)
