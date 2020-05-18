/mob/living/simple_animal/hostile/poison
	var/poison_per_bite = 0
	var/poison_type = "toxin"


/mob/living/simple_animal/hostile/poison/snake
	name = "snake"
	desc = "A slithery snake. These legless reptiles are the bane of mice and adventurers alike."
	icon_state = "snake"
	icon_living = "snake"
	icon_dead = "snake_dead"
	speak_emote = list("hisses")
	health = 20
	maxHealth = 20
	move_to_delay = 2
	attacktext = "bites"
	melee_damage_lower = 5
	melee_damage_upper = 6
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "steps on"
	faction = list("hostile")
	density = FALSE
	pass_flags = PASSTABLE
	mob_size = MOB_SMALL
	behaviour = "defends"

/mob/living/simple_animal/hostile/poison/snake/AttackingTarget()
	var/damage = pick(melee_damage_lower, melee_damage_upper)
	if (!Adjacent(target_mob))
		return

	if(istype(target_mob, /mob/living/simple_animal/mouse))
		visible_message("<span class='notice'>[name] consumes [target_mob] in a single gulp!</span>", "<span class='notice'>You consume [target_mob] in a single gulp!</span>")
		qdel(target_mob)
		adjustBruteLoss(-2)
	else
		custom_emote(1, "bites [target_mob]!")
		if (ishuman(target_mob))
			var/mob/living/human/H = target_mob
			var/dam_zone = pick("l_leg", "r_leg")
			var/obj/item/organ/external/affecting = H.get_organ(ran_zone(dam_zone))
			H.apply_damage(5, TOX, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
		else if (isliving(target_mob))
			var/mob/living/L = target_mob
			L.adjustBruteLoss(damage)
			return L

/mob/living/simple_animal/hostile/poison/snake/cobra
	name = "cobra"
	icon_state = "cobra"
	icon_living = "cobra"
	icon_dead = "cobra_dead"
	health = 30
	maxHealth = 30
	melee_damage_lower = 7
	melee_damage_upper = 9

//////////////////////////////////////////////////////////////////////////////////////////////////////////

/mob/living/simple_animal/hostile/poison/snake/constrictor
	name = "boa constrictor"
	desc = "A large constrictor snake. Probably better to not make it angry."
	icon = 'icons/mob/animal_big.dmi'
	icon_state = "boa"
	icon_living = "boa"
	icon_dead = "boa_dead"
	speak_emote = list("hisses")
	health = 60
	maxHealth = 60
	move_to_delay = 2
	attacktext = "bites"
	melee_damage_lower = 2
	melee_damage_upper = 5
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "steps on"
	faction = list("hostile")
	density = FALSE
	mob_size = MOB_MEDIUM
	predatory_carnivore = 1
	carnivore = 1
	layer = 6
	var/constricting = FALSE
	var/mob/living/cons_target = null

/mob/living/simple_animal/hostile/poison/snake/constrictor/update_icons()
	..()
	if (stat == DEAD)
		icon = 'icons/mob/animal_big.dmi'
		icon_state = icon_dead
	else
		if (constricting)
			icon = 'icons/mob/animal_big.dmi'
			icon_state = "boa_overlay"
		else
			icon = 'icons/mob/animal_big.dmi'
			icon_state = icon_living

/mob/living/simple_animal/hostile/poison/snake/constrictor/python
	name = "python"
	icon_state = "python"
	icon_living = "python"
	icon = 'icons/mob/animal.dmi'
	icon_dead = "python_dead"
	health = 45
	maxHealth = 45
	move_to_delay = 2
/mob/living/simple_animal/hostile/poison/snake/constrictor/python/update_icons()
	..()
	if (stat == DEAD)
		icon = 'icons/mob/animal.dmi'
		icon_state = icon_dead
	else
		if (constricting)
			icon = 'icons/mob/animal.dmi'
			icon_state = "python_overlay"
		else
			icon = 'icons/mob/animal.dmi'
			icon_state = icon_living

/mob/living/simple_animal/hostile/poison/snake/constrictor/proc/start_constricting(var/mob/living/L)
	if (!isliving(L))
		return
	stop_automated_movement = TRUE
	constricting = TRUE
	custom_emote(1, "constricts around [target_mob]!")
	do_constricting(L)
/mob/living/simple_animal/hostile/poison/snake/constrictor/proc/do_constricting(var/mob/living/L)
	if (L && L.client)
		L.client.canmove = FALSE
	if (L && loc != L.loc)
		forceMove(L.loc)
		update_icons()
	cons_target = L
	if (L)
		Paralyse(100)
		L.adjustOxyLoss(25)
		L.adjustBrainLoss(5)
		L << "<span class='danger'>You can't breathe!</span>"
		if (L.stat == DEAD)
			constricting = FALSE
			stop_automated_movement = FALSE
			paralysis = 0
			update_icons()
			if (L && L.client)
				L.client.canmove = TRUE
			return
		spawn(22)
			if (L)
				do_constricting(L)

/mob/living/simple_animal/hostile/poison/snake/constrictor/AttackingTarget()
	if (!Adjacent(target_mob))
		return

	if(istype(target_mob, /mob/living/simple_animal/mouse))
		visible_message("<span class='notice'>[name] consumes [target_mob] in a single gulp!</span>", "<span class='notice'>You consume [target_mob] in a single gulp!</span>")
		qdel(target_mob)
		adjustBruteLoss(-2)
	else
		if (isliving(target_mob))
			start_constricting(target_mob)
			return

/mob/living/simple_animal/hostile/poison/snake/constrictor/death()
	..()
	constricting = FALSE
	if (cons_target)
		cons_target.canmove = TRUE
		cons_target = null
	update_icons()
	if (cons_target && cons_target.client)
		cons_target.client.canmove = TRUE