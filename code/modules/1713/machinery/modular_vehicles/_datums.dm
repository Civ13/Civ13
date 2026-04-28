//////////////////////// MODULAR VEHICLES CONFIGURATION DATUMS ////////////////////////
/// Defines configuration objects for vehicles, wheels, and walls.
/// This replaces scattered vars and deep type hierarchies with composable data.

/// Base configuration for a vehicle
/datum/vehicle_configuration
	var/name = "Generic Vehicle"
	var/desc = "A modular vehicle."
	var/type_class = "light"  // light, medium, heavy, apc
	var/icon = 'icons/obj/vehicles/vehicleparts.dmi'

	/// Movement
	var/base_speed = 1.0
	var/turn_speed = 15  // Lower = faster turning
	var/max_weight = 100

	/// Structure
	var/armor = 10
	var/max_health = 150
	var/current_health = 150

	/// Physics
	var/weight_multiplier = 1.0
	var/speed_multiplier = 1.0

	/// Components
	var/max_components = 25
	var/max_distance = 5
	var/min_wheels = 4

	/// Display
	var/default_color = rgb(128, 128, 128)
	var/has_roof = TRUE
	var/roof_opacity = TRUE

	New(name = "", type_class = "light", base_speed = 1.0, max_health = 150, armor = 10)
		if (name) src.name = name
		if (type_class) src.type_class = type_class
		if (base_speed) src.base_speed = base_speed
		if (max_health) src.max_health = max_health
		if (armor) src.armor = armor
		src.current_health = src.max_health


/// Configuration for wheels and tracks
/datum/wheel_config
	var/name = "Standard Wheel"
	var/type_name = "wheel"  // "wheel" or "track"
	var/icon = 'icons/obj/vehicles/vehicleparts.dmi'
	var/icon_state = "wheel_default"
	var/base_icon_state = "wheel_default"
	var/movement_icon_state = "wheel_default_m"

	/// Performance
	var/base_speed = 1.0
	var/off_road_penalty = 1.0
	var/armor = 0
	var/max_health = 50
	var/current_health = 50

	/// Position-based variants (for tracked vehicles)
	var/position = "front"  // "front", "back", or "center"
	var/side = "left"       // "left" or "right"

	/// Behavior
	var/is_reversed = FALSE

	/// Initialization with named arguments
	New(name, type_name, icon, icon_state, base_icon_state, movement_icon_state, is_reversed, armor, max_health, position, side)
		if(name) src.name = name
		if(type_name) src.type_name = type_name
		if(icon) src.icon = icon
		if(icon_state) src.icon_state = icon_state
		if(base_icon_state) src.base_icon_state = base_icon_state
		if(movement_icon_state) src.movement_icon_state = movement_icon_state
		if(!isnull(is_reversed)) src.is_reversed = is_reversed
		if(!isnull(armor)) src.armor = armor
		if(!isnull(max_health)) { src.max_health = max_health; src.current_health = max_health }
		if(position) src.position = position
		if(side) src.side = side

/// Configuration for vehicle walls/armor
/datum/wall_config
	var/wall_type = ""      // References VEHICLE_WALLS keys
	var/icon_state = ""
	var/opacity = FALSE
	var/density = FALSE
	var/armor = 0
	var/max_health = 40
	var/current_health = 40
	var/can_open = FALSE
	var/is_open = FALSE

	/// Create a wall from type name
	New(type_name = "")
		if (VEHICLE_CONSTANTS.VEHICLE_WALLS[type_name])
			var/list/wall_data = VEHICLE_CONSTANTS.VEHICLE_WALLS[type_name]
			wall_type = wall_data["type"]
			icon_state = wall_data["icon_state"]
			opacity = wall_data["opacity"]
			density = wall_data["density"]
			armor = wall_data["armor"]
			max_health = wall_data["max_health"]
			current_health = max_health
			can_open = wall_data["can_open"]

	/// Take damage to this wall
	proc/take_damage(damage)
		if (current_health <= 0)
			return FALSE
		current_health = max(0, current_health - damage)
		return TRUE

	/// Check if wall blocks passage
	proc/blocks_passage()
		if (is_open)
			return FALSE
		return density && (current_health > 0)

	/// Check if wall is destroyed
	proc/is_broken()
		return current_health <= 0

	/// Toggle door open/closed
	proc/toggle_open()
		if (!can_open)
			return FALSE
		is_open = !is_open
		return TRUE

	/// Get display opacity based on state
	proc/get_opacity()
		if (is_open)
			return FALSE
		return opacity

	/// Get visual density based on state and health
	proc/get_density()
		if (is_broken())
			return FALSE
		if (is_open)
			return FALSE
		return density


/// Configuration for vehicle engines
/datum/engine_config
	var/name = "Standard Engine"
	var/max_fuel = 100
	var/fuel_consumption = 1.0
	var/power_output = 100
	var/starting_time = 40
	var/idle_sound = "sound/machines/engine_idle.ogg"
	var/running_sound = "sound/machines/engine_running.ogg"


/// Registry for premade vehicle configurations
/datum/vehicle_template
	var/name = "Vehicle Template"
	var/datum/vehicle_configuration/config
	var/list/wheel_configs = alist()  // Indexed by position
	var/default_walls = alist()        // Indexed by direction

	/// Create a complete vehicle from this template
	proc/build_vehicle(var/obj/spawn_location)
		// Implementation in Phase 6 (Factory Pattern)
		return null
