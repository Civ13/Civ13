// Vehicle controls for agent characters (docs/agent-control.md#vehicles).
//
// Players drive cars, tanks and aircraft from the driver's seat HUD (turn,
// gear up and down, forward and reverse, climb and descend) and with the
// arrow keys, which also turn a held steering wheel, aim a held turret control
// and fly a drone. An agent character has no HUD or keyboard: the drive action
// presses the same HUD buttons, and move applies the arrow-key extras before
// walking. tests/agent_control (VehicleParityTests) pins the client lines.

// The modular vehicle axis behind the driver's seat the character sits in, or null.
/proc/agent_driven_axis(mob/living/M)
	if (!M || !istype(M.buckled, /obj/structure/bed/chair/drivers))
		return null
	var/obj/structure/bed/chair/drivers/D = M.buckled
	if (!istype(D.axis, /obj/structure/vehicleparts/axis))
		return null
	return D.axis

// What a player reads off the vehicle HUD: gear, direction, engine and height.
/proc/agent_driving_row(mob/living/M)
	var/obj/structure/vehicleparts/axis/V = agent_driven_axis(M)
	if (!V)
		return null
	var/list/row = list("ref" = agent_ref(V), "name" = V.name, "gear" = V.currentspeed, "gears" = V.speeds)
	row["reverse"] = V.reverse ? TRUE : FALSE
	row["moving"] = V.moving ? TRUE : FALSE
	row["dir"] = dir2text(V.dir)
	row["engine"] = V.engine ? (V.engine.on ? "on" : "off") : "none"
	if (V.engine && V.engine.fueltank && V.engine.fueltank.reagents)
		row["fuel"] = round(V.engine.fueltank.reagents.total_volume, 0.1)
	row["key_ok"] = V.key_access(M) ? TRUE : FALSE
	if (istype(V, /obj/structure/vehicleparts/axis/aircraft))
		var/obj/structure/vehicleparts/axis/aircraft/P = V
		switch (P.flight_state)
			if (AIRCRAFT_LOW)
				row["flight"] = "low"
			if (AIRCRAFT_CRUISE)
				row["flight"] = "high"
			else
				row["flight"] = "ground"
		row["altitude"] = P.altitude
		row["target_altitude"] = P.target_altitude
	return row

// Turret and drone controls the character holds, as the arrow keys would steer them.
/proc/agent_remote_rows(mob/living/M)
	. = list()
	for (var/obj/item/turret_controls/TC in M)
		if (TC.turret)
			. += list(list("control" = "turret", "ref" = agent_ref(TC.turret), "name" = TC.turret.name, "azimuth" = TC.turret.azimuth, "target_azimuth" = TC.turret.azimuth_to_target, "distance" = TC.turret.distance))
	for (var/obj/item/drone_controller/RC in M)
		var/list/row = list("control" = "drone", "active" = M.using_drone == RC ? TRUE : FALSE)
		if (RC.connected_drone)
			var/obj/structure/drone/DR = RC.connected_drone
			row["ref"] = agent_ref(DR)
			row["name"] = DR.name
			row["x"] = DR.x
			row["y"] = DR.y
			row["z"] = DR.z
			row["broken"] = DR.broken ? TRUE : FALSE
			if (DR.can_fly)
				row["flying"] = DR.flying ? TRUE : FALSE
		. += list(row)

// The arrow-key extras of /client/verb/startmoving* for one cardinal key: a
// held steering wheel turns (east, west) or picks forward/reverse while
// stopped (north, south), turret controls change range (north, south) or turn
// (east, west), and an active drone moves. hold is how long the key stays
// down for turrets and drones before the matching stopmoving* releases it.
/proc/agent_arrow_key(mob/living/human/H, d, hold)
	. = list()
	for (var/obj/item/vehicleparts/wheel/modular/MW in H)
		var/obj/structure/vehicleparts/axis/V = MW.control ? MW.control.axis : null
		switch (d)
			if (NORTH)
				if (V && V.reverse && V.currentspeed == 0 && !V.moving)
					to_chat(H, "You switch into forward.")
					playsound(H.loc, 'sound/effects/lever.ogg', 65, TRUE)
					V.reverse = FALSE
					. += "forward"
			if (SOUTH)
				if (V && !V.reverse && V.currentspeed == 0 && !V.moving)
					to_chat(H, "You switch into reverse.")
					playsound(H.loc, 'sound/effects/lever.ogg', 65, TRUE)
					V.reverse = TRUE
					. += "reverse"
			if (EAST)
				if (MW.turndir(H, "right"))
					. += "turned right"
			if (WEST)
				if (MW.turndir(H, "left"))
					. += "turned left"
	for (var/obj/item/turret_controls/TC in H)
		switch (d)
			if (NORTH)
				TC.increase_distance(1)
				. += "turret range up"
			if (SOUTH)
				TC.increase_distance(-1)
				. += "turret range down"
			if (EAST, WEST)
				var/turn = d == EAST ? 1 : -1
				if (!TC.is_rotating)
					TC.start_rotation(turn)
					. += "turret turning [d == EAST ? "right" : "left"]"
					spawn(hold)
						if (TC && TC.rotating_dir == turn)
							TC.stop_rotation()
				else if (TC.rotating_dir == -turn)
					TC.stop_rotation()
					. += "turret stopped"
	for (var/obj/item/drone_controller/RC in H)
		if (H.using_drone)
			RC.start_move_drone(d)
			. += "drone [dir2text(d)]"
			spawn(hold)
				if (RC && RC.moving_dir == d)
					RC.stop_move_drone()

// Whether a held control answers the arrow keys at all.
/proc/agent_holds_arrow_controls(mob/living/M)
	if (!ishuman(M))
		return FALSE
	if (locate(/obj/item/vehicleparts/wheel/modular) in M)
		return TRUE
	if (locate(/obj/item/turret_controls) in M)
		return TRUE
	return M.using_drone ? TRUE : FALSE

// One move step's arrow-key extras: a diagonal presses both of its keys.
/proc/agent_arrow_keys(mob/living/human/H, d, hold)
	. = list()
	var/list/keys = (d in cornerdirs) ? list(d & (NORTH|SOUTH), d & (EAST|WEST)) : list(d)
	for (var/key in keys)
		. += agent_arrow_key(H, key, hold)

// The driver's seat HUD buttons (hud_vehicles.dm, hud_aircraft.dm).
/datum/agent_control/proc/agent_drive(datum/agent_character/C, list/req)
	var/mob/living/M = C.body
	if (M.stat != CONSCIOUS)
		agent_fail("cannot_act", "the character is not conscious")
	if (!ishuman(M))
		agent_fail("bad_type", "only humans drive")
	var/mob/living/human/H = M
	var/control = lowertext("[req["control"]]")
	var/obj/structure/vehicleparts/axis/V = agent_driven_axis(H)
	if (!V)
		agent_fail("not_driving", "sit in a driver's seat first (drag yourself onto it)")
	var/obj/structure/bed/chair/drivers/D = H.buckled
	switch (control)
		if ("forward", "reverse")
			// The direction button flips forward and reverse whatever the speed.
			var/want = control == "reverse"
			if (V.reverse != want)
				to_chat(H, want ? "You switch into reverse." : "You switch into forward.")
				playsound(H.loc, 'sound/effects/lever.ogg', 65, TRUE)
				V.reverse = want
		if ("turn_left", "turn_right")
			if (!D.wheel)
				agent_fail("no_wheel", "this seat has no steering wheel")
			if (!D.wheel.turndir(H, control == "turn_left" ? "left" : "right"))
				agent_fail("cannot_turn", "the vehicle cannot turn now: it must be moving, keyed to you, clear of obstacles and past its turn delay")
		if ("gear_up")
			if (!D.wheel)
				agent_fail("no_wheel", "this seat has no steering wheel")
			D.wheel.attack_self(H)
		if ("gear_down")
			if (!D.wheel)
				agent_fail("no_wheel", "this seat has no steering wheel")
			D.wheel.secondary_attack_self(H)
		if ("climb", "descend")
			var/obj/structure/vehicleparts/axis/aircraft/P = V
			if (!istype(P))
				agent_fail("bad_type", "only aircraft climb and descend")
			if (!P.key_access(H))
				agent_fail("no_key", "a matching vehicle key is required")
			var/done = control == "climb" ? P.climb(H) : P.descend(H)
			if (!done)
				agent_fail("cannot_[control]", control == "climb" ? P.takeoff_hint() : "the aircraft cannot descend here")
		else
			agent_fail("bad_args", "control must be forward, reverse, turn_left, turn_right, gear_up, gear_down, climb or descend")
	C.next_action = world.time + 2
	return "[control] ([V.name])"
