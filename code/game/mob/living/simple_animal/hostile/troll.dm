
/mob/living/simple_animal/hostile/troll
	name = "troll"
	desc = "Huge green troll."
	icon = 'icons/mob/animal_64.dmi'
	icon_state = "green_troll"
	icon_living = "green_troll"
	icon_dead = "green_troll_dead"
	icon_gib = "green_troll_dead"
	speak = list("UUUURGH!","UUUH!","WAAAARGH!")
	speak_emote = list("grunts", "screams")
	emote_hear = list("grunts","grunts")
	emote_see = list("stares ferociously", "grunts")
	speak_chance = TRUE
	move_to_delay = 8
	see_in_dark = 8
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "pokes"
	stop_automated_movement_when_pulled = FALSE
	maxHealth = 140
	health = 140
	melee_damage_lower = 35
	melee_damage_upper = 40
	mob_size = MOB_LARGE
	faction = "neutral"

