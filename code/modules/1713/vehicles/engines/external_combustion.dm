///////////////////////EXTERNAL/////////////////////////////////////////////

//steam, sterling

/obj/structure/engine/external
	enginetype = "external"
	name = "external combustion engine"
	desc = "A basic engine."
	var/obj/structure/heatsource/heatsource = null
	weight = 30

/obj/structure/engine/external/turn_on(var/mob/user = null)
	if(heatsource)
		if(!on)
			if (heatsource.on)
				visible_message("[user] turns \the [src] on.","You turn \the [src] on.")
				playsound(loc, 'sound/machines/diesel_starting.ogg', 100, FALSE, 3)
				on = TRUE
				running()
				return
			else
				user << "<span class = 'notice'>You need to light the heat source first.</span>"
				on = FALSE
				return
	else
		user << "<span class = 'notice'>This engine needs an external heat source to work!</span>"
		on = FALSE
		return


/obj/structure/engine/external/running()
	if (on)
		if (!heatsource.on)
			visible_message("The engine stalls.")
			playsound(loc, 'sound/machines/diesel_ending.ogg', 100, FALSE, 3)
			on = FALSE
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
/obj/structure/engine/external/steam
	name = "steam engine"
	desc = "A big steam-powered engine. Low Power-To-Weight ratio, but good for static operations."
	icon = 'icons/obj/engines.dmi'
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

	maxpower = 38
	torque = 1.1
