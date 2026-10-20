// Original experimental native-Move kernel; repository AGPL-3.0 applies.
// No Civ13 player/client integration and no change to the normal game DME.
#ifdef SUBTILE_FEASIBILITY

/obj/subtile_actor
	density = 1
	bound_x = 0
	bound_y = 0
	bound_width = 32
	bound_height = 32
	step_size = 4
	glide_size = 0
	var/bumps = 0

/obj/subtile_actor/Bump(atom/obstacle)
	bumps++
	return ..()

/datum/subtile_kernel
	var/obj/subtile_actor/actor
	var/cosmetic_control = 0
	var/call_tick = -1
	var/calls = 0

/datum/subtile_kernel/New(obj/subtile_actor/owner, control = 0)
	actor = owner
	cosmetic_control = control

/datum/subtile_kernel/proc/position()
	return list("x" = actor.x, "y" = actor.y, "z" = actor.z, "sx" = actor.step_x, "sy" = actor.step_y)

/datum/subtile_kernel/proc/valid_owner()
	return actor && isturf(actor.loc) && actor.bound_x == 0 && actor.bound_y == 0 && actor.bound_width == 32 && actor.bound_height == 32 && world.icon_size == 32 && valid_integer(actor.step_x) && valid_integer(actor.step_y) && actor.step_x >= 0 && actor.step_x < 32 && actor.step_y >= 0 && actor.step_y < 32

/datum/subtile_kernel/proc/valid_integer(value)
	return isnum(value) && value == round(value)

// Fixed work bound: at most eight calls per engine tick. For ordinary attempts
// that is at most32 requested pixels; synthetic placement is not travel.
// This is NOT the game's speed/cooldown policy or a new client scheduler.
/datum/subtile_kernel/proc/admit(deadline)
	if (!isnum(deadline) || deadline < world.time || deadline > world.time + 1)
		return "deadline"
	if (call_tick == world.time && calls >= 8)
		return "budget"
	return null

/datum/subtile_kernel/proc/native_position(turf/destination, sx, sy, direction)
	var/list/before = position()
	if (call_tick != world.time)
		call_tick = world.time
		calls = 0
	calls++
	var/engine_return
	if (cosmetic_control)
		// Deliberately wrong causal control: visual changes cannot move bounds.
		actor.pixel_x += (destination.x - actor.x) * 32 + sx - actor.step_x
		actor.pixel_y += (destination.y - actor.y) * 32 + sy - actor.step_y
		engine_return = 1
	else
		engine_return = actor.Move(destination, direction, sx, sy)
	var/list/after = position()
	var/dx = (after["x"] - before["x"]) * 32 + after["sx"] - before["sx"]
	var/dy = (after["y"] - before["y"]) * 32 + after["sy"] - before["sy"]
	return list("accepted" = 1, "engine_return" = engine_return, "before" = before, "after" = after, "dx" = dx, "dy" = dy, "reached" = actor.loc == destination && actor.step_x == sx && actor.step_y == sy)

/datum/subtile_kernel/proc/attempt(dx, dy, deadline)
	if (!valid_owner())
		return list("accepted" = 0, "reason" = "owner")
	if (!valid_integer(dx) || !valid_integer(dy) || (dx && dy) || abs(dx) + abs(dy) < 1 || abs(dx) + abs(dy) > 4)
		return list("accepted" = 0, "reason" = "cardinal_step")
	var/reason = admit(deadline)
	if (reason)
		return list("accepted" = 0, "reason" = reason)
	var/tx = actor.x
	var/ty = actor.y
	var/sx = actor.step_x + dx
	var/sy = actor.step_y + dy
	// Native Move normalizes too; explicit normalization makes the request auditable.
	while (sx < 0)
		tx--
		sx += 32
	while (sx >= 32)
		tx++
		sx -= 32
	while (sy < 0)
		ty--
		sy += 32
	while (sy >= 32)
		ty++
		sy -= 32
	var/turf/destination = locate(tx, ty, actor.z)
	if (!destination)
		return list("accepted" = 0, "reason" = "map_edge")
	var/direction = dx > 0 ? EAST : dx < 0 ? WEST : dy > 0 ? NORTH : SOUTH
	return native_position(destination, sx, sy, direction)

// Synthetic scalar offset policy only. This is not the Civ13 graph codec.
// Same-z restore can be a jump: destination collision, NOT swept travel.
// Rejection never forces the loc; this is not a route around intermediate walls.
/datum/subtile_kernel/proc/restore_position(list/saved, deadline)
	if (!valid_owner() || !islist(saved) || saved.len != 5)
		return list("accepted" = 0, "reason" = "snapshot")
	for (var/key in list("x", "y", "z", "sx", "sy"))
		if (!valid_integer(saved[key]))
			return list("accepted" = 0, "reason" = "snapshot")
	if (saved["z"] != actor.z || saved["sx"] < 0 || saved["sx"] >= 32 || saved["sy"] < 0 || saved["sy"] >= 32)
		return list("accepted" = 0, "reason" = "snapshot")
	var/turf/destination = locate(saved["x"], saved["y"], saved["z"])
	if (!destination)
		return list("accepted" = 0, "reason" = "snapshot")
	var/reason = admit(deadline)
	if (reason)
		return list("accepted" = 0, "reason" = reason)
	return native_position(destination, saved["sx"], saved["sy"], 0)

#endif
