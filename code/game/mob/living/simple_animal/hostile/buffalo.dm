/mob/living/simple_animal/hostile/buffalo
	name = "buffalo"
	desc =  "A large member of the bovine Family, they are grazers and will be hostile if harmed."
	icon = 'icons/mob/animal_64.dmi'
	icon_state = "buffalo"
	icon_living = "buffalo"
	icon_dead = "buffalo_dead"
	speak_emote = list("Gnnnnnrrrr", "Moooooo", "Pnhhhh")
	emote_hear = list("Grunts", "Puffs")
	health = 350
	maxHealth = 350
	move_to_delay = 5
	attacktext = "charges into"
	melee_damage_lower = 35
	melee_damage_upper = 50
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "punches"
	faction = list("bison")
	mob_size = MOB_LARGE
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	behaviour = "defends"
	fat_extra = 3

/mob/living/simple_animal/bison
	name = "bison cow"
	desc =  "A large member of the bovine family, they are grazers commonly found in herds and will be hostile if harmed."
	icon = 'icons/mob/animal_64.dmi'
	icon_state = "bison_cow"
	icon_living = "bison_cow"
	icon_dead = "bison_cow_dead"
	speak_emote = list("Gnnnnnrrrr", "Moooooo", "Pnhhhh")
	emote_hear = list("Grunts", "Puffs")
	emote_see = list("stomps")
	health = 350
	maxHealth = 350
	move_to_delay = 5
	attacktext = "charges into"
	melee_damage_lower = 25
	melee_damage_upper = 30
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "gores"
	attacktext = "gores"
	var/calf = FALSE
	var/datum/reagents/udder = null
	var/pregnant = FALSE
	var/birthCountdown = 0
	var/overpopulationCountdown = 0
	faction = list("bison")
	mob_size = MOB_LARGE
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	wandersounds = list('sound/animals/cow/cow_1.ogg','sound/animals/cow/cow_2.ogg')
	hostilesounds = list('sound/animals/cow/cow_1.ogg','sound/animals/cow/cow_3.ogg')
	behaviour = "wander"
	fat_extra = 3

/mob/living/simple_animal/bisonbull
	name = "bison bull"
	desc =  "A large member of the bovine family, they are grazers commonly found in herds and will be hostile if harmed."
	icon = 'icons/mob/animal_64.dmi'
	icon_state = "bisonbull"
	icon_living = "bisonbull"
	icon_dead = "bisonbull_dead"
	speak_emote = list("Gnnnnnrrrr", "Moooooo", "Pnhhhh")
	emote_hear = list("Grunts", "Puffs")
	emote_see = list("stomps")
	health = 350
	maxHealth = 350
	move_to_delay = 5
	attacktext = "charges into"
	melee_damage_lower = 35
	melee_damage_upper = 50
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "gores"
	attacktext = "gores"
	var/calf = FALSE
	faction = list("bison")
	mob_size = MOB_LARGE
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	wandersounds = list('sound/animals/cow/cow_1.ogg','sound/animals/cow/cow_2.ogg')
	hostilesounds = list('sound/animals/cow/cow_1.ogg','sound/animals/cow/cow_3.ogg')
	behaviour = "wander"
	fat_extra = 3

/mob/living/simple_animal/bison/death()

	bison_count &= src
	..()
/mob/living/simple_animal/bison/Destroy()

	bison_count &= src
	..()
/mob/living/simple_animal/bisonbull/death()

	bison_count &= src
	..()
/mob/living/simple_animal/bisonbull/Destroy()

	bison_count &= src
	..()
/mob/living/simple_animal/bisonbull/New()
	bison_count |= src
	..()
	spawn(1)
		if (calf)
			icon_state = "bison_calf"
			icon_living = "bison_calf"
			icon_dead = "bison_calf_dead"
			meat_amount = 2
			mob_size = MOB_SMALL
			spawn(3000)
				calf = FALSE
				icon_state = "bisonbull"
				icon_living = "bisonbull"
				icon_dead = "bisonbull_dead"
				mob_size = MOB_LARGE

/mob/living/simple_animal/bison/New()
	bison_count |= src
	udder = new(50)
	udder.my_atom = src
	..()
	spawn(1)
		if (calf)
			icon_state = "bison_calf"
			icon_living = "bison_calf"
			icon_dead = "bison_calf_dead"
			meat_amount = 2
			udder.remove_reagent("milk")
			mob_size = MOB_SMALL
			spawn(3000)
				calf = FALSE
				icon_state = "bison_cow"
				icon_living = "bison_cow"
				icon_dead = "bison_cow_dead"
				mob_size = MOB_LARGE

/mob/living/simple_animal/bison/attackby(var/obj/item/O as obj, var/mob/user as mob) //need some code to make them tempoarily calm or flip out after milking to make it risky.
	var/obj/item/weapon/reagent_containers/glass/G = O
	if (stat == CONSCIOUS && istype(G) && G.is_open_container())
		user.visible_message("<span class='notice'>[user] milks [src] using \the [O].</span>")
		var/transfered = udder.trans_id_to(G, "milk", rand(5,10))
		if (G.reagents.total_volume >= G.volume)
			user << "<span class = 'red'>The [O] is full.</span>"
		if (!transfered)
			user << "<span class = 'red'>The udder is dry. Wait a bit.</span>"
	else
		..()

/mob/living/simple_animal/bison/Life()
	. = ..()
	if (stat == CONSCIOUS)
		if (udder && prob(5) && !calf)
			udder.add_reagent("milk", rand(5, 10))
	else
		return

	if (overpopulationCountdown > 0) //don't do any checks while overpopulation is in effect
		overpopulationCountdown--
		return

	if (!pregnant && bison_count.len < 30)
		var/nearbyObjects = range(1,src) //3x3 area around cow
		for(var/mob/living/simple_animal/bisonbull/M in nearbyObjects)
			if (M.stat == CONSCIOUS)
				pregnant = TRUE
				birthCountdown = 600
				break

		if (pregnant)
			nearbyObjects = range(7,src) //15x15 area around cow

			var/bisonCount = 0
			for(var/mob/living/simple_animal/bison/M in nearbyObjects)
				if (M.stat == CONSCIOUS)
					bisonCount++

			for(var/mob/living/simple_animal/bisonbull/M in nearbyObjects)
				if (M.stat == CONSCIOUS)
					bisonCount++

			if (bisonCount > 5) // max 5 cows/bulls in a 15x15 area around cow
				overpopulationCountdown = 300
				pregnant = FALSE
	else if (pregnant)
		birthCountdown--
		if (birthCountdown <= 0)
			pregnant = FALSE
			if (prob(50))
				var/mob/living/simple_animal/bison/C = new/mob/living/simple_animal/bison(loc)
				C.calf = TRUE
			else
				var/mob/living/simple_animal/bisonbull/B = new/mob/living/simple_animal/bisonbull(loc)
				B.calf = TRUE
			visible_message("A calf has been born!")