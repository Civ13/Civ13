var/global/list/npc_appearance_cache = list()

/mob/living/simple_animal/hostile/human
	attack_verb = "hits"
	speed = 4
	move_to_delay = 3
	icon = 'icons/mob/npcs.dmi'
	icon_state = "pirate_friendly1"
	icon_dead = "pirate_friendly_dead"
	gender = MALE

	idle_vision_range = 14
	aggro_vision_range = 14

	var/corpse = null
	var/use_generated_appearance = FALSE
	var/corpse_job = ""
	var/corpse_s_tone = 0
	var/weapon = null
	var/idle_counter = 0

	var/ranged = FALSE
	var/rapid = FALSE //If fires faster
	var/firedelay = 5
	var/last_fire = 0
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
	behaviour = "hostile"
	var/fire_cannons = TRUE
	var/base_icon = "male_template"
	var/list/messages = list(
		"backup" = list(),
		"injured" = list(),
		"enemy_sighted" = list(),
		"grenade" = list(),
		"flanking" = list(),
		"suppressing" = list(),
		"reloading" = list(),
		"medic_drag" = list(),
	)

	var/turf/cover_turf = null
	var/peeking = FALSE
	var/suppressing = FALSE
	var/last_retreat = 0
	var/moving = FALSE
	var/last_pathfound = 0
/mob/living/simple_animal/hostile/human/New()
	..()
	if (use_generated_appearance)
		invisibility = 101
		spawn(5)
			initialize_npc_appearance()

/mob/living/simple_animal/hostile/human/proc/initialize_npc_appearance()
	var/job_to_use = corpse_job
	var/s_tone_to_use = corpse_s_tone

	if (job_to_use == "" && ispath(corpse, /mob/living/human/corpse))
		var/mob/living/human/corpse/cp = corpse
		job_to_use = initial(cp.corpse_job)
		s_tone_to_use = initial(cp.corpse_s_tone)
		if (s_tone_to_use == 0)
			var/s_min = initial(cp.s_tone_min)
			var/s_max = initial(cp.s_tone_max)
			if (s_min != 0 || s_max != 0)
				s_tone_to_use = rand(s_min, s_max)

	if (job_to_use == "")
		return

	var/cache_key = "[job_to_use]-[s_tone_to_use]-[gender]"
	if (npc_appearance_cache[cache_key])
		var/list/cached = npc_appearance_cache[cache_key]
		src.appearance = cached["appearance"]
		invisibility = 0
		icon_dead = cached["icon_dead"]
		return

	var/mob/living/human/dummy = new(null)
	dummy.gender = gender
	dummy.s_tone = s_tone_to_use
	dummy.invisibility = 101
	dummy.icon_state = "blank"
	dummy.layer = 4

	if (job_master)
		job_master.EquipRank(dummy, job_to_use)
		for (var/obj/item/weapon/gun/G in dummy.contents)
			if (G.loc == dummy)
				dummy.drop_from_inventory(G)
				dummy.equip_to_slot_or_del(G, slot_l_hand)
				break

	spawn(15)
		if (!dummy) return
		dummy.regenerate_icons()

		src.appearance = dummy.appearance
		invisibility = 0
		icon_state = ""

		var/icon/flat = getFlatIcon(src)
		var/icon/dead = new(flat)
		dead.BecomeLying()

		npc_appearance_cache[cache_key] = list("appearance" = dummy.appearance, "icon_dead" = dead)

		icon_dead = dead

		qdel(dummy)

/mob/living/simple_animal/hostile/human/death()
	moving = FALSE
	found_path = list()
	..()
	if(corpse)
		new corpse (src.loc)
	else
		if (istype(icon_dead, /icon))
			icon = icon_dead
			icon_state = ""
		else
			icon_state = icon_dead
	if(weapon)
		new weapon (src.loc)
	if(gun)
		gun.forceMove(src.loc)
	if (corpse)
		qdel(src)
	return

/mob/living/simple_animal/hostile/human/FindTarget()
	var/atom/T = null
	var/list/potential_targets = ListTargets(aggro_vision_range)
	var/best_score = -9999
	
	for(var/atom/A in potential_targets)
		if(A == src || !SA_attackable(A)) continue
		
		var/score = 100
		var/dist = get_dist(src, A)
		score -= dist * 5 // Less penalty for distance than default to allow for more strategic picking
		
		if(isliving(A))
			var/mob/living/L = A
			
			// Faction check
			if(ishuman(L))
				var/mob/living/human/RH = L
				if(RH.faction_text == faction || (RH in friends))
					continue
			else if(L.faction == faction || (L in friends))
				continue

			// Health factor: prioritize targets that are easier to finish off
			score += ((L.maxHealth - L.health) / L.maxHealth) * 30
			
			// Threat factor: prioritize targets that can fight back
			if(ishuman(L))
				var/mob/living/human/H = L
				var/obj/item/held = H.get_active_hand()
				if(held)
					if(istype(held, /obj/item/weapon/gun))
						score += 60
					else if(istype(held, /obj/item/weapon/melee))
						score += 30
			else if(istype(L, /mob/living/simple_animal/hostile))
				score += 20
				
		if(score > best_score)
			best_score = score
			T = A
			
	if (T && messages["enemy_sighted"] && prob(15))
		say(messages["enemy_sighted"], language)

	return T
/mob/living/simple_animal/hostile/human/Life()
	..()
	do_human_behaviour()
	if (role == "medic" && !action_running)
		help_patient()
	do_behaviour()
/mob/living/simple_animal/hostile/human/hear_say(var/message, var/verb = "says", var/datum/language/s_language = null, var/alt_name = "",var/italics = FALSE, var/mob/speaker = null, var/sound/speech_sound, var/sound_vol, var/alt_message = null, var/animal = FALSE, var/original_message = "")
	if (stat == DEAD)
		return
	if(!isliving(speaker))
		return
	if (role == "medic")
		if (istype(speaker, /mob/living/simple_animal/hostile/human) && speaker.faction == src.faction)
			var/mob/living/simple_animal/hostile/human/SMH = speaker
			if (target_action != "helping" && target_action != "bandaging" && target_action != "drag" && target_action != "moving")
				for(var/msg in SMH.messages["injured"])
					msg = replacetext(msg,"!!","")
					if (findtext(message,msg))
						say("!! Coming!", language)
						target_action = "moving"
						target_mob = null
						target_obj = speaker
						do_movement(target_obj)
						return
		else if (ishuman(speaker))
			var/mob/living/human/H = speaker
			message = original_message
			if (H.faction_text == faction && s_language.name == language.name)
				if (findtext(message, "medic!") && target_action != "helping" && target_action != "bandaging" && target_action != "drag" && target_action != "moving")
					if (H.getTotalDmg()>30)
						say("!! Coming!", language)
						target_action = "moving"
						target_mob = null
						target_obj = speaker
						do_movement(target_obj)
						return
					else
						say(pick("!!Shut up, you pussy!","!!That's just a scratch...","!!That's nothing, I am busy..."), language)
	var/found_officer = FALSE
	if (istype(speaker, /mob/living/simple_animal/hostile/human) && speaker.faction == src.faction)
		var/mob/living/simple_animal/hostile/human/SMH = speaker
		if(SMH.role == "officer")
			found_officer = TRUE
	else if (ishuman(speaker))
		var/mob/living/human/H = speaker
		if(H && H.original_job && (H.original_job.is_officer || H.original_job.is_squad_leader || H.original_job.is_commander) && H.faction_text == src.faction)
			found_officer = TRUE
	if(found_officer)
		if (s_language && language && s_language.name == language.name)
			if (findtext(message, "men, "))
				if (findtext(message, "charge") || findtext(message, "attack") || findtext(message, "advance"))
					var/mob/living/lspeaker = speaker
					charge(lspeaker.get_objective())

				else if (findtext(message, "cover me") || findtext(message, "come here"))
					following_mob = null
					if (prob(20))
						say(pick("!! Sir yes Sir!","!! Roger that!","!! Coming!"), language)
					do_movement(speaker)
					spawn(30)
						do_movement(loc)
						walk(src,0)

				else if (findtext(message, "follow me") || findtext(message, "on me"))
					if (prob(20))
						say(pick("!! Sir yes Sir!","!! Roger that!","!! Following!"), language)
					do_movement(speaker)
					following_mob = speaker

				else if (findtext(message, "stop") || findtext(message, "hold"))
					if (prob(20))
						say(pick("!! Sir yes Sir!","!! Roger that!","!! Stopping, Sir!"), language)
					walk(src,0)
					do_movement(loc)
					following_mob = null

				else if (findtext(message, "retreat") || findtext(message, "fall back"))
					if (prob(30))
						say(pick("!!Falling back!","!!Retreating!"), language)
					following_mob = null
					retreat()

				else if (findtext(message, "take cover") || findtext(message, "hide"))
					if (prob(35))
						say(pick("!!Taking cover!"), language)
					following_mob = null
					take_cover(speaker)

				else if (findtext(message, "cease fire") || findtext(message, "stop firing") || findtext(message, "stop shooting"))
					if (prob(35))
						say(pick("!!Ceasing Fire!"), language)
					else
						say(pick("!!Aye! Ceasing Fire!"), language)
					fire_cannons = FALSE

				else if (findtext(message, "fire") || findtext(message, "shoot"))
					if (prob(35))
						say(pick("!!Firing!"), language)
					else
						say(pick("!!Aye!"), language)
					fire_cannons = TRUE
				else if (findtext(message, "move north") || findtext(message, "move south") || findtext(message, "move east") || findtext(message, "move west"))
					following_mob = null
					if (prob(20))
						say(pick("!! Sir yes Sir!","!! Roger that!","!! Moving out!"), language)
					if (prob(15))
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
					do_movement(t_dir)

/////////////////////////////////////////////////////////
////////////////////RANGED///////////////////////////////

/mob/living/simple_animal/hostile/human/proc/OpenFire(target, var/suppress = FALSE)
	var/atom/final_target = target
	if (suppress && !final_target) return
	
	if (grenades && prob(5) && (target_mob in view(7,src)) && !suppress)
		var/enemies_in_sight = 0
		for(var/mob/living/L in range(3,target_mob))
			if (L.faction == src.faction)
				break
			else if (ishuman(L))
				var/mob/living/human/H = L
				if (H.faction_text == faction)
					break
				else
					enemies_in_sight++
			else
				enemies_in_sight++
		if (enemies_in_sight >= 3 && grenades)
			grenades--
			var/obj/item/weapon/grenade/GN = new grenade_type(loc)
			GN.activate(src)
			throw_item(GN,target_mob)
	
	spawn(1)
		if (world.time>last_fire+firedelay)
			last_fire = world.time
			var/shots_to_fire = 1
			var/burst_delay = 2
			switch(rapid)
				if (1) // semi-auto
					shots_to_fire = rand(1,3)
					burst_delay = 3
				if (2) // automatic
					shots_to_fire = rand(3,5)
					burst_delay = 2
			
			if(suppress)
				shots_to_fire += 2
				burst_delay = 1 // Spray and pray
				
			for(var/i = 1, i <= shots_to_fire, i++)
				spawn((i-1) * burst_delay)
					if(src && final_target)
						Shoot(final_target)
						if(casingtype)
							new casingtype(get_turf(src))

/mob/living/simple_animal/hostile/human/proc/Shoot(var/target)
	if(!gun) return
	var/obj/item/projectile/projectile = new projectiletype(get_turf(src))
	if(!projectile) return
	playsound(src, gun.fire_sound, 100, TRUE)

	var/target_zone = "chest"
	if (prob(20))
		target_zone = "head"
	else if (prob(15))
		target_zone = pick("l_arm","r_arm","r_leg","l_leg")
	
	// If suppressing a turf, add some randomness
	if(!isliving(target))
		target_zone = null
		
	gun.process_projectile(projectile, src, target, target_zone)
	set_light(3)
	spawn(5)
		set_light(0)


/mob/living/simple_animal/hostile/human/AttackTarget()
	if (!target_mob || !SA_attackable(target_mob))
		LoseTarget()
		return "lost"
	
	var/has_los = (target_mob in view(14, src))
	
	if (ranged)
		var/dist = get_dist(src, target_mob)
		if (dist <= 1)
			AttackingTarget()
			return "melee"
		else if (dist <= 12)
			if(has_los)
				if(check_friendly_fire(target_mob))
					// Line of fire blocked by friendlies. Try to step to the side.
					var/list/possible_steps = list()
					for(var/d in cardinal)
						var/turf/T = get_step(src, d)
						if(T && !T.density)
							possible_steps += T
					if(possible_steps.len > 0)
						do_movement(pick(possible_steps))
						return "repositioning"
					else
						walk(src, 0)
						do_movement(loc)
						return "blocked"
				else
					walk(src, 0)
					do_movement(loc)
					OpenFire(target_mob)
					return "fire"
			else
				// Peek and shoot logic
				if(cover_turf && get_dist(src, cover_turf) <= 1 && !peeking)
					for(var/dir in cardinal)
						var/turf/peek_step = get_step(src, dir)
						if(peek_step && !peek_step.density && ai_check_los(peek_step, target_mob))
							peeking = TRUE
							var/turf/old_loc = loc
							do_movement(peek_step)
							spawn(2)
								if(src && target_mob)
									OpenFire(target_mob)
								spawn(5)
									if(src && old_loc)
										do_movement(old_loc)
										peeking = FALSE
							return "peeking"
				
				// If no LOS and can't peek, maybe suppress last known location?
				if(prob(20))
					if (!isemptylist(messages["suppressing"]) && prob(40))
						say(pick(messages["suppressing"]), language)
					OpenFire(get_turf(target_mob), TRUE)
					return "suppressing"
					
				MoveToTarget()
				return "move"
		else
			MoveToTarget()
			return "move"
	else
		if (get_dist(src, target_mob) <= 1)
			AttackingTarget()
			return "melee"
		else
			MoveToTarget()
			return "move"

/mob/living/simple_animal/hostile/human/MoveToTarget()
	if (!target_mob || !SA_attackable(target_mob))
		stance = HOSTILE_STANCE_IDLE
		wander = TRUE
		return
		
	stance = HOSTILE_STANCE_ATTACK
	wander = FALSE
	
	var/dist = get_dist(src, target_mob)
	if(ranged)
		if(dist <= 12 && (target_mob in view(14, src)))
			walk(src, 0)
			do_movement(loc)
			return
			
		if(dist <= 3)
			walk_away_od(src, target_mob, 5, 7)
		else
			if (!istype(loc, /turf/floor/trench))
				do_movement(target_mob)
	else
		if (!istype(loc, /turf/floor/trench))
			do_movement(target_mob)

/////////////////////////////AI STUFF///////////////////////////////////////////////
//Special behaviour for human hostile mobs, taking cover, grenades, etc.
/mob/living/simple_animal/hostile/human/proc/do_human_behaviour()
	if (!target_mob && !stop_automated_movement)
		wander = TRUE
		if (role == "officer")
			idle_counter++
			if (idle_counter >= 120)
				for(var/mob/living/simple_animal/hostile/human/H in range(6,src))
					if (H.faction == src.faction)
						H.charge(get_objective())
				idle_counter = 0
		return "no target"
	else
		idle_counter = 0
		wander = FALSE

	// Tactical Retreat
	if (health < maxHealth * 0.3 && world.time > last_retreat + 100)
		last_retreat = world.time
		if (prob(60))
			say(pick("!! I'm hit!", "!! Need a medic!", "!! Falling back!"), language)
			retreat()
			return "retreating"

	// Advanced Cover Seeking
	if (target_mob && !peeking)
		var/should_seek_cover = FALSE
		var/enemies_nearby = 0
		for(var/mob/living/L in view(7, src))
			if(L.faction != faction && L.stat != DEAD)
				enemies_nearby++
		
		if(enemies_nearby >= 2 || (ishuman(target_mob) && target_mob:get_active_hand()))
			should_seek_cover = TRUE
			
		if(should_seek_cover && (!cover_turf || get_dist(src, cover_turf) > 1))
			var/turf/best = find_best_cover(target_mob)
			if(best && best != loc)
				var/current_dir = get_dir(src, target_mob)
				var/new_dir = get_dir(best, target_mob)
				if(current_dir != new_dir && !isemptylist(messages["flanking"]) && prob(40))
					say(pick(messages["flanking"]), language)
				cover_turf = best
				do_movement(cover_turf)
				return "seeking cover"

	for(var/obj/item/weapon/grenade/G in view(2,src))
		if (G.active)
			walk_away_od(src, G, 5, 7)
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
	for(var/mob/living/L_enemy in view(7,src))
		var/is_enemy = FALSE
		if (ishuman(L_enemy))
			var/mob/living/human/H_enemy = L_enemy
			if (H_enemy.faction_text != src.faction && H_enemy.stat != DEAD)
				is_enemy = TRUE
		else if (istype(L_enemy, /mob/living/simple_animal/hostile))
			var/mob/living/simple_animal/hostile/SA_enemy = L_enemy
			if (SA_enemy.faction != src.faction && SA_enemy.stat != DEAD)
				is_enemy = TRUE
				
		if (is_enemy)
			target_action = "drag"
			enemy_detected = TRUE
			drag_patient(L_enemy)
			action_running = FALSE
			return

	if (!enemy_detected && target_action=="drag")
		walk(src,0)
		target_action = "helping"
		if(pulling)
			stop_pulling()
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
	if (MB && target_obj && isliving(target_obj))
		var/mob/living/patient = target_obj
		
		if (!isemptylist(messages["medic_drag"]))
			say(pick(messages["medic_drag"]), language)
			
		src.start_pulling(patient)
		
		var/turf/best_cover = find_best_cover(MB)
		if(best_cover && best_cover != loc)
			cover_turf = best_cover
			do_movement(cover_turf)
		else
			// Fallback: just walk away from the enemy
			var/tdir = OPPOSITE_DIR(get_dir(src,MB))
			do_movement(get_step(src,tdir))
			
		visible_message("<span class='warning'>[src] drags [patient] away!</span>")



/mob/living/simple_animal/hostile/human/do_behaviour(var/t_behaviour = null)
	if (stat == DEAD || stat == UNCONSCIOUS)
		return FALSE
	if (!t_behaviour)
		t_behaviour = behaviour

	a_intent = I_HARM

	if (isturf(loc) && !resting && !buckled && canmove && !stop_automated_movement)		//This is so it only moves if it's not inside a closet, gentics machine, etc.
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
			if (!target_mob || !(target_mob in ListTargets(12)) || target_mob.stat != CONSCIOUS)
				target_mob = FindTarget()
				if (target_mob)
					stance = HOSTILE_STANCE_ATTACK

		if (HOSTILE_STANCE_TIRED,HOSTILE_STANCE_ALERT)
			if (target_mob && (target_mob in ListTargets(12)))
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
		walk_away_od(src,target_mob.loc,10,5)
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
		walk_away_od(src,EN,10,5)
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
			say(pick("!! URAAAAA!","!! Charge!","!! Moving out!"), language)
		if (prob(60))
			playsound(loc, get_sfx("charge_[uppertext(language.name)]"), 100)
	else
		//none found - just move to the nearest one
		for(var/list/LT in map.faction_targets)
			if (LT[2] == src.faction)
				var/turf/t_turf2 = locate(LT[3],LT[4],LT[5])
				if (get_dist(src,t_turf2)<t_distance)
					t_turf = t_turf2
					t_distance = get_dist(src,t_turf2)
		if (t_turf && t_distance<1000)
			do_movement(t_turf)
			if (prob(20))
				say(pick("!! URAAAAA!","!! Charge!","!! Moving out!"), language)
			if (prob(60))
				playsound(loc, get_sfx("charge_[uppertext(language.name)]"), 100)
	return

/mob/living/proc/get_objective()
	return

/mob/living/simple_animal/hostile/human/get_objective()
	var/turf/best_turf = null
	var/best_score = -999999
	
	for(var/list/LT in map.faction_targets)
		if (LT[2] == src.faction || LT[2] == "all")
			var/turf/T = locate(LT[3],LT[4],LT[5])
			if(!T) continue
			
			var/score = 0
			var/dist = get_dist(src, T)
			
			// 1. Distance penalty (closer is better)
			score -= dist * 2 
			
			var/allies_present = 0
			var/enemies_present = 0
			
			// Scan the objective area
			for(var/mob/living/L in range(7, T))
				if(L.stat == DEAD) continue
				
				if(ishuman(L))
					var/mob/living/human/H = L
					if(H.faction_text == src.faction)
						allies_present++
					else
						enemies_present++
				else if(istype(L, /mob/living/simple_animal/hostile/human))
					var/mob/living/simple_animal/hostile/human/HH = L
					if(HH.faction == src.faction)
						allies_present++
					else
						enemies_present++

			// 2. Enemy presence bonus (Action is happening here, attack/defend it)
			if(enemies_present > 0)
				score += 50
				
			// 3. Allied presence evaluation (Garrison logic)
			if(allies_present == 0)
				// Empty objective! Very desirable to capture or guard.
				score += 80 
			else
				// Penalize if it's already heavily guarded to encourage spreading out
				score -= (allies_present * 10)
				
			if(score > best_score)
				best_score = score
				best_turf = T
				
	return best_turf

/mob/living/human/get_objective()
	var/turf/best_turf = null
	var/best_score = -999999
	
	for(var/list/LT in map.faction_targets)
		if (LT[2] == src.faction_text || LT[2] == "all")
			var/turf/T = locate(LT[3],LT[4],LT[5])
			if(!T) continue
			
			var/score = 0
			var/dist = get_dist(src, T)
			
			score -= dist * 2
			
			var/allies_present = 0
			var/enemies_present = 0
			
			for(var/mob/living/L in range(7, T))
				if(L.stat == DEAD) continue
				
				if(ishuman(L))
					var/mob/living/human/H = L
					if(H.faction_text == src.faction_text)
						allies_present++
					else
						enemies_present++
				else if(istype(L, /mob/living/simple_animal/hostile/human))
					var/mob/living/simple_animal/hostile/human/HH = L
					if(HH.faction == src.faction_text)
						allies_present++
					else
						enemies_present++

			if(enemies_present > 0)
				score += 50
				
			if(allies_present == 0)
				score += 80 
			else
				score -= (allies_present * 10)
				
			if(score > best_score)
				best_score = score
				best_turf = T
				
	return best_turf