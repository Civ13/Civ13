/obj/structure/transport_lever // same icon as the train lever for now
	anchored = 1.0
	density = TRUE
	icon = 'icons/obj/vehicles/train_lever.dmi'
	icon_state = "lever_none"
	var/none_state = "lever_none" // Icon for when the transport object is not being used
	var/pushed_state = "lever_pulled" // Icon for when the transport object is used
	var/depart_sound = 'sound/landing_craft.ogg' // Sound for when the transport leaves

	var/orientation = "NONE"
	var/lever_id = "defaulttransportleverid"
	name = "Landing Craft control"
	var/local = "docked" // Where the transport is
	var/next_activation = -1;

/obj/structure/transport_lever/attack_hand(var/mob/user as mob)
//f (user && istype(user, /mob/living/human))
//function(user)
	if (world.time < next_activation)
		next_activation = world.time + 50
		visible_message("This Landing Craft isn't ready to depart yet.</span>")
	else
		next_activation = world.time + 400 //to give it time to reach the destination
		for (var/mob/m in range(10, src))
			m.playsound_local(get_turf(m), depart_sound, 100 - get_dist(m, src))
		if (local == "docked")
			visible_message("The Landing Craft is departing!</span>")
			if (orientation == "NONE")
				icon_state = pushed_state
				orientation = "PULLED"
			for (var/turf/floor/plating/concrete/T in range(10, src))
				T.opacity = TRUE
				T.density = TRUE
			spawn (3)
				icon_state = none_state
				orientation = "NONE"
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
						for (var/mob/m in range(10, src))
							m.playsound_local(get_turf(m), 'sound/landing_craft.ogg', 100 - get_dist(m, src))
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
			local = "launched"
		else if (local == "launched")
			visible_message("The Landing Craft is departing!</span>")
			if (orientation == "NONE")
				icon_state = "lever_pushed"
				orientation = "PUSHED"
			for (var/turf/floor/plating/concrete/T in range(10, src))
				T.opacity = TRUE
				T.density = TRUE
			local = "docked"
			spawn (3)
				icon_state = "lever_none"
				orientation = "NONE"
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
						for (var/mob/m in range(10, src))
							m.playsound_local(get_turf(m), 'sound/landing_craft.ogg', 100 - get_dist(m, src))
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