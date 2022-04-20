/mob/living/simple_animal/cattle
	var/plough = FALSE
	var/plough_raised = TRUE		//Lets make people access the Cattle Pulled Plough menu at first to familiarize
	var/plough_material
	var/plough_road = FALSE
	var/cattle_gender = null			//Nice info to have about the cattle. Will make it easier to work with
	var/calf = FALSE  //Each gender was taking this var
	fat_penalty = 1 //For ballance reasons
	icon_state = "cow_random"

/mob/living/simple_animal/cattle/New()
	..()
	var/mob/living/simple_animal/cattle/cow/NC
	var/mob/living/simple_animal/cattle/bull/NB
	spawn(5)
		if (name!="cow")
			if (name!="bull")
				if (prob(55))
					NC = new/mob/living/simple_animal/cattle/cow(loc)
					if (prob(20))
						NC.calf = TRUE
					else
						if (prob(10))
							NC.pregnant = TRUE
				else
					NB = new/mob/living/simple_animal/cattle/bull(loc)
					if (prob(20))
						NB.calf = TRUE
				qdel(src)

/mob/living/simple_animal/cattle/cow
	name = "cow"
	cattle_gender = "female"
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
	move_to_delay = 5
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 6
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 50
	var/datum/reagents/udder = null
	var/pregnant = FALSE
	var/birthCountdown = 0
	var/overpopulationCountdown = 0
	mob_size = MOB_LARGE
	herbivore = 1
	wandersounds = list('sound/animals/cow/cow_1.ogg','sound/animals/cow/cow_2.ogg','sound/animals/cow/cow_3.ogg')

/mob/living/simple_animal/cattle/bull
	name = "bull"
	cattle_gender = "male"
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
	move_to_delay = 5
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 6
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 65
	mob_size = MOB_LARGE
	herbivore = 1
	wandersounds = list('sound/animals/cow/cow_1.ogg','sound/animals/cow/cow_2.ogg','sound/animals/cow/cow_3.ogg')

/mob/living/simple_animal/cattle/death()
	..()
	if (plough)											//Dropping items after it dies
		if(plough_material == "iron")					//I should probably make it modular, but I'm tired
			new/obj/item/weapon/plough/iron(src.loc)
			plough_material = null				//Dropping two after dying without it
		else if (plough_material == "wood")
			new/obj/item/weapon/plough(src.loc)
			plough_material = null
		new/obj/item/stack/material/rope(src.loc)
		new/obj/item/stack/material/rope(src.loc)
		plough = FALSE

/mob/living/simple_animal/cattle/cow/death()

	cow_count &= src
	..()
/mob/living/simple_animal/cattle/cow/Destroy()

	cow_count &= src
	..()
/mob/living/simple_animal/cattle/bull/death()

	cow_count &= src
	..()
/mob/living/simple_animal/cattle/bull/Destroy()

	cow_count &= src
	..()
/mob/living/simple_animal/cattle/bull/New()
	cow_count |= src
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

/mob/living/simple_animal/cattle/cow/New()
	cow_count |= src
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

/mob/living/simple_animal/cattle/cow/attackby(var/obj/item/O as obj, var/mob/user as mob)
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
									// \/ port the ploughting for the whole cattle family
/mob/living/simple_animal/cattle/attackby(obj/item/weapon/plough/O as obj, var/mob/user as mob)
	if(calf)
		return
	if ((istype(O,/obj/item/weapon/plough) && !plough) && user.a_intent == I_HELP)	//makes sure that you'll bash your cow
		if (istype(O,/obj/item/weapon/plough/iron))									//if you do something wrong
			plough_material = "iron"
		else
			plough_material = "wood"
		if(istype(user.l_hand, /obj/item/stack/material/rope/) || istype(user.r_hand, /obj/item/stack/material/rope/))
			if( user.a_intent == I_HELP )
				if(plough)
					return
				var/obj/item/stack/material/rope/NR
				user << "You try to attach the Plough to the cattle."
				if(istype(user.l_hand, /obj/item/stack/material/rope/))	//Check in which hand is the rope to not mess up
					NR = user.l_hand
					if (NR.amount < 2)
						user << "<span class = 'warning'>You need at least a stack of 2 ropes on one of your hands in order to do this.</span>"
						return
				else if(istype(user.r_hand, /obj/item/stack/material/rope/))
					NR = user.r_hand
					if (NR.amount < 2)
						user << "<span class = 'warning'>You need at least a stack of 2 ropes on one of your hands in order to do this.</span>"
						return
				if (do_after(user,35,src))
					NR.amount -= 2
					if (NR.amount <= 0)
						qdel(NR)			//When dealing with stack ammount, it could stay as object with 0 ammount
					qdel(O)
					if(cattle_gender == "female")
						icon_state = "cow_plough"
					else if(cattle_gender == "male")
						icon_state = "bull_plough"
					plough = TRUE
		else
			user << "You need a rope to attach the Plough to the cattle."
	else
		..()						//If its not set here as new action, just assume the previous one for attackby

/mob/living/simple_animal/cattle/attack_hand(var/mob/user as mob)
	..()
	if(calf)
		return
	if ( user.a_intent == I_HELP && plough )
		var/plough_status
		if (plough_raised)
			plough_status = "Lower Plough"
		else							//Interactive menu vars
			plough_status = "Raise Plough"
		var/road_status
		if(plough_road)
			road_status = "Adjust to stop making Roads"
		else
			road_status = "Adjust to make Roads"
		var/choice1 = WWinput(usr, "What would you like to do with the Cow's Plough?", "Cattle Pulled Plough", "Remove", list("Remove", road_status, plough_status, "Cancel"))
		if (choice1 == "Remove")
			user << "You try to detach the Plough from the Cow."
			if (do_after(user,35,src))
				if(cattle_gender == "female")
					icon_state = "cow"
				else if(cattle_gender == "male")
					icon_state = "bull"
				plough = FALSE
				new/obj/item/stack/material/rope(user.loc)
				new/obj/item/stack/material/rope(user.loc)
				if(plough_material == "iron")
					new/obj/item/weapon/plough/iron(user.loc)
					plough_material = null						//I hate this much of redundancy thats needed
				else if(plough_material == "wood")
					new/obj/item/weapon/plough(user.loc)
					plough_material = null
				plough_material = null
		else if (choice1 == "Raise Plough")
			plough_raised = TRUE
		else if (choice1 == "Lower Plough")
			plough_raised = FALSE
		else if (choice1 == "Adjust to make Roads")
			plough_road = TRUE
		else if (choice1 == "Adjust to stop making Roads")
			plough_road = FALSE
		else
			return

/mob/living/simple_animal/cattle/proc/do_plough(atom/movable/O)
	if(plough && !plough_raised)
		var/plough_time = 48 //25% faster than the iron hand plough
		if (plough_material == "iron")
			plough_time /= 2 //Iron Plough is 2x faster
		if (simplehunger >= 500 && simplehunger <= 700)
			plough_time += plough_time * 0.25		//Hunger between 50% and 70%, receives a 25% penalty
		else if (simplehunger >= 200 && simplehunger < 500)
			plough_time += plough_time * 0.50		//Hunger between 20% and 50%, receives a 50% penalty
		else if (simplehunger >= 0 && simplehunger < 200)
			plough_time += plough_time * 0.75		//Hunger between 0% and 20%, receives a 75% penalty
		var/mob/living/simple_animal/cattle/L = O
		var/mob/living/L2 = L.pulledby
		var/turf/T = get_turf(src)
		if (istype(T, /turf/floor/dirt/flooded) && !locate(/obj/covers/roads/dirt) in get_turf(O))
			if(do_after(L2, plough_time, src))				//ape double code to not let it build infinite roads over the other
				if(L.stat == CONSCIOUS)		//no memes for dead cattle  working
					if(!plough_road)							//dirt/flooded needs to be away from other dirts because it's ploughted field
						T.ChangeTurf(/turf/floor/dirt/ploughed/flooded)	//returns a different ploughted field than the regular dirt
					else
						new/obj/covers/roads/dirt(O.loc)
					simplehunger -= 65		//The hunger rates regenerates after doing brute damage, thats why it can take more than 1000 simplehunger
					visible_message("[src] [pick("ploughs the field","runs the plough into the field","begins ploughing the field.","plows.")]")
		else if (istype(T, /turf/floor/dirt/underground) || locate(/obj/covers/roads/dirt) in get_turf(O))
			return										//I hate these double checks and same looking code
		else											//But its needed unless we rework the ploughing or turf
			if(do_after(L2, plough_time, src))
				if(L.stat == CONSCIOUS)
					if(!plough_road)
						T.ChangeTurf(/turf/floor/dirt/ploughed)
					else
						new/obj/covers/roads/dirt(O.loc)
					simplehunger -= 65
					visible_message("[src] [pick("ploughs the field","runs the plough into the field","begins ploughing the field.","plows.")]")

/mob/living/simple_animal/cattle/Life()
	. = ..()
	if (stat == CONSCIOUS)
		if ( plough && pulledby)
			if ( istype(get_turf(src), /turf/floor/grass/jungle) )
			else if ( istype(get_turf(src), /turf/floor/dirt/burned) )			//Not very modular, since the plough process isnt
			else if ( istype(get_turf(src), /turf/floor/dirt/jungledirt) )		//We can module all the checks if the soil is ploughtable
			else if (istype(get_turf(src), /turf/floor/grass) && !istype(get_turf(src), /turf/floor/grass/jungle))
				do_plough(src)			//Maybe add a Turf var or proc is_ploughtable?
			else if (istype(get_turf(src), /turf/floor/dirt) && !(istype(get_turf(src), /turf/floor/dirt/ploughed)) && !(istype(get_turf(src), /turf/floor/dirt/dust)))
				do_plough(src)

/mob/living/simple_animal/cattle/cow/Life()
	. = ..()

	if (stat == CONSCIOUS)
		if (udder && prob(5) && !calf)
			udder.add_reagent("milk", rand(5, 10))
	else
		return

	if (overpopulationCountdown > 0) //don't do any checks while overpopulation is in effect
		overpopulationCountdown--
		return

	if (!pregnant && cow_count.len < 30)
		var/nearbyObjects = range(1,src) //3x3 area around cow
		for(var/mob/living/simple_animal/cattle/bull/M in nearbyObjects)
			if (M.stat == CONSCIOUS)
				pregnant = TRUE
				birthCountdown = 600
				break

		if (pregnant)
			nearbyObjects = range(7,src) //15x15 area around cow

			var/cowCount = 0
			for(var/mob/living/simple_animal/cattle/cow/M in nearbyObjects)
				if (M.stat == CONSCIOUS)
					cowCount++

			for(var/mob/living/simple_animal/cattle/bull/M in nearbyObjects)
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
				var/mob/living/simple_animal/cattle/cow/C = new/mob/living/simple_animal/cattle/cow(loc)
				C.calf = TRUE
			else
				var/mob/living/simple_animal/cattle/bull/B = new/mob/living/simple_animal/cattle/bull(loc)
				B.calf = TRUE
			visible_message("A calf has been born!")

/mob/living/simple_animal/cattle/cow/attack_hand(mob/living/human/M as mob)
	if (!stat && M.a_intent == I_DISARM && icon_state != icon_dead)
		M.visible_message("<span class='warning'>[M] tips over [src].</span>","<span class='notice'>You tip over [src].</span>")
		Weaken(30)
		icon_state = icon_dead
		spawn(rand(20,50))
			if (!stat && M)
				if ( plough )
					icon_state = "cow_plough"
				else								//For some reason, updating the cow_work to icon_living doesnt work properly
					icon_state = icon_living
				var/list/responses = list(	"[src] looks at you imploringly.",
											"[src] looks at you pleadingly",
											"[src] looks at you with a resigned expression.",
											"[src] seems resigned to its fate.")
				M << pick(responses)
	else
		..()

//pig
/mob/living/simple_animal/pig_boar
	name = "pig boar"
	desc = "A small Mammal, with a stocky Body, Flat snout and small eyes they are a member of the Suidae Family."
	icon_state = "pig_boar"
	icon_living = "pig_boar"
	icon_dead = "pig_boar_dead"
	speak = list("OINK!","SQWEEEL!")
	emote_see = list("rolls on the ground", "lays with it's belly up", "snorts")
	speak_chance = 1
	move_to_delay = 5
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 5
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	faction = list("neutral")
	attack_sound = 'sound/weapons/punch1.ogg'
	health = 60
	maxHealth = 60
	melee_damage_lower = 2
	melee_damage_upper = 6
	stop_automated_movement_when_pulled = 1
	mob_size = MOB_MEDIUM
	var/piglet = FALSE
	herbivore = 0 //if it eats grass of the floor (i.e. goats, cows)
	granivore = 1 //if it will be attracted to crops (i.e. rabbits, mice, birds)
	scavenger = 1 //if it will be attracted to trash, rotting meat, etc (mice, mosquitoes)
	carnivore = 1 //if it will be attracted to meat and dead bodies. Wont attack living animals by default.
	wandersounds = list('sound/animals/pig/pig_1.ogg','sound/animals/pig/pig_2.ogg')
	fat_extra = 2

/mob/living/simple_animal/pig_gilt
	name = "pig gilt"
	desc = "A small Mammal, with a stocky Body, Flat snout and small eyes they are a member of the Suidae Family."
	icon_state = "pig_gilt"
	icon_living = "pig_gilt"
	icon_dead = "pig_gilt_dead"
	speak = list("OINK!","SQWEEEL!")
	emote_see = list("rolls on the ground", "lays with it's belly up", "snorts")
	speak_chance = 1
	move_to_delay = 5
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 6
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 60
	var/piglet = FALSE
	var/datum/reagents/udder = null
	var/pregnant = FALSE
	var/birthCountdown = 0
	var/overpopulationCountdown = 0
	mob_size = MOB_MEDIUM
	herbivore = 0 //if it eats grass of the floor (i.e. goats, cows)
	granivore = 1 //if it will be attracted to crops (i.e. rabbits, mice, birds)
	scavenger = 1 //if it will be attracted to trash, rotting meat, etc (mice, mosquitoes)
	carnivore = 1 //if it will be attracted to meat and dead bodies. Wont attack living animals by default.
	wandersounds = list('sound/animals/pig/pig_1.ogg','sound/animals/pig/pig_2.ogg')
	fat_extra = 2

/mob/living/simple_animal/pig_gilt/death()

	pig_count &= src
	..()
/mob/living/simple_animal/pig_boar/death()

	pig_count &= src
	..()
/mob/living/simple_animal/pig_gilt/Destroy()

	pig_count &= src
	..()
/mob/living/simple_animal/pig_boar/Destroy()

	pig_count &= src
	..()
/mob/living/simple_animal/pig_boar/New()
	pig_count |= src
	..()
	spawn(1)
		if (piglet)
			icon_state = "pig_piglet"
			icon_living = "pig_piglet"
			icon_dead = "pig_piglet_dead"
			meat_amount = 2
			mob_size = MOB_SMALL
			spawn(3000)
				piglet = FALSE
				icon_state = "pig_boar"
				icon_living = "pig_boar"
				icon_dead = "pig_boar_dead"
				mob_size = MOB_MEDIUM

/mob/living/simple_animal/pig_gilt/New()
	pig_count |= src
	udder = new(50)
	udder.my_atom = src
	..()
	spawn(1)
		if (piglet)
			icon_state = "pig_piglet"
			icon_living = "pig_piglet"
			icon_dead = "pig_piglet_dead"
			meat_amount = 2
			udder.remove_reagent("milk")
			mob_size = MOB_SMALL
			spawn(3000)
				piglet = FALSE
				icon_state = "pig_gilt"
				icon_living = "pig_gilt"
				icon_dead = "pig_gilt_dead"
				mob_size = MOB_MEDIUM

/mob/living/simple_animal/pig_gilt/attackby(var/obj/item/O as obj, var/mob/user as mob)
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

/mob/living/simple_animal/pig_gilt/Life()
	. = ..()
	if (stat == CONSCIOUS)
		if (udder && prob(5) && !piglet)
			udder.add_reagent("milk", rand(5, 10))
	else
		return

	if (overpopulationCountdown > 0) //don't do any checks while overpopulation is in effect
		overpopulationCountdown--
		return

	if (!pregnant && pig_count.len < 30)
		var/nearbyObjects = range(1,src) //3x3 area around pig
		for(var/mob/living/simple_animal/pig_boar/M in nearbyObjects)
			if (M.stat == CONSCIOUS)
				pregnant = TRUE
				birthCountdown = 600
				break

		if (pregnant)
			nearbyObjects = range(7,src) //15x15 area around pig

			var/pigCount = 0
			for(var/mob/living/simple_animal/pig_gilt/M in nearbyObjects)
				if (M.stat == CONSCIOUS)
					pigCount++

			for(var/mob/living/simple_animal/pig_boar/M in nearbyObjects)
				if (M.stat == CONSCIOUS)
					pigCount++

			if (pigCount > 5) // max 5 pig_boars/pig_gilts in a 15x15 area around pig gilt
				overpopulationCountdown = 300
				pregnant = FALSE
	else if (pregnant)
		birthCountdown--
		if (birthCountdown <= 0)
			pregnant = FALSE
			if (prob(50))
				var/mob/living/simple_animal/pig_gilt/C = new/mob/living/simple_animal/pig_gilt(loc)
				C.piglet = TRUE
			else
				var/mob/living/simple_animal/pig_boar/B = new/mob/living/simple_animal/pig_boar(loc)
				B.piglet = TRUE
			visible_message("A piglet has been born!")

/mob/living/simple_animal/boar_boar
	name = "boar"
	desc = "A small Wooly Mammal, with a stocky Body, Long snout and small eyes they are a member of the Suidae Family."
	icon_state = "boar_boar"
	icon_living = "boar_boar"
	icon_dead = "boar_dead"
	speak = list("Gweeeeiiirrr!","Ghhhhhhh!","Oeerrrrhhh!")
	emote_see = list("rolls on the ground", "lays with it's belly up", "snorts")
	speak_chance = 1
	move_to_delay = 5
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 3
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	faction = list("neutral")
	attack_sound = 'sound/weapons/punch1.ogg'
	health = 150
	maxHealth = 150
	melee_damage_lower = 8
	melee_damage_upper = 15
	stop_automated_movement_when_pulled = 1
	mob_size = MOB_MEDIUM
	var/piglet = FALSE
	herbivore = 0 //if it eats grass of the floor (i.e. goats, cows)
	granivore = 1 //if it will be attracted to crops (i.e. rabbits, mice, birds)
	scavenger = 1 //if it will be attracted to trash, rotting meat, etc (mice, mosquitoes)
	carnivore = 1 //if it will be attracted to meat and dead bodies. Wont attack living animals by default.
	predatory_carnivore = 1
	behaviour = "defends"
	wandersounds = list('sound/animals/pig/pig_1.ogg','sound/animals/pig/pig_2.ogg')
	fat_extra = 2

/mob/living/simple_animal/boar_gilt
	name = "boar gilt"
	desc = "A small Wooly Mammal, with a stocky Body, Long snout and small eyes they are a member of the Suidae Family."
	icon_state = "boar_gilt"
	icon_living = "boar_gilt"
	icon_dead = "boar_dead"
	speak = list("Gweeeeiiirrr!","Ghhhhhhh!","Oeerrrrhhh!")
	emote_see = list("rolls on the ground", "lays with it's belly up", "snorts")
	speak_chance = 1
	move_to_delay = 5
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 3
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 60
	var/piglet = FALSE
	var/datum/reagents/udder = null
	var/pregnant = FALSE
	var/birthCountdown = 0
	var/overpopulationCountdown = 0
	mob_size = MOB_MEDIUM
	herbivore = 0 //if it eats grass of the floor (i.e. goats, cows)
	granivore = 1 //if it will be attracted to crops (i.e. rabbits, mice, birds)
	scavenger = 1 //if it will be attracted to trash, rotting meat, etc (mice, mosquitoes)
	carnivore = 1 //if it will be attracted to meat and dead bodies. Wont attack living animals by default.
	behaviour = "defends"
	wandersounds = list('sound/animals/pig/pig_1.ogg','sound/animals/pig/pig_2.ogg')
	fat_extra = 2

/mob/living/simple_animal/boar_gilt/death()

	boar_count &= src
	..()
/mob/living/simple_animal/boar_boar/death()

	boar_count &= src
	..()
/mob/living/simple_animal/boar_gilt/Destroy()

	boar_count &= src
	..()
/mob/living/simple_animal/boar_gilt/Destroy()

	boar_count &= src
	..()
/mob/living/simple_animal/boar_gilt/New()
	boar_count |= src
	..()
	spawn(1)
		if (piglet)
			icon_state = "boar_piglet"
			icon_living = "boar_piglet"
			icon_dead = "pig_piglet_dead"
			meat_amount = 1
			mob_size = MOB_SMALL
			spawn(3000)
				piglet = FALSE
				icon_state = "boar_boar"
				icon_living = "boar_boar"
				icon_dead = "boar_dead"
				mob_size = MOB_MEDIUM

/mob/living/simple_animal/boar_gilt/New()
	boar_count |= src
	udder = new(50)
	udder.my_atom = src
	..()
	spawn(1)
		if (piglet)
			icon_state = "boar_piglet"
			icon_living = "boar_piglet"
			icon_dead = "pig_piglet_dead"
			meat_amount = 2
			udder.remove_reagent("milk")
			mob_size = MOB_SMALL
			spawn(3000)
				piglet = FALSE
				icon_state = "boar_gilt"
				icon_living = "boar_gilt"
				icon_dead = "boar_dead"
				mob_size = MOB_MEDIUM

/mob/living/simple_animal/boar_gilt/attackby(var/obj/item/O as obj, var/mob/user as mob)
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

/mob/living/simple_animal/boar_gilt/Life()
	. = ..()
	if (stat == CONSCIOUS)
		if (udder && prob(5) && !piglet)
			udder.add_reagent("milk", rand(5, 10))
	else
		return

	if (overpopulationCountdown > 0) //don't do any checks while overpopulation is in effect
		overpopulationCountdown--
		return

	if (!pregnant && boar_count.len < 30)
		var/nearbyObjects = range(1,src) //3x3 area around pig
		for(var/mob/living/simple_animal/boar_boar/M in nearbyObjects)
			if (M.stat == CONSCIOUS)
				pregnant = TRUE
				birthCountdown = 600
				break

		if (pregnant)
			nearbyObjects = range(7,src) //15x15 area around pig

			var/pigCount = 0
			for(var/mob/living/simple_animal/boar_gilt/M in nearbyObjects)
				if (M.stat == CONSCIOUS)
					pigCount++

			for(var/mob/living/simple_animal/boar_boar/M in nearbyObjects)
				if (M.stat == CONSCIOUS)
					pigCount++

			if (pigCount > 5) // max 5 boar_boars/boar_gilt in a 15x15 area around boar gilt
				overpopulationCountdown = 300
				pregnant = FALSE
	else if (pregnant)
		birthCountdown--
		if (birthCountdown <= 0)
			pregnant = FALSE
			if (prob(50))
				var/mob/living/simple_animal/boar_gilt/C = new/mob/living/simple_animal/boar_gilt(loc)
				C.piglet = TRUE
			else
				var/mob/living/simple_animal/boar_boar/B = new/mob/living/simple_animal/boar_gilt(loc)
				B.piglet = TRUE
			visible_message("A boar piglet has been born!")


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
	move_to_delay = 5
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
	wandersounds = list('sound/animals/goat/goat_1.ogg','sound/animals/goat/goat_2.ogg','sound/animals/goat/goat_3.ogg')

/mob/living/simple_animal/goat/New()
	goat_count |= src
	..()
	spawn(1)
		if (lamb)
			icon_state = "goat_lamb"
			icon_living = "goat_lamb"
			icon_dead = "goat_lamb_dead"
			wandersounds = list('sound/animals/goat/baby_goat_1.ogg','sound/animals/goat/baby_goat_2.ogg')
			meat_amount = 2
			mob_size = MOB_SMALL
			spawn(3000)
				lamb = FALSE
				icon_state = "goat_ram"
				icon_living = "goat_ram"
				icon_dead = "goat_ram_dead"
				mob_size = MOB_MEDIUM
				wandersounds = list('sound/animals/goat/goat_1.ogg','sound/animals/goat/goat_2.ogg','sound/animals/goat/goat_3.ogg')

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

	goat_count &= src
	..()
/mob/living/simple_animal/goat/Destroy()

	goat_count &= src
	..()
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

	if (!pregnant && goat_count.len < 35)
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
	move_to_delay = 5
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
	wandersounds = list('sound/animals/sheep/sheep_1.ogg','sound/animals/sheep/sheep_2.ogg')

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

	sheep_count &= src
	..()
/mob/living/simple_animal/sheep/Destroy()

	sheep_count &= src
	..()
/mob/living/simple_animal/sheep/New()
	sheep_count |= src
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

	if (!pregnant && sheep_count.len < 35)
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
	move_to_delay = 8
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
	fat_extra = 3

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
