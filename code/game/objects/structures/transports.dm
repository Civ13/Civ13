/obj/structure/vehicle
	name = "vehicle"
	icon = 'icons/obj/vehicleparts.dmi'
	desc = "A vehicle."
	icon_state = "motorcycle"
	var/list/ontop = list()
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

/obj/structure/vehicle/proc/do_color()
	return

/obj/structure/vehicle/proc/processmove(var/m_dir = null)
	if (!m_dir)
		return
	else
		if (do_vehicle_check() && lastmove+vehicle_m_delay <= world.time)
			do_move(m_dir)
			lastmove = world.time

/obj/structure/vehicle/proc/do_vehicle_check(var/m_dir = null) //check if the vehicle can move.
	return TRUE

/obj/structure/vehicle/proc/update_overlay() //for the vehicles that have overlays (i.e. motorcycles)
	return

/obj/structure/vehicle/proc/check_engine()
	return

/obj/structure/vehicle/proc/do_move(var/m_dir = null)
	for (var/mob/living/ML in ontop)
		ML.forceMove(get_step(src, m_dir))
	for (var/obj/O in ontop)
		O.forceMove(get_step(src, m_dir))
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

/obj/structure/vehicle/MouseDrop_T(mob/living/carbon/human/M, mob/living/carbon/human/user)
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
			update_overlay()
			update_icon()
			return

/obj/structure/vehicle/attack_hand(mob/living/carbon/human/user as mob)
	if ((user in ontop))
		visible_message("<div class='notice'>[user] start leaving \the [src]...</div>","<div class='notice'>You start going on \the [src]...</div>")
		if (do_after(user, 30, src))
			visible_message("<div class='notice'>[user] sucessfully leaves \the [src].</div>","<div class='notice'>You leave \the [src].</div>")
			ontop -= user
			if (user == driver)
				user.driver = FALSE
				unbuckle_mob()
				user.driver_vehicle = null
				driver = null
				if (wheeled)
					if (user.l_hand == dwheel)
						user.remove_from_mob(dwheel)
						dwheel.forceMove(src)
					else if (user.r_hand == dwheel)
						user.remove_from_mob(dwheel)
						dwheel.forceMove(src)
						user.r_hand = null
					user.update_icons()
			update_overlay()
			update_icon()
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
				if (user == driver)
					user.driver = FALSE
					unbuckle_mob()
					user.driver_vehicle = null
					driver = null
					if (wheeled)
						if (user.l_hand == dwheel)
							user.remove_from_mob(dwheel)
							dwheel.forceMove(src)
						else if (user.r_hand == dwheel)
							user.remove_from_mob(dwheel)
							dwheel.forceMove(src)
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
	health = 50
/obj/structure/vehicle/raft/do_vehicle_check(var/m_dir = null)
	if (istype(get_turf(get_step(src,m_dir)), /turf/floor/beach/water))
		if (driver in src.loc)
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
	cover_overlay = image(icon, "[icon_state]_overlay")//"bike_cover")
	cover_overlay.layer = MOB_LAYER + 2.1
	cover_overlay_c = image(icon, "[icon_state]_overlay_mask")//"bike_cover")
	cover_overlay_c.layer = MOB_LAYER + 2.11
	spawn(3)
		cover_overlay_c.color = customcolor
/obj/structure/vehicle/motorcycle/update_overlay()
	if (driver)
		add_overlay(cover_overlay)
		return
	else
		overlays -= cover_overlay
		return

/obj/structure/vehicle/motorcycle/do_vehicle_check(var/m_dir = null)
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
				driver.remove_from_mob(dwheel)
				dwheel.forceMove(src)
				driver.driver = FALSE
				driver.driver_vehicle = null
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
				unbuckle_mob()
				update_overlay()
				update_icon()
				ontop -= driver
				driver.remove_from_mob(dwheel)
				dwheel.forceMove(src)
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
//TODO: add fuel consumption

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
					return
				else
					var/amttransf = fueltank.reagents.maximum_volume-fueltank.reagents.total_volume
					fueltank.reagents.add_reagent("gasoline",amttransf)
					GC.reagents.remove_reagent("gasoline",amttransf)
					user << "You fill the fueltank completly with \the [W]."
					return
			else
				user << "\The [W] has no gasoline in it."
				return
		else
			user << "The fueltank is full already."
			return
	else
		..()

/obj/structure/vehicle/motorcycle/do_color()
	if (customcolor)
		var/image/colorov = image("icon" = icon, "icon_state" = "[icon_state]_mask1")
		colorov.color = customcolor
		overlays += colorov