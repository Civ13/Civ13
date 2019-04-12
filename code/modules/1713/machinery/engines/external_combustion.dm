///////////////////////EXTERNAL/////////////////////////////////////////////

//steam, sterling

/obj/structure/engine/external
	enginetype = "external"
	name = "external combustion engine"
	desc = "A basic engine."
	weight = 30
	var/defaultmaxpower = 0
/obj/structure/engine/external/turn_on(var/mob/user = null)
	var/pwd=0
	var/hts=0
	for(var/obj/structure/heatsource/HS in range(1,src))
		hts=1
		if (HS.on)
			pwd=1
	if (pwd && hts)
		if(!on)
			visible_message("[user] turns \the [src] on.","You turn \the [src] on.")
			playsound(loc, 'sound/machines/diesel_starting.ogg', 100, FALSE, 3)
			on = TRUE
			update_icon()
			running()
			spawn(40)
				running_sound()
			return
	else if (pwd && !hts)
		user << "<span class = 'notice'>You need to light the heat source first.</span>"
		on = FALSE
		return
	else
		user << "<span class = 'notice'>This engine needs an external heat source to work!</span>"
		on = FALSE
		return


/obj/structure/engine/external/running()
	var/pwd=0
	for(var/obj/structure/heatsource/HSI in range(1,src))
		if (HSI.on)
			pwd=1
	if (!pwd)
		visible_message("The engine stalls.")
		playsound(loc, 'sound/machines/diesel_ending.ogg', 100, FALSE, 3)
		on = FALSE
		power_off_connections()
		currentspeed = 0
		currentpower = 0
		update_icon()
		return
	else
		maxpower = 0
		for(var/obj/structure/heatsource/HS in range(1,src))
			if (HS.on)
				maxpower += 15
		if (maxpower > defaultmaxpower)
			maxpower = defaultmaxpower
		currentpower = process_power_output()
		spawn(10)
			running()
		for (var/obj/structure/cable/CB in connections)
			CB.power_on(maxpower)
		return

/obj/structure/engine/external/New()
	..()
	defaultmaxpower = maxpower
	maxpower = 0

///////////////////////ENGINES//////////////////////////////////////////////
/obj/structure/engine/external/steam
	name = "steam engine"
	desc = "A big steam-powered engine. Low Power-To-Weight ratio, but good for static operations."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "steam_static"
	engineclass = "steam"

	maxpower = 45
	torque = 1.4

/obj/structure/engine/external/stirling
	name = "Stirling engine"
	desc = "A large Stirling cycle engine. Very low Power-To-Weight ratio, but good for static operations, and can run on any source of heat or temperature difference, not just combustion."
	icon = 'icons/obj/engines.dmi'
	icon_state = "stirling_static"
	engineclass = "stirling"

	maxpower = 30
	torque = 1.1
