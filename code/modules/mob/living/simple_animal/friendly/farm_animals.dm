//cow
/mob/living/simple_animal/cow
	name = "cow"
	desc = "Known for their milk, just don't tip them over."
	icon_state = "cow"
	icon_living = "cow"
	icon_dead = "cow_dead"
	icon_gib = "cow_gib"
	speak = list("moo?","moo","MOOOOOO")
	speak_emote = list("moos","moos hauntingly")
	emote_hear = list("brays")
	emote_see = list("shakes its head")
	speak_chance = TRUE
	turns_per_move = 5
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 6
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 50
	var/calf = FALSE
	var/datum/reagents/udder = null
	var/pregnant = FALSE
	var/birthCountdown = 0
	var/overpopulationCountdown = 0
	mob_size = MOB_LARGE
	herbivore = 1

/mob/living/simple_animal/bull
	name = "bull"
	desc = "Good for meat."
	icon_state = "bull"
	icon_living = "bull"
	icon_dead = "bull_dead"
	icon_gib = "cow_gib"
	speak = list("moo?","moo","MOOOOOO")
	speak_emote = list("moos","moos hauntingly")
	emote_hear = list("brays")
	emote_see = list("shakes its head")
	speak_chance = TRUE
	turns_per_move = 5
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 6
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	var/calf = FALSE
	health = 65
	mob_size = MOB_LARGE
	herbivore = 1

/mob/living/simple_animal/cow/death()
	..()
	cow_count -= 1

/mob/living/simple_animal/bull/death()
	..()
	cow_count -= 1

/mob/living/simple_animal/bull/New()
	cow_count += 1
	..()
	spawn(1)
		if (calf)
			icon_state = "calf"
			icon_living = "calf"
			icon_dead = "calf_dead"
			meat_amount = 2
			mob_size = MOB_SMALL
			spawn(3000)
				calf = FALSE
				icon_state = "bull"
				icon_living = "bull"
				icon_dead = "bull_dead"
				mob_size = MOB_LARGE

/mob/living/simple_animal/cow/New()
	cow_count += 1
	udder = new(50)
	udder.my_atom = src
	..()
	spawn(1)
		if (calf)
			icon_state = "calf"
			icon_living = "calf"
			icon_dead = "calf_dead"
			meat_amount = 2
			udder.remove_reagent("milk")
			mob_size = MOB_SMALL
			spawn(3000)
				calf = FALSE
				icon_state = "cow"
				icon_living = "cow"
				icon_dead = "cow_dead"
				mob_size = MOB_LARGE

/mob/living/simple_animal/cow/attackby(var/obj/item/O as obj, var/mob/user as mob)
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

/mob/living/simple_animal/cow/Life()
	. = ..()
	if (stat == CONSCIOUS)
		if (udder && prob(5) && !calf)
			udder.add_reagent("milk", rand(5, 10))
	else
		return

	if (overpopulationCountdown > 0) //don't do any checks while overpopulation is in effect
		overpopulationCountdown--
		return

	if (!pregnant && cow_count < 30)
		var/nearbyObjects = range(1,src) //3x3 area around cow
		for(var/mob/living/simple_animal/bull/M in nearbyObjects)
			if (M.stat == CONSCIOUS)
				pregnant = TRUE
				birthCountdown = 600
				break

		if (pregnant)
			nearbyObjects = range(7,src) //15x15 area around cow

			var/cowCount = 0
			for(var/mob/living/simple_animal/cow/M in nearbyObjects)
				if (M.stat == CONSCIOUS)
					cowCount++

			for(var/mob/living/simple_animal/bull/M in nearbyObjects)
				if (M.stat == CONSCIOUS)
					cowCount++

			if (cowCount > 5) // max 5 cows/bulls in a 15x15 area around cow
				overpopulationCountdown = 300
				pregnant = FALSE
	else if (pregnant)
		birthCountdown--
		if (birthCountdown <= 0)
			pregnant = FALSE
			if (prob(50))
				var/mob/living/simple_animal/cow/C = new/mob/living/simple_animal/cow(loc)
				C.calf = TRUE
			else
				var/mob/living/simple_animal/bull/B = new/mob/living/simple_animal/bull(loc)
				B.calf = TRUE
			visible_message("A calf has been born!")

/mob/living/simple_animal/cow/attack_hand(mob/living/carbon/M as mob)
	if (!stat && M.a_intent == I_DISARM && icon_state != icon_dead)
		M.visible_message("<span class='warning'>[M] tips over [src].</span>","<span class='notice'>You tip over [src].</span>")
		Weaken(30)
		icon_state = icon_dead
		spawn(rand(20,50))
			if (!stat && M)
				icon_state = icon_living
				var/list/responses = list(	"[src] looks at you imploringly.",
											"[src] looks at you pleadingly",
											"[src] looks at you with a resigned expression.",
											"[src] seems resigned to its fate.")
				M << pick(responses)
	else
		..()

//goat
/mob/living/simple_animal/goat
	name = "goat ram"
	desc = "A male goat. Not known for their pleasant disposition."
	icon_state = "goat_ram"
	icon_living = "goat_ram"
	icon_dead = "goat_ram_dead"
	speak = list("EHEHEHEHEH","eh?")
	speak_emote = list("brays")
	emote_hear = list("brays")
	emote_see = list("shakes its head", "stamps a foot", "glares around")
	speak_chance = 1
	turns_per_move = 5
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 3
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	faction = list("neutral")
	attacktext = "kicks"
	attack_sound = 'sound/weapons/punch1.ogg'
	health = 40
	maxHealth = 40
	melee_damage_lower = 2
	melee_damage_upper = 6
	stop_automated_movement_when_pulled = 1
	var/datum/reagents/udder = null
	mob_size = MOB_MEDIUM
	var/lamb = FALSE
	herbivore = 1

/mob/living/simple_animal/goat/New()
	goat_count += 1
	..()
	spawn(1)
		if (lamb)
			icon_state = "goat_lamb"
			icon_living = "goat_lamb"
			icon_dead = "goat_lamb_dead"
			meat_amount = 2
			mob_size = MOB_SMALL
			spawn(3000)
				lamb = FALSE
				icon_state = "goat_ram"
				icon_living = "goat_ram"
				icon_dead = "goat_ram_dead"
				mob_size = MOB_MEDIUM

/mob/living/simple_animal/goat/female
	name = "goat ewe"
	desc = "A female goat. You can milk it."
	icon_state = "goat_ewe"
	icon_living = "goat_ewe"
	icon_dead = "goat_ewe_dead"
	var/pregnant = FALSE
	var/birthCountdown = 0
	var/overpopulationCountdown = 0

/mob/living/simple_animal/goat/death()
	..()
	goat_count -= 1

/mob/living/simple_animal/goat/female/New()
	udder = new(50)
	udder.my_atom = src
	..()
	spawn(1)
		if (lamb)
			icon_state = "goat_lamb"
			icon_living = "goat_lamb"
			icon_dead = "goat_lamb_dead"
			meat_amount = 2
			udder.remove_reagent("milk")
			mob_size = MOB_SMALL
			spawn(3000)
				lamb = FALSE
				icon_state = "goat_ewe"
				icon_living = "goat_ewe"
				icon_dead = "goat_ewe_dead"
				mob_size = MOB_MEDIUM
/mob/living/simple_animal/goat/female/attackby(var/obj/item/O as obj, var/mob/user as mob)
	var/obj/item/weapon/reagent_containers/glass/G = O
	if (stat == CONSCIOUS && istype(G) && G.is_open_container())
		user.visible_message("<span class='notice'>[user] milks [src] using \the [O].</span>")
		var/transfered = udder.trans_id_to(G, "milk", rand(5,10))
		if (G.reagents.total_volume >= G.volume)
			user << "<span class = 'red'>The [O] is full.</span>"
		if (!transfered)
			user << "<span class = 'red'>The udder is dry. Wait a bit.</span>"
		return
	else
		..()

/mob/living/simple_animal/goat/female/Life()
	. = ..()
	if (stat == CONSCIOUS)
		if (udder && prob(5))
			udder.add_reagent("milk", rand(3, 5))

	if (overpopulationCountdown > 0) //don't do any checks while overpopulation is in effect
		overpopulationCountdown--
		return

	if (!pregnant && goat_count < 35)
		var/nearbyObjects = range(1,src) //3x3 area around animal
		for(var/mob/living/simple_animal/goat/M in nearbyObjects)
			if (M.stat == CONSCIOUS && !istype(M, /mob/living/simple_animal/goat/female))
				pregnant = TRUE
				birthCountdown = 600 // life ticks once per 2 seconds, 300 == 10 minutes
				break

		if (pregnant)
			nearbyObjects = range(7,src) //15x15 area around animal

			var/goatCount = 0
			for(var/mob/living/simple_animal/goat/M in nearbyObjects)
				if (M.stat == CONSCIOUS)
					goatCount++


			if (goatCount > 5) // max 5 cows/bulls in a 15x15 area around
				overpopulationCountdown = 300 // 5 minutes
				pregnant = FALSE
	else if (pregnant)
		birthCountdown--
		if (birthCountdown <= 0)
			pregnant = FALSE
			if (prob(50))
				var/mob/living/simple_animal/goat/C = new/mob/living/simple_animal/goat(loc)
				C.lamb = TRUE
			else
				var/mob/living/simple_animal/goat/female/B = new/mob/living/simple_animal/goat/female(loc)
				B.lamb = TRUE
			visible_message("A goat lamb has been born!")

//sheep
/mob/living/simple_animal/sheep
	name = "sheep ram"
	desc = "A male sheep. Good for wool."
	icon_state = "sheep_ram"
	icon_living = "sheep_ram"
	icon_dead = "sheep_ram_dead"
	speak = list("EHEHEHEHEH","eh?")
	speak_emote = list("brays")
	emote_hear = list("brays")
	emote_see = list("shakes its head", "stamps a foot", "glares around")
	speak_chance = 1
	turns_per_move = 5
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 3
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	faction = list("neutral")
	attacktext = "kicks"
	attack_sound = 'sound/weapons/punch1.ogg'
	health = 40
	maxHealth = 40
	melee_damage_lower = 2
	melee_damage_upper = 6
	stop_automated_movement_when_pulled = 1
	var/datum/reagents/udder = null
	mob_size = MOB_MEDIUM
	var/lamb = FALSE
	herbivore = 1
	var/sheared = FALSE

/mob/living/simple_animal/sheep/update_icons()
	..()
	if (sheared)
		icon_state = "sheep_ram_sheared"
		icon_living = "sheep_ram_sheared"
		icon_dead = "sheep_ram_sheared_dead"
	else
		icon_state = "sheep_ram"
		icon_living = "sheep_ram"
		icon_dead = "sheep_ram_dead"

/mob/living/simple_animal/sheep/female/update_icons()
	..()
	if (sheared)
		icon_state = "sheep_ewe_sheared"
		icon_living = "sheep_ewe_sheared"
		icon_dead = "sheep_ewe_sheared_dead"
	else
		icon_state = "sheep_ewe"
		icon_living = "sheep_ewe"
		icon_dead = "sheep_ewe_dead"

/mob/living/simple_animal/sheep/female
	name = "sheep ewe"
	desc = "A female sheep. You can milk it."
	icon_state = "sheep_ewe"
	icon_living = "sheep_ewe"
	icon_dead = "sheep_ewe_dead"
	var/pregnant = FALSE
	var/birthCountdown = 0
	var/overpopulationCountdown = 0
/mob/living/simple_animal/sheep/death()
	..()
	sheep_count -= 1
/mob/living/simple_animal/sheep/New()
	sheep_count += 1
	..()
	spawn(1)
		if (lamb)
			icon_state = "sheep_lamb"
			icon_living = "sheep_lamb"
			icon_dead = "sheep_lamb_dead"
			meat_amount = 2
			mob_size = MOB_SMALL
			spawn(3000)
				lamb = FALSE
				icon_state = "sheep_ram"
				icon_living = "sheep_ram"
				icon_dead = "sheep_ram_dead"
				mob_size = MOB_MEDIUM
/mob/living/simple_animal/sheep/female/New()
	udder = new(50)
	udder.my_atom = src
	..()
	spawn(1)
		if (lamb)
			icon_state = "sheep_lamb"
			icon_living = "sheep_lamb"
			icon_dead = "sheep_lamb_dead"
			meat_amount = 2
			udder.remove_reagent("milk")
			mob_size = MOB_SMALL
			spawn(3000)
				lamb = FALSE
				icon_state = "sheep_ewe"
				icon_living = "sheep_ewe"
				icon_dead = "sheep_ewe_dead"
				mob_size = MOB_MEDIUM

/mob/living/simple_animal/sheep/proc/regrowth()
	spawn(4800)
		sheared = FALSE
		update_icons()
		return

/mob/living/simple_animal/sheep/female/attackby(var/obj/item/O as obj, var/mob/user as mob)
	if (istype(O, /obj/item/weapon/reagent_containers/glass))
		var/obj/item/weapon/reagent_containers/glass/G = O
		if (stat == CONSCIOUS && istype(G) && G.is_open_container())
			user.visible_message("<span class='notice'>[user] milks [src] using \the [O].</span>")
			var/transfered = udder.trans_id_to(G, "milk", rand(5,10))
			if (G.reagents.total_volume >= G.volume)
				user << "<span class = 'red'>The [O] is full.</span>"
			if (!transfered)
				user << "<span class = 'red'>The udder is dry. Wait a bit.</span>"
			return
	else if (istype(O, /obj/item/weapon/shears) && sheared == FALSE)
		user << "You start shearing \the [src]..."
		if (do_after(user, 150, src) && sheared == FALSE)
			user << "You finish shearing \the [src]."
			sheared = TRUE
			update_icons()
			regrowth()
			new/obj/item/stack/material/wool(get_turf(src))
			return
	else
		..()
/mob/living/simple_animal/sheep/attackby(var/obj/item/O as obj, var/mob/user as mob)
	if (istype(O, /obj/item/weapon/shears) && sheared == FALSE)
		user << "You start shearing \the [src]..."
		if (do_after(user, 150, src) && sheared == FALSE)
			user << "You finish shearing \the [src]."
			sheared = TRUE
			update_icons()
			regrowth()
			new/obj/item/stack/material/wool(get_turf(src))
			return
	else
		..()

/mob/living/simple_animal/sheep/female/Life()
	. = ..()
	if (stat == CONSCIOUS && !lamb)
		if (udder && prob(2))
			udder.add_reagent("milk", rand(3, 5))

	if (overpopulationCountdown > 0) //don't do any checks while overpopulation is in effect
		overpopulationCountdown--
		return

	if (!pregnant && sheep_count < 35)
		var/nearbyObjects = range(1,src) //3x3 area around animal
		for(var/mob/living/simple_animal/sheep/M in nearbyObjects)
			if (M.stat == CONSCIOUS && !istype(M, /mob/living/simple_animal/sheep/female))
				pregnant = TRUE
				birthCountdown = 600 // life ticks once per 2 seconds, 300 == 10 minutes
				break

		if (pregnant)
			nearbyObjects = range(7,src) //15x15 area around animal

			var/sheepCount = 0
			for(var/mob/living/simple_animal/sheep/M in nearbyObjects)
				if (M.stat == CONSCIOUS)
					sheepCount++


			if (sheepCount > 5) // max 5 cows/bulls in a 15x15 area around
				overpopulationCountdown = 300 // 5 minutes
				pregnant = FALSE
	else if (pregnant)
		birthCountdown--
		if (birthCountdown <= 0)
			pregnant = FALSE
			if (prob(50))
				var/mob/living/simple_animal/sheep/C = new/mob/living/simple_animal/sheep(loc)
				C.lamb = TRUE
			else
				var/mob/living/simple_animal/sheep/female/B = new/mob/living/simple_animal/sheep/female(loc)
				B.lamb = TRUE
			visible_message("A sheep lamb has been born!")
/mob/living/simple_animal/camel
	name = "camel"
	desc = "Good for meat."
	icon = 'icons/mob/animal_64.dmi'
	icon_state = "camel"
	icon_living = "camel"
	icon_dead = "camel_dead"
	icon_gib = "camel_dead"
	speak = list("MMMMMHM","brooo","BRBRBRBRR!")
	speak_emote = list("grunts")
	emote_hear = list("grunts")
	emote_see = list("shakes its head")
	speak_chance = TRUE
	turns_per_move = 8
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 6
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	var/packed = FALSE
	health = 110
	mob_size = MOB_LARGE
	var/max_content_size = 35
	var/content_size = 0
	var/list/packed_items = list()
	herbivore = 1

/mob/living/simple_animal/camel/attackby(var/obj/item/O as obj, var/mob/user as mob)
	if (!stat && user.a_intent == I_HELP && icon_state != icon_dead && !istype(O, /obj/item/weapon/leash))
		if (content_size + O.w_class > max_content_size)
			user << "The camel is too burdened already!"
			return
		else
			content_size += O.w_class
			visible_message("[user] places \the [O] on the camel's back.","You put \the [O] on the camel's back.")
			packed_items += O
			user.drop_from_inventory(O)
			O.forceMove(locate(0,0,0))
			packed = TRUE
			update_icons()
	else
		..()
/mob/living/simple_animal/camel/update_icons()
	..()
	if (packed)
		icon_state = "pack_camel"
	else
		icon_state = "camel"

/mob/living/simple_animal/camel/verb/remove_from_storage()
	set category = null
	set name = "Remove Pack"
	set src in range(2, usr)
	if (!content_size)
		usr << "The camel is not carrying anything."
		return
	else
		var/list/choicelist = list("Cancel")
		for (var/obj/item/IT in packed_items)
			choicelist += IT.name
		var/choice1 = WWinput(usr, "What do you want to remove from the camel's pack?", "Camel Pack", "Cancel", choicelist)
		if (choice1 == "Cancel")
			return
		else
			for (var/obj/item/ITS in packed_items)
				if (ITS.name == choice1)
					ITS.loc = locate(usr.x,usr.y,usr.z)
					packed_items -= ITS
					visible_message("[usr] removes \the [ITS] from the camel's back.","You remove \the [ITS] from the camel's back.")
					content_size -= ITS.w_class
					if (!content_size)
						packed = FALSE
						update_icons()
					return