
/mob/living/simple_animal/hostile/sabertooth
	name = "Sabertooth"
	desc = "A Prehistoric mammal, with a distinctive pair of long razor sharp canine teeth, Don't get caught by one."
	icon = 'icons/mob/animal_64.dmi'
	icon_state = "sabertooth_brown"
	icon_living = "sabertooth_brown"
	icon_dead = "sabertooth_brown_dead"
	speak = list("GRRR!","rawrr","RAWR!","RRRRR!")
	speak_emote = list("growls", "roars")
	emote_hear = list("growls","roars","buffs")
	emote_see = list("stares ferociously", "sniffs the ground")
	speak_chance = TRUE
	turns_per_move = 5
	move_to_delay = 3
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "pokes"
	stop_automated_movement_when_pulled = FALSE
	maxHealth = 75
	health = 75
	melee_damage_lower = 22
	melee_damage_upper = 44
	mob_size = MOB_MEDIUM

	faction = "hostile"

/mob/living/simple_animal/hostile/sabertooth/white
	name = "Sabertooth"
	desc = "A Prehistoric mammal, with a distinctive pair of long razor sharp canine teeth, Don't get caught by one."
	icon_state = "sabertooth_white"
	icon_living = "sabertooth_white"
	icon_dead = "sabertooth_white_dead"

/mob/living/simple_animal/hostile/sabertooth/AttackingTarget()
	if (!Adjacent(target_mob))
		return
	if(prob(50))
		playsound(src.loc, 'sound/weapons/bite.ogg', 100, TRUE, 2)
	else
		playsound(src.loc, 'sound/weapons/bite_2.ogg', 100, TRUE, 2)
	custom_emote(1, pick( list("slashes at [target_mob]!", "bites [target_mob]!") ) )

	var/damage = pick(melee_damage_lower,melee_damage_upper)

	if (ishuman(target_mob))
		var/mob/living/carbon/human/H = target_mob
		var/dam_zone = pick("chest", "l_hand", "r_hand", "l_leg", "r_leg")
		var/obj/item/organ/external/affecting = H.get_organ(ran_zone(dam_zone))
		H.apply_damage(damage, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
		return H
	else if (isliving(target_mob))
		var/mob/living/L = target_mob
		L.adjustBruteLoss(damage)
		return L