/mob/var/velocity = 0
/mob/var/velocity_lastdir = -1 // turning makes you lose TRUE or 2 velocity
/mob/var/run_delay_maximum = 1.9

/mob/var/ghost_velocity = 0
/mob/proc/movement_delay()
	switch (ghost_velocity)
		if (0)
			return 0.7
		if (1)
			return 0.5
		if (2)
			return 0.3
	return 0.3 // failsafe for instant movement bullshit

/mob/proc/get_run_delay()
	switch (velocity)
		if (0 to 3)
			. = run_delay_maximum
		if (4 to 7)
			. = run_delay_maximum/1.03 // 3% faster
		if (8 to 11)
			. = run_delay_maximum/1.06 // 6% faster
		if (12 to INFINITY)
			. = run_delay_maximum/1.09 // 9% faster
	return .

/mob/proc/get_walk_delay()
	return get_run_delay() * 1.5

/mob/proc/get_stealth_delay()
	return get_run_delay() * 3

/mob/proc/get_prone_delay()
	return get_run_delay() * 7

// weight slowdown

/mob/living/human/var/last_run_delay = -1
/mob/living/human/var/next_calculate_run_delay = -1
/mob/living/human/get_run_delay()

	. = ..()

	if (last_run_delay != -1 && world.time < next_calculate_run_delay)
		return last_run_delay

	var/slowdown = 0
	var/weight = 0
	var/max_weight = (((getStatCoeff("strength")-1)/2)+1) * 59
	var/heavy = FALSE
	for (var/obj/item/I in contents)
		if (I.heavy)
			heavy = TRUE
		weight += I.get_weight()
		if (istype(I,/obj/item/weapon/storage))
			for (var/obj/item/II in I.contents)
				weight += II.get_weight()

	if (weight == 0 && !heavy)
		slowdown = 0
	else if ((weight > max_weight * 0.25 || heavy) && weight <= max_weight * 0.50)
		slowdown = 0.33
	else if (weight > max_weight * 0.50 && weight <= max_weight * 0.65)
		slowdown = 0.44
	else if (weight > max_weight * 0.65 && weight <= max_weight * 0.75)
		slowdown = 0.55
	else if (weight > max_weight * 0.75 && weight <= max_weight * 0.85)
		slowdown = 0.66
	else if (weight > max_weight * 0.85 && weight <= max_weight * 0.95)
		slowdown = 0.77
	else if (weight > max_weight * 0.85 && weight <= max_weight * 0.95)
		slowdown = 0.88
	else if (weight > max_weight * 0.95 && weight <= INFINITY)
		slowdown = 0.99
	. *= slowdown+1

	last_run_delay = .
	next_calculate_run_delay = world.time + 5

/mob/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)

	if (air_group || (height==0)) return TRUE

	if (ismob(mover))
		var/mob/moving_mob = mover
		if ((other_mobs && moving_mob.other_mobs))
			return TRUE
		return (!mover.density || !density || lying || prone)
	else
		return (!mover.density || !density || lying || prone)

/mob/proc/setMoveCooldown(var/timeout)
	if (client)
		client.move_delay = max(world.time + timeout, client.move_delay)

/client/North()
	..()

/client/South()
	..()

/client/West()
	..()

/client/East()
	..()

/client/proc/client_dir(input, direction=-1)
	return turn(input, direction*dir2angle(dir))

/client/Northeast()
	diagonal_action(NORTHEAST)
/client/Northwest()
	diagonal_action(NORTHWEST)
/client/Southeast()
	diagonal_action(SOUTHEAST)
/client/Southwest()
	diagonal_action(SOUTHWEST)

/client/proc/diagonal_action(direction)
	switch(client_dir(direction, TRUE))
		if (NORTHEAST)
			swap_hand()
			return
		if (SOUTHEAST)
			attack_self()
			return
		if (SOUTHWEST)
			if (ishuman(usr))
				var/mob/living/human/C = usr
				C.toggle_throw_mode()
			else
				to_chat(usr, SPAN_RED("This mob type cannot throw items."))
			return
		if (NORTHWEST)
			if (ishuman(usr))
				var/mob/living/human/C = usr
				if (!C.get_active_hand())
					to_chat(usr, SPAN_RED("You have nothing to drop in your hand."))
					return
				drop_item()
			else
				to_chat(usr, SPAN_RED("This mob type cannot drop items."))
			return

//This gets called when you press the delete button.
/client/verb/delete_key_pressed()
	set hidden = TRUE

	if (!usr.pulling)
		to_chat(usr, SPAN_NOTICE("You are not pulling anything."))
		return
	usr.stop_pulling()

/client/verb/swap_hand()
	set hidden = TRUE
	if (istype(mob, /mob/living/human))
		mob:swap_hand()
	return



/client/verb/attack_self()
	set hidden = TRUE
	if (mob && isliving(mob))
		var/mob/living/L = mob
		L.mode()
	return


/client/verb/toggle_throw_mode()
	set hidden = TRUE
	if (!istype(mob, /mob/living/human))
		return
	if (!mob.stat && isturf(mob.loc) && !mob.restrained())
		mob:toggle_throw_mode()
	else
		return


/client/verb/drop_item()
	set hidden = TRUE
	if (mob.stat == CONSCIOUS && isturf(mob.loc))
		return mob.drop_item()
	return


/client/Center()
	return

//This proc should never be overridden elsewhere at /atom/movable to keep directions sane.
/atom/movable/Move(newloc, direct)
	if (!persistence_movement_allowed(src, newloc))
		return FALSE
	var/datum/human_subtile_pulse/subtile_pulse
	var/mob/living/human/subtile_actor
	if (ishuman(src))
		subtile_actor = src
		if (subtile_actor.human_subtile_pulse)
			subtile_pulse = subtile_actor.human_subtile_take_pulse(newloc, direct)
			if (!subtile_pulse)
				return FALSE
		else if (subtile_actor.human_subtile_offset_owned && (step_x || step_y))
			return FALSE
	if (direct & (direct - 1))
		if (direct & TRUE)
			if (direct & 4)
				if (step(src, NORTH))
					step(src, EAST)
				else
					if (step(src, EAST))
						step(src, NORTH)
			else
				if (direct & 8)
					if (step(src, NORTH))
						step(src, WEST)
					else
						if (step(src, WEST))
							step(src, NORTH)
		else
			if (direct & 2)
				if (direct & 4)
					if (step(src, SOUTH))
						step(src, EAST)
					else
						if (step(src, EAST))
							step(src, SOUTH)
				else
					if (direct & 8)
						if (step(src, SOUTH))
							step(src, WEST)
						else
							if (step(src, WEST))
								step(src, SOUTH)
	else
		var/atom/A = loc

		var/olddir = dir //we can't override this without sacrificing the rest of movable/New()
		if (subtile_pulse)
			. = ..(newloc, direct, subtile_pulse.sx, subtile_pulse.sy)
			subtile_pulse.engine_return = .
			if (!subtile_actor || isDeleted(subtile_actor))
				return .
			if (!subtile_pulse.restoring && subtile_actor.human_subtile_transaction)
				var/dx = (x - subtile_pulse.before["x"]) * 32 + step_x - subtile_pulse.before["sx"]
				var/dy = (y - subtile_pulse.before["y"]) * 32 + step_y - subtile_pulse.before["sy"]
				subtile_actor.human_subtile_transaction.total_distance += abs(dx) + abs(dy)
				if (dx || dy)
					subtile_actor.human_subtile_offset_owned = TRUE
		else
			. = ..()
		if (direct != olddir)
			dir = olddir
			set_dir(direct)
		l_move_time = world.time
		if ((A != loc && A && A.z == z))
			last_move = get_dir(A, loc)
	if (istype(src, /mob/living/human))
		var/mob/living/human/H = src
		if (H.riding == TRUE && !isnull(H.riding_mob))
			if (H.pulling)
				H.stop_pulling()
			H.riding_mob.forceMove(H.loc)
			H.riding_mob.dir = H.dir
	return

/client/proc/Move_object(direct)
	if (mob && mob.control_object)
		if (mob.control_object.density)
			step(mob.control_object,direct)
			if (!mob.control_object)	return
			mob.control_object.dir = direct
		else
			mob.control_object.forceMove(get_step(mob.control_object,direct))
	return


/mob/var/next_snow_message = -1
/mob/var/next_mud_message = -1
/mob/var/next_stamina_message = -1
/mob/var/next_gracewall_message = -1
/mob/var/next_cannotmove_message = -1
/mob/var/list/next_change_dir = null

#define NO_ACCURACY_MOVEMENT_CHECKS
/mob/proc/lastMovedRecently(threshold, accuracy_check = FALSE)
	if (accuracy_check)
		#ifdef NO_ACCURACY_MOVEMENT_CHECKS
		return FALSE
		#endif

	var/default_threshold = movement_delay()
	if (ishuman(src))
		default_threshold = get_walk_delay()
	if (m_intent == "run")
		default_threshold = get_run_delay()
	if (abs(world.time - last_movement) <= (threshold ? threshold+0.1 : default_threshold+0.1))
		return TRUE
	return FALSE
#undef NO_ACCURACY_MOVEMENT_CHECKS

/mob/proc/SelfMove(turf/n, direct)
	return Move(n, direct)

///Process_Incorpmove
///Called by client/Move()
///Allows mobs to run though walls
/client/proc/Process_Incorpmove(direct)
	var/turf/mobloc = get_turf(mob)

	switch(mob.incorporeal_move)
		if (1)
			mob.forceMove(get_step(mob, direct))
			mob.dir = direct
		if (2)
			if (prob(50))
				var/locx
				var/locy
				switch(direct)
					if (NORTH)
						locx = mobloc.x
						locy = (mobloc.y+2)
						if (locy>world.maxy)
							return
					if (SOUTH)
						locx = mobloc.x
						locy = (mobloc.y-2)
						if (locy<1)
							return
					if (EAST)
						locy = mobloc.y
						locx = (mobloc.x+2)
						if (locx>world.maxx)
							return
					if (WEST)
						locy = mobloc.y
						locx = (mobloc.x-2)
						if (locx<1)
							return
					else
						return
				mob.forceMove(locate(locx,locy,mobloc.z))
				spawn(0)
					var/limit = 2//For only two trailing shadows.
					for (var/turf/T in getline(mobloc, mob.loc))
						spawn(0)
							anim(T,mob,'icons/mob/mob.dmi',,"shadow",,mob.dir)
						limit--
						if (limit<=0)	break
			else
				spawn(0)
					anim(mobloc,mob,'icons/mob/mob.dmi',,"shadow",,mob.dir)
				mob.forceMove(get_step(mob, direct))
			mob.dir = direct
	// Crossed is always a bit iffy
	for (var/obj/S in mob.loc)
		if (istype(S,/obj/effect/step_trigger))
			S.Crossed(mob)

	var/area/A = get_area(mob)
	if (A)
		A.Entered(mob)
	if (isturf(mob.loc))
		var/turf/T = mob.loc
		T.Entered(mob)
	mob.Post_Incorpmove()
	return TRUE

/mob/proc/Post_Incorpmove()
	return

/mob/proc/Check_Dense_Object() //checks for anything to push off in the vicinity. also handles magboots on gravity-less floors tiles

	var/shoegrip = Check_Shoegrip()

	for (var/turf/T in trange(1,src)) //we only care for non-space turfs
		if (T.density)	//walls work
			return TRUE
		else
			var/area/A = T.loc
			if (A.has_gravity || shoegrip)
				return TRUE

	for (var/obj/O in orange(1, src))
		if (O && O.density && O.anchored)
			return TRUE

	return FALSE

/mob/proc/Check_Shoegrip()
	return FALSE

/mob/proc/slip_chance(var/prob_slip = 5)
	if (stat)
		return FALSE
	if (Check_Shoegrip())
		return FALSE
	return prob_slip

// loop-based movement magic
/mob/var/movement_eastwest = null
/mob/var/movement_northsouth = null

// when a client changes mobs or logs out they stop moving
/mob/Logout()
	movement_eastwest = null
	movement_northsouth = null
	..()

/client/verb/startmovingup()
	set name = ".startmovingup"
	set instant = TRUE
	if (mob)
		mob.movement_northsouth = NORTH
		try
			Move(get_step(mob, NORTH), NORTH)
		catch (var/E)
			pass(E)
		if (istype(mob, /mob/living/human))
			var/mob/living/human/H = mob
			if (H.football && H.football.owner == H)
				H.football.update_movement()
			for(var/obj/item/vehicleparts/wheel/modular/MW in H)
				if (MW && MW.control && MW.control.axis && MW.control.axis.reverse && MW.control.axis.currentspeed == 0 && !MW.control.axis.moving)
					to_chat(H, "You switch into forward.")
					playsound(H.loc, 'sound/effects/lever.ogg',65, TRUE)
					MW.control.axis.reverse = FALSE
			for(var/obj/item/turret_controls/C in H)
				C.increase_distance(1)
			for(var/obj/item/drone_controller/RC in H)
				if(H.using_drone)
					RC.start_move_drone(NORTH)
			if (H.driver && H.driver_vehicle)
				H.dir = NORTH
				H.driver_vehicle.dir = NORTH
				H.driver_vehicle.updatepassdir()
				if (!H.driver_vehicle.wheeled)
					H.driver_vehicle.processmove(NORTH)
			else if (mob.prone)
				if (mob.dir == NORTH || mob.dir == NORTHWEST || mob.dir == NORTHEAST || mob.dir == WEST)
					mob.dir = WEST
					var/matrix/M = matrix()
					M.Turn(-90)
					M.Translate(1,-6)
					mob.transform = M
				else
					mob.dir = EAST
					var/matrix/M = matrix()
					M.Turn(90)
					M.Translate(1,-6)
					mob.transform = M


/client/verb/startmovingdown()
	set name = ".startmovingdown"
	set instant = TRUE
	if (mob)
		mob.movement_northsouth = SOUTH
		try
			Move(get_step(mob, SOUTH), SOUTH)
		catch (var/E)
			pass(E)
		if (istype(mob, /mob/living/human))
			var/mob/living/human/H = mob
			if (H.football && H.football.owner == H)
				H.football.update_movement()
			for(var/obj/item/vehicleparts/wheel/modular/MW in H)
				if (MW && MW.control && MW.control.axis && !MW.control.axis.reverse && MW.control.axis.currentspeed == 0 && !MW.control.axis.moving)
					to_chat(H, "You switch into reverse.")
					playsound(H.loc, 'sound/effects/lever.ogg',65, TRUE)
					MW.control.axis.reverse = TRUE
			for(var/obj/item/turret_controls/C in H)
				C.increase_distance(-1)
			for(var/obj/item/drone_controller/RC in H)
				if(H.using_drone)
					RC.start_move_drone(SOUTH)
			if (H.driver && H.driver_vehicle)
				H.dir = SOUTH
				H.driver_vehicle.dir = SOUTH
				H.driver_vehicle.updatepassdir()
				if (!H.driver_vehicle.wheeled)
					H.driver_vehicle.processmove(SOUTH)
			else if (mob.prone)
				if (mob.dir == NORTH || mob.dir == NORTHWEST || mob.dir == NORTHEAST || mob.dir == WEST)
					mob.dir = WEST
					var/matrix/M = matrix()
					M.Turn(-90)
					M.Translate(1,-6)
					mob.transform = M
				else
					mob.dir = EAST
					var/matrix/M = matrix()
					M.Turn(90)
					M.Translate(1,-6)
					mob.transform = M
/client/verb/startmovingright()
	set name = ".startmovingright"
	set instant = TRUE
	if (mob)
		mob.movement_eastwest = EAST
		try
			Move(get_step(mob, EAST), EAST)
		catch (var/E)
			pass(E)
		if (istype(mob, /mob/living/human))
			var/mob/living/human/H = mob
			if (H.football && H.football.owner == H)
				H.football.update_movement()
			for(var/obj/item/vehicleparts/wheel/modular/MW in H)
				MW.turndir(mob,"right")
			for(var/obj/item/turret_controls/C in H)
				if (!C.is_rotating)
					C.start_rotation(1)
				else
					if (C.rotating_dir == -1)
						C.stop_rotation()

			for(var/obj/item/drone_controller/RC in H)
				if(H.using_drone)
					RC.start_move_drone(EAST)
			if (H.driver && H.driver_vehicle)
				H.dir = EAST
				H.driver_vehicle.dir = EAST
				H.driver_vehicle.updatepassdir()
				if (!H.driver_vehicle.wheeled)
					H.driver_vehicle.processmove(EAST)
			else if (mob.prone)
				if (mob.dir == NORTH || mob.dir == NORTHWEST || mob.dir == NORTHEAST || mob.dir == WEST)
					mob.dir = WEST
					var/matrix/M = matrix()
					M.Turn(-90)
					M.Translate(1,-6)
					mob.transform = M
				else
					mob.dir = EAST
					var/matrix/M = matrix()
					M.Turn(90)
					M.Translate(1,-6)
					mob.transform = M
/client/verb/startmovingleft()
	set name = ".startmovingleft"
	set instant = TRUE
	if (mob)
		mob.movement_eastwest = WEST
		try
			Move(get_step(mob, WEST), WEST)
		catch (var/E)
			pass(E)
		if (istype(mob, /mob/living/human))
			var/mob/living/human/H = mob
			if (H.football && H.football.owner == H)
				H.football.update_movement()
			for(var/obj/item/vehicleparts/wheel/modular/MW in H)
				MW.turndir(mob,"left")
			for(var/obj/item/turret_controls/C in H)
				if (!C.is_rotating)
					C.start_rotation(-1)
				else
					if (C.rotating_dir == 1)
						C.stop_rotation()
			for(var/obj/item/drone_controller/RC in H)
				if(H.using_drone)
					RC.start_move_drone(WEST)
			if (H.driver && H.driver_vehicle)
				H.dir = WEST
				H.driver_vehicle.dir = WEST
				H.driver_vehicle.updatepassdir()
				if (!H.driver_vehicle.wheeled)
					H.driver_vehicle.processmove(WEST)
			else if (mob.prone)
				if (mob.dir == NORTH || mob.dir == NORTHWEST || mob.dir == NORTHEAST || mob.dir == WEST)
					mob.dir = WEST
					var/matrix/M = matrix()
					M.Turn(-90)
					M.Translate(1,-6)
					mob.transform = M
				else
					mob.dir = EAST
					var/matrix/M = matrix()
					M.Turn(90)
					M.Translate(1,-6)
					mob.transform = M
/client/verb/stopmovingup()
	set name = ".stopmovingup"
	set instant = TRUE
	if (mob && mob.movement_northsouth == NORTH)
		mob.movement_northsouth = null
		for(var/obj/item/drone_controller/RC in mob.contents)
			if(mob.using_drone)
				RC.stop_move_drone()

/client/verb/stopmovingdown()
	set name = ".stopmovingdown"
	set instant = TRUE
	if (mob && mob.movement_northsouth == SOUTH)
		mob.movement_northsouth = null
		for(var/obj/item/drone_controller/RC in mob.contents)
			if(mob.using_drone)
				RC.stop_move_drone()

/client/verb/stopmovingright()
	set name = ".stopmovingright"
	set instant = TRUE
	if (mob && mob.movement_eastwest == EAST)
		mob.movement_eastwest = null
		for(var/obj/item/turret_controls/C in mob)
			C.stop_rotation()
		for(var/obj/item/drone_controller/RC in mob.contents)
			if(mob.using_drone)
				RC.stop_move_drone()

/client/verb/stopmovingleft()
	set name = ".stopmovingleft"
	set instant = TRUE
	if (mob && mob.movement_eastwest == WEST)
		mob.movement_eastwest = null
		for(var/obj/item/turret_controls/C in mob)
			C.stop_rotation()
		for(var/obj/item/drone_controller/RC in mob.contents)
			if(mob.using_drone)
				RC.stop_move_drone()


// this is a wrapper that checks if the game is running in OpenDream,
// if YES: Run our own implementation of walk_away(), since it is not implemented
// if NO: Run the normal walk_away() proc
/atom/var/walk_id = 0

/atom/proc/walk_away_od(atom/Trg, Max=5, Lag=0, Speed=0)
	set waitfor = FALSE
	#ifndef OPENDREAM
	walk_away(Trg, Max, Lag, Speed)
	return
	#endif
	#ifdef OPENDREAM
	walk(src, 0) // Halts any built-in walk loop to mimic BYOND
	
	if(!Trg) return
	
	var/current_walk_id = rand(1, 100000)
	src.walk_id = current_walk_id
	
	// Loop continuously in the background
	while(src && Trg && src.walk_id == current_walk_id)
		if(get_dist(src, Trg) > Max)
			break
		
		step_away(src, Trg)
		
		// Wait for the lag, or fallback to world.tick_lag if 0 
		if(Lag > 0)
			sleep(Lag)
		else
			sleep(world.tick_lag)
	#endif
