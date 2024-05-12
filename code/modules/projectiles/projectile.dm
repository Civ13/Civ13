/obj/item/projectile
	name = "projectile"
	icon = 'icons/obj/projectiles.dmi'
	icon_state = "bullet"
	density = FALSE								// we no longer use Bump() to detect collisions - Kachnov
	anchored = TRUE								// There's a reason this is here, Mport. God fucking damn it -Agouri. Find&Fix by Pete. The reason this is here is to stop the curving of emitter shots.
	pass_flags = PASSTABLE
	animate_movement = 0
	mouse_opacity = FALSE
	value = 0
	flags = CONDUCT
	var/angle = 0
	var/direction = EAST
	var/bumped = FALSE							// Prevents it from hitting more than one guy at once
	var/hitsound_wall = ""						// "ricochet"
	var/def_zone = ""							// Aiming at
	var/mob/firer = null						// Who shot it
	var/firer_original_dir = null
	var/obj/item/weapon/gun/firedfrom = null	// gun which shot it
	var/silenced = FALSE						// Attack message
	var/yo = null
	var/xo = null
	var/current = null
	var/shot_from = ""							// name of the object which shot us
	var/atom/original							// the target clicked (not necessarily where the projectile is headed). Should probably be renamed to 'target' or something.
	var/turf/starting							// the projectile's starting turf
	var/list/permutated = list()				// we've passed through these atoms, don't try to hit them again

	var/blockedhit = FALSE						// If blocked by shield/armor/etc

	var/launch_from_trench = FALSE
	var/launch_from_vehicle = FALSE
	var/overcoming_trench = FALSE 				// If bullet flies out of trench, it will be more difficult to hit a target in another trench

	var/fired_from_turret = FALSE
	var/obj/structure/vehicleparts/axis/fired_from_axis = null

	var/p_x = 16
	var/p_y = 16								// the pixel location of the tile that the player clicked. Default is the center

	var/accuracy = 0
	var/dispersion = 0.0

	var/damage = 10
	var/damage_type = BRUTE						// BRUTE, BURN, TOX, OXY, CLONE, HALLOSS are the only things that should be in here
	var/nodamage = FALSE						// Determines if the projectile will skip any damage inflictions
	var/taser_effect = FALSE					// If set then the projectile will apply it's agony damage and stun damage using stun_effect_act() to mobs it hits, and other damage will be ignored
	var/check_armor = "gun"						// Defines what armor to use when it hits things.  Must be set to gun, arrow, energy or bomb	//Cael - bio and rad are also valid
	var/projectile_type = /obj/item/projectile
	var/penetrating = 0							// If greater than zero, the projectile will pass through dense objects as specified by on_penetrate()
	var/gibs = FALSE
	var/crushes = FALSE
	var/kill_count = 35							// This will de-increment every process(). When == 0, it will delete the projectile.
		//Effects
	var/stun = FALSE
	var/weaken = FALSE
	var/paralyze = FALSE
	var/irradiate = FALSE
	var/stutter = FALSE
	var/eyeblur = FALSE
	var/drowsy = FALSE
	var/agony = FALSE
	var/poisonous = FALSE
	var/embed = FALSE							// whether or not the projectile can embed itself in the mob

	var/hitscan = 0		// whether the projectile should be hitscan
	var/step_delay = 0.25	// the delay between iterations if not a hitscan projectile

	var/did_muzzle_effect = FALSE
	var/firer_turf

	// effect types to be used
	var/muzzle_type
	var/tracer_type
	var/impact_type = /obj/effect/projectile/impact

	var/passed_trenches = 0 					// Number of tiles with trenches that a bullet passed in a row

	var/datum/plot_vector/trajectory	// used to plot the path of the projectile
	var/datum/vector_loc/location		// current location of the projectile in pixel space
	var/matrix/effect_transform			// matrix to rotate and scale projectile effects - putting it here so it doesn't
										// have to be recreated multiple times

	armor_penetration = 90

	/* since a lot of WW2 guns use similar ammo, this is calculated during runtime
	 * based on gun type and the distance between the firer and person hit.
	 * Right now, only boltactions & heavysniper guns get a high KD chance. */\

	var/KD_chance = 5
	var/execution = FALSE

	var/is_shrapnel = FALSE

	var/useless = FALSE

	var/can_hit_in_trench = TRUE
	var/btype = "normal" 				// normal, AP (armor piercing) and HP (hollow point)
	var/atype = "normal"
	should_save = 0

/obj/item/projectile/New()
	..()
	damage *=global_damage_modifier

/obj/item/projectile/proc/checktype()
	if (btype == "AP")
		damage *= 0.70
		if (penetrating == 0)
			penetrating += 1
		penetrating *= 2
		armor_penetration *= 3
		return
	else if (btype == "HP")
		damage *= 1.3
		penetrating = 0
		armor_penetration /= 3
		return

/obj/item/projectile/Destroy()
	projectile_list -= src
	walk(src, 0)
	..()

//TODO: make it so this is called more reliably, instead of sometimes by bullet_act() and sometimes not
/obj/item/projectile/proc/on_hit(var/atom/target, var/blocked = FALSE, var/def_zone = null)
	if (blocked >= 2)		return FALSE//Full block
	if (!isliving(target))	return FALSE
	if (isanimal(target))	return FALSE
	var/mob/living/L = target
	L.apply_effects(stun, weaken, paralyze, irradiate, stutter, eyeblur, drowsy, agony, poisonous, blocked)
	return TRUE

/obj/item/projectile/proc/on_impact(var/atom/A)
	impact_effect()		// generate impact effect
	playsound(src, "ric_sound", 50, TRUE, -2)

	spawn(25)
		if (src)
			qdel(src)
	return TRUE

//Checks if the projectile is eligible for embedding. Not that it necessarily will.
/obj/item/projectile/proc/can_embed()
	//embed must be enabled and damage type must be brute
	if (!embed || damage_type != BRUTE)
		return FALSE
	return TRUE

/obj/item/projectile/proc/get_structure_damage()
	if (damage_type == BRUTE || damage_type == BURN)
		return damage
	return FALSE

//return TRUE if the projectile should be allowed to pass through after all, FALSE if not.
/obj/item/projectile/proc/check_penetrate(var/atom/A)
	if (istype(A, /turf/wall))
		if (prob(92))
			return FALSE
	return TRUE

/obj/item/projectile/proc/check_fire(atom/target as mob, var/mob/living/user as mob)  //Checks if you can hit them or not.
	check_trajectory(target, user, pass_flags, flags)

//sets the click point of the projectile using mouse input params
/obj/item/projectile/proc/set_clickpoint(var/params)
	var/list/mouse_control = params2list(params)
	if (mouse_control["icon-x"])
		p_x = text2num(mouse_control["icon-x"])
	if (mouse_control["icon-y"])
		p_y = text2num(mouse_control["icon-y"])

	//randomize clickpoint a bit based on dispersion
	if (dispersion)
		var/radius = round((dispersion*0.443)*world.icon_size*0.8) //0.443 = sqrt(pi)/4 = 2a, where a is the side length of a square that shares the same area as a circle with diameter = dispersion
		p_x = between(0, p_x + rand(-radius, radius), world.icon_size)
		p_y = between(0, p_y + rand(-radius, radius), world.icon_size)

//called to launch a projectile from a gun
/obj/item/projectile/proc/launch(atom/target, mob/user, obj/item/weapon/gun/launcher, var/target_zone, var/x_offset=0, var/y_offset=0)

	var/turf/curloc = get_turf(launcher)
	var/turf/targloc = get_turf(target)

	if (!istype(targloc) || !istype(curloc))
		qdel(src)
		return TRUE

	if (istype(curloc, /turf/floor/trench))
		launch_from_trench = TRUE

	if(user.buckled)
		for (var/obj/structure/turret/T in curloc)
			fired_from_turret = TRUE
			layer = 11
		for (var/obj/structure/vehicleparts/frame/F in curloc)
			fired_from_axis = F.axis

	firer = user
	firer_original_dir = firer.dir
	firedfrom = launcher

	alpha = 0

	if (istype(firedfrom, /obj/item/weapon/gun/projectile/automatic/stationary))
		if (prob(80))
			def_zone = "chest"
	else
		def_zone = target_zone

	if (!def_zone)
		def_zone = "chest"

	if (user == target) //Shooting yourself
		do_bullet_act(user, target_zone)
		on_impact(user)
		qdel(src)
		return FALSE

	if (targloc == curloc) //Shooting something in the same turf
		do_bullet_act(target, target_zone)
		on_impact(target)
		qdel(src)
		return FALSE

	original = target
	loc = curloc
	starting = curloc

	yo = targloc.y - curloc.y + y_offset
	xo = targloc.x - curloc.x + x_offset

	shot_from = launcher
	silenced = launcher.silencer

	projectile_list += src

	return FALSE

/obj/item/projectile/proc/launch_fragment(atom/target)

	is_shrapnel = TRUE
	name = "shrapnel"

	var/turf/curloc = loc
	var/turf/targloc = get_turf(target)

	if (!istype(targloc) || !istype(curloc))
		qdel(src)
		return TRUE

	firer = null
	firedfrom = null
	def_zone = "chest"

	if (targloc == curloc) //Shooting something in the same turf
		do_bullet_act(target, "chest")
		on_impact(target)
		qdel(src)
		return FALSE

	original = target
	loc = curloc
	starting = curloc
	current = curloc

	yo = targloc.y - curloc.y
	xo = targloc.x - curloc.x

	shot_from = null
	silenced = FALSE

	projectile_list += src

	return FALSE

//called to launch a projectile from a gun
/obj/item/projectile/proc/launch_from_gun(atom/target, mob/user, obj/item/weapon/gun/launcher, var/target_zone, var/x_offset=0, var/y_offset=0)
	if (user == target) //Shooting yourself
		do_bullet_act(user, target_zone)
		qdel(src)
		return FALSE

	loc = get_turf(user) //move the projectile out into the world

	firer = user
	firer_original_dir = firer.dir
	firer_turf = get_turf(firer)
	firedfrom = launcher
	shot_from = launcher.name
	if (launcher.silencer)
		silenced = TRUE
	else
		silenced = FALSE

	projectile_list += src

	return launch(target, target_zone, x_offset, y_offset)

//Used to change the direction of the projectile in flight.
/obj/item/projectile/proc/redirect(var/turf/new_target, var/atom/starting_loc)
	original = new_target

	setup_trajectory(starting_loc, new_target)

//Called when the projectile intercepts a mob. Returns TRUE if the projectile hit the mob, FALSE if it missed and should keep flying.
/obj/item/projectile/proc/attack_mob(var/mob/living/target_mob, var/distance, var/miss_modifier=0)
	if (firer && istype(firer, /mob/living/simple_animal/hostile/human) && target_mob && istype(target_mob, /mob/living/simple_animal/hostile/human))
		var/mob/living/simple_animal/hostile/human/HM = firer
		var/mob/living/simple_animal/hostile/human/HM2 = target_mob
		if(HM.faction == HM2.faction)
			return

	if (is_shrapnel)
		var/hit_zone = "head"

		if (prob(50))
			for (var/zone in shuffle(organ_rel_size))
				if (prob(organ_rel_size[zone]))
					hit_zone = zone

		if (ishuman(target_mob))

			var/mob/living/human/H = target_mob
			if (hit_zone == "head")
				if (H.head && istype(H.head, /obj/item/clothing/head/helmet))
					var/obj/item/clothing/head/helmet/helmet = H.head
					if (helmet.block_check(src))
						visible_message(SPAN_WARNING("[H]'s helmet deflects the shrapnel!"))
						return
			else if (hit_zone == "chest")
				if (H.wear_suit && istype(H.wear_suit, /obj/item/clothing/suit/armor))
					var/obj/item/clothing/suit/armor/armor = H.wear_suit
					if (armor.block_check(src))
						visible_message(SPAN_WARNING("[H]'s armor deflects the shrapnel!<"))
						return

		do_bullet_act(target_mob, hit_zone)
		if (blockedhit == FALSE)
			if (silenced)
				to_chat(target_mob, SPAN_DANGER("You've been hit in \the [parse_zone(hit_zone)] by the shrapnel!"))
			else
				visible_message(SPAN_DANGER("\The [target_mob] is hit by the shrapnel in the [parse_zone(hit_zone)]!"))
		return FALSE

	if (!istype(target_mob))
		return FALSE

	if (!firedfrom)
		return FALSE

	// non-projectile gun types will be removed soon, this code doesn't support them anymore - Kachnov
	if (!istype(firedfrom, /obj/item/weapon/gun/projectile))
		return FALSE

	if (!def_zone)
		def_zone = "chest"

	var/redirection_parts = target_mob.redirection_list[def_zone]
	var/hit_zone = null
	var/hitchance = target_mob.body_part_size[def_zone]

	var/distance_modifier = 5
	if (distance != 0)
		distance_modifier = 5 / sqrt(distance)

	if(distance <= 3)
		hitchance = 100

	hitchance = clamp(hitchance * distance_modifier, 0, 100)

	if (prob(hitchance))
		hit_zone = def_zone
	else
		for(var/part in redirection_parts)
			hitchance = clamp(target_mob.body_part_size[def_zone], 0, 100)
			if (prob(hitchance) && !hit_zone)
				hit_zone = part

	if (hit_zone)
		do_bullet_act(target_mob, hit_zone)

	if (!target_mob)
		return

	if (target_mob.takes_less_damage)
		switch (damage)
			if (DAMAGE_LOW-5 to DAMAGE_LOW+5)
				damage = DAMAGE_LOW - 6
			if (DAMAGE_MEDIUM-5 to DAMAGE_MEDIUM+5)
				damage = DAMAGE_MEDIUM - 6
			if (DAMAGE_MEDIUM_HIGH-5 to DAMAGE_MEDIUM_HIGH+5)
				damage = DAMAGE_MEDIUM_HIGH - 6
			if (DAMAGE_HIGH-5 to DAMAGE_HIGH+5)
				damage = DAMAGE_HIGH - 6
			if (DAMAGE_VERY_HIGH-5 to DAMAGE_VERY_HIGH+5)
				damage = DAMAGE_VERY_HIGH - 6
			if (DAMAGE_OH_GOD-5 to DAMAGE_OH_GOD+5)
				damage = DAMAGE_OH_GOD - 6
	// 50% chance of variable damage that stays within the boundaries of the bullet's damage tier
	else
		var/variation = 0
		switch (damage)
			if (DAMAGE_LOW-5 to DAMAGE_LOW+5)
				variation = damage - DAMAGE_LOW
			if (DAMAGE_MEDIUM-5 to DAMAGE_MEDIUM+5)
				variation = damage - DAMAGE_MEDIUM
			if (DAMAGE_MEDIUM_HIGH-5 to DAMAGE_MEDIUM_HIGH+5)
				variation = damage - DAMAGE_MEDIUM_HIGH
			if (DAMAGE_HIGH-5 to DAMAGE_HIGH+5)
				variation = damage - DAMAGE_HIGH
			if (DAMAGE_VERY_HIGH-5 to DAMAGE_VERY_HIGH+5)
				variation = damage - DAMAGE_VERY_HIGH
			if (DAMAGE_OH_GOD-5 to DAMAGE_OH_GOD+5)
				variation = damage - DAMAGE_OH_GOD
		if (variation > 0)
			damage += rand(-variation, variation)

	//hit messages
	if (blockedhit == FALSE)
		if (silenced)
			if(hit_zone)
				target_mob << "<span class='danger'>You've been hit in the [parse_zone(hit_zone)] by \the [src]!</span>"
		else
			if(hit_zone)
				visible_message("<span class='danger'>\The [target_mob] is hit in the [parse_zone(hit_zone)]!</span>")//X has fired Y is now given by the guns so you cant tell who shot you if you could not see the shooter
		if (istype(target_mob, /mob/living/simple_animal/hostile/human/zombie))
			var/mob/living/simple_animal/hostile/human/zombie/Z = target_mob
			if(hit_zone)
				Z.limb_hit(hit_zone)
	if (istype(target_mob, /mob/living/simple_animal/hostile/human) && target_mob.stat != DEAD && prob(33))
		var/list/screamlist = list('sound/voice/screams/scream1.ogg','sound/voice/screams/scream2.ogg','sound/voice/screams/scream3.ogg','sound/voice/screams/scream4.ogg','sound/voice/screams/scream5.ogg','sound/voice/screams/scream6.ogg',)
		playsound(loc, pick(screamlist), 100, extrarange = 50)

	//admin logs
	if (!no_attack_log)
		if (istype(firer, /mob))

			var/attacker_message = "shot with \a [type]"
			var/victim_message = "shot with \a [type]"
			var/admin_message = "shot (\a [type])"

			admin_attack_log(firer, target_mob, attacker_message, victim_message, admin_message)
		else
			if (target_mob && target_mob.ckey)
				target_mob.attack_log += "\[[time_stamp()]\] <b>UNKNOWN SUBJECT (No longer exists)</b> shot <b>[target_mob]/[target_mob.ckey]</b> with <b>\a [src]</b>"
				msg_admin_attack("UNKNOWN shot [target_mob] ([target_mob.ckey]) with \a [src] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[target_mob.x];Y=[target_mob.y];Z=[target_mob.z]'>JMP</a>)", "", target_mob.ckey)

	//sometimes bullet_act() will want the projectile to continue flying
	if (!hit_zone)
		playsound(get_turf(target_mob), "miss_sound", 100, TRUE)
		return FALSE

	return TRUE

/obj/item/projectile/proc/get_angle()
	var/angle = trajectory.return_angle()
	if (angle < 0)
		angle = 180 + (180 - abs(angle))
	return angle

/obj/item/projectile/proc/get_distance()
	return permutated.len

/obj/item/projectile/proc/get_direction()
	if(angle >= 10 && angle <= 80)
		return NORTHEAST
	else if(angle > 80 && angle < 100)
		return NORTH
	else if(angle >= 100 && angle <= 170)
		return NORTHWEST
	else if(angle > 170 && angle < 190)
		return WEST
	else if(angle >= 190 && angle <= 260)
		return SOUTHWEST
	else if(angle > 260 && angle < 280)
		return SOUTH
	else if(angle >= 280 && angle <= 350)
		return SOUTHEAST
	else
		return EAST

/obj/item/projectile/proc/handleTurf(var/turf/T, forced=0, var/list/untouchable = list())
	if(atype == "NUCLEAR")
		radiation_pulse(T, 	damage / 100, damage / 10, damage / 25, 0)
	if (!T || !istype(T))
		return FALSE

	if(starting == T && fired_from_turret)
		forceMove(T)
		permutated += T
		return TRUE

	if ((bumped && !forced) || (permutated.len && (permutated.Find(T))))
		return FALSE

	var/direction = get_direction()

	var/turf/previous_step = starting
	if(T!= starting && permutated.len)
		previous_step = permutated[permutated.len]

	var/passthrough = TRUE //if the projectile should continue flying
	var/passthrough_message = null
	var/is_trench = istype(T, /turf/floor/trench)

	if(fired_from_turret && fired_from_axis) // A bullet fired from a turret has no obstacles inside the vehicle where it was fired
		for (var/obj/structure/vehicleparts/frame/F in T)
			if(fired_from_axis && fired_from_axis == F.axis)
				forceMove(T)
				permutated += T
				return TRUE
			else
				fired_from_turret = FALSE

	if(is_trench)
		passed_trenches += 1
	else
		passed_trenches = 0

	if (!is_trench && launch_from_trench && firer.prone && !overcoming_trench) // shooting while lying down from trench to trench is impossible [translated]
		T.visible_message(SPAN_WARNING("\The [name] hits the wall of the trench!"))
		on_impact(previous_step)
		qdel(src)
		return

	// Checking for vehicle penetration
	if (T != starting)
		for (var/obj/structure/vehicleparts/frame/F in T.contents)
			var/penloc = F.get_wall_name(direction)
			if (!F.CheckPen(src,penloc))
				F.bullet_act(src,penloc)
				passthrough = FALSE
				visible_message(SPAN_WARNING("\The [name] fails to penetrate \the [penloc] wall"))
				bumped = TRUE
				if (istype(src, /obj/item/projectile/shell))
					var/obj/item/projectile/shell/S = src
					if (!istype(src, /obj/item/projectile/shell/missile))
						S.initiate(previous_step)
					else
						forceMove(T)
						permutated += T
						on_impact(T)
						S.initiate(T)
				else
					on_impact(T)
					loc = null
					qdel(src)
				return FALSE
			else
				if (istype(src, /obj/item/projectile/shell))
					var/obj/item/projectile/shell/S = src
					on_impact(T)
					if(S.initiated)
						F.bullet_act(src,penloc)
						passthrough = TRUE
						forceMove(T)
						permutated += T
						S.initiate(T)
					else
						visible_message(SPAN_DANGER("\The [name] penetrates \the [penloc] wall!"))

	if (!is_trench && launch_from_trench && !overcoming_trench)
		overcoming_trench = TRUE

	if (T.density)
		passthrough = FALSE
	else
		// needs to be its own loop for reasons
		for (var/obj/O in T.contents)
			var/hitchance = 0 // a light, for example. This was 66%, but that was unusually accurate, thanks BYOND
			if (O == original)
				if (O.density)
					if (istype(O, /obj/covers/jail))
						hitchance = 0
					else
						hitchance = 100
				else if (isitem(O) && !density) // any item
					hitchance = 0
				if (prob(hitchance))
					if (istype(O, /obj/structure))
						var/obj/structure/S = O
						if (!S.CanPass(src, original))
							on_impact(T)
							do_bullet_act(O)
							passthrough = FALSE
					else
						on_impact(T)
						do_bullet_act(O)
						bumped = TRUE
						loc = null
						qdel(src)
						return FALSE
					O.visible_message(SPAN_WARNING("\The [name] flies over \the [O]!"))
					break
	for (var/atom/movable/AM in T.contents)
		if (!untouchable.Find(AM))
			if (isliving(AM) && AM != firer)
				var/mob/living/L = AM
				if ((!L.lying || T == get_turf(original) || execution))
					// if they have a neck grab on someone, that person gets hit instead
					var/obj/item/weapon/grab/G = locate() in L
					if (G && G.state >= GRAB_NECK && G.affecting.stat < UNCONSCIOUS)
						visible_message(SPAN_DANGER("[L] uses [G.affecting] as a shield!"))
						G.affecting.pre_bullet_act(src)
						attack_mob(G.affecting)
						if (!G.affecting.lying)
							passthrough = FALSE
					else
						var/firer_dist = get_dist(firer,T)
						var/hit_chace = 100
						var/tmp_zone = def_zone

						if (L.lying || L.prone)
							if (firer_dist > 3)
								hit_chace = 100 - (sqrt(firer_dist) * 15)

						// Check for trench protection
						if (is_trench)
							if (passed_trenches * 2 <= firer_dist)
								hit_chace = 100 - (sqrt(firer_dist) * 10)
								def_zone = "head"
								if (L.lying || L.prone)
									hit_chace = 0

						if (firer_dist <= 3)
							hit_chace = 100

						if (prob(hit_chace))
							passthrough = !attack_mob(L, firer_dist)
							return
						else
							visible_message(SPAN_WARNING("\The [name] flies over \the [AM]!"))
						def_zone = tmp_zone

			else if (isobj(AM) && AM != firedfrom)
				var/obj/O = AM
				if (!(istype(O, /obj/structure/vehicleparts/frame) && O.loc == src.loc))
					if (O.density || istype(O, /obj/structure/window/classic) || istype(O, /obj/structure/table)) // hack
						O.pre_bullet_act(src)
						if (O.bullet_act(src, def_zone) != PROJECTILE_CONTINUE)
							if (O && !O.gcDestroyed)
								if (O.density && !istype(O, /obj/structure))
									if (istype(O, /obj/covers))
										var/obj/covers/CVR = O
										if (prob(100-CVR.hardness) && CVR.density)
											passthrough = TRUE
											passthrough_message = SPAN_WARNING("\The [name] penetrates through \the [CVR]!")
										else
											passthrough = FALSE
									else if (istype(O, /obj/item/weapon/gun/projectile/automatic/stationary))
										var/obj/covers/MG = O
										if (prob(100-MG.hardness))
											passthrough = TRUE
										else
											passthrough = FALSE
									else
										passthrough = FALSE
								else if (istype(O, /obj/structure))
									var/obj/structure/S = O
									if (!S.CanPass(src, original))
										passthrough = FALSE
									else if (S.density)
										if (!S.climbable && !istype(S, /obj/structure/vehicleparts/frame))
											passthrough_message = SPAN_WARNING("\The [name] penetrates through \the [S]!")
					if (istype(O, /obj/covers/repairedfloor) && istype(src, /obj/item/projectile/shell))
						if ((src.atype == "cannonball" && prob(18)) || src.atype != "cannonball")
							O.pre_bullet_act(src)
							if (O.bullet_act(src, def_zone) != PROJECTILE_CONTINUE)
								if (O && !O.gcDestroyed)
									passthrough = FALSE

	for(var/obj/structure/window/barrier/S in T)
		if (!S.CanPassOut(src))
			do_bullet_act(T)
			passthrough = FALSE

	if (istype(src, /obj/item/projectile/shell))
		var/obj/item/projectile/shell/S = src
		if(S.initiated)
			on_impact(T)
			S.initiate(T)

	for (var/obj/structure/vehicleparts/frame/F in loc)
		var/penloc = F.get_wall_name(opposite_direction(direction))
		if (F.is_ambrasure(penloc) && loc == starting)
			if(!istype(src, /obj/item/projectile/shell/missile))
				visible_message(SPAN_WARNING("A bullet flies out of the embrasure"))
			else
				var/obj/item/projectile/shell/missile/M = src
				M.initiate(T)
		else if (!F.CheckPen(src,penloc))
			passthrough = FALSE
			T.visible_message(passthrough_message)
			F.bullet_act(src,penloc)
			bumped = TRUE
			loc = null
			qdel(src)

	//penetrating projectiles can pass through things that otherwise would not let them
	++penetrating
	if (((T.density || istype(T, /obj/structure/window/barrier)) && penetrating > 0))
		if (check_penetrate(T))
			passthrough = TRUE
			passthrough_message = SPAN_WARNING("\The [name] penetrates \the [T]!")
		--penetrating

	if (istype(src, /obj/item/projectile/shell))
		if (loc == trajectory.target)
			var/obj/item/projectile/shell/S = src
			on_impact(T)
			S.initiate(loc)
			return FALSE

	//the bullet passes through the turf
	if (passthrough)
		//move ourselves onto T so we can continue on our way.
		forceMove(T)
		permutated += T
		if (passthrough_message)
			T.visible_message(passthrough_message)
		return TRUE

	// for shrapnel
	bumped = TRUE

	// hack to make projectiles disappear immediately, not sure why qdel() doesn't work for this
	loc = null

	//stop flying
	on_impact(T)
	qdel(src)

	return FALSE

/obj/item/projectile/ex_act()
	return //explosions probably shouldn't delete projectiles

/obj/item/projectile/process()
	//plot the initial trajectory

	var/firstmove = FALSE
	alpha = 255

	if (!trajectory)
		setup_trajectory(loc)
		firstmove = TRUE
		alpha = 0

	angle = get_angle()

	if (src && loc)
		if (--kill_count < 1)
			for (var/atom/movable/AM in loc)
				do_bullet_act(AM)
			do_bullet_act(loc)
			on_impact(loc) //for any final impact behaviours
			qdel(src)
			return
		var/area/block_area = get_area(src)
		if (map && firer && map.check_caribbean_block(firer, loc) && !map.allow_bullets_through_blocks.Find(block_area))
			qdel(src)
			return
		if ((!( current ) || loc == current))
			current = locate(min(max(x + xo, 1), world.maxx), min(max(y + yo, 1), world.maxy), z)

		trajectory.increment()	// increment the current location

		// just before we enter nullspace
		if (!trajectory.return_location(location))
			for (var/atom/movable/AM in loc)
				do_bullet_act(AM)
			do_bullet_act(loc)
			on_impact(loc)
			qdel(src)
			return

		location = trajectory.return_location(location)		// update the locally stored location data

		if (!location)
			qdel(src)	// if it's left the world... kill it
			return

		var/list/_untouchable = list()
		var/src_loc = get_turf(src)
		if (ismob(firer) && (!firer.prone && !firer.lying))
			if (firstmove)
				for (var/obj/structure/window/barrier/S in src_loc)
					_untouchable += S
			else
				if (firer)
					for (var/obj/structure/barricade/B in src_loc)
						if (get_dist(firer, B) == 1)
							_untouchable += B

					// Incompleted wall (half walls)
					for (var/obj/covers/dirt_wall/blocks/incomplete/B in src_loc)
						if (get_dist(firer, B) == 1)
							_untouchable += B
					for (var/obj/covers/clay_wall/incomplete/B in src_loc)
						if (get_dist(firer, B) == 1)
							_untouchable += B
					for (var/obj/covers/clay_wall/sumerian/incomplete/B in src_loc)
						if (get_dist(firer, B) == 1)
							_untouchable += B
					for (var/obj/covers/brick_wall/incomplete/B in src_loc)
						if (get_dist(firer, B) == 1)
							_untouchable += B

		handleTurf(loc, untouchable = _untouchable)
		before_move()
		forceMove(location.return_turf())
		update_icon()

		if (!did_muzzle_effect)
			muzzle_effect()
		else if (!bumped && loc)
			tracer_effect()

/obj/item/projectile/proc/do_bullet_act(var/atom/A, var/zone)
	if (A && A != firer && A != firedfrom)
		A.pre_bullet_act(src)
		if (zone)
			return A.bullet_act(src, zone)
		else
			return A.bullet_act(src)
	return FALSE

/obj/item/projectile/proc/before_move()
	return FALSE

/obj/item/projectile/proc/setup_trajectory(var/turf/starting_loc)
	// plot the initial trajectory
	trajectory = new()
	trajectory.setup(starting_loc, original, pixel_x, pixel_y, dispersion)

	// generate this now since all visual effects the projectile makes can use it
	effect_transform = new()
	effect_transform.Turn(-trajectory.return_angle())		//no idea why this has to be inverted, but it works

	transform = turn(transform, -(trajectory.return_angle() + 90)) //no idea why 90 needs to be added, but it works

/obj/item/projectile/update_icon()
	var/dist = permutated.len * world.icon_size
	pixel_x = (cos(angle) * dist) - ((x - starting.x) * world.icon_size)
	pixel_y = (sin(angle) * dist) - ((y - starting.y) * world.icon_size)

/obj/item/projectile/proc/muzzle_effect()
	if (silenced)
		did_muzzle_effect = TRUE
		return
	if (ispath(muzzle_type))
		var/obj/effect/projectile/M = new muzzle_type(starting)
		if (istype(M))
			M.activate(get_angle())
	did_muzzle_effect = TRUE

/obj/item/projectile/proc/tracer_effect()
	if (ispath(tracer_type))
		for(var/i = 1, i <= 2, i++)
			var/obj/effect/projectile/P = new tracer_type(starting)
			if (istype(P))
				P.alpha *= 0.6 / i
				var/px_dist = ((permutated.len - 1) * world.icon_size) + (i * 16)
				P.activate(get_angle(), px_dist, starting)

/obj/item/projectile/proc/impact_effect()
	if (ispath(impact_type))
		var/turf/effect_loc = null
		if(permutated.len > 0)
			effect_loc = permutated[permutated.len]
		else
			effect_loc = starting
		for(var/i = 0, i < 5, i++)
			var/obj/effect/projectile/P = new impact_type(effect_loc)
			if (istype(P))
				P.activate(get_angle())

//Helper proc to check if you can hit them or not.

/proc/check_trajectory(atom/target as mob|obj, atom/firer as mob|obj, var/pass_flags=PASSTABLE|PASSGLASS|PASSGRILLE, flags=null)
	if (!istype(target) || !istype(firer))
		return FALSE

//	var/obj/item/projectile/test/trace = new /obj/item/projectile/test(get_turf(firer)) //Making the test....
	var/obj/item/projectile/trace = new (get_turf(firer))
	trace.invisibility = 101

	//Set the flags and pass flags to that of the real projectile...
	if (!isnull(flags))
		trace.flags = flags
	trace.pass_flags = pass_flags

	var/output = trace.launch(target) //Test it!
	qdel(trace) //No need for it anymore
	return output //Send it back to the gun!