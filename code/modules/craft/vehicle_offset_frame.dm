// ============================================================
// Vehicle offsets, Phase 2: frame vehicles (docs/vehicle-offset.md)
// ------------------------------------------------------------
// Cars, trucks, buses and tanks roll by pixels while a player is near: every
// tick the frames, the wheels, everything standing on them and the crew move
// by the same few pixels the way the vehicle faces (or backs), and the
// vehicle's own tile step (do_move) runs only when the offset passes half a
// tile. Its crash, mine, run-over and grace wall checks (do_vehicle_check)
// run once per tile, when it starts to overlap the tiles ahead. Out of gear it
// coasts on, slowing, and stops square on its tiles. A turn squares it first.
// With nobody near, or once a save starts, the next tick squares it and the
// tile loop in axis.dm takes over again.
//
// Frame ships sail the same way (vehicle_offset_ship.dm). Aircraft, the axes
// of one-object boats, towing rigs and vehicles with a trailer stay on whole
// tiles.
// ============================================================

// Slowest coast, in pixels per tick, so it always reaches the square it rolls to.
#define VEHICLE_OFFSET_FRAME_CREEP 0.5

/obj/structure/vehicleparts/axis
	var/offset_drive = TRUE                         // TRUE for frame vehicles that roll by pixels.
	var/tmp/datum/vehicle_offset/axis/offset_mover = null
	var/tmp/offset_coast = 0                        // Pixels per tick still rolling out of gear.
	var/tmp/offset_last_tick = 0                    // world.time of the last pixel tick.
	var/tmp/offset_committing = FALSE               // TRUE during the tile step of a pixel roll.
	var/tmp/offset_quiet_stop = FALSE               // TRUE when the last stop was no crash.

/obj/structure/vehicleparts/axis/aircraft
	offset_drive = FALSE

/obj/structure/vehicleparts/axis/boat
	offset_drive = FALSE

// The axes of one-object vehicles: the vehicle rolls, not the axis.
/obj/structure/vehicleparts/axis/bike
	offset_drive = FALSE

/obj/structure/vehicleparts/axis/carriage
	offset_drive = FALSE

/obj/structure/vehicleparts/axis/persistence_runtime_var(key)
	return key == "offset_mover" || key == "offset_coast" || key == "offset_last_tick" || key == "offset_committing" || key == "offset_quiet_stop" || ..()

/obj/structure/vehicleparts/axis/Destroy()
	if (offset_mover)
		qdel(offset_mover)
		offset_mover = null
	return ..()

/obj/structure/vehicleparts/axis/proc/vehicle_offset_mover()
	if (!offset_mover)
		offset_mover = new /datum/vehicle_offset/axis(src)
	return offset_mover

// TRUE when a cargo trailer is hitched behind (it follows a tile at a time).
/obj/structure/vehicleparts/axis/proc/vehicle_offset_has_trailer()
	for (var/obj/structure/closet/crate/rover_trailer/T in rover_trailers)
		if (T.hitch == src)
			return TRUE
	return FALSE

// TRUE while this vehicle should roll by pixels right now.
/obj/structure/vehicleparts/axis/proc/vehicle_offset_drives()
	if (!offset_drive || !isturf(loc) || persistence_save_in_progress || transforming_vehicle)
		return FALSE
	if (tow_out || tow_in || vehicle_offset_has_trailer())
		return FALSE
	var/datum/vehicle_offset/axis/O = vehicle_offset_mover()
	return O.watched()

// The way it rolls: the way it faces, or backwards in reverse.
/obj/structure/vehicleparts/axis/proc/vehicle_offset_heading()
	return reverse ? OPPOSITE_DIR(dir) : dir

// The frames are its body; its wheels, seats, cargo and crew ride on them.
// Someone filed on a frame tile whose centre is off the body as it is drawn
// (just stepped off, or not yet aboard) is left alone, and anything that has
// left the frames is dropped where it is drawn.
/obj/structure/vehicleparts/axis/proc/vehicle_offset_sync()
	var/datum/vehicle_offset/axis/O = vehicle_offset_mover()
	add_transporting(FALSE)
	var/list/aboard = list()
	for (var/atom/movable/C in components)
		if (QDELETED(C) || !isturf(C.loc))
			continue
		aboard[C] = TRUE
		if (!O.carried[C])
			O.carry_at(C, 0, 0, istype(C, /obj/structure/vehicleparts/frame))
	var/list/deck = null
	for (var/atom/movable/M in transporting)
		if (aboard[M])
			continue
		if (O.carried[M])
			aboard[M] = TRUE
			continue
		if (ismob(M))
			var/mob/living/human/H = M
			var/in_step = istype(H) && H.human_subtile_transaction && !H.human_subtile_transaction.cancelled && human_subtile_same(H.human_subtile_transaction.expected, H.human_subtile_snapshot())
			if (M.step_x || M.step_y || O.ox || O.oy)
				if (!deck)
					deck = O.deck_tiles()
				if (!O.file_on_deck(M, deck))
					continue
			O.carry(M)
			if (in_step)
				vehicle_offset_rebase_walks(list(H))
		else if (M.step_x || M.step_y)
			O.carry(M)
		else
			// Put down on the deck: it lies square on its frame.
			O.carry_at(M)
		aboard[M] = TRUE
	for (var/atom/movable/A in O.carried)
		if (!aboard[A])
			O.drop(A, TRUE)
			vehicle_offset_refile(A)

// Back to whole tiles: square on its tiles, nobody carried.
/obj/structure/vehicleparts/axis/proc/vehicle_offset_release()
	offset_coast = 0
	if (!offset_mover)
		return
	offset_mover.snap()
	for (var/atom/movable/A in offset_mover.carried)
		offset_mover.drop(A, TRUE)

// Drops a leftover offset once the vehicle is back on whole tiles.
/obj/structure/vehicleparts/axis/proc/vehicle_offset_settle()
	if (offset_mover && (offset_mover.ox || offset_mover.oy || offset_mover.carried.len))
		vehicle_offset_release()

// Ticks of time since the last pixel tick: 1 to 4, 1 after a rest.
/obj/structure/vehicleparts/axis/proc/vehicle_offset_ticks()
	var/ticks = (world.time - offset_last_tick) / world.tick_lag
	if (ticks < 1 || ticks > 4)
		ticks = 1
	offset_last_tick = world.time
	return ticks

// Pixels still to roll along the heading to stand square on a tile again.
/obj/structure/vehicleparts/axis/proc/vehicle_offset_to_square()
	if (!offset_mover)
		return 0
	var/d = 0
	switch (vehicle_offset_heading())
		if (NORTH)
			d = offset_mover.oy
		if (SOUTH)
			d = -offset_mover.oy
		if (EAST)
			d = offset_mover.ox
		if (WEST)
			d = -offset_mover.ox
	if (!d)
		return 0
	return d < 0 ? -d : VEHICLE_OFFSET_TILE - d

// One tick of pixel driving. Returns the delay before the next one, or 0 when it has stopped.
/obj/structure/vehicleparts/axis/proc/vehicle_offset_tick()
	vehicle_offset_sync()
	var/ticks = vehicle_offset_ticks()
	var/datum/vehicle_offset/axis/O = offset_mover
	var/speed = 0
	if (moving && currentspeed > 0)
		offset_coast = vehicle_offset_speed(vehicle_m_delay + 1)
		speed = offset_coast * ticks
		// Holding for something it does square on its tiles (a ship coming about).
		if (vehicle_offset_hold())
			speed = min(speed, vehicle_offset_to_square())
	else
		var/left = vehicle_offset_to_square()
		if (!left || offset_coast <= 0)
			offset_coast = 0
			vehicle_offset_release()
			return 0
		// Slows the way a rolling vehicle does, and never rolls past the square.
		offset_coast = max(VEHICLE_OFFSET_FRAME_CREEP, offset_coast * (0.85 ** ticks))
		speed = min(offset_coast * ticks, left)
	var/d = vehicle_offset_heading()
	var/speed_before = currentspeed
	offset_quiet_stop = FALSE
	O.speed_x = (d & EAST) ? speed : ((d & WEST) ? -speed : 0)
	O.speed_y = (d & NORTH) ? speed : ((d & SOUTH) ? -speed : 0)
	O.pulse()
	if (O.blocked_dir)
		O.blocked_dir = 0
		// A crash or a stall at speed throws riders off the roof, as on whole tiles.
		if (!offset_quiet_stop && speed_before >= 2)
			deck_jolt(speed_before >= 3 ? 100 : 50, d, "The sudden stop throws you off!")
		offset_coast = 0
		currentspeed = 0
		moving = FALSE
		stopmovementloop()
		vehicle_offset_release()
		return 0
	return world.tick_lag

/obj/structure/vehicleparts/axis/movementloop()
	if (!offset_drive || movement_processes || !(moving || offset_coast > 0))
		return ..()
	if (!vehicle_offset_drives())
		vehicle_offset_settle()
		if (!moving)
			offset_coast = 0
			return
		return ..()
	// The tile loop's glides are not used while it rolls by pixels.
	if (glide_was && glide_was.len)
		glide_give_back(glide_was, null)
	movement_processes++
	var/delay = vehicle_offset_tick()
	if (!delay)
		movement_processes--
		return
	addtimer(CALLBACK(src, PROC_REF(vehicle_offset_next)), delay)

/obj/structure/vehicleparts/axis/proc/vehicle_offset_next()
	movement_processes--
	if (QDELETED(src))
		return
	// Still in gear, or still rolling after the gear came out.
	if (moving || offset_coast > 0)
		movementloop()
	else
		vehicle_offset_settle()

// Stopped from outside (a berth, a stall): no coast left.
/obj/structure/vehicleparts/axis/stopmovementloop()
	offset_coast = 0
	return ..()

// A turn swings it round on whole tiles: it squares first.
/obj/structure/vehicleparts/axis/do_matrix(var/olddir = 0, var/newdir = 0, var/tdir = "none", var/mob/user = null)
	if (offset_mover && !transforming_vehicle)
		var/coast = offset_coast
		vehicle_offset_release()
		offset_coast = coast
	return ..()

// Its tile step under the offset moves only what the offset carries.
/obj/structure/vehicleparts/axis/add_transporting(var/trigger_mines = TRUE)
	. = ..()
	if (offset_committing && offset_mover)
		. = vehicle_offset_filter_transporting()

// Drops from transporting whatever the offset does not carry. Returns the count left.
/obj/structure/vehicleparts/axis/proc/vehicle_offset_filter_transporting()
	if (offset_committing && offset_mover)
		for (var/atom/movable/M in transporting.Copy())
			if (!offset_mover.carried[M])
				transporting -= M
	return transporting.len

// TRUE while it should roll no further than the next square (ships coming about).
/obj/structure/vehicleparts/axis/proc/vehicle_offset_hold()
	return FALSE

// Its own checks for the tiles it starts to overlap, before do_vehicle_check()
// (a ship's sails and the wind). FALSE stops it.
/obj/structure/vehicleparts/axis/proc/vehicle_offset_tile_ahead()
	return TRUE

// Its tile step under the offset is drawn by the offset, not glided.
/obj/structure/vehicleparts/axis/glide_step(list/moved)
	if (offset_committing)
		glide_give_back(glide_was, null)
		return
	return ..()

// After a tile step under the offset: what the tile loop does after its own step.
/obj/structure/vehicleparts/axis/proc/vehicle_offset_stepped()
	for (var/obj/structure/vehicleparts/movement/W in wheels)
		W.update_icon()
	// Boarding or unloading on the way changes the pace (vehicle_load.dm).
	if (moving && uses_load_factor() && currentspeed > 0)
		var/loaded_delay = get_speed()
		if (loaded_delay > 0)
			vehicle_m_delay = loaded_delay

// A player near any part of it: its length is added to the range.
/datum/vehicle_offset/axis/watched()
	if (world.time < watch_checked + VEHICLE_OFFSET_WATCH_RECHECK)
		return watch_cached
	watch_checked = world.time
	watch_cached = FALSE
	var/obj/structure/vehicleparts/axis/A = owner
	var/turf/here = get_turf(A)
	if (here)
		var/range = VEHICLE_OFFSET_WATCH_RANGE + (istype(A) ? A.maxdist : 0)
		for (var/client/C in clients)
			var/turf/there = get_turf(C.mob)
			if (there && there.z == here.z && get_dist(here, there) <= range)
				watch_cached = TRUE
				break
	return watch_cached

// Starting to overlap the tiles ahead: its own rules for them (crashes, mines,
// running people over, deep water, grace walls), then walls and dense things.
// Out of gear with the engine off, it stops square instead.
/datum/vehicle_offset/axis/can_cover(dir)
	var/obj/structure/vehicleparts/axis/A = owner
	if (!istype(A) || QDELETED(A))
		return FALSE
	if (A.offset_drive && dir == A.vehicle_offset_heading() && (A.moving || A.offset_coast > 0))
		if (!A.moving && !(A.engine && A.engine.on))
			A.offset_quiet_stop = TRUE
			return FALSE
		if (!A.vehicle_offset_tile_ahead())
			return FALSE
		if (!A.do_vehicle_check())
			return FALSE
	return ..()

/datum/vehicle_offset/axis/commit(dir)
	var/obj/structure/vehicleparts/axis/A = owner
	if (!istype(A) || QDELETED(A))
		return FALSE
	A.offset_committing = TRUE
	try
		. = ..()
	catch (var/exception/E)
		A.offset_committing = FALSE
		throw E
	A.offset_committing = FALSE
	if (.)
		A.vehicle_offset_stepped()

#undef VEHICLE_OFFSET_FRAME_CREEP
