/obj/structure/transport_lever // same icon as the train lever for now
	name = "Landing Craft control"
	icon = 'icons/obj/vehicles/train_lever.dmi'
	icon_state = "lever_none"
	
	anchored = TRUE
	density = TRUE
	
	var/none_state = "lever_none" // Icon for when the transport object is not being used
	var/pushed_state = "lever_pulled" // Icon for when the transport object is used
	var/depart_sound = 'sound/landing_craft.ogg' // Sound for when the transport leaves

	var/position = "docked" // Where the transport is
	var/next_activation = -1;

/obj/structure/transport_lever/attack_hand(var/mob/user as mob)
	if (world.time < next_activation)
		next_activation = world.time + 5 SECONDS
		visible_message("This Landing Craft isn't ready to depart yet.</span>")
		
	else
		next_activation = world.time + 40 SECONDS //to give it time to reach the destination
		for (var/mob/M in range(14, src))
			M.playsound_local(get_turf(M), depart_sound, 100 - get_dist(M, src))

		if (position == "docked")
			visible_message("The Landing Craft is departing!</span>")
			if (icon_state == none_state) // Push lever
				icon_state = pushed_state
			for (var/turf/floor/plating/concrete/T in range(10, src))
				T.opacity = TRUE
				T.density = TRUE
			spawn (5)
				icon_state = none_state // Reset lever
			spawn (200)
				for (var/mob/M in range(5, src))
					if (M.z == 1)
						M.z = 2
					else if (M.z == 2)
						M.z = 1
				for (var/obj/O in range(5, src))
					if (O.z == 1)
						O.z = 2
					else if (O.z == 2)
						O.z = 1
				visible_message("The Landing Craft has arrived.</span>")
				spawn(5)
					for (var/turf/floor/plating/concrete/T in range(10, src))
						T.opacity = FALSE
						T.density = FALSE
				spawn (400)
					if (z == 1)
						visible_message("The Landing Craft is returning!</span>")
						for (var/mob/M in range(14, src))
							M.playsound_local(get_turf(M), 'sound/landing_craft.ogg', 100 - get_dist(M, src))
						for (var/mob/M in range(5, src))
							if (M.z == 1)
								M.z = 2
							else if (M.z == 1)
								M.z = 2
						for (var/obj/O in range(5, src))
							if ((O.anchored == FALSE) || istype(O, /obj/structure/transport_lever))
								if (O.z == 1)
									O.z = 2
								else if (O.z == 1)
									O.z = 2
						z = 2
					spawn(5)
						for (var/turf/floor/plating/concrete/T in range(10, src))
							T.opacity = FALSE
							T.density = FALSE
			position = "launched"

		else if (position == "launched")
			visible_message("The Landing Craft is departing!</span>")
			if (icon_state == none_state)
				icon_state = pushed_state
			for (var/turf/floor/plating/concrete/T in range(10, src))
				T.opacity = TRUE
				T.density = TRUE
			position = "docked"
			spawn (5)
				icon_state = none_state
			spawn (200)
				for (var/mob/M in range(5, src))
					if (M.z == 1)
						M.z = 2
					else if (M.z == 2)
						M.z = 1
				for (var/obj/O in range(5, src))
					if ((O.anchored == FALSE) || istype(O, /obj/structure/transport_lever))
						if (O.z == 1)
							O.z = 2
						else if (O.z == 2)
							O.z = 1
				visible_message("The Landing Craft has arrived.</span>")
				spawn(5)
					for (var/turf/floor/plating/concrete/T in range(10, src))
						T.opacity = FALSE
						T.density = FALSE
				spawn (400)
					if (z == 1)
						visible_message("The Landing Craft is returning!</span>")
						for (var/mob/M in range(14, src))
							M.playsound_local(get_turf(M), 'sound/landing_craft.ogg', 100 - get_dist(M, src))
						for (var/mob/M in range(5, src))
							if (M.z == 1)
								M.z = 2
							else if (M.z == 1)
								M.z = 2
						for (var/obj/O in range(5, src))
							if ((O.anchored == FALSE) || istype(O, /obj/structure/transport_lever))
								if (O.z == 1)
									O.z = 2
								else if (O.z == 1)
									O.z = 2
						z = 2
					spawn(5)
						for (var/turf/floor/plating/concrete/T in range(10, src))
							T.opacity = FALSE
							T.density = FALSE


////////////////////////* Transport Helicopter *////////////////////////

/obj/structure/aircraft_lever
	name = "Aircraft control"
	icon = 'icons/obj/vehicles/train_lever.dmi'
	icon_state = "lever_none"

	anchored = TRUE
	density = TRUE

	var/sound_takeoff = 'sound/landing_craft.ogg'
	var/sound_landing = 'sound/landing_craft.ogg'

	var/knockdown = TRUE //whether shuttle downs non-buckled people when it moves

	var/moving_status = 0 // Not moving
	var/warmup_time = 0
	var/arrive_time = 0	//the time at which the shuttle arrives when long jumping
	
	var/list/shuttle_area //can be both single area type or a list of areas

	var/obj/effect/shuttle_landmark/current_location
	var/obj/effect/shuttle_landmark/transition
	var/next_activation = -1

/obj/structure/aircraft_lever/attack_hand(mob/user)
	..()
	var/list/destinations = list()
	for(var/obj/effect/shuttle_landmark/WP in world)
		destinations += WP

	var/obj/effect/shuttle_landmark/destination = input(user, "Select the destination.") as null|anything in destinations
	if (!destination) return

	long_jump(destination, transition, arrive_time)

/obj/structure/aircraft_lever/proc/attempt_move(var/obj/effect/shuttle_landmark/destination)
	if(current_location == destination)
		return FALSE

		return FALSE
	if(current_location.cannot_depart(src))
		return FALSE
	testing("[src] moving to [destination]. Areas are [english_list(shuttle_area)]")
	var/list/translation = list()
	for(var/area/A in shuttle_area)
		testing("Moving [A]")
		translation += get_turf_translation(get_turf(current_location), get_turf(destination), A.contents)
	shuttle_moved(destination, translation)
	return TRUE

/obj/structure/aircraft_lever/proc/shuttle_moved(var/obj/effect/shuttle_landmark/destination, var/list/turf_translation)

	error("move_shuttle() called for [name] leaving [current_location] en route to [destination].")
	error("area_coming_from: [current_location]")
	error("destination: [destination]")

	for(var/turf/src_turf in turf_translation)
		var/turf/dst_turf = turf_translation[src_turf]
		for(var/atom/movable/AM in dst_turf)
			if(!AM.simulated)
				continue
			if(isliving(AM))
				var/mob/living/bug = AM
				bug.gib()
			else
				qdel(AM) //it just gets atomized I guess? TODO throw it into space somewhere, prevents people from using shuttles as an atom-smasher
	for(var/area/A in shuttle_area)
		if(knockdown)
			for(var/mob/M in A)
				spawn(0)
					if(istype(M, /mob/living/human))
						if(M.buckled)
							to_chat(M, "<span class='warning'>Sudden acceleration presses you into your chair!</span>")
							shake_camera(M, 3, 1)
						else
							to_chat(M, "<span class='warning'>The floor lurches beneath you!</span>")
							shake_camera(M, 10, 1)
							M.visible_message("<span class='warning'>[M.name] is tossed around by the sudden acceleration!</span>")
							M.throw_at_random(FALSE, 4, 1)

	translate_turfs(turf_translation, current_location.base_area, current_location.base_turf)
	current_location = destination

/obj/structure/aircraft_lever/proc/long_jump(var/obj/effect/shuttle_landmark/destination, var/obj/effect/shuttle_landmark/interim, var/travel_time)
	if(moving_status != SHUTTLE_IDLE) return

	var/obj/effect/shuttle_landmark/start_location = current_location

	moving_status = SHUTTLE_WARMUP
	if(sound_takeoff)
		playsound(current_location, sound_takeoff, 100)
		if (!istype(start_location.base_area, /area/caribbean/space))
			var/area/A = get_area(start_location)

			for (var/mob/M in player_list)
				if (M.client && M.z == A.z && !istype(get_turf(M), /turf/floor/space) && !(get_area(M) in src.shuttle_area))
					to_chat(M, SPAN_NOTICE("The heavy sound of rotor blades are heard as a helicopter takes off."))

	spawn(warmup_time*10)
		if(moving_status == SHUTTLE_IDLE)
			return	//someone cancelled the launch

		arrive_time = world.time + travel_time*10
		moving_status = SHUTTLE_INTRANSIT
		if(attempt_move(interim))
			var/fwooshed = 0
			while (world.time < arrive_time)
				if(!fwooshed && (arrive_time - world.time) < 100)
					fwooshed = 1
					playsound(destination, sound_landing, 100)
					if (!istype(destination.base_area, /area/caribbean/space))
						var/area/A = get_area(destination)

						for (var/mob/M in player_list)
							if (M.client && M.z == A.z && !istype(get_turf(M), /turf/floor/space) && !(get_area(M) in src.shuttle_area))
								to_chat(M, SPAN_NOTICE("The heavy sound of rotor blades fill the area as a helicopter manuevers in for a landing."))

				sleep(5)
			if(!attempt_move(destination))
				attempt_move(start_location) //try to go back to where we started. If that fails, I guess we're stuck in the interim location

		moving_status = SHUTTLE_IDLE