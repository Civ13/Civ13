/mob/var/velocity = 0
/mob/var/velocity_lastdir = -1 // turning makes you lose TRUE or 2 velocity
/mob/var/run_delay_maximum = 1.66 // was 1.75

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
	return get_run_delay() * 1.33

/mob/proc/get_stealth_delay()
	return get_run_delay() * 4

/mob/proc/get_prone_delay()
	return get_run_delay() * 8

// weight slowdown

/mob/living/carbon/human/var/last_run_delay = -1
/mob/living/carbon/human/var/next_calculate_run_delay = -1
/mob/living/carbon/human/get_run_delay()

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
	return

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
			if (iscarbon(usr))
				var/mob/living/carbon/C = usr
				C.toggle_throw_mode()
			else
				usr << "<span class = 'red'>This mob type cannot throw items.</span>"
			return
		if (NORTHWEST)
			if (iscarbon(usr))
				var/mob/living/carbon/C = usr
				if (!C.get_active_hand())
					usr << "<span class = 'red'>You have nothing to drop in your hand.</span>"
					return
				drop_item()
			else
				usr << "<span class = 'red'>This mob type cannot drop items.</span>"
			return

//This gets called when you press the delete button.
/client/verb/delete_key_pressed()
	set hidden = TRUE

	if (!usr.pulling)
		usr << "<span class = 'notice'>You are not pulling anything.</span>"
		return
	usr.stop_pulling()

/client/verb/swap_hand()
	set hidden = TRUE
	if (istype(mob, /mob/living/carbon))
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
	if (!istype(mob, /mob/living/carbon))
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
		. = ..()
		if (direct != olddir)
			dir = olddir
			set_dir(direct)

		move_speed = world.time - l_move_time
		l_move_time = world.time
		m_flag = TRUE
		if ((A != loc && A && A.z == z))
			last_move = get_dir(A, loc)
	if (istype(src, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = src
		if (H.riding == TRUE && !isnull(H.riding_mob))
			if (H.pulling)
				H.stop_pulling()
			H.riding_mob.forceMove(locate(x-1,y-1,z))
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

/client/Move(n, direct, ordinal = FALSE)

	// these checks occur once in the movement process, but they currently have to be rewritten here due to initial movements
	if (!canmove)
		return

	if (moving)
		return

	if (world.time < move_delay)
		return

	if (!mob)
		return // Moved here to avoid nullrefs below

	if (!mob.next_change_dir)
		mob.next_change_dir = list(
			num2text(NORTH) = -1,
			num2text(SOUTH) = -1,
			num2text(EAST) = -1,
			num2text(WEST) = -1,
			num2text(NORTHEAST) = -1,
			num2text(SOUTHEAST) = -1,
			num2text(NORTHWEST) = -1,
			num2text(SOUTHWEST) = -1)

	if (direct != mob.dir && world.time < mob.next_change_dir[num2text(direct)])
		return

	// relocate or gib chucklefucks who somehow cross the wall
	if (map && map.check_caribbean_block(mob, mob.loc))
		if (!map.special_relocate(mob))
			if (job_master)
				job_master.relocate(mob)
			else
				mob.gib()
		return

	for (var/obj/structure/noose/N in get_turf(mob))
		if (N.hanging == mob)
			return

	if (mob.prone && istype(n, /turf))
		var/turf/floor/F = n
		if (F.Adjacent(mob))
			mob.proning(F)
			return

	if (mob.lying && istype(n, /turf))
		var/turf/floor/F = n
		if (F.Adjacent(mob))
			mob.scramble(F)
			return

	var/mob_is_observer = istype(mob, /mob/observer)
	var/mob_is_living = istype(mob, /mob/living)
	var/mob_is_human = istype(mob, /mob/living/carbon/human)
	var/mob_loc = mob.loc


	// prevent passing the invisible wall: now supports diagonals :agony:
	var/list/dirs = list()

	switch (direct)
		if (NORTHEAST)
			dirs += NORTH
			dirs += EAST
		if (NORTHWEST)
			dirs += NORTH
			dirs += WEST
		if (SOUTHEAST)
			dirs += SOUTH
			dirs += EAST
		if (SOUTHWEST)
			dirs += SOUTH
			dirs += WEST
		else
			dirs += direct

	for (var/refdir in dirs)
		var/turf/ref = get_step(mob, refdir)

		if (ref && map.check_caribbean_block(mob, ref))
			mob.dir = direct
			if (world.time >= mob.next_gracewall_message)
				mob << "<span class = 'warning'>You cannot pass the invisible wall until the <b>Grace Period</b> has ended.</span>"
				mob.next_gracewall_message = world.time + 10
			return FALSE

	var/turf/t1 = n

	if (mob_is_observer && t1 && locate(/obj/noghost) in t1)
		if (!mob.client.holder || !check_rights(R_MOD, user = mob))
			mob.dir = direct
			return

	if (mob_is_human)
		var/mob/living/carbon/human/H = mob
		if (H.crouching)
			return

	if (mob_is_observer)
		var/turf/t = get_step(mob, direct)
		if (!t)
			return

	if (mob.control_object)	Move_object(direct)

	if (mob.incorporeal_move && mob_is_observer)
		if (mob.velocity_lastdir == direct && mob.lastMovedRecently(5))
			mob.ghost_velocity = min(mob.ghost_velocity+1, 2)
		else
			mob.ghost_velocity = 0
		mob.velocity_lastdir = direct
		mob.last_movement = world.time
		move_delay = world.time + mob.movement_delay()
		Process_Incorpmove(direct)
		return

	if (mob_is_living && mob.stat == DEAD)
		mob.ghostize()
		return

/*	// handle possible Eye movement
	if (mob.eyeobj)
		return mob.EyeMove(n,direct)
*/
	if (mob.transforming)	return//This is sota the goto stop mobs from moving var

	if (mob_is_living)
		var/mob/living/L = mob
		if (L.incorporeal_move)//Move though walls
			if (mob.velocity_lastdir == direct && mob.lastMovedRecently(5))
				mob.ghost_velocity = min(mob.ghost_velocity+1, 2)
			else
				mob.ghost_velocity = 0
			mob.last_movement = world.time
			move_delay = world.time + mob.movement_delay()
			Process_Incorpmove(direct)
			return

	if (Process_Grab())	return

	if (!mob.canmove)
		return

	if (mob_is_living)
		for (var/obj/structure/window_frame/W in mob.loc)
			mob.visible_message("<span class = 'warning'>[mob] starts climbing through the window frame.</span>")
			mob.canmove = FALSE
			var/oloc = mob.loc
			sleep(rand(8,12))
			mob.canmove = TRUE
			if (mob.lying || mob.stat == DEAD || mob.stat == UNCONSCIOUS || mob.loc != oloc)
				return
			mob.visible_message("<span class = 'warning'>[mob] climbs through the window frame.</span>")
			break

	// we can probably move now, so update our eye for ladders
	if (mob_is_human)
		var/mob/living/carbon/human/H = mob
		H.update_laddervision(null)

	if (!mob.lastarea)
		mob.lastarea = get_area(mob_loc)


	else if (isturf(mob_loc))
		if (mob.restrained()) //Why being pulled while cuffed prevents you from moving
			for (var/mob/M in range(mob, 1))
				if (M.pulling == mob)
					if (!M.restrained() && M.stat == 0 && M.canmove && mob.Adjacent(M))
						if (world.time >= mob.next_cannotmove_message)
							src << "<span class = 'notice'>You're restrained! You can't move!</span>"
							mob.next_cannotmove_message = world.time + 10
						return FALSE
					else
						M.stop_pulling()

		if (mob.pinned.len)
			if (world.time >= mob.next_cannotmove_message)
				src << "<span class = 'notice'>You're pinned to a wall by [mob.pinned[1]]!</span>"
				mob.next_cannotmove_message = world.time + 10
			return FALSE

		move_delay = world.time + mob.movement_delay()//set move delay


		var/turf/floor/F = mob_loc
		var/F_is_valid_floor = istype(F)
		var/standing_on_snow = FALSE

		var/mob/living/carbon/human/H = mob
		if (F && ishuman(H) && F_is_valid_floor && isnull(H.riding_mob))

			var/area/F_area = get_area(F)
			var/no_snow = FALSE
			for (var/obj/covers/CV in get_turf(F))
				no_snow = TRUE
			if ((F_area.weather == WEATHER_RAIN || F_area.weather == WEATHER_STORM) && F.may_become_muddy)
				F.muddy = TRUE
			else
				F.muddy = FALSE
			for (var/obj/covers/CV in get_turf(F))
				F.muddy = FALSE
			var/snow_message = ""
			var/snow_span = "notice"

			if (F.icon == 'icons/turf/snow.dmi' && no_snow == FALSE && !H.lizard)
				standing_on_snow = TRUE
				if (prob(50))
					standing_on_snow = 1.25
					snow_message = "You're slowed down a bit by the snow."
				else
					standing_on_snow = 1.75
					snow_message = "You're slowed down quite a bit by the snow."
					snow_span = "warning"

/* OLD CODE - TO BE REACTIVATED WHEN WE GET SNOW LEVELS
				switch (S.amount)
					if (0.01 to 0.8) // more than none and up to ~1/4 feet
						standing_on_snow = TRUE
						snow_message = "You're slowed down a little by the snow."
					if (0.08 to 0.16) // up to ~1/2 feet
						standing_on_snow = 1.25
						snow_message = "You're slowed down a bit by the snow."
					if (0.16 to 0.30) // up to a ~1 foot
						standing_on_snow = 1.75
						snow_message = "You're slowed down quite a bit by the snow."
						snow_span = "warning"
					if (0.30 to 0.75) // ~ 2 to 2.5 feet
						standing_on_snow = 2.25
						snow_message = "You're seriously being slowed down by the snow. It's almost hard to walk in."
						snow_span = "warning"
					if (0.75 to 1.22) // up to 4 feet!
						standing_on_snow = 4.5
						snow_message = "There's way too much snow here to properly move."
						snow_span = "danger"
					if (1.22 to INFINITY) // no way we can go through this easily
						standing_on_snow = 18
						snow_message = "There's way too much snow here to move!"
						snow_span = "danger"
*/
				if (snow_message && world.time >= mob.next_snow_message)
					mob << "<span class = '[snow_span]'>[snow_message]</span>"
					mob.next_snow_message = world.time+100

			else if (F.muddy && !H.lizard)
				if (F_area.weather == WEATHER_STORM)
					standing_on_snow = rand(4,5)
				else
					standing_on_snow = rand(2,3)
				if (world.time >= mob.next_mud_message)
					mob << "<span class = 'warning'>The mud slows you down.</span>"
					mob.next_mud_message = world.time+100

		if (mob.velocity_lastdir != -1)
			if (direct != mob.velocity_lastdir)
				mob.velocity = max(mob.velocity-pick(1,2), FALSE)

		switch(mob.m_intent)
			if ("run")
				mob.velocity = min(mob.velocity+1, 15)
				mob.velocity_lastdir = direct
				move_delay += mob.get_run_delay() + standing_on_snow
				if (mob_is_human)
					H.nutrition -= 0.005
					H.water -= 0.005
					if (H.stats["stamina"][1] > 0)
						--H.stats["stamina"][1]
					if (H.bodytemperature < H.species.body_temperature)
						H.bodytemperature += 0.66
			if ("walk")
				move_delay += mob.get_walk_delay() + standing_on_snow
				if (mob_is_human)
					H.nutrition -= 0.002
					H.water -= 0.002
			if ("stealth")
				move_delay += mob.get_stealth_delay() + standing_on_snow
				if (mob_is_human)
					H.nutrition -= 0.004
					H.water -= 0.004
			if ("proning")
				move_delay += standing_on_snow
				if (mob_is_human)
					H.nutrition -= 0.0015
					H.water -= 0.0015
		if (mob.drowsyness > 0)
			move_delay += 3

		if (istype(mob.l_hand, /obj/item/weapon/material/spear/sarissa))
			var/obj/item/weapon/material/spear/sarissa/sari = mob.l_hand
			if (sari.deployed == TRUE)
				move_delay += 6
		if (istype(mob.r_hand, /obj/item/weapon/material/spear/sarissa))
			var/obj/item/weapon/material/spear/sarissa/sari = mob.r_hand
			if (sari.deployed == TRUE)
				move_delay += 6
		if (mob.pulling)

			if (!mob.pulling.Adjacent(mob))
				mob.stop_pulling()

			else if (istype(mob.pulling, /mob))
				move_delay += 1.25
				if (istype(mob.pulling, /mob/living/carbon/human))
					var/mob/living/carbon/human/HH = mob.pulling
					for (var/obj/structure/noose/N in get_turf(HH))
						if (N.hanging == HH)
							mob.stop_pulling()

			else if (istype(mob.pulling, /obj/item/weapon/gun/projectile/automatic/stationary))
				move_delay += 1.00

			else if (istype(mob.pulling, /obj/structure))
				move_delay += 0.75

		if (mob_is_human)
			if (H.getStat("stamina") == (H.getMaxStat("stamina")/2) && H.m_intent == "run" && world.time >= H.next_stamina_message)
				H << "<span class = 'danger'>You're starting to tire from running so much.</span>"
				H.next_stamina_message = world.time + 20

			if (H.getStat("stamina") <= 0 && H.m_intent == "run")
				H << "<span class = 'danger'>You're too tired to keep running.</span>"
				if (H.m_intent != "walk")
					H.m_intent = "walk" // in case we don't have a m_intent HUD, somehow
					if (mob.HUDneed["mov_intent"])
						var/obj/screen/intent/I = mob.HUDneed["mov_intent"]
						I.update_icon()

		if (!mob_is_observer && F_is_valid_floor)
			if (istype(src, /mob/living/carbon/human))
				var/mob/living/carbon/human/HH = src
				if (isnull(HH.riding_mob))
					if (HH.crab)
						if (!istype(F, /turf/floor/beach))
							move_delay += F.get_move_delay()
			else
				move_delay += F.get_move_delay()

		var/tickcomp = FALSE //moved this out here so we can use it for vehicles
		if (config.Tickcomp)
			// move_delay -= 1.3 //~added to the tickcomp calculation below
			tickcomp = ((1/(world.tick_lag))*1.3) - 1.3
			move_delay += tickcomp

		if (mob.pulledby || mob.buckled) // Wheelchair driving!
			if (istype(mob.buckled, /obj/structure/bed/chair/wheelchair))
				if (mob_is_human)
					var/mob/living/carbon/human/driver = mob
					var/obj/item/organ/external/l_hand = driver.get_organ("l_hand")
					var/obj/item/organ/external/r_hand = driver.get_organ("r_hand")
					if ((!l_hand || l_hand.is_stump()) && (!r_hand || r_hand.is_stump()))
						return // No hands to drive your chair? Tough luck!
				//drunk wheelchair driving
				if (mob.confused && prob(40))
					direct = pick(cardinal)
				move_delay += 2
				return mob.buckled.relaymove(mob,direct)

		if (istype(src, /mob/living/carbon/human))
			var/mob/living/carbon/human/HH = src
			if (HH.riding == TRUE && !isnull(HH.riding_mob))
				move_delay = world.time + 0.5

		//We are now going to move
		moving = TRUE

		/* this is runtiming somehow, sometimes. But no errors. Now it's in a try-catch block so the var moving is always reset
		 * should fix the movement bug - Kachnov */
		try
			if (!mob.grab_list)
				mob.grab_list = list()
			for (var/datum in mob.grab_list)
				var/datum/D = datum
				if (D.gcDestroyed)
					mob.grab_list -= D

			//Something with grabbing things
			if (mob.grab_list.len)
			//	move_delay = max(move_delay, world.time + 7)
				move_delay += 1.0
				var/list/L = mob.ret_grab()
				if (istype(L, /list))
					if (L.len == 2)
						L -= mob
						var/mob/M = L[1]
						if (M)
							for (var/obj/structure/noose/N in get_turf(M))
								if (N.hanging == M)
									goto skipgrab

							if ((get_dist(mob, M) <= 1 || M.loc == mob.loc))
								var/turf/T = mob.loc
								. = ..()
								if (isturf(M.loc))
									var/diag = get_dir(mob, M)
									if ((diag - 1) & diag)
									else
										diag = null
									if ((get_dist(mob, M) > 1 || diag))
										step(M, get_dir(M.loc, T))
					else
						for (var/mob/M in L)
							M.other_mobs = TRUE
							if (mob != M)
								M.animate_movement = 3
						for (var/mob/M in L)
							spawn(0)
								step(M, direct)
								return
							spawn(1)
								M.other_mobs = null
								M.animate_movement = 2
								return

			else if (mob.confused && prob(40))
				step(mob, pick(cardinal))
			else
				. = mob.SelfMove(n, direct)

			skipgrab

			#define STOMP_TIME 3

			// wall stomping is bad
			if (!t1.density && !locate_dense_type(t1.contents, /obj/structure))

				//Step on nerds in our way
				if (mob_is_human)
					if (H.a_intent == I_HURT)
						for (var/mob/living/L in mob.loc)
							if (L.lying && L != H && !istype(L, /mob/living/simple_animal/mosquito)) // you could step on yourself, this fixes it - Kachnov
								H.visible_message("<span class = 'danger'>[H] steps on [L]!</span>")
								playsound(mob.loc, 'sound/effects/gore/fallsmash.ogg', 35, TRUE)
								L.adjustBruteLoss(rand(6,7))
								if (ishuman(L))
									L.emote("painscream")
//								H.next_change_dir[num2text(opposite_direction(direct))] = world.time + (STOMP_TIME*3)
//								H.movement_northsouth = null
//								H.movement_eastwest = null
//								movementMachine_clients -= src
//								sleep(STOMP_TIME)
								break
					else
						for (var/mob/living/L in mob.loc)
							if (L.lying && L != H)
								H.visible_message("<span class = 'warning'>[H] steps over [L].</span>")

			#undef STOMP_TIME

			// make animals acknowledge us
			if (mob_is_human)
				for (var/mob/living/simple_animal/complex_animal/C in living_mob_list) // living_mob_list fails here
					var/dist_x = abs(mob.x - C.x)
					var/dist_y = abs(mob.y - C.y)
					if (dist_x <= 10 && dist_y <= 10)
						C.onHumanMovement(mob)

			for (var/obj/item/weapon/grab/G in mob.grab_list)
				if (G.state == GRAB_NECK)
					mob.set_dir(reverse_dir[direct])
				G.adjust_position()

			for (var/obj/item/weapon/grab/G in mob.grabbed_by)
				G.adjust_position()
		catch (var/exception/E)
			pass(E)

		moving = FALSE

		mob.last_movement = world.time

		if (move_delay > world.time)
			move_delay -= world.time
		if (istype(src, /mob/living/carbon/human))
			var/mob/living/carbon/human/HH = src
			if (HH.riding == TRUE && !isnull(HH.riding_mob))
				move_delay = 0.5
			else
				move_delay /= mob.movement_speed_multiplier
		else
			move_delay /= mob.movement_speed_multiplier
			if (ordinal)
				move_delay *= ROOT2_FAST
		move_delay += world.time

		return .

	return

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
			var/turf/T = get_step(mob, direct)
			if (mob.check_holy(T))
				mob << "<span class='warning'>You cannot get past holy grounds while you are in this plane of existence!</span>"
				return
			else
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
		if (istype(S,/obj/fire))
			var/obj/fire/fire = S
			fire.Burn(mob)

	var/area/A = get_area_master(mob)
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
		if (istype(mob, /mob/living/carbon/human))
			var/mob/living/carbon/human/H = mob
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
		if (istype(mob, /mob/living/carbon/human))
			var/mob/living/carbon/human/H = mob
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
		if (istype(mob, /mob/living/carbon/human))
			var/mob/living/carbon/human/H = mob
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
		if (istype(mob, /mob/living/carbon/human))
			var/mob/living/carbon/human/H = mob
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

/client/verb/stopmovingdown()
	set name = ".stopmovingdown"
	set instant = TRUE
	if (mob && mob.movement_northsouth == SOUTH)
		mob.movement_northsouth = null

/client/verb/stopmovingright()
	set name = ".stopmovingright"
	set instant = TRUE
	if (mob && mob.movement_eastwest == EAST)
		mob.movement_eastwest = null

/client/verb/stopmovingleft()
	set name = ".stopmovingleft"
	set instant = TRUE
	if (mob && mob.movement_eastwest == WEST)
		mob.movement_eastwest = null