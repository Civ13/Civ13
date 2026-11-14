// The airliner (multi-deck vehicles plan, Phase 1d): the twin-engine airframe
// (aircraft_twin.dm) with a cabin three rows long, seats either side of an
// aisle the passengers walk down. 5 sections wide and 6 long, it turns in a
// 6x6 square and needs a long roll. Facing north, rows from the nose:
//
//   open        engine L    nose        engine R    open
//   wing tip L  nacelle L   cockpit     nacelle R   wing tip R
//   open        seat        aisle       seat        open      (x3)
//   tailplane L tail L      tail        tail R      tailplane R
//
// It reuses the twin's art: the cabin rows are its fuselage row repeated.

/obj/structure/vehicleparts/axis/aircraft/airliner
	name = "airliner"
	desc = "The controls of a twin-engine airliner with a walk-through cabin."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	maxpower = 1600
	takeoff_roll = 16
	rough_takeoff_roll = 30

// Built facing south like every hangar plane, so "1,1" is the plane's right.
/proc/aircraft_airliner_layout()
	var/static/list/layout = null
	if (layout)
		return layout
	layout = list()
	. = layout
	for (var/key in aircraft_twin_plane_layout)
		var/list/C = splittext(key, ",")
		var/col = text2num(C[1])
		var/row = text2num(C[2])
		var/list/parts = aircraft_twin_plane_layout[key]
		if (row <= 2)
			.[key] = parts.Copy()
		else if (row == 4)
			.["[col],6"] = parts.Copy()
	for (var/row in 3 to 5)
		.["1,[row]"] = list(/obj/structure/vehicleparts/frame/car/aircraft/twin_open)
		.["2,[row]"] = list(/obj/structure/vehicleparts/frame/car/aircraft/fuselage/right, /obj/structure/bed/chair/carseat/aircraft_cabin)
		.["3,[row]"] = list(/obj/structure/vehicleparts/frame/car/aircraft/fuselage/center)
		.["4,[row]"] = list(/obj/structure/vehicleparts/frame/car/aircraft/fuselage/left, /obj/structure/bed/chair/carseat/aircraft_cabin)
		.["5,[row]"] = list(/obj/structure/vehicleparts/frame/car/aircraft/twin_open)
