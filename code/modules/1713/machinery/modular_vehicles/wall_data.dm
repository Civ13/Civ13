//////////////////////// VEHICLE WALL/ARMOR SYSTEM ////////////////////////
/// Manages vehicle walls and armor panels with proper encapsulation.
/// Replaces the old list-based system with proper datum objects.

/// Manages all 4 sides of vehicle armor
/datum/vehicle_walls
	var/datum/wall_config/front
	var/datum/wall_config/back
	var/datum/wall_config/left
	var/datum/wall_config/right

	New()
		front = new /datum/wall_config()
		back = new /datum/wall_config()
		left = new /datum/wall_config()
		right = new /datum/wall_config()

	/// Get wall in specific direction
	proc/get_wall(direction)
		switch(direction)
			if (NORTH)
				return front
			if (SOUTH)
				return back
			if (WEST)
				return left
			if (EAST)
				return right
		return null

	/// Set wall in specific direction
	proc/set_wall(direction, type_name)
		var/datum/wall_config/W = new /datum/wall_config(type_name)
		switch(direction)
			if (NORTH)
				front = W
			if (SOUTH)
				back = W
			if (WEST)
				left = W
			if (EAST)
				right = W

	/// Check if player can exit vehicle in given direction
	proc/can_exit(direction)
		var/datum/wall_config/W = get_wall(direction)
		if (!W)
			return TRUE  // No wall configured, can exit
		if (!W.blocks_passage())
			return TRUE  // Wall doesn't block or is open
		return FALSE

	/// Check if something can enter vehicle from direction
	proc/can_enter(direction)
		var/datum/wall_config/W = get_wall(direction)
		if (!W || W.wall_type == "")
			return TRUE
		if (W.blocks_passage())
			return FALSE
		return TRUE

	/// Get wall based on world entry direction and vehicle orientation
	proc/get_wall_relative(world_dir, axis_dir)
		var/rel_dir = get_relative_dir(world_dir, axis_dir)
		return get_wall(rel_dir)

	/// Check if entry is possible from a world direction given vehicle orientation
	proc/can_enter_relative(world_dir, axis_dir)
		var/rel_dir = get_relative_dir(world_dir, axis_dir)
		var/datum/wall_config/W = get_wall(rel_dir)
		if (!W || W.wall_type == "")
			return FALSE // Solid hull if no wall/door
		return !W.blocks_passage()

	/// Check if exit is possible to a world direction given vehicle orientation
	proc/can_exit_relative(world_dir, axis_dir)
		var/rel_dir = get_relative_dir(world_dir, axis_dir)
		var/datum/wall_config/W = get_wall(rel_dir)
		if (!W || W.wall_type == "")
			return TRUE // Can always walk off an open side
		return !W.blocks_passage()

	/// Convert world direction to relative direction based on axis orientation
	proc/get_relative_dir(world_dir, axis_dir)
		switch(axis_dir)
			if (NORTH)
				return world_dir
			if (SOUTH)
				return OPPOSITE_DIR(world_dir)
			if (EAST)
				return turn(world_dir, 90)
			if (WEST)
				return turn(world_dir, -90)
		return world_dir

	/// Apply damage to wall in direction
	proc/damage_wall(direction, damage)
		var/datum/wall_config/W = get_wall(direction)
		if (W)
			return W.take_damage(damage)
		return FALSE

	/// Get all walls for iteration
	proc/get_all_walls()
		return list(front, back, left, right)

	/// Check if any walls are broken
	proc/has_broken_walls()
		for (var/datum/wall_config/W in get_all_walls())
			if (W.is_broken())
				return TRUE
		return FALSE

	/// Get total armor rating across all sides
	proc/get_total_armor()
		var/total = 0
		for (var/datum/wall_config/W in get_all_walls())
			if (!W.is_broken())
				total += W.armor
		return total

	/// Get average health percentage
	proc/get_average_health()
		var/total_health = 0
		var/count = 0
		for (var/datum/wall_config/W in get_all_walls())
			if (W.max_health > 0)
				total_health += W.current_health
				count++
		if (count == 0)
			return 100
		return (total_health / (count * 50)) * 100  // Assuming max ~50 health per wall


/// Individual wall section
/datum/wall_section
	var/owner  // Reference to frame or vehicle
	var/direction  // NORTH, SOUTH, EAST, WEST
	var/datum/wall_config/wconfig

	New(owner_ref, dir, wall_type = "")
		owner = owner_ref
		direction = dir
		wconfig = new /datum/wall_config(wall_type)

	proc/try_exit(mob/living/M)
		if (!wconfig.blocks_passage())
			return TRUE
		if (wconfig.is_open)
			return TRUE
		return FALSE

	proc/take_damage(damage)
		wconfig.take_damage(damage)
		if (owner && hascall(owner, "update_icon"))
			call(owner, "update_icon")()

	proc/toggle()
		if (wconfig.can_open)
			wconfig.toggle_open()
			if (owner && hascall(owner, "update_icon"))
				call(owner, "update_icon")()
			return TRUE
		return FALSE

	proc/get_icon_state()
		if (wconfig.is_broken())
			// Return broken state icon
			return "[wconfig.icon_state]_broken"
		if (wconfig.is_open)
			return "[wconfig.icon_state]_open"
		return wconfig.icon_state
