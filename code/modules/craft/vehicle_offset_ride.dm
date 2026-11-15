// ============================================================
// Vehicle offsets, Phase 1: one-object vehicles (docs/vehicle-offset.md)
// ------------------------------------------------------------
// Motorcycles and engine or sail boats roll by pixels while a player is near:
// every tick the vehicle and everyone on it move by the same few pixels in
// the driver's direction, and the vehicle's own tile step (do_move) runs only
// when it passes half a tile. Turning keeps the sideways offset, so it can
// stand anywhere, like a player. Letting off the throttle rolls it to a stop
// within about half a tile. With nobody near, or once a save starts, the next
// tick drops the offset and it steps whole tiles as before.
//
// The tile loop in transports.dm is left as it is; this overrides
// movementloop() and calls it for the tile steps.
//
// Phase 1b: bicycles pedal by pixels on their own schedule (stamina and
// ground are still paid per tile, in their do_move), and rafts and dugouts
// paddle by pixels while a direction key is held, then drift to a stop.
// ============================================================

/obj/structure/vehicle
	var/offset_drive = FALSE                        // TRUE for the vehicles that roll by pixels.
	var/tmp/datum/vehicle_offset/single/offset_mover = null
	var/tmp/offset_coast = 0                        // Pixels per tick still rolling after the throttle is off.
	var/tmp/offset_last_tick = 0                    // world.time of the last pixel tick.

/obj/structure/vehicle/motorcycle
	offset_drive = TRUE

/obj/structure/vehicle/boat
	offset_drive = TRUE

/obj/structure/vehicle/persistence_runtime_var(key)
	return key == "offset_mover" || key == "offset_coast" || key == "offset_last_tick" || ..()

/obj/structure/vehicle/Destroy()
	if (offset_mover)
		qdel(offset_mover)
		offset_mover = null
	return ..()

// TRUE while this vehicle should roll by pixels right now.
/obj/structure/vehicle/proc/vehicle_offset_drives()
	if (!offset_drive || !driver || !isturf(loc) || persistence_save_in_progress)
		return FALSE
	var/datum/vehicle_offset/single/O = vehicle_offset_mover()
	return O.watched()

/obj/structure/vehicle/proc/vehicle_offset_mover()
	if (!offset_mover)
		offset_mover = new(src)
	return offset_mover

// The vehicle, its riders and the things loaded on it share the offset.
/obj/structure/vehicle/proc/vehicle_offset_sync()
	var/datum/vehicle_offset/single/O = vehicle_offset_mover()
	if (!(src in O.footprint))
		O.carry_at(src, 0, 0, TRUE)
	for (var/atom/movable/A in O.carried)
		if (A != src && !(A in ontop) && !(A in ontop_o))
			O.drop(A, TRUE)
	for (var/atom/movable/A in (ontop | ontop_o))
		if (!(A in O.carried) && A.loc == loc)
			O.carry_at(A)

// Back to whole tiles: square on the tile, nobody carried.
/obj/structure/vehicle/proc/vehicle_offset_release()
	offset_coast = 0
	if (!offset_mover)
		return
	offset_mover.snap()
	for (var/atom/movable/A in offset_mover.carried)
		if (A != src)
			offset_mover.drop(A, TRUE)

// One tick of pixel driving. Returns the delay before the next one.
/obj/structure/vehicle/proc/vehicle_offset_tick()
	vehicle_offset_sync()
	// Timers can fire a little later than one tick: cover the time that really
	// passed, so the pace matches the tile loop. A first tick after a rest is one tick.
	var/ticks = vehicle_offset_ticks()
	if (moving && axis.currentspeed > 0)
		offset_coast = vehicle_offset_speed(vehicle_m_delay + 1)
	else if (offset_coast > 0)
		// Stops within about half a tile at top speed: v*v / 2a = 16 px.
		offset_coast = max(0, offset_coast - max(0.25, offset_coast * offset_coast / 32) * ticks)
	if (!offset_coast || !driver)
		vehicle_offset_roll(0)
		return vehicle_m_delay + 1
	if (vehicle_offset_roll(offset_coast * ticks))
		offset_coast = 0
		axis.currentspeed = 0
	return world.tick_lag

/obj/structure/vehicle/movementloop()
	if (movement_processes || !driver || !(moving || offset_coast > 0))
		return ..()
	if (!axis || !vehicle_offset_drives())
		vehicle_offset_settle()
		return ..()
	movement_processes++
	addtimer(CALLBACK(src, PROC_REF(vehicle_offset_next)), vehicle_offset_tick())

/obj/structure/vehicle/proc/vehicle_offset_next()
	movement_processes--
	// Still in gear, or still rolling after the gear came out.
	if (!QDELETED(src) && (moving || offset_coast > 0))
		movementloop()

// TRUE while a vehicle carries this person: seated or driving, aboard a
// one-object vehicle, or standing on a moving frame vehicle.
// Carried steps make no footstep sounds; the engine has its own.
/mob/living/human/proc/carried_by_vehicle()
	if (buckled || driver || driver_vehicle)
		return TRUE
	var/turf/T = loc
	if (!istype(T))
		return FALSE
	for (var/obj/structure/vehicle/V in T)
		if (src in V.ontop)
			return TRUE
	for (var/obj/structure/vehicleparts/frame/F in T)
		if (F.axis && F.axis.moving && (src in F.axis.transporting))
			return TRUE
	return FALSE

// Drops a leftover offset once the vehicle is back on whole tiles.
/obj/structure/vehicle/proc/vehicle_offset_settle()
	if (offset_mover && (offset_mover.ox || offset_mover.oy || offset_mover.carried.len > 1))
		vehicle_offset_release()

// Pushes the shared offset along the driver's facing at speed px per tick
// (already scaled by the ticks that passed). TRUE if it was stopped.
/obj/structure/vehicle/proc/vehicle_offset_roll(speed)
	var/datum/vehicle_offset/single/O = vehicle_offset_mover()
	if (!speed || !driver)
		O.speed_x = 0
		O.speed_y = 0
		return FALSE
	var/d = driver.dir
	O.speed_x = (d & EAST) ? speed : ((d & WEST) ? -speed : 0)
	O.speed_y = (d & NORTH) ? speed : ((d & SOUTH) ? -speed : 0)
	O.pulse()
	return O.blocked_dir ? TRUE : FALSE

// Ticks of time since the last pixel tick: 1 to 4, 1 after a rest.
/obj/structure/vehicle/proc/vehicle_offset_ticks()
	var/ticks = (world.time - offset_last_tick) / world.tick_lag
	if (ticks < 1 || ticks > 4)
		ticks = 1
	offset_last_tick = world.time
	return ticks

// ---- Bicycles and running bikes ------------------------------------------
// The pedal loop runs every tick while someone is near; do_move still pays
// stamina and reads the ground once per tile, when the offset crosses half a
// tile, and sets the pace (vehicle_m_delay) for the tile after it.

/obj/structure/vehicle/bicycle
	offset_drive = TRUE

// Pedal airships fly: aircraft come later (docs/vehicle-offset.md).
/obj/structure/vehicle/bicycle/airship
	offset_drive = FALSE

/obj/structure/vehicle/bicycle/movementloop()
	if (!moving || !vehicle_offset_drives())
		vehicle_offset_settle()
		return ..()
	pedal_timer = null
	if (pedal_busy || !rider_ready())
		stopmovementloop()
		return
	pedal_busy = TRUE
	var/blocked = FALSE
	try
		vehicle_offset_sync()
		var/ticks = vehicle_offset_ticks()
		// The tile step inside the roll keeps its own schedule; the pixels are the pace now.
		pedal_next_move = world.time
		blocked = vehicle_offset_roll(vehicle_offset_speed(vehicle_m_delay) * ticks)
	catch (var/exception/E)
		pedal_busy = FALSE
		stopmovementloop()
		throw E
	pedal_busy = FALSE
	if (blocked || !moving)
		stopmovementloop()
		return
	pedal_timer = addtimer(CALLBACK(src, PROC_REF(movementloop)), world.tick_lag, TIMER_STOPPABLE)

// ---- Rafts and dugout canoes ---------------------------------------------
// Paddled by key: while the driver holds a direction key the raft moves by
// pixels that way; let go and it drifts to a stop within about half a tile.

/obj/structure/vehicle/raft
	offset_drive = TRUE
	var/tmp/offset_paddling = FALSE

/obj/structure/vehicle/raft/persistence_runtime_var(key)
	return key == "offset_paddling" || ..()

// Deciseconds per tile while paddling.
/obj/structure/vehicle/raft/proc/vehicle_offset_paddle_delay()
	return vehicle_m_delay

/obj/structure/vehicle/raft/dugout/vehicle_offset_paddle_delay()
	return paddling() ? paddle_delay : initial(vehicle_m_delay)

// TRUE while the driver holds a key for the way they face.
/obj/structure/vehicle/raft/proc/vehicle_offset_paddle_held()
	if (!driver || driver.stat != CONSCIOUS || driver.incapacitated())
		return FALSE
	var/held = 0
	if (driver.movement_northsouth)
		held |= driver.movement_northsouth
	if (driver.movement_eastwest)
		held |= driver.movement_eastwest
	return (held & driver.dir) ? TRUE : FALSE

/obj/structure/vehicle/raft/processmove(m_dir = null)
	if (!m_dir)
		return
	if (!vehicle_offset_drives())
		vehicle_offset_settle()
		return ..()
	if (!offset_paddling)
		offset_paddling = TRUE
		offset_last_tick = world.time
		vehicle_offset_paddle()

/obj/structure/vehicle/raft/proc/vehicle_offset_paddle()
	if (QDELETED(src) || !offset_paddling)
		return
	if (!vehicle_offset_drives())
		offset_paddling = FALSE
		offset_coast = 0
		vehicle_offset_settle()
		return
	vehicle_offset_sync()
	var/ticks = vehicle_offset_ticks()
	if (vehicle_offset_paddle_held())
		offset_coast = vehicle_offset_speed(vehicle_offset_paddle_delay())
	else if (offset_coast > 0)
		offset_coast = max(0, offset_coast - max(0.25, offset_coast * offset_coast / 32) * ticks)
	if (!offset_coast || vehicle_offset_roll(offset_coast * ticks) || QDELETED(src))
		offset_coast = 0
		offset_paddling = FALSE
		if (offset_mover)
			offset_mover.speed_x = 0
			offset_mover.speed_y = 0
		return
	addtimer(CALLBACK(src, PROC_REF(vehicle_offset_paddle)), world.tick_lag)
