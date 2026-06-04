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

/obj/structure/boat_spawn_lever // same icon as the train lever for now
	name = "boat spawner"
	icon = 'icons/obj/vehicles/train_lever.dmi'
	icon_state = "lever_none"
	
	anchored = TRUE
	density = TRUE
	
	var/none_state = "lever_none" // Icon for when the transport object is not being used
	var/pushed_state = "lever_pulled" // Icon for when the transport object is used
	var/next_activation = -1; // Used for cooldown
	var/cooldown = 60 SECONDS
	var/facing_dir = NORTH

	var/x_offset = 0
	var/y_offset = 0

/obj/structure/boat_spawn_lever/attack_hand(var/mob/user as mob)
	if (world.time < next_activation)
		to_chat(user,SPAN_NOTICE("This boat spawner is cooling down, try again in a bit."))
		return
	else
		next_activation = world.time + cooldown
		var/obj/structure/vehicle/boat/rhib/premade/premade = new /obj/structure/vehicle/boat/rhib/premade(locate(src.x + x_offset, src.y + y_offset, src.z))
		premade.dir = facing_dir
		icon_state = pushed_state
		spawn (5)
			icon_state = none_state
		return

/obj/structure/boat_spawn_lever/north
	facing_dir = NORTH
	y_offset = 1
/obj/structure/boat_spawn_lever/south
	facing_dir = SOUTH
	y_offset = -2

/obj/structure/boat_spawn_lever/east
	facing_dir = EAST
	x_offset = 1
/obj/structure/boat_spawn_lever/west
	facing_dir = WEST
	x_offset = -2