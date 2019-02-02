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
	var/fuelefficiency = 0 //fuel consumption per 1000 rpms. Lower is better


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
				currentrpm = 0.1*maxrpm
				update_icon()
				running()
				spawn(40)
					running_sound()
				done = TRUE
				return


/obj/structure/engine/internal/running()
	if (on)
		var/done = FALSE
		var/fuelconsumption = fuelefficiency*(currentrpm/1000) //fuelconsumption is based on current RPM
		for (var/F in fuels)
			if (fueltank.reagents.has_reagent(F, fuelconsumption) && done == FALSE)
				fueltank.reagents.remove_reagent(F, fuelconsumption)
				done = TRUE

		if (!done)
			visible_message("The engine stalls.")
			playsound(loc, 'sound/machines/diesel_ending.ogg', 100, FALSE, 3)
			on = FALSE
			currentrpm = 0
			currentspeed = 0
			currentpower = 0
			update_icon()
			return
		else
			currentpower = process_power_output()
			currentrpm = max((0.1*maxrpm), currentrpm)

		spawn(10)
			running()
	return

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
