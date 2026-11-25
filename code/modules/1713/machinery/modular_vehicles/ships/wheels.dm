////////////WIP ship wheel////////////////////
/obj/structure/vehicleparts/shipwheel
	name = "ship wheel"
	icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	icon_state = "ship_wheel"
	layer = 2.99
	var/obj/structure/vehicleparts/axis/ship = null
	var/spamtimer = 0
	var/lastdirchange = 0
	var/sails_on = FALSE
	var/mob/living/user = null
	var/reversed = FALSE

/obj/structure/vehicleparts/shipwheel/proc/do_html(var/mob/m)
	if (m && ship)
		ui_interact(m)

/obj/structure/vehicleparts/shipwheel/ui_actions(ui_key)
	return list("set_anchor", "set_sails", "set_heading_left", "set_heading_right", "set_reversed", "set_engine", "increase_speed", "decrease_speed")

// The helm: heading and anchor always, sails with masts, engine and speed with an engine.
/obj/structure/vehicleparts/shipwheel/ui_interact(mob/viewer, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE)
	if (!ship)
		GLOB.nanomanager.close_user_uis(viewer, src)
		return
	var/list/rows = list(
		panel_row("Heading", "[dir2text(ship.dir)][reversed ? " (reversed)" : ""]", buttons = list(panel_button("Turn left", "set_heading_left"), panel_button("Reverse", "set_reversed", selected = reversed), panel_button("Turn right", "set_heading_right"))),
		panel_row("Anchor", ship.anchor ? "Anchored" : "Lifted", buttons = list(panel_button(ship.anchor ? "Lift" : "Drop", "set_anchor"))))
	if (ship.masts.len >= 1)
		rows += list(panel_row("Sails", sails_on ? "Hoisted" : "Retracted", buttons = list(panel_button(sails_on ? "Retract" : "Hoist", "set_sails"))))
	if (ship.engine)
		rows += list(panel_row("Engine", ship.engine.on ? "On" : "Off", ship.engine.on ? "good" : "muted", list(panel_button(ship.engine.on ? "Turn off" : "Turn on", "set_engine"))))
		rows += list(panel_row("Speed", speed2text(), buttons = list(panel_button("Decrease", "decrease_speed"), panel_button("Increase", "increase_speed"))))
	open_panel(viewer, name, 520, 400, list(panel_section("Helm", rows = rows)), ui = ui, force_open = force_open)

/obj/structure/vehicleparts/shipwheel/interact(var/mob/m)
	if (user)
		if (get_dist(src, user) > 1)
			user = null
	if (!anchored)
		to_chat(user, "<span class = 'danger'>You need to fix it to the floor before using.</span>")
		user = null
	if (user && user != m)
		if (user.client)
			return
		else
			user = null
	else
		user = m
		do_html(user)

/obj/structure/vehicleparts/shipwheel/Topic(href, href_list, hsrc)

	var/mob/user = usr

	if (!user || user.lying)
		return

	user.face_atom(src)

	if (!locate(user) in range(1,src))
		to_chat(user, "<span class = 'danger'>Get behind the wheel to use it.</span>")
		return FALSE

	if (!user.can_use_hands())
		to_chat(user, "<span class = 'danger'>You have no hands to use this with.</span>")
		return FALSE

	if (!anchored)
		to_chat(user, "<span class = 'danger'>You need to fix it to the floor before using.</span>")
		return FALSE

	if (href_list["set_anchor"])
		if (ship)
			ship.anchor = !ship.anchor
			if (ship.anchor)
				visible_message("<b>[ship]</b>'s anchor is dropped!")
				ship.moving = FALSE
				ship.stopmovementloop()
			else
				visible_message("<b>[ship]'s</b> anchor is raised!")
				ship.moving = TRUE
				ship.add_transporting()
				ship.startmovementloop()
			spamtimer = world.time + 20
	if (href_list["set_sails"])
		if (ship && ship.masts.len)
			if (world.time <= spamtimer)
				to_chat(user, SPAN_NOTICE("Wait a moment before adjusting the sails."))
				return FALSE
			var/next_sails = !sails_on
			for (var/obj/structure/vehicleparts/movement/sail/M in ship.masts)
				M.sails_on = next_sails
				M.update_icon()
			sails_on = next_sails
			spamtimer = world.time + 20
			if (next_sails)
				to_chat(user, "You hoist the sails on the [ship].")
			else
				to_chat(user, "You retract the sails on the [ship].")

	if (href_list["set_heading_left"])
		if (turndir(user,"left"))
			to_chat(user, "You turn the ship to the left.")
			spamtimer = world.time + 20
	if (href_list["set_heading_right"])
		if (turndir(user,"right"))
			to_chat(user, "You turn the ship to the right.")
			spamtimer = world.time + 20
	if (href_list["set_reversed"])
		if (!reversed)
			to_chat(user, "You reverse the [ship].")
			spamtimer = world.time + 20
			reversed = TRUE
			ship.reverse = TRUE
		else
			to_chat(user, "You return the [ship] to the heading.")
			spamtimer = world.time + 20
			reversed = FALSE
			ship.reverse = FALSE
		return
//engine stuff
	if (href_list["set_engine"])
		if (!ship || !ship.engine)
			return
		else
			if (ship.engine.on)
				playsound(ship.engine.loc, ship.engine.ending_snd, 100, FALSE, 3)
				ship.engine.on = FALSE
				ship.engine.power_off_connections()
				ship.engine.currentspeed = 0
				ship.engine.currentpower = 0
				ship.engine.update_icon()
			else
				ship.engine.turn_on(user)

		return

	if (href_list["increase_speed"])
		if (!ship || !ship.engine)
			return
		if (ship.currentspeed < 0)
			ship.currentspeed = 0
		ship.currentspeed++
		if (ship.currentspeed>ship.speeds)
			ship.currentspeed = ship.speeds

		else
			var/spd = ship.get_speed()
			ship.vehicle_m_delay = spd
			if (spd <= 0)
				return
			var/ahead = "ahead"
			if (reversed)
				ahead = "astern"
			if (ship.currentspeed == 1)
				ship.moving = TRUE
				to_chat(user, "You set the speed to <b>slow [ahead]</b>.")
				playsound(loc, 'sound/effects/lever.ogg',40, TRUE)
				ship.vehicle_m_delay = spd
				ship.add_transporting()
				ship.startmovementloop()
			else if (ship.currentspeed == 2)
				to_chat(user, "You change the speed to <b>half-speed [ahead]</b>.")
				playsound(loc, 'sound/effects/lever.ogg',40, TRUE)
				ship.vehicle_m_delay = spd
				return
			else if (ship.currentspeed == 3)
				to_chat(user, "You change the speed to <b>full-speed [ahead]</b>.")
				playsound(loc, 'sound/effects/lever.ogg',40, TRUE)
				ship.vehicle_m_delay = spd
				return
			else
				return

	if (href_list["decrease_speed"])
		if (!ship || !ship.engine)
			return
		if (ship && ship.engine && ship.currentspeed <= 0)
			if (ship.engine.on)
				to_chat(user, "You turn off the [ship.engine].")
				ship.engine.on = FALSE
				ship.moving = FALSE
				ship.currentspeed = 0
				ship.engine.update_icon()
				return
			return
		else
			ship.currentspeed--
			var/spd = ship.get_speed()
			if (spd <= 0 || ship.currentspeed == 0)
				ship.moving = FALSE
				to_chat(user, "You stop the ship.")
				for (var/obj/structure/vehicleparts/movement/W in ship.wheels)
					W.update_icon()
				return
			else
				var/ahead = "ahead"
				if (reversed)
					ahead = "astern"
				if (ship.currentspeed == 1)
					ship.moving = TRUE
					to_chat(user, "You set the speed to <b>slow [ahead]</b>.")
					playsound(loc, 'sound/effects/lever.ogg',40, TRUE)
					ship.vehicle_m_delay = spd
					ship.add_transporting()
					ship.startmovementloop()
				else if (ship.currentspeed == 2)
					to_chat(user, "You change the speed to <b>half-speed [ahead]</b>.")
					playsound(loc, 'sound/effects/lever.ogg',40, TRUE)
					ship.vehicle_m_delay = spd
					return
				else if (ship.currentspeed == 3)
					to_chat(user, "You change the speed to <b>full-speed [ahead]</b>.")
					playsound(loc, 'sound/effects/lever.ogg',40, TRUE)
					ship.vehicle_m_delay = spd
					return
				else
					return


	sleep(0.5)
	do_html(user)

/obj/structure/vehicleparts/shipwheel/proc/speed2text()
	if (!ship)
		return ""
	if (!ship.engine)
		return "No Engine"
	if (ship.engine && !ship.engine.on)
		return "Engine Off"
	var/ahead = "Ahead"
	if (reversed)
		ahead = "Astern"

	if (ship.currentspeed == 1)
		return "Slow [ahead]"
	else if (ship.currentspeed == 2)
		return "Half-Speed [ahead]"
	else if (ship.currentspeed == 3)
		return "Full-Speed [ahead]"
	else if (ship.currentspeed == 0)
		return "Engine Idle"
	else
		return "Engine Off"
/obj/structure/vehicleparts/shipwheel/proc/turndir(var/mob/living/mob = null, var/newdir = "left")
	if (world.time <= lastdirchange)
		return FALSE
	lastdirchange = world.time+30
	if (!ship)
		return
	if (ship.moving == FALSE || ship.currentspeed == 0)
		return FALSE
	for(var/obj/effect/pseudovehicle/O in ship.components)
		for(var/obj/structure/vehicleparts/frame/VP in O.loc)
			if (VP.axis != ship)
				if (mob)
					to_chat(mob, "<span class='warning'>You can't turn, something is in the way!</span>")
				return FALSE
		for(var/obj/effect/pseudovehicle/PV in O.loc)
			if (PV.link != ship)
				if (mob)
					to_chat(mob, "<span class='warning'>You can't turn, something is in the way!</span>")
				return FALSE
/*
		var/turf/TF = get_turf(O)
		if (!istype(TF, /turf/floor/beach/water) && !istype(TF, /turf/floor/trench/flooded))
			to_chat(mob, "<span class='warning'>You can't turn, the ship will get stuck!</span>")
			return FALSE
*/
	if (newdir == "left")
		return ship.do_matrix(ship.dir,TURN_LEFT(ship.dir), newdir, mob)
	else
		return ship.do_matrix(ship.dir,TURN_RIGHT(ship.dir), newdir, mob)
	return TRUE

/obj/structure/vehicleparts/shipwheel/attack_hand(var/mob/attacker)
	if (!anchored || !ship)
		to_chat(attacker, "<span class = 'warning'>Fix the wheel in place first.</span>")
		return
	else
		interact(attacker)