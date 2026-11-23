// ============================================================
// Room to turn (docs/trains.md "Bends")
// ------------------------------------------------------------
// A bend is one curved tile, and a car takes it a section at a time. A car
// long enough to have sections on two bends at once (an S-bend or a tight
// U-turn) folds onto itself: its decks, walls and load overlap. So:
//  - laying track, a bend may not be spiked down closer than
//    TRAIN_BEND_MIN_GAP tiles to the next bend along the line, and the layer
//    is warned below TRAIN_LONG_CAR_LENGTH, which long bogie stock needs;
//  - a train stops short of a bend when the next bend after it is closer than
//    its longest car, on track laid before this rule or on a map; driven at
//    it faster than a crawl, its leading cars leave the rails instead.
// ============================================================

#define TRAIN_BEND_MIN_GAP TRAIN_CAR_LENGTH // the shortest platform car or heavy engine
#define TRAIN_BEND_CRAWL 1 // tiles a second; faster than this into bends too tight derails

// TRUE when T holds a bend that routes trains (a curved rail).
/proc/rail_bend_at(turf/T)
	return istype(rail_routing_at(T), /obj/structure/rails/turn)

// The heading a train leaves T by, having entered it heading the given way,
// or 0 where the track does not carry on.
/proc/rail_leave_heading(turf/T, heading)
	var/obj/structure/rails/R = rail_routing_at(T)
	if (!R || !R.accepts(heading))
		return 0
	var/list/legs = R.exits()
	if (heading in legs)
		return heading
	for (var/d in legs)
		if (d != OPPOSITE_DIR(heading))
			return d
	return 0

// Entering the bend on T heading the given way: how many tiles on the next
// bend lies, or 0 when there is none within limit tiles.
/proc/rail_bend_gap(turf/T, heading, limit)
	var/turf/at = T
	var/way = rail_leave_heading(at, heading)
	for (var/i in 1 to limit)
		if (!way)
			return 0
		at = get_step(at, way)
		if (!at || !rail_at(at))
			return 0
		if (rail_bend_at(at))
			return i
		way = rail_leave_heading(at, way)
	return 0

// The longest car in a train, in tiles: the sections of a platform car or a
// heavy engine share a car_id; anything else is one tile.
/proc/train_longest_car(list/cars)
	. = 1
	var/run = 0
	var/last_id = null
	for (var/obj/structure/trains/car in cars)
		if (car.car_id && car.car_id == last_id)
			run++
		else
			run = 1
		last_id = car.car_id
		. = max(., run)

// Why a train with these cars may not step onto target heading that way, or
// null: the bend there is followed too closely by another for its longest car.
/proc/train_bend_problem(list/cars, turf/target, heading)
	if (!target || !rail_bend_at(target))
		return null
	var/longest = train_longest_car(cars)
	if (longest <= 1)
		return null
	var/gap = rail_bend_gap(target, heading, longest - 1)
	if (!gap)
		return null
	return "The bends ahead are too close together for a [longest]-tile car: it needs [longest] tiles of track from one bend to the next. Relay the line with longer straights between them."

// Looked at from the drive loop when the train could not step: TRUE when it
// ran at bends too tight for it faster than a crawl and left the rails.
/obj/structure/trains/locomotive/proc/tight_bend_check()
	if (rail_speed <= TRAIN_BEND_CRAWL)
		return FALSE
	var/way = train_way()
	var/obj/structure/trains/lead = (way > 0) ? drive_head : drive_tail
	if (!lead || QDELETED(lead))
		lead = src
	if (!isturf(lead.loc))
		return FALSE
	var/heading = (way > 0) ? lead.train_heading() : OPPOSITE_DIR(lead.train_heading())
	var/list/route = lead.rail_target(heading)
	if (!route || !train_bend_problem(train_consist_list(train_head()), route[1], route[2]))
		return FALSE
	return leave_rails(rail_speed >= 3 * TRAIN_BEND_CRAWL ? 2 : 1, 0.25 * rail_speed, "\The [lead] is driven into bends too tight for the train and leaves the rails!") > 0

// ---- Laying track ----

// The pieces of track along the line through T, up to reach tiles each way,
// in order (beds and finished rails, track_laying.dm).
/proc/track_line_through(turf/T, reach)
	var/atom/start = track_piece_at(T)
	if (!start)
		return list()
	var/list/line = list(start)
	var/list/dirs = track_piece_dirs(start)
	for (var/n in 1 to min(2, dirs.len))
		var/d = dirs[n]
		var/turf/at = T
		var/list/side = list()
		for (var/i in 1 to reach)
			var/turf/next = get_step(at, d)
			var/atom/N = track_piece_at(next)
			if (!N || (N in line) || (N in side))
				break
			var/list/nd = track_piece_dirs(N)
			if (!(OPPOSITE_DIR(d) in nd))
				break
			side += N
			at = next
			var/out = 0
			for (var/e in nd)
				if (e != OPPOSITE_DIR(d))
					out = e
					break
			if (!out)
				break
			d = out
		if (n == 1)
			// The first way out goes before T, farthest first.
			var/list/back = list()
			for (var/i = side.len, i >= 1, i--)
				back += side[i]
			line = back + line
		else
			line += side
	return line

// TRUE when a piece of track is (or will be, once spiked) a bend.
/proc/track_piece_bent(atom/piece)
	if (istype(piece, /obj/structure/rail_bed))
		var/obj/structure/rail_bed/B = piece
		return B.curved
	return istype(piece, /obj/structure/rails/turn)

// How close, in tiles, the bend on T or a bend next to it (laying T bends a
// loose end beside it) comes to the next bend along the line; 0 when no two
// such bends lie within reach. Bends elsewhere on old track are left alone.
/proc/track_bend_spacing(turf/T, reach = TRAIN_LONG_CAR_LENGTH)
	var/list/line = track_line_through(T, reach)
	var/here = line.Find(track_piece_at(T))
	var/last = 0
	. = 0
	for (var/i in 1 to line.len)
		if (!track_piece_bent(line[i]))
			continue
		if (last && (abs(last - here) <= 1 || abs(i - here) <= 1))
			var/gap = i - last
			. = . ? min(., gap) : gap
		last = i

// Why the rails on T may not be spiked down, or null.
/proc/track_bend_problem(turf/T)
	var/gap = track_bend_spacing(T, TRAIN_BEND_MIN_GAP)
	if (gap && gap < TRAIN_BEND_MIN_GAP)
		return "Two bends only [gap] tile[gap == 1 ? "" : "s"] apart would fold a railway car onto itself. Leave at least [TRAIN_BEND_MIN_GAP] tiles of track from one bend to the next."
	return null

// A warning for the layer, or null: long bogie stock needs longer straights.
/proc/track_bend_warning(turf/T)
	var/gap = track_bend_spacing(T, TRAIN_LONG_CAR_LENGTH)
	if (gap && gap < TRAIN_LONG_CAR_LENGTH)
		return "These bends are [gap] tiles apart: four-wheel cars and engines take them, but long bogie cars and main-line engines need [TRAIN_LONG_CAR_LENGTH]."
	return null

#undef TRAIN_BEND_MIN_GAP
#undef TRAIN_BEND_CRAWL
