/obj/structure/vehicle
	name = "vehicle"
	icon = 'icons/obj/vehicleparts.dmi'
	desc = "A vehicle."
	icon_state = "motorcycle"
	var/list/ontop = list()
	var/list/ontop_o = list()
	var/mob/living/carbon/human/driver = null
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
			playsound(loc, 'sound/machines/diesel_loop.ogg', 65, FALSE)
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

/obj/structure/vehicle/MouseDrop_T(atom/A, mob/living/carbon/human/user)
	if (istype(A, /mob/living/carbon/human))
		var/mob/living/carbon/human/M = A
		if (M.anchored == FALSE && M.driver == FALSE && !(M in ontop) && ontop.len < mobcapacity)
			visible_message("<div class='notice'>[M] starts getting on \the [src]...</div>","<div class='notice'>You start going on \the [src]...</div>")
			if (do_after(M, 40, src))
				visible_message("<div class='notice'>[M] sucessfully climbs into \the [src].</div>","<div class='notice'>You sucessfully climb into \the [src].</div>")
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
	else if (istype(A, /obj))
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

/obj/structure/vehicle/attack_hand(mob/living/carbon/human/user as mob)
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

/obj/structure/vehicle/attackby(obj/item/weapon/W as obj, mob/living/carbon/human/user as mob)
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
					playsound(loc, 'sound/machines/diesel_ending.ogg', 65, FALSE, 2)
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
	icon = 'icons/obj/vehicleparts.dmi'
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
	if (istype(get_turf(get_step(src,driver.dir)), /turf/floor/beach/water))
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
            W.add(4)//adds 4 boards to the stack, making it 5
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
	icon = 'icons/obj/vehicleparts64x64.dmi'
	icon_state = "outrigger_frame3"
	anchored = FALSE
	density = FALSE
	opacity = FALSE
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = FALSE
	vehicle_m_delay = 12
	health = 90
	axis = new/obj/structure/vehicleparts/axis/boat
	wheeled = TRUE
	dwheel = new/obj/item/vehicleparts/wheel/rudder
	var/image/cover_overlay = null
	var/image/cover_overlay_c = null
	var/maxcapacity = 1 //besides the driver
	var/mob/living/carbon/human/currentcap = null
	bound_width = 64
	bound_height = 64
	mobcapacity = 2
	storagecapacity = 1

/obj/structure/vehicle/boat/b400
	name = "diesel outrigger"
	desc = "A 400cc, diesel-powered outrigger. Has a 125u fueltank."
	icon_state = "outrigger_frame3"
	health = 130

/obj/structure/vehicle/boat/sailboat
	name = "sailing outrigger"
	desc = "A sailing boat. Powered by the wind."
	icon_state = "outrigger_frame1"
	health = 130
	sails = TRUE
	dwheel = new/obj/item/vehicleparts/wheel/rudder_sails

	New()
		..()
		cover_overlay = image(icon, "sail0")
		cover_overlay.layer = MOB_LAYER + 2.11
		cover_overlay_c = image(icon, "sail")
		cover_overlay_c.layer = MOB_LAYER + 2.12
		add_overlay(cover_overlay)
		update_overlay()
		update_icon()
/obj/structure/vehicle/boat/check_sails()
	var/timer = 15
	if (!sails || !sails_on)
		return
	if (!istype(get_turf(get_step(src,dir)), /turf/floor/beach/water))
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
            W.add(9)//adds 9 boards to the stack, making it 10
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

/obj/structure/vehicle/boat/MouseDrop_T(atom/A, mob/living/carbon/human/user)
	if (istype(A, /mob/living/carbon/human))
		var/mob/living/carbon/human/M = A
		if (M.anchored == FALSE && M.driver == FALSE && !(M in ontop))
			visible_message("<div class='notice'>[M] starts getting on \the [src]...</div>","<div class='notice'>You start going on \the [src]...</div>")
			if (do_after(M, 40, src))
				visible_message("<div class='notice'>[M] sucessfully climbs into \the [src].</div>","<div class='notice'>You sucessfully climb into \the [src].</div>")
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

/obj/structure/vehicle/boat/attack_hand(mob/living/carbon/human/user as mob)
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
/obj/structure/vehicle/boat/attackby(obj/item/weapon/W as obj, mob/living/carbon/human/user as mob)
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
					playsound(loc, 'sound/machines/diesel_ending.ogg', 65, FALSE, 2)
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
	if (istype(get_turf(get_step(src,driver.dir)), /turf/floor/beach/water))
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

/obj/structure/vehicle/boat/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/glass))
		var/obj/item/weapon/reagent_containers/glass/GC = W
		if (fueltank.reagents.total_volume < fueltank.reagents.maximum_volume)
			var/found = FALSE
			for (var/i in engine.fuels)
				if (GC.reagents.has_reagent(i))
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
	else
		..()

///////////////////////////////////////////////////////
/obj/structure/vehicle/motorcycle
	name = "motorcycle"
	desc = "A motorcycle."
	icon = 'icons/obj/vehicleparts.dmi'
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
				var/mob/living/carbon/human/HH = L
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
		if ((!istype(get_turf(get_step(src,driver.dir)), /turf/floor/beach/water/deep) ||  istype(get_turf(get_step(src,driver.dir)), /turf/floor/beach/water/deep) && canpass == TRUE)&& get_turf(get_step(src,driver.dir)).density == FALSE)
			if (driver in src.loc)
				return TRUE
			else
				driver.driver = FALSE
				driver.driver_vehicle = null
				driver << "You leave the [src]."
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

/obj/structure/vehicle/motorcycle/do_color()
	if (customcolor)
		var/image/colorov = image("icon" = icon, "icon_state" = "[icon_state]_mask1")
		colorov.color = customcolor
		overlays += colorov