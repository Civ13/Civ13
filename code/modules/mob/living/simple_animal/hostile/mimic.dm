/mob/living/simple_animal/hostile/mimic
	name = "mimic"
	desc = "Thats no treasure chest!"
	icon_state = "mimic"
	icon_living = "mimic"
	icon_dead = "none"
	icon_gib = "none"
	speak = list("clatter","drool","rattle","creak")
	speak_emote = list("clatters", "creaks")
	emote_hear = list("clatters","creaks","shivers")
	emote_see = list("looks hungry", "starts drooling")
	speak_chance = TRUE
	move_to_delay = 5
	see_in_dark = 8
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/bearmeat
	response_help  = "opens"
	response_disarm = "opens"
	response_harm   = "kicks"
	stop_automated_movement_when_pulled = FALSE
	maxHealth = 120
	health = 120
	melee_damage_lower = 15
	melee_damage_upper = 25
	mob_size = MOB_LARGE

	var/activeicon = 'icons/mob/animal.dmi'
	var/activeicon_state = "mimic"
	var/idleicon = 'icons/obj/storage.dmi'
	var/idleicon_state = "treasure_chest"

	var/btype = ""

	faction = "neutral"

/mob/living/simple_animal/hostile/mimic/death()
	new/obj/structure/closet/crate/loottreasurechest(src.loc)
	..()
	qdel(src)
