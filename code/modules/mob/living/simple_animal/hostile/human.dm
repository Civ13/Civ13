
/mob/living/simple_animal/hostile/human
	var/corpse = null

	var/ranged = FALSE
	var/rapid = FALSE //If fires faster
	var/casingtype = null
	var/projectiletype = null
	var/projectilesound = null
	var/fire_desc = "fires"
	var/obj/item/weapon/gun/projectile/gun = null

	var/role = "soldier" //soldier, medic, officer, recon, guard...
	var/atom/target_obj = null //for some roles (i.e. guard)
	var/action_running = FALSE
	var/target_action = null
	var/datum/language/language = new/datum/language/english

	var/list/messages = list(
		"backup" = list(),
		"injured" = list(),
		"enemy_sighted" = list(),
		"grenade" = list(),
	)

/mob/living/simple_animal/hostile/human/Life()

	..()
	do_human_behaviour()
	if (role == "medic" && !action_running)
		help_patient()

/mob/living/simple_animal/hostile/human/hear_say(var/message, var/verb = "says", var/datum/language/s_language = null, var/alt_name = "",var/italics = FALSE, var/mob/speaker = null, var/sound/speech_sound, var/sound_vol, var/alt_message = null, var/animal = FALSE, var/original_message = "")
	if (stat == DEAD)
		return
	if (istype(speaker, /mob/living/simple_animal/hostile/human) && speaker.faction == src.faction)
		var/mob/living/simple_animal/hostile/human/SMH = speaker
		if (target_action != "helping" && target_action != "bandaging" && target_action != "drag" && target_action != "moving")
			for(var/msg in SMH.messages["injured"])
				msg = replacetext(msg,"!!","")
				if (findtext(message,msg))
					say("!!Coming!", language)
					target_action = "moving"
					target_mob = null
					target_obj = speaker
					walk_towards(src,target_obj,7)
					return
	else if (ishuman(speaker))
		var/mob/living/carbon/human/H = speaker
		message = original_message
		if (H.faction_text == faction && s_language.name == language.name && role == "medic")
			if (findtext(message, "medic!") && target_action != "helping" && target_action != "bandaging" && target_action != "drag" && target_action != "moving")
				if (H.getTotalDmg()>42)
					say("!!Coming!", language)
					target_action = "moving"
					target_mob = null
					target_obj = speaker
					walk_towards(src,target_obj,7)
					return
				else
					say(pick("!!Shut up, you pussy!","!!That's just a scratch...","!!That's nothing, I am busy..."), language)
		if (H.faction_text == faction && s_language.name == language.name && H.original_job && H.original_job.is_officer)
			if (findtext(message, "men, "))
				if (findtext(message, "cover me") || findtext(message, "come here") || findtext(message, "on me"))
					if (prob(20))
						say(pick("!!Sir yes Sir!","!!Roger that!","!!Coming!"), language)
					walk_towards(src,H,7)
					spawn(30)
						walk(src,0)
				else if (findtext(message, "retreat") || findtext(message, "fall back"))
					if (prob(30))
						say(pick("!!Falling back!","!!Retreating!"), language)
					if (target_mob)
						walk_away(src,target_mob,7)
						spawn(40)
							target_mob = null
						spawn(45)
							walk(src,0)
					else
						var/mob/living/EN = null
						for (var/mob/living/carbon/human/PENP in range(10,src))
							if (PENP.faction_text != faction && PENP.stat != DEAD)
								EN = PENP
								break
						for (var/mob/living/simple_animal/hostile/human/PEN in range(10,src))
							if (PEN.faction != faction && PEN.stat != DEAD)
								EN = PEN
								break
						walk_away(src,EN,7)
						spawn(40)
							target_mob = null
						spawn(45)
							walk(src,0)
				else if (findtext(message, "take cover") || findtext(message, "hide"))
					if (prob(35))
						say(pick("!!Taking cover!"), language)
					var/mob/tgt = null //if theres no enemy, take cover somewhere behind the officer
					if (target_mob)
						tgt = target_mob
					else
						tgt = H
					var/tdir = 0
					if (tgt.x >= src.x && abs(tgt.y-src.y)<=abs(tgt.x-src.x))
						tdir = EAST
					if (tgt.x < src.x && abs(tgt.y-src.y)<=abs(tgt.x-src.x))
						tdir = WEST
					if (tgt.y < src.y && abs(tgt.y-src.y)>abs(tgt.x-src.x))
						tdir = SOUTH
					if (tgt.y >= src.y && abs(tgt.y-src.y)>abs(tgt.x-src.x))
						tdir = NORTH
					if (tdir)
						var/found_cover = FALSE
						var/turf/GST = get_step(loc, tdir)
						for(var/obj/structure/ST in GST)
							if (ST.density == TRUE || (istype(ST, /obj/structure/window/sandbag) && ST.dir == tdir))
								found_cover = TRUE
								break
						if (!found_cover)
							for(var/obj/structure/window/sandbag/SB in view(7,src))
								if (!found_cover && SB.dir == tdir && get_dist(src,SB) < get_dist(src,tgt))
									found_cover = TRUE
									walk_to(src, SB, TRUE, move_to_delay)
									spawn(40)
										walk(src,0)
									break
						if (!found_cover)
							for(var/obj/covers/SB in view(7,src))
								if (!found_cover && SB.density)
									if (tdir == NORTH)
										if (SB.y < tgt.y)
											walk_to(src, get_step(SB,OPPOSITE_DIR(tdir)), TRUE, move_to_delay)
											found_cover = TRUE
											spawn(40)
												walk(src,0)
											break
									else if (tdir == SOUTH)
										if (SB.y > tgt.y)
											walk_to(src, get_step(SB,OPPOSITE_DIR(tdir)), TRUE, move_to_delay)
											found_cover = TRUE
											spawn(40)
												walk(src,0)
											break
									else if (tdir == EAST)
										if (SB.x < tgt.x)
											walk_to(src, get_step(SB,OPPOSITE_DIR(tdir)), TRUE, move_to_delay)
											found_cover = TRUE
											spawn(40)
												walk(src,0)
											break
									else if (tdir == WEST)
										if (SB.x > tgt.x)
											walk_to(src, get_step(SB,OPPOSITE_DIR(tdir)), TRUE, move_to_delay)
											found_cover = TRUE
											spawn(40)
												walk(src,0)
											break
						if (!found_cover)
							for(var/obj/structure/SB in view(7,src))
								if (!found_cover && SB.density)
									if (tdir == NORTH)
										if (SB.y < tgt.y)
											walk_to(src, get_step(SB,OPPOSITE_DIR(tdir)), TRUE, move_to_delay)
											found_cover = TRUE
											spawn(40)
												walk(src,0)
											break
									else if (tdir == SOUTH)
										if (SB.y > tgt.y)
											walk_to(src, get_step(SB,OPPOSITE_DIR(tdir)), TRUE, move_to_delay)
											found_cover = TRUE
											spawn(40)
												walk(src,0)
											break
									else if (tdir == EAST)
										if (SB.x < tgt.x)
											walk_to(src, get_step(SB,OPPOSITE_DIR(tdir)), TRUE, move_to_delay)
											found_cover = TRUE
											spawn(40)
												walk(src,0)
											break
									else if (tdir == WEST)
										if (SB.x > tgt.x)
											walk_to(src, get_step(SB,OPPOSITE_DIR(tdir)), TRUE, move_to_delay)
											found_cover = TRUE
											spawn(40)
												walk(src,0)
											break

				else if (findtext(message, "move north") || findtext(message, "move south") || findtext(message, "move east") || findtext(message, "move west"))
					if (prob(20))
						say(pick("!!Sir yes Sir!","!!Roger that!","!!Moving out!"), language)
					if (prob(33))
						playsound(loc, get_sfx("charge_[uppertext(language.name)]"), 100)
					var/turf/t_dir = null
					if (findtext(message, "move north"))
						t_dir = locate(x+rand(-2,2),y+10,z)
						if (!t_dir)
							t_dir = locate(x+rand(-2,2),y+5,z)
					else if (findtext(message, "move south"))
						t_dir = locate(x+rand(-2,2),y-10,z)
						if (!t_dir)
							t_dir = locate(x+rand(-2,2),y-5,z)
					else if (findtext(message, "move east"))
						t_dir = locate(x+10,y+rand(-2,2),z)
						if (!t_dir)
							t_dir = locate(x+5,y+rand(-2,2),z)
					else if (findtext(message, "move west"))
						t_dir = locate(x-10,y+rand(-2,2),z)
						if (!t_dir)
							t_dir = locate(x-5,y+rand(-2,2),z)
					if (target_mob)
						target_mob = null
					walk_towards(src, t_dir, 7)
					/*
					var/mob/living/EN = null
					for (var/mob/living/carbon/human/PENP in range(20,src))
						if (PENP.faction_text != faction && PENP.stat != DEAD)
							EN = PENP
							target_mob = EN
							walk_to(src,EN, TRUE, move_to_delay)
							return
					for (var/mob/living/simple_animal/hostile/human/PEN in range(20,src))
						if (PEN.faction != faction && PEN.stat != DEAD)
							EN = PEN
							target_mob = EN
							walk_to(src,EN, TRUE, move_to_delay)
							return
					*/
/////////////////////////////////////////////////////////
////////////////////RANGED///////////////////////////////

/mob/living/simple_animal/hostile/human/proc/OpenFire(target_mob)
	spawn(rand(0,2))
		switch(rapid)
			if(0) //singe-shot
				Shoot(target_mob, src.loc, src)
				if(casingtype)
					new casingtype
			if(1) //semi-auto
				var/shots = rand(1,3)
				var/s_timer = 1
				for(var/i = 1, i<= shots, i++)
					spawn(s_timer)
						Shoot(target_mob, src.loc, src)
						if(casingtype)
							new casingtype(get_turf(src))
					s_timer+=3
			if (2) //automatic
				var/shots = rand(3,5)
				var/s_timer = 1
				for(var/i = 1, i<= shots, i++)
					spawn(s_timer)
						Shoot(target_mob, src.loc, src)
						if(casingtype)
							new casingtype(get_turf(src))
					s_timer+=2
	return

/mob/living/simple_animal/hostile/human/proc/Shoot(var/target, var/start, var/user, var/bullet = 0)
	if(target == start)
		return

	var/obj/item/projectile/A = new projectiletype(get_turf(user))
	playsound(user, projectilesound, 100, TRUE)
	if(!A)	return
	var/def_zone = pick("chest","head")
	if (prob(8))
		def_zone = pick("l_arm","r_arm","r_leg","l_leg")
	A.launch(target, user, src.gun, def_zone, rand(-1,1), rand(-1,1))
	set_light(3)
	spawn(5)
		set_light(0)


/mob/living/simple_animal/hostile/human/AttackTarget()
	if (!target_mob || !SA_attackable(target_mob))
		LoseTarget()
		return FALSE
	if (!(target_mob in ListTargets(11)))
		spawn(50)
		if (!(target_mob in ListTargets(11)))
			LostTarget()
			return FALSE
	if (ranged)
		if (get_dist(src, target_mob) <= 5)
			walk(src,0)
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
				walk(src,0)
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
		return "no target"
	for(var/obj/item/weapon/grenade/G in view(2,src))
		if (G.active)
			walk_away(src, G, 5, 2)
			spawn(20)
				walk(src,0)
			if (!isemptylist(messages["grenade"]))
				say(pick(messages["grenade"]),language)
			return "grenade"
	if (health < maxHealth*0.6)
		if (prob(8))
			if (prob(75))
				new/obj/effect/decal/cleanable/blood/drip(loc)
			else
				new/obj/effect/decal/cleanable/blood(loc)
		if (prob(5) && !isemptylist(messages["injured"]))
			say(pick(messages["injured"]),language)
/*
	if (get_dist(src,target_mob) >= 3 && prob(50))
		var/tdir = 0
		if (target_mob.x >= src.x && abs(target_mob.y-src.y)<=abs(target_mob.x-src.x))
			tdir = EAST
		if (target_mob.x < src.x && abs(target_mob.y-src.y)<=abs(target_mob.x-src.x))
			tdir = WEST
		if (target_mob.y < src.y && abs(target_mob.y-src.y)>abs(target_mob.x-src.x))
			tdir = SOUTH
		if (target_mob.y >= src.y && abs(target_mob.y-src.y)>abs(target_mob.x-src.x))
			tdir = NORTH
		if (tdir)
			var/found_cover = FALSE
			var/turf/GST = get_step(loc, tdir)
			for(var/obj/structure/ST in GST)
				if (ST.density == TRUE || (istype(ST, /obj/structure/window/sandbag) && ST.dir == tdir))
					found_cover = TRUE
					break
			if (!found_cover)
				for(var/obj/structure/window/sandbag/SB in view(4,src))
					if (SB.dir == tdir && get_dist(src,SB) < get_dist(src,target_mob))
						walk_to(src, SB, TRUE, move_to_delay)
						spawn(40)
							walk(src,0)
						return "find cover"
*/
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
	if (prob(20) && !isemptylist(messages["backup"]))
		say(pick(messages["backup"]),language)
	for(var/mob/living/simple_animal/hostile/human/SA in range(trange,src))
		if (istype(SA, src.type) && !SA.target_mob && SA.faction == src.faction)
			walk_to(SA, src, TRUE, move_to_delay)
			SA.target_mob = src.target_mob
			spawn(45)
				walk_to(SA,0)
	return

/mob/living/simple_animal/hostile/human/proc/help_patient()
	if (!action_running)
		action_running = TRUE
	else
		return
	if (!target_obj || target_action == "none")
		action_running = FALSE
		return
	var/mob/living/L = null
	if (isliving(target_obj))
		L = target_obj
	else
		action_running = FALSE
		return
	stop_automated_movement = TRUE
	if (get_dist(target_obj,src)>1 && target_action != "helping")
		walk_towards(src,target_obj,7)
	else if (get_dist(target_obj,src)<=1 && target_action != "helping")
		walk(src,0)
		target_action = "helping"

	var/enemy_detected = FALSE
	for(var/mob/living/simple_animal/hostile/human/SA in view(7,src))
		if (SA.stat != DEAD && SA.faction != src.faction)
			target_action = "drag"
			enemy_detected = TRUE
			drag_patient(SA)
			action_running = FALSE
			return

	if (!enemy_detected && target_action=="drag")
		walk(src,0)
		target_action = "helping"

	if (!enemy_detected && target_action=="helping")
		target_action = "bandaging"
		if (ishuman(target_mob))
			var/mob/living/carbon/human/H = target_mob
			if (H.getTotalDmg()>95)
				say(pick("!!Hang on buddy, you will be fine!","!!You'll be fine kid, don't worry."), language)
		visible_message("<span class='notice'>[src] starts bandaging [target_obj]...</span>")
		playsound(loc, 'sound/items/poster_ripped.ogg', 100, TRUE)
		walk(src,0)
		spawn(70)
			if (target_obj && src && get_dist(src,target_obj)<=1 && src.stat != DEAD && L.stat != DEAD)
				visible_message("[target_obj] is all bandaged.")
				if (ishuman(target_obj))
					var/mob/living/carbon/human/H = target_obj
					for (var/obj/item/organ/external/affecting in H.organs)

						if (affecting && affecting.open == FALSE)
							if (!affecting.is_bandaged())
								for (var/datum/wound/W in affecting.wounds)
									if (W.internal)
										continue
									if (W.bandaged)
										continue
									W.bandage()
						affecting.update_damages()
					H.update_bandaging(0)
					target_mob = null
					target_action = "none"
					stop_automated_movement = FALSE
					action_running = FALSE
					return
				else if (isliving(target_obj))
					var/mob/living/simple_animal/hostile/human/HMB = target_obj
					HMB.adjustBruteLoss(-((HMB.maxHealth-HMB.health)*0.5))
					target_mob = null
					target_action = "none"
					stop_automated_movement = FALSE
					action_running = FALSE
					return
		spawn(150)
			if (target_action == "bandaging")
				target_action = "none"
				action_running = FALSE
	action_running = FALSE

/mob/living/simple_animal/hostile/human/proc/drag_patient(var/mob/living/MB)
	if (MB.stat != DEAD && MB.faction != src.faction)
		var/tdir = OPPOSITE_DIR(get_dir(src,MB))
		MB.forceMove(loc)
		walk_to(src,get_step(src,tdir),10)
		visible_message("<span class='warning'>[src] drags [MB]!</span>")