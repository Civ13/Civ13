// Boats for agent characters (docs/agent-control.md#boats).
//
// Agents use the same vehicles players do: a raft crafted from 10 wood logs,
// and outrigger, sail and motor boats. These procs give them what a player
// gets from the mouse and the arrow keys: board (drag yourself onto it),
// steer while driving (one tile per move, at the vehicle's own speed),
// disembark (click it while aboard) and drag cargo onto it. Fuel, engine and
// sail state are reported so a motor boat can be refuelled before it stalls.
//
// character_route plans a walk to a tile and says when deep water is in the
// way, where to launch and land, and which boats are near the launch point.

#define AGENT_ROUTE_BLOCKED 0
#define AGENT_ROUTE_DRY 1
#define AGENT_ROUTE_SHALLOW 2
#define AGENT_ROUTE_DEEP 3
#define AGENT_ROUTE_RANGE 150 // farthest goal, in tiles
#define AGENT_ROUTE_MARGIN 24 // tiles the search may stray outside the start-goal box
#define AGENT_ROUTE_NODES 40000 // tiles a search may settle
#define AGENT_ROUTE_EMBARK 40 // extra cost of putting out onto deep water, so one crossing beats several
#define AGENT_BOAT_SEARCH 12 // tiles around the launch point searched for a boat
#define AGENT_RAFT_LOGS 10

// The vehicle a character drives or rides, if any.
/proc/agent_vehicle_of(mob/living/M)
	if (!M)
		return null
	if (ishuman(M))
		var/mob/living/human/H = M
		if (H.driver_vehicle)
			return H.driver_vehicle
	if (istype(M.buckled, /obj/structure/vehicle))
		return M.buckled
	for (var/obj/structure/vehicle/V in range(1, M))
		if (M in V.ontop)
			return V
	return null

/proc/agent_is_boat(obj/structure/vehicle/V)
	return istype(V, /obj/structure/vehicle/raft) || istype(V, /obj/structure/vehicle/boat)

// Why a boat cannot be steered one tile on now, or null when it can.
/proc/agent_vehicle_stalled(obj/structure/vehicle/V)
	if (istype(V, /obj/structure/vehicle/raft))
		return null // paddled
	if (!istype(V, /obj/structure/vehicle/boat))
		return "only rafts and boats can be steered by agents"
	if (V.sails)
		return null
	if (!V.engine)
		return "this boat has no engine or sail"
	if (!V.fueltank || !V.fueltank.reagents || V.fueltank.reagents.total_volume <= 0)
		return "the fuel tank is empty: hold fuel and click the boat to refuel it"
	if (!V.engine.on)
		return "the engine is off: use the rudder in your hand once to start it"
	return null

// What an agent needs to know about a vehicle: kind, seats, cargo, fuel.
/proc/agent_vehicle_row(obj/structure/vehicle/V, mob/living/M = null)
	var/turf/T = get_turf(V)
	var/list/row = list("ref" = agent_ref(V), "name" = V.name, "type" = "[V.type]", "boat" = agent_is_boat(V) ? TRUE : FALSE)
	if (T)
		row["x"] = T.x
		row["y"] = T.y
		row["z"] = T.z
	row["health"] = V.health
	row["aboard"] = V.ontop.len
	row["seats"] = istype(V, /obj/structure/vehicle/boat) ? 2 : V.mobcapacity
	if (V.driver)
		row["driver"] = V.driver.name
	if (M)
		if (V.driver == M)
			row["role"] = "driver"
		else if (M in V.ontop)
			row["role"] = "passenger"
	if (V.storagecapacity)
		var/list/cargo = list()
		for (var/obj/O in V.ontop_o)
			cargo += O.name
		row["cargo"] = cargo
		row["cargo_space"] = max(0, V.storagecapacity - V.ontop_o.len)
	if (V.engine)
		row["engine_on"] = V.engine.on ? TRUE : FALSE
	if (V.fueltank && V.fueltank.reagents)
		row["fuel"] = round(V.fueltank.reagents.total_volume)
		row["fuel_max"] = round(V.fueltank.reagents.maximum_volume)
		if (V.engine && V.engine.fuels)
			row["fuels"] = V.engine.fuels.Copy()
	if (V.sails)
		row["sails"] = V.sails_on ? "up" : "down"
	if (V.wheeled)
		row["needs_free_hand"] = TRUE // the driver holds the rudder
	if (V.moving)
		row["moving"] = TRUE
	var/stalled = agent_vehicle_stalled(V)
	if (stalled && agent_is_boat(V))
		row["stalled"] = stalled
	return row

// Terrain class of a tile for route planning.
/proc/agent_route_kind(turf/T)
	if (!T || T.density || istype(T, /turf/floor/lava))
		return AGENT_ROUTE_BLOCKED
	var/kind = AGENT_ROUTE_DRY
	if (istype(T, /turf/floor/beach/water/ice))
		kind = AGENT_ROUTE_DRY
	else if (istype(T, /turf/floor/beach/water/deep))
		kind = T.iscovered() ? AGENT_ROUTE_DRY : AGENT_ROUTE_DEEP
	else if (istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/trench/flooded))
		kind = AGENT_ROUTE_SHALLOW
	for (var/atom/movable/AM in T)
		if (!AM.density || ismob(AM) || istype(AM, /obj/structure/vehicle))
			continue
		if (istype(AM, /obj/structure/simple_door))
			continue // doors open for whoever has the key; the walk finds out
		return AGENT_ROUTE_BLOCKED
	return kind

// Open deep water a human cannot walk into (it is fine on a raft or boat).
/proc/agent_deep_water(turf/T)
	return agent_route_kind(T) == AGENT_ROUTE_DEEP

// Cheapest route from start to within reach of goal (same z level): dry and
// shallow tiles always, deep water too when water is TRUE. Returns the turfs
// in order, or null.
/proc/agent_route_search(turf/start, turf/goal, reach = 0, water = FALSE, max_nodes = AGENT_ROUTE_NODES)
	if (!start || !goal || start.z != goal.z)
		return null
	var/x1 = max(1, min(start.x, goal.x) - AGENT_ROUTE_MARGIN)
	var/x2 = min(world.maxx, max(start.x, goal.x) + AGENT_ROUTE_MARGIN)
	var/y1 = max(1, min(start.y, goal.y) - AGENT_ROUTE_MARGIN)
	var/y2 = min(world.maxy, max(start.y, goal.y) + AGENT_ROUTE_MARGIN)
	var/list/kinds = list()
	var/list/best = list()
	var/list/parent = list()
	kinds[start] = agent_route_kind(start)
	best[start] = 0
	// Dial's algorithm: one bucket of tiles per path cost.
	var/list/buckets = list(list(start))
	var/settled = 0
	var/turf/found = null
	var/cost_now = 0
	while (!found && cost_now < buckets.len && settled < max_nodes)
		var/list/bucket = buckets[cost_now + 1]
		for (var/turf/T in bucket)
			if (best[T] != cost_now)
				continue // reached more cheaply later
			var/kind_here = kinds[T]
			if (kind_here != AGENT_ROUTE_DEEP && get_dist(T, goal) <= reach)
				found = T
				break
			if (++settled >= max_nodes)
				break
			for (var/d in cardinal)
				var/turf/N = get_step(T, d)
				if (!N || N.x < x1 || N.x > x2 || N.y < y1 || N.y > y2)
					continue
				var/kind = kinds[N]
				if (isnull(kind))
					kind = agent_route_kind(N)
					kinds[N] = kind
				if (kind == AGENT_ROUTE_BLOCKED || (kind == AGENT_ROUTE_DEEP && !water))
					continue
				var/cost = cost_now + (kind == AGENT_ROUTE_SHALLOW ? 2 : 1)
				if (kind == AGENT_ROUTE_DEEP && kind_here != AGENT_ROUTE_DEEP)
					cost += AGENT_ROUTE_EMBARK
				var/known = best[N]
				if (!isnull(known) && known <= cost)
					continue
				best[N] = cost
				parent[N] = T
				while (buckets.len < cost + 1)
					buckets += list(list())
				var/list/into = buckets[cost + 1]
				into += N
		buckets[cost_now + 1] = null // settled; free it
		cost_now++
	if (!found)
		return null
	var/list/path = list()
	var/turf/at = found
	while (at)
		path.Insert(1, at)
		at = parent[at]
	return path

/proc/agent_dir_letter(d)
	switch (d)
		if (NORTH)
			return "n"
		if (SOUTH)
			return "s"
		if (EAST)
			return "e"
		if (WEST)
			return "w"
	return "?"

// A path split into walking and boat legs. A boat leg is every move into a run
// of water tiles that holds deep water, so a raft launched from the last dry
// tile takes over before the water gets deep and lands on the first dry tile.
/proc/agent_route_legs(list/path)
	var/list/kinds = list()
	for (var/turf/T in path)
		kinds += agent_route_kind(T)
	var/list/boat = list()
	boat.len = path.len
	var/i = 1
	while (i <= path.len)
		if (kinds[i] == AGENT_ROUTE_DRY)
			boat[i] = FALSE
			i++
			continue
		var/j = i
		var/deep = FALSE
		while (j <= path.len && kinds[j] != AGENT_ROUTE_DRY)
			if (kinds[j] == AGENT_ROUTE_DEEP)
				deep = TRUE
			j++
		for (var/k = i, k < j, k++)
			boat[k] = deep
		i = j
	var/list/legs = list()
	var/list/leg = null
	for (var/k = 2, k <= path.len, k++)
		var/turf/prev = path[k - 1]
		var/turf/step_to = path[k]
		var/mode = boat[k] ? "boat" : "walk"
		if (!leg || leg["mode"] != mode)
			leg = list("mode" = mode, "from" = list(prev.x, prev.y), "first" = list(step_to.x, step_to.y), "moves" = "")
			legs += list(leg)
		leg["moves"] += agent_dir_letter(get_dir(prev, step_to))
		leg["to"] = list(step_to.x, step_to.y)
	return legs

// Boats near a launch point that the character could take, nearest first,
// each with a dry tile to board from.
/proc/agent_boats_near(turf/launch, mob/living/M, radius = AGENT_BOAT_SEARCH)
	var/list/rows = list()
	if (!launch)
		return rows
	var/list/seen = list()
	for (var/obj/structure/vehicle/V in range(radius, launch))
		if (!agent_is_boat(V) || seen[V])
			continue
		seen[V] = TRUE
		if (V.driver && V.driver != M)
			continue
		var/turf/stand = null
		for (var/turf/T in range(1, V))
			var/kind = agent_route_kind(T)
			if (kind == AGENT_ROUTE_DEEP || kind == AGENT_ROUTE_BLOCKED)
				continue
			if (!stand || get_dist(T, launch) < get_dist(stand, launch))
				stand = T
		if (!stand)
			continue
		var/list/row = agent_vehicle_row(V, M)
		row["board_from"] = list(stand.x, stand.y)
		row["distance"] = get_dist(V, launch)
		rows += list(row)
	// Insertion sort by distance; the list is short.
	for (var/a = 2, a <= rows.len, a++)
		var/b = a
		while (b > 1 && rows[b - 1]["distance"] > rows[b]["distance"])
			rows.Swap(b - 1, b)
			b--
	if (rows.len > 5)
		rows.Cut(6)
	return rows

/datum/agent_control/proc/act_character_route(datum/agent_identity/A, list/req)
	var/datum/agent_character/C = character_arg(A, req)
	var/mob/living/M = C.body
	var/turf/start = get_turf(M)
	if (!start)
		agent_fail("no_position", "the character is not on the map")
	var/turf/goal = null
	if (!isnull(req["target"]))
		var/atom/target = agent_resolve_target(req["target"])
		goal = isatom(target) ? get_turf(target) : null
	else
		var/x = text2num("[req["x"]]")
		var/y = text2num("[req["y"]]")
		if (!isnum(x) || !isnum(y))
			agent_fail("bad_args", "give target, or x and y")
		goal = locate(clamp(round(x), 1, world.maxx), clamp(round(y), 1, world.maxy), start.z)
	if (!goal || goal.z != start.z)
		agent_fail("bad_target", "the goal must be on the character's z level")
	if (get_dist(start, goal) > AGENT_ROUTE_RANGE)
		agent_fail("too_far", "plan at most [AGENT_ROUTE_RANGE] tiles ahead; travel part of the way first")
	var/reach = text2num("[req["reach"]]")
	if (!isnum(reach))
		var/goal_kind = agent_route_kind(goal)
		reach = (goal_kind == AGENT_ROUTE_DRY || goal_kind == AGENT_ROUTE_SHALLOW) ? 0 : 1
	reach = clamp(round(reach), 0, 5)
	audit_read(A, "character_route", "[M] ([agent_ref(M)]) to [goal.x],[goal.y],[goal.z]")
	var/list/out = list("from" = list(start.x, start.y, start.z), "goal" = list(goal.x, goal.y, goal.z), "reach" = reach)
	var/obj/structure/vehicle/aboard = agent_vehicle_of(M)
	if (aboard)
		out["aboard"] = agent_vehicle_row(aboard, M)
	var/list/path = null
	if (agent_route_kind(start) != AGENT_ROUTE_DEEP)
		path = agent_route_search(start, goal, reach, FALSE)
	if (path)
		out["reachable"] = TRUE
		out["needs_boat"] = FALSE
	else
		path = agent_route_search(start, goal, reach, TRUE)
		if (!path)
			out["reachable"] = FALSE
			out["needs_boat"] = FALSE
			out["reason"] = "no way there by land or water within [AGENT_ROUTE_MARGIN] tiles of the straight line"
			return out
		out["reachable"] = TRUE
		out["needs_boat"] = TRUE
	var/list/legs = agent_route_legs(path)
	out["legs"] = legs
	out["length"] = path.len - 1
	var/turf/end = path[path.len]
	out["to"] = list(end.x, end.y)
	if (out["needs_boat"])
		var/list/first_boat = null
		var/crossings = 0
		for (var/list/leg in legs)
			if (leg["mode"] == "boat")
				crossings++
				if (!first_boat)
					first_boat = leg
		out["crossings"] = crossings
		if (first_boat)
			var/list/launch_xy = first_boat["from"]
			var/turf/launch = locate(launch_xy[1], launch_xy[2], start.z)
			out["launch"] = launch_xy
			var/list/landing = null
			var/index = legs.Find(first_boat)
			if (index && index < legs.len)
				var/list/after = legs[index + 1]
				landing = after["first"]
			out["landing"] = landing
			out["water_tiles"] = length(first_boat["moves"])
			out["boats"] = agent_boats_near(launch, M)
			out["raft"] = list("recipe" = "raft", "material" = "wood logs", "amount" = AGENT_RAFT_LOGS, "build_at" = launch_xy)
	return out

// ---------------------------------------------------------------------------
// Character steps (called from perform_step in agent_characters.dm).
// Boarding, getting off and dragging are timed (do_after), so they run only
// from character_queue, where a step may wait; a direct call is refused.

/proc/agent_queue_only(action, from_queue)
	if (!from_queue)
		agent_fail("use_queue", "[action] takes time: send it with character_queue")

// One tile of steering while driving. Rafts are paddled; sail boats sail; a
// motor boat needs its engine running. A boat whose engine is in gear moves
// by itself, so steering only turns it.
/datum/agent_control/proc/agent_drive_step(datum/agent_identity/A, datum/agent_character/C, obj/structure/vehicle/V, d)
	var/mob/living/M = C.body
	if (!(d in cardinal))
		agent_fail("bad_args", "boats steer north, south, east or west")
	if (M.stat != CONSCIOUS || M.restrained())
		agent_fail("cannot_move", "the character cannot steer right now")
	var/stalled = agent_vehicle_stalled(V)
	if (stalled)
		agent_fail("no_propulsion", stalled)
	var/turf/old = get_turf(V)
	M.dir = d
	V.dir = d
	V.updatepassdir()
	V.update_icon()
	if (V.moving)
		C.next_action = world.time + 2
		game_log("AGENT", "[A.name] steered [V] [dir2text(d)] as [M] ([agent_ref(M)])")
		return list("moved" = TRUE, "steered" = TRUE, "self" = character_state(C))
	V.processmove(d)
	var/moved = get_turf(V) != old
	C.next_action = world.time + max(2, V.vehicle_m_delay + 1)
	game_log("AGENT", "[A.name] steered [V] [dir2text(d)] as [M] ([agent_ref(M)]) [moved ? "moved" : "blocked"] from [old.x],[old.y],[old.z]")
	return list("moved" = moved ? TRUE : FALSE, "self" = character_state(C))

/datum/agent_control/proc/agent_board(datum/agent_character/C, list/req, from_queue)
	agent_queue_only("board", from_queue)
	var/mob/living/human/H = C.body
	if (!ishuman(H))
		agent_fail("bad_type", "only humans can board boats")
	var/obj/structure/vehicle/V = agent_resolve_target(req["target"])
	if (!istype(V) || !agent_is_boat(V))
		agent_fail("bad_target", "board a raft or a boat")
	if (!(V in range(1, H)))
		agent_fail("out_of_reach", "stand next to \the [V] first")
	if (agent_vehicle_of(H))
		agent_fail("aboard", "already aboard \the [agent_vehicle_of(H)]")
	if (H.stat != CONSCIOUS || H.restrained() || H.buckled || H.anchored)
		agent_fail("cannot_move", "the character cannot climb aboard right now")
	if (V.ontop.len >= (istype(V, /obj/structure/vehicle/boat) ? 2 : V.mobcapacity))
		agent_fail("full", "\the [V] is full")
	if (V.wheeled && !V.driver && H.get_active_hand())
		if (H.get_inactive_hand())
			agent_fail("hands_full", "the driver holds the rudder: free a hand first")
		H.swap_hand()
	C.next_action = world.time + 5
	V.MouseDrop_T(H, H)
	if (!(H in V.ontop))
		agent_fail("not_boarded", "could not get on \the [V] (moved or interrupted)")
	return "[V] ([agent_ref(V)])"

/datum/agent_control/proc/agent_disembark(datum/agent_character/C, from_queue)
	agent_queue_only("disembark", from_queue)
	var/mob/living/M = C.body
	var/obj/structure/vehicle/V = agent_vehicle_of(M)
	if (!V)
		agent_fail("not_aboard", "the character is not on a vehicle")
	if (V.moving && V.driver == M)
		agent_fail("moving", "stop the boat first (its engine is in gear)")
	C.next_action = world.time + 5
	V.attack_hand(M)
	if (agent_vehicle_of(M) == V)
		agent_fail("still_aboard", "could not get off \the [V] (interrupted)")
	return "[V] ([agent_ref(V)])"

// Drag one thing onto another, as a player does with the mouse: yourself onto
// a boat, a crate onto a boat's deck, an engine onto a boat frame.
/datum/agent_control/proc/agent_drag(datum/agent_character/C, list/req, from_queue)
	agent_queue_only("drag", from_queue)
	var/mob/living/M = C.body
	var/atom/movable/dragged = agent_resolve_target(req["target"])
	var/atom/onto = agent_resolve_target(req["onto"])
	if (!istype(dragged) || !isatom(onto))
		agent_fail("bad_target", "drag needs a target and something to drag it onto")
	if (ismob(dragged) && dragged != M)
		agent_fail("bad_target", "only yourself or objects can be dragged")
	if (M.incapacitated())
		agent_fail("cannot_move", "the character cannot drag things right now")
	if ((dragged != M && !dragged.Adjacent(M)) || !onto.Adjacent(M))
		agent_fail("out_of_reach", "both things must be next to the character")
	C.next_action = world.time + 5
	onto.MouseDrop_T(dragged, M)
	return "[dragged] onto [onto]"

#undef AGENT_ROUTE_BLOCKED
#undef AGENT_ROUTE_DRY
#undef AGENT_ROUTE_SHALLOW
#undef AGENT_ROUTE_DEEP
