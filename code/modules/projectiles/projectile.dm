
/obj/item/projectile
	name = "projectile"
	icon = 'icons/obj/projectiles.dmi'
	icon_state = "bullet"
	density = FALSE // we no longer use Bump() to detect collisions - Kachnov
	anchored = TRUE //There's a reason this is here, Mport. God fucking damn it -Agouri. Find&Fix by Pete. The reason this is here is to stop the curving of emitter shots.
	pass_flags = PASSTABLE
	mouse_opacity = FALSE
	value = 0
	var/bumped = FALSE //Prevents it from hitting more than one guy at once
	var/hitsound_wall = ""//"ricochet"
	var/def_zone = ""	//Aiming at
	var/mob/firer = null//Who shot it
	var/firer_original_dir = null
	var/obj/item/weapon/gun/firedfrom = null // gun which shot it
	var/silenced = FALSE	//Attack message
	var/yo = null
	var/xo = null
	var/current = null
	var/shot_from = "" // name of the object which shot us
	var/atom/original = null // the target clicked (not necessarily where the projectile is headed). Should probably be renamed to 'target' or something.
	var/turf/starting = null // the projectile's starting turf
	var/list/permutated = list() // we've passed through these atoms, don't try to hit them again

	var/blockedhit = FALSE //If blocked by shield/armor/etc

	var/p_x = 16
	var/p_y = 16 // the pixel location of the tile that the player clicked. Default is the center

	var/accuracy = 0
	var/dispersion = 0.0

	var/damage = 10
	var/damage_type = BRUTE //BRUTE, BURN, TOX, OXY, CLONE, HALLOSS are the only things that should be in here
	var/nodamage = FALSE //Determines if the projectile will skip any damage inflictions
	var/taser_effect = FALSE //If set then the projectile will apply it's agony damage using stun_effect_act() to mobs it hits, and other damage will be ignored
	var/check_armor = "gun" //Defines what armor to use when it hits things.  Must be set to gun, arrow, energy or bomb	//Cael - bio and rad are also valid
	var/projectile_type = /obj/item/projectile
	var/penetrating = 0 //If greater than zero, the projectile will pass through dense objects as specified by on_penetrate()
	var/gibs = FALSE
	var/crushes = FALSE
	var/kill_count = 30 //This will de-increment every process(). When == 0, it will delete the projectile.
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
	var/embed = FALSE // whether or not the projectile can embed itself in the mob

	var/did_muzzle_effect = FALSE

	// effect types to be used
	var/muzzle_type = null
	var/tracer_type = null
	var/impact_type = null

	var/datum/plot_vector/trajectory = null	// used to plot the path of the projectile
	var/datum/vector_loc/location = null		// current location of the projectile in pixel space
	var/matrix/effect_transform = null			// matrix to rotate and scale projectile effects - putting it here so it doesn't
										//  have to be recreated multiple times

	armor_penetration = 90

	/* since a lot of WW2 guns use similar ammo, this is calculated during runtime
	 * based on gun type and the distance between the firer and person hit.
	 * Right now, only boltactions & heavysniper guns get a high KD chance. */\

	var/KD_chance = 5
	var/execution = FALSE

	var/is_shrapnel = FALSE

	var/useless = FALSE

	var/can_hit_in_trench = 1

	var/btype = "normal" //normal, AP (armor piercing) and HP (hollow point)

/obj/item/projectile/proc/checktype()
	if (btype == "AP")
		damage *= 0.70
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
	impact_effect(effect_transform)		// generate impact effect
	playsound(src, "ric_sound", 50, TRUE, -2)
	if (istype(src, /obj/item/projectile/bullet))
		if (istype(A, /turf))
			var/turf/T = A
			if (prob(25) && T.bullethole_count < 10 && T.density == TRUE)
				T.overlays += image('icons/turf/walls.dmi', "bullethole[rand(1,15)]")
				T.bullethole_count++
		else if (istype(A, /obj/covers))
			var/obj/covers/C = A
			if (prob(25) && C.bullethole_count < 10 && C.density == TRUE)
				C.overlays += image('icons/turf/walls.dmi', "bullethole[rand(1,15)]")
				C.bullethole_count++
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
	return 0

//return TRUE if the projectile should be allowed to pass through after all, FALSE if not.
/obj/item/projectile/proc/check_penetrate(var/atom/A)
	if (istype(A, /turf/wall))
		if (prob(50))
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

	firer = user
	firer_original_dir = firer.dir
	firedfrom = launcher

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
	silenced = launcher.silenced

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
	firedfrom = launcher
	shot_from = launcher.name
	silenced = launcher.silenced

	projectile_list += src

	return launch(target, target_zone, x_offset, y_offset)

//Used to change the direction of the projectile in flight.
/obj/item/projectile/proc/redirect(var/new_x, var/new_y, var/atom/starting_loc, var/mob/new_firer=null)
	var/turf/new_target = locate(new_x, new_y, z)

	original = new_target
	if (new_firer)
		firer = src
		firer_original_dir = firer.dir

	setup_trajectory(starting_loc, new_target)

//Called when the projectile intercepts a mob. Returns TRUE if the projectile hit the mob, FALSE if it missed and should keep flying.
/obj/item/projectile/proc/attack_mob(var/mob/living/target_mob, var/distance, var/miss_modifier=0)

	if (is_shrapnel)
		var/hit_zone = "head"

		if (prob(50))
			for (var/zone in shuffle(organ_rel_size))
				if (prob(organ_rel_size[zone]))
					hit_zone = zone

		if (ishuman(target_mob))

			var/mob/living/carbon/human/H = target_mob
			if (hit_zone == "head")
				if (H.head && istype(H.head, /obj/item/clothing/head/helmet))
					var/obj/item/clothing/head/helmet/helmet = H.head
					if (helmet.block_check(src))
						visible_message("<span class='warning'>[H]'s helmet deflects the shrapnel!</span>")
						return
			else if (hit_zone == "chest")
				if (H.wear_suit && istype(H.wear_suit, /obj/item/clothing/suit/armor))
					var/obj/item/clothing/suit/armor/armor = H.wear_suit
					if (armor.block_check(src))
						visible_message("<span class='warning'>[H]'s armor deflects the shrapnel!</span>")
						return

		do_bullet_act(target_mob, hit_zone)
		if (blockedhit == FALSE)
			if (silenced)
				target_mob << "<span class='danger'>You've been hit in the [parse_zone(hit_zone)] by the shrapnel!</span>"
			else
				visible_message("<span class='danger'>\The [target_mob] is hit by the shrapnel in the [parse_zone(hit_zone)]!</span>")
		return

	if (!istype(target_mob))
		return

	if (!firedfrom)
		return

	// non-projectile gun types will be removed soon, this code doesn't support them anymore - Kachnov
	if (!istype(firedfrom, /obj/item/weapon/gun/projectile))
		return

	if (!def_zone)
		def_zone = "chest"

	// how many times did we move from our initial def_zone
	var/redirections = 0

	var/obj/item/weapon/gun/projectile/mygun = firedfrom
	if (def_zone in mygun.redirection_chances)
		for (var/nzone in mygun.redirection_chances[def_zone])
			if (prob(mygun.redirection_chances[def_zone][nzone]))
				def_zone = nzone
				++redirections
				break

	var/miss_chance = mygun.calculate_miss_chance(def_zone, target_mob)

	// execution bullets will never miss
	if (execution)
		miss_chance = 0
	else
		// much smaller chance to miss someone you targeted
		if (firer && ishuman(firer) && firer:aiming && firer:aiming.aiming_at == target_mob)
			miss_chance = max(round(miss_chance/mygun.aim_miss_chance_divider), 0)

		// makes hitting people in a "blind spot" easier 50% easier
		if (firer && target_mob.is_in_blindspot(firer))
			miss_chance = max(round(miss_chance * 0.50), 0)

	// get the new zone
	var/hit_zone = mygun.get_zone(def_zone, target_mob, miss_chance)
	if (hit_zone != def_zone)
		++redirections

	// handled below
	var/result = PROJECTILE_FORCE_MISS

	// KD chance handling
	KD_chance = mygun.KD_chance

	// damage handling
	var/extra_damage_change = -(redirections*6)

	// 50-60% chance of less severe damage: either 6, 12, or 18 less damage based on number of redirections
	var/helmet_protection = 0

	var/mob/living/carbon/human/H = target_mob
	if (istype(H) && H.head && istype(H.head, /obj/item/clothing/head/helmet))
		helmet_protection = 15

	// less damage, no headgibs
	if (target_mob.takes_less_damage || (prob((100 - mygun.headshot_kill_chance)+helmet_protection) && target_mob.stat == CONSCIOUS))
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
	damage += extra_damage_change

	if (hit_zone)
//		var/def_zone = hit_zone //set def_zone, so if the projectile ends up hitting someone else later (to be implemented), it is more likely to hit the same part
		result = do_bullet_act(target_mob, hit_zone)

	if (result == PROJECTILE_FORCE_MISS)
		if (!silenced)
			playsound(get_turf(target_mob), "miss_sound", 100, TRUE)
		return FALSE
	else if (target_mob && !useless && !target_mob.takes_less_damage) // if we just grazed, useless is set to TRUE
		if (target_mob.stat == CONSCIOUS && prob(mygun.KO_chance) && damage >= DAMAGE_HIGH-6)
			visible_message("<span class = 'danger'>[target_mob] is knocked out!</span>")
			target_mob.Paralyse(3)

	//hit messages
	if (blockedhit == FALSE)
		if (silenced)
			target_mob << "<span class='danger'>You've been hit in the [parse_zone(hit_zone)] by \the [src]!</span>"
		else
			visible_message("<span class='danger'>\The [target_mob] is hit in the [parse_zone(hit_zone)]!</span>")//X has fired Y is now given by the guns so you cant tell who shot you if you could not see the shooter

	//admin logs
	if (!no_attack_log)
		if (istype(firer, /mob))

			var/attacker_message = "shot with \a [type]"
			var/victim_message = "shot with \a [type]"
			var/admin_message = "shot (\a [type])"

			admin_attack_log(firer, target_mob, attacker_message, victim_message, admin_message)
		else
			target_mob.attack_log += "\[[time_stamp()]\] <b>UNKNOWN SUBJECT (No longer exists)</b> shot <b>[target_mob]/[target_mob.ckey]</b> with <b>\a [src]</b>"
			msg_admin_attack("UNKNOWN shot [target_mob] ([target_mob.ckey]) with \a [src] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[target_mob.x];Y=[target_mob.y];Z=[target_mob.z]'>JMP</a>)")

	//sometimes bullet_act() will want the projectile to continue flying
	if (result == PROJECTILE_CONTINUE)
		return FALSE

	return TRUE

/obj/item/projectile/proc/handleTurf(var/turf/T, forced=0, var/list/untouchable = list())

	if (!T || !istype(T))
		return FALSE

	if ((bumped && !forced) || (permutated.Find(T)))
		return FALSE

	var/passthrough = TRUE //if the projectile should continue flying
	var/passthrough_message = null

	if(can_hit_in_trench == 1)
		if(kill_count < (initial(kill_count) - 1))
			if(!istype(T, /turf/floor/trench))
				can_hit_in_trench = 0
			else
				can_hit_in_trench = -1

	if (T.density || (can_hit_in_trench == -1 && !istype(T, /turf/floor/trench)))
		passthrough = FALSE
	else
		if(!istype(T, /turf/floor/trench) || can_hit_in_trench)
			// needs to be its own loop for reasons
			for (var/obj/O in T.contents)
				if (O == original)
					var/hitchance = 33 // a light, for example. This was 66%, but that was unusually accurate, thanks BYOND
					if (isstructure(O) && !istype(O, /obj/structure/lamp))
						hitchance = 50
					else if (!isitem(O) && isnonstructureobj(O)) // a tank, for example.
						hitchance = 100
					else if (isitem(O)) // any item
						var/obj/item/I = O
						hitchance = 9 * I.w_class // a pistol would be 50%
					if (prob(hitchance))
						do_bullet_act(O)
						bumped = TRUE
						loc = null
						qdel(src)
						return FALSE
					else
						O.visible_message("<span class = 'warning'>\The [src] narrowly misses [O]!</span>")
						if (isitem(O) || (O.density && O.anchored)) // since it was on the ground
							bumped = TRUE
							loc = null
							qdel(src)
							return FALSE
					break
		for (var/atom/movable/AM in T.contents)
			if (!untouchable.Find(AM))
				if (isliving(AM) && AM != firer)
					var/mob/living/L = AM
					if (!L.lying || T == get_turf(original) || execution)
						// if they have a neck grab on someone, that person gets hit instead
						var/obj/item/weapon/grab/G = locate() in L
						if (G && G.state >= GRAB_NECK && G.affecting.stat < UNCONSCIOUS)
							visible_message("<span class='danger'>\The [L] uses [G.affecting] as a shield!</span>")
							//if (Bump(G.affecting, forced=1))
							//	bumped = TRUE // for shrapnel
							//	return FALSE
							G.affecting.pre_bullet_act(src)
							attack_mob(G.affecting)
							if (!G.affecting.lying)
								passthrough = FALSE
						else
							L.pre_bullet_act(src)
							attack_mob(L)
							if (L && !L.lying)
								passthrough = FALSE
				else if (isobj(AM) && AM != firedfrom)
					var/obj/O = AM
					if (O.density || istype(O, /obj/structure/window/classic)) // hack
						O.pre_bullet_act(src)
						if (O.bullet_act(src, def_zone) != PROJECTILE_CONTINUE)
							if (O && !O.gcDestroyed)
								if (O.density && !istype(O, /obj/structure))
									passthrough = FALSE
								else if (istype(O, /obj/structure))
									var/obj/structure/S = O
									if (!S.CanPass(src, original))
										passthrough = FALSE
						//				log_debug("ignored [S] (1)")
									else if (S.density)
										if (!S.climbable)
											passthrough_message = "<span class = 'warning'>The [name] penetrates through \the [S]!</span>"
	//		else
		//		log_debug("ignored [AM] (2)")

	//penetrating projectiles can pass through things that otherwise would not let them
	++penetrating
	if ((T.density && penetrating > 0) && (can_hit_in_trench != -1))
		if (check_penetrate(T))
			passthrough = TRUE
			passthrough_message = "<span class = 'warning'>The bullet penetrates \the [T]!</span>"
		--penetrating

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
/*
/obj/item/projectile/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	return TRUE*/

/obj/item/projectile/process()
	//plot the initial trajectory

	var/firstmove = FALSE

	if (!trajectory)
		setup_trajectory()
		firstmove = TRUE

	if (src && loc)
		if (--kill_count < 1)
			for (var/atom/movable/AM in loc)
				do_bullet_act(AM)
			do_bullet_act(loc)
			on_impact(loc) //for any final impact behaviours
			qdel(src)
			return
		if (firer && map.check_caribbean_block(firer, loc) && !map.allow_bullets_through_blocks.Find(get_area(src):type))
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

		if (firstmove)
			for (var/obj/structure/window/sandbag/S in src_loc)
				_untouchable += S
		else
			if (firer)
				for (var/obj/structure/barricade/B in src_loc)
					if (get_dist(firer, B) == 1)
						_untouchable += B

		handleTurf(loc, untouchable = _untouchable)
		before_move()
		forceMove(location.return_turf())

		if (!did_muzzle_effect)
			muzzle_effect(effect_transform)
		else if (!bumped)
			tracer_effect(effect_transform)

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

/obj/item/projectile/proc/setup_trajectory()
	// trajectory dispersion
	var/offset = 0
	if (dispersion)
		var/radius = round(dispersion*9, TRUE)
		offset = rand(-radius, radius)

	// plot the initial trajectory
	trajectory = new()
	trajectory.setup(starting, original, pixel_x, pixel_y, angle_offset=offset)

	// generate this now since all visual effects the projectile makes can use it
	effect_transform = new()
	effect_transform.Scale(trajectory.return_hypotenuse(), TRUE)
	effect_transform.Turn(-trajectory.return_angle())		//no idea why this has to be inverted, but it works

	transform = turn(transform, -(trajectory.return_angle() + 90)) //no idea why 90 needs to be added, but it works

/obj/item/projectile/proc/muzzle_effect(var/matrix/T)

	if (silenced)
		did_muzzle_effect = TRUE
		return

	if (ispath(muzzle_type))
		var/obj/effect/projectile/M = new muzzle_type(get_turf(src))

		if (istype(M))
			M.set_transform(T)
			M.pixel_x = location.pixel_x
			M.pixel_y = location.pixel_y
			M.activate()

	did_muzzle_effect = TRUE

/obj/item/projectile/proc/tracer_effect(var/matrix/M)
	if (ispath(tracer_type))
		var/obj/effect/projectile/P = new tracer_type(location.loc)

		if (istype(P))
			P.set_transform(M)
			P.pixel_x = location.pixel_x
			P.pixel_y = location.pixel_y
		/*	if (!hitscan)
				P.activate(step_delay)	//if not a hitscan projectile, remove after a single delay
			else*/
			P.activate()

/obj/item/projectile/proc/impact_effect(var/matrix/M)
	if (ispath(tracer_type))
		var/obj/effect/projectile/P = new impact_type(location.loc)

		if (istype(P))
			P.set_transform(M)
			P.pixel_x = location.pixel_x
			P.pixel_y = location.pixel_y
			P.activate()

//Helper proc to check if you can hit them or not.

/proc/check_trajectory(atom/target as mob|obj, atom/firer as mob|obj, var/pass_flags=PASSTABLE|PASSGLASS|PASSGRILLE, flags=null)
	if (!istype(target) || !istype(firer))
		return FALSE

//	var/obj/item/projectile/test/trace = new /obj/item/projectile/test(get_turf(firer)) //Making the test....
	var/obj/item/projectile/bullet/trace = new (get_turf(firer))
	trace.invisibility = 101

	//Set the flags and pass flags to that of the real projectile...
	if (!isnull(flags))
		trace.flags = flags
	trace.pass_flags = pass_flags

	var/output = trace.launch(target) //Test it!
	qdel(trace) //No need for it anymore
	return output //Send it back to the gun!

/obj/item/projectile/bullet
	embed = TRUE