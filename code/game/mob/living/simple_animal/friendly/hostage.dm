/mob/living/simple_animal/hostage
	name = "hostage"
	desc = "A poor guy made hostage."
	icon = 'icons/mob/npcs.dmi'
	icon_state = "hostage_m1"
	icon_living = "hostage_m1"
	icon_dead = "hostage_m1_dead"
	speak = list("Oh god!","Please don't!","AAAAAAH!")
	speak_emote = list("cries","screams","sobs")
	speak_emote = list("cries","screams","sobs")
	emote_see = list("walks around", "waves his hands", "trembles in fear")
	meat_amount = 2
	attacktext = "hit"
	melee_damage_lower = 6
	melee_damage_upper = 9
	mob_size = MOB_MEDIUM
	possession_candidate = FALSE
	move_to_delay = 4
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak_chance = FALSE
	speed = 4
	maxHealth = 150
	health = 150
	stop_automated_movement_when_pulled = TRUE
	stop_automated_movement = TRUE
	wander = FALSE

/mob/living/simple_animal/hostage/New()
	..()
	icon_state = "hostage_m[rand(1,5)]"
	icon_living = icon_state
	icon_dead = "[icon_state]_dead"
	update_icons()

/mob/living/simple_animal/civilian
	name = "civilian"
	desc = "An innocent civilian, just minding his civilian business."
	icon = 'icons/mob/npcs.dmi'
	icon_state = "civilian_1"
	icon_living = "civilian_1"
	icon_dead = "civilian_1_dead"
	meat_amount = 0
	var/list/harmer_factions = list("Redmenia" = 0, "Blugoslavia" = 0)
	var/announce_death = FALSE
	var/uniquenum = 0
/mob/living/simple_animal/civilian/New()
	..()
	uniquenum = rand(10000,99999)
	icon_state = "civilian_[rand(1,9)]"
	if (map && map.ID == MAP_BANK_ROBBERY)
		icon_state = pick("civilian_[rand(1,2)]","civilian_5]","civilian_[rand(7,9)]","hostage_m[rand(1,3)]")
		harmer_factions = list("Police" = 0, "Robbers" = 0)
	icon_living = icon_state
	icon_dead = "[icon_state]_dead"
	update_icons()

var/global/civvies_killed = list()
/mob/living/simple_animal/civilian/death()
	..()
	if(uniquenum in civvies_killed)
		return
	var/killer = "none"
	var/obj/map_metadata/campaign/CM = map
	var/obj/map_metadata/bank_robbery/BR = map
	if (map.ID == MAP_CAMPAIGN && CM)
		if (harmer_factions["Redmenia"] > harmer_factions["Blugoslavia"])
			killer = "Redmenia"
		else if (harmer_factions["Redmenia"] < harmer_factions["Blugoslavia"])
			killer = "Blugoslavia"
		else if (harmer_factions["Redmenia"] == harmer_factions["Blugoslavia"] && harmer_factions["Blugoslavia"] > 0)
			killer = "both factions"
		if (killer != "none")
			var/msg = "Civilian ([name]-[uniquenum]) killed by [killer] at ([src.x],[src.y],[src.z])!"
			civvies_killed += list(uniquenum)
			switch(killer)
				if("Blugoslavia")
					if(announce_death)
						world << "<font size=4>The <b>[name]</b> was killed by <font color='blue'><b>[killer]</b></font>!</font>"
					CM.civilians_killed["Blugoslavia"]++
				if("Redmenia")
					if(announce_death)
						world << "<font size=4>The <b>[name]</b> was killed by <font color='red'><b>[killer]</b></font>!</font>"
					CM.civilians_killed["Redmenia"]++
			harmer_factions = list("Redmenia" = 0, "Blugoslavia" = 0)
			game_log("CIVDEATH: [msg]")
			message_admins(msg)
	else if (map.ID == MAP_BANK_ROBBERY && BR)
		if (harmer_factions["Police"] > harmer_factions["Robbers"])
			killer = "Police"
		else if (harmer_factions["Police"] < harmer_factions["Robbers"])
			killer = "Robbers"
		else if (harmer_factions["Police"] == harmer_factions["Robbers"] && harmer_factions["Robbers"] > 0)
			killer = "both sides"
		if (BR.civilians_killed["Robbers"] == 4)
			world << "<font size=3><span class = 'warning'>At least 4 additional civilians have been killed: the situation is critical!</span></font>"
		if (BR.civilians_killed["Robbers"] == 5)
			world << "<span class = 'danger'>Too many civilians have been killed: Additional SWAT units are on the way!</span>"
		if (killer != "none")
			civvies_killed += list(uniquenum)
			switch(killer)
				if("Robbers")
					world << "<font size=2>A <b>[name]</b> has been killed by the <font color='red'><b>[killer]</b></font>!</font>"
					BR.civilians_killed["Robbers"]++
				if("Police")
					world << "<font size=2>A <b>[name]</b> has been killed by the <font color='blue'><b>[killer]</b></font>!</font>"
					BR.civilians_killed["Police"]++
	else
		var/msg = "Civilian ([name]-[uniquenum]) killed by UNKNOWN at ([src.x],[src.y],[src.z])!"
		game_log("CIVDEATH: [msg]")
		message_admins(msg)
/mob/living/simple_animal/civilian/bullet_act(var/obj/item/projectile/P, var/def_zone)
	if (P.damage == 0)
		return // fix for strange bug
	if (P.firer && ishuman(P.firer))
		var/mob/living/human/H = P.firer
		var/obj/map_metadata/bank_robbery/BR = map
		if (BR && map.ID == MAP_BANK_ROBBERY)
			if (H.faction_text == CIVILIAN)
				harmer_factions["Police"]++
			else if (H.faction_text == AMERICAN)
				harmer_factions["Robbers"]++
		else
			if(H.faction_text == PIRATES)
				harmer_factions["Redmenia"]++
			else if(H.faction_text == CIVILIAN)
				harmer_factions["Blugoslavia"]++
	..()

/mob/living/simple_animal/civilian/attack_hand(mob/living/human/M as mob)
	if(M.a_intent == I_DISARM || M.a_intent == I_HARM)
		if (map && map.ID == MAP_BANK_ROBBERY)
			if (M.faction_text == CIVILIAN)
				harmer_factions["Police"]++
			else if (M.faction_text == AMERICAN)
				harmer_factions["Robbers"]++
		else
			if(M.faction_text == PIRATES)
				harmer_factions["Redmenia"]++
			else if(M.faction_text == CIVILIAN)
				harmer_factions["Blugoslavia"]++
	..()
/mob/living/simple_animal/civilian/attackby(var/obj/item/O, var/mob/user)
	if (ishuman(user))
		var/mob/living/human/H = user
		if (map && map.ID == MAP_BANK_ROBBERY)
			if (H.faction_text == CIVILIAN)
				harmer_factions["Police"]++
			else if (H.faction_text == AMERICAN)
				harmer_factions["Robbers"]++
		else
			if(H.faction_text == PIRATES)
				harmer_factions["Redmenia"]++
			else if(H.faction_text == CIVILIAN)
				harmer_factions["Blugoslavia"]++
	..()

/mob/living/simple_animal/civilian/greenistani_ambassador
	name = "Greenistani Ambassador"
	desc = "The ambassator of Greenistan. Keep him safe!"
	icon_state = "greenistani_2"
	icon_living = "greenistani_2"
	icon_dead = "greenistani_2_dead"
	meat_amount = 0
	announce_death = TRUE
	New()
		..()
		icon_state = "greenistani_2"
		icon_living = "greenistani_2"
		icon_dead = "greenistani_2_dead"
		update_icons()