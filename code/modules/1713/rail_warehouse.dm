// Rail warehouse (docs/train-platforms.md): a drive-through store for rolling
// stock. The track runs straight through the warehouse; a train drives in and
// stops, and the office post beside the track takes cars off the back of it
// one at a time (or the whole train) and puts them away. Taking a car out
// rolls it onto the track behind the train standing in the bay and couples it.
//
// A stored unit (a platform car's four segments, or a one-tile locomotive or
// wagon) is moved, with everything on its deck, into holder objects inside
// the post. Nothing of it is on the map, rendered or simulated, and world
// saves carry it as ordinary nested contents of the post, cargo included.

#define RAIL_WAREHOUSE_REACH 6 // bay tiles either side of the post's centre line
#define RAIL_WAREHOUSE_TIME 30

/obj/structure/rail_warehouse
	name = "rail warehouse office"
	desc = "The office post of a drive-through rail warehouse. Build it facing the track, with one tile between it and the rails; the track running past it, six tiles either way, is the warehouse bay. Stop a train in the bay to put its cars away, or to couple stored cars back on."
	icon = 'icons/obj/structures.dmi'
	icon_state = "gate_control"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/capacity = 8
	var/tmp/busy = FALSE

/obj/structure/rail_warehouse/persistence_runtime_var(key)
	return key == "busy" || ..(key)

/obj/structure/rail_warehouse/after_load()
	..()
	busy = FALSE

// A unit of rolling stock packed away with its load.
/obj/structure/rail_stored_unit
	name = "stored rail car"
	icon = null
	anchored = TRUE
	density = FALSE
	var/unit_name = "rail car"
	var/heading = NORTH
	var/unit_length = 1

// One tile of a stored unit: seg is the segment (1 = front) and side is
// TRAIN_LEFT, 0 (the track) or TRAIN_RIGHT. Holds what stood on that tile.
/obj/structure/rail_stored_tile
	name = "stored rail car tile"
	icon = null
	anchored = TRUE
	density = FALSE
	var/seg = 1
	var/side = 0

/obj/structure/rail_warehouse/proc/axis()
	return turn(dir, 90)

/obj/structure/rail_warehouse/proc/centre()
	return get_step(get_step(src, dir), dir)

// The bay track tiles, from one end to the other along axis().
/obj/structure/rail_warehouse/proc/bay()
	var/list/tiles = list()
	var/turf/T = centre()
	if (!T)
		return tiles
	for (var/i in 1 to RAIL_WAREHOUSE_REACH)
		var/turf/back = get_step(T, OPPOSITE_DIR(axis()))
		if (!back)
			break
		T = back
	while (T && tiles.len < RAIL_WAREHOUSE_REACH * 2 + 1)
		tiles += T
		if (get_dist(T, centre()) >= RAIL_WAREHOUSE_REACH && T != tiles[1])
			break
		T = get_step(T, axis())
	return tiles

/obj/structure/rail_warehouse/proc/stored_units()
	var/list/units = list()
	for (var/obj/structure/rail_stored_unit/U in contents)
		units += U
	return units

// The segments of the unit TR belongs to, front first.
/proc/rail_warehouse_unit(obj/structure/trains/TR)
	if (!istype(TR, /obj/structure/trains/platform))
		return list(TR)
	var/obj/structure/trains/platform/P = TR
	var/list/segs = P.car_segments()
	var/list/ordered = list()
	for (var/i in 1 to TRAIN_CAR_LENGTH)
		for (var/obj/structure/trains/platform/S in segs)
			if (S.seg_index == i)
				ordered += S
	return ordered

/proc/rail_warehouse_unit_name(list/unit)
	var/obj/structure/trains/front = unit[1]
	return "[front.name]"

// The wagon pulling the unit, if any.
/proc/rail_warehouse_leader(list/unit)
	var/obj/structure/trains/front = unit[1]
	for (var/obj/structure/trains/TR in range(2, front))
		if (TR.connected == front)
			return TR
	return null

// The units in the bay that can come off now: nothing is hitched behind them.
/obj/structure/rail_warehouse/proc/rear_units()
	var/list/bay = bay()
	var/list/units = list()
	var/list/seen = list()
	for (var/turf/T in bay)
		for (var/obj/structure/trains/TR in T)
			if (seen[TR])
				continue
			var/list/unit = rail_warehouse_unit(TR)
			for (var/obj/structure/trains/S in unit)
				seen[S] = TRUE
			var/obj/structure/trains/rear = unit[unit.len]
			if (!rear.connected)
				units += list(unit)
	return units

/obj/structure/rail_warehouse/proc/store_problem(list/unit)
	if (stored_units().len >= capacity)
		return "The warehouse is full: it holds [capacity] cars."
	var/list/bay = bay()
	if (istype(unit[1], /obj/structure/trains/platform) && unit.len != TRAIN_CAR_LENGTH)
		return "\The [unit[1]] is not whole."
	for (var/turf/T in bay)
		for (var/obj/structure/trains/TR in T)
			if (TR.automovement)
				return "Stop the train first."
	for (var/obj/structure/trains/S in unit)
		if (!(S.loc in bay))
			return "\The [S] is not all the way inside the warehouse."
		if (S.buckled_mob)
			return "Get everyone off \the [S] first."
		if (istype(S, /obj/structure/trains/locomotive) && S.on)
			return "Shut \the [S] down first."
		if (istype(S, /obj/structure/trains/platform))
			var/obj/structure/trains/platform/P = S
			if (P.braced)
				return "Raise the outriggers of \the [P] first."
		for (var/turf/T in rail_warehouse_unit_tiles(S))
			for (var/mob/living/L in T)
				return "Get everyone off \the [S] first."
	return null

// The tiles a unit's segment carries: its deck for a platform, else its own tile.
/proc/rail_warehouse_unit_tiles(obj/structure/trains/S)
	if (istype(S, /obj/structure/trains/platform))
		var/list/tiles = train_platform_tiles(S.loc, S.dir)
		for (var/i in list(1, 3))
			if (tiles[i] && train_centre_of_other(tiles[i], S))
				tiles[i] = null
		return tiles
	return list(null, S.loc, null)

// Packs the unit into a holder inside the post.
/obj/structure/rail_warehouse/proc/store_unit(list/unit)
	var/obj/structure/trains/leader = rail_warehouse_leader(unit)
	if (leader)
		leader.connected = null
	var/obj/structure/trains/front = unit[1]
	var/obj/structure/rail_stored_unit/U = new(src)
	U.unit_name = rail_warehouse_unit_name(unit)
	U.heading = front.dir
	U.unit_length = unit.len
	for (var/i in 1 to unit.len)
		var/obj/structure/trains/S = unit[i]
		var/list/tiles = rail_warehouse_unit_tiles(S)
		for (var/slot in 1 to 3)
			var/turf/T = tiles[slot]
			if (!T)
				continue
			var/obj/structure/rail_stored_tile/H = new(U)
			H.seg = i
			H.side = slot - 2
			for (var/atom/movable/AM in T)
				if (AM.loc == T && train_platform_carries(AM))
					AM.persistence_set_loc(H)
			if (slot == 2)
				if (istype(S, /obj/structure/trains/platform))
					var/obj/structure/trains/platform/P = S
					P.clear_parts()
				S.set_light(0)
				S.persistence_set_loc(H)
	return U

// Where a stored unit would roll out: list(front tile, heading, wagon to couple to).
/obj/structure/rail_warehouse/proc/retrieve_place(obj/structure/rail_stored_unit/U)
	var/list/bay = bay()
	for (var/list/unit in rear_units())
		var/obj/structure/trains/rear = unit[unit.len]
		var/turf/behind = get_step(rear, OPPOSITE_DIR(rear.dir))
		if (behind in bay)
			return list(behind, rear.dir, rear)
	var/heading = U.heading
	if (heading != axis() && heading != OPPOSITE_DIR(axis()))
		heading = axis()
	// An empty bay: the unit rolls to the far end it faces.
	return list(heading == axis() ? bay[bay.len] : bay[1], heading, null)

/obj/structure/rail_warehouse/proc/retrieve_turfs(turf/front, heading, length)
	var/list/turfs = list()
	var/turf/T = front
	for (var/i in 1 to length)
		if (!T)
			return null
		turfs += T
		T = get_step(T, OPPOSITE_DIR(heading))
	return turfs

/obj/structure/rail_warehouse/proc/retrieve_problem(obj/structure/rail_stored_unit/U, list/place)
	var/list/bay = bay()
	var/heading = place[2]
	var/list/turfs = retrieve_turfs(place[1], heading, U.unit_length)
	if (!turfs)
		return "There is no room in the bay for [U.unit_name]."
	var/platform = FALSE
	for (var/obj/structure/rail_stored_tile/H in U)
		for (var/obj/structure/trains/platform/P in H)
			platform = TRUE
	for (var/turf/T in turfs)
		if (!(T in bay))
			return "There is no room in the bay for [U.unit_name]: move the train further in."
		var/straight = FALSE
		for (var/obj/structure/rails/R in T)
			if (R.dir == heading || R.dir == OPPOSITE_DIR(heading))
				straight = TRUE
		if (!straight)
			return "The bay track must run straight."
		var/list/check = platform ? train_platform_tiles(T, heading) : list(T)
		for (var/turf/S in check)
			if (!S || S.density)
				return "The bay must be clear either side of the track."
			for (var/atom/movable/AM in S)
				if (istype(AM, /obj/structure/trains) || istype(AM, /obj/structure/train_part))
					return "\The [AM] is in the way."
				if (AM.density && !isliving(AM) && !istype(AM, /obj/structure/rails))
					return "\The [AM] is in the way."
	return null

// Rolls the stored unit out and couples it behind the train in the bay.
/obj/structure/rail_warehouse/proc/retrieve_unit(obj/structure/rail_stored_unit/U)
	var/list/place = retrieve_place(U)
	if (retrieve_problem(U, place))
		return null
	var/heading = place[2]
	var/list/turfs = retrieve_turfs(place[1], heading, U.unit_length)
	var/turning = 0
	for (var/angle in list(0, 90, 180, 270))
		if (turn(U.heading, angle) == heading)
			turning = angle
	var/list/segments = list()
	segments.len = U.unit_length
	for (var/obj/structure/rail_stored_tile/H in U.contents.Copy())
		if (H.seg < 1 || H.seg > turfs.len)
			continue
		var/turf/where = turfs[H.seg]
		if (H.side)
			where = train_platform_tiles(where, heading)[H.side + 2]
		for (var/atom/movable/AM in H.contents.Copy())
			if (istype(AM, /obj/structure/trains))
				var/obj/structure/trains/S = AM
				S.dir = heading
				S.persistence_set_loc(turfs[H.seg])
				segments[H.seg] = S
				continue
			if (turning && isobj(AM))
				AM.set_dir(turn(AM.dir, turning))
			AM.persistence_set_loc(where ? where : turfs[H.seg])
	for (var/obj/structure/trains/platform/P in segments)
		P.last_moved = world.time
		P.apply_layout()
	var/obj/structure/trains/front = segments[1]
	var/obj/structure/trains/coupled = place[3]
	if (coupled && front)
		coupled.connected = front
	qdel(U)
	return front

// A wrench turns the post to face the track.
/obj/structure/rail_warehouse/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wrench) && !busy && !stored_units().len)
		set_dir(turn(dir, -90))
		playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
		to_chat(user, "You turn \the [src] to face [dir2text(dir)].")
		return
	return ..()

// Puts away unit, or with all every car of the train in the bay from the back.
/obj/structure/rail_warehouse/proc/put_away(mob/user, list/unit, all)
	var/stored = 0
	while (TRUE)
		if (!unit)
			var/list/candidates = rear_units()
			if (!candidates.len)
				break
			unit = candidates[1]
		var/problem = store_problem(unit)
		if (problem)
			if (user)
				to_chat(user, SPAN_WARNING(problem))
			break
		var/obj/structure/rail_stored_unit/U = store_unit(unit)
		stored++
		if (user)
			log_game("[key_name(user)] stored [U.unit_name] in [src] at [x],[y],[z].")
			to_chat(user, SPAN_NOTICE("You put \the [U.unit_name] away."))
		if (!all)
			break
		unit = null
	return stored

/obj/structure/rail_warehouse/examine(mob/user, distance)
	..()
	var/list/units = stored_units()
	var/list/names = list()
	for (var/obj/structure/rail_stored_unit/U in units)
		names += U.unit_name
	to_chat(user, names.len ? "Stored ([names.len]/[capacity]): [english_list(names)]." : "It is empty ([capacity] spaces).")

/obj/structure/rail_warehouse/attack_hand(mob/living/human/H)
	if (busy || !istype(H) || !Adjacent(H))
		return
	var/list/options = list()
	var/list/rear = rear_units()
	for (var/list/unit in rear)
		options["Put away \the [rail_warehouse_unit_name(unit)]"] = unit
	if (rear.len)
		options["Put away the whole train"] = "all"
	var/list/units = stored_units()
	for (var/i in 1 to units.len)
		var/obj/structure/rail_stored_unit/U = units[i]
		options["Couple on [i]. [U.unit_name]"] = U
	if (!options.len)
		to_chat(H, SPAN_WARNING("Stop a train in the bay (the track in front of \the [src]) to put its cars away."))
		return
	var/choice = WWinput(H, "Stored: [units.len]/[capacity]. Cars come off the back of the train in the bay, and stored cars are coupled on behind it.", name, "Cancel", options + list("Cancel"))
	if (!(choice in options) || busy || !Adjacent(H))
		return
	busy = TRUE
	if (!do_after(H, RAIL_WAREHOUSE_TIME, src) || QDELETED(src) || !Adjacent(H))
		busy = FALSE
		return
	var/action = options[choice]
	if (istype(action, /obj/structure/rail_stored_unit))
		var/obj/structure/rail_stored_unit/U = action
		if (U.loc == src)
			var/problem = retrieve_problem(U, retrieve_place(U))
			if (problem)
				to_chat(H, SPAN_WARNING(problem))
			else
				var/label = U.unit_name
				if (retrieve_unit(U))
					log_game("[key_name(H)] took [label] out of [src] at [x],[y],[z].")
					to_chat(H, SPAN_NOTICE("\The [label] rolls out of the warehouse."))
	else
		put_away(H, islist(action) ? action : null, action == "all")
	busy = FALSE

#undef RAIL_WAREHOUSE_REACH
#undef RAIL_WAREHOUSE_TIME
