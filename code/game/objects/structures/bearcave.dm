/obj/structure/bearcave
	icon = 'icons/obj/bearcave.dmi'
	icon_state = "cave_den"
	var/struc_health = 1000
	var/females = 0
	var/males = 0
	var/cubs = 0
	var/total_population = 0
	var/overpopulation = FALSE
	var/copulating = FALSE
	var/ticking = FALSE
	var/bear_climate = null
	var/aggroed = FALSE
	var/empty = TRUE


/obj/structure/bearcave/New()
	var/current_climate = get_area(src).climate
	src.males = pick(1, 2, 3) //Initialize with some random ammount of bears, from 2 to 6
	src.females = pick(1, 2, 3)
	empty = FALSE
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

	if(!bearcave_ticking) //Checks if the bearcave tick havent been started yet
		bearcave_ticking = TRUE	//Sets the global var to true, stopping any multiple tickings
		Tick()
	..()

/obj/structure/bearcave/proc/reproduction()
	if(total_population > 0)
		if(females && males) //Just one pregnancy at time, doesnt matter the ammount of females
			cubs++

/obj/structure/bearcave/proc/Tick()
	set background = 1
	spawn while(1)
		for(var/obj/structure/bearcave/B in world)
			src.total_population = src.males + src.females + src.cubs
			if(total_population)
				B.Ticker()
		sleep(50)

/obj/structure/bearcave/proc/Ticker()
	if(src.males && src.females)
		src.reproduction() //Couples the couple
	if(src.cubs)
		spawn(50)
			cubs--
			if(prob(50))
				females++
			else
				males++
	if (!total_population && !empty) //Is it unpopulated? No hope left, ready to be destroyed
		src.empty = TRUE // It will change it's icon just once
		src.icon_state = "cave_den-blocked" + pick("", "2")

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
	..()

/obj/structure/bearcave/attack_hand(mob/living/human/M as mob)
	if(!aggroed)
		src.aggro()
	..()
