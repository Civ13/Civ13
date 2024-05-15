/obj/item/drone_controller
	name = "drone controller"
	desc = "A controller for moving a drone."
	icon = 'icons/obj/device.dmi'
	icon_state = "rc_control"
	secondary_action = TRUE
	var/obj/structure/drone/connected_drone = null
	var/mob/living/human/controller = null
	var/is_moving = FALSE
	var/executing_move = FALSE
	var/moving_dir = NORTH

/obj/item/drone_controller/attack_self(var/mob/living/human/H)
	if(ishuman(H))
		toggle(H)

/obj/item/drone_controller/secondary_attack_self(var/mob/living/human/H)
	if(secondary_action && connected_drone && connected_drone.has_special)
		to_chat(H, SPAN_DANGER("You press the detonate button."))
		connected_drone.do_special(H)

/obj/item/drone_controller/proc/toggle(var/mob/living/human/H)
	if(connected_drone)
		to_chat(H, SPAN_NOTICE("You [H.using_drone ? "deactivate" : "activate"] \the [src]."))
		if(H.using_drone)
			H.unset_using_drone(src)
		else
			H.set_using_drone(src)
		return
	else
		to_chat(H, SPAN_WARNING("There is no drone connected to \the [src]."))
		return

/obj/item/drone_controller/proc/cut_connection()
	if(controller)
		to_chat(controller, SPAN_NOTICE("The connection to \the [connected_drone] has been lost."))
		connected_drone = null
		controller.unset_using_drone(src)
		return

/obj/item/drone_controller/dropped()
	if (controller)
		controller.unset_using_drone(src)
	..()

/obj/item/drone_controller/proc/stop_move_drone()
	is_moving = FALSE

/obj/item/drone_controller/proc/start_move_drone(var/direction)
	moving_dir = direction
	if(!connected_drone)	return

	if(connected_drone.broken)
		if(controller)
			to_chat(controller, SPAN_DANGER("\The [connected_drone]\'s tracks are broken, repair it with a welding tool."))
		return
	if(!is_moving)
		is_moving = TRUE
		move_drone()

/obj/item/drone_controller/proc/move_drone()
	if(!is_moving)	return
	if(!connected_drone)	return
	if(connected_drone.broken)	return
	if(executing_move)	return
	executing_move = TRUE
	connected_drone.Move(get_step(connected_drone, moving_dir))
	connected_drone.dir = moving_dir

	spawn(connected_drone.movement_delay)
		executing_move = FALSE
		move_drone()

/obj/structure/drone
	name = "drone"
	desc = "A movable drone."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "goliath"
	var/obj/item/drone_controller/connected_controller = null
	var/movement_delay = 5
	var/movement_sound = 'sound/machines/rc_car.ogg'
	var/has_special = FALSE
	var/health = 100
	var/broken = FALSE
	
	heavy_armor_penetration = 0
	var/devastation_range = 2
	var/heavy_impact_range = 3
	var/light_impact_range = 5
	var/flash_range = 6

/obj/structure/drone/attackby(obj/item/I as obj, mob/user)
	if(istype(I, /obj/item/drone_controller))
		var/obj/item/drone_controller/RC = I
		if (!connected_controller && !RC.connected_drone)
			connected_controller = RC
			connected_controller.connected_drone = src
			to_chat(user, SPAN_NOTICE("You connect \the [src] to \the [connected_controller]."))
			return
		else
			to_chat(user, SPAN_WARNING("\The [src] is already connected to a controller."))
			return
	if(broken && istype(I, /obj/item/weapon/weldingtool))
		visible_message("[user] starts repairing \the [src]...")
		if (do_after(user, 100, src))
			visible_message("[user] sucessfully repairs \the [src].")
			broken = FALSE
			return
	else
		..()

/obj/structure/drone/proc/try_destroy()
	if (health <= 0)
		health = 0
		visible_message(SPAN_DANGER("<big>\The [src] took too much damage and explodes!</big>"))
		do_special()
	else if (health <= 50 && !broken)
		if (prob(5))
			broken = TRUE
			visible_message(SPAN_DANGER("\The [src] breaks down!"))
			if (connected_controller)
				connected_controller.is_moving = FALSE
	return

/obj/structure/drone/ex_act(severity)
	switch(severity)
		if (1.0)
			health -= 100
		if (2.0)
			health -= 50
			if (prob(40))
				broken = TRUE
				visible_message(SPAN_DANGER("\The [src] breaks down!"))
				if (connected_controller)
					connected_controller.is_moving = FALSE
		if (3.0)
			health -= 25
	try_destroy()

/obj/structure/drone/bullet_act(var/obj/item/projectile/proj)
	health -= proj.damage * 0.1
	visible_message(SPAN_DANGER("\The [src] is hit by \the [proj.name]!"))
	try_destroy()

/obj/structure/drone/Destroy()
	if (connected_controller)
		connected_controller.cut_connection()
	..()

/obj/structure/drone/proc/do_special()
	var/turf/T = get_turf(src)
	qdel(src)
	explosion(T, devastation_range, heavy_impact_range, light_impact_range, flash_range)
	for(var/obj/structure/vehicleparts/frame/F in range(1,src))
		for (var/mob/M in F.axis.transporting)
			shake_camera(M, 3, 3)
		var/penloc = F.CheckPenLoc(T)
		switch(penloc)
			if ("left")
				if (F.w_left[5] > 0)
					F.w_left[5] -= heavy_armor_penetration
					visible_message(SPAN_DANGER("<big>The left hull gets damaged!</big></span>"))
			if ("right")
				if (F.w_right[5] > 0)
					F.w_right[5] -= heavy_armor_penetration
					visible_message(SPAN_DANGER("<big>The right hull gets damaged!</big></span>"))
			if ("front")
				if (F.w_front[5] > 0)
					F.w_front[5] -= heavy_armor_penetration
					visible_message(SPAN_DANGER("<big>The front hull gets damaged!</big></span>"))
			if ("back")
				if (F.w_back[5] > 0)
					F.w_back[5] -= heavy_armor_penetration
					visible_message(SPAN_DANGER("<big>The rear hull gets damaged!</big></span>"))
			if ("frontleft")
				if (F.w_left[5] > 0 && F.w_front[5] > 0)
					if (F.w_left[4] > F.w_front[4] && F.w_left[5]>0)
						F.w_left[5] -= heavy_armor_penetration
						visible_message(SPAN_DANGER("<big>The left hull gets damaged!</big></span>"))
					else
						F.w_front[5] -= heavy_armor_penetration
						visible_message(SPAN_DANGER("<big>The front hull gets damaged!</big></span>"))
			if ("frontright")
				if (F.w_right[5] > 0 && F.w_front[5] > 0)
					if (F.w_right[4] > F.w_front[4] && F.w_right[5]>0)
						F.w_right[5] -= heavy_armor_penetration
						visible_message(SPAN_DANGER("<big>The right hull gets damaged!</big></span>"))
					else
						F.w_front[5] -= heavy_armor_penetration
						visible_message(SPAN_DANGER("<big>The front hull gets damaged!</big></span>"))
			if ("backleft")
				if (F.w_left[5] > 0 && F.w_back[5] > 0)
					if (F.w_left[4] > F.w_back[4] && F.w_left[5]>0)
						F.w_left[5] -= heavy_armor_penetration
						visible_message(SPAN_DANGER("<big>The left hull gets damaged!</big></span>"))
					else
						F.w_back[5] -= heavy_armor_penetration
						visible_message(SPAN_DANGER("<big>The rear hull gets damaged!</big></span>"))
			if ("backright")
				if (F.w_right[5] > 0 && F.w_back[5] > 0)
					if (F.w_right[4] > F.w_back[4] && F.w_right[5]>0)
						F.w_right[5] -= heavy_armor_penetration
						visible_message(SPAN_DANGER("<big>The right hull gets damaged!</big></span>"))
					else
						F.w_back[5] -= heavy_armor_penetration
						visible_message(SPAN_DANGER("<big>The rear hull gets damaged!</big></span>"))
		F.try_destroy()
		for(var/obj/structure/vehicleparts/movement/MV in F)
			MV.broken = TRUE
			MV.update_icon()
		F.update_icon()
	return

/obj/structure/drone/Move()
	..()
	playsound(loc, movement_sound, 100, TRUE)

/obj/structure/drone/goliath
	name = "Goliath SdKfz. 302"
	desc = "The SdKfz. 302, also known as the Goliath, is a remote-controlled tracked mine carrying either 60 or 100 kg of high explosives. It is used for destroying tanks, disrupting dense infantry formations, and the demolition of buildings or bridges."
	movement_delay = 4.5
	has_special = TRUE
	heavy_armor_penetration = 40
	devastation_range = 2
	heavy_impact_range = 3
	light_impact_range = 5
	flash_range = 6
