//////////////////////// VEHICLE FACTORY SYSTEM ////////////////////////
/// Factory pattern for creating complete vehicles from templates.
/// Eliminates manual assembly of frames, wheels, and components.

/// Global vehicle factory instance
var/global/datum/vehicle_factory/vehicle_factory = new()

/datum/vehicle_factory
	var/list/datum/vehicle_template/templates = list()

	New()
		..()
		// Light Vehicles
		templates["jeep"] = new /datum/vehicle_template()
		templates["jeep"].name = "Jeep"
		templates["jeep"].config = new /datum/vehicle_configuration("Jeep", "light", 2.5, 200, 15)
		templates["jeep"].tocreate = list(
			"1,1" = list(/obj/structure/vehicleparts/frame/car/type95/rf, /obj/structure/vehicleparts/movement, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline),
			"2,1" = list(/obj/structure/vehicleparts/frame/car/type95/lf, /obj/structure/vehicleparts/movement, /obj/structure/engine/internal/gasoline/premade/v6),
			"1,2" = list(/obj/structure/vehicleparts/frame/car/type95/rc, /obj/structure/bed/chair/carseat/right),
			"2,2" = list(/obj/structure/vehicleparts/frame/car/type95/lc, /obj/structure/bed/chair/drivers/car),
			"1,3" = list(/obj/structure/vehicleparts/frame/car/type95/rb, /obj/structure/vehicleparts/movement/reversed),
			"2,3" = list(/obj/structure/vehicleparts/frame/car/type95/lb, /obj/structure/vehicleparts/movement/reversed)
		)

		templates["truck"] = new /datum/vehicle_template()
		templates["truck"].name = "Truck"
		templates["truck"].config = new /datum/vehicle_configuration("Truck", "medium", 1.8, 350, 25)
		templates["truck"].tocreate = list(
			"1,1" = list(/obj/structure/vehicleparts/frame/car/type94/rf, /obj/structure/vehicleparts/movement, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline),
			"2,1" = list(/obj/structure/vehicleparts/frame/car/type94/lf, /obj/structure/vehicleparts/movement, /obj/structure/engine/internal/gasoline/premade/v6),
			"1,2" = list(/obj/structure/vehicleparts/frame/car/type94/rc, /obj/structure/bed/chair/carseat/right),
			"2,2" = list(/obj/structure/vehicleparts/frame/car/type94/lc, /obj/structure/bed/chair/drivers/car),
			"1,3" = list(/obj/structure/vehicleparts/frame/car/right),
			"2,3" = list(/obj/structure/vehicleparts/frame/car/left),
			"1,4" = list(/obj/structure/vehicleparts/frame/car/right),
			"2,4" = list(/obj/structure/vehicleparts/frame/car/left),
			"1,5" = list(/obj/structure/vehicleparts/frame/car/right, /obj/structure/vehicleparts/movement/reversed),
			"2,5" = list(/obj/structure/vehicleparts/frame/car/left, /obj/structure/vehicleparts/movement/reversed)
		)

		// Armored Vehicles
		templates["btr80"] = new /datum/vehicle_template()
		templates["btr80"].name = "BTR-80 APC"
		templates["btr80"].axis_type = /obj/structure/vehicleparts/axis/heavy
		templates["btr80"].tocreate = list(
			"1,1" = list(/obj/structure/vehicleparts/frame/btr80/rf, /obj/structure/vehicleparts/movement, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel),
			"2,1" = list(/obj/structure/vehicleparts/frame/btr80/lf, /obj/structure/vehicleparts/movement, /obj/structure/engine/internal/diesel/premade/v6),
			"1,2" = list(/obj/structure/vehicleparts/frame/btr80/rfc, /obj/structure/bed/chair/office/dark),
			"2,2" = list(/obj/structure/vehicleparts/frame/btr80/lfc, /obj/structure/bed/chair/drivers/car),
			"1,3" = list(/obj/structure/vehicleparts/frame/btr80/rbc, /obj/structure/bed/chair/office/dark),
			"2,3" = list(/obj/structure/vehicleparts/frame/btr80/lbc, /obj/structure/bed/chair/office/dark),
			"1,4" = list(/obj/structure/vehicleparts/frame/btr80/rb, /obj/structure/vehicleparts/movement/reversed),
			"2,4" = list(/obj/structure/vehicleparts/frame/btr80/lb, /obj/structure/vehicleparts/movement/reversed)
		)

		templates["mtlb"] = new /datum/vehicle_template()
		templates["mtlb"].name = "MT-LB APC"
		templates["mtlb"].axis_type = /obj/structure/vehicleparts/axis/heavy
		templates["mtlb"].tocreate = list(
			"1,1" = list(/obj/structure/vehicleparts/frame/mtlb/rf, /obj/structure/vehicleparts/movement/tracks, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel),
			"2,1" = list(/obj/structure/vehicleparts/frame/mtlb/lf, /obj/structure/vehicleparts/movement/tracks, /obj/structure/engine/internal/diesel/premade/v6),
			"1,2" = list(/obj/structure/vehicleparts/frame/mtlb/rfc, /obj/structure/bed/chair/office/dark),
			"2,2" = list(/obj/structure/vehicleparts/frame/mtlb/lfc, /obj/structure/bed/chair/drivers/car),
			"1,3" = list(/obj/structure/vehicleparts/frame/mtlb/rbc, /obj/structure/bed/chair/office/dark),
			"2,3" = list(/obj/structure/vehicleparts/frame/mtlb/lbc, /obj/structure/bed/chair/office/dark),
			"1,4" = list(/obj/structure/vehicleparts/frame/mtlb/rb, /obj/structure/vehicleparts/movement/tracks/reversed),
			"2,4" = list(/obj/structure/vehicleparts/frame/mtlb/lb, /obj/structure/vehicleparts/movement/tracks/reversed)
		)

		// Tanks
		templates["t34"] = new /datum/vehicle_template()
		templates["t34"].name = "T-34 Tank"
		templates["t34"].axis_type = /obj/structure/vehicleparts/axis/heavy/t34
		templates["t34"].tocreate = list(
			"1,1" = list(/obj/structure/vehicleparts/movement/tracks/t34/right_front, /obj/structure/vehicleparts/frame/t34/rf, /obj/structure/bed/chair/mgunner/dt28),
			"2,1" = list(/obj/structure/vehicleparts/frame/t34/front, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt),
			"3,1" = list(/obj/structure/vehicleparts/movement/tracks/t34/left_front, /obj/structure/vehicleparts/frame/t34/lf, /obj/structure/bed/chair/drivers/tank),
			"1,2" = list(/obj/structure/vehicleparts/frame/t34/right, /obj/structure/shellrack/full76),
			"2,2" = list(/obj/structure/vehicleparts/frame/t34/fc, /obj/structure/turret/t34),
			"3,2" = list(/obj/structure/vehicleparts/frame/t34/left, /obj/structure/shellrack/full76),
			"1,3" = list(/obj/structure/vehicleparts/frame/t34/right/door),
			"2,3" = list(/obj/structure/vehicleparts/frame/t34/bc, /obj/structure/shellrack/full76),
			"3,3" = list(/obj/structure/vehicleparts/frame/t34/left/door),
			"1,4" = list(/obj/structure/vehicleparts/movement/tracks/t34/right_back, /obj/structure/vehicleparts/frame/t34/rb, /obj/structure/engine/internal/diesel/premade/chiha),
			"2,4" = list(/obj/structure/vehicleparts/frame/t34/back),
			"3,4" = list(/obj/structure/vehicleparts/movement/tracks/t34/left_back, /obj/structure/vehicleparts/frame/t34/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
		)

		templates["bradley"] = new /datum/vehicle_template()
		templates["bradley"].name = "M2 Bradley IFV"
		templates["bradley"].axis_type = /obj/structure/vehicleparts/axis/heavy
		templates["bradley"].tocreate = list(
			"1,1" = list(/obj/structure/vehicleparts/frame/bradley/rf, /obj/structure/vehicleparts/movement/tracks, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel),
			"2,1" = list(/obj/structure/vehicleparts/frame/bradley/lf, /obj/structure/vehicleparts/movement/tracks, /obj/structure/engine/internal/diesel/premade/v6),
			"1,2" = list(/obj/structure/vehicleparts/frame/bradley/rfc, /obj/structure/bed/chair/office/dark),
			"2,2" = list(/obj/structure/vehicleparts/frame/bradley/lfc, /obj/structure/bed/chair/drivers/car),
			"1,3" = list(/obj/structure/vehicleparts/frame/bradley/rbc, /obj/structure/bed/chair/office/dark),
			"2,3" = list(/obj/structure/vehicleparts/frame/bradley/lbc, /obj/structure/bed/chair/office/dark),
			"1,4" = list(/obj/structure/vehicleparts/frame/bradley/rb, /obj/structure/vehicleparts/movement/tracks/reversed),
			"2,4" = list(/obj/structure/vehicleparts/frame/bradley/lb, /obj/structure/vehicleparts/movement/tracks/reversed)
		)

	/// Spawn a complete vehicle from template
	proc/spawn_vehicle(template_id, turf/location, direction = NORTH)
		if (!templates[template_id])
			return null

		var/datum/vehicle_template/template = templates[template_id]

		var/vmaxx = 1
		var/vmaxy = 1
		for (var/coords in template.tocreate)
			var/list/C = splittext(coords, ",")
			if (C.len != 2) continue
			var/dx = text2num(C[1])
			var/dy = text2num(C[2])
			if (dx > vmaxx) vmaxx = dx
			if (dy > vmaxy) vmaxy = dy

		// Create axis at the same relative position as premade.dm (max_x, 1)
		var/turf/axis_turf = locate(location.x + vmaxx, location.y + 1, location.z)
		if (!axis_turf) axis_turf = location
		
		var/obj/structure/vehicleparts/axis/axis = new template.axis_type(axis_turf)
		axis.name = template.name
		axis.dir = direction
		if (template.custom_color)
			axis.color = template.custom_color

		var/list/spawned_frames = list()
		var/list/spawned_movement = list()

		for (var/coords in template.tocreate)
			var/list/C = splittext(coords, ",")
			if (C.len != 2) continue
			var/dx = text2num(C[1])
			var/dy = text2num(C[2])
			var/turf/T = locate(location.x + dx, location.y + dy, location.z)
			if (!T) continue

			for (var/typepath in template.tocreate[coords])
				var/obj/O = new typepath(T)
				O.dir = direction
				
				if (istype(O, /obj/structure/vehicleparts/frame))
					var/obj/structure/vehicleparts/frame/F = O
					F.axis = axis
					if (!(F in axis.components))
						axis.components += F
					F.anchored = TRUE
					spawned_frames += F
				
				else if (istype(O, /obj/structure/vehicleparts/movement))
					spawned_movement += O

				else if (istype(O, /obj/structure/engine/internal))
					axis.engine = O
					O.anchored = TRUE

				else if (istype(O, /obj/structure/bed/chair/drivers))
					var/obj/structure/bed/chair/drivers/D = O
					axis.wheel = D.wheel
					if (axis.wheel)
						axis.wheel.control = O // or frame? usually it's the seat or frame
					O.anchored = TRUE

		// Initialise axis geometry first; MouseDrop() depends on corners
		axis.check_corners()

		// Link movement parts to frames
		for (var/obj/structure/vehicleparts/movement/M in spawned_movement)
			var/obj/structure/vehicleparts/frame/F = locate() in M.loc
			if (F)
				M.MouseDrop(F)

		// Initialize axis
		axis.check_matrix()

		for (var/obj/F in axis.components)
			F.update_icon()

		return axis

	/// Debug: Print template info
	proc/debug_templates()
		for (var/id in templates)
			var/datum/vehicle_template/T = templates[id]
			to_world("Template [id]: [T.name] ([T.config.type_class])")

// Global helper function for easy spawning
/proc/spawn_vehicle(template_id, turf/location, direction = NORTH)
	return vehicle_factory.spawn_vehicle(template_id, location, direction)

