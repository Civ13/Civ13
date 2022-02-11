/mob/living/simple_animal/leech
	name = "leech"
	desc = "A bloodsucking leech."
	icon = 'icons/mob/critter.dmi'
	icon_state = "leech"
	icon_living = "leech"
	icon_dead = "leech-dead"
	health = 5
	maxHealth = 5
	attacktext = "bitten"
	melee_damage_lower = TRUE
	melee_damage_upper = 2
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "stomps on"
	mob_size = MOB_MINISCULE
	possession_candidate = TRUE

/mob/living/simple_animal/leech/attack_hand(mob/living/human/M as mob)
	if (stat == DEAD)
		M << "This leech is dead, no point in picking it up."
	else
		M.put_in_hands(new/obj/item/weapon/leech)
		M << "You pick up the leech."
		qdel(src)

/obj/item/weapon/leech
	name = "leech"
	desc = "A bloodsucking leech."
	icon = 'icons/mob/critter.dmi'
	icon_state = "leech_h"
	var/fill = 0
	value = 0
	flags = FALSE
/obj/item/weapon/leech/New()
	..()
	if (fill)
		desc = "A bloodsucking leech. It's full of blood!"
	else
		desc = "A bloodsucking leech."

/obj/item/weapon/leech/proc/emptyit()
	if (fill)
		spawn(1200)
			fill = 0
			desc = "A bloodsucking leech."
			return

/obj/item/weapon/leech/attack(var/mob/living/human/C, var/mob/living/user)
	visible_message("[user] starts to attach the leech to [C]...")
	if (do_after(user,150,src))
		visible_message("[user] has finished leeching [C].")
		fill = 1
		C.adjustToxLoss(-7)
		C.vessel.remove_reagent("blood", 85)
		desc = "A bloodsucking leech. It's full of blood!"
		emptyit()
		return