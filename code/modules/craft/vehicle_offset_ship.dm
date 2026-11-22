// ============================================================
// Vehicle offsets: frame ships (docs/vehicle-offset.md)
// ------------------------------------------------------------
// A ship built from frames in a workshop sails by pixels while a player is
// near, the way cars roll (vehicle_offset_frame.dm): every tick her frames,
// masts, crew and cargo move by the same few pixels the way she heads, and her
// tile step (do_move) runs only when the offset passes half a tile. Before she
// starts to overlap the water ahead, the checks her tile loop made before each
// step run once: the wind and her sails (check_sails), then do_vehicle_check
// (anchor, open water, grace walls, mines, what she runs down). After each tile
// step her degaussing coil and the naval mines near her are checked, as before.
//
// A turn ordered between squares is held until she reaches the next square,
// so she comes about without a jump back. Out of gear she drifts on, slowing,
// to the next square. With nobody near, or during a save, she squares on her
// tiles and the tile loop in ships/axis.dm takes over again.
// ============================================================

/obj/structure/vehicleparts/axis/ship
	offset_drive = TRUE
	var/tmp/offset_turn = null         // "left" or "right": a turn held for the next square.
	var/tmp/mob/offset_turn_by = null  // Who ordered it.

/obj/structure/vehicleparts/axis/ship/persistence_runtime_var(key)
	return key == "offset_turn" || key == "offset_turn_by" || ..()

// Her movement loop while she sails by pixels. TRUE when it has handled the
// loop; FALSE hands it to the tile loop.
/obj/structure/vehicleparts/axis/ship/proc/ship_offset_movementloop()
	if (!offset_drive || movement_processes || !(moving || offset_coast > 0))
		return FALSE
	if (!vehicle_offset_drives())
		vehicle_offset_settle()
		ship_offset_turn_now()
		if (!moving)
			offset_coast = 0
			return TRUE
		return FALSE
	// The tile loop's glides are not used while she sails by pixels.
	if (glide_was && glide_was.len)
		glide_give_back(glide_was, null)
	// Under sail the wind sets her gear and pace before she gets under way.
	if (moving && masts.len && currentspeed <= 0)
		get_weight()
		check_sails()
		if (!moving)
			vehicle_offset_settle()
			return TRUE
	movement_processes++
	var/delay = vehicle_offset_tick()
	if (offset_turn && !vehicle_offset_to_square())
		ship_offset_turn_now()
	if (!delay || QDELETED(src))
		movement_processes--
		return TRUE
	addtimer(CALLBACK(src, PROC_REF(vehicle_offset_next)), delay)
	return TRUE

// She rolls no further than the next square while a turn is held.
/obj/structure/vehicleparts/axis/ship/vehicle_offset_hold()
	return offset_turn ? TRUE : FALSE

// What her tile loop checked before each step: her load, the wind and her
// sails. She stops as she did on whole tiles, nobody thrown off.
/obj/structure/vehicleparts/axis/ship/vehicle_offset_tile_ahead()
	offset_quiet_stop = TRUE
	if (!moving)
		return TRUE
	get_weight()
	if (masts.len)
		check_sails()
		if (!moving)
			return FALSE
	for (var/obj/structure/vehicleparts/movement/sail/S in masts)
		if (!S.sails || S.broken)
			moving = FALSE
			stopmovementloop()
			return FALSE
		S.update_icon()
	return TRUE

// After a tile step: her wiping and degaussing coil (naval/degaussing.dm),
// then the mines near the water she just crossed (naval/naval_mines.dm).
/obj/structure/vehicleparts/axis/ship/vehicle_offset_stepped()
	..()
	if (craft || naval_mines.len)
		var/datum/craft/MC = craft_of_axis(src)
		if (MC)
			MC.magnetic_moved(1)
			if (naval_mines.len && !QDELETED(src))
				MC.check_naval_mines()

// A turn ordered while she is between squares waits for the next square.
/obj/structure/vehicleparts/axis/ship/do_matrix(var/olddir = 0, var/newdir = 0, var/tdir = "none", var/mob/user = null)
	if ((tdir == "left" || tdir == "right") && !transforming_vehicle && offset_mover && (offset_mover.ox || offset_mover.oy) && (moving || offset_coast > 0) && vehicle_offset_drives())
		offset_turn = tdir
		offset_turn_by = user
		return TRUE
	offset_turn = null
	offset_turn_by = null
	return ..()

// Makes the held turn, now that she is square (or back on whole tiles).
/obj/structure/vehicleparts/axis/ship/proc/ship_offset_turn_now()
	if (!offset_turn)
		return FALSE
	var/tdir = offset_turn
	var/mob/user = offset_turn_by
	offset_turn = null
	offset_turn_by = null
	if (QDELETED(user))
		user = null
	return do_matrix(dir, tdir == "left" ? TURN_LEFT(dir) : TURN_RIGHT(dir), tdir, user)
