///////////////////////INTERNAL//////////////////////////////////////////////

//two-stroke (small gasoline gasoline)
//four-stroke (otto gasoline)
//six-stroke (experimental?)
//diesel (compression-ignition, two-stroke)
//hot-bulb/crude oil
//hesselman (hybrid, low compression and spark-ignition)
//rotary (Wankel)
//Turbine

#define FUEL_CONSUMPTION_MODIFIER 2

/obj/structure/engine/internal
	name = "internal combustion engine"
	desc = "A basic engine."
	enginetype = "internal"
	var/list/fuels = list() //accepted fuels (can be more than one)
	var/fuelefficiency = 0 //fuel consumption on max power. Lower is better. The default value is per 1000 cc (liter)
	var/enginesize = 1000 //in cubic centimeters (cc)


/obj/structure/engine/internal/bullet_act(var/obj/item/projectile/proj)
	if (istype(proj, /obj/item/projectile/shell))
		var/obj/item/projectile/shell/S = proj
		if (S.atype == "HE")
			if (prob(90))
				visible_message("<span class = 'warning'>\The [src] explodes!</span>")
				explosion(loc, 1, 2, 2, 0)
				qdel(src)
			else
				visible_message("<span class = 'warning'>\The [src] breaks down!</span>")
				broken = TRUE
				on = FALSE
				new/obj/effect/decal/cleanable/blood/oil(loc)
				update_icon()
		else
			if (prob(20))
				visible_message("<span class = 'warning'>\The [src] explodes!</span>")
				explosion(loc, 1, 1, 2, 0)
				qdel(src)
			else if (prob(75))
				visible_message("<span class = 'warning'>\The [src] breaks down!</span>")
				broken = TRUE
				on = FALSE
				new/obj/effect/decal/cleanable/blood/oil(loc)
				update_icon()
/obj/structure/engine/internal/New()
	..()
	weight = 20*(enginesize/1000)
	name = "[enginesize]cc [name]"
	maxpower *= (enginesize/1000)
	fuelefficiency *= (enginesize/1000)

/obj/structure/engine/internal/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/glass/barrel) && fueltank == null)
		user.drop_from_inventory(W)
		fueltank = W
		W.anchored = TRUE
		user << "You connect \the [W] to the [src]."
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		return
	else
		..()

/obj/structure/engine/internal/verb/remove_fueltank()
	set category = null
	set name = "Remove Fueltank"
	set src in range(1, usr)

	if (!ishuman(usr))
		return

	if (fueltank == null)
		return

	else
		if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
			if (usr.original_job_title == "Mechanic")
				on = FALSE
				power_off_connections()
				fueltank.anchored = FALSE
				usr << "You disconnect the fuel tank from the [src]."
				fueltank = null
				update_icon()
				return
			else
				usr << "<span class='warning'>You do not know how to do this.</span>"
				return

		on = FALSE
		power_off_connections()
		fueltank.anchored = FALSE
		usr << "You disconnect the fuel tank from the [src]."
		fueltank = null
		update_icon()
		return

/obj/structure/engine/internal/turn_on(var/mob/user = null)
	if (on)
		return
	if (broken)
		user << "\The [src] is broken, you can't turn it on!"
		return
	if (fueltank != null)
		var/done = FALSE
		for (var/F in fuels)
			if (fueltank && fueltank.reagents && fueltank.reagents.has_reagent(F, fuelefficiency*5) && done == FALSE)
				if (user)
					visible_message("[user] turns the [src] on.","You turn the [src] on.")
					on = TRUE
				playsound(loc, starting_snd, 35, FALSE, 3)
				spawn(starting_snd_len)
					running_sound()
					update_icon() //Having the update_icon here means that the icon for it being on doesn't start until after the spawn which is arguably a downside, maybe patchable
					running()
					for (var/obj/structure/cable/CB in connections)
						CB.power_on(maxpower)
					done = TRUE
	return


/obj/structure/engine/internal/running()
	if (on)
		var/done = FALSE
		var/fuelconsumption = fuelefficiency*(min(currentpower, maxpower)/maxpower)*FUEL_CONSUMPTION_MODIFIER //fuelconsumption is based on current load
		for (var/F in fuels)
			if (fueltank && fueltank.reagents && fueltank.reagents.has_reagent(F, fuelconsumption) && done == FALSE)
				fueltank.reagents.remove_reagent(F, fuelconsumption)
				//add polution to global meter
				change_global_pollution(fuelconsumption)
				done = TRUE
		if (broken)
			on = FALSE
			power_off_connections()
			currentspeed = 0
			currentpower = 0
			update_icon()
			return
		if (!done)
			visible_message("The engine stalls.")
			playsound(loc, ending_snd, 100, FALSE, 3)
			on = FALSE
			power_off_connections()
			currentspeed = 0
			currentpower = 0
			update_icon()
			return
		else
			currentpower = process_power_output()

		spawn(10)
			running()
	return

///////////////////////ENGINES//////////////////////////////////////////////
/obj/structure/engine/internal/hotbulb
	name = "hot bulb engine"
	desc = "A big, somewhat inefficient engine, that can run on pretty much any liquid fuel."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "hotbulb_static"
	engineclass = "hotbulb"

	maxpower = 66
	torque = 1.1
	fuelefficiency = 0.5
	fuels = list("petroleum", "gasoline", "diesel", "pethanol", "biodiesel", "olive_oil", "fat_oil") //basically everything

/obj/structure/engine/internal/gasoline
	name = "four-stroke gasoline engine"
	desc = "A relatively cheap four-stroke gasoline engine."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "gasoline_static"
	engineclass = "gasoline"

	maxpower = 100
	torque = 0.9
	fuelefficiency = 0.3
	fuels = list("gasoline")

	starting_snd = 'sound/machines/gasoline_starting.ogg'
	running_snd = 'sound/machines/gasoline_loop.ogg'
	ending_snd = 'sound/machines/gasoline_ending.ogg'

/obj/structure/engine/internal/gasoline/twostroke
	name = "two-stroke gasoline engine"
	desc = "A cheap and simple two-stroke gasoline engine."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "gasoline_static"
	engineclass = "gasoline"

	maxpower = 90
	torque = 0.83
	fuelefficiency = 0.38
	fuels = list("gasoline")

/obj/structure/engine/internal/gasoline/sixstroke
	name = "six-stroke gasoline engine"
	desc = "A very efficient, altough costly, gasoline engine. Good fuel efficiency."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "gasoline6_static"
	engineclass = "gasoline6"

	maxpower = 90
	torque = 0.92
	fuelefficiency = 0.25
	fuels = list("gasoline")

/obj/structure/engine/internal/gasoline/ethanol
	name = "four-stroke gasoline-ethanol engine"
	desc = "A relatively cheap four-stroke gasoline engine, converted to use ethanol too. Can run on both fuels, but its around 15% less efficient."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "gasoline_static"
	engineclass = "gasoline"

	maxpower = 86
	torque = 0.77
	fuelefficiency = 0.35
	fuels = list("gasoline","pethanol")

/obj/structure/engine/internal/gasoline/wankel
	name = "Wankel rotary gasoline engine"
	desc = "A somewhat complex rotary engine. Very high Power-To-Weight ratio, but bad fuel economy."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "wankel_static"
	engineclass = "wankel"

	maxpower = 150
	torque = 0.83
	fuelefficiency = 0.37
	fuels = list("gasoline")

	starting_snd = 'sound/machines/gasoline_starting.ogg'
	running_snd = 'sound/machines/gasoline_loop.ogg'
	ending_snd = 'sound/machines/gasoline_ending.ogg'

/obj/structure/engine/internal/turbine
	name = "turbine engine"
	desc = "A turbine engine using an air compressor. High Power-To-Weight ratio and can run on a lot of fuels, but has bad fuel economy."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "turbine_static"
	engineclass = "turbine"

	maxpower = 136
	torque = 0.88
	fuelefficiency = 0.4
	fuels = list("petroleum", "gasoline", "diesel", "pethanol", "biodiesel", "olive_oil", "fat_oil")

	starting_snd = 'sound/machines/atomic_turbine_exterior_starting.ogg'
	running_snd = 'sound/machines/atomic_turbine_exterior_loop.ogg'
	ending_snd = 'sound/machines/atomic_turbine_exterior_ending.ogg'

	starting_snd_len = 39
	running_snd_len = 37

/obj/structure/engine/internal/diesel
	name = "diesel engine"
	desc = "A heavy diesel engine, using compression instead of spark plugs. High torque and fuel efficiency."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "diesel_static"
	engineclass = "diesel"

	maxpower = 80
	torque = 1.25
	fuelefficiency = 0.22
	fuels = list("diesel")

/obj/structure/engine/internal/diesel/biodiesel
	name = "diesel engine"
	desc = "A heavy diesel engine, using compression instead of spark plugs. High torque and fuel efficiency. Converted to accept Biodiesel too, but has 10% lower efficiency."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "diesel_static"
	engineclass = "diesel"

	maxpower = 72
	torque = 1.12
	fuelefficiency = 0.245
	fuels = list("diesel","biodiesel")

/obj/structure/engine/internal/hesselman
	name = "Hesselman engine"
	desc = "A hybrid gasoline and diesel engine. Better Power-To-Weight ratio than diesel but less efficient. Can run on Gasoline, Diesel, and Biodiesel."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "diesel_static"
	engineclass = "diesel"

	maxpower = 86
	torque = 1.08
	fuelefficiency = 0.37
	fuels = list("diesel","biodiesel","gasoline")

#undef FUEL_CONSUMPTION_MODIFIER
