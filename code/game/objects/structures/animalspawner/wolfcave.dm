/obj/structure/animalspawner/wolfcave
	name = "Wolf Cave"
	icon = 'icons/obj/animal_spawner.dmi'
	icon_state = "cave_den"
	desc = "Thats a wolfcave. You probably want to stay away from it."

/obj/structure/animalspawner/wolfcave/New()
	src.males = pick(1, 2, 3) //Initialize with some random amount of wolves, from 2 to 6
	src.females = pick(1, 2, 3)
	src.total_population = src.males + src.females + src.cubs //Initializes the local population
	src.empty = FALSE
	src.set_cavetype()
	if(!src.ticking) // ticks the tick if the tick havent been ticked yet
		src.ticking = TRUE
		Tick()
	..()

/obj/structure/animalspawner/wolfcave/proc/set_cavetype()
	var/current_climate = get_area(src).climate
	if(current_climate == "jungle")
		icon_state += "-bamboo" + pick("", "2")
		src.t_climate = "grey"
	if(current_climate == "tundra" || current_climate == "taiga")
		icon_state += "-ice" + pick("", "2")
		src.t_climate = "white"
	if(current_climate == "temperate")
		icon_state += "-foliage" + pick("", "2")
		src.t_climate = "grey"
	if(current_climate == "desert" || current_climate == "semiarid" || current_climate == "savanna")
		icon_state += "-tree" + pick("", "2")
		src.t_climate = "grey"
	if(current_climate == "sea") // default icon state
		src.t_climate = "grey"
	if (istype(get_area(src), /area/caribbean/void/caves/special))
		src.t_climate = "grey"

/obj/structure/animalspawner/wolfcave/proc/reproduction()
	if(total_population >= 0 && total_population < 10) //Greater than 0 or zero, and less than ten
		if((females && males) && !procreate_cooldown) //Just one pregnancy at time, doesnt matter the ammount of females
			cubs++
			procreate_cooldown = TRUE
			spawn(procreate_holder)
				procreate_cooldown = FALSE

/obj/structure/animalspawner/wolfcave/proc/Tick()
	spawn while(1)
		for(var/obj/structure/animalspawner/wolfcave/B in world)
			B.total_population = B.males + B.females + B.cubs
			B.Ticker()
		sleep(50)

/obj/structure/animalspawner/wolfcave/proc/Ticker()
//################## Description Ticker Settings Output #################
	src.desc = "Thats a wolfcave. You probably want to stay away from it."
	var/number_flavor = 0
	if(src.total_population > 0)
		if(prob(35))
			number_flavor = src.total_population + pick(1, 2)
		else if(prob(35))
			number_flavor = src.total_population - pick(1, 2)
		if(number_flavor <= 0)
			number_flavor = src.total_population
		src.desc = "You can see [number_flavor] eyes"
		src.desc += " staring at you in the darkness."
	else
		src.desc += pick("You maybe have seen one pair of eyes, but it looks empty.", "You dont see anything inside it.")
//################## Description Ticker Settings Output #################
	if(!src.wanderer_cooldown) // checks if there was a wanderer going out
		var/nearbyObjects = range(6,src) // 36 square area around the wolfcave
		var/wolfsAround = FALSE
		for(var/mob/living/simple_animal/hostile/wolf/W in nearbyObjects)
			if (W.stat == CONSCIOUS) {
				wolfsAround = TRUE // checks if there are wolfs around before spitting mobs out
				break
			}
		if(prob(18) && !wolfsAround) {// 18% chance to spawn and there are no wolves around
			wolf_out()
			src.wanderer_cooldown = TRUE
			spawn(wanderer_holder)
				src.wanderer_cooldown = FALSE
		}
	if(src.males && src.females)
		src.reproduction() //Couples the couple
	if(src.cubs && !cub_growing)
		src.cub_growing = TRUE
		spawn(4500) // waits 7.5 minutes before a cub can turn into adult
			cubs--
			cub_growing = FALSE
			if(prob(50))
				females++
			else
				males++
	if (!total_population && !empty) //Is it unpopulated? No hope left, ready to be destroyed
		src.empty = TRUE // It will change it's icon just once
		src.icon_state = "cave_den-blocked" + pick("", "2")
	if(empty && total_population)
		src.empty = FALSE
		src.set_cavetype()

/obj/structure/animalspawner/wolfcave/proc/process_cub(var/is_cub = FALSE, var/mob/living/simple_animal/hostile/wolf/C, var/loc)
	if(is_cub)
		new/mob/living/simple_animal/hostile/wolf{cub = TRUE}(loc)
	return

/obj/structure/animalspawner/wolfcave/proc/wolf_out()
	var/B = /mob/living/simple_animal/hostile/wolf
	var/type_roll = null
	var/is_cub = FALSE
	if(src.total_population)
		if(src.males > 0 && src.males >= src.females)
			type_roll = "wolf"
		else if (src.females > 0)
			type_roll = "she-wolf"
		else if(src.cubs) //No females or males(grown), only cubs
			is_cub = TRUE
			if(prob(50))	//Rolls to define the cub's sex
				type_roll = "wolf"
			else
				type_roll = "she-wolf"
		switch(src.t_climate)
			if("brown")
				if(type_roll == "wolf")
					B = new/mob/living/simple_animal/hostile/wolf(loc)
				else
					B = new/mob/living/simple_animal/hostile/wolf/female(loc)

			if("polar")
				if(type_roll == "wolf")
					B = new/mob/living/simple_animal/hostile/wolf/white(loc)
				else
					B = new/mob/living/simple_animal/hostile/wolf/white/female(loc)
		if(!is_cub) // default spawn if their climates were not matched in the previous switch
			if(type_roll == "wolf")
				src.males--
				B = new/mob/living/simple_animal/hostile/wolf(loc)
			else
				src.females--
				B = new/mob/living/simple_animal/hostile/wolf/female(loc)

		else
			process_cub(is_cub, B, loc) // spawns a cub setting it's src.cub var to 1
			src.cubs--
	else
		return

/obj/structure/animalspawner/wolfcave/proc/aggro()
	if(src.total_population > 0)
		if(src.total_population > 5)
			var/pick = pick(1, 2, 3)
			for(var/i=0, i<pick, i++)
				wolf_out()
		else if (src.total_population > 1 && src.total_population < 5)
			var/pick = pick(1, 2)
			for(var/i=0, i<pick, i++)
				wolf_out()
		else if(src.total_population == 1)
			wolf_out()
		src.aggroed = TRUE
		spawn(50) //No spamclick
			src.aggroed = FALSE

/obj/structure/animalspawner/wolfcave/attackby(obj/W as obj, mob/user as mob)
	if(!src.aggroed)
		aggro()
	if(istype(W,/obj/item/weapon/material/pickaxe) && empty)
		if (do_after(user,65,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			qdel(src)
	..()

/obj/structure/animalspawner/wolfcave/attack_hand(mob/living/human/M as mob)
	if(!src.aggroed)
		aggro()
	..()

/obj/structure/animalspawner/wolfcave/Crossed(mob/living/human/M as mob)
	if(istype(M, /mob/living/human))
		if(!src.aggroed)
			aggro()
	..()

/obj/structure/animalspawner/wolfcave/full // initializes defaultly with 5 males and 5 females

/obj/structure/animalspawner/wolfcave/full/New()
	src.males = 5
	src.females = 5
	src.total_population = src.males + src.females + src.cubs //Initializes the local population
	empty = FALSE
	if(!wolfcave_ticking) //Checks if the wolfcave tick havent been started yet
		wolfcave_ticking = TRUE	//Sets the global var to true, stopping any multiple tickings
		Tick()
	..()