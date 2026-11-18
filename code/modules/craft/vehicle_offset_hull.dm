// ============================================================
// Vehicle offsets: built hulls under way (docs/vehicle-offset.md)
// ------------------------------------------------------------
// A hull the players laid themselves (built_body.dm) sails by pixels while a
// player is near: her deck, her walls, her upper deck and everyone and
// everything aboard share one offset that creeps along her heading at her
// pace, a pixel at a time, and her own whole-tile move (move_to) runs only
// when the offset passes half a tile. Her crew can walk her deck as she
// moves (settle() in vehicle_offset.dm). The engine's tile glide is not used.
//
// With nobody near, or while the world saves, she squares on her tiles and
// hops a tile at a time as before. A turn or an all stop squares her too.
// Nothing here is saved.
// ============================================================

/datum/craft
	var/tmp/datum/vehicle_offset/hull/offset_mover = null
	var/tmp/offset_tile_wait = 0    // Deciseconds waited towards a whole-tile hop while unwatched.

/datum/vehicle_offset/hull
	var/datum/craft/craft = null

/datum/vehicle_offset/hull/New(datum/craft/C)
	..(null)
	craft = C

/datum/vehicle_offset/hull/Destroy()
	craft = null
	return ..()

// A player near any part of her: her length is added to the range.
/datum/vehicle_offset/hull/watched()
	if (world.time < watch_checked + VEHICLE_OFFSET_WATCH_RECHECK)
		return watch_cached
	watch_checked = world.time
	watch_cached = FALSE
	var/datum/craft_body/B = craft ? craft.body : null
	var/turf/here = B ? B.origin() : null
	if (here)
		var/range = VEHICLE_OFFSET_WATCH_RANGE + max(B.length_tiles(), B.beam_tiles())
		// Her upper deck and her hold count as near her too.
		var/datum/craft_body/built/BB = B
		var/upper = istype(BB) ? BB.upper_z() : 0
		var/lower = istype(BB) ? BB.lower_z() : 0
		for (var/client/C in clients)
			var/turf/there = get_turf(C.mob)
			if (there && (there.z == here.z || (upper && there.z == upper) || (lower && there.z == lower)) && get_dist(here, there) <= range)
				watch_cached = TRUE
				break
	return watch_cached

// She only ever moves along her heading. Starting to overlap the water ahead
// marks it, as the hop warning did, so anyone there is told to get clear.
/datum/vehicle_offset/hull/can_cover(dir)
	var/list/hop = craft ? craft.offset_hop(dir) : null
	if (!hop)
		return FALSE
	craft.mark_path(hop[1], hop[2], dir)
	return TRUE

/datum/vehicle_offset/hull/commit(dir)
	return craft ? craft.offset_commit(dir) : FALSE

// Carries everything aboard her and drops what has left her. Her planks come
// first, so a newcomer is judged by the deck as it is drawn: someone whose
// centre is over her deck is filed on it and carried from where they stand;
// someone whose centre is over the water beside her (just stepped off, or not
// yet aboard) is left alone.
/datum/vehicle_offset/hull/proc/sync()
	var/datum/craft_body/B = craft ? craft.body : null
	if (!B)
		return
	var/list/aboard = list()
	var/list/newcomers = list()
	for (var/atom/movable/M in B.aboard())
		if (istype(M, /obj/effect/vessel_path))
			continue
		aboard[M] = TRUE
		if (M in carried)
			continue
		if (istype(M, /obj/covers))
			carry(M, TRUE)
		else
			newcomers += M
	var/list/deck = newcomers.len ? deck_tiles() : null
	for (var/atom/movable/M in newcomers)
		// Someone boarding mid-step goes on with it from the plank they are filed on.
		var/mob/living/human/H = M
		var/in_step = istype(H) && H.human_subtile_transaction && !H.human_subtile_transaction.cancelled && human_subtile_same(H.human_subtile_transaction.expected, H.human_subtile_snapshot())
		if (ismob(M) && (M.step_x || M.step_y || ox || oy) && !file_on_deck(M, deck))
			aboard -= M
			continue
		carry(M)
		if (in_step)
			vehicle_offset_rebase_walks(list(H))
	for (var/atom/movable/A in carried)
		if (!aboard[A])
			drop(A, TRUE)
			vehicle_offset_refile(A)

// Back to whole tiles: square on her tiles, nobody carried.
/datum/vehicle_offset/hull/proc/release()
	snap()
	for (var/atom/movable/A in carried)
		drop(A, TRUE)

/datum/craft/Destroy()
	. = ..()
	if (offset_mover)
		qdel(offset_mover)
		offset_mover = null

// TRUE when she sails by pixels: a hull the players built, gliding, not in a save.
/datum/craft/proc/offset_sails()
	return istype(body, /datum/craft_body/built) && body.glides && !persistence_save_in_progress

/datum/craft/proc/hull_offset()
	if (!offset_mover)
		offset_mover = new(src)
	return offset_mover

// Deciseconds between pulses: a pixel at a time at her pace.
/datum/craft/proc/offset_period()
	return max(world.tick_lag, sail_interval() / VEHICLE_OFFSET_TILE)

// Squares her on her tiles (a turn, an all stop, a save) and lets go of everyone.
/datum/craft/proc/offset_square()
	offset_tile_wait = 0
	if (offset_mover)
		offset_mover.release()

// Where her box corner goes for one tile in dir, as list(x, y), or null.
/datum/craft/proc/offset_hop(dir)
	if (!body || !body.placed() || dir != body.heading())
		return null
	var/turf/O = body.origin()
	if (!O)
		return null
	var/turf/N = get_step(O, dir)
	if (!N || !body.can_move_to(N.x, N.y, dir))
		last_refusal = body.last_refusal
		return null
	return list(N.x, N.y)

// Her whole-tile move under the offset. TRUE when she moved.
/datum/craft/proc/offset_commit(dir)
	var/list/hop = offset_hop(dir)
	clear_path()
	if (!hop)
		return FALSE
	body.glide_time = 0
	var/moved = body.move_to(hop[1], hop[2], dir)
	if (!moved)
		last_refusal = body.last_refusal
		return FALSE
	sail_paid(1)
	return TRUE

// One pulse of sailing. Unwatched, she waits out a whole hop and hops.
/datum/craft/proc/offset_tick()
	// Coming about: she holds where she is until the turn squares her.
	if (turning_to)
		return
	if (!body || !body.placed() || anchored || speed <= 0 || !offset_sails())
		offset_square()
		return
	var/datum/vehicle_offset/hull/O = hull_offset()
	if (!O.watched())
		if (O.ox || O.oy || O.carried.len)
			offset_square()
		offset_tile_wait += offset_period()
		if (offset_tile_wait >= sail_interval())
			offset_tile_wait = 0
			// A mast lost on the way slows her: the pulse is set again.
			var/before = speed
			sail_hop()
			if (speed != before && speed > 0 && !anchored && !turning_to)
				start_sailing()
		return
	offset_tile_wait = 0
	// A mast lost since the last pulse slows her at once.
	var/was = speed
	sail_trim()
	if (speed != was)
		start_sailing()
		return
	// Squaring, filing and carrying are the deck's moves, not the walker's.
	var/list/walkers = O.walks_in_step()
	O.settle()
	O.sync()
	var/heading = body.heading()
	var/px = VEHICLE_OFFSET_TILE * offset_period() / sail_interval()
	O.speed_x = heading == EAST ? px : (heading == WEST ? -px : 0)
	O.speed_y = heading == NORTH ? px : (heading == SOUTH ? -px : 0)
	O.pulse()
	vehicle_offset_rebase_walks(walkers)
	if (O.blocked_dir)
		O.blocked_dir = 0
		sail_refused()
