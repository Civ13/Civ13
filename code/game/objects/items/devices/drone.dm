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
	if(secondary_action && connected_drone && connected_drone.special)
		to_chat(H, SPAN_DANGER("You press the [connected_drone.special] button."))
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
	if(!connected_drone.can_move)	return
	if(connected_drone.broken && controller)
		if(!connected_drone.can_fly)
			to_chat(controller, SPAN_DANGER("\The [connected_drone]\'s tracks are broken, repair it with a welding tool."))
		return
	if(!is_moving)
		is_moving = TRUE
		move_drone()

/obj/item/drone_controller/proc/move_drone()
	if(!is_moving)	return
	if(!connected_drone)	return
	if(!connected_drone.can_move)	return
	if(connected_drone.can_fly && !connected_drone.flying)	return
	if(connected_drone.broken)	return
	if(executing_move)	return
	executing_move = TRUE
	connected_drone.Move(get_step(connected_drone, moving_dir))
	connected_drone.dir = moving_dir

	spawn(connected_drone.movement_delay)
		executing_move = FALSE
		move_drone()

/obj/item/drone_controller/proc/toggle_state()
	if(connected_drone && connected_drone.can_fly && !connected_drone.broken)
		to_chat(controller, SPAN_NOTICE("You [connected_drone.flying ? "decent \the [src] to the ground." : "fly \the [src] into the air."]"))
		connected_drone.toggle_state()
	else if(connected_drone.broken)
		to_chat(controller, SPAN_NOTICE("You try to [connected_drone.flying ? "decent \the [src] to the ground but nothing happens." : "fly \the [src] into the air but nothing happens.."]"))

/obj/structure/drone
	name = "drone"
	desc = "A movable drone."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "goliath"
	var/obj/item/drone_controller/connected_controller = null
	var/movement_delay = 5
	
	var/health = 100
	var/broken = FALSE
	var/can_move = TRUE
	var/can_fly = FALSE
	var/flying = FALSE

	var/obj/item/weapon/grenade/payload = null
	var/special = null

	var/movement_sound = 'sound/machines/rc_car.ogg'

	var/starting_snd = null
	var/running_snd = null
	var/ending_snd = null

	var/starting_snd_len = 26
	var/running_snd_len = 11
	
	heavy_armor_penetration = 0

/obj/structure/drone/attackby(obj/item/I as obj, mob/user)
	if(istype(I, /obj/item/drone_controller))
		var/obj/item/drone_controller/RC = I
		if (!connected_controller && !RC.connected_drone)
			connected_controller = RC
			connected_controller.connected_drone = src
			to_chat(user, SPAN_NOTICE("You connect \the [src] to \the [connected_controller]."))
		else
			to_chat(user, SPAN_WARNING("\The [src] is already connected to a controller."))
		return
	if((istype(I, /obj/item/weapon/weldingtool) || istype(I, /obj/item/taperoll)) && broken)
		visible_message("[user] starts repairing \the [src]...")
		if (do_after(user, 100, src))
			visible_message("[user] repairs \the [src].")
			broken = FALSE
		return
	if(istype(I, /obj/item/weapon/grenade) && !payload && special && !flying)
		visible_message("[user] starts attaching the [I] to \the [src]...")
		if (do_after(user, 100, src))
			visible_message("[user] attaches the [I] to \the [src].")
			user.remove_from_mob(I)
			I.loc = src
			payload = I
	else
		..()

/obj/structure/drone/proc/toggle_state()
	if(!can_fly)
		return
	if(!broken)
		can_move = FALSE
		if (connected_controller)
			connected_controller.is_moving = FALSE
		if(!flying)
			animate(src, pixel_y = 16, time = starting_snd_len, easing = CUBIC_EASING | EASE_IN)
			playsound(loc, starting_snd, 50, FALSE, 2)
			icon_state = "[initial(icon_state)]_flying"
			spawn(starting_snd_len)
				can_move = TRUE
				flying = TRUE
				sinkable = FALSE
				layer = 8
				running_sound()
		else
			playsound(loc, ending_snd, 50, FALSE, 2)
			spawn(5)
				animate(src, pixel_y = 0, time = 5, easing = BOUNCE_EASING | EASE_OUT)
				spawn(5)
					can_move = FALSE
					flying = FALSE
					sinkable = TRUE
					icon_state = initial(icon_state)
					layer = initial(layer)

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
	if (flying)
		var/crash = FALSE
		switch(severity)
			if (1.0)
				health -= 70
				crash = TRUE
			if (2.0)
				health -= 25
				if (prob(75))
					crash = TRUE
			if (3.0)
				if (prob(25))
					crash = TRUE
		try_destroy()
		if (crash && src)
			toggle_state()
	else
		switch(severity)
			if (1.0)
				health -= 100
				broken = TRUE
				visible_message(SPAN_DANGER("\The [src] breaks down!"))
				if (connected_controller)
					connected_controller.is_moving = FALSE
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
	if (flying)
		if (prob(60))
			health -= proj.damage * 0.1
			visible_message(SPAN_DANGER("\The [src] is hit by \the [proj.name]!"))
		else if (prob(10))
			visible_message(SPAN_DANGER("\The [src]\'s propeller is hit, shooting it down!"))
			toggle_state()
	else
		health -= proj.damage * 0.1
		visible_message(SPAN_DANGER("\The [src] is hit by \the [proj.name]!"))
		try_destroy()

/obj/structure/drone/Destroy()
	if (connected_controller)
		connected_controller.cut_connection()
	..()

/obj/structure/drone/proc/do_special()
	return

/obj/structure/drone/Move()
	..()
	playsound(loc, movement_sound, 100, TRUE)

/obj/structure/drone/proc/running_sound()
	if (flying)
		playsound(loc, pick(running_snd), 50, FALSE, 2)
		spawn(running_snd_len)
			running_sound()
	return

/obj/structure/drone/goliath
	name = "Goliath SdKfz. 302"
	desc = "The SdKfz. 302, also known as the Goliath, is a remote-controlled tracked mine carrying either 60 or 100 kg of high explosives. It is used for destroying tanks, disrupting dense infantry formations, and the demolition of buildings or bridges."
	movement_delay = 4.5
	special = "detonate"
	heavy_armor_penetration = 40

/obj/structure/drone/goliath/do_special()
	var/turf/T = get_turf(src)
	qdel(src)
	explosion(T, 2, 3, 5, 6)
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

/obj/structure/drone/flying
	name = "drone"
	desc = "A flying drone."
	icon_state = "drone"
	health = 50
	movement_delay = 2
	movement_sound = null
	can_fly = TRUE

	movement_sound = null

	starting_snd = 'sound/machines/drone_startup.ogg'
	running_snd = list('sound/machines/drone_active1.ogg', 'sound/machines/drone_active2.ogg', 'sound/machines/drone_active3.ogg')
	ending_snd = 'sound/machines/drone_shutdown.ogg'

/obj/structure/drone/flying/do_special()
	if (payload)
		var/turf/T = get_turf(src)
		payload.pixel_x = pixel_x
		payload.pixel_y = pixel_y
		payload.loc = T
		payload.activate()
		if (flying)
			animate(payload, pixel_y = 0, time = 5, easing = LINEAR_EASING)
		payload = null
	return

/obj/structure/drone/flying/Move()
	..()

/obj/structure/drone/flying/grenade
	name = "drone"
	desc = "A flying drone. This one is capable of carrying and releasing grenades."
	special = "release"