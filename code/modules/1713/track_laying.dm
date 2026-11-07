// Laying railway track by hand, one tile at a time (docs/track-laying.md).
// Sleepers go on the ground first, then a pair of rails on top, then a hammer
// spikes the rails down and the tile becomes ordinary track that trains use.
// A tile's shape (straight or curved) follows the track around it; nobody picks
// an orientation from a menu. A crowbar takes a tile apart again in reverse.
// Unfinished tiles are /obj/structure/rail_bed, not /obj/structure/rails, so
// trains, stations and the rail network ignore them until they are spiked.

#define TRACK_SLEEPER_TIME 20
#define TRACK_RAIL_TIME 20
#define TRACK_SPIKE_TIME 30
#define TRACK_PRY_TIME 30

/obj/item/stack/rail_sleepers
	name = "railway sleepers"
	singular_name = "set of railway sleepers"
	desc = "Wooden ties for one tile of railway track. Lay them on the ground, then fasten rails on top."
	icon = 'icons/obj/vehicles/trains.dmi'
	icon_state = "rails_background"
	w_class = ITEM_SIZE_LARGE
	max_amount = 10
	force = 5
	throwforce = 5

/obj/item/stack/rail_sleepers/attack_self(mob/user)
	var/turf/T = get_step(user, user.dir)
	if (T)
		track_lay_sleepers(T, user)

/obj/item/stack/rail_sleepers/resolve_attack_turf(atom/A, mob/user, icon_x, icon_y)
	var/turf/T = A
	if (!istype(T) || !user.Adjacent(T))
		return ..()
	var/facing = get_dir(user, T)
	track_lay_sleepers(T, user, (facing in cardinal) ? facing : user.dir)
	return TRUE

/obj/item/stack/rail_sleepers/proc/track_lay_sleepers(turf/T, mob/user, facing = user.dir)
	var/problem = track_lay_problem(T)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	to_chat(user, SPAN_NOTICE("You start laying \the [src]."))
	if (!do_after(user, TRACK_SLEEPER_TIME, T))
		return FALSE
	// Someone may have laid track here while we worked.
	problem = track_lay_problem(T)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	if (!use(1))
		return FALSE
	track_place_bed(T, facing)
	playsound(T, 'sound/effects/woodhit.ogg', 50, TRUE)
	user.visible_message(SPAN_NOTICE("[user] lays railway sleepers on the ground."), SPAN_NOTICE("You lay the sleepers; they line up with the track beside them."))
	return TRUE

/obj/item/stack/rail_lengths
	name = "rails"
	singular_name = "pair of rails"
	desc = "Two iron rails, enough for one tile of track. Lay them on railway sleepers and spike them down with a hammer."
	icon = 'icons/obj/vehicles/trains.dmi'
	icon_state = "railspair"
	w_class = ITEM_SIZE_LARGE
	max_amount = 10
	force = 10
	throwforce = 8
	flags = CONDUCT

/obj/item/stack/rail_lengths/attack_self(mob/user)
	var/turf/T = get_step(user, user.dir)
	var/obj/structure/rail_bed/B = T ? (locate(/obj/structure/rail_bed) in T) : null
	if (!B)
		B = locate(/obj/structure/rail_bed) in get_turf(user)
	if (B)
		B.lay_rails(src, user)
	else
		to_chat(user, SPAN_WARNING("Lay railway sleepers first, then put the rails on them."))

/obj/item/stack/rail_lengths/resolve_attack_turf(atom/A, mob/user, icon_x, icon_y)
	var/obj/structure/rail_bed/B = locate(/obj/structure/rail_bed) in A
	if (!B || !user.Adjacent(A))
		return ..()
	B.lay_rails(src, user)
	return TRUE

// Lays sleepers on T shaped to the track around them; loose ends they lead to
// turn to meet them.
/proc/track_place_bed(turf/T, facing)
	var/obj/structure/rail_bed/B = new(T)
	B.reshape(facing)
	B.reshape_neighbours()
	return B

// Why track cannot be laid on T, or null.
/proc/track_lay_problem(turf/T)
	if (!istype(T, /turf/floor) || T.density)
		return "You can't lay track there."
	if (istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/trench))
		return "Track needs firm, dry ground."
	if (locate(/obj/structure/rails) in T)
		return "There is already track there."
	if (locate(/obj/structure/rail_bed) in T)
		return "There are already sleepers there."
	for (var/obj/O in T)
		if (O.density)
			return "\The [O] is in the way."
	return null

// The piece of track on T: finished rails first, then an unfinished bed.
/proc/track_piece_at(turf/T)
	if (!T)
		return null
	var/obj/structure/rails/R = locate(/obj/structure/rails) in T
	if (R)
		return R
	return locate(/obj/structure/rail_bed) in T

// The directions a piece of track leads to.
/proc/track_piece_dirs(atom/piece)
	if (istype(piece, /obj/structure/rail_bed))
		var/obj/structure/rail_bed/B = piece
		return B.shape_dirs()
	if (istype(piece, /obj/structure/rails/rotate))
		return cardinal.Copy()
	if (istype(piece, /obj/structure/rails/turn))
		var/obj/structure/rails/turn/RT = piece
		if (RT.turn_dir)
			return list(OPPOSITE_DIR(RT.dir), RT.turn_dir)
		return list()
	if (istype(piece, /obj/structure/rails/split/switcher))
		var/obj/structure/rails/S = piece
		return list(S.dir, OPPOSITE_DIR(S.dir), turn(S.dir, S.sw_direction == "right" ? -90 : 90))
	if (istype(piece, /obj/structure/rails))
		return list(piece.dir, OPPOSITE_DIR(piece.dir))
	return list()

// The directions from piece's tile whose neighbouring track leads back to it.
/proc/track_linked_dirs(atom/piece)
	. = list()
	var/turf/T = get_turf(piece)
	for (var/d in track_piece_dirs(piece))
		var/atom/N = track_piece_at(get_step(T, d))
		if (N && (OPPOSITE_DIR(d) in track_piece_dirs(N)))
			. += d

// Whether a piece may still turn to meet new track: an unfinished bed, or a
// finished plain tile at the loose end of a line with no wagon on it.
/proc/track_piece_bendable(atom/piece)
	if (istype(piece, /obj/structure/rail_bed))
		var/list/linked = track_linked_dirs(piece)
		return linked.len < 2
	if (!track_plain_rail(piece))
		return FALSE
	if (locate(/obj/structure/trains) in get_turf(piece))
		return FALSE
	var/list/linked = track_linked_dirs(piece)
	return linked.len < 2

// Plain straight or curved track, the kind laid by hand. Switches, rotators and
// buffer ends are left alone.
/proc/track_plain_rail(atom/piece)
	return istype(piece, /obj/structure/rails/regular) || istype(piece, /obj/structure/rails/turn)

// The shape a tile of track on T should take: list(dir, curved).
// Track already leading to T wins; otherwise a loose end in line with the
// layer joins it; a lone tile follows fallback_dir (the way the layer faces).
/proc/track_shape_for(turf/T, fallback_dir)
	var/list/linked = list()
	var/list/loose = list()
	for (var/d in cardinal)
		var/atom/N = track_piece_at(get_step(T, d))
		if (!N)
			continue
		if (OPPOSITE_DIR(d) in track_piece_dirs(N))
			linked += d
		else if (track_piece_bendable(N))
			loose += d
	var/list/ends = linked.Copy()
	if (ends.len == 1)
		// A line leading here carries straight on; a loose end beside it is
		// only joined straight ahead, so a parallel line is never pulled in.
		// Corners form when the next tile is laid and bends this one.
		if (OPPOSITE_DIR(ends[1]) in loose)
			ends += OPPOSITE_DIR(ends[1])
	var/fallback = (fallback_dir in cardinal) ? fallback_dir : NORTH
	if (!ends.len)
		// A new tile joins a loose end ahead of or behind the layer, and then
		// may curve to one more; a loose end off to the side alone is ignored,
		// so a new line can start beside the tip of another.
		for (var/d in loose)
			if (d == fallback || d == OPPOSITE_DIR(fallback))
				ends += d
				break
		if (ends.len)
			for (var/d in loose)
				if (ends.len >= 2)
					break
				if (!(d in ends))
					ends += d
	// Straight through when both ends of one axis are track.
	var/vertical = (NORTH in ends) && (SOUTH in ends)
	var/horizontal = (EAST in ends) && (WEST in ends)
	if (vertical && horizontal)
		return list((fallback == EAST || fallback == WEST) ? EAST : NORTH, FALSE)
	if (vertical)
		return list(NORTH, FALSE)
	if (horizontal)
		return list(EAST, FALSE)
	if (ends.len >= 2)
		return list(track_curve_dir(ends[1], ends[2]), TRUE)
	if (ends.len == 1)
		return list((ends[1] == EAST || ends[1] == WEST) ? EAST : NORTH, FALSE)
	return list((fallback == EAST || fallback == WEST) ? EAST : NORTH, FALSE)

// The dir of a /obj/structure/rails/turn joining perpendicular sides a and b.
// A turn faces dir and leads to OPPOSITE_DIR(dir) and turn(dir, 90).
/proc/track_curve_dir(a, b)
	var/d = OPPOSITE_DIR(a)
	if (turn(d, 90) == b)
		return d
	return OPPOSITE_DIR(b)

// Re-bends finished plain rail into the shape its neighbours now ask for.
/proc/track_bend_rail(obj/structure/rails/R)
	var/turf/T = get_turf(R)
	var/list/shape = track_shape_for(T, R.dir)
	var/curved = shape[2]
	if (curved == istype(R, /obj/structure/rails/turn) && (curved ? R.dir == shape[1] : (shape[1] in list(R.dir, OPPOSITE_DIR(R.dir)))))
		return R
	qdel(R)
	return track_make_rail(T, shape[1], curved)

/proc/track_make_rail(turf/T, d, curved)
	var/obj/structure/rails/R
	if (curved)
		R = new /obj/structure/rails/turn(T)
	else
		R = new /obj/structure/rails/regular(T)
	R.set_dir(d)
	return R

/obj/structure/rail_bed
	name = "railway sleepers"
	desc = "Sleepers laid for a tile of railway track."
	icon = 'icons/obj/vehicles/trains.dmi'
	icon_state = "rails_background"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	crushable = FALSE
	layer = 2.5
	dir = NORTH
	var/railed = FALSE // rails sit on the sleepers, not yet spiked down
	var/curved = FALSE // a /obj/structure/rails/turn facing dir once spiked

/obj/structure/rail_bed/after_load()
	..()
	update_icon()

/obj/structure/rail_bed/update_icon()
	if (railed)
		icon_state = curved ? "rails_turn_left" : "rails"
		color = "#c8c8c8"
	else
		icon_state = "rails_background"
		color = null

/obj/structure/rail_bed/examine(mob/user)
	..()
	if (railed)
		to_chat(user, SPAN_NOTICE("The rails are not spiked down yet. Use a hammer to finish the track, or a crowbar to lift the rails off."))
	else
		to_chat(user, SPAN_NOTICE("Put rails on the sleepers next, or pry the sleepers up with a crowbar."))

/obj/structure/rail_bed/proc/shape_dirs()
	if (curved)
		return list(OPPOSITE_DIR(dir), turn(dir, 90))
	return list(dir, OPPOSITE_DIR(dir))

/obj/structure/rail_bed/proc/reshape(fallback_dir = dir)
	var/list/shape = track_shape_for(get_turf(src), fallback_dir)
	curved = shape[2]
	set_dir(shape[1])
	update_icon()

// After this tile is laid, loose ends it leads to turn to meet it.
/obj/structure/rail_bed/proc/reshape_neighbours()
	var/turf/T = get_turf(src)
	for (var/d in shape_dirs())
		var/atom/N = track_piece_at(get_step(T, d))
		if (!N || (OPPOSITE_DIR(d) in track_piece_dirs(N)) || !track_piece_bendable(N))
			continue
		if (istype(N, /obj/structure/rail_bed))
			var/obj/structure/rail_bed/B = N
			B.reshape(B.dir)
		else
			track_bend_rail(N)

/obj/structure/rail_bed/proc/place_rails()
	// The track around may have grown while the rails were carried over.
	if (track_piece_bendable(src))
		reshape(dir)
	railed = TRUE
	update_icon()

/obj/structure/rail_bed/proc/lay_rails(obj/item/stack/rail_lengths/R, mob/user)
	if (railed)
		to_chat(user, SPAN_WARNING("There are already rails on \the [src]. Spike them down with a hammer."))
		return FALSE
	to_chat(user, SPAN_NOTICE("You start setting the rails on \the [src]."))
	if (!do_after(user, TRACK_RAIL_TIME, src))
		return FALSE
	if (railed || QDELETED(src) || !R.use(1))
		return FALSE
	place_rails()
	playsound(loc, 'sound/effects/clang.ogg', 50, TRUE)
	user.visible_message(SPAN_NOTICE("[user] sets rails on the sleepers."), SPAN_NOTICE("You set the rails on the sleepers. Spike them down with a hammer."))
	return TRUE

// Spikes the rails down: the tile becomes finished track. Returns the rails.
/obj/structure/rail_bed/proc/spike()
	if (!railed)
		return null
	var/turf/T = get_turf(src)
	var/d = dir
	var/c = curved
	qdel(src)
	return track_make_rail(T, d, c)

// Lifts loose rails off the sleepers, or pries up bare sleepers; returns the item.
/obj/structure/rail_bed/proc/pry()
	var/turf/T = get_turf(src)
	if (railed)
		railed = FALSE
		update_icon()
		return new /obj/item/stack/rail_lengths(T, 1)
	qdel(src)
	return new /obj/item/stack/rail_sleepers(T, 1)

/obj/structure/rail_bed/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/rail_lengths))
		lay_rails(W, user)
		return TRUE
	if (istype(W, /obj/item/weapon/hammer))
		if (!railed)
			to_chat(user, SPAN_WARNING("Put rails on the sleepers before spiking them."))
			return TRUE
		to_chat(user, SPAN_NOTICE("You start driving spikes into \the [src]."))
		playsound(loc, 'sound/effects/clang.ogg', 50, TRUE)
		if (!do_after(user, TRACK_SPIKE_TIME, src) || QDELETED(src) || !railed)
			return TRUE
		var/turf/T = get_turf(src)
		spike()
		playsound(T, 'sound/effects/clang.ogg', 50, TRUE)
		user.visible_message(SPAN_NOTICE("[user] spikes the rails down."), SPAN_NOTICE("You spike the rails down. The track is ready for trains."))
		return TRUE
	if (istype(W, /obj/item/weapon/crowbar))
		var/had_rails = railed
		to_chat(user, SPAN_NOTICE(had_rails ? "You start lifting the rails off \the [src]." : "You start prying up \the [src]."))
		if (!do_after(user, TRACK_PRY_TIME, src) || QDELETED(src) || railed != had_rails)
			return TRUE
		pry()
		if (had_rails)
			user.visible_message(SPAN_NOTICE("[user] lifts the rails off the sleepers."), SPAN_NOTICE("You lift the rails off the sleepers."))
		else
			user.visible_message(SPAN_NOTICE("[user] pries up the railway sleepers."), SPAN_NOTICE("You pry up the sleepers."))
		return TRUE
	return ..()

// Takes finished track apart: plain track loses its spikes and becomes loose
// rails on sleepers (returned); switches, rotators and buffer ends give their
// iron back. Refused while a wagon stands on the tile.
/obj/structure/rails/proc/pry_apart()
	var/turf/T = get_turf(src)
	if (!T || (locate(/obj/structure/trains) in T))
		return null
	. = null
	if (track_plain_rail(src))
		var/obj/structure/rail_bed/B = new(T)
		B.curved = istype(src, /obj/structure/rails/turn)
		B.set_dir(dir)
		B.railed = TRUE
		B.update_icon()
		. = B
	else
		var/iron = istype(src, /obj/structure/rails/rotate) ? 3 : (istype(src, /obj/structure/rails/split) ? 2 : 1)
		. = new /obj/item/stack/material/iron(T, iron)
	qdel(src)

// A crowbar takes finished track apart; a hammer no longer turns rails into wood.
/obj/structure/rails/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/hammer))
		to_chat(user, SPAN_NOTICE("This track is already spiked down. Pry it up with a crowbar to take it apart."))
		return TRUE
	if (!istype(W, /obj/item/weapon/crowbar))
		return ..()
	if (locate(/obj/structure/trains) in get_turf(src))
		to_chat(user, SPAN_WARNING("Move the wagon off this track first."))
		return TRUE
	var/plain = track_plain_rail(src)
	to_chat(user, SPAN_NOTICE(plain ? "You start pulling the spikes from \the [src]." : "You start dismantling \the [src]."))
	if (!do_after(user, TRACK_PRY_TIME, src) || QDELETED(src))
		return TRUE
	var/turf/T = get_turf(src)
	if (!pry_apart())
		to_chat(user, SPAN_WARNING("Move the wagon off this track first."))
		return TRUE
	playsound(T, 'sound/items/Crowbar.ogg', 50, TRUE)
	if (plain)
		user.visible_message(SPAN_NOTICE("[user] pulls the spikes from the track."), SPAN_NOTICE("You pull the spikes. The rails now sit loose on their sleepers."))
	else
		user.visible_message(SPAN_NOTICE("[user] dismantles the track."), SPAN_NOTICE("You dismantle the track."))
	return TRUE

#undef TRACK_SLEEPER_TIME
#undef TRACK_RAIL_TIME
#undef TRACK_SPIKE_TIME
#undef TRACK_PRY_TIME
