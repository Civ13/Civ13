// ============================================================
// Builders' pegs (docs/build-markers.md)
// ------------------------------------------------------------
// A plan drawn on paper is marked out on the ground as pegs: one on each tile
// that has something to build, with a tag saying what. A peg builds nothing
// and stops nothing: it is not solid, a click on it goes to its tile, and it
// goes when everything it asks for stands on the tile.
//
// A peg knows only text, so it survives a save as it is:
//   wants     "kind=label;kind=label", what is still to build here, the
//             first of them shown on the tag
//   set_id    the pegs of one marking-out share it
//   set_name  what the plan is called
//   note      a note pinned to the tile
//
// Whoever marks a plan out (house_plan_pegs.dm marks a house) calls
// build_marker_place() for each tile with a list of "kind=label" and pulls
// the pegs with build_markers_pull(). A new kind of work is a row of
// build_marker_kinds() and a line of build_marker_built().
// ============================================================

// kind = list("name" = what the kind is, "state" = the tag's icon state).
/proc/build_marker_kinds()
	var/static/list/table
	if (!table)
		table = list(
		"wall" = list("name" = "wall", "state" = "wall"),
		"door" = list("name" = "door", "state" = "door"),
		"window" = list("name" = "window", "state" = "window"),
		"pillar" = list("name" = "pillar", "state" = "pillar"),
		"stairs" = list("name" = "stairs", "state" = "stairs"),
		"ladder" = list("name" = "ladder", "state" = "ladder"),
		"floor" = list("name" = "floor", "state" = "floor"),
		"roof" = list("name" = "roof", "state" = "roof"),
		)
	return table

// Whether work of a kind stands on a tile. Any wall answers a wall and any
// roofing a roof: the plan says what was meant, the builder what was to hand.
/proc/build_marker_built(kind, turf/T)
	if (!T)
		return FALSE
	switch (kind)
		if ("wall")
			if (istype(T, /turf/wall))
				return TRUE
			for (var/obj/covers/C in T)
				if (C.wall && !C.incomplete && !QDELETED(C))
					return TRUE
		if ("door")
			return (locate(/obj/structure/simple_door) in T) ? TRUE : FALSE
		if ("window")
			return ((locate(/obj/structure/window_frame) in T) || (locate(/obj/structure/window) in T)) ? TRUE : FALSE
		if ("pillar")
			return ((locate(/obj/structure/roof_support) in T) || (locate(/obj/structure/mine_support) in T)) ? TRUE : FALSE
		if ("stairs")
			for (var/obj/covers/C in T)
				if (C.stairs && !QDELETED(C))
					return TRUE
		if ("ladder")
			return (locate(/obj/structure/multiz/ladder) in T) ? TRUE : FALSE
		if ("floor")
			// The upper face of the ceiling below is the storey's own floor,
			// not a floor laid on it.
			for (var/obj/covers/C in T)
				if (!C.wall && !C.stairs && !C.incomplete && !C.building_pair_id && !QDELETED(C))
					return TRUE
		if ("roof")
			return (locate(/obj/roof) in T) ? TRUE : FALSE
	return FALSE

// Whether a tile is somewhere to drive a peg: the ground, or a floor over
// open air (an upper storey's floor lies on the open tile).
/proc/build_marker_ground(turf/T)
	return isturf(T) && (!building_open_turf(T) || (locate(/obj/covers) in T))

// Every peg standing in the world. A proc with a static list, not a global:
// the world's global initialiser has no room to spare.
/proc/build_marker_registry()
	var/static/list/standing = list()
	return standing

/proc/build_markers_of(set_id)
	. = list()
	if (!length(set_id))
		return
	for (var/obj/effect/build_marker/M in build_marker_registry())
		if (M.set_id == set_id && !QDELETED(M))
			. += M

// Pulls the pegs of a marking-out, on one level when z is given. Returns how many.
/proc/build_markers_pull(set_id, z = 0)
	. = 0
	for (var/obj/effect/build_marker/M in build_markers_of(set_id))
		if (z && M.z != z)
			continue
		qdel(M)
		.++

/proc/build_marker_at(turf/T, set_id)
	for (var/obj/effect/build_marker/M in T)
		if (M.set_id == set_id && !QDELETED(M))
			return M
	return null

// Drives a peg into a tile asking for wants (a list of "kind=label"), less
// whatever already stands there. A peg of the same marking-out on the tile is
// replaced. Returns the peg, or null when nothing is left to ask for and no
// note is pinned, or when the world holds its fill of pegs.
/proc/build_marker_place(turf/T, list/wants, set_id, set_name, note)
	if (!isturf(T) || !length(set_id))
		return null
	var/obj/effect/build_marker/old = build_marker_at(T, set_id)
	if (old)
		qdel(old)
	var/list/kinds = build_marker_kinds()
	var/list/left = list()
	for (var/want in wants)
		var/kind = build_marker_want_kind(want)
		if (kinds[kind] && !build_marker_built(kind, T))
			left += want
	if (!left.len && !length(note))
		return null
	var/list/standing = build_marker_registry()
	if (standing.len >= BUILD_MARKER_WORLD_MAX)
		return null
	var/obj/effect/build_marker/M = new(T)
	M.wants = jointext(left, ";")
	M.set_id = set_id
	M.set_name = set_name
	M.note = note ? "[note]" : ""
	M.update_tag()
	return M

/proc/build_marker_want_kind(want)
	var/cut = findtext(want, "=")
	return cut ? copytext(want, 1, cut) : want

/proc/build_marker_want_label(want)
	var/cut = findtext(want, "=")
	if (cut && cut < length(want))
		return copytext(want, cut + 1)
	var/list/row = build_marker_kinds()[build_marker_want_kind(want)]
	return row ? row["name"] : "something"

// What the pegs of a marking-out still ask for: label = how many.
/proc/build_markers_left(set_id)
	. = list()
	for (var/obj/effect/build_marker/M in build_markers_of(set_id))
		M.look()
		if (QDELETED(M))
			continue
		for (var/want in M.want_list())
			.[build_marker_want_label(want)]++

// Looks at every peg in turn while any stands, and pulls those whose work is done.
/proc/build_marker_sweep()
	var/static/running = FALSE
	if (running)
		return
	running = TRUE
	spawn (BUILD_MARKER_SWEEP)
		var/list/standing = build_marker_registry()
		while (standing.len)
			var/looked = 0
			for (var/obj/effect/build_marker/M in standing.Copy())
				if (!QDELETED(M))
					M.look()
				if (++looked % BUILD_MARKER_BATCH == 0)
					sleep(1)
			sleep(BUILD_MARKER_SWEEP)
		running = FALSE

/obj/effect/build_marker
	name = "builder's peg"
	desc = "A peg driven into the ground with string run round the tile."
	icon = 'icons/obj/build_markers.dmi'
	icon_state = "peg"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = 2.15 // on the floor, under whatever is built on the tile
	map_storage_saved_vars = "icon_state;name;wants;set_id;set_name;note"
	var/wants = ""
	var/set_id = ""
	var/set_name = ""
	var/note = ""

/obj/effect/build_marker/New()
	..()
	var/list/standing = build_marker_registry()
	standing |= src
	build_marker_sweep()

/obj/effect/build_marker/Destroy()
	var/list/standing = build_marker_registry()
	standing -= src
	return ..()

/obj/effect/build_marker/proc/want_list()
	return length(wants) ? splittext(wants, ";") : list()

/obj/effect/build_marker/proc/update_tag()
	var/list/left = want_list()
	var/list/kinds = build_marker_kinds()
	if (left.len)
		var/list/row = kinds[build_marker_want_kind(left[1])]
		icon_state = row ? row["state"] : "peg"
		name = "peg ([build_marker_want_label(left[1])])"
	else
		icon_state = length(note) ? "note" : "peg"
		name = length(note) ? "peg (note)" : initial(name)

// Strikes off what now stands on the tile; the peg goes with its last want
// unless a note is pinned to it, and goes when its floor does.
/obj/effect/build_marker/proc/look()
	var/turf/T = loc
	if (!isturf(T) || !build_marker_ground(T))
		qdel(src)
		return
	var/list/left = list()
	var/changed = FALSE
	for (var/want in want_list())
		if (build_marker_built(build_marker_want_kind(want), T))
			changed = TRUE
		else
			left += want
	if (!changed)
		return
	if (!left.len && !length(note))
		qdel(src)
		return
	wants = jointext(left, ";")
	update_tag()

/obj/effect/build_marker/proc/wants_text()
	var/list/labels = list()
	for (var/want in want_list())
		var/label = build_marker_want_label(want)
		labels += copytext(label, length(label)) == "s" ? label : "\a [label]"
	return english_list(labels)

/obj/effect/build_marker/examine(mob/user, distance)
	..()
	look()
	if (QDELETED(src))
		to_chat(user, "Everything it asked for is built: the peg comes loose.")
		return
	if (length(set_name))
		to_chat(user, "It marks out <b>[set_name]</b>.")
	if (length(wants))
		to_chat(user, "Still to build on this tile: [wants_text()].")
	if (length(note))
		to_chat(user, "<i>Note:</i> [note]")
	to_chat(user, "<span class='notice'>Alt-click it to pull it up.</span>")

// A peg never takes a click meant for its tile: only examining (shift) and
// pulling (alt) reach the peg itself.
/obj/effect/build_marker/Click(location, control, params)
	var/list/modifiers = params2list(params)
	if (modifiers["shift"] || modifiers["alt"] || !isturf(loc))
		return ..()
	var/turf/T = loc
	return T.Click(location, control, params)

/obj/effect/build_marker/AltClick(mob/user)
	if (!ishuman(user) || user.stat || user.restrained() || !Adjacent(user))
		return ..()
	var/list/options = list("This peg")
	if (length(set_id))
		options += "Every peg of this plan"
	options += "Cancel"
	var/choice = WWinput(user, "Pull up which pegs?", name, "Cancel", options)
	if (QDELETED(src) || QDELETED(user) || user.stat || !Adjacent(user))
		return TRUE
	if (choice == "This peg")
		user.visible_message("<span class='notice'>[user] pulls up a builder's peg.</span>", "<span class='notice'>You pull up the peg.</span>")
		qdel(src)
	else if (choice == "Every peg of this plan")
		var/label = length(set_name) ? set_name : "the plan"
		var/n = build_markers_pull(set_id)
		user.visible_message("<span class='notice'>[user] pulls up the pegs of [label].</span>", "<span class='notice'>You pull up [n] peg\s of [label].</span>")
	return TRUE
