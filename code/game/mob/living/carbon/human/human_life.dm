//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:32

//NOTE: Breathing happens once per FOUR TICKS, unless the last breath fails. In which case it happens once per ONE TICK! So oxyloss healing is done once per 4 ticks while oxyloss damage is applied once per tick!
#define HUMAN_MAX_OXYLOSS TRUE //Defines how much oxyloss humans can get per tick. A tile with no air at all (such as space) applies this value, otherwise it's a percentage of it.
#define HUMAN_CRIT_MAX_OXYLOSS ( 2.0 / 6) //The amount of damage you'll get when in critical condition. We want this to be a 5 minute deal = 300s. There are 50HP to get through, so (1/6)*last_tick_duration per second. Breaths however only happen every 4 ticks. last_tick_duration = ~2.0 on average

#define HEAT_DAMAGE_LEVEL_1 1 //Amount of damage applied when your body temperature just passes the 360.15k safety point
#define HEAT_DAMAGE_LEVEL_2 2 //Amount of damage applied when your body temperature passes the 400K point
#define HEAT_DAMAGE_LEVEL_3 4 //Amount of damage applied when your body temperature passes the 1000K point

#define COLD_DAMAGE_LEVEL_1 2 //Amount of damage applied when your body temperature just passes the 260.15k safety point
#define COLD_DAMAGE_LEVEL_2 4 //Amount of damage applied when your body temperature passes the 200K point
#define COLD_DAMAGE_LEVEL_3 8 //Amount of damage applied when your body temperature passes the 120K point
/*
//Note that gas heat damage is only applied once every FOUR ticks.
#define HEAT_GAS_DAMAGE_LEVEL_1 2 //Amount of damage applied when the current breath's temperature just passes the 360.15k safety point
#define HEAT_GAS_DAMAGE_LEVEL_2 4 //Amount of damage applied when the current breath's temperature passes the 400K point
#define HEAT_GAS_DAMAGE_LEVEL_3 8 //Amount of damage applied when the current breath's temperature passes the 1000K point

#define COLD_GAS_DAMAGE_LEVEL_1 0.5 //Amount of damage applied when the current breath's temperature just passes the 260.15k safety point
#define COLD_GAS_DAMAGE_LEVEL_2 1.5 //Amount of damage applied when the current breath's temperature passes the 200K point
#define COLD_GAS_DAMAGE_LEVEL_3 3 //Amount of damage applied when the current breath's temperature passes the 120K point
*/


//#define RADIATION_SPEED_COEFFICIENT 0.1

/mob/living/human
	var/global/list/overlays_cache = null
	var/heatDamageFromClothingTimer = 0
	var/start_to_rot = FALSE
	var/rotting_stage = 0

	var/healing_stage = 0 //for beds
/mob/living/human/Life()

	handle_look_stuff()
	if (map && !map.civilizations && !map.nomads && !map.is_RP)
		process_awards()
	if (transforming)
		return
	if (werewolf + gorillaman + orc +goblin + ant + lizard + wolfman + crab > 1)
		werewolf = 0
		gorillaman = 0
		orc = 0
		goblin = 0
		ant = 0
		lizard = 0
		wolfman = 0
		crab = 0
		handle_animalistic("Default")

	if (werewolf)
		handle_animalistic("Werewolf")
	else if (gorillaman)
		handle_animalistic("Gorilla")
	else if (orc)
		handle_animalistic("Orc")
	else if (goblin)
		handle_animalistic("Goblin")
	else if (ant)
		handle_animalistic("Ant")
	else if (lizard)
		handle_animalistic("Lizard")
	else if (wolfman)
		handle_animalistic("Wolf")
	else if (crab)
		handle_animalistic("Crab")
	else if (!gorillaman && !werewolf && !orc && !goblin && !ant && !lizard && !wolfman && !crab && body_build.name != "Default")
		handle_animalistic("Default")
//	if (prone)
//		lying = 1
	if (lying || stat < CONSCIOUS || prone)
		layer = MOB_LAYER - 0.01
	else
		layer = MOB_LAYER

	//TODO: seperate this out
	// update the current life tick, can be used to e.g. only do something every 4 ticks
	life_tick++
	if (map && map.nomads)
		if (find_trait("Gigantism"))
			size_multiplier = 1.3
		else if (find_trait("Dwarfism"))
			size_multiplier = 0.8
		else if (find_trait("Short"))
			size_multiplier = 0.9
		else if (find_trait("Tall"))
			size_multiplier = 1.1
	if (riding && riding_mob)
		if (!(riding_mob in range(1,src)))
			riding = FALSE
			riding_mob = null
			var/mob/living/human/H = src
			forceMove(H.loc)
			if (riding_mob)
				riding_mob.ride = FALSE
				riding_mob.rider = null
				riding_mob.update_icons()
				riding_mob.stop_automated_movement = FALSE

	// handle nutrition stuff before we handle stomach stuff in the callback

/*
	var/area/currentarea = get_area(src)
	if (istype(currentarea, /area/caribbean/no_mans_land/invisible_wall))
		if (faction_text == map.faction1 && !map.faction1_can_cross_blocks())
			gib()
		else if (faction_text == map.faction2 && !map.faction2_can_cross_blocks())
			gib()
*/
	if (mood > 100)
		mood = 100
	else if (mood < 0)
		mood = 0
	if(istype(buckled, /obj/structure/cross))
		if (stats["stamina"][1] > 0)
			stats["stamina"][1]-=3

	#define HUNGER_THIRST_MULTIPLIER 0.32 //was 0.32, doubled due to demand - reverted 20/01
	if (stat != DEAD && !map.civilizations)
		ssd_hiding(config.ssd_invisibility_timer) //makes SSD players invisible after a while
	if (istype(buckled, /obj/structure/bed) || istype(buckled, /obj/structure/optable))
		healing_stage += 2

	else if (istype(buckled, /obj/structure/medicalbed))
		healing_stage += 0.5
	else
		healing_stage = 0
	if (healing_stage >= 30 && (istype(buckled, /obj/structure/bed) || istype(buckled, /obj/structure/optable) || istype(buckled, /obj/structure/medicalbed)))
		if (istype(buckled, /obj/structure/medicalbed))
			rejuvenate()
			src << "You feel much better."
		healing_stage = 0
		if (getBruteLoss() >= 15)
			adjustBruteLoss(-2)
			if (halloss > 40)
				adjustHalLoss(-30)
	if (map && map.ID == MAP_FOOTBALL && (r_hand || l_hand))
		var/area/A = get_area(loc)
		if (!istype(A, /area/caribbean/football/red/goalkeeper) && !istype(A, /area/caribbean/football/blue/goalkeeper))
			if (istype(l_hand, /obj/item/football))
				drop_from_inventory(l_hand, loc, TRUE)
				drop_item()
			if (istype(r_hand, /obj/item/football))
				drop_from_inventory(r_hand, loc, TRUE)
				drop_item()
	if (map && map.ID == MAP_FOOTBALL_CAMPAIGN && (r_hand || l_hand))
		var/area/A = get_area(loc)
		if (!istype(A, /area/caribbean/football/red/goalkeeper) && !istype(A, /area/caribbean/football/blue/goalkeeper))
			if (istype(l_hand, /obj/item/football))
				drop_from_inventory(l_hand, loc, TRUE)
				drop_item()
			if (istype(r_hand, /obj/item/football))
				drop_from_inventory(r_hand, loc, TRUE)
				drop_item()
	// fixes invisibility while alive (from ssd?)
	if (invisibility == 101)
		invisibility = 0
	if (has_hunger_and_thirst && (map.civilizations || map.nomads || map.has_hunger))
		var/water_m = 1
		var/food_m = 1
		if (find_trait("Gigantism"))
			food_m *= 1.4
		else if (find_trait("Dwarfism"))
			food_m *= 0.8
		if (orc)
			food_m *= 1.5
		if (goblin)
			food_m *= 0.8
			water_m *= 1.0
		if (crab)
			food_m *= 0.8
			water_m *= 2.5
		if (gorillaman)
			water_m *= 0.2
		if (istype(buckled, /obj/structure/cross))
			food_m *= 1.5
			water_m *= 5

		if (inducedSSD) //if sleeping in SSD mode = takes ~72 hours to starve
			nutrition -= ((0.0025) * HUNGER_THIRST_MULTIPLIER * food_m)
			water -= ((0.0025) * HUNGER_THIRST_MULTIPLIER * water_m)

		else if (istype(buckled, /obj/structure/bed) && stat == UNCONSCIOUS && !inducedSSD) //if sleeping in a bed (buckled!) takes ~20 hours to starve
			nutrition -= ((0.01) * HUNGER_THIRST_MULTIPLIER * food_m)
			water -= ((0.01) * HUNGER_THIRST_MULTIPLIER * water_m)

		else if (map.heat_wave || map.ID == MAP_NOMADS_DESERT)
			switch (stat)
				if (CONSCIOUS) // takes about 1333 ticks to start starving, or ~44 minutes
					nutrition -= ((0.27) * HUNGER_THIRST_MULTIPLIER * food_m)
					water -= ((0.7) * HUNGER_THIRST_MULTIPLIER * water_m)
				if (UNCONSCIOUS) // takes over an hour to starve
					nutrition -= ((0.27) * HUNGER_THIRST_MULTIPLIER * food_m)
					water -= ((0.7) * HUNGER_THIRST_MULTIPLIER * water_m)
		else
			switch (stat)
				if (CONSCIOUS) // takes about 1333 ticks to start starving, or ~44 minutes
					nutrition -= ((0.27) * HUNGER_THIRST_MULTIPLIER * food_m)
					water -= ((0.27) * HUNGER_THIRST_MULTIPLIER * water_m)
				if (UNCONSCIOUS) // takes over an hour to starve
					nutrition -= ((0.27) * HUNGER_THIRST_MULTIPLIER * food_m)
					water -= ((0.27) * HUNGER_THIRST_MULTIPLIER * water_m)
		if (find_trait("Extroverted"))
			if (prob(20))
				var/ct = 0
				for(var/mob/living/human/HM in range(3,src))
					if (HM.stat != DEAD)
						ct++
				if (ct)
					mood += 0.12
				else
					mood -= 0.8
		else if (find_trait("Introverted"))
			if (prob(20))
				var/ct = 0
				for(var/mob/living/human/HM in range(3,src))
					if (HM.stat != DEAD)
						ct++
				if (!ct)
					mood += 0.12
				else
					mood -= 0.8
		if (!inducedSSD)
			mood -= 0.02
	#undef HUNGER_THIRST_MULTIPLIER
	if (stats && stats.len)
	// hotfixes some stamina bugs
		if (stats["stamina"][1] < 0)
			stats["stamina"][1] = 0

		if (stats["stamina"][2] < 80)
			stats["stamina"][2] = 80

		if (getStat("stamina") == getMaxStat("stamina")-1 && m_intent == "walk")
			src << "<span class = 'good'>You feel like you can run for a while.</span>"

	nutrition = min(nutrition, max_nutrition)
	nutrition = max(nutrition, -max_nutrition)

	water = min(water, max_water)
	water = max(water, -max_water)

	// make us die very slowly if we're unconscious, but recover oxyloss if we're conscious
	switch (stat)
		if (CONSCIOUS)
			adjustOxyLoss(-5)

//drug addictions
	for(var/ad in addictions)
		if (addictions[ad]>0)
			var/ind = addictions[ad]
			process_addictions(ad,ind)
			addictions[ad] -= 0.05
		if (addictions[ad] < 0)
			addictions[ad] = 0

//death
	if (getBrainLoss() > 60 || getTotalDmg() > 150)
		death()

// disease stuff
	if (inducedSSD && disease && disease_progression <= 15)
		disease = 0
		disease_type = "none"
		disease_progression = 0
		bodytemperature = 310.055
		disease_treatment = 0

	if (disease == TRUE)
		if (disease_type == "none")
			disease = FALSE
		else if (disease_type == "plague")
			mood -= 0.25
			if (disease_progression == 1 || disease_progression == 90 || disease_progression == 180)
				update_surgery(1)
			disease_progression += 0.5
			// first 3 minutes
			if (prob(7))
				src << "You feel painful lumps on your skin."
				adjustToxLoss(rand(8,12))
			//3 more minutes
			else if (disease_progression >= 90 && prob(10) && stat != DEAD)
				vomit_blood()
			// 3 more minutes
			else if (disease_progression >= 180 && disease_progression <= 300 && prob(15))
				adjustBrainLoss(rand(3,5))
				src << "You feel your body burning up from fever!"
				Weaken(5)
				bodytemperature = 313.15
			// 4 more minutes
			else if (disease_progression >= 360 && prob(35))
				disease = 0
				disease_type = "none"
				disease_progression = 0
				src << "You feel much better now! The disease is finally gone!"
				disease_immunity += "plague"
				disease_treatment = 0
				bodytemperature = 310.055
		else if (disease_type == "flu")
			mood -= 0.1
			if (!disease_treatment)
				disease_progression += 0.5
			else
				disease_progression += 2
			// first 2 minutes
			if (disease_progression == 25)
				src << "You feel a little feverish."
				disease_treatment = 0
				apply_effect(10, DROWSY, FALSE)
				bodytemperature = 311.35
			//4 more minutes
			if (prob(1))
				emote("sniff")
				apply_effect(5, DROWSY, FALSE)
			else if (disease_progression >= 60 && disease_progression < 180 && bodytemperature < 312.15 && prob(10))
				src << "You feel like your fever is getting worse!"
				apply_effect(5, AGONY, FALSE)
				apply_effect(5, DROWSY, FALSE)
				emote(pick("cough","sneeze"))
				bodytemperature = 312.15
			else if (disease_progression >= 60 && disease_progression < 180 && bodytemperature < 313.15 && prob(1))
				adjustBrainLoss(rand(7,10))
				src << "You feel your body burning up from fever!"
				apply_effect(10, AGONY, FALSE)
				apply_effect(5, DROWSY, FALSE)
				emote(pick("cough","sneeze"))
				Weaken(5)
				bodytemperature = 313.15
			// 2 more minutes
			else if (disease_progression >= 180 && disease_progression < 240 && bodytemperature >= 313.15 && prob(8))
				src << "You feel your fever going down."
				apply_effect(5, DROWSY, FALSE)
				emote(pick("cough","sneeze"))
				bodytemperature = 312.35
			else if (disease_progression >= 180 && disease_progression < 240 && bodytemperature >= 312.15 && prob(2))
				src << "You feel your fever going down."
				emote(pick("cough","sneeze"))
				bodytemperature = 310.055
			else if (disease_progression >= 240 && prob(35))
				disease = 0
				disease_type = "none"
				disease_progression = 0
				bodytemperature = 310.055
				src << "You feel much better now! The disease is finally gone!"
				disease_treatment = 0
				if (prob(25))
					disease_immunity += "flu"

		else if (disease_type == "typhus")
			mood -= 0.2
			if (!disease_treatment)
				disease_progression += 0.5
			else
				disease_progression += 5
			// first 2 minutes
			if (disease_progression == 25)
				src << "You feel a little feverish."
				disease_treatment = 0
				apply_effect(10, DROWSY, FALSE)
				bodytemperature = 311.35
			//4 more minutes
			if (prob(1))
				if (prob(50))
					emote("cough")
					apply_effect(5, DROWSY, FALSE)
				else
					src << "Your muscles ache!"
					apply_effect(5, AGONY, FALSE)
			else if (disease_progression >= 60 && disease_progression < 180 && bodytemperature < 312.15 && prob(4))
				src << "You feel like your fever is getting worse!"
				apply_effect(5, AGONY, FALSE)
				apply_effect(5, DROWSY, FALSE)
				emote(pick("cough"))
				bodytemperature = 312.15
				adjustBrainLoss(1)
			else if (disease_progression >= 60 && disease_progression < 180 && bodytemperature < 313.15 && prob(1))
				src << "You feel very nauseous!"
				apply_effect(8, AGONY, FALSE)
				spawn(200)
					water -= 35
					vomit()
			// 2 more minutes
			else if (disease_progression >= 180 && disease_progression < 240 && bodytemperature >= 313.15 && prob(8))
				if (prob(50))
					src << "You feel your fever going down."
					apply_effect(5, DROWSY, FALSE)
					emote(pick("cough"))
					bodytemperature = 312.35
				else
					src << "You feel nauseous!"
					apply_effect(5, AGONY, FALSE)
					spawn(200)
						water -= 12
						vomit()
			else if (disease_progression >= 180 && disease_progression < 240 && bodytemperature >= 312.15 && prob(2))
				if (!disease_treatment && prob(20))
					var/obj/item/organ/external/E = get_organ("groin")
					var/datum/wound/W = new /datum/wound/internal_bleeding(35, internal_organs_by_name["liver"])
					E.wounds += W
				src << "You feel your fever going down."
				emote(pick("cough"))
				bodytemperature = 310.055
			else if (disease_progression >= 240 && prob(35))
				disease = 0
				disease_type = "none"
				disease_progression = 0
				bodytemperature = 310.055
				src << "You feel much better now! The disease is finally gone!"
				disease_treatment = 0
				if (prob(25))
					disease_immunity += "typhus"

		else if (disease_type == "malaria")
			mood -= 0.17
			if (!disease_treatment)
				disease_progression += 0.5
			else
				disease_progression += 1.5
			// first 2 minutes
			if (disease_progression == 25)
				src << "You feel a little feverish."
				disease_treatment = 0
				apply_effect(10, DROWSY, FALSE)
				bodytemperature = 311.35
			//4 more minutes
			if (prob(1))
				emote("shiver")
				apply_effect(7, DROWSY, FALSE)
			else if (disease_progression >= 60 && disease_progression < 180 && bodytemperature < 312.15 && prob(10))
				src << "You feel like your fever is getting worse!"
				adjustBrainLoss(rand(2,3))
				apply_effect(8, AGONY, FALSE)
				apply_effect(6, DROWSY, FALSE)
				if (prob(75))
					spawn(200)
						vomit()
				emote("shiver")
				bodytemperature = 312.15
			else if (disease_progression >= 60 && disease_progression < 180 && bodytemperature < 313.15 && prob(1) && !disease_treatment)
				adjustBrainLoss(rand(7,10))
				src << "You feel your body burning up from fever!"
				apply_effect(12, AGONY, FALSE)
				apply_effect(7, DROWSY, FALSE)
				spawn(200)
					vomit()
				emote("shiver")
				Weaken(5)
				bodytemperature = 313.15
			// 2 more minutes
			else if (disease_progression >= 180 && disease_progression < 240 && bodytemperature >= 313.15 && prob(8) && !disease_treatment)
				src << "You feel your fever going down."
				adjustBrainLoss(rand(4,6))
				apply_effect(6, DROWSY, FALSE)
				emote("shiver")
				bodytemperature = 312.35
			else if (disease_progression >= 180 && disease_progression < 240 && bodytemperature >= 312.15 && prob(2))
				src << "You feel your fever going down."
				adjustBrainLoss(rand(2,3))
				emote("shiver")
				bodytemperature = 310.055
			else if (disease_progression >= 240 && prob(35))
				disease = 0
				disease_type = "none"
				disease_progression = 0
				bodytemperature = 310.055
				src << "You feel much better now! The disease is finally gone!"
				disease_treatment = 0

		else if (disease_type == "cholera")
			mood -= 0.15
			if (!disease_treatment)
				disease_progression += 0.5
			else
				disease_progression += 1.5
			// first 3 minutes
			if (disease_progression == 90)
				src << "You feel nauseous."
				disease_treatment = 0
				apply_effect(5, AGONY, FALSE)
			//5 more minutes
			if (prob(1))
				emote("shiver")
				apply_effect(7, DROWSY, FALSE)
			else if (disease_progression >= 90 && disease_progression < 240 && prob(10))
				src << "You feel very nauseous!"
				apply_effect(8, AGONY, FALSE)
				spawn(200)
					water -= 55
					vomit()
				custom_emote(1, "looks very dehydrated.")
				if (prob(40))
					apply_effect(4, WEAKEN, FALSE)
			// 2 more minutes
			else if (disease_progression >= 240 && prob(35))
				disease = 0
				disease_type = "none"
				disease_progression = 0
				bodytemperature = 310.055
				src << "You feel much better now! The disease is finally gone!"
				disease_treatment = 0
		else if (disease_type == "zombie")
			mood -= 0.15
			if (!disease_treatment)
				disease_progression += 0.5
			else
				disease = 0
				disease_type = "none"
				disease_progression = 0
				bodytemperature = 310.055
				src << "You feel much better now! The disease is finally gone!"
				disease_treatment = 0

			if (disease_progression == 25)
				src << "You feel your temperature rising."
				apply_effect(10, DROWSY, FALSE)
				bodytemperature = 311.35
			if (prob(1))
				apply_effect(7, DROWSY, FALSE)
			else if (disease_progression >= 60 && disease_progression < 140 && prob(10))
				src << pick("You feel like your fever is getting worse!","Your head hurts so much!")
				adjustBrainLoss(rand(2,3))
				apply_effect(8, AGONY, FALSE)
				bodytemperature = 313.15
			else if (disease_progression >= 140 && disease_progression < 200 && prob(1) && !disease_treatment)
				adjustBrainLoss(rand(7,10))
				src << "<big>[pick("You feel your body burning up!","Your head is pounding!")]</big>"
				apply_effect(12, AGONY, FALSE)
				bodytemperature = 314.15

			else if (disease_progression >= 200 && disease_progression < 240 && prob(8) && !disease_treatment)
				src << "You feel your fever going down."
				adjustBrainLoss(rand(4,6))
				apply_effect(6, DROWSY, FALSE)
				bodytemperature = 313.35
			else if (disease_progression >= 240 && prob(50) && !istype(get_area(src), /area/caribbean/admin))
				adjustBrainLoss(200)
				var/mob/living/simple_animal/hostile/human/zombie/playerzombie //make a var for the zombie
				playerzombie = new /mob/living/simple_animal/hostile/human/zombie/ //make a zombie!
				visible_message("<big>[src] turns into a zombie!</big>")
				//transferring vars.
				playerzombie.loc = loc
				playerzombie.name = "[real_name]'s zombie"
				strip()


	if (disease == TRUE)
		if (disease_type in disease_immunity)
			disease = FALSE
			disease_type = "none"
			disease_progression = 0
			disease_treatment = 0

		for (var/mob/living/human/H in range(2,src))
			if (H.disease == TRUE && !(H.disease_type in disease_immunity) && !H.disease_type == "malaria" && !H.disease_type == "zombie") //malaria doesn't transmit from person to person.
				if (H.stat != DEAD)
					if (prob(1) || (prob(2) && find_trait("Weak Immune System")))
						if ((prob(50) && istype(wear_mask, /obj/item/clothing/mask/sterile)) || !istype(wear_mask, /obj/item/clothing/mask/sterile))
							if ((H.disease_type == "flu" && !istype(H.wear_mask, /obj/item/clothing/mask/sterile)) || H.disease_type != "flu")
								disease = TRUE
								disease_type = H.disease_type
								disease_progression = 0
								disease_treatment = 0
				else if (H.stat == DEAD)
					if (prob(3) || (prob(6) && find_trait("Weak Immune System")))
						if ((prob(50) && istype(wear_mask, /obj/item/clothing/mask/sterile)) || !istype(wear_mask, /obj/item/clothing/mask/sterile))
							disease = TRUE
							disease_type = H.disease_type
							disease_progression = 0
							disease_treatment = 0

	else if (disease == FALSE)
		if (prob(1) && map.civilizations)
			if ((prob(20) || (prob(40) && find_trait("Weak Immune System"))) && !inducedSSD && hygiene < HYGIENE_LEVEL_DIRTY && !("flu" in disease_immunity))
				disease = TRUE
				disease_type = "flu"
				disease_progression = 0
				disease_treatment = 0

	//shitcode to fix the movement bug because byond hates me
	if (grab_list.len)
		if (grab_list[1] == null)
			grab_list = list()
	..()

	// recover stamina
	stats["stamina"][1] = min(stats["stamina"][1] + round(stats["stamina"][2] * 0.02), stats["stamina"][2])

	voice = GetVoice()

	//No need to update all of these procs if the guy is dead.
	if (stat != DEAD)
		// Organs and blood
		handle_organs()

		// Stop processing organs that aren't bad
		for (var/obj/item/organ/external/E in bad_external_organs)
			if (E.brute_dam == 0 && E.burn_dam == 0)
				E.wounds.Cut()
				bad_external_organs -= E

		handle_drowning()

		handle_blood()

		stabilize_body_temperature()

		handle_shock()

		handle_pain()

		if (!inducedSSD)
			handle_excrement()
			if (map.civilizations || map.ID == MAP_COLONY || map.ID == MAP_JUNGLE_COLONY || map.ID == MAP_GULAG13)
				handle_hygiene()
			handle_mood()
			handle_ptsd()
		if (!map.civilizations && map.ID != MAP_COLONY && map.ID != MAP_JUNGLE_COLONY)
			bowels = 0
			bladder = 0
		handle_medical_side_effects()
		if (map.civilizations)
			handle_hair_growth()

		if (original_job && base_faction)
			faction_hud_users |= src
			process_faction_hud(src)

		if (!client)
			species.handle_npc(src)
	else if (stat == DEAD)
		handle_defib_timer()
	process_roofs()
	process_static_roofs()
	if (!handle_some_updates())
		return											//We go ahead and process them 5 times for HUD images and other stuff though.

	//Update our name based on whether our face is obscured/disfigured
	name = get_visible_name()

/mob/living/human/proc/handle_hair_growth() //hair will increase in size every ~16.666 mins
	if (gender == MALE)
		var/currh = h_growth
		var/currf = f_growth
		if (h_growth < 4 && !find_trait("Baldness"))
			h_growth += 0.002
		if (f_growth < 4)
			f_growth += 0.002
		if (find_trait("Baldness"))
			h_growth = 0
			h_style = "Bald"
		else
			if (h_growth >= 1 && currh < 1)
				h_style = pick("Short Hair","Cut Hair","Skinhead")
			else if (h_growth >= 2 && currh < 2)
				h_style = pick("Parted","Bedhead","Bedhead 2","Bedhead 3","Mulder")
			else if (h_growth >= 3 && currh < 3)
				h_style = pick("Shoulder-length Hair","Dreadlocks","Long Emo","Gentle")
			else if (h_growth >= 4 && currh < 4)
				h_style = "Hime Cut"

		if (f_growth >= 1 && currf < 1)
			f_style = "Chinstrap"
		else if (f_growth >= 2 && currf < 2)
			f_style = "Medium Beard"
		else if (f_growth >= 3 && currf < 3)
			f_style = pick("Long Beard","Full Beard")
		else if (f_growth >= 4 && currf < 4)
			f_style = "Very Long Beard"
		update_hair()

	else if (gender == FEMALE)
		var/currh = h_growth
		if (h_growth < 4)
			h_growth += 0.002
		if (h_growth >= 1 && currh < 1)
			h_style = pick("Short Hair")
		else if (h_growth >= 2 && currh < 2)
			h_style = pick("Bobcurl","Mia","Curls")
		else if (h_growth >= 3 && currh < 3)
			h_style = pick("Shoulder-length Hair","Flaired Hair","Ombre","Gentle")
		else if (h_growth >= 4 && currh < 4)
			h_style = pick("Long Hair","Long Hair Alt")
		update_hair()
	else
		return


/mob/living/human/proc/handle_some_updates()
	if (life_tick > 5 && timeofdeath && (timeofdeath < 5 || world.time - timeofdeath > 6000))	//We are long dead, or we're junk mobs spawned
		return FALSE
	return TRUE

/mob/living/human/handle_disabilities()
	..()
	//Vision
	var/obj/item/organ/vision
	if (species.vision_organ)
		vision = internal_organs_by_name[species.vision_organ]

	if (!species.vision_organ) // Presumably if a species has no vision organs, they see via some other means.
		eye_blind =  0
		blinded =	0
		eye_blurry = 0
	else if (!vision || (vision && vision.is_broken()) || istype(eyes,/obj/item/clothing/glasses/sunglasses/blindfold))   // Vision organs cut out or broken? Permablind.
		eye_blind =  1
		blinded =	1
		eye_blurry = 1

/mob/living/human/handle_chemical_smoke(var/datum/gas_mixture/environment)
	if (wear_mask && (wear_mask.item_flags & BLOCK_GAS_SMOKE_EFFECT))
		return
	if (head && (head.item_flags & BLOCK_GAS_SMOKE_EFFECT))
		return
	..()

/mob/living/human/handle_environment()

	var/loc_temp = 20
	var/area/mob_area = get_area(src)

	if (!mob_area)
		return

	loc_temp = get_temp(src)

	for (var/obj/structure/bed/bedroll/BRL in src.loc)
		if (BRL.used == TRUE && BRL.buckled_mob == src)
			if (loc_temp < 22)
				loc_temp = 22
				break

	if (loc_temp > 18 && istype(wear_suit, /obj/item/clothing/suit/storage/coat) && map && (map.civilizations || map.ID == MAP_GULAG13 || map.ID == MAP_COLONY) && mob_area.location == AREA_INSIDE)
		heatDamageFromClothingTimer++

		if (heatDamageFromClothingTimer == 5)
			src << "<span class = 'warning'><big>You are sweating inside your coat. It's way too warm to wear one.</big></span>"

		if (heatDamageFromClothingTimer >= 35)
			if (prob(50))
				src << "<span class = 'warning'><big>You are very uncomfortable. Remove the coat.</big></span>"
			heatDamageFromClothingTimer = 6
			adjustBurnLoss(2)


	else if (heatDamageFromClothingTimer > 0)
		heatDamageFromClothingTimer--
	//lets convert from Celsius to Kelvin
	loc_temp += 273.15
	//Body temperature adjusts depending on surrounding atmosphere based on your thermal protection (convection)
	var/temp_adj = 0
	if ((loc_temp < bodytemperature-20) || (loc_temp < bodytemperature-12 && (ant || lizard))) //Under 17 degrees = unconfortable without clothing
		var/thermal_protection = get_cold_protection(loc_temp) //This returns a 0 - 1 value, which corresponds to the percentage of protection based on what you're wearing and what you're exposed to.
		if (thermal_protection < 1)
			temp_adj = (1-thermal_protection) * ((loc_temp - bodytemperature-10) / BODYTEMP_COLD_DIVISOR) //this will be negative
	else if ((loc_temp > bodytemperature) || (loc_temp > bodytemperature-7 && (ant || lizard))) //Over 37 degrees = unconfortable with too much clothing
		var/thermal_protection = get_heat_protection(loc_temp) //This returns a 0 - 1 value, which corresponds to the percentage of protection based on what you're wearing and what you're exposed to.
		if (thermal_protection < 1)
			temp_adj = (1-thermal_protection) * ((loc_temp - bodytemperature) / BODYTEMP_HEAT_DIVISOR)
			temp_adj = abs(temp_adj)
	if (temp_adj > 0)
		temp_adj = min(temp_adj,8)
	else if (temp_adj < 0)
		temp_adj = max(temp_adj,-8)
	else
		if (loc_temp < bodytemperature)
			temp_adj = -0.1
		if (loc_temp > bodytemperature)
			temp_adj = 0.1
	if (map && map.civilizations)
		bodytemperature += temp_adj
	// +/- 50 degrees from 310.15K is the 'safe' zone, where no damage is dealt.

//this is handled in the get_environment_discomfort.
/*
	if (bodytemperature >= species.heat_level_1 && !orc)
		//Body temperature is too hot.

		if (status_flags & GODMODE)	return TRUE	//godmode
		var/burn_dam = FALSE
		switch(bodytemperature)
			if (species.heat_level_1 to species.heat_level_2)
				burn_dam = HEAT_DAMAGE_LEVEL_1
			if (species.heat_level_2 to species.heat_level_3)
				burn_dam = HEAT_DAMAGE_LEVEL_2
			if (species.heat_level_3 to INFINITY)
				burn_dam = HEAT_DAMAGE_LEVEL_3
		take_overall_damage(burn=burn_dam, used_weapon = "High Body Temperature")

	else if (bodytemperature <= species.cold_level_1 && !wolfman)
		if (status_flags & GODMODE)	return TRUE	//godmode

		var/burn_dam = FALSE
		switch(bodytemperature)
			if (-INFINITY to species.cold_level_3)
				burn_dam = COLD_DAMAGE_LEVEL_3
			if (species.cold_level_3 to species.cold_level_2)
				burn_dam = COLD_DAMAGE_LEVEL_2
			if (species.cold_level_2 to species.cold_level_1)
				burn_dam = COLD_DAMAGE_LEVEL_1
		take_overall_damage(burn=burn_dam, used_weapon = "Low Body Temperature")
*/

	species.get_environment_discomfort(src)

/mob/living/human/proc/stabilize_body_temperature()

	var/body_temperature_difference = species.body_temperature - bodytemperature

	if (abs(body_temperature_difference) < 3)
		return //fuck this precision

	if (on_fire)
		return //too busy for pesky metabolic regulation

	if (bodytemperature < species.cold_level_1) //260.15 is 310.15 - 50, the temperature where you start to feel effects.
		if (nutrition >= 2 && !inducedSSD) //If we are very, very cold we'll use up quite a bit of nutriment to heat us up.
			nutrition -= 0.10
		bodytemperature += 0.1
	else if (bodytemperature > species.heat_level_1) //360.15 is 310.15 + 50, the temperature where you start to feel effects.
		bodytemperature -= 0.1

//This proc returns a number made up of the flags for body parts which you are protected on. (such as HEAD, UPPER_TORSO, LOWER_TORSO, etc. See setup.dm for the full list)
/mob/living/human/proc/get_heat_protection_flags(temperature) //Temperature is the temperature you're being exposed to.
	. = FALSE
	//Handle normal clothing
	for (var/obj/item/clothing/C in list(head,wear_suit,w_uniform,shoes,gloves,wear_mask))
		if (C)
			if (C.max_heat_protection_temperature && C.max_heat_protection_temperature >= temperature)
				. |= C.heat_protection

//See proc/get_heat_protection_flags(temperature) for the description of this proc.
/mob/living/human/proc/get_cold_protection_flags(temperature)
	. = FALSE
	//Handle normal clothing
	for (var/obj/item/clothing/C in list(head,wear_suit,w_uniform,shoes,gloves,wear_mask))
		if (C)
			if (C.min_cold_protection_temperature && C.min_cold_protection_temperature <= temperature)
				. |= C.cold_protection

/mob/living/human/get_heat_protection(temperature) //Temperature is the temperature you're being exposed to.
	var/thermal_protection_flags = get_heat_protection_flags(temperature)
	return get_thermal_protection(thermal_protection_flags)

/mob/living/human/get_cold_protection(temperature)

	temperature = max(temperature, 2.7) //There is an occasional bug where the temperature is miscalculated in ares with a small amount of gas on them, so this is necessary to ensure that that bug does not affect this calculation. Space's temperature is 2.7K and most suits that are intended to protect against any cold, protect down to 2.0K.
	var/thermal_protection_flags = get_cold_protection_flags(temperature)
	return get_thermal_protection(thermal_protection_flags)

/mob/living/human/proc/get_thermal_protection(var/flags)
	.=0
	if (flags)
		if (flags & HEAD)
			. += THERMAL_PROTECTION_HEAD
		if (flags & UPPER_TORSO)
			. += THERMAL_PROTECTION_UPPER_TORSO
		if (flags & LOWER_TORSO)
			. += THERMAL_PROTECTION_LOWER_TORSO
		if (flags & LEG_LEFT)
			. += THERMAL_PROTECTION_LEG_LEFT
		if (flags & LEG_RIGHT)
			. += THERMAL_PROTECTION_LEG_RIGHT
		if (flags & FOOT_LEFT)
			. += THERMAL_PROTECTION_FOOT_LEFT
		if (flags & FOOT_RIGHT)
			. += THERMAL_PROTECTION_FOOT_RIGHT
		if (flags & ARM_LEFT)
			. += THERMAL_PROTECTION_ARM_LEFT
		if (flags & ARM_RIGHT)
			. += THERMAL_PROTECTION_ARM_RIGHT
		if (flags & HAND_LEFT)
			. += THERMAL_PROTECTION_HAND_LEFT
		if (flags & HAND_RIGHT)
			. += THERMAL_PROTECTION_HAND_RIGHT
	return min(1,.)

/mob/living/human/handle_chemicals_in_body()
	if (reagents)
		chem_effects.Cut()
		analgesic = FALSE

		if (touching) touching.metabolize()
		if (ingested) ingested.metabolize()
		if (bloodstr) bloodstr.metabolize()

		if (CE_PAINKILLER in chem_effects)
			analgesic = chem_effects[CE_PAINKILLER]

		var/total_plasmaloss = FALSE
	/*	for (var/obj/item/I in src)
			if (I.contaminated)
				total_plasmaloss += vsc.plc.CONTAMINATION_LOSS*/
		if (!(status_flags & GODMODE)) adjustToxLoss(total_plasmaloss)

	if (status_flags & GODMODE)	return FALSE	//godmode

	if (species.light_dam)
		var/light_amount = FALSE
		if (isturf(loc))
			var/turf/T = loc
			light_amount = round((T.get_lumcount()*10)-5)

		if (light_amount > species.light_dam) //if there's enough light, start dying
			take_overall_damage(1,1)
		else //heal in the dark
			heal_overall_damage(1,1)

	// TODO: stomach and bloodstream organ.
	handle_trace_chems()

	updatehealth()

	return //TODO: DEFERRED

/mob/living/human/handle_regular_status_updates()
	if (!handle_some_updates())
		return FALSE

	if (status_flags & GODMODE)	return FALSE

	//SSD check, if a logged player is awake put them back to sleep!
	if (species.show_ssd && ssd_check())
		Sleeping(2)
	if (stat == DEAD)	//DEAD. BROWN BREAD. SWIMMING WITH THE SPESS CARP
		blinded = TRUE
		silent = FALSE
	else				//ALIVE. LIGHTS ARE ON
		updatehealth()	//TODO

		if (health <= config.health_threshold_dead || (species.has_organ["brain"] && !has_brain()))
			death()
			blinded = TRUE
			silent = FALSE
			return TRUE

		//UNCONSCIOUS. NO-ONE IS HOME
		if ((getOxyLoss() > (species.total_health/2)) || (health <= config.health_threshold_crit))
			Paralyse(3)


		if (paralysis || sleeping)
			blinded = TRUE
			stat = UNCONSCIOUS
			adjustHalLoss(-3)
			if (l_hand) unEquip(l_hand)
			if (r_hand) unEquip(r_hand)

		if (paralysis)
			AdjustParalysis(-1)

		else if (sleeping)
			speech_problem_flag = TRUE
			handle_dreams()
			if (mind)
				//Are they SSD? If so we'll keep them asleep but work off some of that sleep var in case of stoxin or similar.
				if (client || sleeping > 3)
					AdjustSleeping(-1)
			if ( prob(2) && health)
				spawn(0)
					emote("snore")
		//CONSCIOUS
		else
			stat = CONSCIOUS

		// Check everything else.

		//Periodically double-check embedded_flag
		if (embedded_flag && !(life_tick % 10))
			if (!embedded_needs_process())
				embedded_flag = FALSE

		//Ears
		if ((sdisabilities & DEAF) || find_trait("Deaf"))	//disabled-deaf, doesn't get better on its own
			ear_deaf = max(ear_deaf, TRUE)
		else if (ear_deaf)			//deafness, heals slowly over time
			ear_deaf = max(ear_deaf-1, FALSE)
		else if (istype(l_ear, /obj/item/clothing/ears/earmuffs) || istype(r_ear, /obj/item/clothing/ears/earmuffs))	//resting your ears with earmuffs heals ear damage faster
			ear_damage = max(ear_damage-0.15, FALSE)
			ear_deaf = max(ear_deaf, TRUE)
		else if (ear_damage < 25)	//ear damage heals slowly under this threshold. otherwise you'll need earmuffs
			ear_damage = max(ear_damage-0.05, FALSE)

		//Resting
		if (resting)
			dizziness = max(0, dizziness - 15)
			jitteriness = max(0, jitteriness - 15)
			//adjustHalLoss(-3)
			if (halloss >= 3)
				halloss -= 3
		else
			dizziness = max(0, dizziness - 3)
			jitteriness = max(0, jitteriness - 3)
			//adjustHalLoss(-1)
			if (halloss >= 1)
				halloss -= 1

		//Other
		handle_statuses()

		if (drowsyness)
			drowsyness--
			eye_blurry = max(2, eye_blurry)
			if (prob(5))
				sleeping += 1
				Paralyse(5)

		confused = max(0, confused - 1)

		// If you're dirty, your gloves will become dirty, too.
		if (gloves && germ_level > gloves.germ_level && prob(10))
			gloves.germ_level += 1

	return TRUE

/mob/living/human/handle_regular_hud_updates()
	for (var/obj/screen/H in HUDprocess)
//		var/obj/screen/B = H
		H.process()
	if (!overlays_cache)
		overlays_cache = list()
		overlays_cache.len = 23
		overlays_cache[1] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage1")
		overlays_cache[2] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage2")
		overlays_cache[3] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage3")
		overlays_cache[4] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage4")
		overlays_cache[5] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage5")
		overlays_cache[6] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage6")
		overlays_cache[7] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage7")
		overlays_cache[8] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage8")
		overlays_cache[9] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage9")
		overlays_cache[10] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage10")
		overlays_cache[11] = image('icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay1")
		overlays_cache[12] = image('icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay2")
		overlays_cache[13] = image('icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay3")
		overlays_cache[14] = image('icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay4")
		overlays_cache[15] = image('icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay5")
		overlays_cache[16] = image('icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay6")
		overlays_cache[17] = image('icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay7")
		overlays_cache[18] = image('icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay1")
		overlays_cache[19] = image('icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay2")
		overlays_cache[20] = image('icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay3")
		overlays_cache[21] = image('icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay4")
		overlays_cache[22] = image('icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay5")
		overlays_cache[23] = image('icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay6")

	// update our mob's hud overlays, AKA what others see floating above our head
	handle_hud_list()

	// now handle what we see on our screen

	if (!..())
		return

	return TRUE

/mob/living/human/handle_random_events()

	// Puke if toxloss is too high
	if (!stat)
		if (getToxLoss() >= 45 && nutrition > 20)
			vomit()
/*
	//0.1% chance of playing a scary sound to someone who's in complete darkness
	if (isturf(loc) && rand(1,1000) == 1)
		var/turf/T = loc
		if (T.get_lumcount() == 0)
			playsound_local(src,pick(scarySounds),50, TRUE, -1)*/s

/mob/living/human/handle_stomach()
	spawn(0)
		for (var/mob/living/M in stomach_contents)
			if (M.loc != src)
				stomach_contents.Remove(M)
				continue
			if (ishuman(M)|| isanimal(M))
				if (M.stat == 2)
					M.death(1)
					stomach_contents.Remove(M)
					qdel(M)
					continue

		if (stat != DEAD)
			if (config.use_hunger)
				handle_starvation()
			else
				nutrition = max_nutrition

			if (config.use_thirst)
				handle_dehydration()
			else
				water = max_water

/*Hardcore mode stuff. This was moved here because constants that are only used
  at one spot in the code shouldn't be in the __defines folder */

#define STARVATION_MIN 0 //If you have less nutrition than this value, the hunger indicator starts flashing

#define STARVATION_NOTICE -15 //If you have more nutrition than this value, you get an occasional message reminding you that you're going to starve soon

#define STARVATION_WEAKNESS -40 //Otherwise, if you have more nutrition than this value, you occasionally become weak and receive minor damage

#define STARVATION_NEARDEATH -55 //Otherwise, if you have more nutrition than this value, you have seizures and occasionally receive damage

#define STARVATION_NEGATIVE_INFINITY -10000 // because trying to parse INFINITY into text is bad

//If you have less nutrition than STARVATION_NEARDEATH, you start getting damage

#define STARVATION_TOX_DAMAGE 2.5
#define STARVATION_BRAIN_DAMAGE 2.5

/mob/living/human/var/list/informed_starvation[4]

/mob/living/human/proc/handle_starvation()//Making this it's own proc for my sanity's sake - Matt

	if (nutrition < 220 && nutrition >= 150)
		if (prob(3))
			src << "<span class = 'warning'>You're getting a bit hungry.</span>"

	else if (nutrition < 150 && nutrition >= 100)
		if (prob(4))
			src << "<span class = 'warning'>You're pretty hungry.</span>"

	else if (nutrition < 100 && nutrition >= 20)
		if (prob(5))
			src << "<span class = 'danger'>You're getting really hungry!</span>"

	else if (nutrition < 20) //Nutrition is below 20 = starvation

		var/list/hunger_phrases = list(
			"You feel weak and malnourished. You must find something to eat now!",
			"You haven't eaten in ages, and your body feels weak! It's time to eat something.",
			"You can barely remember the last time you had a proper, nutritional meal. Your body will shut down soon if you don't eat something!",
			"Your body is running out of essential nutrients! You have to eat something soon.",
			"If you don't eat something very soon, you're going to starve to death."
			)

		//When you're starving, the rate at which oxygen damage is healed is reduced by 80% (you only restore TRUE oxygen damage per life tick, instead of 5)

		switch(nutrition)
			if (STARVATION_NOTICE to STARVATION_MIN)
				if (sleeping) return

				if (!informed_starvation[num2text(-STARVATION_NOTICE)])
					src << "<span class='warning'>[pick("You're very hungry.","You really could use a meal right now.")]</span>"

				informed_starvation[num2text(-STARVATION_NOTICE)] = TRUE
				informed_starvation[num2text(-STARVATION_WEAKNESS)] = FALSE
				informed_starvation[num2text(-STARVATION_NEARDEATH)] = FALSE
				informed_starvation[num2text(-STARVATION_NEGATIVE_INFINITY)] = FALSE

				if (prob(10))
					src << "<span class='warning'>[pick("You're very hungry.","You really could use a meal right now.")]</span>"

			if (STARVATION_WEAKNESS to STARVATION_NOTICE)
				if (sleeping) return

				if (!informed_starvation[num2text(-STARVATION_WEAKNESS)])
					src << "<span class='danger'>[pick(hunger_phrases)]</span>"

				informed_starvation[num2text(-STARVATION_NOTICE)] = TRUE
				informed_starvation[num2text(-STARVATION_WEAKNESS)] = TRUE
				informed_starvation[num2text(-STARVATION_NEARDEATH)] = FALSE
				informed_starvation[num2text(-STARVATION_NEGATIVE_INFINITY)] = FALSE

				if (prob(6)) //6% chance of a tiny amount of toxin damage (1-5)

					adjustToxLoss(rand(1,5))
					src << "<span class='danger'>[pick(hunger_phrases)]</span>"

				else if (prob(5)) //5% chance of being weakened

					eye_blurry += 10
					Weaken(10)
					adjustToxLoss(rand(1,15))
					src << "<span class='danger'>You're starving! The lack of strength makes you black out for a few moments...</span>"

			if (STARVATION_NEARDEATH to STARVATION_WEAKNESS) //5-30, 5% chance of weakening and TRUE-230 oxygen damage. 5% chance of a seizure. 10% chance of dropping item
				if (sleeping) return

				if (!informed_starvation[num2text(-STARVATION_NEARDEATH)])
					src << "<span class='danger'>You're starving. You feel your life force slowly leaving your body...</span>"

				informed_starvation[num2text(-STARVATION_NOTICE)] = TRUE
				informed_starvation[num2text(-STARVATION_WEAKNESS)] = TRUE
				informed_starvation[num2text(-STARVATION_NEARDEATH)] = TRUE
				informed_starvation[num2text(-STARVATION_NEGATIVE_INFINITY)] = FALSE

				if (prob(7))

					adjustToxLoss(rand(1,20))
					src << "<span class='danger'>You're starving. You feel your life force slowly leaving your body...</span>"
					eye_blurry += 20
					if (weakened < 1) Weaken(20)

				else if (paralysis<1 && prob(7)) //Mini seizure (25% duration and strength of a normal seizure)

					visible_message("<span class='danger'>\The [src] starts having a seizure!</span>", \
							"<span class='warning'>You have a seizure!</span>")
					Paralyse(5)
					make_jittery(500)
					adjustToxLoss(rand(1,25))
					eye_blurry += 20

			if (-INFINITY to STARVATION_NEARDEATH) //Fuck the whole body up at this point

				if (!informed_starvation[num2text(-STARVATION_NEGATIVE_INFINITY)])
					src << "<span class='danger'>You are dying from starvation!</span>"

				informed_starvation[num2text(-STARVATION_NOTICE)] = TRUE
				informed_starvation[num2text(-STARVATION_WEAKNESS)] = TRUE
				informed_starvation[num2text(-STARVATION_NEARDEATH)] = TRUE
				informed_starvation[num2text(-STARVATION_NEGATIVE_INFINITY)] = TRUE

				if (prob(10))
					src << "<span class='danger'>You are dying from starvation!</span>"

				adjustToxLoss(STARVATION_TOX_DAMAGE)
				adjustBrainLoss(STARVATION_BRAIN_DAMAGE)

				if (prob(10))
					Weaken(15)

#define DEHYDRATION_MIN FALSE
#define DEHYDRATION_NOTICE -15
#define DEHYDRATION_WEAKNESS -40
#define DEHYDRATION_NEARDEATH -55
#define DEHYDRATION_NEGATIVE_INFINITY -10000

#define DEHYDRATION_TOX_DAMAGE 2.5
#define DEHYDRATION_BRAIN_DAMAGE 2.5

/mob/living/human/var/list/informed_dehydration[4]

/mob/living/human/proc/handle_dehydration()//Making this it's own proc for my sanity's sake - Matt

	if (water < 200 && water >= 150)
		if (prob(3))
			src << "<span class = 'warning'>You're getting a bit thirsty.</span>"

	else if (water < 150 && water >= 100)
		if (prob(4))
			src << "<span class = 'warning'>You're pretty thirsty.</span>"

	else if (water < 100 && water >= 20)
		if (prob(5))
			src << "<span class = 'danger'>You're really thirsty!</span>"

	else if (water < 20) //Nutrition is below 20 = dehydration

		var/list/thirst_phrases = list(
			"You feel weak and malnourished. You must find something to drink now!",
			"You haven't drank in ages, and your body feels weak! It's time to drink something.",
			"You can barely remember the last time you had something to drink!",
			"Your body is starting to dehydrate! You have to drink something soon.",
			"If you don't drink something very soon, you're going to dehydrate to death."
			)

		//When you're starving, the rate at which oxygen damage is healed is reduced by 80% (you only restore TRUE oxygen damage per life tick, instead of 5)

		switch(water)
			if (DEHYDRATION_NOTICE to DEHYDRATION_MIN)
				if (sleeping) return

				if (!informed_dehydration[num2text(-DEHYDRATION_NOTICE)])
					src << "<span class='warning'>[pick("You're very thirsty.","You really could use some water right now.")]</span>"

				informed_dehydration[num2text(-DEHYDRATION_NOTICE)] = TRUE
				informed_dehydration[num2text(-DEHYDRATION_WEAKNESS)] = FALSE
				informed_dehydration[num2text(-DEHYDRATION_NEARDEATH)] = FALSE
				informed_dehydration[num2text(-DEHYDRATION_NEGATIVE_INFINITY)] = FALSE

				if (prob(10))
					src << "<span class='warning'>[pick("You're very thirsty.","You really could use some water right now.")]</span>"

			if (DEHYDRATION_WEAKNESS to DEHYDRATION_NOTICE)
				if (sleeping) return

				if (!informed_dehydration[num2text(-DEHYDRATION_WEAKNESS)])
					src << "<span class='danger'>[pick(thirst_phrases)]</span>"

				informed_dehydration[num2text(-DEHYDRATION_NOTICE)] = TRUE
				informed_dehydration[num2text(-DEHYDRATION_WEAKNESS)] = TRUE
				informed_dehydration[num2text(-DEHYDRATION_NEARDEATH)] = FALSE
				informed_dehydration[num2text(-DEHYDRATION_NEGATIVE_INFINITY)] = FALSE

				if (prob(6)) //6% chance of a tiny amount of toxin damage (1-5)

					adjustToxLoss(rand(1,5))
					src << "<span class='danger'>[pick(thirst_phrases)]</span>"

				else if (prob(5)) //5% chance of being weakened

					eye_blurry += 10
					Weaken(10)
					adjustToxLoss(rand(1,15))
					src << "<span class='danger'>You're dehydrating! The lack of strength makes you black out for a few moments...</span>"

			if (DEHYDRATION_NEARDEATH to DEHYDRATION_WEAKNESS) //5-30, 5% chance of weakening and TRUE-230 oxygen damage. 5% chance of a seizure. 10% chance of dropping item
				if (sleeping) return

				if (!informed_dehydration[num2text(-DEHYDRATION_NEARDEATH)])
					src << "<span class='danger'>You're dehydrating. You feel your life force slowly leaving your body...</span>"

				informed_dehydration[num2text(-DEHYDRATION_NOTICE)] = TRUE
				informed_dehydration[num2text(-DEHYDRATION_WEAKNESS)] = TRUE
				informed_dehydration[num2text(-DEHYDRATION_NEARDEATH)] = TRUE
				informed_dehydration[num2text(-DEHYDRATION_NEGATIVE_INFINITY)] = FALSE

				if (prob(7))

					adjustToxLoss(rand(1,20))
					src << "<span class='danger'>You're dehydrating. You feel your life force slowly leaving your body...</span>"
					eye_blurry += 20
					if (weakened < 1) Weaken(20)

				else if (paralysis<1 && prob(7)) //Mini seizure (25% duration and strength of a normal seizure)

					visible_message("<span class='danger'>\The [src] starts having a seizure!</span>", \
							"<span class='warning'>You have a seizure!</span>")
					Paralyse(5)
					make_jittery(500)
					adjustToxLoss(rand(1,25))
					eye_blurry += 20

			if (-INFINITY to DEHYDRATION_NEARDEATH) //Fuck the whole body up at this point

				if (!informed_dehydration[num2text(-DEHYDRATION_NEGATIVE_INFINITY)])
					src << "<span class='danger'>You are dying from dehydration!</span>"

				informed_dehydration[num2text(-DEHYDRATION_NOTICE)] = TRUE
				informed_dehydration[num2text(-DEHYDRATION_WEAKNESS)] = TRUE
				informed_dehydration[num2text(-DEHYDRATION_NEARDEATH)] = TRUE
				informed_dehydration[num2text(-DEHYDRATION_NEGATIVE_INFINITY)] = TRUE

				if (prob(10))
					src << "<span class='danger'>You are dying from dehydration!</span>"

				adjustToxLoss(DEHYDRATION_TOX_DAMAGE)
				adjustBrainLoss(DEHYDRATION_BRAIN_DAMAGE)

				if (prob(10))
					Weaken(15)

/mob/living/human/proc/handle_shock()
	if(status_flags & GODMODE)	return FALSE	//godmode
	if(!can_feel_pain())
		shock_stage = 0
		return
		
	var/traumatic_shock = get_shock()
	if(traumatic_shock >= max(30, 0.8*shock_stage))
		shock_stage += 1
	else
		shock_stage = min(shock_stage, 160)
		var/recovery = 1
		if(traumatic_shock < 0.5 * shock_stage) // Fower shock faster if pain is gone completely
			recovery++
		if(traumatic_shock < 0.25 * shock_stage)
			recovery++
		shock_stage = max(shock_stage - recovery, 0)
		return
	if (stat == UNCONSCIOUS) return FALSE // If they're unconscious they won't feel pain

	if (shock_stage == 10)
		custom_pain("[pick("It hurts so much", "You really need some painkillers", "Dear god, the pain")]!", 10, nohalloss = TRUE)

	if (shock_stage >= 40)
		if (shock_stage == 40) emote("me",1,"is having trouble keeping their eyes open.")
		eye_blurry = max(2, eye_blurry)
		stuttering = max(stuttering, 5)

	if (shock_stage == 50)
		custom_pain("[pick("The pain is excruciating", "Please, just end the pain", "Your whole body is going numb")]!", 40, nohalloss = TRUE)

	if (shock_stage >= 70)
		if (shock_stage == 90) emote("me",1,"'s body becomes limp.")
		if (prob(2))
			custom_pain("[pick("The pain is excruciating", "Please, just end the pain", "Your whole body is going numb")]!", shock_stage, nohalloss = TRUE)
			Weaken(10)

	if (shock_stage >= 80)
		if (prob(5))
			custom_pain("[pick("The pain is excruciating", "Please, just end the pain", "Your whole body is going numb")]!", shock_stage, nohalloss = TRUE)
			Weaken(20)

	if (shock_stage >= 120)
		if (prob(2))
			custom_pain("[pick("You black out", "You feel like you could die any moment now", "You're about to lose consciousness")]!", shock_stage, nohalloss = TRUE)
			Paralyse(5)

	if (shock_stage == 150)
		emote("me",1,"can no longer stand, collapsing!")
		Weaken(20)

	if (shock_stage >= 150)
		Weaken(20)
		if (prob(1))
			adjustOxyLoss(10)
	if (getBruteLoss() >= 150)
		spawn(1200)
			if (getBruteLoss() >= 150)
				death()

/mob/living/human/proc/handle_hud_list()
	if (stat == DEAD)
		hud_list[BASE_FACTION].icon_state = ""
		hud_list[BASE_FACTION].overlays.Cut()
		hud_list[FACTION_TO_ENEMIES].icon_state = ""
		hud_list[FACTION_TO_ENEMIES].overlays.Cut()
	if (original_job && never_set_faction_huds && stat != DEAD)

		never_set_faction_huds = FALSE

		if (base_faction)
			var/image/holder = hud_list[FACTION_TO_ENEMIES]
			holder.icon = null
			holder.icon_state = null
			hud_list[FACTION_TO_ENEMIES] = holder

			var/image/holder2 = hud_list[BASE_FACTION]
			holder2.icon = 'icons/mob/hud_1713.dmi'
			holder2.plane = HUD_PLANE
			switch (original_job.base_type_flag())
				if (PIRATES)
					if (map.ID == MAP_CAMPAIGN || map.ID == MAP_NOMADS_PERSISTENCE_BETA || map.ID == MAP_ROTSTADT || map.ID == MAP_NATIONSRP_COLDWAR_CAMPAIGN || map.ID == MAP_BATTLE_SHIPS)
						holder2.icon_state = "redmenia"
					else if (map && !map.battleroyale)
						holder2.icon_state = "pirate_basic"
				if (BRITISH)
					if (map.ordinal_age >= 4)
						holder2.icon_state = "brit_basic"
					else if (map.ordinal_age >= 3)
						holder2.icon_state = "rn_basic"
					else if (map.ID == MAP_TWOTRIBES)
						holder2.icon_state = "civ1"
					else
						holder2.icon_state = "eng_basic"
				if (FRENCH)
					if (map.ordinal_age >= 4)
						holder2.icon_state = "fr2_basic"
					else if (map.ID == MAP_TWOTRIBES)
						holder2.icon_state = "civ3"
					else
						holder2.icon_state = "fr_basic"
				if (SPANISH)
					if (map.ordinal_age <= 3)
						holder2.icon_state = "sp_basic"
					else
						holder2.icon_state = "spn_basic"
				if (PORTUGUESE)
					if (map.ordinal_age <= 4)
						holder2.icon_state = "pt_basic"
					else
						holder2.icon_state = "pt2_basic"
				if (INDIANS)
					if (map.ID == MAP_AFRICAN_WARLORDS)
						if(nationality == "Yellowagwana")
							holder2.icon_state = "civ4"
						if(nationality == "Redkantu")
							holder2.icon_state = "civ1"
						if(nationality == "Blugisi")
							holder2.icon_state = "civ3"
					else if (map.ID == MAP_EAST_LOS_SANTOS)
						holder2.icon_state = "ballas"
					else
						holder2.icon_state = "ind_basic"
				if (DUTCH)
					if (map.ordinal_age >= 6)
						holder2.icon_state = "nl_basic"
					else
						holder2.icon_state = "nl_old_basic"
				if (ITALIAN)
					holder2.icon_state = "it_basic"
				if (ARAB)
					if (map.ordinal_age >= 6)
						if (map.ID == MAP_ARAB_TOWN)
							holder2.icon_state = "hez_basic"
						else if (map.ID == MAP_SYRIA)
							if (original_job.title == "Wagner Group PMC")
								holder2.icon_state = "wagner"
							else
								holder2.icon_state = "syria_basic"
						else
							holder2.icon_state = "isis_basic"
					else
						holder2.icon_state = "arab_basic"
				if (GREEK)
					holder2.icon_state = "greek_basic"
				if (ROMAN)
					if (map.ID == MAP_WHITERUN)
						holder2.icon_state = "empire"
					else
						holder2.icon_state = "roman_basic"
				if (CHECHEN)
					holder2.icon_state = "chechen_basic"
				if (FINNISH)
					holder2.icon_state = "finnish_basic"
				if (NORWEGIAN)
					if (map.ID == MAP_CLASH)
						holder2.icon_state = "ger0_basic"
					else
						holder2.icon_state = "norway_basic"
				if (SWEDISH)
					holder2.icon_state = "swedish_basic"
				if (DANISH)
					if (map.ID == MAP_CLASH)
						holder2.icon_state = "barbarian_basic"
					else
						holder2.icon_state = "danish_basic"
				if (JAPANESE)
					if (original_job.is_yakuza && original_job.is_yama)
						holder2.icon_state = "yamaguchi"
					else if (original_job.is_yakuza && original_job.is_ichi)
						holder2.icon_state = "ichiwa"
					else if (original_job.is_samurai && original_job.is_eastern)
						holder2.icon_state = "eastern"
					else if (original_job.is_samurai && original_job.is_western)
						holder2.icon_state = "western"
					else
						holder2.icon_state = "jp_basic"
				if (RUSSIAN)
					if (map.ID == MAP_YELTSIN || map.ID == MAP_GROZNY || map.ID == MAP_FACTORY || map.ID == MAP_OPERATION_FALCON || map.ID == MAP_VADSO_CITY)
						holder2.icon_state = "ru_basic"
					else if (map.ID == MAP_BANK_ROBBERY)
						holder2.icon_state = "robbers"
					else if (map.ID == MAP_DRUG_BUST)
						holder2.icon_state = "rednikov"
					else if (map.ID == MAP_EFT_FACTORY)
						holder2.icon_state = "none"
					else
						if (map.ordinal_age <= 5)
							holder2.icon_state = "ru_basic"
						else if (map.ordinal_age >= 6)
							holder2.icon_state = "sov_basic"
				if (GERMAN)
					if (map.ordinal_age <= 1)
						holder2.icon_state = "ger0_basic"
					else if (map.ordinal_age <= 5)
						holder2.icon_state = "ger_basic"
					else if (map.ordinal_age == 6)
						holder2.icon_state = "ger2_basic"
					else
						holder2.icon_state = "ger3_basic"
				if (AMERICAN)
					if (map.ID == MAP_ARAB_TOWN)
						holder2.icon_state = "idf_basic"
					else if (map.ID == MAP_TANTIVEIV)
						holder2.icon_state = "imp_basic"
					else if (map.ID == MAP_EAST_LOS_SANTOS)
						holder2.icon_state = "civ2"
					else if (map.ID == MAP_EFT_FACTORY)
						holder2.icon_state = "none"
					else if (map.ID == MAP_SYRIA && original_job.title != "Delta Force Operator")
						holder2.icon_state = "syria_fsa"
					else
						holder2.icon_state = "us_basic"
				if (VIETNAMESE)
					if (original_job.is_nva)
						holder2.icon_state = "vn_basic"
					else
						holder2.icon_state = "vc_basic"
				if (FILIPINO)
					holder2.icon_state = "fp_basic"
				if (CHINESE)
					if((map && map.ordinal_age >= 7) || map.ID == MAP_RETREAT)
						holder2.icon_state = "sov_basic"
					else
						holder2.icon_state = "roc_basic"
				if (POLISH)
					holder2.icon_state = "pol_basic"
				if (CIVILIAN)
					if (map.ID == MAP_CAPITOL_HILL)
						holder2.icon_state = "civ1"
					else if (map.ID == MAP_CAMPAIGN || map.ID == MAP_NOMADS_PERSISTENCE_BETA || map.ID == MAP_ROTSTADT || map.ID == MAP_NATIONSRP_COLDWAR_CAMPAIGN || map.ID == MAP_BATTLE_SHIPS)
						holder2.icon_state = "blugoslavia"
					else if (original_job_title == "Nomad")
						holder2.icon_state = ""
					else if (original_job.is_upa && map.ID != MAP_OCCUPATION)
						holder2.icon_state = "upa_basic"
					else if (map.ID == MAP_WHITERUN)
						holder2.icon_state = "stormcloak"
					else if (map.ID == MAP_TANTIVEIV)
						holder2.icon_state = "rebel_basic"
					else if ((map.ID == MAP_BANK_ROBBERY || map.ID == MAP_DRUG_BUST)&& original_job.is_law)
						holder2.icon_state = "police"
					else if (map.ID == MAP_TADOJSVILLE)
						holder2.icon_state = "un"
					else if (map.ID == MAP_TSARITSYN || map.ID == MAP_YELTSIN || map.ID == MAP_LONG_MARCH)
						holder2.icon_state = "sov_basic"
					else if (map.ID == MAP_EFT_FACTORY)
						holder2.icon_state = "none"
					else if (map.ID == MAP_GULAG13)
						if(nationality == "Polish")
							holder2.icon_state = "pol_basic"
						else if(nationality == "German")
							holder2.icon_state = "ger3_basic"
						else if(nationality == "Ukrainian")
							holder2.icon_state = "ukr_basic"
					else if (original_job_title == "Civilization A Citizen")
						if (map.ID == MAP_NATIONSRP_COLDWAR)
							holder2.icon_state = "us_basic"
						else
							holder2.icon_state = "civ1"
					else if (original_job_title == "Civilization B Citizen")
						if (map.ID == MAP_NATIONSRP_COLDWAR)
							holder2.icon_state = "sov_basic"
						else
							holder2.icon_state = "civ2"
					else if (original_job_title == "Civilization C Citizen")
						holder2.icon_state = "civ3"
					else if (original_job_title == "Civilization D Citizen")
						holder2.icon_state = "civ4"
					else if (original_job_title == "Civilization E Citizen")
						holder2.icon_state = "civ5"
					else if (original_job_title == "Civilization F Citizen")
						holder2.icon_state = "civ6"
					else
						holder2.icon_state = ""
			holder2.overlays.Cut()
			if (faction_text == CIVILIAN && map.ID == MAP_GULAG13)
				switch(original_job_title)
					if ("Janitor")
						holder2.overlays += icon(holder2.icon,"role_janitor")
					if ("Kitchen Duty")
						holder2.overlays += icon(holder2.icon,"role_kitchen")
					if ("Miner")
						holder2.overlays += icon(holder2.icon,"role_miner")
					if ("Nurse Helper")
						holder2.overlays += icon(holder2.icon,"role")
					if ("Builder")
						holder2.overlays += icon(holder2.icon,"role_builder")
					if ("Logger")
						holder2.overlays += icon(holder2.icon,"role_logger")
			if (original_job.uses_squads)
				if (faction_text == CIVILIAN && map.ID == MAP_OCCUPATION)
					holder2.icon_state = ""
				else
					if(map.ID == MAP_CAMPAIGN || map.ID == MAP_ROTSTADT || map.ID == MAP_BATTLE_SHIPS)
						if(squad == 4)
							holder2.overlays += icon(holder2.icon,"squad_recon")
							holder2.overlays += icon(holder2.icon,"i_cpl")
						else if (squad == 5)
							holder2.overlays += icon(holder2.icon,"squad_armoured")
						else if (squad == 6)
							holder2.overlays += icon(holder2.icon,"squad_at")
							holder2.overlays += icon(holder2.icon,"i_cpl")
						else if (squad == 7)
							holder2.overlays += icon(holder2.icon,"squad_engineer")
							holder2.overlays += icon(holder2.icon,"i_cpl")
						else
							holder2.overlays += icon(holder2.icon,"squad_[squad]")
						if(findtext(original_job_title,"Private"))
							holder2.overlays += icon(holder2.icon,"rifleman")
						if(findtext(original_job_title,"Des. Marksman"))
							holder2.overlays += icon(holder2.icon,"i_cpl")
							holder2.overlays += icon(holder2.icon,"designated_marksman")
						if(findtext(original_job_title,"Machinegunner"))
							holder2.overlays += icon(holder2.icon,"mg")
							holder2.overlays += icon(holder2.icon,"i_cpl")
						if((findtext(original_job_title,"Officer") && !findtext(original_job_title,"Petty Officer")) || findtext(original_job_title,"Ensign"))
							holder2.overlays += icon(holder2.icon,"i_lt")
						else if(findtext(original_job_title,"Squadleader") || findtext(original_job_title,"Petty Officer"))
							holder2.overlays += icon(holder2.icon,"i_sgt")
						else if(findtext(original_job_title,"Commander") || findtext(original_job_title,"Captain"))
							holder2.overlays += icon(holder2.icon,"i_cpt")
						else if(findtext(original_job_title,"Medic"))
							holder2.overlays += icon(holder2.icon,"i_ssgt")
						else if(findtext(original_job_title,"Corpsman"))
							holder2.overlays += icon(holder2.icon,"i_cpl")
					else
						holder2.overlays += icon(holder2.icon,"squad_[squad]")
			if (map.ID != MAP_CAMPAIGN && map.ID != MAP_ROTSTADT && map.ID != MAP_BATTLE_SHIPS)
				if (original_job.is_commander || (original_job.is_commander && original_job.is_officer) || original_job.is_vip)
					if (faction_text == CIVILIAN && map.ID == MAP_OCCUPATION)
						holder2.icon_state = ""
					else
						holder2.overlays += icon(holder2.icon,"commander")
				else if (original_job.is_officer && !original_job.is_commander && !original_job.is_vip)
					if (faction_text == CIVILIAN && map.ID == MAP_OCCUPATION)
						holder2.icon_state = ""
					else
						holder2.overlays += icon(holder2.icon,"officer")
				else if (original_job.is_squad_leader)
					if (faction_text == CIVILIAN && map.ID == MAP_OCCUPATION)
						holder2.icon_state = ""
					else
						holder2.overlays += icon(holder2.icon,"nco")
			if (map.ID == MAP_OPERATION_FALCON || map.ID == MAP_VADSO_CITY)
				if (original_job.is_commander)
					to_chat(world, "<font color='green' size=4>[ckey] is now the <b>[capitalize(lowertext(faction_text))] Army</b> Commander!</font>")
			if (original_job.is_medic)
				holder2.overlays += icon(holder2.icon,"medic")
			hud_list[BASE_FACTION] = holder2

/mob/living/human/handle_silent()
	if (..())
		speech_problem_flag = TRUE
	return silent

/mob/living/human/handle_slurring()
	if (..())
		speech_problem_flag = TRUE
	return slurring

/mob/living/human/handle_stunned()
	if (species.flags & NO_PAIN)
		stunned = FALSE
		return FALSE
	if (..())
		speech_problem_flag = TRUE
	return stunned

/mob/living/human/handle_stuttering()
	if (..())
		speech_problem_flag = TRUE
	return stuttering

/mob/living/human/handle_fire()
	if (..())
		return
	
	if (prob(10))
		src << pick(SPAN_DANGER("<big>OH MY GOD I AM ON FIRE!!!</big>"), SPAN_DANGER("<big>PUT IT OUT!!!</big>"), SPAN_DANGER("<big>I AM BURNING ALIVE!!!</big>"), SPAN_DANGER("<big>MY SKIN IS PEELING OFF!!!</big>"))
		emote("scream")

	var/burn_temperature = fire_burn_temperature()
	var/thermal_protection = get_heat_protection(burn_temperature)

	if (thermal_protection < 1 && bodytemperature < burn_temperature)
		bodytemperature += round(BODYTEMP_HEATING_MAX*(1-thermal_protection), TRUE)
	
	var/species_heat_mod = 1

	var/protected_limbs = get_heat_protection_flags(burn_temperature)


	if(species)
		if(burn_temperature < species.heat_level_2)
			species_heat_mod = 0.5
		else if(burn_temperature < species.heat_level_3)
			species_heat_mod = 0.75

	burn_temperature -= species.heat_level_1

	if(burn_temperature < 1)
		return

	for(var/obj/item/organ/external/E in organs)
		if(!(E.body_part & protected_limbs) && prob(20))
			E.take_damage(burn = round(species_heat_mod * log(10, (burn_temperature + 10)), 0.1), used_weapon = "Fire")

/mob/living/human/handle_vision()

	if (client)
		client.screen.Remove(global_hud.blurry, global_hud.druggy, global_hud.vimpaired, global_hud.darkMask, global_hud.nvg, global_hud.thermal)

	if (!laddervision)
		if (using_object)
			var/viewflags = using_object.check_eye(src)
			if (viewflags < 0)
				reset_view(null, FALSE)
			else if (viewflags)
				sight |= viewflags
	else if (client)
		client.perspective = EYE_PERSPECTIVE
		client.eye = laddervision

	update_equipment_vision()
	species.handle_vision(src)

/mob/living/human/update_sight()
	..()
	if (stat == DEAD)
		return

/mob/living/human/proc/do_rotting()
	if (map && istype(src, /mob/living/human/corpse))
		return
	spawn(600)
		if (stat == DEAD)
			spawn(30000)
				if (stat == DEAD)
					visible_message("[src]'s body starts to rot.")
					rotting_stage = 1
					spawn(30000)
						if (stat == DEAD)
							visible_message("[src]'s body is visibly rotten!")
							rotting_stage = 2
							if(map.ID != "TANTIVEIV" && map.ID != MAP_VERDUN)
								if (isturf(loc))
									new/mob/living/simple_animal/crow(loc)
							spawn(20000)
								if (stat == DEAD)
									var/found = FALSE
									for (var/obj/item/organ/external/head/H in organs)
										found = TRUE
										break
									if ((map.is_zombie) && found && !istype(get_area(src), /area/caribbean/admin))
										var/mob/living/simple_animal/hostile/human/zombie/playerzombie //make a var for the zombie
										playerzombie = new /mob/living/simple_animal/hostile/human/zombie/ //make a zombie!
										//transferring vars.
										playerzombie.loc = loc
										playerzombie.name = "[real_name]'s zombie"
										strip()
									else
										if (!istype(src, /mob/living/human/corpse))
											var/obj/structure/religious/remains/HR = new/obj/structure/religious/remains(src.loc)
											HR.name = "[src]'s remains"
											strip()
									qdel(src)
									return
								else
									return
						else
							return
				else
					return

/mob/living/human/proc/ssd_hiding(var/timer = 10)
	if (!map.civilizations)
		return
	if (timer <= 0)
		return
	timer *= 600 //convert minutes to deciseconds
	spawn(timer)
		if (stat!=DEAD && (!key || !client))
			if (istype(buckled, /obj/structure/bed) || istype(buckled, /obj/structure/optable))
				invisibility = 101
				return
			else
				invisibility = 0
				return

/mob/living/human/proc/buried_proc()
	if (buriedalive)
		spawn(300)
			if (buriedalive && stat != DEAD)
				adjustOxyLoss(5)
				src << "<span class='danger'>You can't breathe!</span>"


/mob/living/human/proc/process_addictions(drug = null, value = 0)
	if (!drug || value == 0)
		return
	else
		switch(drug)
			if ("cocaine")
				if (ingested.has_reagent("cocaine"))
					return
				mood -= (value/100)*0.26
				switch (value)
					if (0 to 24)
						return
					if (24 to 37)
						if (prob(13))
							emote("twitch")
						return
					if (37 to 56)
						if (prob(15))
							if (prob(50))
								emote("twitch")
							else
								emote("shiver")
						if (prob(2))
							confused = 5
						return
					if (56 to 81)
						if (prob(33))
							if (prob(50))
								emote("twitch")
							else
								emote("shiver")
							custom_pain("You feel restless.",0)
						if (prob(5))
							confused = 6
						if (prob(10))
							make_dizzy(5)
						return
					if (81 to 100)
						if (prob(40))
							if (prob(50))
								emote("twitch")
							else
								emote("shiver")
							custom_pain("You can't stand still!",4)
						if (prob(10))
							confused = 6
						if (prob(12))
							make_dizzy(6)
						return
			if ("opium")
				if (ingested.has_reagent("opium"))
					return
				mood -= (value/100)*0.32
				switch (value)
					if (0 to 13)
						if (prob(5))
							emote("shiver")
							src << "You feel slightly sick."
						return
					if (13 to 25)
						if (prob(10))
							custom_pain("You feel a slight itch.",0)
						if (prob(8))
							emote("shiver")
							src << "You feel sick."
						return
					if (25 to 48)
						if (prob(10))
							custom_pain("Your body itches all over.",1)
						if (prob(11))
							emote("shiver")
							src << "You feel sick."
						if (prob(6))
							vomit()
						return
					if (48 to 67)
						if (prob(10))
							custom_pain("Your body itches all over, it's driving you mad!",1)
						if (prob(11))
							emote("shiver")
						if (prob(2))
							apply_effect(12, AGONY, FALSE)
							apply_effect(7, DROWSY, FALSE)
						return
					if (67 to 81)
						if (prob(10))
							custom_pain("Your body itches all over, it's driving you mad!",2)
						if (prob(11))
							emote("shiver")
						if (prob(2))
							apply_effect(15, AGONY, FALSE)
							apply_effect(9, DROWSY, FALSE)
						return
					if (81 to 100)
						if (prob(10))
							custom_pain("Your body itches all over, it's driving you mad!",2)
						if (prob(11))
							emote("shiver")
						if (prob(2))
							apply_effect(17, AGONY, FALSE)
							apply_effect(10, DROWSY, FALSE)
						return
			if ("tobacco")
				if (ingested.has_reagent("nicotine"))
					return
				mood -= (value/100)*0.14
				switch (value)
					if (0 to 21)
						return
					if (21 to 44)
						return
					if (44 to 72)
						return
					if (72 to 87)
						return
					if (87 to 100)
						return
			if ("alcohol")
				if (ingested.has_reagent("wine") || ingested.has_reagent("rum") || ingested.has_reagent("beer") || ingested.has_reagent("vodka") || ingested.has_reagent("sake") || ingested.has_reagent("ale"))
					return
				mood -= (value/100)*0.20
				switch (value)
					if (0 to 21)
						return
					if (21 to 44)
						if (prob(5))
							emote("shiver")
						return
					if (44 to 72)
						if (prob(10))
							emote("shiver")
						if (prob(2))
							make_dizzy(6) // It is decreased at the speed of 3 per tick
							custom_pain("You feel a light pain in your head.",0)
						return
					if (72 to 87)
						if (prob(13))
							emote("shiver")
						if (prob(5))
							custom_pain("You head hurts a lot!",1)
						if (prob(5))
							make_dizzy(6) // It is decreased at the speed of 3 per tick
						return
					if (87 to 100)
						if (prob(16))
							emote("shiver")
						if (prob(9))
							custom_pain("You feel an excrutiating pain in your head!",1)
						if (prob(9))
							make_dizzy(6) // It is decreased at the speed of 3 per tick
						return

/mob/living/human/proc/instadeath_check()
	if (getBrainLoss() > 60 || getTotalDmg() > 150)
		death()
		return
	else
		return
/mob/living/human/proc/handle_defib_timer()
	var/obj/item/organ/brain/brain = internal_organs_by_name["brain"]
	if(!brain)
		return // No brain.

	brain.tick_defib_timer()

/mob/living/human/proc/handle_embedded_objects()

	for (var/obj/item/organ/external/organ in organs)
		if (organ.status & ORGAN_SPLINTED) //Splints prevent movement.
			continue
		for (var/obj/item/O in organ.implants)
			if (/*!istype(O,/obj/item/weapon/implant) && */prob(2)) //Moving with things stuck in you could be bad.
				// All kinds of embedded objects cause bleeding.
				if (species.flags & NO_PAIN)
					src << "<span class='warning'>You feel [O] moving inside your [organ.name].</span>"
				else
					var/msg = pick( \
						"<span class='warning'>A spike of pain jolts your [organ.name] as you bump [O] inside.</span>", \
						"<span class='warning'>Your movement jostles [O] in your [organ.name] painfully.</span>", \
						"<span class='warning'>Your movement jostles [O] in your [organ.name] painfully.</span>")
					src << msg

				organ.take_damage(rand(1,3), FALSE, FALSE)
				if (!(species.flags & NO_BLOOD)) //There is no blood in protheses.
					organ.status |= ORGAN_BLEEDING
					adjustToxLoss(rand(1,3))