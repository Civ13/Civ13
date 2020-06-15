
/mob/living/simple_animal/hostile/human
	var/corpse = null
	var/idle_counter = 0

	var/ranged = FALSE
	var/rapid = FALSE //If fires faster
	var/casingtype = null
	var/projectiletype = null
	var/fire_desc = "fires"
	var/obj/item/weapon/gun/projectile/gun = null
	var/grenades = 0 //number of grenades
	var/grenade_type = /obj/item/weapon/grenade

	var/role = "soldier" //soldier, medic, officer, recon, guard...
	var/list/found_path = list()
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
	do_behaviour()
/mob/living/simple_animal/hostile/human/hear_say(var/message, var/verb = "says", var/datum/language/s_language = null, var/alt_name = "",var/italics = FALSE, var/mob/speaker = null, var/sound/speech_sound, var/sound_vol, var/alt_message = null, var/animal = FALSE, var/original_message = "")
	if (stat == DEAD)
		return

	if (istype(speaker, /mob/living/simple_animal/hostile/human) && speaker.faction == src.faction && role == "medic")
		var/mob/living/simple_animal/hostile/human/SMH = speaker
		if (target_action != "helping" && target_action != "bandaging" && target_action != "drag" && target_action != "moving")
			for(var/msg in SMH.messages["injured"])
				msg = replacetext(msg,"!!","")
				if (findtext(message,msg))
					say("!!Coming!", language)
					target_action = "moving"
					target_mob = null
					target_obj = speaker
					do_movement(target_obj)
					return
	else if (ishuman(speaker))
		var/mob/living/human/H = speaker
		message = original_message
		if (H.faction_text == faction && s_language.name == language.name && role == "medic")
			if (findtext(message, "medic!") && target_action != "helping" && target_action != "bandaging" && target_action != "drag" && target_action != "moving")
				if (H.getTotalDmg()>30)
					say("!!Coming!", language)
					target_action = "moving"
					target_mob = null
					target_obj = speaker
					do_movement(target_obj)
					return
				else
					say(pick("!!Shut up, you pussy!","!!That's just a scratch...","!!That's nothing, I am busy..."), language)
		if (H.faction_text == faction && s_language.name == language.name && H.original_job && H.original_job.is_officer)
			if (findtext(message, "men, "))
				if (findtext(message, "charge") || findtext(message, "attack") || findtext(message, "advance"))
					charge(H.get_objective())

				else if (findtext(message, "cover me") || findtext(message, "come here"))
					if (prob(20))
						say(pick("!!Sir yes Sir!","!!Roger that!","!!Coming!"), language)
					do_movement(H)
					spawn(30)
						do_movement(loc)
						walk(src,0)

				else if (findtext(message, "follow me") || findtext(message, "on me"))
					if (prob(20))
						say(pick("!!Sir yes Sir!","!!Roger that!","!!Following!"), language)
					do_movement(H)

				else if (findtext(message, "stop") || findtext(message, "hold"))
					if (prob(20))
						say(pick("!!Sir yes Sir!","!!Roger that!","!!Stopping, Sir!"), language)
					walk(src,0)
					do_movement(loc)

				else if (findtext(message, "retreat") || findtext(message, "fall back"))
					if (prob(30))
						say(pick("!!Falling back!","!!Retreating!"), language)
					retreat()

				else if (findtext(message, "take cover") || findtext(message, "hide"))
					if (prob(35))
						say(pick("!!Taking cover!"), language)
					take_cover(H)


				else if (findtext(message, "move north") || findtext(message, "move south") || findtext(message, "move east") || findtext(message, "move west"))
					if (prob(20))
						say(pick("!!Sir yes Sir!","!!Roger that!","!!Moving out!"), language)
//					if (prob(33))
//						playsound(loc, get_sfx("charge_[uppertext(language.name)]"), 100)
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
					do_movement(t_dir)

/////////////////////////////////////////////////////////
////////////////////RANGED///////////////////////////////

/mob/living/simple_animal/hostile/human/proc/OpenFire(target_mob)
	if (grenades && prob(5) && target_mob in view(7,src))
		var/do_it = FALSE
		for(var/mob/living/L in range(3,target_mob))
			if (L.faction == src.faction)
				break
			else if (ishuman(L))
				var/mob/living/human/H = L
				if (H.faction_text == faction)
					break
				else
					do_it++
			else
				do_it++
		if (do_it>=3 && grenades)
			grenades--
			var/obj/item/weapon/grenade/GN = new grenade_type(loc)
			throw_item(GN,target_mob)
			GN.active = TRUE
			spawn(GN.det_time)
				GN.prime()
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
	if(target == start || !gun)
		return

	var/obj/item/projectile/A = new projectiletype(get_turf(user))
	playsound(user, gun.fire_sound, 100, TRUE)
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
			do_movement(loc)
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
		wander = TRUE
	if (target_mob in ListTargets(8))
		stance = HOSTILE_STANCE_ATTACK
		wander = FALSE
		if(ranged)
			if(get_dist(src, target_mob) <= 6)
				walk(src,0)
				OpenFire(target_mob)
			else if (get_dist(src, target_mob) <= 1)
				walk_away(src, target_mob, 5, 7)
				spawn(10)
					walk(src,0)
					do_movement(loc)
			else
				if (!istype(loc, /turf/floor/trench))
					do_movement(target_mob)
		else
			if (!istype(loc, /turf/floor/trench))
				do_movement(target_mob)
	else if (target_mob in ListTargets(12))
		wander = FALSE
		if (!istype(loc, /turf/floor/trench))
			do_movement(target_mob)

/////////////////////////////AI STUFF///////////////////////////////////////////////
//Special behaviour for human hostile mobs, taking cover, grenades, etc.
/mob/living/simple_animal/hostile/human/proc/do_human_behaviour()
	if (!target_mob)
		wander = TRUE
		if (role == "officer")
			idle_counter++
			if (idle_counter >= 120)
				for(var/mob/living/simple_animal/hostile/human/H in range(3,src))
					if (H.faction == src.faction)
						H.charge(get_objective())
				idle_counter = 0
		return "no target"
	else
		idle_counter = 0
		wander = FALSE
	if (prob(33))
		var/enemy_found = 0
		for(var/mob/living/simple_animal/hostile/human/HH in range(3,target_mob))
			if (HH.faction != faction && HH.stat != DEAD)
				enemy_found++
		if (enemy_found >= 3)
			take_cover(target_mob)
	for(var/obj/item/weapon/grenade/G in view(2,src))
		if (G.active)
			walk_away(src, G, 5, 7)
			spawn(20)
				walk(src,0)
				do_movement(loc)
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
			SA.do_movement(src)
			SA.target_mob = src.target_mob
			spawn(45)
				walk(SA,0)
				do_movement(loc)
	return

/mob/living/simple_animal/hostile/human/proc/help_patient()
	if (action_running)
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
		do_movement(target_obj)
		return
	else if (get_dist(target_obj,src)<=1 && target_action != "helping")
		walk(src,0)
		do_movement(loc)
		target_action = "helping"

	var/enemy_detected = FALSE
/*
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
*/
	if (!enemy_detected && !action_running && target_action=="helping")
		target_action = "bandaging"
		action_running = TRUE
		if (ishuman(target_mob))
			var/mob/living/human/H = target_mob
			if (H.getTotalDmg()>95)
				say(pick("!!Hang on buddy, you will be fine!","!!You'll be fine kid, don't worry."), language)
		visible_message("<span class='notice'>[src] starts bandaging [target_obj]...</span>")
		playsound(loc, 'sound/items/poster_ripped.ogg', 100, TRUE)
		walk(src,0)
		do_movement(loc)
		spawn(70)
			if (target_obj && src && get_dist(src,target_obj)<=1 && src.stat != DEAD && L.stat != DEAD)
				visible_message("[target_obj] is all bandaged.")
				if (ishuman(target_obj))
					var/mob/living/human/H = target_obj
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


/mob/living/simple_animal/hostile/human/proc/drag_patient(var/mob/living/MB)
	if (MB.stat != DEAD && MB.faction != src.faction)
		var/tdir = OPPOSITE_DIR(get_dir(src,MB))
		MB.forceMove(loc)
		walk_to(src,get_step(src,tdir),10)
		visible_message("<span class='warning'>[src] drags [MB]!</span>")



/mob/living/simple_animal/hostile/human/do_behaviour(var/t_behaviour = null)
	if (stat == DEAD || stat == UNCONSCIOUS)
		return FALSE
	if (!t_behaviour)
		t_behaviour = behaviour

	a_intent = I_HARM

	if (isturf(loc) && !resting && !buckled && canmove)		//This is so it only moves if it's not inside a closet, gentics machine, etc.
		turns_since_move++
		if (turns_since_move >= move_to_delay && stance==HOSTILE_STANCE_IDLE)
			var/moving_to = FALSE // otherwise it always picks 4, fuck if I know.   Did I mention fuck BYOND
			moving_to = pick(cardinal)
			var/turf/move_to_turf = get_step(src,moving_to)
			if (!(istype(loc, /turf/floor/trench) && !istype(move_to_turf, /turf/floor/trench)))
				set_dir(moving_to)			//How about we turn them the direction they are moving, yay.
				Move(move_to_turf)
			turns_since_move = FALSE
	switch(stance)
		if (HOSTILE_STANCE_IDLE)
			if (!target_mob || !(target_mob in ListTargets(10)) || target_mob.stat != CONSCIOUS)
				target_mob = FindTarget()
				if (target_mob)
					stance = HOSTILE_STANCE_ATTACK

		if (HOSTILE_STANCE_TIRED,HOSTILE_STANCE_ALERT)
			if (target_mob && target_mob in ListTargets(10))
				if ((SA_attackable(target_mob)))
					set_dir(get_dir(src,target_mob))	//Keep staring at the mob
					stance = HOSTILE_STANCE_ATTACK
				else
					target_mob = FindTarget()
			else
				target_mob = FindTarget()

		if (HOSTILE_STANCE_ATTACK)
			if (destroy_surroundings)
				DestroySurroundings()
			AttackTarget()
	return t_behaviour

/mob/living/simple_animal/hostile/human/throw_item(var/obj/item/item,var/atom/target)
	if (!item || !target)
		return

	playsound(src, 'sound/effects/throw.ogg', 50, TRUE)
	visible_message("<span class = 'warning'>[src] throws \the [item]!</span>")

	item.throw_at(target, 7, item.throw_speed, src)

/mob/living/simple_animal/hostile/human/proc/retreat()
	if (target_mob)
		walk_away(src,target_mob.loc,10,5)
		target_mob = null
		spawn(80)
			walk(src,0)
			do_movement(loc)
	else
		var/mob/living/EN = null
		for (var/mob/living/human/PENP in range(10,src))
			if (PENP.faction_text != faction && PENP.stat != DEAD)
				EN = PENP
				break
		for (var/mob/living/simple_animal/hostile/human/PEN in range(10,src))
			if (PEN.faction != faction && PEN.stat != DEAD)
				EN = PEN
				break
		walk_away(src,EN,10,5)
		spawn(40)
			target_mob = null
		spawn(45)
			walk(src,0)
			do_movement(loc)

/mob/living/simple_animal/hostile/human/proc/take_cover(var/mob/living/H)
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
			if (ST.density == TRUE || (istype(ST, /obj/structure/window/barrier) && ST.dir == tdir))
				found_cover = TRUE
				break
		if (!found_cover)
			for(var/obj/structure/window/barrier/SB in view(7,src))
				if (!found_cover && SB.dir == tdir && get_dist(src,SB) < get_dist(src,tgt))
					found_cover = TRUE
					do_movement(SB)
					spawn(40)
						walk(src,0)
						do_movement(loc)
					break
		if (!found_cover)
			for(var/obj/covers/SB in view(7,src))
				if (!found_cover && SB.density)
					if (tdir == NORTH)
						if (SB.y < tgt.y)
							do_movement(get_step(SB,OPPOSITE_DIR(tdir)))
							found_cover = TRUE
							spawn(40)
								walk(src,0)
								do_movement(loc)
							break
					else if (tdir == SOUTH)
						if (SB.y > tgt.y)
							do_movement(get_step(SB,OPPOSITE_DIR(tdir)))
							found_cover = TRUE
							spawn(40)
								walk(src,0)
								do_movement(loc)
							break
					else if (tdir == EAST)
						if (SB.x < tgt.x)
							do_movement(get_step(SB,OPPOSITE_DIR(tdir)))
							found_cover = TRUE
							spawn(40)
								walk(src,0)
								do_movement(loc)
							break
					else if (tdir == WEST)
						if (SB.x > tgt.x)
							do_movement(get_step(SB,OPPOSITE_DIR(tdir)))
							found_cover = TRUE
							spawn(40)
								walk(src,0)
								do_movement(loc)
							break
		if (!found_cover)
			for(var/obj/structure/SB in view(7,src))
				if (!found_cover && SB.density)
					if (tdir == NORTH)
						if (SB.y < tgt.y)
							do_movement(get_step(SB,OPPOSITE_DIR(tdir)))
							found_cover = TRUE
							spawn(40)
								walk(src,0)
								do_movement(loc)
							break
					else if (tdir == SOUTH)
						if (SB.y > tgt.y)
							do_movement(get_step(SB,OPPOSITE_DIR(tdir)))
							found_cover = TRUE
							spawn(40)
								walk(src,0)
								do_movement(loc)
							break
					else if (tdir == EAST)
						if (SB.x < tgt.x)
							do_movement(get_step(SB,OPPOSITE_DIR(tdir)))
							found_cover = TRUE
							spawn(40)
								walk(src,0)
								do_movement(loc)
							break
					else if (tdir == WEST)
						if (SB.x > tgt.x)
							do_movement(get_step(SB,OPPOSITE_DIR(tdir)))
							found_cover = TRUE
							spawn(40)
								walk(src,0)
								do_movement(loc)
							break

/mob/living/simple_animal/hostile/human/proc/charge(var/atom/objective = null)
	if (!objective)
		objective = get_objective()
	if (!objective)
		return
	var/turf/t_turf = get_turf(objective)
	var/t_distance = 1000
	if (t_turf)
		do_movement(t_turf)
		if (prob(20))
			say(pick("!!URAAAAA!","!!Charge!","!!Moving out!"), language)
		if (prob(60))
			playsound(loc, get_sfx("charge_[uppertext(language.name)]"), 100)
	else
		//none found - just move to the nearest one
		for(var/list/LT in faction_targets)
			if (LT[2] == src.faction)
				var/turf/t_turf2 = locate(LT[3],LT[4],LT[5])
				if (get_dist(src,t_turf2)<t_distance)
					t_turf = t_turf2
					t_distance = get_dist(src,t_turf2)
		if (t_turf && t_distance<1000)
			do_movement(t_turf)
			if (prob(20))
				say(pick("!!URAAAAA!","!!Charge!","!!Moving out!"), language)
			if (prob(60))
				playsound(loc, get_sfx("charge_[uppertext(language.name)]"), 100)
	return

/mob/living/proc/get_objective()
	return

/mob/living/simple_animal/hostile/human/get_objective()
	var/turf/t_turf = null
	var/t_distance = 1000
	//check all the targets and choose the closest one that has enemies nearby.
	for(var/list/LT in faction_targets)
		if (LT[2] == src.faction)
			var/turf/t_turf2 = locate(LT[3],LT[4],LT[5])
			for(var/mob/living/simple_animal/hostile/human/HH in range(7,t_turf2))
				if (HH.faction != src.faction && HH.stat != DEAD && get_dist(src,t_turf2)<t_distance)
					t_turf = t_turf2
					t_distance = get_dist(src,t_turf2)
					break
			for(var/mob/living/human/HH in range(7,t_turf2))
				if (HH.faction_text != src.faction && HH.stat != DEAD && get_dist(src,t_turf2)<t_distance)
					t_turf = t_turf2
					t_distance = get_dist(src,t_turf2)
					break
	return t_turf

/mob/living/human/get_objective()
	var/turf/t_turf = null
	var/t_distance = 1000
	//check all the targets and choose the closest one that has enemies nearby.
	for(var/list/LT in faction_targets)
		if (LT[2] == src.faction_text)
			var/turf/t_turf2 = locate(LT[3],LT[4],LT[5])
			for(var/mob/living/simple_animal/hostile/human/HH in range(7,t_turf2))
				if (HH.faction != src.faction_text && HH.stat != DEAD && get_dist(src,t_turf2)<t_distance)
					t_turf = t_turf2
					t_distance = get_dist(src,t_turf2)
					break
			for(var/mob/living/human/HH in range(7,t_turf2))
				if (HH.faction_text != src.faction_text && HH.stat != DEAD && get_dist(src,t_turf2)<t_distance)
					t_turf = t_turf2
					t_distance = get_dist(src,t_turf2)
					break
	return t_turf