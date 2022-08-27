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
		if (ship.engine && ship.masts.len<=0)

			m << browse({"

			<br>
			<html>

			<head>
			[common_browser_style]
			</head>

			<body>

			<script language="javascript">

			function set(input) {
			  window.location="byond://?src=\ref[src];action="+input.name+"&value="+input.value;
			}

			</script>

			<center>
			<big><b>[ship] wheel</b></big><br><br>
			</center>
			<font size='3'>
			<i>Current wind: [map.windspeed], from [map.winddirection]</i><br><br>
			Heading: <b>[dir2text(ship.dir)] [reversed ? "(reversed)" : ""]</b>  <a href='?src=\ref[src];set_heading_left=1'>Turn Left</a> <a href='?src=\ref[src];set_reversed=1'>Reverse</a> <a href='?src=\ref[src];set_heading_right=1'>Turn Right</a><br><br>
			Anchor: <a href='?src=\ref[src];set_anchor=1'>[ship.anchor ? "anchored" : "anchor lifted"]</a><br><br>
			Engine: <b><a href='?src=\ref[src];set_engine=1'>[ship.engine.on ? "On" : "Off"]</a></b> - Speed <b>[speed2text()]</b><br><br>
			<a href='?src=\ref[src];decrease_speed=1'>Decrease Speed</a>  <a href='?src=\ref[src];increase_speed=1'>Increase Speed</a><br><br>
			</font>
			</body>
			</html>
			"},  "window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=500x500")
		else if (!ship.engine && ship.masts.len>=1)

			m << browse({"

			<br>
			<html>

			<head>
			[common_browser_style]
			</head>

			<body>

			<script language="javascript">

			function set(input) {
			  window.location="byond://?src=\ref[src];action="+input.name+"&value="+input.value;
			}

			</script>

			<center>
			<big><b>[ship] wheel</b></big><br><br>
			</center>
			<font size='3'>
			<i>Current wind: [map.windspeed], from [map.winddirection]</i><br><br>
			Heading: <b>[dir2text(ship.dir)] [reversed ? "(reversed)" : ""]</b>  <a href='?src=\ref[src];set_heading_left=1'>Turn Left</a> <a href='?src=\ref[src];set_reversed=1'>Reverse</a> <a href='?src=\ref[src];set_heading_right=1'>Turn Right</a><br><br>
			Anchor: <a href='?src=\ref[src];set_anchor=1'>[ship.anchor ? "anchored" : "anchor lifted"]</a><br><br>
			Sails: <a href='?src=\ref[src];set_sails=1'>[sails_on ? "hoisted" : "retracted"]</a><br><br>
			</font>
			</body>
			</html>
			"},  "window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=500x500")
		else if (ship.engine && ship.masts.len>=1)
			m << browse({"

			<br>
			<html>

			<head>
			[common_browser_style]
			</head>

			<body>

			<script language="javascript">

			function set(input) {
			  window.location="byond://?src=\ref[src];action="+input.name+"&value="+input.value;
			}

			</script>

			<center>
			<big><b>[ship] wheel</b></big><br><br>
			</center>
			<font size='3'>
			<i>Current wind: [map.windspeed], from [map.winddirection]</i><br><br>
			Heading: <b>[dir2text(ship.dir)] [reversed ? "(reversed)" : ""]</b>  <a href='?src=\ref[src];set_heading_left=1'>Turn Left</a> <a href='?src=\ref[src];set_reversed=1'>Reverse</a> <a href='?src=\ref[src];set_heading_right=1'>Turn Right</a><br><br>
			Anchor: <a href='?src=\ref[src];set_anchor=1'>[ship.anchor ? "anchored" : "anchor lifted"]</a><br><br>
			Sails: <a href='?src=\ref[src];set_sails=1'>[sails_on ? "hoisted" : "retracted"]</a><br><br>
			Engine: <b><a href='?src=\ref[src];set_engine=1'>[ship.engine.on ? "On" : "Off"]</a></b> - Speed <b>[speed2text()]</b><br><br>
			<a href='?src=\ref[src];decrease_speed=1'>Decrease Speed</a>  <a href='?src=\ref[src];increase_speed=1'>Increase Speed</a><br><br>
			</font>
			</body>
			</html>
			"},  "window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=500x500")
		else
			m << browse({"

			<br>
			<html>

			<head>
			[common_browser_style]
			</head>

			<body>

			<script language="javascript">

			function set(input) {
			  window.location="byond://?src=\ref[src];action="+input.name+"&value="+input.value;
			}

			</script>

			<center>
			<big><b>[ship] wheel</b></big><br><br>
			</center>
			<font size='3'>
			<i>Current wind: [map.windspeed], from [map.winddirection]</i><br><br>
			Heading: <b>[dir2text(ship.dir)] [reversed ? "(reversed)" : ""]</b>  <a href='?src=\ref[src];set_heading_left=1'>Turn Left</a> <a href='?src=\ref[src];set_reversed=1'>Reverse</a> <a href='?src=\ref[src];set_heading_right=1'>Turn Right</a><br><br>
			Anchor: <a href='?src=\ref[src];set_anchor=1'>[ship.anchor ? "anchored" : "anchor lifted"]</a><br><br>
			</font>
			</body>
			</html>
			"},  "window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=500x500")
/obj/structure/vehicleparts/shipwheel/interact(var/mob/m)
	if (user)
		if (get_dist(src, user) > 1)
			user = null
	restart
	if (!anchored)
		user << "<span class = 'danger'>You need to fix it to the floor before using.</span>"
		user = null
	if (user && user != m)
		if (user.client)
			return
		else
			user = null
			goto restart
	else
		user = m
		do_html(user)

/obj/structure/vehicleparts/shipwheel/Topic(href, href_list, hsrc)

	var/mob/user = usr

	if (!user || user.lying)
		return

	user.face_atom(src)

	if (!locate(user) in range(1,src))
		user << "<span class = 'danger'>Get behind the wheel to use it.</span>"
		return FALSE

	if (!user.can_use_hands())
		user << "<span class = 'danger'>You have no hands to use this with.</span>"
		return FALSE

	if (!anchored)
		user << "<span class = 'danger'>You need to fix it to the floor before using.</span>"
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
		if (ship)
			for (var/obj/structure/vehicleparts/movement/sails/M in ship.masts)
				if (world.time > spamtimer)
					if (!sails_on)
						M.sails_on = TRUE
					else
						M.sails_on = FALSE
					M.update_icon()
			if (!sails_on)
				user << "You hoist the sails on the [ship]."
			else
				user << "You retract the sails on the [ship]."
			spamtimer = world.time + 20
			sails_on = !sails_on

	if (href_list["set_heading_left"])
		if (turndir(user,"left"))
			user << "You turn the ship to the left."
			spamtimer = world.time + 20
	if (href_list["set_heading_right"])
		if (turndir(user,"right"))
			user << "You turn the ship to the right."
			spamtimer = world.time + 20
	if (href_list["set_reversed"])
		if (!reversed)
			user << "You reverse the [ship]."
			spamtimer = world.time + 20
			reversed = TRUE
			ship.reverse = TRUE
		else
			user << "You return the [ship] to the heading."
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
				user << "You set the speed to <b>slow [ahead]</b>."
				playsound(loc, 'sound/effects/lever.ogg',40, TRUE)
				ship.vehicle_m_delay = spd
				ship.add_transporting()
				ship.startmovementloop()
			else if (ship.currentspeed == 2)
				user << "You change the speed to <b>half-speed [ahead]</b>."
				playsound(loc, 'sound/effects/lever.ogg',40, TRUE)
				ship.vehicle_m_delay = spd
				return
			else if (ship.currentspeed == 3)
				user << "You change the speed to <b>full-speed [ahead]</b>."
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
				user << "You turn off the [ship.engine]."
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
				user << "You stop the ship."
				for (var/obj/structure/vehicleparts/movement/W in ship.wheels)
					W.update_icon()
				return
			else
				var/ahead = "ahead"
				if (reversed)
					ahead = "astern"
				if (ship.currentspeed == 1)
					ship.moving = TRUE
					user << "You set the speed to <b>slow [ahead]</b>."
					playsound(loc, 'sound/effects/lever.ogg',40, TRUE)
					ship.vehicle_m_delay = spd
					ship.add_transporting()
					ship.startmovementloop()
				else if (ship.currentspeed == 2)
					user << "You change the speed to <b>half-speed [ahead]</b>."
					playsound(loc, 'sound/effects/lever.ogg',40, TRUE)
					ship.vehicle_m_delay = spd
					return
				else if (ship.currentspeed == 3)
					user << "You change the speed to <b>full-speed [ahead]</b>."
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
			if (!VP.axis.ship)
				if (mob)
					mob << "<span class='warning'>You can't turn, something is in the way!</span>"
				return FALSE
		for(var/obj/effect/pseudovehicle/PV in O.loc)
			if (PV.link != ship)
				if (mob)
					mob << "<span class='warning'>You can't turn, something is in the way!</span>"
				return FALSE
/*
		var/turf/TF = get_turf(O)
		if (!istype(TF, /turf/floor/beach/water) && !istype(TF, /turf/floor/trench/flooded))
			mob << "<span class='warning'>You can't turn, the ship will get stuck!</span>"
			return FALSE
*/
	if (newdir == "left")
		ship.do_matrix(dir,TURN_LEFT(ship.dir), newdir)
	else
		ship.do_matrix(dir,TURN_RIGHT(ship.dir), newdir)
	return TRUE

/obj/structure/vehicleparts/shipwheel/attack_hand(var/mob/attacker)
	if (!anchored || !ship)
		attacker << "<span class = 'warning'>Fix the wheel in place first.</span>"
		return
	else
		interact(attacker)