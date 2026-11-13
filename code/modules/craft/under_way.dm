// ============================================================
// Under way (docs/craft-core.md): hop sailing for any craft body
// ------------------------------------------------------------
// The telegraph, anchor, hop timer and path warning for a craft whose body
// can plan a move (craft_body.move_cells). Turf-built vessels keep their own
// copy of these rules in naval/vessel.dm; everything newer sails from here.
//
// A craft hops every VESSEL_HOP_INTERVAL along its heading by
// VESSEL_TILES_PER_STEP tiles per telegraph step, marks the water it is about
// to cover VESSEL_PATH_WARNING ahead, and stops with a reason when something
// is in the way.
//
// A body made of objects (body.glides, craft/glide.dm) covers the same water
// in the same time one tile at a step, and every step is shown to clients as
// one unbroken glide of the deck, all aboard and the cameras of her crew.
// ============================================================

/datum/craft
	var/speed = 0
	var/anchored = TRUE
	var/last_refusal = ""
	var/tmp/hop_timer = 0
	var/tmp/warn_timer = 0
	var/tmp/turning_to = 0
	var/tmp/list/path_markers = list()
	var/tmp/sailing_at = 0       // The telegraph step the running timer was set for.
	var/tmp/tiles_since_burn = 0 // Tiles glided since her drives last paid.
	// How many times faster than the sea she makes her way. A battle map sets
	// it on its ships (map_metadata/broadside.dm); everywhere else it is 1.
	var/tmp/pace = 1

// The turfs a move would occupy, or null with last_refusal set. Writes
// nothing. A body that cannot plan cannot sail from here.
/datum/craft_body/proc/move_cells(x, y, heading)
	last_refusal = "it cannot move"
	return null

/datum/craft_body/template/move_cells(x, y, heading)
	if (!placed())
		last_refusal = "she is not afloat"
		return null
	var/list/dest = list()
	if (!vessel.plan_move(x, y, heading, vessel.cells(), dest, list()))
		last_refusal = vessel.last_refusal
		return null
	return dest

// The fastest telegraph step she can make. Drives decide
// (naval/hull_drives.dm); a hull with none is poled along at slow ahead.
/datum/craft/proc/max_speed()
	return VESSEL_SPEED_SLOW

/datum/craft/proc/clear_path()
	for (var/obj/effect/vessel_path/M in path_markers)
		qdel(M)
	path_markers = list()

// TRUE when she covers her water a tile at a time.
/datum/craft/proc/glides()
	return body && body.glides

// Tiles one move covers, and the ticks between moves. A gliding hull makes
// the same way as a hopping one: slow ahead is two tiles every half minute.
/datum/craft/proc/sail_tiles()
	return glides() ? 1 : speed * VESSEL_TILES_PER_STEP

/datum/craft/proc/sail_interval()
	if (!glides() || speed <= 0)
		return VESSEL_HOP_INTERVAL
	return max(1, round(VESSEL_HOP_INTERVAL / (speed * VESSEL_TILES_PER_STEP * max(pace, 1))))

/datum/craft/proc/start_sailing()
	if (hop_timer)
		if (sailing_at == speed || !glides())
			return
		// A new telegraph order changes her pace at once.
		deltimer(hop_timer)
		hop_timer = 0
	sailing_at = speed
	hop_timer = addtimer(CALLBACK(src, PROC_REF(sail_tick)), sail_interval(), TIMER_LOOP | TIMER_STOPPABLE)
	schedule_path_warning()

/datum/craft/proc/stop_sailing()
	if (hop_timer)
		deltimer(hop_timer)
		hop_timer = 0
		if (body)
			body.glide_rest(sail_interval())
	sailing_at = 0
	if (warn_timer)
		deltimer(warn_timer)
		warn_timer = 0
	if (!turning_to)
		clear_path()

/datum/craft/proc/set_speed(new_speed)
	fit_drives()
	speed = clamp(new_speed, VESSEL_SPEED_STOP, max_speed())
	if (speed > 0 && !anchored)
		start_sailing()
	else if (speed <= 0)
		stop_sailing()
	show_drives()

/datum/craft/proc/set_anchor(down)
	anchored = down
	if (!anchored && speed > 0)
		start_sailing()
	else if (anchored)
		stop_sailing()
	show_drives()

// Where the next hop would put the box corner, as list(x, y), or null.
/datum/craft/proc/next_hop()
	if (!body || !body.placed() || anchored || speed <= 0 || turning_to)
		return null
	var/turf/O = body.origin()
	if (!O)
		return null
	var/heading = body.heading()
	for (var/tiles = sail_tiles(), tiles >= 1, tiles--)
		var/turf/N = locate(O.x + (heading == EAST ? tiles : (heading == WEST ? -tiles : 0)), O.y + (heading == NORTH ? tiles : (heading == SOUTH ? -tiles : 0)), O.z)
		if (N && body.can_move_to(N.x, N.y, heading))
			return list(N.x, N.y)
	last_refusal = body.last_refusal
	return null

// Marks the tiles a move would newly cover. Returns how many.
/datum/craft/proc/mark_path(x, y, heading)
	clear_path()
	if (!body)
		return 0
	var/list/mine = body.cells()
	var/list/dest = body.move_cells(x, y, heading)
	if (!dest)
		last_refusal = body.last_refusal
		return 0
	var/turf/O = body.origin()
	for (var/turf/D in dest)
		if ((O && D.z != O.z) || (D in mine))
			continue
		path_markers += new /obj/effect/vessel_path(D)
		for (var/mob/living/M in D)
			if (M.client)
				to_chat(M, SPAN_DANGER("The [name] is about to move over you. Get clear!"))
	return path_markers.len

/datum/craft/proc/schedule_path_warning()
	if (warn_timer)
		deltimer(warn_timer)
	warn_timer = addtimer(CALLBACK(src, PROC_REF(warn_tick)), max(1, sail_interval() - VESSEL_PATH_WARNING), TIMER_STOPPABLE)

/datum/craft/proc/warn_tick()
	warn_timer = 0
	if (persistence_save_in_progress || turning_to)
		return 0
	var/refusal_was = last_refusal
	var/list/hop = next_hop()
	last_refusal = refusal_was
	if (!hop)
		return 0
	return mark_path(hop[1], hop[2], body.heading())

// The hop timer: one hop, then the warning for the next.
/datum/craft/proc/sail_tick()
	. = sail_hop()
	if (hop_timer)
		schedule_path_warning()

// One hop along the heading. TRUE when she moved.
/datum/craft/proc/sail_hop()
	if (!body || !body.placed() || anchored || speed <= 0 || turning_to)
		return FALSE
	if (persistence_save_in_progress)
		return FALSE
	// A mast lost since the last hop slows her at once.
	fit_drives()
	if (speed > max_speed())
		speed = max_speed()
		crew_message(SPAN_WARNING("She loses way: [drives_text()]"))
	show_drives()
	var/list/hop = next_hop()
	clear_path()
	if (hop)
		body.glide_time = glides() ? sail_interval() : 0
		var/moved = body.move_to(hop[1], hop[2], body.heading())
		body.glide_time = 0
		if (moved)
			// Her drives pay once for the water a hop would have covered.
			tiles_since_burn += sail_tiles()
			if (tiles_since_burn >= speed * VESSEL_TILES_PER_STEP)
				tiles_since_burn = 0
				burn_drives()
			return TRUE
	if (hop)
		last_refusal = body.last_refusal
	crew_message(SPAN_WARNING("<b>All stop!</b> [capitalize(last_refusal)]."))
	speed = VESSEL_SPEED_STOP
	stop_sailing()
	show_drives()
	return FALSE

// A turn ordered at the helm: the swing is marked and she comes about
// VESSEL_PATH_WARNING later. FALSE with last_refusal set when she cannot.
/datum/craft/proc/order_turn(heading)
	if (!body || !body.placed())
		last_refusal = "she is not afloat"
		return FALSE
	if (turning_to)
		last_refusal = "she is already coming about"
		return FALSE
	if (heading == body.heading())
		return TRUE
	var/list/box = turn_corner(heading)
	if (!box || !body.can_move_to(box[1], box[2], heading))
		last_refusal = body.last_refusal
		return FALSE
	mark_path(box[1], box[2], heading)
	turning_to = heading
	addtimer(CALLBACK(src, PROC_REF(finish_turn)), VESSEL_PATH_WARNING)
	return TRUE

// Where a turn puts the box corner: list(x, y). Bodies turn about their own
// pivot, so the body is asked.
/datum/craft/proc/turn_corner(heading)
	return body ? body.turn_corner(heading) : null

/datum/craft_body/proc/turn_corner(heading)
	return null

/datum/craft_body/built/turn_corner(heading)
	var/list/B = box(turned_offsets(heading))
	return list(px + B[1], py + B[2])

/datum/craft/proc/finish_turn()
	var/heading = turning_to
	turning_to = 0
	if (!heading)
		return FALSE
	if (!body || !body.placed() || anchored)
		clear_path()
		return FALSE
	clear_path()
	. = body.turn_to(heading)
	if (!.)
		last_refusal = body.last_refusal
		crew_message(SPAN_WARNING("She cannot come about: [last_refusal]."))
