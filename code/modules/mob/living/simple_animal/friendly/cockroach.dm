/mob/living/simple_animal/cockroach
	name = "cockroach"
	real_name = "cockroach"
	desc = "ewwwwww!"
	icon_state = "cockroach"
	item_state = "cockroach"
	icon_living = "cockroach"
	icon_dead = "dead_cockroach"
	icon = 'icons/mob/critter.dmi'
	speak = list("Chitter!","Chatter!","Click!")
	speak_emote = list("clicks","chitters","chatters")
	emote_hear = list("clicks","chitters","chatters")
	emote_see = list("skitters around", "hops", "waves it's antennae")
	pass_flags = PASSTABLE
	speak_chance = TRUE
	move_to_delay = 5
	see_in_dark = 6
	maxHealth = 5
	health = 5
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "squishes"
	density = FALSE
	layer = MOB_LAYER
	universal_speak = FALSE
	universal_understand = TRUE
	mob_size = MOB_MINISCULE
	possession_candidate = TRUE

	can_pull_size = TRUE
	can_pull_mobs = MOB_PULL_NONE
	scavenger = 1

/mob/living/simple_animal/cockroach/New()
	..()


/mob/living/simple_animal/cockroach/death()
	layer = MOB_LAYER
	..()
	new/obj/item/weapon/reagent_containers/food/snacks/cockroach(src.loc)
	qdel(src)

/mob/living/simple_animal/cockroach/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (stat != DEAD)
		return ..()
	if (!istype(W) || !W.sharp)
		return ..()

/mob/living/simple_animal/cockroach/handle_mutations_and_radiation()
	return

/mob/living/simple_animal/cockroach/rad_act()
	return