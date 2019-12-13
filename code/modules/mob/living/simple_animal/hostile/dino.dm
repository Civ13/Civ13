
/mob/living/simple_animal/hostile/dinosaur/velociraptor
	name = "velociraptor"
	desc = "Yep. You are fucked."
	icon = 'icons/mob/animal_big.dmi'
	icon_state = "velociraptor"
	icon_living = "velociraptor"
	icon_dead = "velociraptor_dead"
	icon_gib = "velociraptor_dead"
	speak = list("hisss","kkk!","krrrr")
	speak_emote = list("bellow", "hiss")
	emote_hear = list("bellows","hisses")
	emote_see = list("stares ferociously", "grunts")
	speak_chance = TRUE
	turns_per_move = 3
	move_to_delay = 3
	see_in_dark = 6
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
	predatory_carnivore = 1
	carnivore = 1
	faction = "neutral"


/mob/living/simple_animal/hostile/dinosaur/velociraptor/AttackingTarget()
	if (!Adjacent(target_mob))
		return
	custom_emote(1, pick( list("bites [target_mob]!") ) )

	var/damage = pick(melee_damage_lower,melee_damage_upper)

	if (ishuman(target_mob))
		var/mob/living/carbon/human/H = target_mob
		var/dam_zone = pick("l_hand", "r_hand", "l_leg", "r_leg")
		var/obj/item/organ/external/affecting = H.get_organ(ran_zone(dam_zone))
		if (prob(90))
			H.apply_damage(damage, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
		else
			affecting.droplimb(FALSE, DROPLIMB_EDGE)
			visible_message("\The [src] bites off [H]'s limb!")
			for(var/mob/living/carbon/human/NB in view(6,src))
				NB.mood -= 12
		return H
	else if (isliving(target_mob))
		var/mob/living/L = target_mob
		L.adjustBruteLoss(damage)
		return L