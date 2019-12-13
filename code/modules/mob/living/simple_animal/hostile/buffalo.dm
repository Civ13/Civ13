
/mob/living/simple_animal/hostile/buffalo
	name = "buffalo"
	desc =  "A Large member of the Bovine Family, They are grazers and will be hostile if harmed."
	icon = 'icons/mob/animal_64.dmi'
	icon_state = "buffalo"
	icon_living = "buffalo"
	icon_dead = "buffalo_dead"
	speak_emote = list("Gnnnnnrrrr", "Moooooo", "Pnhhhh")
	emote_hear = list("Grunts", "Puffs")
	health = 350
	maxHealth = 350
	move_to_delay = 5
	turns_per_move = 4
	attacktext = "charges into"
	melee_damage_lower = 35
	melee_damage_upper = 50
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "punches"
	faction = list("neutral")
	mob_size = MOB_LARGE
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	behaviour = "defends"

/mob/living/simple_animal/hostile/buffalo/AttackingTarget()
	var/damage = pick(melee_damage_lower, melee_damage_upper)
	if (!Adjacent(target_mob))
		return
	else
		custom_emote(1, "tackles [target_mob]!")
		if (ishuman(target_mob))
			var/mob/living/carbon/human/H = target_mob
			var/dam_zone = pick("l_leg", "r_leg")
			var/obj/item/organ/external/affecting = H.get_organ(ran_zone(dam_zone))
			H.apply_damage(40, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
		else if (isliving(target_mob))
			var/mob/living/L = target_mob
			L.adjustBruteLoss(damage)
			return L
