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
	if (!offset_drive || !driver || !axis || !isturf(loc) || persistence_save_in_progress)
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
	var/datum/vehicle_offset/single/O = vehicle_offset_mover()
	vehicle_offset_sync()
	// Timers can fire a little later than one tick: cover the time that really
	// passed, so the pace matches the tile loop. A first tick after a rest is one tick.
	var/ticks = (world.time - offset_last_tick) / world.tick_lag
	if (ticks < 1 || ticks > 4)
		ticks = 1
	offset_last_tick = world.time
	var/speed = 0
	if (moving && axis.currentspeed > 0)
		offset_coast = vehicle_offset_speed(vehicle_m_delay + 1)
		speed = offset_coast * ticks
	else if (offset_coast > 0)
		// Stops within about half a tile at top speed: v*v / 2a = 16 px.
		offset_coast = max(0, offset_coast - max(0.25, offset_coast * offset_coast / 32) * ticks)
		speed = offset_coast * ticks
	if (!speed || !driver)
		O.speed_x = 0
		O.speed_y = 0
		return vehicle_m_delay + 1
	var/d = driver.dir
	O.speed_x = (d & EAST) ? speed : ((d & WEST) ? -speed : 0)
	O.speed_y = (d & NORTH) ? speed : ((d & SOUTH) ? -speed : 0)
	O.pulse()
	if (O.blocked_dir)
		offset_coast = 0
		axis.currentspeed = 0
	return world.tick_lag

/obj/structure/vehicle/movementloop()
	if (movement_processes || !driver || !(moving || offset_coast > 0))
		return ..()
	if (!vehicle_offset_drives())
		if (offset_mover && (offset_mover.ox || offset_mover.oy || offset_mover.carried.len > 1))
			vehicle_offset_release()
		return ..()
	movement_processes++
	addtimer(CALLBACK(src, PROC_REF(vehicle_offset_next)), vehicle_offset_tick())

/obj/structure/vehicle/proc/vehicle_offset_next()
	movement_processes--
	// Still in gear, or still rolling after the gear came out.
	if (!QDELETED(src) && (moving || offset_coast > 0))
		movementloop()
