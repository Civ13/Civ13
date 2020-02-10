
/mob/living/simple_animal/hostile/human
	var/corpse = null
	var/ranged = FALSE
	var/rapid = FALSE //If fires faster
	var/casingtype = null
	var/projectiletype = null
	var/projectilesound = null
	var/fire_desc = "fires"
	var/obj/item/weapon/gun/projectile/gun = null

	var/datum/language/language = new/datum/language/english
	var/list/messages = list(
		"backup" = null,
		"injured" = null,
		"enemy_sighted" = null,
		"grenade" = null,
	)

/mob/living/simple_animal/hostile/human/Life()
	if (target_mob)
		if(get_dist(src, target_mob) <= 4)
			walk_to(src,0)
	..()
	do_human_behaviour()

/mob/living/simple_animal/hostile/human/hear_say(var/message, var/verb = "says", var/datum/language/s_language = null, var/alt_name = "",var/italics = FALSE, var/mob/speaker = null, var/sound/speech_sound, var/sound_vol, var/alt_message = null, var/animal = FALSE)
	if (speaker.faction == faction && s_language == language)
		if (findtext(message, "attack!"))
			say("URAAAAAAA!", language)
			var/mob/living/simple_animal/hostile/human/EN = null
			for (var/mob/living/simple_animal/hostile/human/PEN in range(15,src))
				if (PEN.faction != faction)
					EN = PEN
					target_mob = EN
					walk_to(src,EN, TRUE, move_to_delay)
					return
/////////////////////////////////////////////////////////
////////////////////RANGED///////////////////////////////

/mob/living/simple_animal/hostile/human/proc/OpenFire(target_mob)
	var/target = target_mob
	spawn(rand(0,2))
		switch(rapid)
			if(0) //singe-shot
				Shoot(target, src.loc, src)
				if(casingtype)
					new casingtype
			if(1) //semi-auto
				var/shots = rand(1,3)
				var/s_timer = 1
				for(var/i = 1, i<= shots, i++)
					spawn(s_timer)
						Shoot(target, src.loc, src)
						if(casingtype)
							new casingtype(get_turf(src))
					s_timer+=3
			if (2) //automatic
				var/shots = rand(3,5)
				var/s_timer = 1
				for(var/i = 1, i<= shots, i++)
					spawn(s_timer)
						Shoot(target, src.loc, src)
						if(casingtype)
							new casingtype(get_turf(src))
					s_timer+=2
	return

/mob/living/simple_animal/hostile/human/proc/Shoot(var/target, var/start, var/user, var/bullet = 0)
	if(target == start)
		return

	var/obj/item/projectile/A = new projectiletype(get_turf(user))
	playsound(user, projectilesound, 100, 1)
	if(!A)	return
	var/def_zone = pick("chest","head")
	if (prob(8))
		def_zone = pick("l_arm","r_arm","r_leg","l_leg")
	A.launch(target, user, src.gun, def_zone, rand(-1,1), rand(-1,1))


/mob/living/simple_animal/hostile/human/AttackTarget()
	if (!target_mob || !SA_attackable(target_mob))
		LoseTarget()
		return FALSE
	if (!(target_mob in ListTargets(7)))
		LostTarget()
		return FALSE
	if (ranged)
		if (get_dist(src, target_mob) <= 5)
			walk_to(src,0)
			OpenFire(target_mob)
		else
			MoveToTarget()
	else
		if (get_dist(src, target_mob) <= 1)	//Attacking
			AttackingTarget()
			return TRUE

/mob/living/simple_animal/hostile/human/MoveToTarget()
	if (!target_mob || !SA_attackable(target_mob))
		stance = HOSTILE_STANCE_IDLE
	if (target_mob in ListTargets(7))
		stance = HOSTILE_STANCE_ATTACKING
		if(ranged)
			if(get_dist(src, target_mob) <= 5)
				walk_to(src,0)
				OpenFire(target_mob)
			else if (get_dist(src, target_mob) <= 1)
				walk_away(src, target_mob, 5, 2)
				spawn(10)
					walk(src,0)
			else
				if (!istype(loc, /turf/floor/trench))
					walk_to(src, target_mob, TRUE, move_to_delay)
		else
			if (!istype(loc, /turf/floor/trench))
				walk_to(src, target_mob, TRUE, move_to_delay)
	else if (target_mob in ListTargets(10))
		if (!istype(loc, /turf/floor/trench))
			walk_to(src, target_mob, TRUE, move_to_delay)

/////////////////////////////AI STUFF///////////////////////////////////////////////
//Special behaviour for human hostile mobs, taking cover, grenades, etc.
/mob/living/simple_animal/hostile/human/proc/do_human_behaviour()
	if (!target_mob)
		walk_to(src,0)
		return "no target"
	for(var/obj/item/weapon/grenade/G in view(2,src))
		if (G.active)
			walk_away(src, G, 5, 2)
			spawn(20)
				walk(src,0)
			if (messages["grenade"])
				say(messages["grenade"],language)
			return "grenade"
	if (health < maxHealth*0.6)
		if (prob(8))
			if (prob(75))
				new/obj/effect/decal/cleanable/blood/drip(loc)
			else
				new/obj/effect/decal/cleanable/blood(loc)
		if (prob(5) && messages["injured"])
			say(messages["injured"],language)
		if (prob(10))
			if (health < maxHealth*0.2)
				walk_away(src, target_mob, 7, 2)
				spawn(30)
					walk_to(src,0)
				return "retreat"
	if (get_dist(src,target_mob) >= 3 && prob(50))
		var/tdir = 0
		if (target_mob.x >= src.x)
			tdir = EAST
		if (target_mob.x < src.x)
			tdir = WEST
		if (target_mob.y < src.y)
			tdir = SOUTH
		if (target_mob.y >= src.y)
			tdir = NORTH
		var/found_cover = FALSE
		var/turf/GST = get_step(loc, tdir)
		for(var/obj/structure/ST in GST)
			if (ST.density == TRUE || istype(ST, /obj/structure/window/sandbag) && ST.dir == tdir)
				found_cover = TRUE
				break
		if (!found_cover)
			for(var/obj/structure/window/sandbag/SB in view(4,src))
				if (SB.dir == tdir && get_dist(src,SB) < get_dist(src,target_mob))
					walk_to(src, SB, TRUE, move_to_delay)
					spawn(40)
						walk_to(src,0)
					return "find cover"
	if (target_mob in range(7, src))
		var/found_friends = FALSE
		for(var/mob/living/simple_animal/hostile/human/SA in range(11,src))
			if (istype(SA, src.type) && !SA.target_mob && SA.faction == src.faction)
				if (get_dist(src,SA) > 7)
					found_friends = TRUE
					break
		if (found_friends && prob(50))
			call_for_backup(11)

/mob/living/simple_animal/hostile/human/proc/call_for_backup(var/trange=1)
	if (!trange)
		return
	if (prob(30) && messages["backup"])
		say(messages["backup"],language)
	for(var/mob/living/simple_animal/hostile/human/SA in range(trange,src))
		if (istype(SA, src.type) && !SA.target_mob && SA.faction == src.faction)
			walk_to(SA, src, TRUE, move_to_delay)
			SA.target_mob = src.target_mob
			spawn(25)
				walk_to(SA,0)
	return

