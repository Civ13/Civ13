// ============================================================
// Wide curves (docs/trains.md "Wide curves")
// ------------------------------------------------------------
// A sharp corner turns a train through a right angle on one tile, so it must
// be taken slowly and long cars fold across it. A platelayer with a hammer
// can ease a corner into a wide curve of radius 4 or 8 tiles: the corner and
// that many tiles of straight track on each side are lifted and relaid as one
// sweeping curve of the same number of tiles, so no rail is gained or lost.
//
// The curve is a run of tiles from S, where it leaves the first straight, to
// E, where it joins the second. Seen from S heading h1 and turning towards b,
// a tile is (i, j): i tiles towards b, j tiles along h1. The tiles step from
// (0, 0) to (R, R): a short straight run, a staircase, then another run, the
// nearest a line of tiles comes to a quarter circle.
//
// Trains route along it tile by tile. A car's deck lies across the curve
// diagonally on the staircase (train_platform_tiles), and every car, deck part
// and engine body is drawn turned and shifted onto the true circle the track
// art follows, so the train sweeps round instead of zig-zagging.
// ============================================================

#define TRAIN_ARC_EASE_TIME 100 // deciseconds of work for each four tiles of radius

// The radii a corner can be eased to; each has its own track art.
/proc/train_arc_radii()
	return list(4, 8)

// The fastest a train takes a wide curve of radius R without leaving the
// rails, in tiles a second (a sharp corner takes 3, train_derail.dm).
/proc/train_arc_speed(R)
	return 2 + R / 2

/proc/train_arc_dx(d)
	return ((d & EAST) ? 1 : 0) - ((d & WEST) ? 1 : 0)

/proc/train_arc_dy(d)
	return ((d & NORTH) ? 1 : 0) - ((d & SOUTH) ? 1 : 0)

// The direction of a step of (lx, ly) in the curve's own frame.
/proc/train_arc_dir(lx, ly, h1, b)
	var/wx = lx * train_arc_dx(b) + ly * train_arc_dx(h1)
	var/wy = lx * train_arc_dy(b) + ly * train_arc_dy(h1)
	return (wx > 0 ? EAST : 0) | (wx < 0 ? WEST : 0) | (wy > 0 ? NORTH : 0) | (wy < 0 ? SOUTH : 0)

// How many tiles run straight at each end of a curve of radius R.
/proc/train_arc_run(R)
	return R >= 8 ? 3 : 2

// The tiles of a curve of radius R in order from S: list(i, j) each.
/proc/train_arc_path(R)
	. = list()
	var/run = train_arc_run(R)
	for (var/j in 0 to run)
		. += list(list(0, j))
	var/i = 0
	var/j = run
	for (var/k in 1 to R - run)
		i++
		. += list(list(i, j))
		j++
		. += list(list(i, j))
	for (var/k in 1 to run)
		i++
		. += list(list(i, j))

// The tile (i, j) of a curve starting on S.
/proc/train_arc_turf(turf/S, h1, b, i, j)
	if (!S)
		return null
	return locate(S.x + i * train_arc_dx(b) + j * train_arc_dx(h1), S.y + i * train_arc_dy(b) + j * train_arc_dy(h1), S.z)

/obj/structure/rails/arc
	name = "curved rails"
	desc = "A wide curve of track. Trains take it faster than a sharp corner."
	icon = null
	icon_state = null
	var/arc_radius = 0
	var/arc_sx = 0 // S, where the curve leaves the first straight
	var/arc_sy = 0
	var/arc_h1 = 0 // the heading at S
	var/arc_b = 0 // the way the curve turns
	var/leg_a = 0 // the ways this tile leads
	var/leg_b = 0
	var/arc_lay = 0 // how a deck lies across this tile, heading from S
	var/arc_master = FALSE // this tile draws the whole curve
	var/tmp/image/arc_image = null

/obj/structure/rails/arc/exits()
	return list(leg_a, leg_b)

/obj/structure/rails/arc/after_load()
	..()
	update_icon()

/obj/structure/rails/arc/update_icon()
	if (arc_image)
		overlays -= arc_image
		arc_image = null
	if (!arc_master || !arc_radius)
		return
	var/image/I = image(arc_radius >= 8 ? 'icons/obj/vehicles/train_arc8.dmi' : 'icons/obj/vehicles/train_arc4.dmi', "arc")
	var/bx = train_arc_dx(arc_b)
	var/by = train_arc_dy(arc_b)
	var/hx = train_arc_dx(arc_h1)
	var/hy = train_arc_dy(arc_h1)
	// The art is drawn turning from north to east; turn or mirror it onto
	// this curve's frame. Turning happens about the art's centre, which is
	// moved to where that centre lies on the ground.
	I.transform = matrix(bx, hx, 0, by, hy, 0)
	var/c = arc_radius * world.icon_size / 2
	I.pixel_x = (bx + hx) * c - (x - arc_sx) * world.icon_size - c
	I.pixel_y = (by + hy) * c - (y - arc_sy) * world.icon_size - c
	arc_image = I
	overlays += arc_image

// This tile's place in its curve: list(i, j).
/obj/structure/rails/arc/proc/arc_local()
	var/wx = x - arc_sx
	var/wy = y - arc_sy
	return list(wx * train_arc_dx(arc_b) + wy * train_arc_dy(arc_b), wx * train_arc_dx(arc_h1) + wy * train_arc_dy(arc_h1))

// Where a car on this tile is drawn on the track's true circle and which way
// it runs there: list(offset x, offset y, heading x, heading y), in tiles from
// this tile's centre, heading from S towards E. The circle is the art's: it
// leaves the near edge of S and meets the far edge of E. The curve's tiles
// share it out evenly (tile k of n stands at (k + 0.5) / n of the way round),
// so a train keeps an even pace and spacing; a staircase has more tiles than
// the circle is long, so cars stand a little closer there.
/obj/structure/rails/arc/proc/arc_frame()
	var/list/L = arc_local()
	var/rad = arc_radius + 0.5
	var/count = 2 * arc_radius + 1
	var/angle = 90 * (L[1] + L[2] + 0.5) / count
	var/lx = rad - rad * cos(angle) - L[1]
	var/ly = -0.5 + rad * sin(angle) - L[2]
	var/tx = sin(angle)
	var/ty = cos(angle)
	var/bx = train_arc_dx(arc_b)
	var/by = train_arc_dy(arc_b)
	var/hx = train_arc_dx(arc_h1)
	var/hy = train_arc_dy(arc_h1)
	return list(lx * bx + ly * hx, lx * by + ly * hy, tx * bx + ty * hx, tx * by + ty * hy)

// The curve on T, or null.
/proc/train_arc_at(turf/T)
	if (!T)
		return null
	return locate(/obj/structure/rails/arc) in T

// A sharp corner has no wear allowance on a curve; a wide curve has its own
// limit (train_derail.dm). 0 off a curve.
/proc/rail_arc_speed_at(turf/T)
	var/obj/structure/rails/arc/A = train_arc_at(T)
	return A ? train_arc_speed(A.arc_radius) : 0

// The way a car's deck lies across T for a car heading that way: across a
// curve's staircase a deck lies diagonally (train_platform_tiles).
/proc/rail_arc_lay(turf/T, heading)
	var/obj/structure/rails/arc/A = train_arc_at(T)
	if (!A || !A.arc_lay)
		return heading
	var/list/f = A.arc_frame()
	if (train_arc_dx(heading) * f[3] + train_arc_dy(heading) * f[4] < 0)
		return OPPOSITE_DIR(A.arc_lay)
	return A.arc_lay

// The cardinal a car heading that way on T counts as facing: on a curve, the
// one nearest the way the track runs, so what rides on it turns once over the
// whole curve and not at every step of the staircase.
/proc/rail_arc_facing(turf/T, heading)
	var/obj/structure/rails/arc/A = train_arc_at(T)
	if (!A)
		return heading
	var/list/f = A.arc_frame()
	var/tx = f[3]
	var/ty = f[4]
	if (train_arc_dx(heading) * tx + train_arc_dy(heading) * ty < 0)
		tx = -tx
		ty = -ty
	if (abs(tx) > abs(ty))
		return tx > 0 ? EAST : WEST
	return ty > 0 ? NORTH : SOUTH

// How far a car turned stepping from (oldloc, old_dir) to (newloc, new_dir):
// 90, -90 or 0. Furniture aboard turns with it.
/proc/train_turning(turf/oldloc, old_dir, turf/newloc, new_dir)
	var/was = rail_arc_facing(oldloc, old_dir)
	var/now = rail_arc_facing(newloc, new_dir)
	if (now == turn(was, 90))
		return 90
	if (now == turn(was, -90))
		return -90
	return 0

// ---- Drawing trains on a curve ----

/obj/structure/var/tmp/train_arc_posed = FALSE

// Bearing of a vector, clockwise from north, in degrees.
/proc/train_arc_bearing(vx, vy)
	return 90 - arctan(vx, vy)

/proc/train_arc_place(obj/structure/O, matrix/M, px, py)
	if (!O)
		return
	px = round(px)
	py = round(py)
	if (train_glide_record && train_glide_time > world.tick_lag)
		animate(O, transform = M, pixel_x = px, pixel_y = py, time = train_glide_time)
	else
		O.transform = M
		O.pixel_x = px
		O.pixel_y = py

/proc/train_arc_unpose(obj/structure/O)
	if (!O || !O.train_arc_posed)
		return
	O.train_arc_posed = FALSE
	train_arc_place(O, matrix(), initial(O.pixel_x), initial(O.pixel_y))

// Draws a car (or a section) heading that way, and the deck parts or body
// beside it, on the curve under it: turned to the way the track runs and
// moved onto its circle. Off a curve they are drawn square again.
/proc/train_arc_pose(obj/structure/centre, list/parts, heading)
	if (!centre)
		return
	var/obj/structure/rails/arc/A = isturf(centre.loc) && !QDELETED(centre) ? train_arc_at(centre.loc) : null
	if (!A || !heading)
		train_arc_unpose(centre)
		for (var/obj/structure/P in parts)
			train_arc_unpose(P)
		return
	var/list/f = A.arc_frame()
	var/tx = f[3]
	var/ty = f[4]
	if (train_arc_dx(heading) * tx + train_arc_dy(heading) * ty < 0)
		tx = -tx
		ty = -ty
	var/angle = train_arc_bearing(tx, ty) - train_arc_bearing(train_arc_dx(heading), train_arc_dy(heading))
	while (angle > 180)
		angle -= 360
	while (angle <= -180)
		angle += 360
	var/matrix/M = matrix()
	M.Turn(angle)
	var/size = world.icon_size
	centre.train_arc_posed = TRUE
	train_arc_place(centre, M, initial(centre.pixel_x) + f[1] * size, initial(centre.pixel_y) + f[2] * size)
	// Left of the way on (TRAIN_LEFT is -1).
	var/left_x = -ty
	var/left_y = tx
	for (var/obj/structure/train_part/P in parts)
		if (!isturf(P.loc))
			continue
		var/vx = f[1] - P.side * left_x - (P.x - centre.x)
		var/vy = f[2] - P.side * left_y - (P.y - centre.y)
		P.train_arc_posed = TRUE
		train_arc_place(P, M, initial(P.pixel_x) + vx * size, initial(P.pixel_y) + vy * size)

// ---- Easing a corner ----

// The corner's two straights: list(list of tiles before it, list after).
/obj/structure/rails/turn/proc/arc_legs(R)
	var/turf/C = get_turf(src)
	var/list/before = list()
	var/list/after = list()
	for (var/k in 1 to R)
		before += locate(C.x - k * train_arc_dx(dir), C.y - k * train_arc_dy(dir), C.z)
		after += locate(C.x + k * train_arc_dx(turn_dir), C.y + k * train_arc_dy(turn_dir), C.z)
	return list(before, after)

// Why this corner may not be eased to radius R, or null.
/obj/structure/rails/turn/proc/arc_problem(R)
	var/turf/C = get_turf(src)
	if (!C || !turn_dir || !(R in train_arc_radii()))
		return "This corner cannot be eased."
	if (rail_routing_at(C) != src)
		return "The switch here must stay where it is."
	var/list/legs = arc_legs(R)
	if ((null in legs[1]) || (null in legs[2]))
		return "There is no room for the curve here."
	var/list/track = list(C)
	for (var/n in 1 to 2)
		var/d = (n == 1) ? dir : turn_dir
		for (var/turf/T in legs[n])
			var/obj/structure/rails/L = rail_routing_at(T)
			if (!istype(L, /obj/structure/rails/regular) || !(d in L.exits()) || !(OPPOSITE_DIR(d) in L.exits()))
				return "A curve of radius [R] needs [R] tiles of plain straight track on each side of the corner."
			track += T
	var/turf/S = legs[1][R]
	for (var/list/at in train_arc_path(R))
		var/turf/T = train_arc_turf(S, dir, turn_dir, at[1], at[2])
		if (!T)
			return "There is no room for the curve here."
		if (!(T in track))
			track += T
			if (track_piece_at(T))
				return "Other track is in the way of the curve."
			var/problem = track_lay_problem(T)
			if (problem)
				return problem
	for (var/turf/T in track)
		if ((locate(/obj/structure/trains) in T) || (locate(/obj/structure/train_part) in T))
			return "Move the wagons off the track first."
	return null

// Relays a corner and its straights as a curve of radius R; returns the
// curve's first tile. The corner itself is lifted, so this is not one of its
// own procs: a proc of a deleted object stops.
/proc/train_arc_ease(obj/structure/rails/turn/corner, R)
	var/h1 = corner.dir
	var/b = corner.turn_dir
	var/list/legs = corner.arc_legs(R)
	var/turf/S = legs[1][R]
	var/worn = corner.wear
	var/was_wooden = corner.wooden
	var/list/old = list(corner)
	for (var/n in 1 to 2)
		for (var/turf/T in legs[n])
			old += rail_routing_at(T)
	for (var/obj/structure/rails/O in old)
		worn = max(worn, O.wear)
		qdel(O)
	var/list/path = train_arc_path(R)
	var/count = path.len
	for (var/k in 1 to count)
		var/list/at = path[k]
		var/list/back = (k == 1) ? list(0, -1) : list(path[k - 1][1] - at[1], path[k - 1][2] - at[2])
		var/list/on = (k == count) ? list(1, 0) : list(path[k + 1][1] - at[1], path[k + 1][2] - at[2])
		var/obj/structure/rails/arc/A = new(train_arc_turf(S, h1, b, at[1], at[2]))
		A.arc_radius = R
		A.arc_sx = S.x
		A.arc_sy = S.y
		A.arc_h1 = h1
		A.arc_b = b
		A.leg_a = train_arc_dir(back[1], back[2], h1, b)
		A.leg_b = train_arc_dir(on[1], on[2], h1, b)
		var/run = train_arc_run(R)
		A.arc_lay = (k <= run + 1) ? h1 : ((k >= count - run) ? b : (h1 | b))
		A.arc_master = (k == R + 1)
		A.dir = (k <= R) ? h1 : b
		A.wear = worn
		A.set_wooden(was_wooden)
		A.show_wear()
		A.update_icon()
	return S

// The tiles of this tile's curve, in order from S.
/obj/structure/rails/arc/proc/arc_tiles()
	. = list()
	var/turf/S = locate(arc_sx, arc_sy, z)
	for (var/list/at in train_arc_path(arc_radius))
		. += train_arc_turf(S, arc_h1, arc_b, at[1], at[2])

/obj/structure/rails/arc/proc/arc_pieces()
	. = list()
	for (var/turf/T in arc_tiles())
		for (var/obj/structure/rails/arc/A in T)
			if (A.arc_sx == arc_sx && A.arc_sy == arc_sy && A.arc_h1 == arc_h1 && A.arc_b == arc_b && A.arc_radius == arc_radius)
				. += A

// The sharp corner and straights this curve was eased from: list(corner turf,
// list of tiles before it, list after it).
/obj/structure/rails/arc/proc/arc_corner()
	var/turf/S = locate(arc_sx, arc_sy, z)
	var/turf/C = train_arc_turf(S, arc_h1, arc_b, 0, arc_radius)
	var/list/before = list()
	var/list/after = list()
	for (var/k in 1 to arc_radius)
		before += train_arc_turf(S, arc_h1, arc_b, 0, arc_radius - k)
		after += train_arc_turf(S, arc_h1, arc_b, k, arc_radius)
	return list(C, before, after)

// Why this curve may not be put back to a sharp corner, or null.
/obj/structure/rails/arc/proc/sharpen_problem()
	var/list/mine = arc_tiles()
	var/list/corner = arc_corner()
	var/list/all = mine.Copy()
	all |= corner[1]
	all |= corner[2]
	all |= corner[3]
	if (null in all)
		return "There is no room for the corner here."
	for (var/turf/T in all)
		if ((locate(/obj/structure/trains) in T) || (locate(/obj/structure/train_part) in T))
			return "Move the wagons off the track first."
		if (!(T in mine))
			if (track_piece_at(T))
				return "Other track is in the way of the corner."
			var/problem = track_lay_problem(T)
			if (problem)
				return problem
	return null

// Puts the curve back to the sharp corner and straights it was eased from.
// Returns the corner.
/proc/train_arc_sharpen(obj/structure/rails/arc/curve)
	var/list/corner = curve.arc_corner()
	var/h1 = curve.arc_h1
	var/b = curve.arc_b
	var/worn = 0
	var/was_wooden = curve.wooden
	for (var/obj/structure/rails/arc/A in curve.arc_pieces())
		worn = max(worn, A.wear)
		qdel(A)
	var/list/made = list()
	for (var/turf/T in corner[2])
		made += track_make_rail(T, h1, FALSE)
	for (var/turf/T in corner[3])
		made += track_make_rail(T, b, FALSE)
	var/obj/structure/rails/C = track_make_rail(corner[1], track_curve_dir(OPPOSITE_DIR(h1), b), TRUE)
	made += C
	for (var/obj/structure/rails/R in made)
		R.wear = worn
		R.set_wooden(was_wooden)
		R.show_wear()
	return C

/obj/structure/rails/turn/verb/ease_curve()
	set category = null
	set name = "Ease the Curve"
	set desc = "Relay this sharp corner as a wide curve that trains take faster."
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.incapacitated())
		return
	var/obj/item/W = H.get_active_hand()
	if (!W || !is_tool(W, TOOL_HAMMER))
		to_chat(H, SPAN_WARNING("You need a hammer in your hand to relay track."))
		return
	var/list/choices = list()
	for (var/R in train_arc_radii())
		choices["Radius [R] (trains up to [train_arc_speed(R)] tiles a second)"] = R
	var/pick = player_input(H, "Ease this corner into a curve of which radius? It takes the corner and that many tiles of straight track on each side.", "Ease the Curve", null, "anything", choices, TRUE)
	if (!pick || QDELETED(src) || !(src in view(1, H)))
		return
	var/R = choices[pick]
	var/problem = arc_problem(R)
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		return
	to_chat(H, SPAN_NOTICE("You start lifting the corner and relaying it as a wide curve."))
	playsound(loc, 'sound/effects/clang.ogg', 50, TRUE)
	if (!do_after(H, TRAIN_ARC_EASE_TIME * R / 4, src) || QDELETED(src) || arc_problem(R))
		return
	H.visible_message(SPAN_NOTICE("[H] relays the corner as a wide curve."), SPAN_NOTICE("You relay the corner as a wide curve of radius [R]."))
	train_arc_ease(src, R)

// A crowbar on a curve puts it back to a sharp corner (track_laying.dm takes
// the corner apart from there).
/obj/structure/rails/arc/attackby(obj/item/W, mob/user)
	if (!is_tool(W, TOOL_CROWBAR))
		return ..()
	var/problem = sharpen_problem()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return TRUE
	to_chat(user, SPAN_NOTICE("You start lifting the curve to relay it as a sharp corner."))
	if (!do_after(user, TRAIN_ARC_EASE_TIME * arc_radius / 4, src) || QDELETED(src) || sharpen_problem())
		return TRUE
	playsound(get_turf(src), 'sound/items/Crowbar.ogg', 50, TRUE)
	user.visible_message(SPAN_NOTICE("[user] relays the curve as a sharp corner."), SPAN_NOTICE("You relay the curve as a sharp corner and its straights. Pry them again to take them apart."))
	train_arc_sharpen(src)
	return TRUE

// Anything else that takes the curve apart puts it back to its corner first.
/obj/structure/rails/arc/pry_apart()
	if (sharpen_problem())
		return null
	return train_arc_pry(src)

/proc/train_arc_pry(obj/structure/rails/arc/curve)
	var/obj/structure/rails/C = train_arc_sharpen(curve)
	return C ? C.pry_apart() : null

/obj/structure/rails/arc/examine(mob/user)
	..()
	to_chat(user, "A wide curve of radius [arc_radius]: trains take it at up to [train_arc_speed(arc_radius)] tiles a second. A crowbar relays it as a sharp corner.")

#undef TRAIN_ARC_EASE_TIME
