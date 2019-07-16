/* Simple object type, calls a proc when "stepped" on by something */

/obj/effect/step_trigger
	var/affect_ghosts = FALSE
	var/stopper = TRUE // stops throwers
	invisibility = 101 // nope cant see this shit
	anchored = TRUE

/obj/effect/step_trigger/proc/Trigger(var/atom/movable/A)
	return FALSE

/obj/effect/step_trigger/Crossed(H as mob|obj)
	..()
	if (!H)
		return
	if (isobserver(H) && !(isghost(H) && affect_ghosts))
		return
	Trigger(H)



/* Tosses things in a certain direction */

/obj/effect/step_trigger/thrower
	var/direction = SOUTH // the direction of throw
	var/tiles = 3	// if FALSE: forever until atom hits a stopper
	var/immobilize = TRUE // if nonzero: prevents mobs from moving while they're being flung
//	var/speed = TRUE	// delay of movement
	var/facedir = FALSE // if TRUE: atom faces the direction of movement
	var/nostop = FALSE // if TRUE: will only be stopped by teleporters
	var/list/affecting = list()

	Trigger(var/atom/A)
		if (!A || !istype(A, /atom/movable))
			return
		var/atom/movable/AM = A
		var/curtiles = FALSE
		var/stopthrow = FALSE
		for (var/obj/effect/step_trigger/thrower/T in orange(2, src))
			if (AM in T.affecting)
				return

		if (ismob(AM))
			var/mob/M = AM
			if (immobilize)
				M.canmove = FALSE

		affecting.Add(AM)
		while (AM && !stopthrow)
			if (tiles)
				if (curtiles >= tiles)
					break
			if (AM.z != z)
				break

			curtiles++

			sleep(speed)

			// Calculate if we should stop the process
			if (!nostop)
				for (var/obj/effect/step_trigger/T in get_step(AM, direction))
					if (T.stopper && T != src)
						stopthrow = TRUE
			else
				for (var/obj/effect/step_trigger/teleporter/T in get_step(AM, direction))
					if (T.stopper)
						stopthrow = TRUE

			if (AM)
				var/predir = AM.dir
				step(AM, direction)
				if (!facedir)
					AM.set_dir(predir)



		affecting.Remove(AM)

		if (ismob(AM))
			var/mob/M = AM
			if (immobilize)
				M.canmove = TRUE

/* Stops things thrown by a thrower, doesn't do anything */

/obj/effect/step_trigger/stopper

/* Instant teleporter */

/obj/effect/step_trigger/teleporter
	var/teleport_x = FALSE	// teleportation coordinates (if one is null, then no teleport!)
	var/teleport_y = FALSE
	var/teleport_z = FALSE

	Trigger(var/atom/movable/A)
		if (teleport_x && teleport_y && teleport_z)

			A.x = teleport_x
			A.y = teleport_y
			A.z = teleport_z

/* Random teleporter, teleports atoms to locations ranging from teleport_x - teleport_x_offset, etc */

/obj/effect/step_trigger/teleporter/random
	var/teleport_x_offset = FALSE
	var/teleport_y_offset = FALSE
	var/teleport_z_offset = FALSE

	Trigger(var/atom/movable/A)
		if (teleport_x && teleport_y && teleport_z)
			if (teleport_x_offset && teleport_y_offset && teleport_z_offset)

				A.x = rand(teleport_x, teleport_x_offset)
				A.y = rand(teleport_y, teleport_y_offset)
				A.z = rand(teleport_z, teleport_z_offset)

//////////////////////////////////////TELEPORTER///////////////////////////////////////////
/obj/effect/step_trigger/teleporter/stairs
	var/teleport_x_offset = FALSE
	var/teleport_y_offset = FALSE
	var/teleport_z_offset = FALSE
	var/up = FALSE
	var/timer = 0

	Trigger(var/atom/movable/A)
		spawn(timer)
			if (teleport_x && teleport_y && teleport_z)
				if (teleport_x_offset)
					A.x = rand(teleport_x, teleport_x_offset)
				else
					A.x = teleport_x

				if (teleport_y_offset)
					A.y = rand(teleport_y, teleport_y_offset)
				else
					A.y = teleport_y

				if (teleport_z_offset)
					A.z = rand(teleport_z, teleport_z_offset)
				else
					A.z = teleport_z
/////////////////////////////////////////////////////////////////////////////////////////////

/* Step trigger to display message if *TRIGGERED* */
/obj/effect/step_trigger/message
	var/message	//the message to give to the mob
	var/once = TRUE

/obj/effect/step_trigger/message/Trigger(mob/M as mob)
	if (M.client)
		M << "<span class='info'>[message]</span>"
		if (once)
			qdel(src)