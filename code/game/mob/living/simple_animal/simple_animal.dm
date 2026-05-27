#define GRAIN /obj/item/weapon/reagent_containers/food/snacks/grown/wheat||/obj/item/weapon/reagent_containers/food/snacks/grown/oat||/obj/item/weapon/reagent_containers/food/snacks/grown/barley||/obj/item/weapon/reagent_containers/food/snacks/grown/rice

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

	var/turns_since_move = FALSE
	var/stuck_ticks = 0
	var/turf/last_loc = null
	universal_speak = FALSE		//No, just no.
	var/meat_amount = FALSE
	var/meat_type
	var/fat_extra = 0
	var/fat_penalty = 0
	var/has_fat = TRUE //Does this animal drops fat?
	var/stop_automated_movement = FALSE //Use this to temporarely stop random movement or to if you write special movement code for animals.
	var/wander = TRUE	// Does the mob wander around when idle?
	var/stop_automated_movement_when_pulled = TRUE //When set to TRUE this stops the animal from moving when someone is pulling it.
	var/flying = FALSE

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
	var/attack_sound = 'sound/weapons/bite.ogg'
	var/friendly = "nuzzles"
	var/environment_smash = FALSE
	var/resistance		  = FALSE	// Damage reduction
	var/obj/origin = null
	var/mob/living/following_mob = null

	var/herbivore = 0 //if it eats grass of the floor (i.e. goats, cows)
	var/granivore = 0 //if it will be attracted to crops (i.e. rabbits, mice, birds)
	var/scavenger = 0 //if it will be attracted to trash, rotting meat, etc (mice, mosquitoes)
	var/carnivore = 0 //if it will be attracted to meat and dead bodies. Wont attack living animals by default.
	var/predatory_carnivore = 0 //same as carnivore but will actively hunt animals/humans if hungry.
	var/starves = TRUE

	var/behaviour = "wander" ///wander: go around randomly. scared: run from humans-predators, default to wander after. hunt: move towards prey areas. defends: will attack only if attacked

	var/simplehunger = 1000
	var/eggsleft = FALSE //Eggs left that may be generated, currently set to FALSE by default to decide what animals lay eggs, may cause issues later
	var/maxeggs = 5

	//hostile mob stuff
	var/stance = HOSTILE_STANCE_IDLE	//Used to determine behavior
	var/mob/living/target_mob
	var/move_to_delay = 4 //delay for the automated movement.
	var/list/friends = list()
	var/break_stuff_probability = 10
	var/destroy_surroundings = TRUE
	var/enroute = FALSE
	var/stance_step = FALSE
	var/can_bite_limbs_off = FALSE
	var/ai_tick_delay = 0 // Throttle AI logic in Life()
	var/ai_tick_delay_max = 3 // Idle ticks between AI logic runs

	var/vision_range = 7 //How big of an area to search for targets in, a vision of 7 attempts to find targets as soon as they walk into screen view
	var/aggro_vision_range = 7 //If a mob is aggro, we search in this radius.
	var/idle_vision_range = 7 //If a mob is just idling around, it's vision range is limited to this.

	//SoundFX
	var/hostilesounds = list()
	var/wandersounds = list()

	//Radiation Varients
	var/mutation_variants = list()

	var/attack_verb = "bites"
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
	if (loc == null)
		spawn(10)
			if (loc == null)
				qdel(src)
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
	handle_mutations_and_radiation()

	if (starves)
		if (herbivore || carnivore || predatory_carnivore || granivore || scavenger)
			simplehunger-=1
			if (simplehunger > 1000)
				simplehunger = 1000

		if (simplehunger <= 0)
			visible_message("\The [src] is starving!")
			adjustBruteLoss(round(max(1,maxHealth/10)))
			simplehunger = 60
			updatehealth()

	if (following_mob)
		stop_automated_movement = TRUE
		if (get_dist(src, following_mob) > 2)
			turns_since_move++
			if (turns_since_move >= move_to_delay)
				walk_to(src, following_mob,1, 6)
				turns_since_move = FALSE
		if (get_dist(src, following_mob) > 6)
			following_mob = null
			stop_automated_movement = FALSE

	// AI and Movement logic
	handle_ai()

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
	if (proj.firer && istype(proj.firer, /mob/living/simple_animal/hostile/human))
		var/mob/living/simple_animal/hostile/human/HM = proj.firer
		if(HM.faction == src.faction)
			return
	if (proj.firer && ishuman(proj.firer) && proj.firedfrom)
		if (proj.firer == rider)
			return //we can't hit the animals we are riding
		var/mob/living/human/H = proj.firer
		if (prob(40) && proj.firedfrom)
			if (istype(proj.firedfrom, /obj/item/weapon/gun))
				var/obj/item/weapon/gun/G = proj.firedfrom
				switch (G.gun_type)
					if (GUN_TYPE_RIFLE)
						H.adaptStat("rifle", 1)
					if (GUN_TYPE_PISTOL)
						H.adaptStat("pistol", 1)
					if (GUN_TYPE_BOW)
						H.adaptStat("bows", 1)

	if (!proj || proj.nodamage)
		return FALSE

	adjustBruteLoss(proj.damage)
	return FALSE

/mob/living/simple_animal/attack_hand(mob/living/human/M as mob)
	..()
	if (istype(src, /mob/living/simple_animal/hostile/human/voyage/pirate/friendly))
		faction = CIVILIAN
		behaviour = "hostile"
	if (behaviour == "hunt" || behaviour == "hostile")
		if (stance == HOSTILE_STANCE_ATTACK && target_mob && target_mob != M)
			if (prob(75))
				target_mob = M
		else
			target_mob = M
		stance = HOSTILE_STANCE_ATTACK
		stance_step = 6
	else if (behaviour == "scared")
		do_behaviour("scared")

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
			if (behaviour == "defends")
				if (stance == HOSTILE_STANCE_ATTACK && target_mob && target_mob != M)
					if (prob(75))
						target_mob = M
				else
					target_mob = M
				stance = HOSTILE_STANCE_ATTACK
				stance_step = 6
			M.visible_message("<span class = 'notice'>[M] [response_disarm] \the [src].</span>")
			M.do_attack_animation(src)
			playsound(get_turf(M), 'sound/weapons/punchmiss.ogg', 50, TRUE, -1)
			//TODO: Push the mob away or something

		if (I_GRAB)
			if (behaviour == "defends")
				if (stance == HOSTILE_STANCE_ATTACK && target_mob && target_mob != M)
					if (prob(75))
						target_mob = M
				else
					target_mob = M
				stance = HOSTILE_STANCE_ATTACK
				stance_step = 6
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

		if (I_HARM)
			if (behaviour == "defends")
				if (stance == HOSTILE_STANCE_ATTACK && target_mob && target_mob != M)
					if (prob(75))
						target_mob = M
				else
					target_mob = M
				stance = HOSTILE_STANCE_ATTACK
				stance_step = 6
			adjustBruteLoss(harm_intent_damage*M.getStatCoeff("strength"))
			M.visible_message("<span class = 'red'>[M] [response_harm] \the [src].</span>")
			M.do_attack_animation(src)
			playsound(get_turf(M), "punch", 50, TRUE, -1)

	return

/mob/living/simple_animal/proc/feed(var/obj/item/O as obj, var/mob/user as mob)
	if (stat == CONSCIOUS)
		if (granivore && istype(O, /obj/item/stack/farming/seeds))
			var/obj/item/stack/S = O
			if (eggsleft != FALSE && eggsleft < maxeggs)
				eggsleft++
			else if (simplehunger >= 800)
				to_chat(user, SPAN_RED("\The [src] is not hungry."))
				return
			if (mob_size >= MOB_MEDIUM)
				new/obj/item/weapon/reagent_containers/food/snacks/poo/animal(src.loc)
			simplehunger += 500
			adjustBruteLoss(-4)
			user.visible_message(SPAN_NOTICE("[user] feeds [src] \the [S]."))
			if(S.amount >= 2)
				S.amount -= 1
			else
				qdel(S)
		if (herbivore && istype(O, GRAIN))
			var/obj/item/weapon/reagent_containers/food/snacks/grown/G = O
			if (simplehunger >= 800)
				to_chat(user, SPAN_RED("\The [src] is not hungry."))
				return
			if (mob_size >= MOB_MEDIUM)
				new/obj/item/weapon/reagent_containers/food/snacks/poo/animal(src.loc)
			simplehunger += 550
			adjustBruteLoss(-4)
			user.visible_message(SPAN_NOTICE("[user] feeds [src] \the [G].</span>"))
			qdel(G)
	return

/mob/living/simple_animal/attackby(var/obj/item/O, var/mob/user)
	if (ishuman(user))
		var/mob/living/human/H = user
		if ((H.a_intent == I_DISARM || H.a_intent == I_HARM) && (istype(src, /mob/living/simple_animal/hostile/human/voyage) || istype(src, /mob/living/simple_animal/hostile/human/voyage/pirate/friendly)) && src.behaviour != "Hostile")
			for(var/mob/living/simple_animal/hostile/human/FR in world)
				FR.faction = CIVILIAN
				FR.behaviour = "hostile"
	if (istype(O, /obj/item/weapon/leash) && behaviour != "defends" && behaviour != "hunt")
		var/obj/item/weapon/leash/L = O
		if (L.onedefined == FALSE)
			L.S1 = src
			to_chat(user, "You tie \the [src] with the leash.")
			L.onedefined = TRUE
			return
		else if (L.onedefined == TRUE && (src in range(3,L.S1)))
			L.S2 = src
			L.S2.following_mob = L.S1
			to_chat(user, "You tie \the [src] to \the [L.S1] with the leash. It will now follow \the [L.S1].")
			qdel(L)
			return
	else if (istype(O, /obj/item/stack/farming/seeds))
		var/obj/item/S = O
		feed(S, user)
	else if (istype(O, GRAIN))
		var/obj/item/G = O
		feed(G, user)
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
			to_chat(user, SPAN_NOTICE("\The [src] is dead, medical items won't bring \him back to life."))
			return TRUE
	else if (!O.sharp || istype(O, /obj/item/weapon/macuahuitl))
		if (!O.force && !istype(O, /obj/item/stack/medical/bruise_pack))
			visible_message("<span class='notice'>[user] gently taps [src] with \the [O].</span>")
		else
			var/tgt = user.targeted_organ
			if (user.targeted_organ == "random")
				tgt = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
			O.attack(src, user, tgt)
	else if (O.sharp && !istype(src, /mob/living/simple_animal/hostage))
		if (!istype(O, /obj/item/weapon/reagent_containers) && user.a_intent == I_HARM && stat == DEAD)
			if (istype(src, /mob/living/simple_animal/frog/poisonous))
				user.visible_message("<span class = 'notice'>[user] starts to butcher [src].</span>")
				if (do_after(user, 30, src))
					user.visible_message("<span class = 'notice'>[user] butchers [src] into a meat slab.</span>")
					var/obj/item/weapon/reagent_containers/food/snacks/meat/poisonfrog/P = new/obj/item/weapon/reagent_containers/food/snacks/meat/poisonfrog(get_turf(src))
					P.radiation = radiation/2
					if (istype(user, /mob/living/human))
						var/mob/living/human/HM = user
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
					if (!istype(src, /mob/living/simple_animal/crab))
						if(src.has_fat)
							var/fat_calc = (namt + fat_extra) - fat_penalty
							if(!fat_calc <= 0)
								for (var/i=0, i<=fat_calc, i++) //Fat drop
									var/obj/item/weapon/reagent_containers/food/snacks/animalfat/fat = new/obj/item/weapon/reagent_containers/food/snacks/animalfat(get_turf(src))
									fat.name = "[name] fat"
						if (istype(src, /mob/living/simple_animal/hostile/human/zombie))
							for (var/i=0, i<=namt, i++)
								var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
								meat.name = "rotten zombie meat"
								meat.radiation = radiation/2
								meat.icon_state = "rottenmeat"
								if (meat.reagents)
									meat.reagents.remove_reagent("protein", 2)
									meat.reagents.add_reagent("food_poisoning", 1)
								meat.rotten = TRUE
								meat.satisfaction = -30
						else if (istype(src, /mob/living/simple_animal/pig_gilt) || istype(src, /mob/living/simple_animal/pig_boar))
							new/obj/item/weapon/reagent_containers/food/snacks/pig/stomach(get_turf(src))
							new/obj/item/weapon/pigleg(get_turf(src))
						else if (istype(src, /mob/living/simple_animal/boar_gilt))
							new/obj/item/weapon/reagent_containers/food/snacks/pig/stomach(get_turf(src))
							new/obj/item/weapon/pigleg(get_turf(src))
						else if (istype(src, /mob/living/simple_animal/boar_boar))
							new/obj/item/weapon/reagent_containers/food/snacks/pig/stomach(get_turf(src))
							new/obj/item/weapon/pigleg(get_turf(src))
						else if (istype(src, /mob/living/simple_animal/chicken) || istype(src, /mob/living/simple_animal/rooster))
							new/obj/item/weapon/chicken_carcass(get_turf(src))
						else if (istype(src, /mob/living/simple_animal/cattle/cow) || istype(src, /mob/living/simple_animal/cattle/bull))
							new/obj/item/weapon/reagent_containers/food/snacks/cow/stomach(get_turf(src))
							for (var/i=0, i<=namt, i++)
								var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
								meat.name = "[name] meat"
								meat.radiation = radiation/2
						else if (istype(src, /mob/living/simple_animal/goat))
							new/obj/item/weapon/reagent_containers/food/snacks/pig/stomach/goat(get_turf(src))
							for (var/i=0, i<=namt, i++)
								var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
								meat.name = "[name] meat"
								meat.radiation = radiation/2
						else if (istype(src, /mob/living/simple_animal/sheep))
							new/obj/item/weapon/reagent_containers/food/snacks/pig/stomach/sheep(get_turf(src))
							for (var/i=0, i<=namt, i++)
								var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
								meat.name = "[name] meat"
								meat.radiation = radiation/2
						else
							for (var/i=0, i<=namt, i++)
								var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
								meat.name = "[name] meat"
								meat.radiation = radiation/2
					else
						for (var/i=0, i<=namt, i++)
							var/obj/item/weapon/reagent_containers/food/snacks/rawcrab/meat = new/obj/item/weapon/reagent_containers/food/snacks/rawcrab(get_turf(src))
							meat.radiation = radiation/2

					if ((amt-2) >= 1)
						var/obj/item/stack/material/leather/leather = new/obj/item/stack/material/leather(get_turf(src))
						leather.name = "[name] leather"
						leather.amount = (amt-2)
					if ((amt-2) >= 1)
						var/obj/item/stack/material/bone/bone = new/obj/item/stack/material/bone(get_turf(src))
						bone.name = "[name] bone"
						bone.amount = (amt-2)
					if (istype(user, /mob/living/human))
						var/mob/living/human/HM = user
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
				if (!istype(src, /mob/living/simple_animal/crab))
					var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
					meat.name = "[name] meatsteak"
					meat.amount = namt
					meat.radiation = radiation/2
				else
					var/obj/item/weapon/reagent_containers/food/snacks/rawcrab/meat = new/obj/item/weapon/reagent_containers/food/snacks/rawcrab(get_turf(src))
					meat.amount = namt
					meat.radiation = radiation/2

				if ((amt-2) >= 1)
					var/obj/item/stack/material/bone/bone = new/obj/item/stack/material/bone(get_turf(src))
					bone.name = "[name] bone"
					bone.amount = amt
				if (istype(src, /mob/living/simple_animal/hostile/bear)) //all bears on the inheritance path drop leather to compensate for improper types.
					var/obj/item/stack/material/leather/NP = new/obj/item/stack/material/leather(get_turf(src))
					NP.amount = 1.5
				if (istype(src, /mob/living/simple_animal/hostile/bear/boar/black))
					var/obj/item/stack/material/pelt/bearpelt/black/NP = new/obj/item/stack/material/pelt/bearpelt/black(get_turf(src))
					NP.amount = 6
				if (istype(src, /mob/living/simple_animal/hostile/bear/sow/black))
					var/obj/item/stack/material/pelt/bearpelt/black/NP = new/obj/item/stack/material/pelt/bearpelt/black(get_turf(src))
					NP.amount = 6
				if (istype(src, /mob/living/simple_animal/hostile/bear/boar/polar))
					var/obj/item/stack/material/pelt/bearpelt/white/NP = new/obj/item/stack/material/pelt/bearpelt/white(get_turf(src))
					NP.amount = 6
				if (istype(src, /mob/living/simple_animal/hostile/bear/sow/polar))
					var/obj/item/stack/material/pelt/bearpelt/white/NP = new/obj/item/stack/material/pelt/bearpelt/white(get_turf(src))
					NP.amount = 6
				if (istype(src, /mob/living/simple_animal/hostile/bear/boar/brown))
					var/obj/item/stack/material/pelt/bearpelt/brown/NP = new/obj/item/stack/material/pelt/bearpelt/brown(get_turf(src))
					NP.amount = 6
				if (istype(src, /mob/living/simple_animal/hostile/bear/sow/brown))
					var/obj/item/stack/material/pelt/bearpelt/brown/NP = new/obj/item/stack/material/pelt/bearpelt/brown(get_turf(src))
					NP.amount = 6
				else if (istype(src, /mob/living/simple_animal/hostile/wolf))
					var/obj/item/stack/material/pelt/wolfpelt/NP = new/obj/item/stack/material/pelt/wolfpelt(get_turf(src))
					NP.amount = 4
				else if (istype(src, /mob/living/simple_animal/hostile/wolf/white))
					var/obj/item/stack/material/pelt/wolfpelt/white/NP = new/obj/item/stack/material/pelt/wolfpelt/white(get_turf(src))
					NP.amount = 4
				else if (istype(src, /mob/living/simple_animal/monkey))
					var/obj/item/stack/material/pelt/monkeypelt/NP = new/obj/item/stack/material/pelt/monkeypelt(get_turf(src))
					NP.amount = 3
				else if (istype(src, /mob/living/simple_animal/hostile/gorilla))
					var/obj/item/stack/material/pelt/gorillapelt/NP = new/obj/item/stack/material/pelt/gorillapelt(get_turf(src))
					NP.amount = 3
				else if (istype(src, /mob/living/simple_animal/hostile/gorilla/gigantopithecus))
					var/obj/item/stack/material/pelt/gorillapelt/NP = new/obj/item/stack/material/pelt/gorillapelt(get_turf(src))
					NP.amount = 6
				else if (istype(src, /mob/living/simple_animal/hostile/fox/arctic))
					var/obj/item/stack/material/pelt/foxpelt/white/NP = new/obj/item/stack/material/pelt/foxpelt/white(get_turf(src))
					NP.amount = 3
				else if (istype(src, /mob/living/simple_animal/hostile/fox))
					var/obj/item/stack/material/pelt/foxpelt/NP = new/obj/item/stack/material/pelt/foxpelt(get_turf(src))
					NP.amount = 3
				else if (istype(src, /mob/living/simple_animal/cat))
					var/obj/item/stack/material/pelt/catpelt/NP = new/obj/item/stack/material/pelt/catpelt(get_turf(src))
					NP.amount = 2
				else if (istype(src, /mob/living/simple_animal/hostile/panther) && !istype(src, /mob/living/simple_animal/hostile/panther/jaguar))
					var/obj/item/stack/material/pelt/pantherpelt/NP = new/obj/item/stack/material/pelt/pantherpelt(get_turf(src))
					NP.amount = 3
				else if (istype(src, /mob/living/simple_animal/hostile/sabertooth) && !istype(src, /mob/living/simple_animal/hostile/sabertooth/white))
					var/obj/item/stack/material/pelt/lionpelt/NP = new/obj/item/stack/material/pelt/lionpelt(get_turf(src))
					NP.amount = 6
				else if (istype(src, /mob/living/simple_animal/hostile/sabertooth/lion) && !istype(src, /mob/living/simple_animal/hostile/sabertooth/lion/gladiator))
					var/obj/item/stack/material/pelt/lionpelt/NP = new/obj/item/stack/material/pelt/lionpelt(get_turf(src))
					NP.amount = 3
				else if (istype(src, /mob/living/simple_animal/hostile/alligator))
					var/obj/item/stack/material/pelt/gatorpelt/NP = new/obj/item/stack/material/pelt/gatorpelt(get_turf(src))
					NP.amount = 3
				else if (istype(src, /mob/living/simple_animal/hostile/dinosaur/trex))
					var/obj/item/stack/material/pelt/lizardpelt/NP = new/obj/item/stack/material/pelt/lizardpelt(get_turf(src))
					NP.amount = 10
				else if (istype(src, /mob/living/simple_animal/hostile/dinosaur/velociraptor))
					var/obj/item/stack/material/pelt/lizardpelt/NP = new/obj/item/stack/material/pelt/lizardpelt(get_turf(src))
					NP.amount = 3
				else if (istype(src, /mob/living/simple_animal/pachy))
					var/obj/item/stack/material/pelt/lizardpelt/NP = new/obj/item/stack/material/pelt/lizardpelt(get_turf(src))
					NP.amount = 3
				else if (istype(src, /mob/living/simple_animal/hostile/dinosaur/compsognathus))
					var/obj/item/stack/material/pelt/lizardpelt/NP = new/obj/item/stack/material/pelt/lizardpelt(get_turf(src))
					NP.amount = 1
				else if (istype(src, /mob/living/simple_animal/sheep))
					var/obj/item/stack/material/pelt/sheeppelt/NP = new/obj/item/stack/material/pelt/sheeppelt(get_turf(src))
					NP.amount = 2
				else if (istype(src, /mob/living/simple_animal/goat))
					var/obj/item/stack/material/pelt/goatpelt/NP = new/obj/item/stack/material/pelt/goatpelt(get_turf(src))
					NP.amount = 2
				else if (istype(src, /mob/living/simple_animal/cattle/cow))
					var/obj/item/stack/material/pelt/cowpelt/NP = new/obj/item/stack/material/pelt/cowpelt(get_turf(src))
					NP.amount = 2
				else if (istype(src, /mob/living/simple_animal/cattle/bull))
					var/obj/item/stack/material/pelt/cowpelt/NP = new/obj/item/stack/material/pelt/cowpelt(get_turf(src))
					NP.amount = 3
				else if (istype(src, /mob/living/simple_animal/bison))
					var/obj/item/stack/material/pelt/bisonpelt/NP = new/obj/item/stack/material/pelt/bisonpelt(get_turf(src))
					NP.amount = 3
				else if (istype(src, /mob/living/simple_animal/bisonbull))
					var/obj/item/stack/material/pelt/bisonpelt/NP = new/obj/item/stack/material/pelt/bisonpelt(get_turf(src))
					NP.amount = 4
				else if (istype(user, /mob/living/human))
					var/mob/living/human/HM = user
					HM.adaptStat("medical", amt/3)
				else
					var/obj/item/stack/material/leather/leather = new/obj/item/stack/material/leather(get_turf(src))
					leather.name = "[name] leather"
					leather.amount = amt
				crush()
				qdel(src)
		else
			var/tgt = user.targeted_organ
			if (user.targeted_organ == "random")
				tgt = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
			O.attack(src, user, tgt)
	if (behaviour == "defends" || behaviour == "hunt" || behaviour == "hostile")
		if (stance == HOSTILE_STANCE_ATTACK && target_mob && target_mob != user)
			if (prob(75))
				target_mob = user
		else
			target_mob = user
		stance = HOSTILE_STANCE_ATTACK
		stance_step = 6
		..()
	else
		if (behaviour == "scared" || (behaviour == "wander" && mob_size < user.mob_size))
			do_behaviour("scared")
		else if (behaviour == "wander")
			do_behaviour("defends")
		..()

/mob/living/simple_animal/hit_with_weapon(obj/item/O, mob/living/user, var/effective_force, var/hit_zone)

	visible_message("<span class='danger'>\The [src] has been attacked with \the [O] by [user].</span>")

	if (O.force <= resistance)
		to_chat(user, SPAN_DANGER("This weapon is ineffective, it does no damage."))
		return 2

	var/damage = O.force
	if (O.damtype == HALLOSS)
		damage = FALSE

	adjustBruteLoss(damage)

	return FALSE

/mob/living/simple_animal/movement_delay()
	var/tally = FALSE //Incase I need to add stuff other than "speed" later

	tally = speed

	return tally

/mob/living/simple_animal/Stat()
	..()

	if ((client.add_stat_tab("Status") || client.statpanel_tab == "Status") && show_stat_health)
		client.add_stat(null, "Health: [round((health / maxHealth) * 100)]%")

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

	walk(src,0) // stops movement
	unregisterSpawner()
	delayed_decay(src,3000)
	return ..(gibbed,deathmessage)

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

/mob/living/simple_animal/say(var/message, var/datum/language/language = null)
	var/verb = "says"
	if (speak_emote.len)
		verb = pick(speak_emote)

	message = sanitize(message)
	if(!isemptylist(wandersounds))
		playsound(src, pick(wandersounds), 60)

	..(message, language, verb)

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
		to_chat(usr, "This animal is not leashed.")
		return
	else if (istype(following_mob, /obj/structure/grille/fence) || istype(following_mob, /obj/structure/barricade/wood_pole))
		following_mob = null
		new/obj/item/weapon/leash(src.loc)
		to_chat(usr, "You free the [src].")
		stop_automated_movement = FALSE

		return
	else
		following_mob = null
		new/obj/item/weapon/leash(src.loc)
		to_chat(usr, "You free the [src].")
		stop_automated_movement = FALSE

		return

/mob/living/simple_animal/handle_mutations_and_radiation()
	if (z == world.maxz)
		rad_act((global_radiation/1000))
	if (radiation < 0)
		radiation = 0
	if(radiation > 0)
		radiation -= 0.05
		if(radiation >= 80 && radiation <= 100) //"Safe" Mutation/Radiation amount. Low Chance.
			if(prob(1))
				mutate()
		else if(radiation >= 100 && radiation <= 150) //Unsafe levels of radiation, Higher chance.
			adjustBurnLoss(radiation*0.002)
			updatehealth()
			if(prob(5))
				mutate()
		else if(radiation >= 150 && radiation <= 200) //Very unsafe levels of radiation.
			adjustBurnLoss(radiation*0.004)
			updatehealth()
			if(prob(15))
				mutate()
		else if(radiation >= 200) //How is it still even alive!?!?
			adjustBurnLoss(radiation*0.006)
			updatehealth()
			if(prob(25))
				mutate()
		else
			return

/mob/living/simple_animal/proc/mutate()
	if(mutation_variants == null)
		return

#undef GRAIN
