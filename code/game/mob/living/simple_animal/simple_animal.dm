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
	var/targeting = FALSE // If TRUE, uses A* waypoint navigation toward pathfind_target. Only for specific mob types.

	// Pathfinding vars (used by do_movement / get_path in code/pathfinding.dm)
	var/moving = FALSE
	var/atom/target_obj = null
	var/list/found_path = list()
	var/atom/pathfind_target = null
	var/last_pathfound = 0
	var/move_gen = 0

	//Interaction
	var/response_help   = "tries to help"
	var/response_disarm = "tries to disarm"
	var/response_harm   = "tries to hurt"
	var/harm_intent_damage = 3
	// Explicit species opt-in; peaceful animals never acquire a pursuit target.
	var/defensive_retaliation = FALSE

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

// Invalidate deferred work at the mutation, even if the link later returns to
// its old value between worker checks. Save restoration has no pending worker.
/mob/living/simple_animal/proc/npc_set_following(atom/new_following)
	if (src.following_mob != new_following)
		src.npc_subtile_pending_intent = null
	src.following_mob = new_following

/mob/living/simple_animal/proc/npc_set_combat_target(atom/new_target)
	if (src.target_mob != new_target)
		src.npc_subtile_pending_intent = null
	src.target_mob = new_target

/mob/living/simple_animal/New()
	..()
	verbs -= /mob/verb/observe
	if (map)
		if (map.chad_mode)
			melee_damage_lower *= 1.5
			melee_damage_upper *= 1.5
/mob/living/simple_animal/Login()
	npc_subtile_pending_intent = null
	if (src && client)
		client.screen = null
	..()
	// Parent login rebuilds the HUD after saved actions were already granted.
	update_action_buttons()

/mob/living/simple_animal/adjustBruteLoss(var/amount)
	. = ..()
	updatehealth()

/mob/living/simple_animal/Life()
	..()
	if (npc_subtile_pending_intent && (client || stat))
		npc_subtile_pending_intent = null
	if (loc == null)
		spawn(10)
			if (loc == null)
				qdel(src)
	//Health
	if (stat == DEAD)
		if (health > 0)
			icon_state = icon_living
			dead_mob_list -= src
			register_living_mob(src)
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
	if (npc_subtile_recovery_enabled)
		npc_subtile_prune_pending()
		npc_subtile_dispatch_pending()
		npc_subtile_request_recovery()

	if (following_mob)
		stop_automated_movement = TRUE
		if (get_dist(src, following_mob) > 2)
			turns_since_move++
			if (turns_since_move >= move_to_delay)
				if (get_dist(src, following_mob) > 1)
					if (npc_subtile_follow_enabled)
						npc_subtile_start_follow(following_mob)
					else
						walk_to(src, following_mob, 1, 6)
					turns_since_move = FALSE
		if (get_dist(src, following_mob) > 6)
			npc_set_following(null)
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

	var/shield_check = check_shields(proj.damage*5, proj, null, null, "the [proj.name]")
	if (shield_check)
		proj.blockedhit = TRUE
		if (shield_check < 0)
			return shield_check
		else
			proj.on_hit(src, 2)
			return 2

	if (!proj || proj.nodamage)
		if (proj)
			proj.on_hit(src, FALSE)
		return FALSE

	if (proj.firer)
		lastattacker = proj.firer

	adjustBruteLoss(proj.damage)
	proj.on_hit(src, FALSE)
	return FALSE

/mob/living/var/tmp/next_animal_retaliation = 0

/mob/living/simple_animal/proc/uses_defensive_retaliation()
	return defensive_retaliation && (behaviour == "wander" || behaviour == "defends")

// One immediate, zero-damage shove. Weaken is measured in Life updates, not ds.
// Both participants share a ten-second deadline, preventing herd stun chains too.
/mob/living/simple_animal/proc/try_defensive_retaliation(mob/living/attacker)
	if (!uses_defensive_retaliation() || QDELETED(src) || stat != CONSCIOUS || health <= 0 || incapacitated() || lying || prone || resting || buckled || !canmove || !isturf(loc))
		return FALSE
	if (!istype(attacker) || attacker == src || QDELETED(attacker) || attacker.stat != CONSCIOUS || attacker.health <= 0 || !isturf(attacker.loc) || !Adjacent(attacker))
		return FALSE
	if (behaviour == "wander" && mob_size < attacker.mob_size)
		return FALSE
	if (!(attacker.status_flags & CANWEAKEN) || attacker.incapacitated() || attacker.lying || attacker.prone || attacker.buckled)
		return FALSE
	if (world.time < next_animal_retaliation || world.time < attacker.next_animal_retaliation)
		return FALSE
	next_animal_retaliation = world.time + 10 SECONDS
	attacker.next_animal_retaliation = world.time + 10 SECONDS
	attacker.Weaken(2)
	attacker.drop_from_inventory(attacker.get_active_hand())
	visible_message(SPAN_WARNING("\The [src] knocks [attacker] off balance!"))
	do_attack_animation(attacker)
	return TRUE

/mob/living/simple_animal/attack_hand(mob/living/human/M as mob)
	..()
	if (M)
		lastattacker = M
	if (istype(src, /mob/living/simple_animal/hostile/human/voyage/pirate/friendly))
		faction = CIVILIAN
		behaviour = "hostile"
	if (behaviour == "hunt" || behaviour == "hostile")
		if (stance == HOSTILE_STANCE_ATTACK && target_mob && target_mob != M)
			if (prob(75))
				npc_set_combat_target(M)
		else
			npc_set_combat_target(M)
		stance = HOSTILE_STANCE_ATTACK
		stance_step = 6
	else if (behaviour == "scared")
		do_behaviour("scared")

	switch(M.a_intent)

		if (I_HELP)
			if (health > 0)
				if (istype(src, /mob/living/simple_animal/pet/dog))
					if (prob(30))
						M.visible_message("<span class = 'notice'>[M] tells \the [src] that he is a good boy!</span>")
					else
						M.visible_message("<span class = 'notice'>[M] pats \the [src]'s head!</span>")
				else
					M.visible_message("<span class = 'notice'>[M] [response_help] \the [src].</span>")

		if (I_DISARM)
			if (behaviour == "defends" && !uses_defensive_retaliation())
				if (stance == HOSTILE_STANCE_ATTACK && target_mob && target_mob != M)
					if (prob(75))
						npc_set_combat_target(M)
				else
					npc_set_combat_target(M)
				stance = HOSTILE_STANCE_ATTACK
				stance_step = 6
			M.visible_message("<span class = 'notice'>[M] [response_disarm] \the [src].</span>")
			M.do_attack_animation(src)
			playsound(get_turf(M), 'sound/weapons/punchmiss.ogg', 50, TRUE, -1)
			//TODO: Push the mob away or something

		if (I_GRAB)
			if (behaviour == "defends" && !uses_defensive_retaliation())
				if (stance == HOSTILE_STANCE_ATTACK && target_mob && target_mob != M)
					if (prob(75))
						npc_set_combat_target(M)
				else
					npc_set_combat_target(M)
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
			if (behaviour == "defends" && !uses_defensive_retaliation())
				if (stance == HOSTILE_STANCE_ATTACK && target_mob && target_mob != M)
					if (prob(75))
						npc_set_combat_target(M)
				else
					npc_set_combat_target(M)
				stance = HOSTILE_STANCE_ATTACK
				stance_step = 6
			adjustBruteLoss(harm_intent_damage*M.getStatCoeff("strength"))
			M.visible_message("<span class = 'red'>[M] [response_harm] \the [src].</span>")
			M.do_attack_animation(src)
			playsound(get_turf(M), "punch", 50, TRUE, -1)

	if (M.a_intent == I_HARM || M.a_intent == I_DISARM || M.a_intent == I_GRAB)
		try_defensive_retaliation(M)
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

/mob/living/simple_animal/pet
	var/turns_since_scan = FALSE
	var/mob/living/simple_animal/mouse/movement_target
	var/mob/flee_target
	var/flee_message = "HSSSSS"

/mob/living/simple_animal/pet/proc/npc_set_movement_target(atom/new_target)
	if (src.movement_target != new_target && src.npc_subtile_pending_intent && src.npc_subtile_pending_intent.kind == "pet" && src.npc_subtile_pending_intent.mode == "towards")
		src.npc_subtile_pending_intent = null
	src.movement_target = new_target

/mob/living/simple_animal/pet/proc/npc_set_flee_target(atom/new_target)
	if (src.flee_target != new_target && src.npc_subtile_pending_intent && src.npc_subtile_pending_intent.kind == "pet" && src.npc_subtile_pending_intent.mode == "away")
		src.npc_subtile_pending_intent = null
	src.flee_target = new_target

/mob/living/simple_animal/pet/proc/handle_movement_target()
	if ((movement_target) && !(isturf(movement_target.loc) || ishuman(movement_target.loc)))
		npc_set_movement_target(null)
		stop_automated_movement = FALSE
	if (!movement_target || !(movement_target.loc in oview(src, 4)))
		npc_set_movement_target(null)
		stop_automated_movement = FALSE
		for (var/mob/living/simple_animal/mouse/snack in oview(src))
			if (isturf(snack.loc) && !snack.stat)
				npc_set_movement_target(snack)
				break
	if (movement_target)
		stop_automated_movement = TRUE
		if (npc_subtile_pet_enabled)
			npc_subtile_start_pet_walk(movement_target, "towards", 0, npc_subtile_native_interval(3))
		else
			walk_to(src, movement_target, 0, 3)

/mob/living/simple_animal/pet/proc/handle_flee_target()
	if (flee_target && !(flee_target.loc in view(src)))
		npc_set_flee_target(null)
		stop_automated_movement = FALSE
	if (flee_target)
		if (prob(25)) say(flee_message)
		stop_automated_movement = TRUE
		if (npc_subtile_pet_enabled)
			npc_subtile_start_pet_walk(flee_target, "away", 7, npc_subtile_native_interval(2))
		else
			walk_away_od(src, flee_target, 7, 2)

/mob/living/simple_animal/pet/proc/set_flee_target(atom/A)
	if (A)
		npc_set_flee_target(A)
		turns_since_scan = 5

/mob/living/simple_animal/pet/attackby(var/obj/item/O, var/mob/user)
	. = ..()
	if (O.force)
		set_flee_target(user ? user : loc)

/mob/living/simple_animal/pet/attack_hand(mob/living/human/M as mob)
	. = ..()
	if (M.a_intent == I_HARM)
		set_flee_target(M)

/mob/living/simple_animal/pet/ex_act()
	. = ..()
	set_flee_target(loc)

/mob/living/simple_animal/pet/bullet_act(var/obj/item/projectile/proj)
	. = ..()
	set_flee_target(proj.firer ? proj.firer : loc)

/mob/living/simple_animal/pet/hitby(atom/movable/AM)
	. = ..()
	set_flee_target(AM.thrower ? AM.thrower : loc)

/mob/living/simple_animal/proc/try_infect(var/mob/living/human/target, base_chance, disease_name, check_strong_immune = TRUE)
	if (!target || !istype(target))
		return FALSE
	var/dmod = 1
	if (target.find_trait("Weak Immune System"))
		dmod = 2
	if (check_strong_immune && target.find_trait("Strong Immune System"))
		dmod = 0.2
	if (prob(base_chance * dmod))
		target.disease = TRUE
		target.disease_type = disease_name
		return TRUE
	return FALSE

/mob/living/simple_animal/proc/butcher_yield(var/mob/living/simple_animal/target)
	var/mob_size_to_check = target ? target.mob_size : src.mob_size
	switch(mob_size_to_check)
		if (MOB_MINISCULE)
			return 1
		if (MOB_TINY)
			return 2
		if (MOB_SMALL)
			return 3
		if (MOB_MEDIUM)
			return 4
		if (MOB_LARGE)
			return 5
		if (MOB_HUGE)
			return 8
	return 1

/mob/living/simple_animal/attackby(var/obj/item/O, var/mob/user)
	var/attack_result = FALSE
	var/health_before_attack = health
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
			L.S2.npc_set_following(L.S1)
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
			attack_result = O.attack(src, user, tgt)
	else if (O.sharp && !istype(src, /mob/living/simple_animal/hostage))
		if (!istype(O, /obj/item/weapon/reagent_containers) && stat == DEAD && (user.a_intent == I_HARM || user.a_intent == I_GRAB))
			harvest_animal(user, O, user.a_intent == I_GRAB)
			return
		else
			var/tgt = user.targeted_organ
			if (user.targeted_organ == "random")
				tgt = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
			attack_result = O.attack(src, user, tgt)
	if (uses_defensive_retaliation() && (behaviour == "defends" || mob_size >= user.mob_size))
		// Healing, food, husbandry and harmless taps must not provoke a shove.
		if (health < health_before_attack)
			try_defensive_retaliation(user)
		return attack_result
	if (behaviour == "defends" || behaviour == "hunt" || behaviour == "hostile")
		if (stance == HOSTILE_STANCE_ATTACK && target_mob && target_mob != user)
			if (prob(75))
				npc_set_combat_target(user)
		else
			npc_set_combat_target(user)
		stance = HOSTILE_STANCE_ATTACK
		stance_step = 6
	else
		if (behaviour == "scared" || (behaviour == "wander" && mob_size < user.mob_size))
			do_behaviour("scared")
		else if (behaviour == "wander")
			do_behaviour("defends")
	// Explicit attacks above already invoke item damage, logs and wear once.
	if (O.sharp && istype(src, /mob/living/simple_animal/hostage))
		return ..()
	return attack_result

/mob/living/simple_animal/hit_with_weapon(obj/item/O, mob/living/user, var/effective_force, var/hit_zone)

	if (check_shields(effective_force, O, user, hit_zone, "the [O.name]"))
		return 0

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

/mob/living/simple_animal/proc/get_valid_move_dirs()
	var/list/valid = list()
	for (var/d in cardinal)
		var/turf/T = get_step(src, d)
		if (!T || T.density)
			continue
		if (istype(T, /turf/floor/beach/water/deep) && !T.iscovered() && !flying)
			continue
		if (istype(T, /turf/floor/broken_floor) && !T.iscovered())
			continue
		valid += d
	return valid

/mob/living/simple_animal/proc/smart_step_towards(atom/target)
	var/turf/next = get_step_towards2(src, target)
	if (isturf(next) && next != loc)
		return ai_step(next, move_to_delay)
	return FALSE

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
	// A native Move may never return to its DM wrapper after src is deleted.
	// Detach only the frame belonging to this actor; retire it without deleting
	// the datum while its collision callback could still be on the stack.
	var/datum/npc_subtile_large_frame/F = npc_subtile_large_frame
	if (F && F.actor == src)
		npc_subtile_large_frame = null
		F.retire()
	npc_subtile_pending_intent = null
	unregisterSpawner()
	..()

/mob/living/simple_animal/death(gibbed, deathmessage = "dies!")
	npc_subtile_pending_intent = null
	icon_state = icon_dead
	density = FALSE

	walk(src,0) // stops movement
	unregisterSpawner()
	delayed_decay(src,3000)

	if (istype(src, /mob/living/simple_animal/hostile) && lastattacker && ishuman(lastattacker))
		var/mob/living/human/H = lastattacker
		if (H.client && map && istype(map, /obj/map_metadata/wizard_boy))
			var/obj/map_metadata/wizard_boy/WB = map
			WB.record_npc_kill(H.client.ckey, src.name)
			if (WB.check_level(H.client.ckey) == "3")
				WB.change_level(H.client.ckey, "4")
				to_chat(world, "<font size=3 class='wizard'><b>[H.real_name]</b> ([H.key]) has progressed to qualification level 4 (<b>B.A.S.E.D.</b>) by slaying \a [src]!</font>")

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
	return W && W.persistence_set_loc(get_turf(src))

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
		npc_set_following(null)
		new/obj/item/weapon/leash(src.loc)
		to_chat(usr, "You free the [src].")
		stop_automated_movement = FALSE

		return
	else
		npc_set_following(null)
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
