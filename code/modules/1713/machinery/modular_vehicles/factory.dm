//////////////////////// VEHICLE FACTORY SYSTEM ////////////////////////
/// Factory pattern for creating complete vehicles from templates.
/// Eliminates manual assembly of frames, wheels, and components.

/// Global vehicle factory instance
var/global/datum/vehicle_factory/vehicle_factory = new()

/datum/vehicle_factory
	var/static/list/templates = list()

	New()
		..()
		build_templates()

	/// Build all premade vehicle templates
	proc/build_templates()
		// Light Vehicles
		templates["jeep"] = new /datum/vehicle_template(
			name = "Jeep",
			wconfig = new /datum/vehicle_configuration("Jeep", "light", 2.5, 200, 15),
			wheel_configs = alist(
				"front_left" = "standard_wheel",
				"front_right" = "standard_wheel",
				"back_left" = "standard_wheel_reversed",
				"back_right" = "standard_wheel_reversed"
			),
			default_walls = alist(
				"front" = "c_windshield",
				"back" = "c_wall",
				"left" = "c_windowdoor",
				"right" = "c_windowdoor"
			),
		)

		templates["truck"] = new /datum/vehicle_template(
			name = "Truck",
			wconfig = new /datum/vehicle_configuration("Truck", "medium", 1.8, 350, 25),
			wheel_configs = alist(
				"front_left" = "armored_wheel",
				"front_right" = "armored_wheel",
				"back_left" = "armored_wheel_reversed",
				"back_right" = "armored_wheel_reversed"
			),
			default_walls = alist(
				"front" = "c_armoredfront",
				"back" = "c_wall",
				"left" = "c_windowdoor",
				"right" = "c_windowdoor"
			),
		)

		// Armored Vehicles
		templates["btr80"] = new /datum/vehicle_template(
			name = "BTR-80 APC",
			wconfig = new /datum/vehicle_configuration("BTR-80", "apc", 1.6, 450, 35),
			wheel_configs = alist(
				"front_left" = "btr80_wheel_front_left",
				"front_right" = "btr80_wheel_front_right",
				"back_left" = "btr80_wheel_back_left",
				"back_right" = "btr80_wheel_back_right",
			),
			default_walls = alist(
				"front" = "c_armoredfront",
				"back" = "c_armoredwall",
				"left" = "c_armoredwall",
				"right" = "c_armoredwall",
			),
		)

		templates["mtlb"] = new /datum/vehicle_template(
			name = "MT-LB APC",
			wconfig = new /datum/vehicle_configuration("MT-LB", "apc", 1.4, 500, 40),
			wheel_configs = alist(
				"front_left" = "mtlb_track_left_front",
				"front_right" = "mtlb_track_right_front",
				"back_left" = "mtlb_track_left_back",
				"back_right" = "mtlb_track_right_back",
			),
			default_walls = list(
				"front" = "c_armoredfront",
				"back" = "c_armoredwall",
				"left" = "c_armoredwall",
				"right" = "c_armoredwall",
			),
		)

		// Tanks
		templates["t34"] = new /datum/vehicle_template(
			name = "T-34 Tank",
			wconfig = new /datum/vehicle_configuration("T-34", "heavy", 0.9, 600, 55),
			wheel_configs = alist(
				"front_left" = "t34_track_left_front",
				"front_right" = "t34_track_right_front",
				"back_left" = "t34_track_left_back",
				"back_right" = "t34_track_right_back",
			),
			default_walls = alist(
				"front" = "c_armoredfront",
				"back" = "c_armoredwall",
				"left" = "c_armoredwall",
				"right" = "c_armoredwall",
			),
		)

		templates["is3"] = new /datum/vehicle_template(
			name = "IS-3 Tank",
			wconfig = new /datum/vehicle_configuration("IS-3", "heavy", 0.8, 650, 60),
			wheel_configs = alist(
				"front_left" = "is3_track_left_front",
				"front_right" = "is3_track_right_front",
				"back_left" = "is3_track_left_back",
				"back_right" = "is3_track_right_back",
			),
			default_walls = alist(
				"front" = "c_armoredfront",
				"back" = "c_armoredwall",
				"left" = "c_armoredwall",
				"right" = "c_armoredwall",
			),
		)

		templates["is2"] = new /datum/vehicle_template(
			name = "IS-2 Tank",
			wconfig = new /datum/vehicle_configuration("IS-2", "heavy", 0.85, 630, 58),
			wheel_configs = alist(
				"front_left" = "is2_track_left_front",
				"front_right" = "is2_track_right_front",
				"back_left" = "is2_track_left_back",
				"back_right" = "is2_track_right_back",
			),
			default_walls = alist(
				"front" = "c_armoredfront",
				"back" = "c_armoredwall",
				"left" = "c_armoredwall",
				"right" = "c_armoredwall",
			),
		)

		templates["char1"] = new /datum/vehicle_template(
			name = "Char-B1 Tank",
			wconfig = new /datum/vehicle_configuration("Char-B1", "heavy", 1.1, 550, 50),
			wheel_configs = alist(
				"front_left" = "char1_track_left_front",
				"front_right" = "char1_track_right_front",
				"back_left" = "char1_track_left_back",
				"back_right" = "char1_track_right_back",
			),
			default_walls = alist(
				"front" = "c_armoredfront",
				"back" = "c_armoredwall",
				"left" = "c_armoredwall",
				"right" = "c_armoredwall",
			),
		)

		templates["m41"] = new /datum/vehicle_template(
			name = "M41 Walker Bulldog",
			wconfig = new /datum/vehicle_configuration("M41", "heavy", 1.2, 400, 30),
			wheel_configs = alist(
				"front_left" = "m41_track_left_front",
				"front_right" = "m41_track_right_front",
				"back_left" = "m41_track_left_back",
				"back_right" = "m41_track_right_back",
			),
			default_walls = alist(
				"front" = "c_armoredfront",
				"back" = "c_armoredwall",
				"left" = "c_armoredwall",
				"right" = "c_armoredwall",
			),
		)

		templates["bmd2"] = new /datum/vehicle_template(
			name = "BMD-2 APC",
			wconfig = new /datum/vehicle_configuration("BMD-2", "apc", 1.2, 350, 25),
			wheel_configs = alist(
				"front_left" = "bmd2_track_left_front",
				"front_right" = "bmd2_track_right_front",
				"back_left" = "bmd2_track_left_back",
				"back_right" = "bmd2_track_right_back",
			),
			default_walls = alist(
				"front" = "c_armoredfront",
				"back" = "c_armoredwall",
				"left" = "c_armoredwall",
				"right" = "c_armoredwall",
			),
		)

		templates["bradley"] = new /datum/vehicle_template(
			name = "M2 Bradley IFV",
			wconfig = new /datum/vehicle_configuration("Bradley", "apc", 1.4, 450, 35),
			wheel_configs = alist(
				"front_left" = "bradley_track_left_front",
				"front_right" = "bradley_track_right_front",
				"back_left" = "bradley_track_left_back",
				"back_right" = "bradley_track_right_back",
			),
			default_walls = alist(
				"front" = "c_armoredfront",
				"back" = "c_armoredwall",
				"left" = "c_armoredwall",
				"right" = "c_armoredwall",
			),
		)

		templates["hago"] = new /datum/vehicle_template(
			name = "Type 95 Ha-Go",
			wconfig = new /datum/vehicle_configuration("Ha-Go", "heavy", 1.3, 300, 20),
			wheel_configs = alist(
				"front_left" = "hago_track_left_front",
				"front_right" = "hago_track_right_front",
				"back_left" = "hago_track_left_back",
				"back_right" = "hago_track_right_back",
			),
			default_walls = alist(
				"front" = "c_armoredfront",
				"back" = "c_armoredwall",
				"left" = "c_armoredwall",
				"right" = "c_armoredwall",
			),
		)

		templates["m113"] = new /datum/vehicle_template(
			name = "M113 APC",
			wconfig = new /datum/vehicle_configuration("M113", "apc", 1.7, 300, 15),
			wheel_configs = alist(
				"front_left" = "m113_track_left_front",
				"front_right" = "m113_track_right_front",
				"back_left" = "m113_track_left_back",
				"back_right" = "m113_track_right_back",
			),
			default_walls = alist(
				"front" = "c_armoredfront",
				"back" = "c_armoredwall",
				"left" = "c_armoredwall",
				"right" = "c_armoredwall",
			),
		)

	/// Spawn a complete vehicle from template
	proc/spawn_vehicle(template_id, turf/location, direction = NORTH)
		if (!templates[template_id])
			return null

		var/datum/vehicle_template/template = templates[template_id]

		// Create axis
		var/obj/structure/vehicleparts/axis/axis = new(location)
		axis.name = template.config.name
		axis.dir = direction

		// Create frames in a 2x2 grid (front-left, front-right, back-left, back-right)
		var/list/frame_positions = list(
			list(0, 1, "front_left"),   // x, y, position_name
			list(1, 1, "front_right"),
			list(0, 0, "back_left"),
			list(1, 0, "back_right"),
		)

		var/list/frames = list()
		for (var/list/pos_data in frame_positions)
			var/turf/frame_turf = locate(location.x + pos_data[1], location.y + pos_data[2], location.z)
			if (!frame_turf)
				continue

			var/obj/structure/vehicleparts/frame/frame = new(frame_turf)
			frame.axis = axis
			frame.name = "[template.config.name] Frame"
			frame.dir = direction

			// Set walls based on position
			var/pos_name = pos_data[3]
			if (pos_name == "front_left")
				frame.initialize_walls(template.default_walls["front"], template.default_walls["back"], template.default_walls["left"], template.default_walls["right"])
			else if (pos_name == "front_right")
				frame.initialize_walls(template.default_walls["front"], template.default_walls["back"], template.default_walls["right"], template.default_walls["left"])
			else if (pos_name == "back_left")
				frame.initialize_walls(template.default_walls["back"], template.default_walls["front"], template.default_walls["left"], template.default_walls["right"])
			else if (pos_name == "back_right")
				frame.initialize_walls(template.default_walls["back"], template.default_walls["front"], template.default_walls["right"], template.default_walls["left"])

			frames[pos_name] = frame
			axis.components += frame

		axis.check_corners()
		// Attach wheels/tracks
		for (var/pos_name in template.wheel_configs)
			var/obj/structure/vehicleparts/frame/frame = frames[pos_name]
			if (!frame || !frame.loc)
				continue

			var/datum/wheel_config/wheel_config = get_wheel_config(template.wheel_configs[pos_name])
			var/obj/structure/vehicleparts/movement/movement = new frame.type(wheel_config)
			if (movement)
				// Initialize with config
				movement.wconfig = wheel_config
				if (wheel_config)
					movement.name = wheel_config.name
					movement.icon = wheel_config.icon
					movement.icon_state = wheel_config.icon_state
				// Simulate MouseDrop to attach to frame
				movement.MouseDrop(frame)

		// Initialize axis
		axis.check_corners()
		axis.check_matrix()

		return axis

	/// Get list of available templates
	proc/get_template_list()
		var/list/result = list()
		for (var/id in templates)
			var/datum/vehicle_template/T = templates[id]
			result[id] = T.name
		return result

	/// Debug: Print template info
	proc/debug_templates()
		for (var/id in templates)
			var/datum/vehicle_template/T = templates[id]
			to_world("Template [id]: [T.name] ([T.config.type_class])")

// Global helper function for easy spawning
/proc/spawn_vehicle(template_id, turf/location, direction = NORTH)
	return vehicle_factory.spawn_vehicle(template_id, location, direction)

/client/proc/spawn_modular_vehicle()
	set category = "Admin"
	set name = "Spawn Modular Vehicle"

	if (!holder)
		return
	
	if (!check_rights(R_SPAWN))
		return

	var/list/templates = vehicle_factory.get_template_list()
	var/template_id = input(usr, "Select a vehicle template:", "Vehicle Factory") as null|anything in templates
	if (!template_id)
		return

	var/direction_text = input(usr, "Select direction:", "Vehicle Factory") as null|anything in list("NORTH", "SOUTH", "EAST", "WEST")
	if (!direction_text)
		return

	var/direction = NORTH
	switch(direction_text)
		if("NORTH") direction = NORTH
		if("SOUTH") direction = SOUTH
		if("EAST") direction = EAST
		if("WEST") direction = WEST

	var/turf/T = get_turf(usr)
	if (!T)
		return

	var/obj/structure/vehicleparts/axis/axis = vehicle_factory.spawn_vehicle(template_id, T, direction)
	if (axis)
		to_chat(usr, "Successfully spawned [axis.name] at [T.x], [T.y], [T.z].")
		message_admins("[key_name(src)] spawned a vehicle, [axis.name] ([T.x], [T.y], [T.z])", key_name(src))
		log_admin("[key_name(src)] spawned a vehicle, [axis.name] ([T.x], [T.y], [T.z])")
	else
		to_chat(usr, "Failed to spawn vehicle.")