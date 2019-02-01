//two main types of engines: external combustion and internal combustion.
//
//fossil fuels:
//petroleum - unrefined crude oil
//gasoline - refined from petroleum
//diesel - refined from petroleum
//
//biofuels:
// ethanol - from fermentation and destilation
//biodiesel - using a special machine to process various farming products
//olive oil - from olives
//
//from the heavyest to the lightest: petroleum > olive oil > biodiesel > diesel > gasoline > ethanol


/obj/structure/engine
	name = "engine"
	desc = "A basic engine."
	icon = 'icons/obj/engines.dmi'
	icon_state = "steam_static"
	var/engineclass = "steam"
	flammable = FALSE
	anchored = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE

	var/weight = 20 //how much the engine weights (duh)

	var/maxpower = 0 //how powerful (in kw/hp) the engine is. Both for vehicles and static engines.
	var/torque = 0 //a modifier for power and max weight. Engines like diesel have a positive modifier, meaning they can carry heavier loads with less power
	var/maxrpm = 0 //maximum engine rpms (or "speed"). Used to calculate maximum engine strain and the vehicle speed, adjusting for torque power and weight.

	var/currentweight = 0
	var/currentpower = 0
	var/currentrpm = 0

	var/currentspeed = 0 //current speed

	var/enginetype = "external" //internal or external. External requires a separate combustion source.
	var/list/connections = list() // what this engine is connected to. cam be an axis, well, etc.
	var/on = FALSE

/obj/structure/engine/proc/turn_on()
	return

/obj/structure/engine/proc/running()
	return

/obj/structure/engine/proc/running_sound()
	if (on)
		playsound(loc, 'sound/machines/diesel_loop.ogg', 100, FALSE, 2)
	spawn(27)
		running_sound()
/obj/structure/engine/attack_hand(mob/user as mob)
	if (on)
		on = FALSE
		visible_message("[user] turns the [src] off.","You turn the [src] off.")
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		update_icon()
		return
	else
		turn_on(user)
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		return

/obj/structure/engine/update_icon()
	..()
	if (on)
		icon_state = "[engineclass]_on"
	else
		icon_state = "[engineclass]_static"

///////////////////////INTERNAL//////////////////////////////////////////////

//two-stroke (small gasoline gasoline)
//four-stroke (otto gasoline)
//six-stroke (experimental?)
//diesel (compression-ignition, two-stroke)
//hot-bulb/crude oil
//hasselman (hybrid, low compression and spark-ignition)
//rotary (Wankel)
//Turbine

/obj/structure/engine/internal
	name = "internal combustion engine"
	desc = "A basic engine."
	enginetype = "internal"
	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank = null
	var/list/fuels = list() //accepted fuels (can be more than one)
	var/fuelefficiency = 0 //fuel consumption per power unit. the lower the better.

/obj/structure/engine/internal/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/glass/barrel) && fueltank == null)
		user.drop_from_inventory(W)
		fueltank = W
		W.anchored = TRUE
		user << "You connect \the [W] to the [src]."
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		return
	else
		..()
/obj/structure/engine/internal/turn_on(var/mob/user = null)
	if (fueltank != null)
		var/done = FALSE
		for (var/F in fuels)
			if (fueltank.reagents.has_reagent(F, fuelefficiency*5) && done == FALSE)
				on = TRUE
				if (user)
					visible_message("[user] turns the [src] on.","You turn the [src] on.")
				playsound(loc, 'sound/machines/diesel_starting.ogg', 100, FALSE, 3)
				update_icon()
				running()
				spawn(40)
					running_sound()
				done = TRUE
				return

/obj/structure/engine/internal/running()
	if (on)
		var/done = FALSE
		for (var/F in fuels)
			if (fueltank.reagents.has_reagent(F, fuelefficiency) && done == FALSE)
				fueltank.reagents.remove_reagent(F, fuelefficiency)
				done = TRUE

		if (!done)
			visible_message("The engine stalls.")
			playsound(loc, 'sound/machines/diesel_ending.ogg', 100, FALSE, 3)
			on = FALSE
			update_icon()
			return

		spawn(10)
			running()
	return

///////////////////////EXTERNAL/////////////////////////////////////////////

//steam, sterling
/obj/structure/engine/external
	enginetype = "external"
	name = "external combustion engine"
	desc = "A basic engine."
	var/obj/structure/heatsource = null

///////////////////////ENGINES//////////////////////////////////////////////

/obj/structure/engine/internal/hotbulb
	name = "hot bulb engine"
	desc = "A big, somewhat inefficient engine, that can run on pretty much any liquid fuel."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "gasoline_static"
	engineclass = "gasoline"

	maxpower = 100
	torque = 1.1
	maxrpm = 2000
	weight = 40
	fuelefficiency = 0.2
	fuels = list("petroleum", "gasoline", "diesel", "ethanol", "biodiesel", "olive_oil") //basically everything
