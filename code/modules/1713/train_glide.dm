// ============================================================
// Train glide (docs/trains.md): a train's step drawn as one smooth motion
// ------------------------------------------------------------
// A train moves a whole tile at a time: every car, deck part, load and rider
// changes tile in one call, then the train waits for its next step. Drawn at
// their own glide, those moves jump at once and then stand still, so the
// train lurched from tile to tile. Boats and ships hold the glide of
// everything aboard at their own pace (craft/glide.dm); a train uses the same
// helpers, so its cars, decks, loads, riders and the riders' views all slide
// together for exactly as long as the step lasts.
//
// Appearance only: nothing here changes where anything goes or when.
// ============================================================

/obj/structure/trains
	var/tmp/list/train_glide_was = null // Things whose glide this train holds: atom = list(before, applied).

// The step a train is taking right now: the record of the train that owns
// it, how long it lasts on screen (deciseconds) and what it has carried.
var/global/list/train_glide_record = null
var/global/train_glide_time = 0
var/global/list/train_glide_carried = null
var/global/list/train_glide_holder_was = null

// Before a train step that lasts time: everything the step moves takes that
// pace from here to train_glide_end().
/proc/train_glide_begin(obj/structure/trains/owner, time)
	if (!owner || train_glide_record || time <= world.tick_lag)
		return FALSE
	if (!owner.train_glide_was)
		owner.train_glide_was = list()
	train_glide_record = owner.train_glide_was
	train_glide_time = time
	train_glide_carried = list()
	// The cars' own Move() keeps the glide they hold (moved.dm).
	train_glide_holder_was = craft_glide_holder
	craft_glide_holder = train_glide_record
	return TRUE

// After the step: whatever the train no longer carries glides at its own
// pace again.
/proc/train_glide_end(obj/structure/trains/owner)
	if (!owner || !train_glide_record || train_glide_record != owner.train_glide_was)
		return
	var/list/record = train_glide_record
	var/list/carried = train_glide_carried
	craft_glide_holder = train_glide_holder_was
	train_glide_record = null
	train_glide_time = 0
	train_glide_carried = null
	train_glide_holder_was = null
	glide_give_back(record, carried)

// The train has stopped and its last step has been drawn.
/proc/train_glide_rest(obj/structure/trains/owner)
	if (owner && owner.train_glide_was && owner.train_glide_was.len)
		glide_give_back(owner.train_glide_was, null)

// Before AM moves with the train to dest. The engine draws a move at the
// glide a thing has when it moves, so it takes the train's pace first.
/proc/train_glide_before(atom/movable/AM, turf/dest)
	if (!train_glide_record || !AM || !isturf(AM.loc) || !isturf(dest) || AM.z != dest.z)
		return
	if (max(abs(dest.x - AM.x), abs(dest.y - AM.y)) == 1 && craft_glides_natively(AM))
		glide_hold(train_glide_record, AM, craft_glide_size(train_glide_time))

// After AM has moved with the train from the tile from. The engine glides
// only a one-tile move of a thing square on its tile: a free-moving rider,
// or a load swung two tiles round a curve, is drawn where it was and slid.
/proc/train_glide_after(atom/movable/AM, turf/from)
	if (!train_glide_record || !AM || !isturf(AM.loc) || !istype(from) || AM.loc == from || AM.z != from.z)
		return
	var/dx = AM.x - from.x
	var/dy = AM.y - from.y
	if ((abs(dx) > 1 || abs(dy) > 1 || !craft_glides_natively(AM)) && AM.invisibility < 101)
		glide_slide(AM, dx, dy, train_glide_time)
	train_glide_carried[AM] = TRUE

// One move of a train's rider or load, shown at the train's pace.
/atom/movable/proc/train_glide_set_loc(turf/dest)
	var/turf/from = loc
	train_glide_before(src, dest)
	. = persistence_set_loc(dest)
	train_glide_after(src, from)
