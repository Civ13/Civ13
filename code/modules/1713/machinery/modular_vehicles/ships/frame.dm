/obj/structure/vehicleparts/frame/ship
	name = "ship frame"
	desc = "a wood ship frame."
	icon = 'icons/obj/vehicleparts_boats.dmi'
	icon_state = "boat_floor1"
	normal_icon = 'icons/obj/vehicleparts_boats.dmi'
	broken_icon = 'icons/obj/vehicleparts_boats.dmi'
	noroof = TRUE
	New()
		..()
		roof = image(icon=icon, loc=src, icon_state="boat2", layer=8)
		roof.override = TRUE
		spawn(1)
			update_icon()