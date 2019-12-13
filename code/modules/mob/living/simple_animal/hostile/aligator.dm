
/mob/living/simple_animal/hostile/alligator
	name = "alligator"
	desc = "probably not safe to get close to it..."
	icon = 'icons/mob/animal_big.dmi'
	icon_state = "alligator"
	icon_living = "alligator"
	icon_dead = "alligator_dead"
	icon_gib = "alligator_gib"
	speak = list("hisss","rrrww!","FFFF!","krrrr")
	speak_emote = list("bellow", "hiss")
	emote_hear = list("bellows","hisses","snaps")
	emote_see = list("stares ferociously", "stomps")
	speak_chance = TRUE
	turns_per_move = 12
	move_to_delay = 8
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "pokes"
	stop_automated_movement_when_pulled = FALSE
	maxHealth = 120
	health = 120
	melee_damage_lower = 20
	melee_damage_upper = 30
	mob_size = MOB_LARGE
	predatory_carnivore = 1
	carnivore = 1

	faction = "neutral"

/mob/living/simple_animal/hostile/alligator/AttackingTarget()
	if (!Adjacent(target_mob))
		return
	custom_emote(1, pick( list("bites [target_mob]!") ) )

	var/damage = pick(melee_damage_lower,melee_damage_upper)

	if (ishuman(target_mob))
		var/mob/living/carbon/human/H = target_mob
		var/dam_zone = pick("l_hand", "r_hand", "l_leg", "r_leg")
		var/obj/item/organ/external/affecting = H.get_organ(ran_zone(dam_zone))
		if (prob(95))
			H.apply_damage(damage, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
		else
			affecting.droplimb(FALSE, DROPLIMB_EDGE)
			visible_message("\The [src] bites off [H]'s limb!")
			for(var/mob/living/carbon/human/NB in view(6,src))
				NB.mood -= 10
		return H
	else if (isliving(target_mob))
		var/mob/living/L = target_mob
		L.adjustBruteLoss(damage)
		return L