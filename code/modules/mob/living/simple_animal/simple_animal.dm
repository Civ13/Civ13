/mob/living/simple_animal
	name = "animal"
	icon = 'icons/mob/animal.dmi'
	health = 20
	maxHealth = 20

	mob_bump_flag = SIMPLE_ANIMAL
	mob_swap_flags = MONKEY|SIMPLE_ANIMAL
	mob_push_flags = MONKEY|SIMPLE_ANIMAL

	var/show_stat_health = TRUE	//does the percentage health show in the stat panel for the mob

	var/icon_living = ""
	var/icon_dead = ""
	var/icon_gib = null	//We only try to show a gibbing animation if this exists.

	var/list/speak = list()
	var/speak_chance = FALSE
	var/list/emote_hear = list()	//Hearable emotes
	var/list/emote_see = list()		//Unlike speak_emote, the list of things in this variable only show by themselves with no spoken text. IE: Ian barks, Ian yaps

	var/turns_per_move = TRUE
	var/turns_since_move = FALSE
	universal_speak = FALSE		//No, just no.
	var/meat_amount = FALSE
	var/meat_type
	var/stop_automated_movement = FALSE //Use this to temporarely stop random movement or to if you write special movement code for animals.
	var/wander = TRUE	// Does the mob wander around when idle?
	var/stop_automated_movement_when_pulled = TRUE //When set to TRUE this stops the animal from moving when someone is pulling it.

	//Interaction
	var/response_help   = "tries to help"
	var/response_disarm = "tries to disarm"
	var/response_harm   = "tries to hurt"
	var/harm_intent_damage = 3

	//Temperature effect
	var/minbodytemp = 250
	var/maxbodytemp = 350
	var/heat_damage_per_tick = 3	//amount of damage applied if animal's body temperature is higher than maxbodytemp
	var/cold_damage_per_tick = 2	//same as heat_damage_per_tick, only if the bodytemperature it's lower than minbodytemp
	var/fire_alert = FALSE

	//LETTING SIMPLE ANIMALS ATTACK? WHAT COULD GO WRONG. Defaults to zero so Ian can still be cuddly
	var/melee_damage_lower = FALSE
	var/melee_damage_upper = FALSE
	var/attacktext = "attacked"
	var/attack_sound = null
	var/friendly = "nuzzles"
	var/environment_smash = FALSE
	var/resistance		  = FALSE	// Damage reduction
	//Null rod stuff
	var/supernatural = FALSE
	var/purge = FALSE
	var/obj/origin = null
	var/mob/living/following_mob = null

	var/herbivore = 0 //if it eats grass of the floor (i.e. goats, cows)
	var/granivore = 0 //if it will be attracted to crops (i.e. rabbits, mice, birds)
	var/scavenger = 0 //if it will be attracted to trash, rotting meat, etc (mice, mosquitoes)
	var/carnivore = 0 //if it will be attracted to meat and dead bodies. Wont attack living animals by default.
	var/predatory_carnivore = 0 //same as carnivore but will actively hunt animals/humans if hungry.

	var/simplehunger = 2000

/mob/living/simple_animal/New()
	..()
	verbs -= /mob/verb/observe
	if (map)
		if (map.chad_mode)
			melee_damage_lower *= 1.5
			melee_damage_upper *= 1.5
/mob/living/simple_animal/Login()
	if (src && client)
		client.screen = null
	..()

/mob/living/simple_animal/adjustBruteLoss(var/amount)
	. = ..()
	updatehealth()

/mob/living/simple_animal/Life()
	..()

	//Health
	if (stat == DEAD)
		if (health > 0)
			icon_state = icon_living
			dead_mob_list -= src
			living_mob_list += src
			stat = CONSCIOUS
			density = TRUE
		return FALSE

	if (health > maxHealth)
		health = maxHealth

	handle_stunned()
	handle_weakened()
	handle_paralysed()
	handle_supernatural()

	if (herbivore || carnivore || predatory_carnivore || granivore)
		simplehunger-=1
		if (simplehunger > 2000)
			simplehunger = 2000

		if (simplehunger <= 0)
			visible_message("\The [src] is starving!")
			adjustBruteLoss(round(max(1,maxHealth/10)))
			simplehunger = 60

	if (following_mob)
		stop_automated_movement = TRUE
		if (get_dist(src, following_mob) > 2)
			turns_since_move++
			if (turns_since_move >= turns_per_move)
				walk_to(src, following_mob,1, 6)
				turns_since_move = FALSE
		if (get_dist(src, following_mob) > 6)
			visible_message("The leash on \the [src] breaks.")
			following_mob = null
			stop_automated_movement = FALSE

	//Movement
	if (!client && !stop_automated_movement && wander && !anchored && clients.len > 0 && !istype(src, /mob/living/simple_animal/hostile))
		if (isturf(loc) && !resting && !buckled && canmove)		//This is so it only moves if it's not inside a closet, gentics machine, etc.
			turns_since_move++
			if (turns_since_move >= turns_per_move)
				if (!(stop_automated_movement_when_pulled && pulledby)) //Soma animals don't move when pulled

					if (istype(src, /mob/living/simple_animal/hostile/skeleton/attacker))
						if (prob(20) && get_dist(src, locate(/obj/effect/landmark/npctarget)) > 11)
							walk_towards(src, locate(/obj/effect/landmark/npctarget),6)
					if (istype(src, /mob/living/simple_animal/hostile/skeleton/attacker_gods))
						var/mob/living/simple_animal/hostile/skeleton/attacker_gods/A = src
						if (prob(20) && get_dist(src, A.target_loc) > 11)
							walk_towards(src, A.target_loc,6)
					if ((prob(20) && (herbivore || carnivore || predatory_carnivore || granivore || scavenger) && simplehunger < 220) || simplehunger < 180)
						check_food() // animals will search for crops, grass, and so on
					else
						var/moving_to = FALSE // otherwise it always picks 4, fuck if I know.   Did I mention fuck BYOND
						moving_to = pick(cardinal)
						set_dir(moving_to)			//How about we turn them the direction they are moving, yay.
						Move(get_step(src,moving_to))
						turns_since_move = FALSE

	//Speaking
	if (!client && speak_chance)
		if (rand(0,200) < speak_chance)
			if (speak && speak.len)
				if ((emote_hear && emote_hear.len) || (emote_see && emote_see.len))
					var/length = speak.len
					if (emote_hear && emote_hear.len)
						length += emote_hear.len
					if (emote_see && emote_see.len)
						length += emote_see.len
					var/randomValue = rand(1,length)
					if (randomValue <= speak.len)
						say(pick(speak))
					else
						randomValue -= speak.len
						if (emote_see && randomValue <= emote_see.len)
							visible_emote("[pick(emote_see)].")
						else
							audible_emote("[pick(emote_hear)].")
				else
					say(pick(speak))
			else
				if (!(emote_hear && emote_hear.len) && (emote_see && emote_see.len))
					visible_emote("[pick(emote_see)].")
				if ((emote_hear && emote_hear.len) && !(emote_see && emote_see.len))
					audible_emote("[pick(emote_hear)].")
				if ((emote_hear && emote_hear.len) && (emote_see && emote_see.len))
					var/length = emote_hear.len + emote_see.len
					var/pick = rand(1,length)
					if (pick <= emote_see.len)
						visible_emote("[pick(emote_see)].")
					else
						audible_emote("[pick(emote_hear)].")
	if (bodytemperature < minbodytemp)
		fire_alert = 2
		adjustBruteLoss(cold_damage_per_tick)

	else if (bodytemperature > maxbodytemp)
		fire_alert = TRUE
		adjustBruteLoss(heat_damage_per_tick)

	else
		fire_alert = FALSE
	return TRUE


/mob/living/simple_animal/proc/handle_supernatural()
	if (purge)
		purge -= 1

/mob/living/simple_animal/gib()
	..(icon_gib,1)

/mob/living/simple_animal/emote(var/act, var/type, var/desc)
	if (act)
		..(act, type, desc)

/mob/living/simple_animal/proc/visible_emote(var/act_desc)
	custom_emote(1, act_desc)

/mob/living/simple_animal/proc/audible_emote(var/act_desc)
	custom_emote(2, act_desc)

/mob/living/simple_animal/bullet_act(var/obj/item/projectile/proj)
	if (proj.firer && ishuman(proj.firer) && proj.firedfrom)
		if (proj.firer == rider)
			return //we can't hit the animals we are riding
		var/mob/living/carbon/human/H = proj.firer
		if (prob(40))
			switch (proj.firedfrom.gun_type)
				if (GUN_TYPE_RIFLE)
					H.adaptStat("rifle", 1)
				if (GUN_TYPE_PISTOL)
					H.adaptStat("pistol", 1)
				if (GUN_TYPE_BOW)
					H.adaptStat("bows", 1)

	adjustBruteLoss(proj.damage)
	return FALSE

	if (!proj || proj.nodamage)
		return

/mob/living/simple_animal/attack_hand(mob/living/carbon/human/M as mob)
	..()

	switch(M.a_intent)

		if (I_HELP)

			if (health > 0)
				if (istype(src, /mob/living/simple_animal/dog))
					if (prob(30))
						M.visible_message("<span class = 'notice'>[M] tells \the [src] that he is a good boy!</span>")
					else
						M.visible_message("<span class = 'notice'>[M] pats \the [src]'s head!</span>")
				else
					M.visible_message("<span class = 'notice'>[M] [response_help] \the [src].</span>")

		if (I_DISARM)
			M.visible_message("<span class = 'notice'>[M] [response_disarm] \the [src].</span>")
			M.do_attack_animation(src)
			playsound(get_turf(M), 'sound/weapons/punchmiss.ogg', 50, TRUE, -1)
			//TODO: Push the mob away or something

		if (I_GRAB)
			if (M == src)
				return
			if (!(status_flags & CANPUSH))
				return

			var/obj/item/weapon/grab/G = new /obj/item/weapon/grab(M, src)

			M.put_in_active_hand(G)

			G.synch()
			G.affecting = src
			LAssailant = M

			M.visible_message("<span class = 'red'>[M] has grabbed [src] passively!</span>")
			M.do_attack_animation(src)

		if (I_HURT)
			adjustBruteLoss(harm_intent_damage*M.getStatCoeff("strength"))
			M.visible_message("<span class = 'red'>[M] [response_harm] \the [src].</span>")
			M.do_attack_animation(src)
			playsound(get_turf(M), "punch", 50, TRUE, -1)

	return

/mob/living/simple_animal/attackby(var/obj/item/O, var/mob/user)
	if (istype(O, /obj/item/weapon/leash) && !(istype(src, /mob/living/simple_animal/hostile)))
		var/obj/item/weapon/leash/L = O
		if (L.onedefined == FALSE)
			L.S1 = src
			user << "You tie \the [src] with the leash."
			L.onedefined = TRUE
			return
		else if (L.onedefined == TRUE && (src in range(3,L.S1)))
			L.S2 = src
			L.S2.following_mob = L.S1
			user << "You tie \the [src] to \the [L.S1] with the leash. It will now follow \the [L.S1]."
			qdel(L)
			return
	else if (istype(O, /obj/item/stack/medical))
		if (stat != DEAD)
			var/obj/item/stack/medical/MED = O
			if (health < maxHealth)
				if (MED.amount >= 1)
					adjustBruteLoss(-MED.heal_brute)
					MED.amount -= 1
					if (MED.amount <= 0)
						qdel(MED)
					for (var/mob/M in viewers(src, null))
						if ((M.client && !( M.blinded )))
							M.show_message("<span class='notice'>[user] applies the [MED] on [src].</span>")
					return TRUE
		else
			user << "<span class='notice'>\The [src] is dead, medical items won't bring \him back to life.</span>"
			return TRUE
	else if (!O.sharp)
		if (!O.force && !istype(O, /obj/item/stack/medical/bruise_pack))
			visible_message("<span class='notice'>[user] gently taps [src] with \the [O].</span>")
		else
			var/tgt = user.targeted_organ
			if (user.targeted_organ == "random")
				tgt = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
			O.attack(src, user, tgt)
	else if (O.sharp && !istype(src, /mob/living/simple_animal/hostage))
		if (!istype(O, /obj/item/weapon/reagent_containers) && user.a_intent == I_HURT && stat == DEAD)
			if (istype(src, /mob/living/simple_animal/frog/poisonous))
				user.visible_message("<span class = 'notice'>[user] starts to butcher [src].</span>")
				if (do_after(user, 30, src))
					user.visible_message("<span class = 'notice'>[user] butchers [src] into a meat slab.</span>")
					new/obj/item/weapon/reagent_containers/food/snacks/meat/poisonfrog(get_turf(src))
					if (istype(user, /mob/living/carbon/human))
						var/mob/living/carbon/human/HM = user
						HM.adaptStat("medical", 0.3)
					crush()
					qdel(src)
			else
				user.visible_message("<span class = 'notice'>[user] starts to butcher [src].</span>")
				if (do_after(user, 30, src))
					user.visible_message("<span class = 'notice'>[user] butchers [src].</span>")
					var/amt = 0
					if (mob_size == MOB_MINISCULE)
						amt = 1
					if (mob_size == MOB_TINY)
						amt = 2
					if (mob_size == MOB_SMALL)
						amt = 3
					if (mob_size == MOB_MEDIUM)
						amt = 4
					if (mob_size == MOB_LARGE)
						amt = 5
					if (mob_size == MOB_HUGE)
						amt = 8
					var/namt = amt-2
					if (namt <= 0)
						namt = 1
					var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
					meat.name = "[name] meatsteak"
					meat.amount = namt
					if ((amt-2) >= 1)
						var/obj/item/stack/material/leather/leather = new/obj/item/stack/material/leather(get_turf(src))
						leather.name = "[name] leather"
						leather.amount = (amt-2)
					if ((amt-2) >= 1)
						var/obj/item/stack/material/bone/bone = new/obj/item/stack/material/bone(get_turf(src))
						bone.name = "[name] bone"
						bone.amount = (amt-2)
					if (istype(user, /mob/living/carbon/human))
						var/mob/living/carbon/human/HM = user
						HM.adaptStat("medical", amt/3)
					crush()
					qdel(src)
		if (!istype(O, /obj/item/weapon/reagent_containers) && user.a_intent == I_GRAB && stat == DEAD)
			user.visible_message("<span class = 'notice'>[user] starts to skin and butcher [src].</span>")
			if (do_after(user, 100, src))
				user.visible_message("<span class = 'notice'>[user] skins and butchers [src].</span>")
				var/amt = 0
				if (mob_size == MOB_MINISCULE)
					amt = 1
				if (mob_size == MOB_TINY)
					amt = 2
				if (mob_size == MOB_SMALL)
					amt = 3
				if (mob_size == MOB_MEDIUM)
					amt = 4
				if (mob_size == MOB_LARGE)
					amt = 5
				if (mob_size == MOB_HUGE)
					amt = 8
				var/namt = amt-2
				if (namt <= 0)
					namt = 1
				var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
				meat.name = "[name] meatsteak"
				meat.amount = namt
				if ((amt-2) >= 1)
					var/obj/item/stack/material/bone/bone = new/obj/item/stack/material/bone(get_turf(src))
					bone.name = "[name] bone"
					bone.amount = amt
				if (istype(src, /mob/living/simple_animal/hostile/bear))
					var/obj/item/stack/material/bearpelt/black/NP = new/obj/item/stack/material/bearpelt/black(get_turf(src))
					NP.amount = 6
				else if (istype(src, /mob/living/simple_animal/hostile/bear/polar))
					var/obj/item/stack/material/bearpelt/white/NP = new/obj/item/stack/material/bearpelt/white(get_turf(src))
					NP.amount = 6
				else if (istype(src, /mob/living/simple_animal/hostile/bear/brown))
					var/obj/item/stack/material/bearpelt/brown/NP = new/obj/item/stack/material/bearpelt/brown(get_turf(src))
					NP.amount = 6
				else if (istype(src, /mob/living/simple_animal/hostile/wolf))
					var/obj/item/stack/material/wolfpelt/NP = new/obj/item/stack/material/wolfpelt(get_turf(src))
					NP.amount = 4
				else if (istype(src, /mob/living/simple_animal/monkey))
					var/obj/item/stack/material/monkeypelt/NP = new/obj/item/stack/material/monkeypelt(get_turf(src))
					NP.amount = 3
				else if (istype(src, /mob/living/simple_animal/cat))
					var/obj/item/stack/material/catpelt/NP = new/obj/item/stack/material/catpelt(get_turf(src))
					NP.amount = 2
				if (istype(user, /mob/living/carbon/human))
					var/mob/living/carbon/human/HM = user
					HM.adaptStat("medical", amt/3)
				crush()
				qdel(src)
		else if (istype(O, /obj/item/weapon/reagent_containers/glass))
			return
		else
			var/tgt = user.targeted_organ
			if (user.targeted_organ == "random")
				tgt = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
			O.attack(src, user, tgt)
/mob/living/simple_animal/hit_with_weapon(obj/item/O, mob/living/user, var/effective_force, var/hit_zone)

	visible_message("<span class='danger'>\The [src] has been attacked with \the [O] by [user].</span>")

	if (O.force <= resistance)
		user << "<span class='danger'>This weapon is ineffective, it does no damage.</span>"
		return 2

	var/damage = O.force
	if (O.damtype == HALLOSS)
		damage = FALSE

	adjustBruteLoss(damage)

	return FALSE

/mob/living/simple_animal/movement_delay()
	var/tally = FALSE //Incase I need to add stuff other than "speed" later

	tally = speed
	if (purge)//Purged creatures will move more slowly. The more time before their purge stops, the slower they'll move.
		if (tally <= 0)
			tally = 1.0
		tally *= purge

	return tally

/mob/living/simple_animal/Stat()
	..()

	if (statpanel("Status") && show_stat_health)
		stat(null, "Health: [round((health / maxHealth) * 100)]%")

/mob/living/simple_animal/proc/unregisterSpawner()
	if (origin != null)
		if (istype(origin, /obj/effect/spawner/mobspawner))
			var/obj/effect/spawner/mobspawner/O = origin
			O.current_number--
			if (O.current_number < 0)
				O.current_number = 0
			origin = null
		else if (istype(origin, /obj/structure/sink))
			var/obj/structure/sink/O = origin
			O.mosquito_count--
			if (O.mosquito_count < 0)
				O.mosquito_count = 0
			origin = null

/mob/living/simple_animal/Destroy()
	unregisterSpawner()
	..()

/mob/living/simple_animal/death(gibbed, deathmessage = "dies!")
	icon_state = icon_dead
	density = FALSE

	walk_to(src,0) // stops movement
	unregisterSpawner()
	decay()
	return ..(gibbed,deathmessage)

/mob/living/simple_animal/proc/decay()
	spawn(7200)
		if (stat == DEAD)
			var/amt = 0
			if (mob_size == MOB_MINISCULE)
				amt = 0
			if (mob_size == MOB_TINY)
				amt = 0
			if (mob_size == MOB_SMALL)
				amt = 1
			if (mob_size == MOB_MEDIUM)
				amt = 2
			if (mob_size == MOB_LARGE)
				amt = 3
			if (mob_size == MOB_HUGE)
				amt = 6
			if (amt >= 1)
				var/obj/item/stack/material/bone/bone = new/obj/item/stack/material/bone(get_turf(src))
				bone.name = "[name] bone"
				bone.amount = amt
			qdel(src)
/mob/living/simple_animal/ex_act(severity)
	if (!blinded)
		if (HUDtech.Find("flash"))
			flick("flash", HUDtech["flash"])
	switch (severity)
		if (1.0)
			adjustBruteLoss(500)
			gib()
			return

		if (2.0)
			adjustBruteLoss(60)


		if (3.0)
			adjustBruteLoss(30)

/mob/living/simple_animal/proc/SA_attackable(target_mob)
	if (isliving(target_mob))
		var/mob/living/L = target_mob
		if (!L.stat)
			return (0)
	return TRUE

/mob/living/simple_animal/say(var/message)
	var/verb = "says"
	if (speak_emote.len)
		verb = pick(speak_emote)

	message = sanitize(message)

	..(message, null, verb)

/mob/living/simple_animal/get_speech_ending(verb, var/ending)
	return verb

/mob/living/simple_animal/put_in_hands(var/obj/item/W) // No hands.
	W.loc = get_turf(src)
	return TRUE

/mob/living/simple_animal/handle_fire()
	return

/mob/living/simple_animal/update_fire()
	return
/mob/living/simple_animal/IgniteMob()
	return
/mob/living/simple_animal/ExtinguishMob()
	return

/mob/living/simple_animal/verb/remove_leash()
	set category = null
	set name = "Remove leash"
	set desc = "Remove a leash from this animal."

	set src in view(1)

	if (following_mob == null)
		usr << "This animal is not leashed."
		return
	else if (istype(following_mob, /obj/structure/grille/fence) || istype(following_mob, /obj/structure/barricade/wood_pole))
		following_mob = null
		new/obj/item/weapon/leash(src.loc)
		usr << "You free the [src]."
		stop_automated_movement = FALSE

		return
	else
		following_mob = null
		new/obj/item/weapon/leash(src.loc)
		usr << "You free the [src]."
		stop_automated_movement = FALSE

		return

/mob/living/simple_animal/proc/check_food()

	var/totalcount = herbivore+granivore+carnivore+predatory_carnivore+scavenger
	if (totalcount <= 0)
		return
	if (herbivore)
		if (prob(100/totalcount))
			for(var/turf/floor/grass/GT in range(2,src))
				walk_towards(src,0)
				eat()
				return
			for(var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/WT in range(2,src))
				walk_towards(src,0)
				eat()
				return
			for(var/turf/floor/grass/GT in range(6,src))
				walk_towards(src, GT, turns_per_move)
				return
		else
			return

	if (granivore)
		if (prob(100/totalcount))
			for(var/obj/item/stack/farming/seeds/WT in range(2,src))
				walk_towards(src,0)
				eat()
				return
			for(var/obj/structure/farming/plant/PL in range(2,src))
				walk_towards(src,0)
				eat()
				return
			for(var/obj/structure/farming/plant/PL in range(8,src))
				walk_towards(src, PL, turns_per_move)
				return

	if (carnivore)
		if (prob(100/totalcount))
			for(var/mob/living/ML in range(2,src))
				walk_towards(src,0)
				eat()
				return
			for(var/mob/living/ML in range(9,src))
				if (ML.stat == DEAD)
					walk_towards(src, ML, turns_per_move)
					return

	if (predatory_carnivore)
		if (prob(100/totalcount))
			for(var/mob/living/ML in range(2,src))
				walk_towards(src,0)
				eat()
				return
			for(var/mob/living/ML in range(9,src))
				walk_towards(src, ML, turns_per_move)
				return

	if (scavenger)
		if (prob(100/totalcount))
			for(var/obj/item/weapon/reagent_containers/food/snacks/FD in range(2,src))
				walk_towards(src,0)
				eat()
				return
			for(var/obj/item/weapon/reagent_containers/food/snacks/FD in range(8,src))
				walk_towards(src, FD, turns_per_move)
				return

/mob/living/simple_animal/proc/eat()
	var/totalcount = herbivore+granivore+carnivore+predatory_carnivore+scavenger
	if (totalcount <= 0)
		return

	if (herbivore)
		for(var/turf/floor/grass/GT in range(2,src))
			if (prob(33))
				visible_message("\The [src] eats some grass.")
				simplehunger += 550
				adjustBruteLoss(-4)
				GT.grassamt -= 1
				if (GT.grassamt <= 0)
					if (istype(GT, (/turf/floor/grass/jungle)))
						GT.ChangeTurf(/turf/floor/dirt/jungledirt)
						return
					else
						GT.ChangeTurf(/turf/floor/dirt)
						return
				else
					return
		for(var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/WT in range(2,src))
			if (prob(30))
				visible_message("\The [src] eats some of the wheat.")
				simplehunger += 550
				adjustBruteLoss(-4)
				qdel(WT)
				return


	if (granivore)
		for(var/obj/item/stack/farming/seeds/SD in range(2,src))
			if (prob(35))
				visible_message("<span class='notice'>\The [src] eats \the [SD]!</span>")
				simplehunger += 500
				adjustBruteLoss(-4)
				qdel(SD)
				return
		for(var/obj/structure/farming/plant/PL in range(2,src))
			if (prob(15))
				visible_message("<span class='notice'>\The [src] eats \the [PL]!</span>")
				simplehunger += 400
				adjustBruteLoss(-4)
				qdel(PL)
				return
			else
				return


	if (carnivore)
		for(var/mob/living/ML in range(2,src))
			if (ML.stat == DEAD)
				if (prob(33))
					visible_message("\The [src] bites some meat of \the [ML].")
					simplehunger += 400
					adjustBruteLoss(-4)
					if (istype(ML, /mob/living/simple_animal))
						var/mob/living/simple_animal/MLL = ML
						if (MLL.mob_size <= 9)
							qdel(ML)
						else
							if (prob(30))
								qdel(ML)
						return


	if (scavenger)
		for(var/obj/item/weapon/reagent_containers/food/snacks/FD in range(2,src))
			if (prob(33))
				visible_message("\The [src] bites some of \the [FD].")
				simplehunger += 400
				adjustBruteLoss(-4)
				if (prob(30))
					qdel(FD)
					return


	if (predatory_carnivore)
		for(var/mob/living/ML in range(2,src))
			return


