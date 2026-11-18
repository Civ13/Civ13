// Turntables (train scale-up, step 15).
//
// A turntable is a pivot with a girder bridge of rails across a square pit.
// Pushed round by hand, it turns whatever stands on the bridge: an engine to
// face the other way, or a car onto a road that leaves the pit at a right
// angle. The small table carries five tiles of rail (a heavy locomotive or a
// short car), the large one eleven (a main-line engine with its tender).
//
// Nothing here runs on a timer. The bridge rails are ordinary rails as far as
// trains are concerned, so a line that meets the pit where the bridge is not
// lined up simply ends there: an engine driven on runs off the end of the
// rails (train_derail.dm).

#define TURNTABLE_TIME 20 // deciseconds for a quarter turn of the empty bridge
#define TURNTABLE_WEIGHT_TIME 6 // more for each unit of weight standing on it
#define TURNTABLE_TIME_MAX 150

/obj/structure/rails/turntable
	name = "turntable bridge"
	desc = "Rails on the girder bridge of a turntable."
	not_disassemblable = TRUE

// The plank deck lies under the rails and the girders stand over them.
/obj/structure/rails/turntable/update_icon()
	..()
	var/image/deck = image('icons/obj/vehicles/train_platforms.dmi', "turntable_deck")
	deck.dir = dir
	var/image/girders = image('icons/obj/vehicles/train_platforms.dmi', "turntable_girders")
	girders.dir = dir
	underlays = list(deck)
	overlays = list(girders)

/obj/structure/rails/turntable/after_load()
	..()
	update_icon()

// The turntable this piece of bridge belongs to, or null.
/obj/structure/rails/turntable/proc/table()
	var/turf/here = get_turf(src)
	for (var/obj/structure/train_turntable/T in range(5, src))
		if (T.laid && (here in T.bridge_tiles()))
			return T
	return null

/obj/structure/rails/turntable/pry_apart()
	return null

/obj/structure/rails/turntable/attackby(obj/item/W, mob/user)
	if (is_tool(W, TOOL_CROWBAR) || is_tool(W, TOOL_HAMMER))
		to_chat(user, SPAN_NOTICE("\The [src] is part of a turntable. Take the table up with a crowbar at its pivot."))
		return TRUE
	return ..()

/obj/structure/rails/turntable/attack_hand(mob/living/user as mob)
	var/obj/structure/train_turntable/T = table()
	if (T)
		return T.attack_hand(user)
	return ..()

/obj/structure/rails/turntable/examine(mob/user)
	..()
	var/obj/structure/train_turntable/T = table()
	if (T)
		to_chat(user, "Click it with an empty hand to push the table round.")

/obj/structure/train_turntable
	name = "turntable"
	desc = "The pivot of a locomotive turntable. Its bridge carries five tiles of rail across a pit five tiles square."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "turntable_pivot"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	flammable = FALSE
	layer = 2.55
	var/radius = 2 // tiles of bridge either side of the pivot
	var/laid = FALSE // the bridge is down
	var/tmp/busy = FALSE

/obj/structure/train_turntable/large
	name = "large turntable"
	desc = "The pivot of a large locomotive turntable. Its bridge carries eleven tiles of rail across a pit eleven tiles square: room for a main-line engine with its tender."
	radius = 5

/obj/structure/train_turntable/persistence_runtime_var(key)
	return key == "busy" || ..(key)

/obj/structure/train_turntable/after_load()
	..()
	busy = FALSE
	update_icon()

// The pit is drawn from the pivot, under the bridge and whatever stands on it.
/obj/structure/train_turntable/update_icon()
	overlays.Cut()
	if (!laid)
		return
	var/image/pit = image(radius > 2 ? 'icons/obj/vehicles/train_turntable_large.dmi' : 'icons/obj/vehicles/train_turntable.dmi', "pit")
	pit.layer = 2.1
	pit.pixel_x = -32 * radius
	pit.pixel_y = -32 * radius
	overlays += pit

/obj/structure/train_turntable/Destroy()
	if (laid)
		for (var/obj/structure/rails/turntable/R in bridge_rails())
			qdel(R)
	return ..()

// Whether the bridge lies north and south.
/obj/structure/train_turntable/proc/upright(heading = null)
	if (!heading)
		heading = dir
	return heading == NORTH || heading == SOUTH

// The tiles the bridge covers, lying the way heading runs.
/obj/structure/train_turntable/proc/bridge_tiles(heading = null)
	var/list/tiles = list()
	var/turf/C = get_turf(src)
	if (!C)
		return tiles
	var/tall = upright(heading)
	for (var/i in -radius to radius)
		var/turf/T = locate(C.x + (tall ? 0 : i), C.y + (tall ? i : 0), C.z)
		if (T)
			tiles += T
	return tiles

// The square the bridge sweeps, or null when it runs off the map.
/obj/structure/train_turntable/proc/pit_tiles()
	var/turf/C = get_turf(src)
	if (!C || C.x - radius < 1 || C.y - radius < 1 || C.x + radius > world.maxx || C.y + radius > world.maxy)
		return null
	return block(locate(C.x - radius, C.y - radius, C.z), locate(C.x + radius, C.y + radius, C.z))

/obj/structure/train_turntable/proc/bridge_rails()
	var/list/rails = list()
	for (var/turf/T in bridge_tiles())
		for (var/obj/structure/rails/turntable/R in T)
			rails += R
	return rails

/obj/structure/train_turntable/proc/bridge_whole()
	for (var/turf/T in bridge_tiles())
		if (!(locate(/obj/structure/rails/turntable) in T))
			return FALSE
	return TRUE

// Where T comes to when the table turns by angle (90 is a quarter to the left).
/obj/structure/train_turntable/proc/rotated(turf/T, angle)
	var/turf/C = get_turf(src)
	if (!C || !T)
		return null
	var/dx = T.x - C.x
	var/dy = T.y - C.y
	switch (angle)
		if (90)
			return locate(C.x - dy, C.y + dx, C.z)
		if (-90, 270)
			return locate(C.x + dy, C.y - dx, C.z)
		if (180, -180)
			return locate(C.x - dx, C.y - dy, C.z)
	return T

// Why the bridge cannot be laid here, or null.
/obj/structure/train_turntable/proc/lay_problem()
	var/list/pit = pit_tiles()
	if (!pit)
		return "\The [src] is too near the edge of the land: its pit is [radius * 2 + 1] tiles square."
	var/list/bridge = bridge_tiles()
	for (var/turf/T in pit)
		if (!istype(T, /turf/floor) || T.density || istype(T, /turf/floor/trench) || (istype(T, /turf/floor/beach/water) && !bridge_deck_at(T)))
			return "The pit needs firm, dry, open ground [radius * 2 + 1] tiles square: \the [T] will not do."
		for (var/atom/movable/AM in T)
			if (AM == src)
				continue
			if (istype(AM, /obj/structure/rails/turntable) && (T in bridge))
				continue
			if (istype(AM, /obj/structure/rails) || istype(AM, /obj/structure/rail_bed))
				return "Take up the track inside the pit first: the lines must stop at its edge."
			if (istype(AM, /obj/structure/trains) || istype(AM, /obj/structure/train_part) || (AM.density && !isliving(AM)))
				return "\The [AM] is in the way of the pit."
	return null

// Lays the bridge rails, or sets back the ones that are missing.
/obj/structure/train_turntable/proc/lay()
	if (lay_problem())
		return FALSE
	for (var/turf/T in bridge_tiles())
		if (locate(/obj/structure/rails/turntable) in T)
			continue
		var/obj/structure/rails/turntable/R = new(T)
		R.set_dir(upright() ? NORTH : EAST)
		R.update_icon()
	laid = TRUE
	update_icon()
	return TRUE

/obj/structure/train_turntable/proc/take_up_problem()
	if (!laid)
		return "Its bridge is not laid."
	for (var/turf/T in pit_tiles())
		for (var/obj/structure/trains/TR in T)
			return "Run \the [TR] off the table first."
	return null

/obj/structure/train_turntable/proc/take_up()
	if (take_up_problem())
		return FALSE
	for (var/obj/structure/rails/turntable/R in bridge_rails())
		qdel(R)
	laid = FALSE
	update_icon()
	return TRUE

// Every train section standing on the bridge.
/obj/structure/train_turntable/proc/units()
	var/list/cars = list()
	for (var/turf/T in bridge_tiles())
		for (var/obj/structure/trains/TR in T)
			cars += TR
	return cars

// The tiles that turn with the table: the bridge, and the overhang of the
// wide cars and engines standing on it.
/obj/structure/train_turntable/proc/moving_tiles(list/cars)
	var/list/tiles = bridge_tiles()
	for (var/obj/structure/trains/TR in cars)
		if (TR.wide_body())
			for (var/turf/T in train_platform_tiles(TR.loc, TR.dir))
				tiles |= T
	return tiles

// Why the table cannot turn now, or null.
/obj/structure/train_turntable/proc/turn_problem()
	if (!laid)
		return "Its bridge is not laid yet."
	if (!bridge_whole())
		return "The bridge is broken."
	var/list/pit = pit_tiles()
	if (!pit)
		return "There is no room for its pit."
	var/list/cars = units()
	for (var/obj/structure/trains/TR in cars)
		var/obj/structure/trains/locomotive/L = TR
		if (TR.automovement || TR.roll_speed > 0 || (istype(L) && (L.driving || L.rail_speed > 0)))
			return "Stop \the [TR] first."
		if (TR.derailed)
			return "Put \the [TR] back on the rails first."
		if (istype(TR, /obj/structure/trains/platform))
			var/obj/structure/trains/platform/P = TR
			if (P.braced || P.wrecked)
				return "\The [P] cannot be turned as it stands."
		var/obj/structure/trains/behind = TR.connected
		if (behind && !(behind in cars))
			return "\The [TR] is coupled to \the [behind], which is not on the table: uncouple it, or bring it all on."
		var/obj/structure/trains/ahead = TR.lead_car()
		if (ahead && !(ahead in cars))
			return "\The [TR] is coupled to \the [ahead], which is not on the table: uncouple it, or bring it all on."
	var/list/moving = moving_tiles(cars)
	for (var/turf/T in pit)
		if (T.density)
			return "\The [T] is in the way of the bridge."
		if (T in moving)
			continue
		for (var/atom/movable/AM in T)
			if (AM == src)
				continue
			if (isliving(AM))
				return "[AM] is standing in the pit."
			if (istype(AM, /obj/structure/trains) || istype(AM, /obj/structure/train_part) || istype(AM, /obj/structure/rails) || AM.density)
				return "\The [AM] is in the way of the bridge."
	return null

// How long a quarter turn takes one person, by what stands on the bridge.
/obj/structure/train_turntable/proc/turn_time()
	var/weight = 0
	for (var/obj/structure/trains/TR in units())
		weight += TR.car_load_weight()
	return min(TURNTABLE_TIME_MAX, round(TURNTABLE_TIME + weight * TURNTABLE_WEIGHT_TIME))

// The people who can put a shoulder to it: at either end of the bridge, or
// standing on it.
/obj/structure/train_turntable/proc/hands()
	var/list/found = list()
	var/list/bridge = bridge_tiles()
	if (!bridge.len)
		return found
	for (var/turf/E in list(bridge[1], bridge[bridge.len]))
		for (var/mob/living/human/H in range(1, E))
			if (!H.incapacitated())
				found |= H
	return found

// Turns the bridge and everything on it by angle. Returns TRUE when it moved.
/obj/structure/train_turntable/proc/swing(angle)
	if (!(angle in list(90, -90, 180)) || turn_problem())
		return FALSE
	var/list/cars = units()
	var/list/cargo = list()
	for (var/turf/T in moving_tiles(cars))
		for (var/atom/movable/AM in T)
			if (AM.loc == T && AM != src && train_platform_carries(AM))
				cargo[AM] = rotated(T, angle)
	for (var/obj/structure/rails/turntable/R in bridge_rails())
		R.loc = rotated(R.loc, angle)
		R.dir = turn(R.dir, angle)
		R.update_icon()
	dir = turn(dir, angle)
	var/list/places = list()
	for (var/obj/structure/trains/TR in cars)
		places[TR] = rotated(TR.loc, angle)
	for (var/obj/structure/trains/TR in cars)
		TR.dir = turn(TR.dir, angle)
		TR.train_shift(places[TR], FALSE)
	for (var/obj/structure/trains/TR in cars)
		if (istype(TR, /obj/structure/trains/platform))
			var/obj/structure/trains/platform/P = TR
			P.last_moved = world.time
			P.place_parts(P.loc, P.dir)
		if (istype(TR, /obj/structure/trains/locomotive))
			var/obj/structure/trains/locomotive/E = TR
			E.place_body()
		TR.update_couplers()
	for (var/atom/movable/AM in cargo)
		AM.train_shift(cargo[AM], FALSE)
		AM.set_dir(turn(AM.dir, angle))
	rail_network_serial++
	if (isturf(loc))
		playsound(loc, 'sound/effects/lever.ogg', 60, TRUE)
	return TRUE

// Whether user stands on the bridge or next to it.
/obj/structure/train_turntable/proc/in_reach(mob/user)
	for (var/turf/T in bridge_tiles())
		if (get_dist(user, T) <= 1)
			return TRUE
	return FALSE

// user pushes the table round by angle.
/obj/structure/train_turntable/proc/work(mob/living/user, angle)
	if (busy || !istype(user) || user.incapacitated())
		return FALSE
	if (!in_reach(user))
		to_chat(user, SPAN_WARNING("Stand at the bridge to push it."))
		return FALSE
	var/problem = turn_problem()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	var/quarters = (angle == 180) ? 2 : 1
	var/time = turn_time() * quarters
	if (hands().len >= 2)
		time = round(time / 2)
	busy = TRUE
	user.visible_message("[user] puts a shoulder to \the [src] and starts to push it round.", "You start to push \the [src] round.")
	var/done = do_after(user, time, src)
	busy = FALSE
	if (!done || QDELETED(src) || !in_reach(user))
		return FALSE
	problem = turn_problem()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	if (!swing(angle))
		return FALSE
	user.visible_message("\The [src] comes round and its bridge lies [upright() ? "north and south" : "east and west"].", "You bring \the [src] round: its bridge lies [upright() ? "north and south" : "east and west"].")
	return TRUE

/obj/structure/train_turntable/attack_hand(mob/living/user as mob)
	if (!istype(user) || user.incapacitated() || busy)
		return
	if (!laid || !bridge_whole())
		var/problem = lay_problem()
		if (problem)
			to_chat(user, SPAN_WARNING(problem))
			return
		busy = TRUE
		user.visible_message("[user] starts to lay the bridge of \the [src].", "You start to lay the bridge of \the [src], [upright() ? "north and south" : "east and west"].")
		var/done = do_after(user, 100, src)
		busy = FALSE
		if (!done || QDELETED(src))
			return
		if (lay())
			to_chat(user, SPAN_NOTICE("The bridge is laid. Bring the lines up to the edge of the pit, in line with the pivot."))
		return
	var/list/options = list("A quarter turn to the left" = 90, "A quarter turn to the right" = -90, "Right round, to face the other way" = 180)
	var/choice = WWinput(user, "The bridge lies [upright() ? "north and south" : "east and west"]. How far do you push it?", name, "Cancel", options + "Cancel")
	if (!(choice in options) || QDELETED(src))
		return
	work(user, options[choice])

/obj/structure/train_turntable/attackby(obj/item/W as obj, mob/user as mob)
	if (is_tool(W, TOOL_WRENCH))
		if (laid)
			to_chat(user, SPAN_WARNING("The bridge is laid: push it round by hand."))
			return
		set_dir(turn(dir, -90))
		playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
		to_chat(user, "You set \the [src] out for a bridge lying [upright() ? "north and south" : "east and west"].")
		return
	if (is_tool(W, TOOL_CROWBAR) && laid)
		var/problem = take_up_problem()
		if (problem || busy)
			to_chat(user, SPAN_WARNING(problem ? problem : "Somebody is working it."))
			return
		busy = TRUE
		user.visible_message("[user] starts to take up the bridge of \the [src].", "You start to take up the bridge of \the [src].")
		var/done = do_after(user, 100, src)
		busy = FALSE
		if (done && !QDELETED(src) && take_up())
			to_chat(user, SPAN_NOTICE("You take up the bridge. The pivot can be set out again."))
		return
	return ..()

/obj/structure/train_turntable/examine(mob/user)
	..()
	var/size = radius * 2 + 1
	if (!laid)
		to_chat(user, "Its bridge is not laid. It wants a clear pit [size] tiles square with no track in it, the pivot at the middle. A wrench sets which way the bridge will lie ([upright() ? "north and south" : "east and west"] now); an empty hand lays it.")
		return
	to_chat(user, "Its bridge carries [size] tiles of rail and lies [upright() ? "north and south" : "east and west"]. An empty hand on the pivot or the bridge pushes it round; a second pair of hands at an end of the bridge halves the work. A crowbar on the pivot takes the bridge up.")

#undef TURNTABLE_TIME
#undef TURNTABLE_WEIGHT_TIME
#undef TURNTABLE_TIME_MAX
