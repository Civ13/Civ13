// backend member functions for complex_animals, which call frontend hooks
/mob/living/simple_animal/complex_animal/New()
	..()
	resting_state = "[icon_state]_rest"
	dead_state = "[icon_state]_dead"
	icon_dead = dead_state

/mob/living/simple_animal/complex_animal/Life()
	..()
	onEveryLifeTick()

/mob/living/simple_animal/complex_animal/death(gibbed, deathmessage = "dies!")
	..(gibbed,deathmessage)
	icon_state = dead_state

/mob/living/simple_animal/complex_animal/proc/taming(var/mob/living/human/H, var/value = 0)
	if (!can_be_tamed)
		return
	if (!tamed)
		var/found = FALSE
		if (value != 0)
			if (friendly_mobs[H.name] && friendly_mobs[H.name][1] == H)
				found = TRUE
				friendly_mobs[H.name][2] += value
				check_tame_stat(H)
				return
			if (found == FALSE)
				friendly_mobs += list("[H.name]" = list(H,value))
				check_tame_stat(H)
				return
	else
		return
/mob/living/simple_animal/complex_animal/proc/check_tame_stat(var/mob/living/human/H)
	if (!can_be_tamed)
		return
	if (friendly_mobs[H.name] && friendly_mobs[H.name][1] == H)
		if (friendly_mobs[H.name][2] >= tameminimum && !owner && !tamed)
			owner = H
			H << "The [src] really likes you! It now sees you as it's owner!"
			owner = H
			if (map.civilizations)
				faction = H.civilization
			else
				faction = H.faction_text
			tamed = TRUE
			if (findtext(name, "Wild"))
				name = replacetext(name,"Wild", "[H]'s")
		return
/mob/living/simple_animal/complex_animal/attack_hand(var/mob/living/human/H as mob)
	..(H)
	onTouchedBy(H, H.a_intent)

/mob/living/simple_animal/complex_animal/attackby(var/obj/item/weapon/W as obj, var/mob/living/human/H as mob)
	if (can_be_tamed)
		if (H.a_intent == I_HELP)
			if (istype(W, /obj/item/weapon/reagent_containers/food))
				if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/meat))
					var/obj/item/weapon/reagent_containers/food/snacks/meat/MT = W
					if (MT.rotten)
						H << "The meat is rotten! \The [src] doesn't want it..."
						taming(H, -1)
						return
					else if (MT.reagents.has_reagent("protein",1))
						nutrition += 18*MT.reagents.get_reagent_amount("protein")
						H << "\The [src] eats \the [MT] and wags it's tail in happiness!"
						taming(H, 5)
						H.drop_from_inventory(W)
						qdel(W)
						return
				else
					H << "\The [src] sniffs the [W] but does not eat it."
					return
	..(W, H)
	onAttackedBy(H, W)

// movement detection
/mob/living/simple_animal/complex_animal/Move()
	..()
	// I used to do a 'in range(30, src)' check here, it caused MASSIVE cpu usage
	for (var/mob/living/L in living_mob_list)
		if (L == src)
			continue
		if (istype(L, /mob/living/simple_animal/complex_animal))
			var/mob/living/simple_animal/complex_animal/C = L
			// range() can get extremely expensive so do this insteads
			var/dist_x = abs(x - C.x)
			var/dist_y = abs(x - C.y)
			if (prob(90) && dist_x <= C.sightrange && dist_y <= C.sightrange)
				C.knows_about_mobs |= src
			else if (prob(45) && dist_x <= C.hearrange && dist_y <= C.hearrange)
				C.knows_about_mobs |= src
			else if (prob(22) && dist_x <= C.smellrange && dist_y <= C.smellrange)
				C.knows_about_mobs |= src
			else if (vars.Find("base_type") && src:base_type == C.base_type)
				if (dist_x <= 10 && dist_y <= 10)
					C.onEveryBaseTypeMovement(src)
			else
				if (dist_x <= 10 && dist_y <= 10)
					C.onEveryXMovement(type)