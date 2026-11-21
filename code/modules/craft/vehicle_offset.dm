// ============================================================
// Vehicle offsets (docs/vehicle-offset.md): a vehicle that moves by pixels
// ------------------------------------------------------------
// One shared sub-tile offset per vehicle, the way free-moving players move.
// Every pulse synchronizes step_x/step_y on everything the vehicle
// carries, so the hull, the riders and the cargo stay together to the pixel
// and the riders' views follow their own step offset. The vehicle's own
// whole-tile step runs only when the offset passes half a tile; the offset
// then wraps back by a tile, so every carried thing stays filed under the
// tile beneath its centre (offsets -16 to 15, as players since #4333).
//
// Tiles stay the truth for everything else: contents, saves, shots, sight.
// A save drops the offset (snap()); a loaded vehicle starts square on its
// tile. Nothing here is saved.
//
// Phase 0: the core and its native probe only (tests/vehicle_offset). No
// vehicle owns one yet, so nothing in play changes.
// ============================================================

#define VEHICLE_OFFSET_TILE 32
#define VEHICLE_OFFSET_HALF 16
// The longest single advance; a faster pulse is split so that no tile edge is skipped.
#define VEHICLE_OFFSET_CHUNK 15
// Ticks between checks for a player close enough to see the pixels.
#define VEHICLE_OFFSET_WATCH_RECHECK 20
#define VEHICLE_OFFSET_WATCH_RANGE 12

// Every live vehicle offset, so that a save can drop them all at once.
var/global/list/vehicle_offsets = list()
// Everything a vehicle offset carries, to the offset carrying it.
var/global/list/vehicle_offset_riders = list()

// Pixels per tick that cover one tile in this many deciseconds.
/proc/vehicle_offset_speed(ds_per_tile)
	if (!isnum(ds_per_tile) || ds_per_tile <= 0)
		return 0
	return VEHICLE_OFFSET_TILE * world.tick_lag / ds_per_tile

// Drops every vehicle offset before a save collects the world.
/proc/vehicle_offset_snap_all()
	for (var/datum/vehicle_offset/O in vehicle_offsets)
		O.snap()

// The tiles an atom covers: its bounds, plus its step offset when with_step is set.
/proc/vehicle_offset_tiles(atom/movable/A, with_step = FALSE)
	. = list()
	if (!A || !isturf(A.loc))
		return
	var/sx = with_step ? A.step_x : 0
	var/sy = with_step ? A.step_y : 0
	// round() with one argument is floor, so negative offsets reach the tile behind.
	var/x0 = A.x + round((A.bound_x + sx) / VEHICLE_OFFSET_TILE)
	var/y0 = A.y + round((A.bound_y + sy) / VEHICLE_OFFSET_TILE)
	var/x1 = A.x + round((A.bound_x + sx + A.bound_width - 1) / VEHICLE_OFFSET_TILE)
	var/y1 = A.y + round((A.bound_y + sy + A.bound_height - 1) / VEHICLE_OFFSET_TILE)
	for (var/tx = x0 to x1)
		for (var/ty = y0 to y1)
			var/turf/T = locate(tx, ty, A.z)
			if (T)
				. |= T

/datum/vehicle_offset
	var/atom/movable/owner = null  // The vehicle (an axis, a one-object vehicle).
	var/ox = 0                     // Shared offset, -16 to 15.
	var/oy = 0
	var/speed_x = 0                // Pixels per pulse, signed.
	var/speed_y = 0
	var/rest_x = 0                 // Fractions of a pixel carried to the next pulse.
	var/rest_y = 0
	var/list/carried = list()      // atom = list(own x, own y) on top of the shared offset.
	var/list/footprint = list()    // The carried things whose tiles are the vehicle's body.
	var/blocked_dir = 0            // The direction the last pulse was stopped in, or 0.
	var/pulses = 0
	var/crossings = 0
	var/watch_checked = -1000
	var/watch_cached = FALSE
	var/write_changed_steps_only = FALSE

/datum/vehicle_offset/New(atom/movable/vehicle)
	..()
	owner = vehicle
	vehicle_offsets += src

/datum/vehicle_offset/Destroy()
	vehicle_offsets -= src
	snap()
	for (var/atom/movable/A in carried)
		if (vehicle_offset_riders[A] == src)
			vehicle_offset_riders -= A
	carried = list()
	footprint = list()
	owner = null
	return ..()

// Carries A; its own offset now (minus the shared one) is kept on top of the shared offset.
/datum/vehicle_offset/proc/carry(atom/movable/A, body = FALSE)
	if (!A)
		return
	carry_at(A, A.step_x - ox, A.step_y - oy, body)

// Carries A at a fixed place on the vehicle: a seated rider sits at (0, 0).
// Each entry is list(own x, own y, drawn x, drawn y): the last two are where
// draw() last put A, in absolute pixels, so that settle() can tell when A
// moved by itself (a person walking on the deck).
/datum/vehicle_offset/proc/carry_at(atom/movable/A, own_x = 0, own_y = 0, body = FALSE)
	if (!A)
		return
	carried[A] = list(own_x, own_y, A.x * VEHICLE_OFFSET_TILE + A.step_x, A.y * VEHICLE_OFFSET_TILE + A.step_y)
	vehicle_offset_riders[A] = src
	if (body)
		footprint |= A

// Stops carrying A. With keep_place it stays where it is drawn (a rider getting
// off steps off where the vehicle is); otherwise it gets its own offset back.
/datum/vehicle_offset/proc/drop(atom/movable/A, keep_place = FALSE)
	if (!(A in carried))
		return
	var/list/own = carried[A]
	carried -= A
	footprint -= A
	if (vehicle_offset_riders[A] == src)
		vehicle_offset_riders -= A
	if (!QDELETED(A) && !keep_place)
		A.step_x = own[1]
		A.step_y = own[2]

// Writes the shared offset on everything carried. Direct writes: no Move(), no turf events.
/datum/vehicle_offset/proc/draw()
	for (var/atom/movable/A in carried)
		if (QDELETED(A))
			carried -= A
			footprint -= A
			continue
		draw_one(A)

/datum/vehicle_offset/proc/draw_one(atom/movable/A)
	var/list/own = carried[A]
	if (write_changed_steps_only)
		var/target_x = ox + own[1]
		var/target_y = oy + own[2]
		if (A.step_x != target_x)
			A.step_x = target_x
		if (A.step_y != target_y)
			A.step_y = target_y
	else
		A.step_x = ox + own[1]
		A.step_y = oy + own[2]
	own[3] = A.x * VEHICLE_OFFSET_TILE + A.step_x
	own[4] = A.y * VEHICLE_OFFSET_TILE + A.step_y
	if (ismob(A))
		A.vehicle_offset_drawn()

// Square on the tile again, everything with it. A walk made on the deck since
// the last pulse is taken in first, so squaring does not undo it.
/datum/vehicle_offset/proc/snap()
	var/list/walkers = walks_in_step()
	settle()
	speed_x = 0
	speed_y = 0
	rest_x = 0
	rest_y = 0
	if (ox || oy)
		ox = 0
		oy = 0
		draw()
	vehicle_offset_rebase_walks(walkers)

// TRUE when a player is close enough to see the pixels; cached for two seconds.
/datum/vehicle_offset/proc/watched()
	if (world.time < watch_checked + VEHICLE_OFFSET_WATCH_RECHECK)
		return watch_cached
	watch_checked = world.time
	watch_cached = FALSE
	var/turf/here = get_turf(owner)
	if (here)
		for (var/client/C in clients)
			var/turf/there = get_turf(C.mob)
			if (there && there.z == here.z && get_dist(here, there) <= VEHICLE_OFFSET_WATCH_RANGE)
				watch_cached = TRUE
				break
	return watch_cached

// The tiles the body would newly cover one step in dir.
/datum/vehicle_offset/proc/tiles_ahead(dir)
	var/list/body = list()
	for (var/atom/movable/A in footprint)
		body |= vehicle_offset_tiles(A, TRUE)
	. = list()
	for (var/turf/T in body)
		var/turf/next = get_step(T, dir)
		if (!next)
			return null
		if (!(next in body))
			. |= next

// TRUE when the body may start to overlap the tiles ahead in dir.
// Vehicles with their own rules (crashes, water, rails) override this.
// People and animals are the vehicle's own business (run over, shoved, a
// crash), so only walls and dense objects stop it here.
/datum/vehicle_offset/proc/can_cover(dir)
	var/list/ahead = tiles_ahead(dir)
	if (!ahead)
		return FALSE
	for (var/turf/T in ahead)
		if (T.density)
			return FALSE
		for (var/atom/movable/O in T)
			if (O.density && !ismob(O) && !(O in carried))
				return FALSE
	return TRUE

// The whole-tile step. TRUE when everything carried moved one tile in dir.
// Vehicles override this with their own step (axis do_move, vehicle do_move).
/datum/vehicle_offset/proc/commit(dir)
	var/list/destinations = list()
	for (var/atom/movable/A in carried)
		if (!isturf(A.loc))
			return FALSE
		var/turf/T = get_step(A.loc, dir)
		if (!T)
			return FALSE
		destinations[A] = T
	for (var/atom/movable/A in destinations)
		A.forceMove(destinations[A])
	return TRUE

// Advances the offset along one axis by d pixels (sign = way). Returns the pixels moved.
/datum/vehicle_offset/proc/advance(d, horizontal)
	. = 0
	while (d)
		var/part = clamp(d, -VEHICLE_OFFSET_CHUNK, VEHICLE_OFFSET_CHUNK)
		var/now = horizontal ? ox : oy
		var/next = now + part
		var/way = horizontal ? (part > 0 ? EAST : WEST) : (part > 0 ? NORTH : SOUTH)
		// Starting to overlap the next tile: it has to be open.
		if ((now <= 0 && next > 0) || (now >= 0 && next < 0))
			if (!can_cover(way))
				next = 0
				blocked_dir = way
				d = 0
		// Past half a tile: the vehicle's own tile step, then wrap back by a tile.
		if (next >= VEHICLE_OFFSET_HALF || next < -VEHICLE_OFFSET_HALF)
			if (commit(way))
				crossings++
				next += (next > 0) ? -VEHICLE_OFFSET_TILE : VEHICLE_OFFSET_TILE
			else
				next = (next > 0) ? VEHICLE_OFFSET_HALF - 1 : -VEHICLE_OFFSET_HALF
				blocked_dir = way
				d = 0
		. += abs(next - now) * (part > 0 ? 1 : -1)
		if (horizontal)
			ox = next
		else
			oy = next
		if (d)
			d -= part

// Walking on a moving deck. Anything carried that moved by itself since the
// last draw (a person walking, a crate shoved) keeps where it went: its own
// offset is taken again from where it stands. It stays filed under the body
// tile beneath its centre as the body is drawn, so a person at the bow is never
// filed onto the water ahead while the body overlaps it. Someone whose centre
// has left every body tile has stepped off: they are dropped where they stand
// and filed by their own centre again. Runs at the start of every pulse;
// seated riders and cargo that did not move cost one comparison each.
/datum/vehicle_offset/proc/settle()
	var/list/deck = null
	for (var/atom/movable/A in carried)
		if (QDELETED(A) || (A in footprint))
			continue
		var/list/own = carried[A]
		if (!isturf(A.loc))
			drop(A, TRUE)
			continue
		if (A.x * VEHICLE_OFFSET_TILE + A.step_x == own[3] && A.y * VEHICLE_OFFSET_TILE + A.step_y == own[4])
			continue
		if (!deck)
			deck = deck_tiles()
		if (!file_on_deck(A, deck))
			drop(A, TRUE)
			vehicle_offset_refile(A)
			continue
		own[1] = A.step_x - ox
		own[2] = A.step_y - oy
		own[3] = A.x * VEHICLE_OFFSET_TILE + A.step_x
		own[4] = A.y * VEHICLE_OFFSET_TILE + A.step_y

// The tiles the body is filed on (its drawn offset aside).
/datum/vehicle_offset/proc/deck_tiles()
	. = list()
	for (var/atom/movable/F in footprint)
		for (var/turf/T in vehicle_offset_tiles(F))
			.[T] = TRUE

// Files A under the body tile beneath its centre as the body is drawn, keeping
// where A is drawn. FALSE when no body tile is under its centre.
/datum/vehicle_offset/proc/file_on_deck(atom/movable/A, list/deck)
	if (!isturf(A.loc) || A.bound_x || A.bound_y || A.bound_width != VEHICLE_OFFSET_TILE || A.bound_height != VEHICLE_OFFSET_TILE)
		return FALSE
	var/turf/T = vehicle_offset_turf_under(A, ox, oy)
	if (!T || !deck[T])
		return FALSE
	if (A.loc != T)
		// A direct loc write, as human_subtile_anchor(): no turf events, and
		// the pixel position, collision and covered turfs stay as they were.
		var/px = (A.x - T.x) * VEHICLE_OFFSET_TILE + A.step_x
		var/py = (A.y - T.y) * VEHICLE_OFFSET_TILE + A.step_y
		A.loc = T
		A.step_x = px
		A.step_y = py
	return TRUE

// The logical tile underneath A's centre on a body drawn at (ox, oy).
// This read-only inverse is also used by placement; never refile its caller.
/proc/vehicle_offset_turf_under(atom/movable/A, ox, oy)
	if (!isturf(A?.loc))
		return null
	// round() with one argument is floor.
	var/cx = A.x + round((A.step_x - ox + VEHICLE_OFFSET_HALF) / VEHICLE_OFFSET_TILE)
	var/cy = A.y + round((A.step_y - oy + VEHICLE_OFFSET_HALF) / VEHICLE_OFFSET_TILE)
	return locate(cx, cy, A.z)

// One pulse at the current speed: x first, then y. Returns TRUE if anything moved.
/datum/vehicle_offset/proc/pulse()
	pulses++
	var/list/walkers = walks_in_step()
	settle()
	if (speed_x || speed_y)
		blocked_dir = 0
	// round() with one argument is floor; the fraction waits for the next pulse.
	var/total_x = speed_x + rest_x
	var/total_y = speed_y + rest_y
	var/whole_x = round(total_x)
	var/whole_y = round(total_y)
	rest_x = total_x - whole_x
	rest_y = total_y - whole_y
	var/moved_x = whole_x ? advance(whole_x, TRUE) : 0
	var/moved_y = whole_y ? advance(whole_y, FALSE) : 0
	if (blocked_dir & (EAST|WEST))
		speed_x = 0
		rest_x = 0
	if (blocked_dir & (NORTH|SOUTH))
		speed_y = 0
		rest_y = 0
	draw()
	vehicle_offset_rebase_walks(walkers)
	return moved_x || moved_y

// A frame vehicle (cars, trucks, tanks): the tile step is the axis's own
// do_move, which only goes the way the vehicle faces (or backs).
/datum/vehicle_offset/axis/commit(dir)
	var/obj/structure/vehicleparts/axis/A = owner
	if (!istype(A) || QDELETED(A))
		return FALSE
	if (dir != (A.reverse ? OPPOSITE_DIR(A.dir) : A.dir))
		return FALSE
	return A.do_move() ? TRUE : FALSE

// A one-object vehicle (motorcycle, boat): its own rules for the tile ahead
// (water, crashes, grace walls) when it heads that way, then walls beside.
/datum/vehicle_offset/single/can_cover(dir)
	var/obj/structure/vehicle/V = owner
	if (!istype(V) || QDELETED(V))
		return FALSE
	if (V.driver && V.driver.dir == dir && !V.do_vehicle_check())
		return FALSE
	return ..()

// Only single-tile boats opt into eliding unchanged native step assignments.
/datum/vehicle_offset/single/small_boat
	write_changed_steps_only = TRUE

// Its own do_move.
/datum/vehicle_offset/single/commit(dir)
	var/obj/structure/vehicle/V = owner
	if (!istype(V) || QDELETED(V) || !isturf(V.loc))
		return FALSE
	var/turf/was = V.loc
	V.do_move(dir)
	return V.loc != was

// Files A under the tile beneath its own centre again (offsets -16 to 15),
// keeping where it is drawn. For things a vehicle offset stops carrying.
/proc/vehicle_offset_refile(atom/movable/A)
	if (!A || !isturf(A.loc) || A.bound_x || A.bound_y || A.bound_width != VEHICLE_OFFSET_TILE || A.bound_height != VEHICLE_OFFSET_TILE)
		return
	if (ishuman(A))
		var/mob/living/human/H = A
		H.human_subtile_anchor()
		H.human_subtile_offset_owned = !!(H.step_x || H.step_y)
		return
	var/px = A.x * VEHICLE_OFFSET_TILE + A.step_x
	var/py = A.y * VEHICLE_OFFSET_TILE + A.step_y
	var/cx = round((px + VEHICLE_OFFSET_HALF) / VEHICLE_OFFSET_TILE)
	var/cy = round((py + VEHICLE_OFFSET_HALF) / VEHICLE_OFFSET_TILE)
	var/turf/T = locate(cx, cy, A.z)
	if (!T)
		return
	if (A.loc != T)
		A.loc = T
	A.step_x = px - cx * VEHICLE_OFFSET_TILE
	A.step_y = py - cy * VEHICLE_OFFSET_TILE

// Called on every carried mob after each draw.
/atom/movable/proc/vehicle_offset_drawn()
	return

// A person carried at an offset owns it for free movement, so they can walk
// on the deck by pixels; with free movement off they walk whole tiles.
/mob/living/human/vehicle_offset_drawn()
	if (human_subtile_enabled || human_subtile_default_pending)
		human_subtile_offset_owned = !!(step_x || step_y)

// A step under way checks that nobody else moved the walker since its last
// pulse. The deck carrying them is not somebody else: the step goes on from
// where the deck put them. Only a walk whose snapshot still matched before the
// deck moved is carried on, so a shove from anyone else still stops it.
/datum/vehicle_offset/proc/walks_in_step()
	for (var/mob/living/human/H in carried)
		var/datum/human_subtile_transaction/T = H.human_subtile_transaction
		if (T && !T.cancelled && human_subtile_same(T.expected, H.human_subtile_snapshot()))
			LAZYADD(., H)

/proc/vehicle_offset_rebase_walks(list/walkers)
	for (var/mob/living/human/H in walkers)
		var/datum/human_subtile_transaction/T = H.human_subtile_transaction
		if (T && !T.cancelled)
			T.expected = H.human_subtile_snapshot()

#undef VEHICLE_OFFSET_CHUNK
