//Bloomery
/obj/structure/bloomery
	density = TRUE
	anchored = TRUE
	name = "\improper stone bloomery"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "bloomery"
	desc = "A primitive furnace for smelting iron."
	var/ore = 0
	var/orelimit = 12				//Max amount of ore.
	var/fuel = 0
	var/matperiron = INGOT_VALUE	//Amount of ore and fuel needed for one iron bar (in bloom).
	var/active = FALSE
	var/timer = 100					//Time till ore produced, discounting aeration.
	var/heat = 5					//How many ticks until the bloomery will shut off due to lack of heat.
	var/nextaeration = 0
	var/aerationdecrease = 5		//Amount of time saved by aerating the bloomery.

//Item Interactions
/obj/structure/bloomery/attackby(obj/item/I, mob/user, params)
	//Add Iron Ore
	if(istype(I, /obj/item/stack/ore/iron))
		var/obj/item/stack/ore/O = I
		var/toadd = min(O.amount, orelimit - ore)
		if(toadd <= 0)
			to_chat(user, "<span class='notice'>\The [src] is full.</span>")
		else
			to_chat(user, "<span class='italics'>You add [toadd] units of ore to \the [src].</span>")
			ore += toadd
			O.use(toadd)
		return
	//Add Coal or Charcoal
	else if((istype(I, /obj/item/stack/ore/coal)) && fuel < orelimit)
		var/obj/item/stack/ore/O = I
		var/toadd = min(O.amount, orelimit - fuel)
		if(toadd <= 0)
			to_chat(user, "<span class='notice'>\The [src] is full.</span>")
		else
			to_chat(user, "<span class='italics'>You add [toadd] units of fuel to \the [src].</span>")
			fuel += toadd
			O.use(toadd)
		return
	//Hand Bellows
	else if(istype(I, /obj/item/handbellows))
		var/obj/item/handbellows/HB = I
		if(!active)
			to_chat(user, "<span class='notice'>What am I doing, \the [src] isn't ignited.</span>")
		else if(world.time - nextaeration >= 0 && HB.ready())
			if(world.time - nextaeration >= 10)
				to_chat(user, "<span class='notice'>Air wooshes into \the [src], and the flames atop blaze brighter.</span>")
			nextaeration = HB.nextuse
			heat = initial(heat)
			timer -= aerationdecrease
			if(do_after(user, HB.usedelay, target = src))
				attackby(I, user)
		else
			to_chat(user, "<span class='notice'>Whew... I need a break...</span>")
		return
	//Ignite the Bloomery
	else if(I.ignition_source && !active)
		if(fuel / matperiron < 1)
			to_chat(user, "<span class='notice'>You need at least [matperiron] units of fuel.</span>")
		else if(ore / matperiron < 1)
			to_chat(user, "<span class='notice'>You need at least [matperiron] units of ore.</span>")
		else
			to_chat(user, "<span class='italics'>You ignite \the [src] at its base.</span>")
			timer = initial(timer)
			heat = initial(heat)
			active = TRUE
			processing_objects |= src
			updatesprites()
		return
	//Run as Normal
	..()

//Examine Function
/obj/structure/bloomery/examine(mob/user)
	..()
	if(!active)
		to_chat(user, "<span class='notice'>The bloomery contains [ore] chunks of ore and [fuel] chunks of fuel.</span>")
	else if(heat / initial(heat) <= 0.5)
		to_chat(user, "<span class='notice'>The bloomery looks cold.</span>")

//On Destruction
/obj/structure/bloomery/Destroy()
	if(ore > 0)
		var/obj/item/stack/ore/iron/O = new /obj/item/stack/ore/iron(loc)
		O.amount = ore
	return ..()

//Sprite Updates
/obj/structure/bloomery/proc/updatesprites()
	icon_state = initial(icon_state)
	if(active)
		icon_state += "-on"

//Processing
/obj/structure/bloomery/process()
	//Checks
	if(fuel <= 0 || !active)
		active = FALSE
		updatesprites()
		processing_objects |= src
		return

	//Heat
	heat--
	if(heat <= 0)
		fuel = round(fuel*timer/initial(timer))
		active = FALSE
		updatesprites()
		processing_objects |= src
		return

	//Timer
	timer--
	if(timer <= 0)
		//Amount of Iron Formed
		var/minimum = min(fuel, ore)
		var/amount = (minimum - (minimum % matperiron)) / matperiron //Simple floor operation

		//End if no Iron is Formed
		if(amount < 1)
			active = FALSE
			updatesprites()
			processing_objects -= src
			return

		//Create Bloom
		var/obj/item/heatable/bloom/B = new /obj/item/heatable/bloom(loc)
		B.iron = amount
		B.temperature = 1400
		B.updatesprites()

		//Adjust Resource Values
		ore -= amount * matperiron
		fuel -= amount * matperiron

		//Reset
		active = FALSE
		updatesprites()
		processing_objects -= src
		return

