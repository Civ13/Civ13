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
	var/obj/structure/engine/internal/engine = null
	var/obj/structure/vehicleparts/axis/axis = null
	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/fueltank = null
	var/health = 100
	var/customcolor = "#FFFFFF"
	var/sails = FALSE
	var/sails_on = FALSE

	var/mobcapacity = 1
	var/storagecapacity = 0

	mouse_drop_zone = TRUE

	var/animal_propelled = FALSE

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

/obj/structure/vehicle/proc/do_move(var/m_dir = null)
	for (var/mob/living/ML in ontop)
		ML.forceMove(get_step(src, m_dir))
	for (var/obj/structure/O in ontop_o)
		O.forceMove(get_step(src, m_dir))
		O.dir = dir
	forceMove(get_step(src, m_dir))
	update_icon()
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
	if (driver)
		if (!driver in range(2,src))
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
	if (moving == TRUE && driver)
		if (do_vehicle_check() && axis.currentspeed > 0)
			do_move(driver.dir)
		else
			axis.currentspeed = 0
		spawn(vehicle_m_delay+1)
			movementloop()
			return
	else
		return

/obj/structure/vehicle/proc/stopmovementloop()
	moving = FALSE
	return

/obj/structure/vehicle/MouseDrop_T(atom/A, mob/living/human/user)
	if (istype(A, /mob/living/human))
		var/mob/living/human/M = A
		if (M.anchored == FALSE && M.driver == FALSE && !(M in ontop) && ontop.len < mobcapacity)
			visible_message("<div class='notice'>[M] starts getting on \the [src]...</div>","<div class='notice'>You start going on \the [src]...</div>")
			if (do_after(M, 40, src))
				visible_message("<div class='notice'>[M] sucessfully climbs into \the [src].</div>","<div class='notice'>You sucessfully climb into \the [src].</div>")
				M.plane = GAME_PLANE
				M.forceMove(get_turf(src))
				if (!driver)
					if (wheeled)
						if (M.put_in_active_hand(dwheel) == FALSE)
							M << "Your hands are full!"
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
	else if (istype(A, /obj) && storagecapacity >= 1)
		if (src == A)
			return
		var/obj/structure/O = A
		if (O.anchored == FALSE && !(O in ontop_o) && ontop_o.len < storagecapacity && O != src)
			visible_message("<div class='notice'>[user] starts putting \the [O] on \the [src]...</div>","<div class='notice'>You start putting \the [O] on \the [src]...</div>")
			if (do_after(user, 40, src) && ontop_o.len < storagecapacity)
				visible_message("<div class='notice'>[user] sucessfully puts \the [O] on \the [src].</div>","<div class='notice'>You sucessfully put \the [O] on \the [src].</div>")
				O.pixel_x = pixel_x+16
				O.pixel_y = pixel_y+16
				ontop_o += O
				O.anchored = TRUE
				O.dir = dir
				if (istype(O, /obj/structure/cannon))
					O.icon = 'icons/obj/cannon.dmi'
					O.x = x
					O.y = y
					O.pixel_x = pixel_x
					O.pixel_y = pixel_y
				update_overlay()
				update_icon()
				return

/obj/structure/vehicle/attack_hand(mob/living/human/user as mob)
	if ((user in ontop))
		visible_message("<div class='notice'>[user] start leaving \the [src]...</div>","<div class='notice'>You start going on \the [src]...</div>")
		if (do_after(user, 30, src))
			visible_message("<div class='notice'>[user] sucessfully leaves \the [src].</div>","<div class='notice'>You leave \the [src].</div>")
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
		for (var/obj/structure/O in ontop_o)
			O.anchored = FALSE
			ontop_o -= O
			O.pixel_x = 0
			O.pixel_y = 0
			visible_message("[user] takes \the [O] from \the [src].","You take \the [O] from \the [src].")
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
					user << "You turn off the engine."
					set_light(0)
					playsound(loc, engine.ending_snd, 65, FALSE, 2)
					return

			visible_message("<div class='notice'>[user] start leaving \the [src]...</div>","<div class='notice'>You start going on \the [src]...</div>")
			if (do_after(user, 30, src))
				visible_message("<div class='notice'>[user] sucessfully leaves \the [src].</div>","<div class='notice'>You leave \the [src].</div>")
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
			driver << "<span class='danger'>You can't go further into the sea with a raft!</span>"
			return FALSE
		if (driver in get_turf(src))
			return TRUE
		else
			driver.driver = FALSE
			driver.driver_vehicle = null
			driver << "You leave the [src]."
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
		user << "<span class='notice'>You begin dismantling \the [src].</span>"
		if (do_after(user,25,src))
			user << "<span class='notice'>You dismantle \the [src].</span>"//We lose some materials in the process. Some wood and rope is no longer useful as raw.
			var /obj/item/stack/material/wood/W = new /obj/item/stack/material/wood(get_turf(src))
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
	var/maxcapacity = 1 //besides the driver
	var/mob/living/human/currentcap = null
	bound_width = 64
	bound_height = 64
	mobcapacity = 2
	storagecapacity = 1
	New()
		..()
		dwheel.origin = src

/obj/structure/vehicle/boat/b400
	name = "diesel outrigger"
	desc = "A 400cc, diesel-powered outrigger. Has a 125u fueltank."
	icon_state = "outrigger_frame3"
	health = 130

/obj/structure/vehicle/boat/rib
	name = "rigidbody inflatable motor boat"
	desc = "A 400cc, diesel-powered outrigger. Has a 125u fueltank."
	icon_state = "rib"
	health = 200

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
		for (var/obj/structure/O in ontop_o)
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
				driver.pixel_x += 23
				driver.pixel_y += 33
			if (NORTH)
				driver.pixel_x += 10
				driver.pixel_y += 11
			if (EAST)
				driver.pixel_x += 5
				driver.pixel_y += 31
			if (WEST)
				driver.pixel_x += 31
				driver.pixel_y += 10
		if (!(driver in range(1,src)))
			ontop -= driver
			driver.anchored = FALSE
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
	if (currentcap)
		currentcap.pixel_x = pixel_x
		currentcap.pixel_y = pixel_y
		switch (dir)
			if (SOUTH)
				currentcap.pixel_x += 10
				currentcap.pixel_y += 33
			if (NORTH)
				currentcap.pixel_x += 25
				currentcap.pixel_y += 11
			if (EAST)
				currentcap.pixel_x += 5
				currentcap.pixel_y += 19
			if (WEST)
				currentcap.pixel_x += 31
				currentcap.pixel_y += 19
		if (!(currentcap in range(1,src)))
			ontop -= currentcap
			currentcap.anchored = FALSE
			currentcap = null
	if (ontop_o.len > 0)
		if(storagecapacity >= 1)
			for(var/obj/structure/OB in ontop_o)
				switch (dir)
					if (SOUTH, NORTH)
						if (istype(OB, /obj/structure/cannon))
							OB.pixel_x = pixel_x
							if (dir == SOUTH)
								OB.pixel_y = pixel_y-32
								OB.dir = dir
							else
								OB.pixel_y = pixel_y+32
								OB.dir = dir
						else
							OB.pixel_x = pixel_x+16
							OB.pixel_y = pixel_y+20
							OB.dir = dir
					if (EAST, WEST)
						if (istype(OB, /obj/structure/cannon))
							OB.pixel_y = pixel_y
							if (dir == WEST)
								OB.pixel_x = pixel_x-32
								OB.dir = dir
							else
								OB.pixel_x = pixel_x+32
								OB.dir = dir
						else
							OB.pixel_x = pixel_x+32
							OB.pixel_y = pixel_y+10
							OB.dir = dir

/obj/structure/vehicle/boat/sailboat/attackby(obj/item/O as obj, mob/user as mob)
	if (istype(O,/obj/item/weapon/hammer) && !not_disassemblable)
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		user << "<span class='notice'>You begin dismantling \the [src].</span>"
		if (do_after(user,25,src))
			user << "<span class='notice'>You dismantle \the [src].</span>"//We lose some materials in the process. Some wood is no longer useful as raw.
			new /obj/item/sail(get_turf(src))
			var /obj/item/stack/material/wood/W = new /obj/item/stack/material/wood(get_turf(src))
			W.amount += 9 //adds 9 boards to the stack, making it 10
			qdel(src)
			return
	else
		..()

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

/obj/structure/vehicle/boat/MouseDrop_T(atom/A, mob/living/human/user)
	if (istype(A, /mob/living/human))
		var/mob/living/human/M = A
		if (M.anchored == FALSE && M.driver == FALSE && !(M in ontop))
			visible_message("<div class='notice'>[M] starts getting on \the [src]...</div>","<div class='notice'>You start going on \the [src]...</div>")
			if (do_after(M, 40, src))
				visible_message("<div class='notice'>[M] sucessfully climbs into \the [src].</div>","<div class='notice'>You sucessfully climb into \the [src].</div>")
				M.plane = GAME_PLANE
				M.forceMove(get_turf(src))
				if (!driver)
					if (wheeled)
						if (M.put_in_active_hand(dwheel) == FALSE)
							M << "Your hands are full!"
							return

					M.driver = TRUE
					M.driver_vehicle = src
					driver = M
					buckle_mob(driver)
					ontop += M
					updatepassdir()
				else if (!currentcap)
					currentcap = M
					ontop += M
					M.anchored = TRUE
					updatepassdir()
				update_overlay()
				update_icon()
				return
	else if (istype(A, /obj))
		if (src == A)
			return
		var/obj/structure/O = A
		if (O.anchored == FALSE && !(O in ontop_o) && ontop_o.len < storagecapacity)
			visible_message("<div class='notice'>[user] starts putting \the [O] on \the [src]...</div>","<div class='notice'>You start putting \the [O] on \the [src]...</div>")
			if (do_after(user, 40, src) && ontop_o.len < storagecapacity)
				visible_message("<div class='notice'>[user] sucessfully puts \the [O] on \the [src].</div>","<div class='notice'>You sucessfully put \the [O] on \the [src].</div>")
				O.pixel_x = pixel_x+16
				O.pixel_y = pixel_y+16
				ontop_o += O
				O.dir = dir
				O.anchored = TRUE
				if (istype(O, /obj/structure/cannon))
					O.x = x
					O.y = y
					O.pixel_x = pixel_x
					O.pixel_y = pixel_y
					O.icon = 'icons/obj/cannon.dmi'
				update_overlay()
				update_icon()
				return

/obj/structure/vehicle/boat/attack_hand(mob/living/human/user as mob)
	if ((user in ontop))
		visible_message("<div class='notice'>[user] start leaving \the [src]...</div>","<div class='notice'>You start going on \the [src]...</div>")
		if (do_after(user, 30, src))
			visible_message("<div class='notice'>[user] sucessfully leaves \the [src].</div>","<div class='notice'>You leave \the [src].</div>")
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
			else if (currentcap)
				currentcap = null
				ontop -= user
				user.anchored = FALSE
				updatepassdir()
			update_overlay()
			update_icon()
			return
	else if (ontop_o.len > 0)
		for (var/obj/structure/O in ontop_o)
			O.anchored = FALSE
			ontop_o -= O
			O.pixel_x = 0
			O.pixel_y = 0
			O.dir = dir
			visible_message("[user] takes \the [O] from \the [src].","You take \the [O] from \the [src].")
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
				user << "\The [W] has no acceptable fuel in it."
				update_customdesc()
				return
			for (var/i in engine.fuels)
				if (GC.reagents.has_reagent(i))
					if (GC.reagents.get_reagent_amount(i)<= fueltank.reagents.maximum_volume-fueltank.reagents.total_volume)
						fueltank.reagents.add_reagent(i,GC.reagents.get_reagent_amount(i))
						GC.reagents.del_reagent(i)
						user << "You empty \the [W] into the fueltank."
						update_customdesc()
						return
					else
						var/amttransf = fueltank.reagents.maximum_volume-fueltank.reagents.total_volume
						fueltank.reagents.add_reagent(i,amttransf)
						GC.reagents.remove_reagent(i,amttransf)
						user << "You fill the fueltank completly with \the [W]."
						update_customdesc()
						return
		else
			user << "The fueltank is full already."
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
					user << "You turn off the engine."
					set_light(0)
					playsound(loc, engine.ending_snd, 65, FALSE, 2)
					return

			visible_message("<div class='notice'>[user] start leaving \the [src]...</div>","<div class='notice'>You start going on \the [src]...</div>")
			if (do_after(user, 30, src))
				visible_message("<div class='notice'>[user] sucessfully leaves \the [src].</div>","<div class='notice'>You leave \the [src].</div>")
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
				else if (!currentcap)
					currentcap = null
					ontop -= user
					user.anchored = FALSE
					updatepassdir()
				update_overlay()
				update_icon()
				return
	else
		..()
/obj/structure/vehicle/boat/do_vehicle_check()
	update_customdesc()
	if (istype(get_turf(get_step(src,driver.dir)), /turf/floor/beach/water) || istype(get_turf(get_step(src,driver.dir)), /turf/floor/trench/flooded))
		if (driver in get_turf(loc))
			return TRUE
		else
			driver.driver = FALSE
			driver.driver_vehicle = null
			driver << "You leave the [src]."
			unbuckle_mob()
			update_overlay()
			update_icon()
			ontop -= driver
			driver = null
	else
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
	if (check_engine())
		var/turf/T = get_turf(get_step(src,driver.dir))
		if (!T)
			moving = FALSE
			stopmovementloop()
			return FALSE
		var/blocked = 0
		for(var/obj/structure/O in get_turf(get_step(src,driver.dir)))
			if (O.density == TRUE)
				blocked = 1
				visible_message("<span class='warning'>\the [src] hits \the [O]!</span>","<span class='warning'>You hit \the [O]!</span>")
		if (get_turf(get_step(src,driver.dir)).density == TRUE)
			blocked = 1
			visible_message("<span class='warning'>\the [src] hits \the [get_turf(get_step(src,driver.dir))]!</span>","<span class='warning'>You hit \the [get_turf(get_step(src,driver.dir))]!</span>")
		for(var/obj/covers/CV in get_turf(get_step(src,driver.dir)))
			if (CV.density == TRUE)
				blocked = 1
				visible_message("<span class='warning'>\the [src] hits \the [CV]!</span>","<span class='warning'>You hit \the [CV]!</span>")
		for(var/mob/living/L in get_turf(get_step(src,driver.dir)))
			if (ishuman(L))
				var/mob/living/human/HH = L
				HH.adjustBruteLoss(rand(7,16)*axis.currentspeed)
				HH.Weaken(rand(2,5))
				blocked = 1
				visible_message("<span class='warning'>\the [src] hits \the [L]!</span>","<span class='warning'>You hit \the [L]!</span>")
			else if (istype(L,/mob/living/simple_animal))
				var/mob/living/simple_animal/SA = L
				SA.health -= rand(7,16)*axis.currentspeed
				if (SA.mob_size >= 30)
					blocked = 1
					visible_message("<span class='warning'>\the [src] hits \the [SA]!</span>","<span class='warning'>You hit \the [SA]!</span>")
				else
					visible_message("<span class='warning'>\the [src] runs over \the [SA]!</span>","<span class='warning'>You run over \the [SA]!</span>")
		if (blocked)
			moving = FALSE
			health -= rand(3,4)*axis.currentspeed
			driver.adjustBruteLoss(rand(3,4)*axis.currentspeed)
			if (axis.currentspeed >= 3 || (axis.currentspeed == 2 && prob(50)))
				visible_message("<span class='warning'>[driver] falls from \the [src]!</span>","<span class='warning'>You fall from \the [src]!</span>")
				stopmovementloop()
				driver.SpinAnimation(5,1)
				if (isturf(locate(x+1,y,z)))
					driver.forceMove(locate(x+1,y,z))
				else if (isturf(locate(x-1,y,z)))
					driver.forceMove(locate(x+1,y,z))
				else
					driver.forceMove(locate(x,y,z))
				driver.Weaken(5)
				driver.adjustBruteLoss(rand(8,19))
				if (!driver.head)
					driver << "<span class='warning'>Your head hits the ground!</span>"
					driver.adjustBrainLoss(rand(5,8))
				if (driver.head && !istype(driver.head, /obj/item/clothing/head/helmet))
					driver << "<span class='warning'>Your head hits the ground!</span>"
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
		for(var/obj/covers/CVV in get_turf(get_step(src,driver.dir)))
			if (CVV.density == FALSE)
				canpass = TRUE
		if ((!istype(get_turf(get_step(src,driver.dir)), /turf/floor/beach/water/deep) ||  istype(get_turf(get_step(src,driver.dir)), /turf/floor/beach/water/deep) && canpass == TRUE)&& get_turf(get_step(src,driver.dir)).density == FALSE  || istype(get_turf(get_step(src,driver.dir)), /turf/floor/trench/flooded))
			if (driver in src.loc)
				return TRUE
			else
				driver.driver = FALSE
				driver.driver_vehicle = null
				driver << "You leave the [src]."
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
	else
		moving = FALSE
		stopmovementloop()
		return FALSE

/obj/structure/vehicle/motorcycle/check_engine()

	if (!engine || !fueltank)
		return FALSE
	else
		if (fueltank.reagents.total_volume <= 0)
			fueltank.reagents.total_volume = 0
			return FALSE
		else
			if (engine.on)
				return TRUE
			else
				return FALSE
		return FALSE

	return TRUE

/obj/structure/vehicle/motorcycle/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/glass))
		var/obj/item/weapon/reagent_containers/glass/GC = W
		if (fueltank.reagents.total_volume < fueltank.reagents.maximum_volume)
			if (GC.reagents.has_reagent("gasoline"))
				if (GC.reagents.get_reagent_amount("gasoline")<= fueltank.reagents.maximum_volume-fueltank.reagents.total_volume)
					fueltank.reagents.add_reagent("gasoline",GC.reagents.get_reagent_amount("gasoline"))
					GC.reagents.del_reagent("gasoline")
					user << "You empty \the [W] into the fueltank."
					update_customdesc()
					return
				else
					var/amttransf = fueltank.reagents.maximum_volume-fueltank.reagents.total_volume
					fueltank.reagents.add_reagent("gasoline",amttransf)
					GC.reagents.remove_reagent("gasoline",amttransf)
					user << "You fill the fueltank completly with \the [W]."
					update_customdesc()
					return
			else
				user << "\The [W] has no gasoline in it."
				update_customdesc()
				return
		else
			user << "The fueltank is full already."
			update_customdesc()
			return
	else
		..()

/obj/structure/vehicle/motorcycle/do_color(_color = null)
	var/tempcolor = customcolor
	if (_color != null)
		tempcolor = _color
	if (tempcolor)
		var/image/colorov = image("icon" = icon, "icon_state" = "[icon_state]_mask1")
		colorov.color = tempcolor
		overlays += colorov

/obj/structure/vehicle/carriage
	name = "Carriage"
	icon = 'icons/obj/vehicles/vehicles96x96.dmi'
	icon_state = "simple_carriage"
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = FALSE
	vehicle_m_delay = 12
	layer = 3.9
	health = 150
	axis =  new/obj/structure/vehicleparts/axis/carriage
	wheeled = TRUE
	dwheel = new/obj/item/vehicleparts/wheel/rope
	var/image/cover_overlay = null
	var/image/cover_overlay_c = null
	var/maxcapacity = 0 //besides the driver
	var/mob/living/human/currentcap = null
	bound_width = 64
	bound_height = 96
	mobcapacity = 7
	storagecapacity = null //This is rekting my crates pixel location
	var/max_animal_propulsion = 8
	var/buckled_animal_propulsion = 0
	var/mob/living/simple_animal/pulling1 = null
	var/mob/living/simple_animal/pulling2 = null
	var/mob/living/simple_animal/pulling3 = null
	var/mob/living/simple_animal/pulling4 = null
	var/bucklepoint1 = null
	var/bucklepoint2 = null
	var/bucklepoint3 = null
	var/bucklepoint4 = null
	var/bucklepoint5 = null
	var/total_cargo = 5
	var/current_cargo = 0
	pixel_x = -18
	pixel_y = -10

/obj/structure/vehicle/carriage/MouseDrop_T(atom/A, mob/living/human/user)
	if(istype(A, /turf) || istype(A, /area)) //failsafe
		return
	if(A in ontop)	//Removing a passenger/mob-cargo or pulling animal?
		if (istype(A, /mob/living) && (A != pulling1 && A != pulling2 && A != pulling3 && A != pulling4))
			var/mob/living/M = A
			if(A == user && M == driver) //The driver shouldnt unbuckle himself like this
				return
			visible_message("<div class='notice'>[user] start to remove [M] from the [src]...</div>")
			if (do_after(user, 30, src))
				if(bucklepoint1 == M)
					bucklepoint1 = null
				else if(bucklepoint2 == M)
					bucklepoint2 = null
				else if(bucklepoint3 == M)
					bucklepoint3 = null
				else if(bucklepoint4 == M)
					bucklepoint4 = null
				else if(bucklepoint5 == M)
					bucklepoint5 = null
				visible_message("<div class='notice'>[user] sucessfully removes [M] from the [src].</div>")
				ontop -= M
				M.pixel_x = 0
				M.pixel_y = 0
				unbuckle_mob()
				buckled_mob = null
				M.buckled = null
				current_cargo -= 1
				return
		else if(A == pulling1 || A == pulling2 || A == pulling3 || A == pulling4) //Removing a pulling animal?
			if(istype(A, /mob/living/simple_animal/cattle))
				var/mob/living/simple_animal/cattle/M = A
				visible_message("<div class='notice'>[user] tries to untie the [A] from the [src]...</div>")
				if (do_after(user, 40, src))
					if(M == pulling1)
						pulling1 = null
						ontop -= pulling1
					else if(M == pulling2)
						pulling2 = null
						ontop -= pulling2
					else if(M == pulling3)
						pulling3 = null
						ontop -= pulling3
					else if(M == pulling4)
						pulling4 = null
						ontop -= pulling4
					visible_message("<div class='notice'>[user]  unties the [A] from the [src]...</div>")
					ontop -= M
					buckled_animal_propulsion -= 1
					M.buckled = null
					M.pixel_y = 0
					M.pixel_x = 0
			else if(istype(A, /mob/living/simple_animal/horse))
				var/mob/living/simple_animal/horse/M = A
				visible_message("<div class='notice'>[user] tries to untie the [A] from the [src]...</div>")
				if (do_after(user, 40, src))
					if(M == pulling1)
						pulling1 = null
						ontop -= pulling1
					else if(M == pulling2)
						pulling2 = null
						ontop -= pulling2
					else if(M == pulling3)
						pulling3 = null
						ontop -= pulling3
					else if(M == pulling4)
						pulling4 = null
						ontop -= pulling4
					visible_message("<div class='notice'>[user]  unties the [A] from the [src]...</div>")
					ontop -= M
					buckled_animal_propulsion -= 2
					M.buckled = null
					M.pixel_y = 0
					M.pixel_x = 0
	else if(A in ontop_o)	//Removing a cargo object?
		if(istype(A, /obj/structure))
			var/obj/structure/M = A
			if (do_after(user, 30, src))
				if(bucklepoint1 == M)
					bucklepoint1 = null
				else if(bucklepoint2 == M)
					bucklepoint2 = null
				else if(bucklepoint3 == M)
					bucklepoint3 = null
				else if(bucklepoint4 == M)
					bucklepoint4 = null
				else if(bucklepoint5 == M)
					bucklepoint5 = null
				M.anchored = FALSE
				ontop_o -= M
				M.pixel_x = 0
				M.pixel_y = 0
				visible_message("[user] takes \the [M] from \the [src].","You take \the [M] from \the [src].")
				current_cargo -= 1
				M.layer -= src.layer
				return
	else if (istype(A, /mob/living/human) && A == user && !driver) //Placing yourself as driver
		var/mob/living/human/M = A
		if(!(M in ontop) && M.driver == FALSE)
			if (do_after(M, 40, src))
				M.plane = GAME_PLANE
				visible_message("<div class='notice'>[M] starts getting on \the driver seat of the [src]...</div>")
				if (wheeled)
					if (M.put_in_active_hand(dwheel) == FALSE)
						M << "Your hands are full!"
						return
				M.forceMove(get_turf(src))
				M.driver = TRUE
				M.driver_vehicle = src
				driver = M
				buckle_mob(driver)
				M.pixel_x = 0
				M.pixel_y = 0
				ontop += M
				switch (dir)
					if (SOUTH)
						M.pixel_x = 27
						M.pixel_y = 0
						M.dir = SOUTH
					if (NORTH)
						M.pixel_x = 25
						M.pixel_y = 58
						M.dir = NORTH
					if (EAST)
						M.pixel_x = 42
						M.pixel_y = 18
						M.dir = EAST
					if (WEST)
						M.pixel_x = -18
						M.pixel_y = 16
						M.dir = WEST
				visible_message("<div class='notice'>[M] sucessfully climbs into the [src]'s driver seat.</div>")
		return
	else if(istype(A, /mob/living/simple_animal/cattle) && (buckled_animal_propulsion < max_animal_propulsion)) //Attaching a pulling animal?
		var/mob/living/simple_animal/cattle/M = A
		if(pulling1 == null || pulling2 == null || pulling3 == null || pulling4 == null)
			user.visible_message("[user] tries to tie the [M] to the [src].")
			if(do_after(user, 30, src))
				buckle_mob(M)
				ontop += M
				M.buckled = 1
				user.visible_message("[user] ties the [M] to the [src].")
				if(!pulling1)
					pulling1 = M
				else if(!pulling2)
					pulling2 = M
				else if(!pulling3)
					pulling3 = M
				else if(!pulling4)
					pulling4 = M
				buckled_animal_propulsion += 1
				updatepassdir()
				M.forceMove(get_turf(src))
				return
	else if(istype(A, /mob/living/simple_animal/horse) && (buckled_animal_propulsion < max_animal_propulsion)) //Attaching a pulling animal?
		var/mob/living/simple_animal/horse/M = A
		if(pulling1 == null || pulling2 == null || pulling3 == null || pulling4 == null)
			user.visible_message("[user] tries to tie the [M] to the [src].")
			if(do_after(user, 30, src))
				buckle_mob(M)
				ontop += M
				M.buckled = 1
				user.visible_message("[user] ties the [M] to the [src].")
				if(!pulling1)
					pulling1 = M
				else if(!pulling2)
					pulling2 = M
				else if(!pulling3)
					pulling3 = M
				else if(!pulling4)
					pulling4 = M
				buckled_animal_propulsion += 2
				updatepassdir()
				M.forceMove(get_turf(src))
				return
	else if((current_cargo < total_cargo) && (!(A in ontop) || !(A in ontop_o))) //Placing a cargo object or human passenger?
		var/seat = null
		if(A != driver && (A != pulling1 && A != pulling2 && A != pulling3 && A != pulling4))
			if(A == user) //Passenger climbing by himself
				visible_message("<div class='notice'>[user] starts climbing on the [src] as a passenger...</div>")
			else
				visible_message("<div class='notice'>[user] tries to place [A] over the carriage...</div>")
			if(!bucklepoint1)
				if(istype(A, /mob/living))
					var/mob/living/M = A
					if (do_after(user, 30, src))
						buckle_mob(M)
						ontop += M
						M.buckled = 1
						bucklepoint1 = M
						current_cargo += 1
						seat = 1
				else if(istype(A, /obj/structure))
					var/obj/structure/M = A
					if (M.anchored == FALSE && !(M in ontop_o) && ontop_o.len < total_cargo && M != src)
						if (do_after(user, 30, src))
							ontop_o += M
							M.anchored = TRUE
							M.dir = dir
							bucklepoint1 = M
							current_cargo += 1
							seat = 1
			else if(!bucklepoint2)
				if(istype(A, /mob/living))
					var/mob/living/M = A
					if (do_after(user, 30, src))
						buckle_mob(M)
						ontop += M
						M.buckled = 1
						bucklepoint2 = M
						current_cargo += 1
						seat = 2
				else if(istype(A, /obj/structure))
					var/obj/structure/M = A
					if (M.anchored == FALSE && !(M in ontop_o) && ontop_o.len < total_cargo && M != src)
						if (do_after(user, 30, src))
							ontop_o += M
							M.anchored = TRUE
							M.dir = dir
							bucklepoint2 = M
							current_cargo += 1
							seat = 2
			else if(!bucklepoint3)
				if(istype(A, /mob/living))
					if (do_after(user, 30, src))
						var/mob/living/M = A
						buckle_mob(M)
						ontop += M
						M.buckled = 1
						bucklepoint3 = M
						current_cargo += 1
						seat = 3
				else if(istype(A, /obj/structure))
					var/obj/structure/M = A
					if (M.anchored == FALSE && !(M in ontop_o) && ontop_o.len < total_cargo && M != src)
						if (do_after(user, 30, src))
							ontop_o += M
							M.anchored = TRUE
							M.dir = dir
							bucklepoint3 = M
							current_cargo += 1
							seat = 3
			else if(!bucklepoint4)
				if(istype(A, /mob/living))
					if (do_after(user, 30, src))
						var/mob/living/M = A
						buckle_mob(M)
						ontop += M
						M.buckled = 1
						bucklepoint4 = M
						current_cargo += 1
						seat = 4
				else if(istype(A, /obj/structure))
					var/obj/structure/M = A
					if (M.anchored == FALSE && !(M in ontop_o) && ontop_o.len < total_cargo && M != src)
						if (do_after(user, 30, src))
							ontop_o += M
							M.anchored = TRUE
							M.dir = dir
							bucklepoint4 = M
							current_cargo += 1
							seat = 4
			else if(!bucklepoint5)
				if(istype(A, /mob/living))
					if (do_after(user, 30, src))
						var/mob/living/M = A
						buckle_mob(M)
						ontop += M
						M.buckled = 1
						bucklepoint5 = M
						current_cargo += 1
						seat = 5
				else if(istype(A, /obj/structure))
					var/obj/structure/M = A
					if (M.anchored == FALSE && !(M in ontop_o) && ontop_o.len < total_cargo && M != src)
						if (do_after(user, 30, src))
							ontop_o += M
							M.anchored = TRUE
							M.dir = dir
							bucklepoint5 = M
							current_cargo += 1
							seat = 5
		if(seat)	//Updates the mob/obj pixel deviation
			if(istype(A, /obj/structure))	//Moves obj or mob to carriage's turf location so the pixel deviation can be precise
				var/obj/structure/M = A
				M.layer += src.layer
				M.forceMove(get_turf(src))
			else if(istype(A, /mob/living))
				var/mob/living/M = A
				M.forceMove(get_turf(src))
			visible_message("<div class='notice'>[user] sucessfully places [A] over the carriage...</div>")
			switch(seat)
				if(1)
					A.pixel_x = pixel_x
					A.pixel_y = pixel_y
					switch (dir)
						if (SOUTH)
							A.pixel_x += 18
							A.pixel_y += 10
							A.dir = SOUTH
						if (NORTH)
							A.pixel_x += 18
							A.pixel_y += 68
							A.dir = NORTH
						if (EAST)
							A.pixel_x += 60
							A.pixel_y += 50
							A.dir = EAST
						if (WEST)
							A.pixel_x += 0
							A.pixel_y += 52
							A.dir = WEST
				if(2)
					switch (dir)
						if (SOUTH)
							A.pixel_x = 27
							A.pixel_y = 28
							A.dir = SOUTH
						if (NORTH)
							A.pixel_x = 25
							A.pixel_y = 26
							A.dir = NORTH
						if (EAST)
							A.pixel_x = 13
							A.pixel_y = 18
							A.dir = EAST
						if (WEST)
							A.pixel_x = 18
							A.pixel_y = 16
							A.dir = WEST
				if(3)
					switch (dir)
						if (SOUTH)
							A.pixel_x = 3
							A.pixel_y = 28
							A.dir = SOUTH
						if (NORTH)
							A.pixel_x = 0
							A.pixel_y = 26
							A.dir = NORTH
						if (EAST)
							A.pixel_x = 13
							A.pixel_y = 42
							A.dir = EAST
						if (WEST)
							A.pixel_x = 18
							A.pixel_y = 40
							A.dir = WEST
				if(4)
					switch (dir)
						if (SOUTH)
							A.pixel_x = 3
							A.pixel_y = 58
							A.dir = SOUTH
						if (NORTH)
							A.pixel_x = 0
							A.pixel_y = 0
							A.dir = NORTH
						if (EAST)
							A.pixel_x = -15
							A.pixel_y = 42
							A.dir = EAST
						if (WEST)
							A.pixel_x = 46
							A.pixel_y = 40
							A.dir = WEST
				if(5)
					switch (dir)
						if (SOUTH)
							A.pixel_x = 27
							A.pixel_y = 58
							A.dir = SOUTH
						if (NORTH)
							A.pixel_x = 26
							A.pixel_y = 0
							A.dir = NORTH
						if (EAST)
							A.pixel_x = -15
							A.pixel_y = 18
							A.dir = EAST
						if (WEST)
							A.pixel_x = 46
							A.pixel_y = 16
							A.dir = WEST
			seat = null
	update_overlay()
	update_icon()
	return

/obj/structure/vehicle/carriage/updatepassdir()
	if (driver)
		driver.pixel_x = 0
		driver.pixel_y = 0
		switch (dir)
			if (SOUTH)
				driver.pixel_x = 27
				driver.pixel_y = 0
				driver.dir = SOUTH
			if (NORTH)
				driver.pixel_x = 25
				driver.pixel_y = 58
				driver.dir = NORTH
			if (EAST)
				driver.pixel_x = 42
				driver.pixel_y = 18
				driver.dir = EAST
			if (WEST)
				driver.pixel_x = -18
				driver.pixel_y = 16
				driver.dir = WEST
		if (!(driver in range(1,src)))
			ontop -= driver
			driver.anchored = FALSE
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
	if(pulling1)
		var/mob/living/simple_animal/cattle/M = pulling1
		M.pixel_x = pixel_x
		M.pixel_y = pixel_y
		switch (dir)
			if (SOUTH)
				M.pixel_x = 0
				M.pixel_y = -32
				M.dir = SOUTH
			if (NORTH)
				M.pixel_x = 0
				M.pixel_y = 88
				M.dir = NORTH
			if (EAST)
				M.pixel_x = 75
				M.pixel_y = 42
				M.dir = EAST
			if (WEST)
				M.pixel_x = -47
				M.pixel_y = 43
				M.dir = WEST
		var/mob/living/simple_animal/horse/H = pulling1
		H.pixel_x = pixel_x
		H.pixel_y = pixel_y
		switch (dir)
			if (SOUTH)
				H.pixel_x = 16
				H.pixel_y = -57
				H.dir = SOUTH
			if (NORTH)
				H.pixel_x = 16
				H.pixel_y = 88
				H.dir = NORTH
			if (EAST)
				H.pixel_x = 68
				H.pixel_y = 22
				H.dir = EAST
			if (WEST)
				H.pixel_x = -68
				H.pixel_y = 22
				H.dir = WEST
	if(pulling2)
		var/mob/living/simple_animal/cattle/M = pulling2
		M.pixel_x = pixel_x
		M.pixel_y = pixel_y
		switch (dir)
			if (SOUTH)
				M.pixel_x = 28
				M.pixel_y = -32
				M.dir = SOUTH
			if (NORTH)
				M.pixel_x = 26
				M.pixel_y = 88
				M.dir = NORTH
			if (EAST)
				M.pixel_x = 55
				M.pixel_y = 32
				M.dir = EAST
			if (WEST)
				M.pixel_x = -62
				M.pixel_y = 32
				M.dir = WEST
		var/mob/living/simple_animal/horse/H = pulling2
		H.pixel_x = pixel_x
		H.pixel_y = pixel_y
		switch (dir)
			if (SOUTH)
				H.pixel_x = -12
				H.pixel_y = -57
				H.dir = SOUTH
			if (NORTH)
				H.pixel_x = -16
				H.pixel_y = 88
				H.dir = NORTH
			if (EAST)
				H.pixel_x = 68
				H.pixel_y = 2
				H.dir = EAST
			if (WEST)
				H.pixel_x = -68
				H.pixel_y = 2
				H.dir = WEST
	if(pulling3)
		var/mob/living/simple_animal/cattle/M = pulling3
		M.pixel_x = pixel_x
		M.pixel_y = pixel_y
		switch (dir)
			if (SOUTH)
				M.pixel_x = 0
				M.pixel_y = -62
				M.dir = SOUTH
			if (NORTH)
				M.pixel_x = 0
				M.pixel_y = 118
				M.dir = NORTH
			if (EAST)
				M.pixel_x = 95
				M.pixel_y = 42
				M.dir = EAST
			if (WEST)
				M.pixel_x = -77
				M.pixel_y = 43
				M.dir = WEST
		var/mob/living/simple_animal/horse/H = pulling3
		H.pixel_x = pixel_x
		H.pixel_y = pixel_y
		switch (dir)
			if (SOUTH)
				H.pixel_x = 16
				H.pixel_y = -88
				H.dir = SOUTH
			if (NORTH)
				H.pixel_x = 16
				H.pixel_y = 132
				H.dir = NORTH
			if (EAST)
				H.pixel_x = 125
				H.pixel_y = 22
				H.dir = EAST
			if (WEST)
				H.pixel_x = -117
				H.pixel_y = 22
				H.dir = WEST
	if(pulling4)
		var/mob/living/simple_animal/cattle/M = pulling4
		M.pixel_x = pixel_x
		M.pixel_y = pixel_y
		switch (dir)
			if (SOUTH)
				M.pixel_x = 38
				M.pixel_y = -62
				M.dir = SOUTH
			if (NORTH)
				M.pixel_x = 26
				M.pixel_y = 118
				M.dir = NORTH
			if (EAST)
				M.pixel_x = 95
				M.pixel_y = 15
				M.dir = EAST
			if (WEST)
				M.pixel_x = -77
				M.pixel_y = 15
				M.dir = WEST
		var/mob/living/simple_animal/horse/H = pulling4
		H.pixel_x = pixel_x
		H.pixel_y = pixel_y
		switch (dir)
			if (SOUTH)
				H.pixel_x = -12
				H.pixel_y = -88
				H.dir = SOUTH
			if (NORTH)
				H.pixel_x = -16
				H.pixel_y = 132
				H.dir = NORTH
			if (EAST)
				H.pixel_x = 125
				H.pixel_y = 2
				H.dir = EAST
			if (WEST)
				H.pixel_x = -117
				H.pixel_y = 2
				H.dir = WEST
	if(bucklepoint1)
		var/atom/M = bucklepoint1
		M.pixel_x = pixel_x
		M.pixel_y = pixel_y
		switch (dir)
			if (SOUTH)
				M.pixel_x += 18
				M.pixel_y += 10
				M.dir = SOUTH
			if (NORTH)
				M.pixel_x += 18
				M.pixel_y += 68
				M.dir = NORTH
			if (EAST)
				M.pixel_x += 60
				M.pixel_y += 50
				M.dir = EAST
			if (WEST)
				M.pixel_x += 0
				M.pixel_y += 52
				M.dir = WEST

	if(bucklepoint2)
		var/atom/M = bucklepoint2
		M.pixel_x = 0
		M.pixel_y = 0
		switch (dir)
			if (SOUTH)
				M.pixel_x = 27
				M.pixel_y = 28
				M.dir = SOUTH
			if (NORTH)
				M.pixel_x = 25
				M.pixel_y = 26
				M.dir = NORTH
			if (EAST)
				M.pixel_x = 13
				M.pixel_y = 18
				M.dir = EAST
			if (WEST)
				M.pixel_x = 18
				M.pixel_y = 16
				M.dir = WEST

	if(bucklepoint3)
		var/atom/M = bucklepoint3
		M.pixel_x = 0
		M.pixel_y = 0
		switch (dir)
			if (SOUTH)
				M.pixel_x = 3
				M.pixel_y = 28
				M.dir = SOUTH
			if (NORTH)
				M.pixel_x = 0
				M.pixel_y = 26
				M.dir = NORTH
			if (EAST)
				M.pixel_x = 13
				M.pixel_y = 42
				M.dir = EAST
			if (WEST)
				M.pixel_x = 18
				M.pixel_y = 40
				M.dir = WEST

	if(bucklepoint4)
		var/atom/M = bucklepoint4
		M.pixel_x = 0
		M.pixel_y = 0
		switch (dir)
			if (SOUTH)
				M.pixel_x = 3
				M.pixel_y = 58
				M.dir = SOUTH
			if (NORTH)
				M.pixel_x = 0
				M.pixel_y = 0
				M.dir = NORTH
			if (EAST)
				M.pixel_x = -15
				M.pixel_y = 42
				M.dir = EAST
			if (WEST)
				M.pixel_x = 46
				M.pixel_y = 40
				M.dir = WEST

	if(bucklepoint5)
		var/atom/M = bucklepoint5
		M.pixel_x = 0
		M.pixel_y = 0
		switch (dir)
			if (SOUTH)
				M.pixel_x = 27
				M.pixel_y = 58
				M.dir = SOUTH
			if (NORTH)
				M.pixel_x = 26
				M.pixel_y = 0
				M.dir = NORTH
			if (EAST)
				M.pixel_x = -15
				M.pixel_y = 18
				M.dir = EAST
			if (WEST)
				M.pixel_x = 46
				M.pixel_y = 16
				M.dir = WEST
	if (currentcap)
		currentcap.pixel_x = pixel_x
		currentcap.pixel_y = pixel_y
		switch (dir)
			if (SOUTH)
				currentcap.pixel_x += 10
				currentcap.pixel_y += 33
			if (NORTH)
				currentcap.pixel_x += 25
				currentcap.pixel_y += 11
			if (EAST)
				currentcap.pixel_x += 5
				currentcap.pixel_y += 19
			if (WEST)
				currentcap.pixel_x += 31
				currentcap.pixel_y += 19
		if (!(currentcap in range(1,src)))
			ontop -= currentcap
			currentcap.anchored = FALSE
			currentcap = null

/obj/structure/vehicle/carriage/attack_hand(mob/living/human/user as mob)
	if ((user in ontop))
		visible_message("<div class='notice'>[user] start leaving \the [src]...</div>","<div class='notice'>You start going on \the [src]...</div>")
		if (do_after(user, 30, src))
			if(bucklepoint1 == user)
				bucklepoint1 = null
			else if(bucklepoint2 == user)
				bucklepoint2 = null
			else if(bucklepoint3 == user)
				bucklepoint3 = null
			else if(bucklepoint4 == user)
				bucklepoint4 = null
			else if(bucklepoint5 == user)
				bucklepoint5 = null
			visible_message("<div class='notice'>[user] sucessfully leaves \the [src].</div>","<div class='notice'>You leave \the [src].</div>")
			if (user == driver)
				user.driver = FALSE
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
						ontop -= user
			else
				current_cargo -= 1 //The driver doesnt counts as cargo. Just passengers
			user.pixel_x = 0
			user.pixel_y = 0
			user.buckled = null
			unbuckle_mob()
			buckled_mob = null
			update_overlay()
			update_icon()
			ontop -= user
			return

/obj/structure/vehicle/carriage/do_vehicle_check()
	var/turf/t1 = null
	var/turf/t2 = null
	switch (dir)
		if (SOUTH)
			t1 = get_turf(get_step(locate(x, y, z),driver.dir))
			t2 = get_turf(get_step(locate(x+1, y, z),driver.dir))
		if (NORTH)
			t1 = get_turf(get_step(locate(x, y+2, z),driver.dir))
			t2 = get_turf(get_step(locate(x+1, y+2, z),driver.dir))
		if (EAST)
			t1 = get_turf(get_step(locate(x+2, y, z),driver.dir))
			t2 = get_turf(get_step(locate(x+2, y+1, z),driver.dir))
		if (WEST)
			t1 = get_turf(get_step(locate(x-1, y, z),driver.dir))
			t2 = get_turf(get_step(locate(x-1, y+1, z),driver.dir))
	if (!t1 || !t2)
		moving = FALSE
		stopmovementloop()
		return FALSE
	var/blocked = 0
	for(var/obj/structure/O in t1)
		if (O.density == TRUE && O != src)
			blocked = 1
			visible_message("<span class='warning'>\the [src] hits \the [O]!</span>","<span class='warning'>You hit \the [O]!</span>")
			break
	for(var/obj/structure/O in t2)
		if (O.density == TRUE && O != src)
			blocked = 1
			visible_message("<span class='warning'>\the [src] hits \the [O]!</span>","<span class='warning'>You hit \the [O]!</span>")
			break
	if (t1.density == TRUE || t2.density == TRUE)
		blocked = 1
		var/blocking = null
		if(t1.density)
			blocking = t1
		else
			blocking = t2
		visible_message("<span class='warning'>\the [src] hits \the [blocking]!</span>","<span class='warning'>You hit \the [get_turf(get_step(src,driver.dir))]!</span>")
	for(var/obj/covers/CV in t1)
		if (CV.density == TRUE)
			blocked = 1
			visible_message("<span class='warning'>\the [src] hits \the [CV]!</span>","<span class='warning'>You hit \the [CV]!</span>")
			break
	for(var/obj/covers/CV in t2)
		if (CV.density == TRUE)
			blocked = 1
			visible_message("<span class='warning'>\the [src] hits \the [CV]!</span>","<span class='warning'>You hit \the [CV]!</span>")
			break
	for(var/mob/living/L in t1)
		if (ishuman(L))
			var/mob/living/human/HH = L
			HH.adjustBruteLoss(rand(7,16)*axis.currentspeed)
			HH.Weaken(rand(2,5))
			blocked = 1
			visible_message("<span class='warning'>\the [src] hits \the [L]!</span>","<span class='warning'>You hit \the [L]!</span>")
		else if (istype(L,/mob/living/simple_animal))
			var/mob/living/simple_animal/SA = L
			SA.health -= rand(7,16)*axis.currentspeed
			if (SA.mob_size >= 30)
				blocked = 1
				visible_message("<span class='warning'>\the [src] hits \the [SA]!</span>","<span class='warning'>You hit \the [SA]!</span>")
			else
				visible_message("<span class='warning'>\the [src] runs over \the [SA]!</span>","<span class='warning'>You run over \the [SA]!</span>")
	for(var/mob/living/L in t2)
		if (ishuman(L))
			var/mob/living/human/HH = L
			HH.adjustBruteLoss(rand(7,16)*axis.currentspeed)
			HH.Weaken(rand(2,5))
			blocked = 1
			visible_message("<span class='warning'>\the [src] hits \the [L]!</span>","<span class='warning'>You hit \the [L]!</span>")
		else if (istype(L,/mob/living/simple_animal))
			var/mob/living/simple_animal/SA = L
			SA.health -= rand(7,16)*axis.currentspeed
			if (SA.mob_size >= 30)
				blocked = 1
				visible_message("<span class='warning'>\the [src] hits \the [SA]!</span>","<span class='warning'>You hit \the [SA]!</span>")
			else
				visible_message("<span class='warning'>\the [src] runs over \the [SA]!</span>","<span class='warning'>You run over \the [SA]!</span>")
	if (blocked)
		moving = FALSE
		health -= rand(3,4)*axis.currentspeed
		if (axis.currentspeed >= 3 || (axis.currentspeed == 2 && prob(30)))
			visible_message("<span class='warning'>[driver] falls from \the [src]!</span>","<span class='warning'>You fall from \the [src]!</span>")
			stopmovementloop()
			driver.SpinAnimation(5,1)
			driver.buckled = null
			if (isturf(locate(x+1,y,z)))
				driver.forceMove(locate(x+1,y,z))
			else if (isturf(locate(x-1,y,z)))
				driver.forceMove(locate(x+1,y,z))
			else
				driver.forceMove(locate(x,y,z))
			driver.Weaken(3)
			driver.adjustBruteLoss(rand(0,8))
			if (prob(10)) //10% chance to hit the head hard, inside the 30% chance
				driver << "<span class='warning'>Your head hits the ground!</span>"
				driver.adjustBrainLoss(rand(0,5))
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
			unbuckle_mob() //This is quite broken, doesnt make the buckled_mob null
			buckled_mob = null
			update_overlay()
			update_icon()
			ontop -= driver
			driver = null
			return FALSE
		axis.currentspeed = 0
		stopmovementloop()
		return FALSE
	var/canpass = FALSE
	for(var/obj/covers/CVV in get_turf(get_step(src,driver.dir)))
		if (CVV.density == FALSE)
			canpass = TRUE
	if ((!istype(get_turf(get_step(src,driver.dir)), /turf/floor/beach/water/deep) ||  istype(get_turf(get_step(src,driver.dir)), /turf/floor/beach/water/deep) && canpass == TRUE)&& get_turf(get_step(src,driver.dir)).density == FALSE  || istype(get_turf(get_step(src,driver.dir)), /turf/floor/trench/flooded))
		if (driver in src.loc)
			return TRUE
		else
			driver.driver = FALSE
			driver.driver_vehicle = null
			driver << "You leave the [src]."
			driver.buckled = null
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

/obj/structure/vehicle/carriage/movementloop() //Makes the pulling animals hungry
	if(pulling1 || pulling2 || pulling3 || pulling4)
		if(pulling1)
			if(pulling1.fireloss + pulling1.oxyloss + pulling1.toxloss + pulling1.bruteloss >= pulling1.health) //Is it dead?
				axis.currentspeed = 0
				stopmovementloop()
				visible_message("<span class='warning'>The dead [pulling1.name] stops the [src] from moving!</span>")
				return
			else
				pulling1.simplehunger -= 1 //Each step -1 hunger. Basically doubles it's food comsuption while carrying the carriage
		if(pulling2)
			if(pulling2.fireloss + pulling2.oxyloss + pulling2.toxloss + pulling2.bruteloss >= pulling2.health) //Is it dead?
				axis.currentspeed = 0
				stopmovementloop()
				visible_message("<span class='warning'>The dead [pulling2.name] stops the [src] from moving!</span>")
				return
			else
				pulling2.simplehunger -= 1
		if(pulling3)
			if(pulling3.fireloss + pulling3.oxyloss + pulling3.toxloss + pulling3.bruteloss >= pulling3.health) //Is it dead?
				axis.currentspeed = 0
				stopmovementloop()
				visible_message("<span class='warning'>The dead [pulling2.name] stops the [src] from moving!</span>")
				return
			else
				pulling3.simplehunger -= 1
		if(pulling4)
			if(pulling4.fireloss + pulling4.oxyloss + pulling4.toxloss + pulling4.bruteloss >= pulling4.health) //Is it dead?
				axis.currentspeed = 0
				stopmovementloop()
				visible_message("<span class='warning'>The dead [pulling2.name] stops the [src] from moving!</span>")
				return
			else
				pulling4.simplehunger -= 1
	..()