/obj/structure/vehicle
	name = "vehicle"
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	desc = "A vehicle."
	icon_state = "motorcycle"
	var/list/ontop = list()
	var/list/ontop_o = list()
	var/mob/living/human/driver = null
	var/lastmove = 0
	var/vehicle_m_delay = 15
	anchored = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	flammable = FALSE
	can_buckle = TRUE
	buckle_lying = FALSE
	var/wheeled = FALSE
	var/obj/item/vehicleparts/wheel/dwheel = null
	var/moving = FALSE
	var/movement_processes = 0
	var/obj/structure/engine/internal/engine = null
	var/obj/structure/vehicleparts/axis/axis = null
	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/fueltank = null
	var/health = 100
	var/customcolor = "#FFFFFF"
	var/sails = FALSE
	var/sails_on = FALSE

	var/mobcapacity = 1
	var/storagecapacity = 0

	var/leave_time = 5

	mouse_drop_zone = TRUE

/obj/structure/vehicle/proc/check_sails()
	return
/obj/structure/vehicle/proc/updatepassdir()
	return
/obj/structure/vehicle/proc/do_color()
	return

/obj/structure/vehicle/proc/processmove(var/m_dir = null)
	if (!m_dir)
		return
	else
		if (do_vehicle_check() && lastmove+vehicle_m_delay <= world.time)
			do_move(m_dir)
			lastmove = world.time

/obj/structure/vehicle/proc/do_vehicle_check() //check if the vehicle can move.
	return TRUE

/obj/structure/vehicle/proc/update_overlay() //for the vehicles that have overlays (i.e. motorcycles)
	return

/obj/structure/vehicle/proc/check_engine()
	return

/obj/structure/vehicle/proc/do_move(var/m_dir = null, interval = null)
	// Riders and cargo glide with the vehicle for this leg (see the leases below).
	var/datum/carriage_glide_lease/lease = claim_ride_glides(m_dir, interval)
	try
		for (var/mob/living/ML in ontop)
			ML.forceMove(get_step(src, m_dir))
		for (var/obj/O in ontop_o)
			O.forceMove(get_step(src, m_dir))
			O.dir = dir
		forceMove(get_step(src, m_dir))
		update_icon()
	catch (var/exception/E)
		lease.release()
		throw E
	for (var/atom/movable/A in lease.members)
		A.carriage_glide_step = null
	return

/obj/structure/vehicle/update_icon()
	if (driver)
		dir = driver.dir
		buckle_dir = dir
	..()
/obj/structure/vehicle/proc/running_sound()
	if (engine)
		if (engine.on)
			playsound(loc, engine.running_snd, 65, FALSE)
			spawn(27)
				running_sound()
				return
//ok so, there seems to be a lot of bugs whenre people fall off or get thrown out of vehicles and stay on them. So we add a regular check.
/obj/structure/vehicle/proc/safety_check()
	if (!src)
		return
	release_stale_ride_glides()
	if (driver)
		if (!(driver in range(2,src)))
			driver.release_carriage_glide()
			ontop -= driver
			driver.pixel_x = 0
			driver.pixel_y = 0
			driver.driver = FALSE
			unbuckle_mob()
			driver.driver_vehicle = null
			if (wheeled)
				if (driver.l_hand == dwheel)
					driver.remove_from_mob(dwheel)
					dwheel.forceMove(src)
					driver.l_hand = null
				else if (driver.r_hand == dwheel)
					driver.remove_from_mob(dwheel)
					dwheel.forceMove(src)
					driver.r_hand = null
			driver.update_icons()
			driver = null
			update_overlay()
			update_icon()
	spawn(20)
		safety_check()

/obj/structure/vehicle/New()
	..()
	safety_check()
////////MOVEMENT LOOP/////////
/obj/structure/vehicle/proc/startmovementloop()
	moving = TRUE
	movementloop()

/obj/structure/vehicle/proc/movementloop()
	if (moving && driver && !movement_processes)
		movement_processes++
		var/interval = null
		if (do_vehicle_check() && axis.currentspeed > 0)
			interval = vehicle_m_delay + 1
			do_move(driver.dir, interval)
		else
			axis.currentspeed = 0
		spawn(vehicle_m_delay + 1)
			movement_processes--
			movementloop()
			return
	else
		return

/obj/structure/vehicle/proc/stopmovementloop()
	moving = FALSE
	axis.currentspeed = 0
	return

/obj/structure/vehicle/MouseDrop_T(atom/A, mob/living/human/user)
	if (istype(A, /mob/living/human))
		var/mob/living/human/M = A
		if (M.anchored == FALSE && M.driver == FALSE && !(M in ontop) && ontop.len < mobcapacity)
			user.visible_message(SPAN_NOTICE("[M] starts getting on \the [src]..."), SPAN_NOTICE("You start getting on \the [src]..."))
			if (do_after(M, 40, src))
				user.visible_message(SPAN_NOTICE("[M] sucessfully climbs onto \the [src]."), SPAN_NOTICE("You sucessfully climb onto \the [src]."))
				M.plane = GAME_PLANE
				M.forceMove(get_turf(src))
				M.settle_on_tile()
				if (!driver)
					if (wheeled)
						if (M.put_in_active_hand(dwheel) == FALSE)
							to_chat(M, "Your hands are full!")
							return

					M.driver = TRUE
					M.driver_vehicle = src
					driver = M
					buckle_mob(driver)
					ontop += M
				else
					ontop += M
				update_overlay()
				update_icon()
				return
	else if (istype(A, /obj/structure) && storagecapacity >= 1)
		if (src == A)
			return
		var/obj/structure/O = A
		if (O != src && ontop_o.len < storagecapacity && !(O.anchored) && !(O in ontop_o))
			user.visible_message(SPAN_NOTICE("[user] starts putting \the [O] on \the [src]..."), SPAN_NOTICE("You start putting \the [O] on \the [src]..."))
			if (do_after(user, 40, src) && ontop_o.len < storagecapacity)
				if (!O.persistence_set_loc(get_turf(src))) return FALSE
				user.visible_message(SPAN_NOTICE("[user] sucessfully puts \the [O] on \the [src]."), SPAN_NOTICE("You sucessfully put \the [O] on \the [src]."))
				O.pixel_x = pixel_x + 16
				O.pixel_y = pixel_y + 16
				ontop_o += O
				O.anchored = TRUE
				O.density = FALSE
				O.dir = dir
				if (istype(O, /obj/structure/cannon))
					O.x = x
					O.y = y
					O.pixel_x = pixel_x
					O.pixel_y = pixel_y
				update_overlay()
				update_icon()
				return

/obj/structure/vehicle/attack_hand(mob/living/human/user as mob)
	if (retake_controls(user))
		return
	if ((user in ontop))
		user.visible_message(SPAN_NOTICE("[user] start leaving \the [src]..."), SPAN_NOTICE("You start getting off \the [src]..."))
		if (do_after(user, leave_time, src))
			user.visible_message(SPAN_NOTICE("[user] sucessfully leaves \the [src]."), SPAN_NOTICE("You leave \the [src]."))
			user.release_carriage_glide()
			ontop -= user
			user.pixel_x = 0
			user.pixel_y = 0
			if (user == driver)
				user.driver = FALSE
				unbuckle_mob()
				user.driver_vehicle = null
				driver = null
				if (wheeled)
					if (user.l_hand == dwheel)
						user.remove_from_mob(dwheel)
						dwheel.forceMove(src)
						user.l_hand = null
					else if (user.r_hand == dwheel)
						user.remove_from_mob(dwheel)
						dwheel.forceMove(src)
						user.r_hand = null
					user.update_icons()
			update_overlay()
			update_icon()
			return
	else if (ontop_o.len > 0)
		for (var/obj/O in ontop_o)
			if (do_after(user, 15, src))
				if (!O.persistence_set_loc(get_turf(user))) return FALSE
				O.anchored = FALSE
				if (initial(O.density))
					O.density = TRUE
				O.release_carriage_glide()
				ontop_o -= O
				O.pixel_x = 0
				O.pixel_y = 0
				user.visible_message(SPAN_NOTICE("[user] takes \the [O] from \the [src]."), SPAN_NOTICE("You take \the [O] from \the [src]."))
		return

/obj/structure/vehicle/attackby(obj/item/weapon/W as obj, mob/living/human/user as mob)
	if (istype(W, /obj/item/vehicleparts/wheel))
		if ((user in ontop))
			if (user == driver && engine)
				if (engine.on)
					engine.on = FALSE
					engine.power_off_connections()
					engine.currentspeed = 0
					engine.currentpower = 0
					to_chat(user, "You turn off the engine.")
					set_light(0)
					playsound(loc, engine.ending_snd, 65, FALSE, 2)
					return

			user.visible_message("<div class='notice'>[user] start leaving \the [src]...</div>","<div class='notice'>You start leaving \the [src]...</div>")
			if (do_after(user, leave_time, src))
				user.visible_message("<div class='notice'>[user] sucessfully leaves \the [src].</div>","<div class='notice'>You leave \the [src].</div>")
				user.release_carriage_glide()
				ontop -= user
				user.pixel_x = 0
				user.pixel_y = 0
				if (user == driver)
					user.driver = FALSE
					unbuckle_mob()
					user.driver_vehicle = null
					driver = null
					if (wheeled)
						if (user.l_hand == dwheel)
							user.remove_from_mob(dwheel)
							dwheel.forceMove(src)
							user.l_hand = null
						else if (user.r_hand == dwheel)
							user.remove_from_mob(dwheel)
							dwheel.forceMove(src)
							user.r_hand = null
				update_overlay()
				update_icon()
				return
	else
		..()
///////////////////////////////////////////////////////
/obj/structure/vehicle/raft
	name = "raft"
	desc = "A simple wood raft. Can be used to cross water."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "raft"
	anchored = FALSE
	density = FALSE
	opacity = FALSE
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = FALSE
	wheeled = FALSE
	vehicle_m_delay = 12
	health = 50
/obj/structure/vehicle/raft/do_vehicle_check()
	var/turf/DT = get_turf(get_step(src,driver.dir))
	if (!DT)
		return FALSE
	if (driver && istype(DT, /turf/floor/beach/water) || istype(DT, /turf/floor/trench/flooded))
		if (istype(DT, /turf/floor/beach/water/deep/saltwater) && istype(DT.loc, /area/caribbean/sea))
			to_chat(driver, "<span class='danger'>You can't go further into the sea with a raft!</span>")
			return FALSE
		if (driver in get_turf(src))
			return TRUE
		else
			driver.driver = FALSE
			driver.driver_vehicle = null
			to_chat(driver, "You leave the [src].")
			unbuckle_mob()
			update_overlay()
			update_icon()
			ontop -= driver
			driver = null
	else
		return FALSE

/obj/structure/vehicle/raft/attackby(obj/item/O as obj, mob/user as mob)
	if (istype(O,/obj/item/weapon/hammer) && !not_disassemblable)
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		to_chat(user, SPAN_NOTICE("You begin dismantling \the [src]."))
		if (do_after(user,25,src))
			to_chat(user, SPAN_NOTICE("You dismantle \the [src].")) //We lose some materials in the process. Some wood and rope is no longer useful as raw.)
			var /obj/item/stack/material/woodplank/W = new /obj/item/stack/material/woodplank(get_turf(src))
			new /obj/item/stack/material/rope(get_turf(src))
			W.amount += 4 //adds 4 boards to the stack, making it 5
			qdel(src)
			return
	else
		..()

///////////////////////////////////////////////////////
//dirs:
//S: 23,33; 10,33
//N: 10,11; 25,11
//E: 5,31; 5,19
//W: 31,10; 31,20
/obj/structure/vehicle/boat
	name = "outrigger raft"
	desc = "A simple wood boat. Can be powered by a motor."
	icon = 'icons/obj/vehicles/vehicleparts64x64.dmi'
	icon_state = "outrigger_frame3"
	anchored = FALSE
	density = FALSE
	opacity = FALSE
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = FALSE
	vehicle_m_delay = 12
	layer = 2.95
	health = 90
	axis = new/obj/structure/vehicleparts/axis/boat
	wheeled = TRUE
	dwheel = new/obj/item/vehicleparts/wheel/rudder
	var/image/cover_overlay = null
	var/image/cover_overlay_c = null
	var/mob/living/human/currentcap = null
	bound_width = 64
	bound_height = 64
	mobcapacity = 2
	storagecapacity = 1
	plane = GAME_PLANE
	New()
		..()
		dwheel.origin = src

/obj/structure/vehicle/boat/b400
	name = "diesel outrigger"
	desc = "A 400cc, diesel-powered outrigger. Has a 125u fueltank."
	icon_state = "outrigger_frame3"
	health = 130

/obj/structure/vehicle/boat/b400/New()
	..()
	engine = new/obj/structure/engine/internal/diesel
	fueltank = new/obj/item/weapon/reagent_containers/glass/barrel/fueltank/small
	spawn(1)
		engine.enginesize = 400
		engine.weight = 20*(engine.enginesize/1000)
		engine.name = "400cc diesel engine"
		engine.maxpower *= (engine.enginesize/1000)
		engine.fuelefficiency *= (engine.enginesize/1000)
		spawn(1)
			engine.fueltank = fueltank
			engine.connections += axis
			dwheel.forceMove(src)

/obj/structure/vehicle/boat/rhib
	name = "rigid hull inflatable boat"
	desc = "A 400cc, gasoline-powered Ridgid Inflatable Boat. Has a 180u fueltank."
	icon_state = "rib_frame3"
	health = 300
	axis = new/obj/structure/vehicleparts/axis/boat/fast

/obj/structure/vehicle/boat/rhib/premade/New()
	..()
	engine = new/obj/structure/engine/internal/gasoline
	fueltank = new/obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank
	spawn(1)
		engine.enginesize = 400
		engine.weight = 20*(engine.enginesize/1000)
		engine.name = "400cc gasoline engine"
		engine.maxpower *= (engine.enginesize/1000)
		engine.fuelefficiency *= (engine.enginesize/1000)
		fueltank.reagents.add_reagent("gasoline",180)
		spawn(1)
			engine.fueltank = fueltank
			engine.connections += axis
			dwheel.forceMove(src)

/obj/structure/vehicle/boat/sailboat
	name = "sailing outrigger"
	desc = "A sailing boat. Powered by the wind."
	icon_state = "outrigger_frame1"
	health = 130
	sails = TRUE
	dwheel = new/obj/item/vehicleparts/wheel/rudder_sails

	New()
		..()
		dwheel.origin = src
		cover_overlay = image(icon, "sail1")
		cover_overlay.layer = MOB_LAYER + 2.11
		cover_overlay_c = image(icon, "sail2")
		cover_overlay_c.layer = MOB_LAYER + 2.12
		add_overlay(cover_overlay)
		update_overlay()
		update_icon()
/obj/structure/vehicle/boat/check_sails()
	var/timer = 15
	if (!sails || !sails_on)
		return
	if (!istype(get_turf(get_step(src,dir)), /turf/floor/beach/water) && !istype(get_turf(get_step(src,dir)), /turf/floor/trench/flooded))
		visible_message("<span class='notice'>\The [src] crashes into \the [get_turf(get_step(src,dir))]!</span>")
		sails_on = FALSE
		return
	if (sails && sails_on)
		switch(map.windspeedvar)
			if (0)
				timer = 40
			if (1)
				timer = 15
			if (2)
				timer = 11
			if (3)
				timer = 7
			if (4)
				timer = 4
		switch(map.winddirection)
			if ("North")
				if (dir == SOUTH)
					timer /= 1
				if  (dir == WEST || dir == EAST)
					timer /= 0.4
				if (dir == NORTH)
					timer /= 0.1
			if ("South")
				if (dir == NORTH)
					timer /= 1
				if  (dir == WEST || dir == EAST)
					timer /= 0.4
				if (dir == SOUTH)
					timer /= 0.1
			if ("East")
				if (dir == WEST)
					timer /= 1
				if  (dir == NORTH || dir == SOUTH)
					timer /= 0.4
				if (dir == EAST)
					timer /= 0.1
			if ("West")
				if (dir == EAST)
					timer /= 1
				if  (dir == NORTH || dir == SOUTH)
					timer /= 0.4
				if (dir == WEST)
					timer /= 0.1
	spawn(timer)
		for (var/mob/living/ML in ontop)
			ML.forceMove(get_step(src, dir))
		for (var/obj/O in ontop_o)
			O.forceMove(get_step(src, dir))
		forceMove(get_step(src, dir))
		updatepassdir()
		update_icon()
		check_sails()
/obj/structure/vehicle/boat/updatepassdir()
	if (driver)
		driver.pixel_x = pixel_x
		driver.pixel_y = pixel_y
		switch (dir)
			if (SOUTH)
				driver.pixel_x += 24
				driver.pixel_y += 32
			if (NORTH)
				driver.pixel_x += 8
				driver.pixel_y += 0
			if (EAST)
				driver.pixel_x += 0
				driver.pixel_y += 24
			if (WEST)
				driver.pixel_x += 32
				driver.pixel_y += 8
		if (!(driver in range(1,src)))
			ontop -= driver
			driver.anchored = FALSE
			driver.driver = FALSE
			driver.pixel_x = 0
			driver.pixel_y = 0
			unbuckle_mob()
			driver.buckled = null
			driver.driver_vehicle = null
			if (wheeled)
				if (driver.l_hand == dwheel)
					driver.remove_from_mob(dwheel)
					dwheel.forceMove(src)
					driver.l_hand = null
				else if (driver.r_hand == dwheel)
					driver.remove_from_mob(dwheel)
					dwheel.forceMove(src)
					driver.r_hand = null
				driver.update_icons()
				driver = null
	if (currentcap)
		currentcap.pixel_x = pixel_x
		currentcap.pixel_y = pixel_y
		switch (dir)
			if (SOUTH)
				currentcap.pixel_x += 8
				currentcap.pixel_y += 32
			if (NORTH)
				currentcap.pixel_x += 24
				currentcap.pixel_y += 0
			if (EAST)
				currentcap.pixel_x += 0
				currentcap.pixel_y += 8
			if (WEST)
				currentcap.pixel_x += 32
				currentcap.pixel_y += 24
		if (!(currentcap in range(1,src)))
			ontop -= currentcap
			currentcap.anchored = FALSE
			currentcap.pixel_x = 0
			currentcap.pixel_y = 0
			unbuckle_mob()
			currentcap.buckled = null
			currentcap = null
	if (ontop_o.len > 0)
		for (var/obj/OB in ontop_o)
			OB.pixel_x = pixel_x
			OB.pixel_y = pixel_y
			OB.dir = dir
			switch (dir)
				if (NORTH)
					OB.pixel_x += 16
					OB.pixel_y += 38
				if (SOUTH)
					OB.pixel_x += 16
					OB.pixel_y += 10
				if (EAST)
					OB.pixel_x += 32
					OB.pixel_y += 24
				if (WEST)
					OB.pixel_x += 0
					OB.pixel_y += 24

/obj/structure/vehicle/boat/sailboat/attackby(obj/item/O as obj, mob/user as mob)
	if (istype(O,/obj/item/weapon/hammer) && !not_disassemblable)
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		to_chat(user, SPAN_NOTICE("You begin dismantling \the [src]."))
		if (do_after(user,25,src))
			to_chat(user, SPAN_NOTICE("You dismantle \the [src].")) //We lose some materials in the process. Some wood is no longer useful as raw.)
			new /obj/item/sail(get_turf(src))
			var /obj/item/stack/material/woodplank/W = new /obj/item/stack/material/woodplank(get_turf(src))
			W.amount += 9 //adds 9 boards to the stack, making it 10
			qdel(src)
			return
	else
		..()

/obj/structure/vehicle/boat/MouseDrop_T(atom/A, mob/living/human/user)
	if (istype(A, /mob/living/human))
		if (!driver || !currentcap)
			var/mob/living/human/M = A
			if (M.anchored == FALSE && M.driver == FALSE && !(M in ontop))
				user.visible_message(SPAN_NOTICE("[M] starts getting on \the [src]..."), SPAN_NOTICE("You start getting on \the [src]..."))
				if (do_after(M, 25, src))
					user.visible_message(SPAN_NOTICE("[M] climbs onto \the [src]."), SPAN_NOTICE("You climb onto \the [src]."))
					M.plane = GAME_PLANE
					M.forceMove(get_turf(src))
					M.settle_on_tile()
					if (!driver)
						if (wheeled)
							if (M.put_in_active_hand(dwheel) == FALSE)
								to_chat(M, SPAN_WARNING("Your hands are full!"))
								return

						M.driver = TRUE
						M.driver_vehicle = src
						driver = M
						ontop += M
						buckle_mob(driver)
						updatepassdir()
					else if (!currentcap)
						currentcap = M
						ontop += M
						buckle_mob(currentcap)
						updatepassdir()
					update_overlay()
					update_icon()
					return
		else
			to_chat(user, SPAN_WARNING("\The [src] is full!"))
			return

	else if (istype(A, /obj/structure) || istype(A, /obj/item/weapon/gun/projectile/automatic/stationary) && storagecapacity >= 1)
		if (src == A)
			return
		var/obj/structure/O = A
		if (O.anchored == FALSE && !(O in ontop_o) && ontop_o.len < storagecapacity)
			user.visible_message(SPAN_NOTICE("[user] starts putting \the [O] on \the [src]..."), SPAN_NOTICE("You start putting \the [O] on \the [src]..."))
			if (do_after(user, 40, src) && ontop_o.len < storagecapacity)
				if (!O.persistence_set_loc(get_turf(src))) return FALSE
				user.visible_message(SPAN_NOTICE("[user] sucessfully puts \the [O] on \the [src]."), SPAN_NOTICE("You sucessfully put \the [O] on \the [src]."))
				O.pixel_x = pixel_x + 16
				O.pixel_y = pixel_y + 16
				ontop_o += O
				O.sinkable = FALSE
				O.anchored = TRUE
				O.density = FALSE
				O.dir = dir
				if (istype(O, /obj/structure/cannon))
					O.x = x
					O.y = y
					O.pixel_x = pixel_x
					O.pixel_y = pixel_y
				update_overlay()
				update_icon()
				return

/obj/structure/vehicle/boat/attack_hand(mob/living/human/user as mob)
	if (retake_controls(user))
		return
	if ((user in ontop))
		user.visible_message("<div class='notice'>[user] starts leaving \the [src]...</div>","<div class='notice'>You start leaving \the [src]...</div>")
		if (do_after(user, leave_time, src))
			user.visible_message("<div class='notice'>[user] leaves \the [src].</div>","<div class='notice'>You leave \the [src].</div>")
			ontop -= user
			user.pixel_x = 0
			user.pixel_y = 0
			if (user == driver)
				user.driver = FALSE
				unbuckle_mob()
				user.driver_vehicle = null
				driver = null
				updatepassdir()
				if (wheeled)
					if (user.l_hand == dwheel)
						user.remove_from_mob(dwheel)
						dwheel.forceMove(src)
						user.l_hand = null
					else if (user.r_hand == dwheel)
						user.remove_from_mob(dwheel)
						dwheel.forceMove(src)
						user.r_hand = null
					user.update_icons()
			if (user == currentcap)
				unbuckle_mob()
				currentcap = null
				ontop -= user
				user.anchored = FALSE
				user.buckled = FALSE
				updatepassdir()
			update_overlay()
			update_icon()
			return
	else if (ontop_o.len > 0)
		for (var/obj/O in ontop_o)
			if (do_after(user, 15, src))
				if (!O.persistence_set_loc(get_turf(user))) return FALSE
				O.anchored = FALSE
				if (initial(O.density))
					O.density = TRUE
				ontop_o -= O
				O.sinkable = TRUE
				O.pixel_x = 0
				O.pixel_y = 0
				O.dir = dir
				user.visible_message(SPAN_NOTICE("[user] takes \the [O] from \the [src]."), SPAN_NOTICE("You take \the [O] from \the [src]."))
		return

/obj/structure/vehicle/boat/attackby(obj/item/weapon/W as obj, mob/living/human/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/glass))
		var/obj/item/weapon/reagent_containers/glass/GC = W
		if (fueltank && fueltank.reagents && fueltank.reagents.total_volume < fueltank.reagents.maximum_volume)
			var/found = FALSE
			for (var/i in engine.fuels)
				if (GC && GC.reagents && GC.reagents.has_reagent(i))
					found = TRUE
			if (!found)
				to_chat(user, "\The [W] has no acceptable fuel in it.")
				update_customdesc()
				return
			for (var/i in engine.fuels)
				if (GC.reagents.has_reagent(i))
					if (GC.reagents.get_reagent_amount(i)<= fueltank.reagents.maximum_volume-fueltank.reagents.total_volume)
						fueltank.reagents.add_reagent(i,GC.reagents.get_reagent_amount(i))
						GC.reagents.del_reagent(i)
						to_chat(user, "You empty \the [W] into the fueltank.")
						update_customdesc()
						return
					else
						var/amttransf = fueltank.reagents.maximum_volume-fueltank.reagents.total_volume
						fueltank.reagents.add_reagent(i,amttransf)
						GC.reagents.remove_reagent(i,amttransf)
						to_chat(user, "You fill the fueltank completly with \the [W].")
						update_customdesc()
						return
		else
			to_chat(user, "The fueltank is full already.")
			update_customdesc()
			return
	else if (istype(W, /obj/item/vehicleparts/wheel))
		if ((user in ontop))
			if (user == driver && engine)
				if (engine.on)
					engine.on = FALSE
					engine.power_off_connections()
					engine.currentspeed = 0
					engine.currentpower = 0
					to_chat(user, "You turn off the engine.")
					moving = FALSE
					set_light(0)
					playsound(loc, engine.ending_snd, 65, FALSE, 2)
					stopmovementloop()
					return

			user.visible_message("<div class='notice'>[user] starts leaving \the [src]...</div>","<div class='notice'>You start leaving \the [src]...</div>")
			if (do_after(user, leave_time, src))
				user.visible_message("<div class='notice'>[user] sucessfully leaves \the [src].</div>","<div class='notice'>You leave \the [src].</div>")
				ontop -= user
				user.pixel_x = 0
				user.pixel_y = 0
				if (user == driver)
					user.driver = FALSE
					unbuckle_mob()
					user.driver_vehicle = null
					driver = null
					updatepassdir()
					if (wheeled)
						if (user.l_hand == dwheel)
							user.remove_from_mob(dwheel)
							dwheel.forceMove(src)
							user.l_hand = null
						else if (user.r_hand == dwheel)
							user.remove_from_mob(dwheel)
							dwheel.forceMove(src)
							user.r_hand = null
					user.buckled = null
				update_overlay()
				update_icon()
				return
	else
		..()

/obj/structure/vehicle/boat/do_vehicle_check()
	update_customdesc()
	if (!driver)
		moving = FALSE
		stopmovementloop()
		return FALSE
		
	var/turf/T = get_turf(get_step(src,driver.dir))
	var/area/A = get_area(T)
	if (map && A && map.caribbean_blocking_area_types.Find(A.type))
		if (!map.faction1_can_cross_blocks() && !map.faction2_can_cross_blocks())
			visible_message(SPAN_DANGER("You cannot cross the grace wall yet!"))
			moving = FALSE
			stopmovementloop()
			return FALSE
	if (map && map.check_caribbean_block(driver,T))
		visible_message(SPAN_DANGER("You cannot cross the grace wall yet!"))
		moving = FALSE
		stopmovementloop()
		return FALSE

	if (driver.stat == UNCONSCIOUS || driver.stat == DEAD)
		visible_message("<span class='warning'>[driver] falls from \the [src]!</span>","<span class='warning'>You fall from \the [src]!</span>")
		stopmovementloop()
		driver.driver = FALSE
		driver.driver_vehicle = null
		driver.pixel_x = 0
		driver.pixel_y = 0
		unbuckle_mob()
		update_overlay()
		update_icon()
		ontop -= driver
		driver = null

	if (istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/trench/flooded))
		if (driver in get_turf(src))
			return TRUE
		else
			to_chat(driver, "You fall off \the [src].")
			stopmovementloop()
			driver.driver = FALSE
			driver.driver_vehicle = null
			driver.pixel_x = 0
			driver.pixel_y = 0
			unbuckle_mob()
			update_overlay()
			update_icon()
			ontop -= driver
			driver = null
			return FALSE
	else
		moving = FALSE
		axis.currentspeed = 0
		stopmovementloop()
		return FALSE

/obj/structure/vehicle/boat/New()
	..()
	spawn(3)
		if (engine)
			update_customdesc()

/obj/structure/vehicle/boat/proc/update_customdesc()
	desc = "A boat with a [engine.enginesize]cc engine. Has [fueltank.reagents.total_volume] of [fueltank.reagents.maximum_volume] units of fuel left."
	return
/obj/structure/vehicle/boat/update_overlay()
	if (sails)
		if (sails_on)
			add_overlay(cover_overlay_c)
			update_icon()
			return
		else
			overlays -= cover_overlay_c
			update_icon()
			return
	else
		overlays -= cover_overlay_c

///////////////////////////////////////////////////////
/obj/structure/vehicle/motorcycle
	name = "motorcycle"
	desc = "A motorcycle."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "motorcycle"
	anchored = FALSE
	density = TRUE
	opacity = FALSE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	vehicle_m_delay = 3
	var/image/cover_overlay = null
	var/image/cover_overlay_c = null
	var/image/cover_overlay_base = null
	axis = new/obj/structure/vehicleparts/axis/bike
	wheeled = TRUE
	dwheel = new/obj/item/vehicleparts/wheel/handle
	light_color = "#e2ac53"
	New()
		..()
		dwheel.origin = src
/obj/structure/vehicle/motorcycle/m125
	name = "125cc motorcycle"
	desc = "A 125cc, 4-stroke gasoline motorcycle."
	icon_state = "motorcycleX"
	health = 130
/obj/structure/vehicle/motorcycle/m125/New()
	..()
	engine = new/obj/structure/engine/internal/gasoline
	spawn(1)
		engine.enginesize = 125
		engine.weight = 20*(engine.enginesize/1000)
		engine.name = "125cc gasoline engine"
		engine.maxpower *= (engine.enginesize/1000)
		engine.fuelefficiency *= (engine.enginesize/1000)
		spawn(1)
			engine.fueltank = fueltank
			engine.connections += axis
			dwheel.forceMove(src)

	fueltank = new/obj/item/weapon/reagent_containers/glass/barrel/fueltank/bike

/obj/structure/vehicle/motorcycle/m125/full/New()
	name = "Yamasaki M125"
	..()
	fueltank = new/obj/item/weapon/reagent_containers/glass/barrel/fueltank/bike/full

/obj/structure/vehicle/motorcycle/New()
	..()
	//TODO: assign axis, fueltank, engine and connect them
	cover_overlay_base = image(icon, "[icon_state]_frame2_mask")//"bike_cover")
	cover_overlay = image(icon, "[icon_state]_overlay")//"bike_cover")
	cover_overlay.layer = MOB_LAYER + 2.1
	cover_overlay_c = image(icon, "[icon_state]_overlay_mask")//"bike_cover")
	cover_overlay_c.layer = MOB_LAYER + 2.11
	spawn(3)
		cover_overlay_c.color = customcolor
		cover_overlay_base.color = customcolor
		overlays += cover_overlay_base
		update_customdesc()

/obj/structure/vehicle/motorcycle/proc/update_customdesc()
	if(engine && fueltank)
		desc = "A [engine.enginesize]cc motorcycle. Has [fueltank.reagents.total_volume] of [fueltank.reagents.maximum_volume] units of fuel left."
	return
/obj/structure/vehicle/motorcycle/update_overlay()
	if (driver)
		add_overlay(cover_overlay)
		add_overlay(cover_overlay_c)
		return
	else
		overlays -= cover_overlay
		overlays -= cover_overlay_c
		return

/obj/structure/vehicle/motorcycle/do_vehicle_check()
	update_customdesc()
	var/turf/T = get_turf(get_step(src,driver.dir))
	var/area/A = get_area(T)
	if (!check_engine() || !T)
		moving = FALSE
		stopmovementloop()
		return FALSE
	if (map && A && map.caribbean_blocking_area_types.Find(A.type))
		if (!map.faction1_can_cross_blocks() && !map.faction2_can_cross_blocks())
			visible_message(SPAN_DANGER("You cannot cross the grace wall yet!"))
			moving = FALSE
			stopmovementloop()
			return FALSE
	if (map && map.check_caribbean_block(driver,T))
		visible_message(SPAN_DANGER("You cannot cross the grace wall yet!"))
		moving = FALSE
		stopmovementloop()
		return FALSE
	var/blocked = 0
	for (var/obj/structure/O in T)
		if (O.density == TRUE)
			blocked = 1
			visible_message(SPAN_WARNING("\The [src] hits \the [O]!"), SPAN_WARNING("You hit \the [O]!"))
	if (T.density)
		blocked = 1
		visible_message(SPAN_WARNING("\The [src] hits \the [T]!"), SPAN_WARNING("You hit \the [T]!"))
	for (var/obj/covers/CV in T)
		if (CV.density == TRUE)
			blocked = 1
			visible_message("<span class='warning'>\The [src] hits \the [CV]!</span>","<span class='warning'>You hit \the [CV]!</span>")
	for (var/mob/living/L in T)
		// A rider's body can reach into the tile ahead; never hit our own.
		if (L == driver || (L in ontop))
			continue
		if (ishuman(L))
			var/mob/living/human/HH = L
			HH.adjustBruteLoss(rand(7,16)*axis.currentspeed)
			HH.Weaken(rand(2,5))
			blocked = 1
			visible_message("<span class='warning'>\The [src] hits \the [L]!</span>","<span class='warning'>You hit \the [L]!</span>")
		else if (istype(L,/mob/living/simple_animal))
			var/mob/living/simple_animal/SA = L
			SA.health -= rand(7,16)*axis.currentspeed
			if (SA.mob_size >= 30)
				blocked = 1
				visible_message("<span class='warning'>\The [src] hits \the [SA]!</span>","<span class='warning'>You hit \the [SA]!</span>")
			else
				visible_message("<span class='warning'>\The [src] runs over \the [SA]!</span>","<span class='warning'>You run over \the [SA]!</span>")
	if (blocked)
		moving = FALSE
		health -= rand(3,4)*axis.currentspeed
		driver.adjustBruteLoss(rand(3,4)*axis.currentspeed)
		if (axis.currentspeed >= 3 || (axis.currentspeed == 2 && prob(50)))
			visible_message("<span class='warning'>[driver] falls from \the [src]!</span>","<span class='warning'>You fall from \the [src]!</span>")
			stopmovementloop()
			driver.SpinAnimation(5,1)
			var/list/turf/emptyTurfs = new
			for(var/turf/TT in range(1,src))
				var/invalid = FALSE
				if (istype(TT, /turf/wall) || istype(TT, /turf/floor/dirt/underground) || istype (TT, /turf/floor/beach/water))
					invalid = TRUE
				for(var/obj/structure/OB in TT)
					invalid = TRUE
				for(var/obj/covers/OB in TT)
					invalid = TRUE
				if (!invalid)
					emptyTurfs += TT
			if (!emptyTurfs.len)
				driver.forceMove(locate(x,y,z))
			else
				driver.forceMove((pick(emptyTurfs)))
			driver.Weaken(5)
			driver.adjustBruteLoss(rand(8,19))
			if (!driver.head)
				to_chat(driver, "<span class='warning'>Your head hits the ground!</span>")
				driver.adjustBrainLoss(rand(5,8))
			if (driver.head && !istype(driver.head, /obj/item/clothing/head/helmet))
				to_chat(driver, "<span class='warning'>Your head hits the ground!</span>")
				driver.adjustBrainLoss(rand(3,6))
			if (driver.l_hand == dwheel)
				driver.remove_from_mob(dwheel)
				dwheel.forceMove(src)
				driver.l_hand = null
			else if (driver.r_hand == dwheel)
				driver.remove_from_mob(dwheel)
				dwheel.forceMove(src)
				driver.r_hand = null
			driver.driver = FALSE
			driver.driver_vehicle = null
			driver.pixel_x = 0
			driver.pixel_y = 0
			unbuckle_mob()
			update_overlay()
			update_icon()
			ontop -= driver
			driver = null
			return FALSE
		axis.currentspeed = 0
		stopmovementloop()
		return FALSE
	var/canpass = FALSE
	for (var/obj/covers/CVV in T)
		if (CVV.density == FALSE)
			canpass = TRUE
	if ((!istype(T, /turf/floor/beach/water/deep) ||  istype(T, /turf/floor/beach/water/deep) && canpass == TRUE)&& T.density == FALSE  || istype(T, /turf/floor/trench/flooded))
		if (driver in src.loc)
			return TRUE
		else
			driver.driver = FALSE
			driver.driver_vehicle = null
			to_chat(driver, "You leave the [src].")
			driver.buckled  = null
			driver.pixel_x = 0
			driver.pixel_y = 0
			unbuckle_mob()
			update_overlay()
			update_icon()
			ontop -= driver
			if (driver.l_hand == dwheel)
				driver.remove_from_mob(dwheel)
				dwheel.forceMove(src)
				driver.l_hand = null
			else if (driver.r_hand == dwheel)
				driver.remove_from_mob(dwheel)
				dwheel.forceMove(src)
				driver.r_hand = null
			driver = null
	else
		moving = FALSE
		stopmovementloop()
		return FALSE

/obj/structure/vehicle/motorcycle/check_engine()
	if (!engine || !fueltank)
		return FALSE
	if (fueltank.reagents.total_volume <= 0)
		fueltank.reagents.total_volume = 0
		return FALSE
	if (!engine.on)
		return FALSE
	return TRUE

/obj/structure/vehicle/motorcycle/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/glass))
		var/obj/item/weapon/reagent_containers/glass/GC = W
		if (fueltank.reagents.total_volume >= fueltank.reagents.maximum_volume)
			to_chat(user, "The fueltank is full already.")
		if (fueltank.reagents.total_volume < fueltank.reagents.maximum_volume)
			if (!GC.reagents.has_reagent("gasoline"))
				to_chat(user, "\The [W] has no gasoline in it.")
			if (GC.reagents.get_reagent_amount("gasoline") <= fueltank.reagents.maximum_volume-fueltank.reagents.total_volume)
				fueltank.reagents.add_reagent("gasoline",GC.reagents.get_reagent_amount("gasoline"))
				GC.reagents.del_reagent("gasoline")
				to_chat(user, "You empty \the [W] into the fueltank.")
			else
				var/amttransf = fueltank.reagents.maximum_volume-fueltank.reagents.total_volume
				fueltank.reagents.add_reagent("gasoline",amttransf)
				GC.reagents.remove_reagent("gasoline",amttransf)
				to_chat(user, "You fill the fueltank completely with \the [W].")
		update_customdesc()
		return
	..()

/obj/structure/vehicle/motorcycle/do_color(_color = null)
	var/tempcolor = customcolor
	if (_color != null)
		tempcolor = _color
	if (tempcolor)
		var/image/colorov = image("icon" = icon, "icon_state" = "[icon_state]_mask1")
		colorov.color = tempcolor
		overlays += colorov

// Appearance-only leases. No timer or physical movement is owned here.
/atom/movable
	var/tmp/datum/carriage_glide_lease/carriage_glide_owner
	var/tmp/carriage_glide_previous
	var/tmp/carriage_glide_applied
	var/tmp/list/carriage_glide_step

/atom/movable/proc/release_carriage_glide()
	var/datum/carriage_glide_lease/lease = carriage_glide_owner
	if (!lease)
		return
	carriage_glide_owner = null
	carriage_glide_step = null
	if (glide_size == carriage_glide_applied)
		glide_size = carriage_glide_previous
	carriage_glide_previous = null
	carriage_glide_applied = null
	lease.members -= src
	GLOB.moved_event.unregister(src, lease, /datum/carriage_glide_lease/proc/moved)
	GLOB.destroyed_event.unregister(src, lease, /datum/carriage_glide_lease/proc/destroyed)

/datum/carriage_glide_lease
	should_save = FALSE
	var/obj/structure/vehicle/carriage // the leasing vehicle, of any kind
	var/list/members = list()

/datum/carriage_glide_lease/Destroy()
	release()
	return ..()

/datum/carriage_glide_lease/proc/release()
	var/obj/structure/vehicle/C = carriage
	carriage = null // Retire before callbacks; an old listener never owns a new leg.
	if (C && C.carriage_glide == src)
		C.carriage_glide = null
	for (var/atom/movable/A in members.Copy())
		if (!A)
			continue
		if (A.carriage_glide_owner == src)
			A.release_carriage_glide()
		// Retire this listener even if a foreign owner replaced the pointer.
		GLOB.moved_event.unregister(A, src, /datum/carriage_glide_lease/proc/moved)
		GLOB.destroyed_event.unregister(A, src, /datum/carriage_glide_lease/proc/destroyed)
	members.Cut()

/datum/carriage_glide_lease/proc/moved(atom/movable/A, atom/old_loc, atom/new_loc)
	if (!carriage || !A || A.carriage_glide_owner != src)
		return
	var/list/expected = A.carriage_glide_step
	A.carriage_glide_step = null // One arrival only, including nested callbacks.
	if (expected && old_loc == expected[1] && new_loc == expected[2])
		return
	if (A == carriage)
		release()
	else
		A.release_carriage_glide()

/datum/carriage_glide_lease/proc/destroyed(atom/movable/A)
	if (!carriage || !A || A.carriage_glide_owner != src)
		return
	if (A == carriage)
		release()
	else
		A.release_carriage_glide()

/datum/carriage_glide_lease/proc/claim(atom/movable/A, interval, m_dir, turf/destination)
	if (!carriage || !A || isDeleted(A) || A.loc != carriage.loc)
		return
	// Retire the walking adapter's stack before recording the native prior value.
	if (ishuman(A))
		var/mob/living/human/H = A
		if (H.human_subtile_visual_owner && H.human_subtile_visual_owner.human_subtile_visual_actor == H)
			H.human_subtile_visual_owner.human_subtile_release_visuals()
		H.human_subtile_release_glide()
	A.release_carriage_glide()
	A.carriage_glide_owner = src
	A.carriage_glide_previous = A.glide_size
	A.carriage_glide_applied = 32 * world.tick_lag / max(interval, world.tick_lag)
	if ((m_dir & (m_dir - 1)) && !(A.appearance_flags & LONG_GLIDE))
		A.carriage_glide_applied *= ROOT2_FAST
	A.glide_size = A.carriage_glide_applied
	A.carriage_glide_step = list(A.loc, destination)
	members |= A
	GLOB.moved_event.register(A, src, /datum/carriage_glide_lease/proc/moved)
	GLOB.destroyed_event.register(A, src, /datum/carriage_glide_lease/proc/destroyed)

// Every vehicle (carriages, motorcycles, boats, rafts, mops) leases one glide
// to itself, its riders and its cargo for each leg, so a rider never keeps a
// walking glide and drifts off the seat while the vehicle moves.
/obj/structure/vehicle
	var/tmp/datum/carriage_glide_lease/carriage_glide

/obj/structure/vehicle/proc/release_carriage_glides()
	if (carriage_glide)
		carriage_glide.release()

/obj/structure/vehicle/proc/claim_ride_glides(m_dir, interval)
	if (isnull(interval))
		interval = vehicle_m_delay + 1
	release_carriage_glides()
	var/datum/carriage_glide_lease/lease = new
	lease.carriage = src
	carriage_glide = lease
	var/turf/destination = get_step(src, m_dir)
	if (destination)
		lease.claim(src, interval, m_dir, destination)
		for (var/mob/living/M in ontop)
			lease.claim(M, interval, m_dir, destination)
		for (var/obj/O in ontop_o)
			lease.claim(O, interval, m_dir, destination)
	return lease

/obj/structure/vehicle/proc/release_stale_ride_glides()
	var/datum/carriage_glide_lease/lease = carriage_glide
	if (lease)
		for (var/atom/movable/A in lease.members.Copy())
			if (A != src && (!(A in ontop) && !(A in ontop_o) || A.loc != loc))
				A.release_carriage_glide()
	if (!movement_processes)
		release_carriage_glides()

/obj/structure/vehicle/persistence_runtime_var(key)
	return key == "carriage_glide" || ..()

