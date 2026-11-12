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
/datum/craft_body/proc/craft_glide(atom/movable/M, dx, dy, time)
	if (craft_glides_natively(M))
		var/size = craft_glide_size(time)
		if (!glide_was)
			glide_was = list()
		var/list/held = glide_was[M]
		if (!held)
			glide_was[M] = list(M.glide_size, size)
		else
			// Something else set its glide since; that is the value to give back.
			if (M.glide_size != held[2])
				held[1] = M.glide_size
			held[2] = size
		M.glide_size = size
		return
	var/shift_x = dx * world.icon_size
	var/shift_y = dy * world.icon_size
	var/rest_x = M.pixel_x
	var/rest_y = M.pixel_y
	M.pixel_x = rest_x - shift_x
	M.pixel_y = rest_y - shift_y
	animate(M, pixel_x = rest_x, pixel_y = rest_y, time = time)
	if (ismob(M))
		var/mob/rider = M
		var/client/C = rider.client
		if (C && C.eye == rider)
			rest_x = C.pixel_x
			rest_y = C.pixel_y
			C.pixel_x = rest_x - shift_x
			C.pixel_y = rest_y - shift_y
			animate(C, pixel_x = rest_x, pixel_y = rest_y, time = time)

// After a step: gives back the glide of whatever she no longer carries. With
// null, of everything.
/datum/craft_body/proc/glide_keep(list/aboard)
	if (!glide_was || !glide_was.len)
		return
	var/list/still = list()
	if (aboard)
		for (var/atom/movable/M in aboard)
			still[M] = TRUE
	for (var/atom/movable/M in glide_was.Copy())
		if (still[M])
			continue
		var/list/held = glide_was[M]
		glide_was -= M
		if (M && !QDELETED(M) && M.glide_size == held[2])
			M.glide_size = held[1]

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
