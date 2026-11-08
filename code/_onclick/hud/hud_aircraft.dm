// Aircraft HUD: three buttons under the gear controls that only show while the driver's
// seat belongs to an aircraft: the height state, Climb and Descend.

/obj/screen/vehicle/flight
	icon_state = "speed_off"
	maptext_width = 32
	maptext_height = 32
	maptext_y = 10
	process_flag = TRUE
	alpha = 0
	mouse_opacity = 0

/obj/screen/vehicle/flight/proc/flown_aircraft()
	var/obj/structure/vehicleparts/axis/aircraft/A = resolve_driver_axis()
	return istype(A) ? A : null

/obj/screen/vehicle/flight/proc/label(text)
	maptext = "<span style='font-size:7pt;color:#ffffff;text-align:center;-dm-text-outline:1px #000000'>[text]</span>"

/obj/screen/vehicle/flight/process()
	update_icon()

/obj/screen/vehicle/flight/update_icon()
	..()
	var/obj/structure/vehicleparts/axis/aircraft/A = flown_aircraft()
	if (!A)
		alpha = 0
		mouse_opacity = 0
		maptext = null
		return
	alpha = 255
	mouse_opacity = 1
	refresh_label(A)

/obj/screen/vehicle/flight/proc/refresh_label(obj/structure/vehicleparts/axis/aircraft/A)
	return

/obj/screen/vehicle/flight/state
	name = "height"
	screen_loc = "14,13"

/obj/screen/vehicle/flight/state/refresh_label(obj/structure/vehicleparts/axis/aircraft/A)
	switch (A.flight_state)
		if (AIRCRAFT_LOW)
			label("LOW")
		if (AIRCRAFT_CRUISE)
			label("CRUISE")
		else
			label("GROUND")

/obj/screen/vehicle/flight/climb
	name = "climb"
	screen_loc = "15,13"

/obj/screen/vehicle/flight/climb/refresh_label(obj/structure/vehicleparts/axis/aircraft/A)
	label("CLIMB")

/obj/screen/vehicle/flight/climb/Click()
	var/obj/structure/vehicleparts/axis/aircraft/A = flown_aircraft()
	if (A && parentmob && A.key_access(parentmob))
		A.climb(parentmob)

/obj/screen/vehicle/flight/descend
	name = "descend"
	screen_loc = "13,13"

/obj/screen/vehicle/flight/descend/refresh_label(obj/structure/vehicleparts/axis/aircraft/A)
	label("DESCEND")

/obj/screen/vehicle/flight/descend/Click()
	var/obj/structure/vehicleparts/axis/aircraft/A = flown_aircraft()
	if (A && parentmob && A.key_access(parentmob))
		A.descend(parentmob)
