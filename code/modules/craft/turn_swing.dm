// ============================================================
// Turning swings (docs/craft-core.md "Turning swings")
// ------------------------------------------------------------
// A vehicle of frames or a built hull turns on the server in one go: every
// part is set down on its new tile, already facing the new way. Clients are
// shown that turn as the whole body swinging round a point, the way a wide
// rail curve swings a train's cars round (train_arcs.dm): each part is drawn
// where it stood, turned back to the way it faced, and carried round the
// turn's pivot on the arc to where it now is, turning as it goes. Riders and
// the views of riders follow the same arc without being tipped over.
//
// A one-object boat with a top-down hull turns in place the same way.
//
// Appearance only: the server has already finished the turn, and nothing
// here moves anything or owns a timer.
// ============================================================

// The last swing shown: list(pivot x, pivot y, angle, things swung, things
// drawn turning, tenths of a second). For the probes; nothing reads it in play.
var/global/list/turn_swing_last = null

// Degrees of the turn between two keyframes of the arc. A quarter turn is
// three straight pieces, close enough to the circle at a vehicle's size.
#define TURN_SWING_STEP 30
#define TURN_SWING_FINE_STEP 15

// Tenths of a second a turn of a body this many tiles across is shown swinging round. The
// far corners of a big body travel further, so it swings a little longer.
/proc/turn_swing_time(span)
	return clamp(4 + round(span / 2), 5, 10)

// The rigid turn that carried each thing in was_at (thing = the tile it left)
// to the tile it stands on now: list(pivot x, pivot y, angle), the pivot in
// tiles and the angle in degrees anticlockwise. angle, when given, is the only
// turn tried; else a quarter turn either way and a half turn are. A thing that
// did not move with the body (one that was not carried round) does not count
// against it. Returns null if fewer than half of them moved together.
/proc/turn_swing_fit(list/was_at, angle = null)
	if (!was_at || !was_at.len)
		return null
	var/list/tries = isnull(angle) ? list(90, -90, 180) : list(angle)
	var/list/best = null
	var/best_votes = 0
	var/counted = 0
	for (var/a in tries)
		var/c = cos(a)
		var/s = sin(a)
		var/det = 2 - 2 * c
		if (det < 0.01)
			continue
		var/list/votes = list()
		counted = 0
		for (var/atom/movable/M in was_at)
			var/turf/from = was_at[M]
			if (QDELETED(M) || !istype(from) || !isturf(M.loc) || M.z != from.z)
				continue
			counted++
			// The pivot p this pair alone gives: n - p = R(o - p), so
			// p = (I - R)^-1 (n - R o).
			var/qx = M.x - (c * from.x - s * from.y)
			var/qy = M.y - (s * from.x + c * from.y)
			var/px = ((1 - c) * qx - s * qy) / det
			var/py = (s * qx + (1 - c) * qy) / det
			var/key = "[round(px * 2 + 0.5)],[round(py * 2 + 0.5)]"
			var/list/v = votes[key]
			if (!v)
				votes[key] = list(px, py, 1)
			else
				v[3]++
		for (var/key in votes)
			var/list/v = votes[key]
			if (v[3] > best_votes)
				best_votes = v[3]
				best = list(v[1], v[2], a)
	if (!best || best_votes * 2 < counted)
		return null
	return best

// TRUE when M stood on from before a turn of angle about (px, py) and now
// stands where that turn takes it.
/proc/turn_swing_carried(atom/movable/M, turf/from, px, py, angle)
	if (!M || !istype(from) || !isturf(M.loc) || M.z != from.z)
		return FALSE
	var/c = cos(angle)
	var/s = sin(angle)
	var/nx = px + c * (from.x - px) - s * (from.y - py)
	var/ny = py + s * (from.x - px) + c * (from.y - py)
	return abs(nx - M.x) < 0.1 && abs(ny - M.y) < 0.1

// Draws M, which a turn of angle about (px, py) has just carried, back where
// it stood and swings it round the arc to where it is now over time. With
// turned set, the thing turned with the body and its sprite is seen from
// above, so it is drawn turned back to its old facing and turns as it goes.
// A player who is that mob sees the view swing round with it. span is the
// body's size in tiles: a big body's arc is cut finer, so its far corners
// keep to the circle.
/proc/turn_swing(atom/movable/M, px, py, angle, time, turned = FALSE, span = 0)
	if (!M || !angle || time <= 0)
		return
	var/steps = turn_swing_steps(angle, span)
	var/rx = M.x - px
	var/ry = M.y - py
	var/rest_x = M.pixel_x
	var/rest_y = M.pixel_y
	var/matrix/rest_t = turned ? matrix(M.transform) : null
	for (var/k = 0, k <= steps, k++)
		var/list/at = turn_swing_offset(rx, ry, -angle * (steps - k) / steps)
		var/to_x = rest_x + round(at[1] * world.icon_size, 1)
		var/to_y = rest_y + round(at[2] * world.icon_size, 1)
		var/matrix/T = null
		if (turned)
			T = matrix(rest_t)
			// Turn() is clockwise; the arc's angles are anticlockwise.
			T.Turn(angle * (steps - k) / steps)
		if (k == 0)
			M.pixel_x = to_x
			M.pixel_y = to_y
			if (T)
				M.transform = T
			continue
		var/list/piece = turn_swing_piece(k, steps, time)
		if (k == 1)
			if (T)
				animate(M, pixel_x = to_x, pixel_y = to_y, transform = T, time = piece[1], easing = piece[2])
			else
				animate(M, pixel_x = to_x, pixel_y = to_y, time = piece[1], easing = piece[2])
		else if (T)
			animate(pixel_x = to_x, pixel_y = to_y, transform = T, time = piece[1], easing = piece[2])
		else
			animate(pixel_x = to_x, pixel_y = to_y, time = piece[1], easing = piece[2])
	if (!ismob(M))
		return
	var/mob/rider = M
	var/client/C = rider.client
	if (!C || C.eye != rider)
		return
	rest_x = C.pixel_x
	rest_y = C.pixel_y
	for (var/k = 0, k <= steps, k++)
		var/list/at = turn_swing_offset(rx, ry, -angle * (steps - k) / steps)
		var/to_x = rest_x + round(at[1] * world.icon_size, 1)
		var/to_y = rest_y + round(at[2] * world.icon_size, 1)
		if (k == 0)
			C.pixel_x = to_x
			C.pixel_y = to_y
			continue
		var/list/piece = turn_swing_piece(k, steps, time)
		if (k == 1)
			animate(C, pixel_x = to_x, pixel_y = to_y, time = piece[1], easing = piece[2])
		else
			animate(pixel_x = to_x, pixel_y = to_y, time = piece[1], easing = piece[2])

// How many straight pieces a turn of angle is drawn in: one every 30 degrees,
// or every 15 for a body 6 tiles or more across.
/proc/turn_swing_steps(angle, span)
	return max(1, round(abs(angle) / (span >= 6 ? TURN_SWING_FINE_STEP : TURN_SWING_STEP)))

// Piece k of steps: list(time, easing). The swing eases in on its first piece
// and out on its last, and the pieces between run at the speed the eased ends
// reach (a sine ease ends at pi/2 times its average speed), so the body
// gathers way, swings round evenly and settles.
/proc/turn_swing_piece(k, steps, time)
	if (steps <= 1)
		return list(time, SINE_EASING)
	var/middle = time / (steps - 2 + M_PI)
	var/edge = steps == 2 ? time / 2 : middle * M_PI / 2
	if (k == 1)
		return list(edge, SINE_EASING | EASE_IN)
	if (k == steps)
		return list(edge, SINE_EASING | EASE_OUT)
	return list(middle, LINEAR_EASING)

// Where a thing (rx, ry) tiles from the pivot is drawn, in tiles from where it
// stands, when the turn still has phi degrees (anticlockwise) to go back.
/proc/turn_swing_offset(rx, ry, phi)
	var/c = cos(phi)
	var/s = sin(phi)
	return list(c * rx - s * ry - rx, s * rx + c * ry - ry)

// Shows the turn that carried everything in was_at (thing = tile it left) as
// one swing. dirs maps things to the facing they had before, so that the
// things that turned with the body are drawn turning. hold is the glide
// record whose things move at once (held at a whole tile before the move).
// Returns the things it could not show as part of the swing, for the caller
// to slide as before; everything when the moves were not one rigid turn.
/proc/turn_swing_all(list/was_at, list/dirs, angle = null, span = 0)
	. = list()
	var/list/fit = turn_swing_fit(was_at, angle)
	if (!fit)
		for (var/atom/movable/M in was_at)
			. += M
		return
	var/px = fit[1]
	var/py = fit[2]
	var/a = fit[3]
	var/time = turn_swing_time(span)
	var/swung = 0
	var/turned_count = 0
	for (var/atom/movable/M in was_at)
		var/turf/from = was_at[M]
		if (QDELETED(M) || M.invisibility >= 101)
			continue
		if (!turn_swing_carried(M, from, px, py, a))
			. += M
			continue
		var/turned = dirs && !isnull(dirs[M]) && dirs[M] != M.dir && M.turn_swing_turns()
		turn_swing(M, px, py, a, time, turned, span)
		swung++
		if (turned)
			turned_count++
	turn_swing_last = list(px, py, a, swung, turned_count, time)

// The tiles across a body that turned: the larger side of the box around
// where its things now stand.
/proc/turn_swing_span(list/was_at)
	var/x0 = null
	var/x1 = null
	var/y0 = null
	var/y1 = null
	for (var/atom/movable/M in was_at)
		if (QDELETED(M) || !isturf(M.loc))
			continue
		x0 = isnull(x0) ? M.x : min(x0, M.x)
		x1 = isnull(x1) ? M.x : max(x1, M.x)
		y0 = isnull(y0) ? M.y : min(y0, M.y)
		y1 = isnull(y1) ? M.y : max(y1, M.y)
	if (isnull(x0))
		return 0
	return max(x1 - x0, y1 - y0) + 1

// TRUE for a thing whose sprites for each facing are its top-down shape
// turned round, so that it may be drawn turning: a vehicle's frames, a hull's
// floors and roofs. Everything else (wheels and seats drawn from the side,
// furniture, people) is carried round the arc upright and takes its new
// facing at once.
/atom/movable/proc/turn_swing_turns()
	return FALSE

/obj/structure/vehicleparts/frame/turn_swing_turns()
	return TRUE

/obj/covers/turn_swing_turns()
	return TRUE

/obj/roof/turn_swing_turns()
	return TRUE

// ---- One-object vehicles ----
// A boat drawn from above (an outrigger, a RHIB) turns in place on screen:
// its new facing is drawn turned back to the old one and turns round. Side-
// view sprites (rafts, motorcycles, carriages) would tip over, so they keep
// the plain change of facing.

/obj/structure/vehicle
	var/turn_swings = FALSE // TRUE when its sprite is seen from above and may be drawn turning.

/obj/structure/vehicle/boat
	turn_swings = TRUE

// After its facing changed from was: shows the change as a short turn.
/obj/structure/vehicle/proc/turn_swing_facing(was)
	if (!turn_swings || !was || was == dir || !isturf(loc))
		return
	var/angle = craft_turn_angle(was, dir)
	if (!angle)
		return
	var/matrix/rest_t = matrix(transform)
	var/matrix/T = matrix(rest_t)
	T.Turn(angle)
	transform = T
	animate(src, transform = rest_t, time = abs(angle) >= 180 ? 4 : 3, easing = SINE_EASING)

#undef TURN_SWING_STEP
#undef TURN_SWING_FINE_STEP
