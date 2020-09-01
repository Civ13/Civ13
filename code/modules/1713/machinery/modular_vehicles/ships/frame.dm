/obj/structure/vehicleparts/frame/ship
	name = "ship frame"
	desc = "a wood ship frame."
	icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	icon_state = "boat_floor1"
	normal_icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	broken_icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	noroof = TRUE
	var/prefix = ""
	New()
		..()
		roof = image(icon=icon, loc=src, icon_state="boat2", layer=8)
		roof.override = TRUE
		spawn(1)
			update_icon()

/obj/structure/vehicleparts/frame/ship/steel
	name = "steel ship frame"
	desc = "a steel ship frame."
	icon_state = "Mboat_floor1"
	prefix = "M"
	New()
		..()
		roof.icon_state = "Mboat2"