
/obj/structure/vehicleparts
	name = "vehicle part"
	desc = "a basic vehicle part."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "part"
	anchored = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	flammable = FALSE

/obj/structure/vehicleparts/axis
	name = "vehicle axis"
	desc = "supports wheels."
	icon_state = "axis"
	var/list/wheels = list()
	var/currentspeed = 10 //5 to 10, 5 being the fastest (less delay)

/obj/structure/vehicleparts/axis/proc/get_speed()
	if (powered)
		return currentspeed
	else
		return 0