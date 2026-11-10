/*
plot_vector is a helper datum for plotting a path in a straight line towards a target turf.
This datum converts from world space (turf.x and turf.y) to pixel space, which the datum keeps track of itself. This
should work with any size turfs (i.e. 32x32, 64x64) as it references world.icon_size (note: not actually tested with
anything other than 32x32 turfs).

setup()
	This should be called after creating a new instance of a plot_vector datum.
	This does the initial setup and calculations. Since we are travelling in a straight line we only need to calculate
	the	vector and x/y steps once. x/y steps are capped to TRUE full turf, whichever is further. If we are travelling along
	the y axis each step will be +/- 1 y, and the x movement reduced based on the angle (tangent calculation). After
	this every subsequent step will be incremented based on these calculations.
	Inputs:
		source - the turf the object is starting from
		target - the target turf the object is travelling towards
		xo - starting pixel_x offset, typically won't be needed, but included in case someone has a need for it later
		yo - same as xo, but for the y_pixel offset

increment()
	Adds the offset to the current location - incrementing it by one step along the vector.

return_angle()
	Returns the direction (angle in degrees) the object is travelling in.

			 (N)
			 90�
			  ^
			  |
  (W) 180� <--+--> 0� (E)
			  |
			  v
			 -90�
			 (S)

return_hypotenuse()
	Returns the distance of travel for each step of the vector, relative to each full step of movement. TRUE is a full turf
	length. Currently used as a multiplier for scaling effects that should be contiguous, like laser beams.

return_location()
	Returns a vector_loc datum containing the current location data of the object (see /datum/vector_loc). This includes
	the turf it currently should be at, as well as the pixel offset from the centre of that turf. Typically increment()
	would be called before this if you are going to move an object based on it's vector data.
*/

/datum/plot_vector
	var/turf/source
	var/turf/target
	var/angle = 0	// direction of travel in degrees
	var/loc_x = 0	// in pixels from the left edge of the map
	var/loc_y = 0	// in pixels from the bottom edge of the map
	var/loc_z = 0	// loc z is in world space coordinates (i.e. z level) - we don't care about measuring pixels for this
	var/offset_x = 0	// distance to increment each step
	var/offset_y = 0

/datum/plot_vector/proc/setup(var/turf/S, var/turf/T, var/xo = 0, var/yo = 0, var/angle_offset=0)
	source = S
	target = T

	if (!istype(source))
		source = get_turf(source)
	if (!istype(target))
		target = get_turf(target)

	if (!istype(source) || !istype(target))
		return

	// convert coordinates to pixel space (default is 32px/turf, 8160px across for a size 255 map)
	loc_x = source.x * world.icon_size + xo
	loc_y = source.y * world.icon_size + yo
	loc_z = source.z

	// calculate initial x and y difference
	var/dx = target.x - source.x
	var/dy = target.y - source.y

	// if we aren't moving anywhere; quit now
	if (dx == 0 && dy == 0)
		return

	// calculate the angle
	angle = Atan2(dx, dy) + angle_offset

	// An undeviated shot steps one whole tile along the major axis and the exact
	// ratio along the other, so step max(|dx|, |dy|) lands on the target tile.
	// The whole-degree rounding below drifts up to a tile at 15-20 tiles, so about
	// one shot in ten hit a bystander beside the line (tests/perf_probes probe).
	if (!angle_offset)
		var/steps = max(abs(dx), abs(dy))
		offset_x = dx / steps * world.icon_size
		offset_y = dy / steps * world.icon_size
		return

	// and some rounding to stop the increments jumping whole turfs - because byond favours certain angles
	if (angle > -135 && angle < 45)
		angle = ceil(angle)
	else
		angle = Floor(angle)

	// calculate the offset per increment step
	if (abs(angle) in list(0, 45, 90, 135, 180))		// check if the angle is a cardinal
		if (abs(angle) in list(0, 45, 135, 180))		// if so we can skip the trigonometry and set these to absolutes as
			offset_x = ((dx) ? ((dx) < 0 ? -1 : 1) : 0)					// they will always be a full step in one or more directions
		if (abs(angle) in list(45, 90, 135))
			offset_y = ((dy) ? ((dy) < 0 ? -1 : 1) : 0)
	else if (abs(dy) > abs(dx))
		offset_x = Cot(abs(angle))					// otherwise set the offsets
		offset_y = ((dy) ? ((dy) < 0 ? -1 : 1) : 0)
	else
		offset_x = ((dx) ? ((dx) < 0 ? -1 : 1) : 0)
		offset_y = Tan(angle)
		if (dx < 0)
			offset_y = -offset_y

	// multiply the offset by the turf pixel size
	offset_x *= world.icon_size
	offset_y *= world.icon_size

// A straight line between two exact pixel points in plot space (a tile's centre
// is x * icon_size; return_location() rounds to the nearest tile), such as the
// centre of the shooter's body and the centre of the target's.
/datum/plot_vector/proc/setup_points(turf/S, turf/T, sx, sy, tx, ty, angle_offset = 0)
	source = S
	target = T
	if (!istype(source) || !istype(target))
		return
	loc_x = sx
	loc_y = sy
	loc_z = source.z
	var/dx = tx - sx
	var/dy = ty - sy
	if (dx == 0 && dy == 0)
		return
	angle = Atan2(dx, dy) + angle_offset
	if (angle_offset)
		dx = cos(angle)
		dy = sin(angle)
	// One whole tile along the major axis per step, the exact ratio on the other.
	var/steps = max(abs(dx), abs(dy))
	offset_x = dx / steps * world.icon_size
	offset_y = dy / steps * world.icon_size

/datum/plot_vector/proc/increment()
	loc_x += offset_x
	loc_y += offset_y

/datum/plot_vector/proc/return_angle()
	return angle

/datum/plot_vector/proc/return_hypotenuse()
	return sqrt(((offset_x / 32) ** 2) + ((offset_y / 32) ** 2))

/datum/plot_vector/proc/return_location(var/datum/vector_loc/data)
	if (!data)
		data = new()
	data.loc = locate(round(loc_x / world.icon_size, TRUE), round(loc_y / world.icon_size, TRUE), loc_z)
	if (!data.loc)
		return
	data.pixel_x = loc_x - (data.loc.x * world.icon_size)
	data.pixel_y = loc_y - (data.loc.y * world.icon_size)
	return data

/*
vector_loc is a helper datum for returning precise location data from plot_vector. It includes the turf the object is in
as well as the pixel offsets.

return_turf()
	Returns the turf the object should be currently located in.
*/
/datum/vector_loc
	var/turf/loc
	var/pixel_x
	var/pixel_y

/datum/vector_loc/proc/return_turf()
	return loc

// Centre of an atom's body (its bounding box) in plot_vector space, where a
// tile's centre is x * icon_size, or of its turf when it is inside something.
/proc/body_pixel_x(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return 0
	if (ismovable(A) && A.loc == T)
		var/atom/movable/M = A
		return M.x * world.icon_size + M.step_x + M.bound_x + (M.bound_width - world.icon_size) / 2
	return T.x * world.icon_size

/proc/body_pixel_y(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return 0
	if (ismovable(A) && A.loc == T)
		var/atom/movable/M = A
		return M.y * world.icon_size + M.step_y + M.bound_y + (M.bound_height - world.icon_size) / 2
	return T.y * world.icon_size

// Whether the segment (x0, y0)-(x1, y1) passes through the box [bx0, bx1) x
// [by0, by1) (Liang-Barsky clipping).
/proc/segment_crosses_box(x0, y0, x1, y1, bx0, by0, bx1, by1)
	var/t0 = 0
	var/t1 = 1
	var/dx = x1 - x0
	var/dy = y1 - y0
	var/list/edges = list(list(-dx, x0 - bx0), list(dx, bx1 - x0), list(-dy, y0 - by0), list(dy, by1 - y0))
	for (var/list/edge in edges)
		var/p = edge[1]
		var/q = edge[2]
		if (!p)
			if (q < 0)
				return FALSE
			continue
		var/r = q / p
		if (p < 0)
			if (r > t1)
				return FALSE
			t0 = max(t0, r)
		else
			if (r < t0)
				return FALSE
			t1 = min(t1, r)
	return t0 < t1
