/obj/structure/bearcave
	name = "Bear Cave"
	icon = 'icons/obj/bearcave.dmi'
	icon_state = "cave_den"
	desc = "Thats a bearcave. You probably want to stay away from it. "
	var/females = 0
	var/males = 0
	var/cubs = 0
	var/cub_growing = FALSE
	var/total_population = 0
	var/ticking = FALSE
	var/bear_climate = null
	var/aggroed = FALSE
	var/empty = FALSE
	var/max_pop = 10
	var/procreate_holder = 27000 //45 minutes - TIMER TO PROCREATE
	var/procreate_cooldown = FALSE
	var/wanderer_holder = 18000 //30 minutes to roll the chance for the wanderer to go out
	var/wanderer_cooldown = FALSE

/obj/structure/bearcave/New()
	src.males = pick(1, 2, 3) //Initialize with some random ammount of bears, from 2 to 6
	src.females = pick(1, 2, 3)
	src.total_population = src.males + src.females + src.cubs //Initializes the local population
	empty = FALSE
	src.set_cavetype()
	if(!bearcave_ticking) //Checks if the bearcave tick havent been started yet
		bearcave_ticking = TRUE	//Sets the global var to true, stopping any multiple tickings
		Tick()
	..()

/obj/structure/bearcave/proc/set_cavetype()
	var/current_climate = get_area(src).climate
	if(current_climate == "jungle")
		icon_state += "-bamboo" + pick("", "2")
		src.bear_climate = "black"
	if(current_climate == "tundra" || current_climate == "taiga")
		icon_state += "-ice" + pick("", "2")
		src.bear_climate = "polar"
	if(current_climate == "temperate")
		icon_state += "-foliage" + pick("", "2")
		src.bear_climate = "brown"
	if(current_climate == "desert" || current_climate == "semiarid" || current_climate == "savanna")
		icon_state += "-tree" + pick("", "2")
		src.bear_climate = "brown"

/obj/structure/bearcave/proc/reproduction()
	if(total_population > 0 && total_population < 10)
		if((females && males) && !procreate_cooldown) //Just one pregnancy at time, doesnt matter the ammount of females
			cubs++
			procreate_cooldown = TRUE
			spawn(procreate_holder)
				procreate_cooldown = FALSE

/obj/structure/bearcave/proc/Tick()
	set background = 1
	spawn while(1)
		for(var/obj/structure/bearcave/B in world)
			B.total_population = B.males + B.females + B.cubs
			B.Ticker()
		sleep(50)

/obj/structure/bearcave/proc/Ticker()
//################## Description Ticker Settings Output #################
	src.desc = "Thats a bearcave. You probably want to stay away from it. "
	if(src.total_population > 0)
		if(prob(35))
			src.desc += "You can see [src.total_population+pick(1, 2)]"
		else if(prob(35))
			src.desc += "You can see [src.total_population-pick(1, 2)]"
		else
			src.desc += "You can see [src.total_population]"
		src.desc += " staring at you in the darkness."
	else
		src.desc += pick("You maybe have seen one pair of eyes, but it looks empty.", "You dont see anything inside it.")
//################## Description Ticker Settings Output #################
	if(!wanderer_cooldown) //Configurations for wanderer bears
		if(prob(8))
			bear_out()
		wanderer_cooldown = TRUE
		spawn(wanderer_holder)
			wanderer_cooldown = FALSE
	if(src.males && src.females)
		src.reproduction() //Couples the couple
	if(src.cubs && !cub_growing)
		cub_growing = TRUE
		spawn(4500)
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

/obj/structure/bearcave/proc/process_cub(var/is_cub = FALSE, var/mob/living/simple_animal/hostile/bear/C)
	if(is_cub)
		C.cub = TRUE
	return

/obj/structure/bearcave/proc/bear_out()
	var/B = /mob/living/simple_animal/hostile/bear
	var/type_roll = null
	var/is_cub = FALSE
	if(src.total_population)
		if(src.males > 0 && src.males >= src.females)
			type_roll = "boar"
		else if (src.females > 0)
			type_roll = "sow"
		else if(src.cubs) //No females or males(grown), only cubs
			is_cub = TRUE
			if(prob(50))	//Rolls to define the cub's sex
				type_roll = "boar"
			else
				type_roll = "sow"
		switch(src.bear_climate)
			if("brown")
				if(type_roll == "boar")
					B = new/mob/living/simple_animal/hostile/bear/boar/brown/(loc)
				else
					B = new/mob/living/simple_animal/hostile/bear/sow/brown/(loc)

			if("polar")
				if(type_roll == "boar")
					B = new/mob/living/simple_animal/hostile/bear/boar/polar/(loc)
				else
					B = new/mob/living/simple_animal/hostile/bear/sow/polar/(loc)

			if("black")
				if(type_roll == "boar")
					B = new/mob/living/simple_animal/hostile/bear/boar/black/(loc)
				else
					B = new/mob/living/simple_animal/hostile/bear/sow/black/(loc)
		if(!is_cub)
			if(type_roll == "boar")
				src.males--
			else
				src.females--
		else
			process_cub(is_cub, B)
			src.cubs--
	else
		return

/obj/structure/bearcave/proc/aggro()
	if(src.total_population > 0)
		if(src.total_population > 5)
			var/pick = pick(1, 2, 3)
			for(var/i=0, i<pick, i++)
				bear_out()
		else if (src.total_population > 1 && src.total_population < 5)
			var/pick = pick(1, 2)
			for(var/i=0, i<pick, i++)
				bear_out()
		else if(src.total_population == 1)
			bear_out()
		aggroed = TRUE
		spawn(50) //No spamclick
			aggroed = FALSE

/obj/structure/bearcave/attackby(obj/W as obj, mob/user as mob)
	if(!aggroed)
		src.aggro()
	if(istype(W,/obj/item/weapon/material/pickaxe) && empty)
		if (do_after(user,65,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)
	..()

/obj/structure/bearcave/attack_hand(mob/living/human/M as mob)
	if(!aggroed)
		src.aggro()
	..()

/obj/structure/bearcave/Crossed(mob/living/human/M as mob)
	if(istype(M, /mob/living/human))
		if(!aggroed)
			src.aggro()
	..()