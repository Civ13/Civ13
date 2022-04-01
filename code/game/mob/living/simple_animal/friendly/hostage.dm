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
	var/civilian_wander = TRUE
	var/initial_spot = list(0,0,0)
	var/list/harmer_factions = list("Redmenia" = 0, "Blugoslavia" = 0)
/mob/living/simple_animal/civilian/New()
	..()
	icon_state = "civilian_[rand(1,5)]"
	icon_living = icon_state
	icon_dead = "[icon_state]_dead"
	initial_spot = list("x" = src.x,"y" = src.y, "z" = src.z)
	civilian_wander_proc()
	update_icons()

/mob/living/simple_animal/civilian/death()
	var/killer = "none"
	if (harmer_factions["Redmenia"] > harmer_factions["Blugoslavia"])
		killer = "Redmenia"
	else if (harmer_factions["Redmenia"] < harmer_factions["Blugoslavia"])
		killer = "Blugoslavia"
	else if (harmer_factions["Redmenia"] == harmer_factions["Blugoslavia"] && harmer_factions["Blugoslavia"] > 0)
		killer = "both factions"
	if (killer != "none")
		var/msg = "Civilian killed by [killer] at ([src.x],[src.y],[src.z])!"
		harmer_factions = list("Redmenia" = 0, "Blugoslavia" = 0)
		world.log << "CIVDEATH: [msg]"
		message_admins(msg)
	..()
/mob/living/simple_animal/civilian/bullet_act(var/obj/item/projectile/P, var/def_zone)
	if (P.damage == 0)
		return // fix for strange bug
	if (P.firer && ishuman(P.firer))
		var/mob/living/human/H = P.firer
		if(H.faction_text == PIRATES)
			harmer_factions["Redmenia"]++
		else if(H.faction_text == CIVILIAN)
			harmer_factions["Blugoslavia"]++
	..()

/mob/living/simple_animal/civilian/attack_hand(mob/living/human/M as mob)
	if(M.a_intent == I_DISARM || M.a_intent == I_HARM)
		if(M.faction_text == PIRATES)
			harmer_factions["Redmenia"]++
		else if(M.faction_text == CIVILIAN)
			harmer_factions["Blugoslavia"]++
	..()
/mob/living/simple_animal/civilian/attackby(var/obj/item/O, var/mob/user)
	if (ishuman(user))
		var/mob/living/human/H = user
		if(H.faction_text == PIRATES)
			harmer_factions["Redmenia"]++
		else if(H.faction_text == CIVILIAN)
			harmer_factions["Blugoslavia"]++
	..()
/mob/living/simple_animal/civilian/proc/civilian_wander_proc()
	if (!civilian_wander)
		return
	if (buckled)
		return
	if (stat != CONSCIOUS)
		return
	var/atom/init_loc = locate(initial_spot["x"],initial_spot["y"],initial_spot["z"])
	if (!init_loc)
		return
	if (get_dist(src,init_loc)<= 5)
		var/moving_to = FALSE
		moving_to = pick(cardinal)
		set_dir(moving_to)
		Move(get_step(src,moving_to))
		turns_since_move = FALSE
	else
		var/dir_to_origin = get_dir(src,init_loc)
		set_dir(dir_to_origin)
		Move(get_step(src,dir_to_origin))
		turns_since_move = FALSE

	spawn(100)
		civilian_wander_proc()