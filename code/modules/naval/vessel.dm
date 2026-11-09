// Turf-built vessels: ships too large for the modular vehicle system (which
// caps a vehicle at 25 frames). A vessel is a template of cells on one or more
// stacked levels, written onto the map as turfs. It sails by hopping: every
// VESSEL_HOP_INTERVAL the whole block moves along its heading, carrying
// everything standing on it, and the sea it left is put back.
//
// The submarine module's hull, bulkhead and deck turfs do the damage control;
// each vessel owns one flooding controller (flooding_controller.dm), found
// from a deck tile through vessel_at().

var/global/list/naval_vessels = list()

// The vessel whose footprint holds T on T's level, or null.
/proc/vessel_at(turf/T)
	if (!T)
		return null
	for (var/datum/vessel/V in naval_vessels)
		if (V.contains(T))
			return V
	return null

// One deck: a grid of template characters, `length` columns (stern to bow)
// by `beam` rows (port to starboard), on one z-level. '.' is not part of the
// ship. The legend maps each other character to its turf type and the
// structures spawned on it.
/datum/vessel_level
	var/z = 0
	var/dz = 0                 // Level offset from the vessel's base level.
	var/list/rows = list()     // beam strings of length characters.
	var/list/legend = list()   // char -> list("turf" = type, "spawn" = list of types)
	var/list/originals = list() // "x,y" -> the turf type found before the ship arrived.
	var/list/allowed = list()  // Turf types the ship may move onto.

/datum/vessel_level/proc/spec_at(u, v)
	if (v < 0 || v >= rows.len)
		return null
	var/row = rows[v + 1]
	if (u < 0 || u >= length(row))
		return null
	var/c = copytext(row, u + 1, u + 2)
	if (c == ".")
		return null
	return legend[c]

/datum/vessel
	var/name = "vessel"
	var/length = 1             // Along the bow axis.
	var/beam = 1               // Across.
	var/dir = EAST             // Where the bow points: a cardinal direction.
	var/ox = 0                 // South-west corner of the footprint's bounding box.
	var/oy = 0
	var/base_z = 0             // The level of dz = 0 (the surface deck).
	var/list/levels = list()   // /datum/vessel_level
	var/datum/flooding_controller/flooding
	var/placed = FALSE
	var/speed = VESSEL_SPEED_STOP
	var/anchored = TRUE
	// Fuel oil in the bunkers; every hop burns VESSEL_FUEL_PER_STEP per step.
	var/fuel = 0
	var/fuel_capacity = VESSEL_FUEL_CAPACITY
	// Flooding lists the ship: each flooded compartment takes a telegraph
	// step off her (recomputed every second by damage_tick()).
	var/max_speed = VESSEL_SPEED_FULL
	var/sunk = FALSE
	var/deck_lights_on = TRUE
	var/hop_timer = 0
	var/last_hop_ms = 0        // Wall time the last relocation took, for the probe.
	var/last_refusal = ""
	var/tmp/relocating = FALSE

/datum/vessel/New()
	..()
	naval_vessels += src
	flooding = new /datum/flooding_controller(src)

/datum/vessel/Destroy()
	stop_sailing()
	naval_vessels -= src
	if (flooding)
		global.flooding_controllers -= flooding
		flooding = null
	return ..()

// Whether a breached compartment lets its air out. A hangar deck below the
// waterline keeps its pocket like a submerged hull.
/datum/vessel/proc/breaches_vent()
	return FALSE

// ---- Geometry ----

// Bounding box width and height for the current heading.
/datum/vessel/proc/box_w()
	return (dir == EAST || dir == WEST) ? length : beam

/datum/vessel/proc/box_h()
	return (dir == EAST || dir == WEST) ? beam : length

// World offset of ship cell (u, v) for a heading, relative to the box corner.
// Port (v = 0) is to the left of the bow.
/datum/vessel/proc/cell_dx(u, v, heading)
	switch (heading)
		if (EAST) return u
		if (WEST) return length - 1 - u
		if (NORTH) return v
		if (SOUTH) return beam - 1 - v
	return u

/datum/vessel/proc/cell_dy(u, v, heading)
	switch (heading)
		if (EAST) return beam - 1 - v
		if (WEST) return v
		if (NORTH) return u
		if (SOUTH) return length - 1 - u
	return v

// Inverse of cell_dx/cell_dy.
/datum/vessel/proc/cell_u(dx, dy, heading)
	switch (heading)
		if (EAST) return dx
		if (WEST) return length - 1 - dx
		if (NORTH) return dy
		if (SOUTH) return length - 1 - dy
	return dx

/datum/vessel/proc/cell_v(dx, dy, heading)
	switch (heading)
		if (EAST) return beam - 1 - dy
		if (WEST) return dy
		if (NORTH) return dx
		if (SOUTH) return beam - 1 - dx
	return dy

/datum/vessel/proc/level_for_z(z)
	for (var/datum/vessel_level/L in levels)
		if (L.z == z)
			return L
	return null

/datum/vessel/proc/contains(turf/T)
	if (!placed || !T)
		return FALSE
	var/datum/vessel_level/L = level_for_z(T.z)
	if (!L)
		return FALSE
	return L.spec_at(cell_u(T.x - ox, T.y - oy, dir), cell_v(T.x - ox, T.y - oy, dir)) != null

// The world turf of ship cell (u, v) on level L at a given box corner and heading.
/datum/vessel/proc/cell_turf(datum/vessel_level/L, u, v, x, y, heading)
	return locate(x + cell_dx(u, v, heading), y + cell_dy(u, v, heading), L.z)

// Every turf of the ship as it stands.
/datum/vessel/proc/cells()
	. = list()
	if (!placed)
		return
	for (var/datum/vessel_level/L in levels)
		for (var/v = 0, v < beam, v++)
			for (var/u = 0, u < length, u++)
				if (!L.spec_at(u, v))
					continue
				var/turf/T = cell_turf(L, u, v, ox, oy, dir)
				if (T)
					. += T

/datum/vessel/proc/deck_turfs()
	. = list()
	for (var/turf/floor/sub_deck/T in cells())
		. += T

/datum/vessel/proc/crew()
	. = list()
	for (var/turf/T in cells())
		for (var/mob/living/M in T)
			. += M

/datum/vessel/proc/crew_message(text)
	for (var/mob/living/M in crew())
		if (M.client)
			to_chat(M, text)

// ---- Placement ----

// Lays the ship down with its box corner at (x, y) on level z, bow to heading.
// Returns TRUE, or FALSE with the reason in last_refusal.
/datum/vessel/proc/place(x, y, z, heading = EAST)
	if (placed)
		last_refusal = "already afloat"
		return FALSE
	if (!assign_levels(z))
		return FALSE
	return relocate(x, y, heading)

// Gives each deck its level around surface level z.
/datum/vessel/proc/assign_levels(z)
	base_z = z
	for (var/datum/vessel_level/L in levels)
		var/lz = L.dz ? (L.dz > 0 ? multiz_level_above(z) : multiz_level_below(z)) : z
		if (!lz)
			last_refusal = "no level [L.dz > 0 ? "above" : "below"] the surface for deck [L.dz]"
			return FALSE
		L.z = lz
	return TRUE

// Whether an unplaced ship could be laid down with its box corner at (x, y)
// on level z, bow to heading, without writing anything. The reason it could
// not is in last_refusal.
/datum/vessel/proc/fits(x, y, z, heading = EAST)
	if (placed)
		last_refusal = "already afloat"
		return FALSE
	if (!assign_levels(z))
		return FALSE
	return plan_move(x, y, heading, list(), list(), list())

// Takes the ship off the map, putting back what was under it. Whatever stood
// on it is left where it was.
/datum/vessel/proc/remove()
	if (!placed)
		return
	stop_sailing()
	var/list/old_cells = cells()
	for (var/turf/floor/sub_deck/T in old_cells)
		flooding.unregister_turf(T)
	placed = FALSE
	var/old_bulk = wall_bulk_placement
	wall_bulk_placement = TRUE
	for (var/turf/T in old_cells)
		var/datum/vessel_level/L = level_for_z(T.z)
		var/original = L ? L.originals["[T.x],[T.y]"] : null
		if (original)
			T.ChangeTurf(original)
	wall_bulk_placement = old_bulk
	for (var/datum/vessel_level/L in levels)
		L.originals = list()

// Checks every destination cell of a move to (x, y, heading) and fills
// dest_turfs (turf -> spec) and dest_source (turf -> the cell it comes from,
// or null for a cell the ship did not cover). Cells in old_cells are the
// ship's own and need no terrain check. Returns FALSE with last_refusal set.
/datum/vessel/proc/plan_move(x, y, heading, list/old_cells, list/dest_turfs, list/dest_source)
	for (var/datum/vessel_level/L in levels)
		for (var/v = 0, v < beam, v++)
			for (var/u = 0, u < length, u++)
				var/list/spec = L.spec_at(u, v)
				if (!spec)
					continue
				var/turf/D = cell_turf(L, u, v, x, y, heading)
				if (!D)
					last_refusal = "the edge of the world"
					return FALSE
				if (!(D in old_cells))
					var/allowed = FALSE
					for (var/path in L.allowed)
						if (istype(D, path))
							allowed = TRUE
							break
					if (!allowed)
						last_refusal = "[D.name] ahead at [D.x],[D.y]"
						return FALSE
					for (var/atom/movable/M in D)
						if (M.loc == D && M.density && !istype(M, /atom/movable/lighting_overlay))
							last_refusal = "[M.name] in the way at [D.x],[D.y]"
							return FALSE
				dest_turfs[D] = spec
				dest_source[D] = placed ? cell_turf(L, u, v, ox, oy, dir) : null
	return TRUE

// Moves the block so its box corner is at (x, y) with the bow to heading.
// Refuses, leaving the ship where it is, when any destination tile is missing,
// is not water, sea or sky the ship may use, or holds something solid that is
// not ours. One call does the whole move and never sleeps, so nobody sees a
// half-moved ship.
/datum/vessel/proc/relocate(x, y, heading)
	if (relocating)
		last_refusal = "already moving"
		return FALSE
	var/started = world.timeofday
	var/list/old_cells = placed ? cells() : list()
	// Destinations with the spec that goes there and the cell it comes from.
	var/list/dest_turfs = list()
	var/list/dest_source = list()
	if (!plan_move(x, y, heading, old_cells, dest_turfs, dest_source))
		return FALSE
	relocating = TRUE
	var/old_bulk = wall_bulk_placement
	wall_bulk_placement = TRUE
	try
		// What each old cell carries and how damaged it is, keyed by position.
		var/list/states = list()
		var/list/cargo = list()
		for (var/turf/S in old_cells)
			states[S] = S.vessel_capture()
			var/list/aboard = list()
			for (var/atom/movable/M in S)
				if (M.loc != S || QDELETED(M))
					continue
				if (istype(M, /atom/movable/lighting_overlay) || istype(M, /atom/movable/lighting_fullbright))
					continue
				aboard += M
			cargo[S] = aboard
		// What lay under the ship before, per level, and what lies under the
		// new footprint: cells the ship keeps covering carry their record over.
		var/list/prior = list()
		var/list/next = list()
		for (var/datum/vessel_level/L in levels)
			prior[L] = L.originals
			next[L] = list()
		for (var/turf/D in dest_turfs)
			var/datum/vessel_level/L = level_for_z(D.z)
			var/list/mine = next[L]
			var/list/was = prior[L]
			var/key = "[D.x],[D.y]"
			mine[key] = (D in old_cells) ? was[key] : D.type
		var/list/air = flooding.air_snapshot()
		// The ship now stands at the new place: vessel_at() must find it from
		// the constructors of the turfs written below.
		ox = x
		oy = y
		dir = heading
		placed = TRUE
		for (var/datum/vessel_level/L in levels)
			L.originals = next[L]
		// Write the decks.
		var/list/moved_to = list()
		for (var/turf/D in dest_turfs)
			var/list/spec = dest_turfs[D]
			var/turf/S = dest_source[D]
			var/turf/N = D.ChangeTurf(spec["turf"])
			if (!N)
				N = D
			if (S)
				if (states[S])
					N.vessel_restore(states[S])
				moved_to[N] = S
			else if (spec["spawn"])
				for (var/path in spec["spawn"])
					new path(N)
		// Carry everything across. Turf references are positional, so the
		// cargo lists were taken before any turf changed.
		for (var/turf/N in moved_to)
			var/turf/S = moved_to[N]
			if (S == N)
				continue
			for (var/atom/movable/M in cargo[S])
				if (QDELETED(M) || M.loc != S)
					continue
				M.forceMove(N)
		// Put the sea back where the ship was.
		for (var/turf/S in old_cells)
			if (S in dest_turfs)
				continue
			var/datum/vessel_level/L = level_for_z(S.z)
			var/list/was = L ? prior[L] : null
			var/original = was ? was["[S.x],[S.y]"] : null
			if (original)
				S.ChangeTurf(original)
		flooding.rebind_turfs(deck_turfs(), air)
		for (var/turf/N in moved_to)
			for (var/obj/O in N)
				O.update_icon()
	catch (var/exception/e)
		relocating = FALSE
		wall_bulk_placement = old_bulk
		throw e
	wall_bulk_placement = old_bulk
	relocating = FALSE
	last_hop_ms = (world.timeofday - started) * 100
	return TRUE

// ---- Sailing ----

/datum/vessel/proc/start_sailing()
	if (hop_timer)
		return
	hop_timer = addtimer(CALLBACK(src, PROC_REF(sail_tick)), VESSEL_HOP_INTERVAL, TIMER_LOOP | TIMER_STOPPABLE)

/datum/vessel/proc/stop_sailing()
	if (hop_timer)
		deltimer(hop_timer)
		hop_timer = 0

/datum/vessel/proc/set_speed(new_speed)
	speed = clamp(new_speed, VESSEL_SPEED_STOP, max_speed)
	if (speed > 0 && !anchored)
		start_sailing()

/datum/vessel/proc/set_anchor(down)
	anchored = down
	if (!anchored && speed > 0)
		start_sailing()

// One hop along the heading. Returns TRUE when the ship moved.
/datum/vessel/proc/sail_tick()
	if (!placed || anchored || speed <= 0)
		return FALSE
	// Never rewrite a level while the world save is capturing it.
	if (persistence_save_in_progress)
		return FALSE
	var/burn = speed * VESSEL_FUEL_PER_STEP
	if (fuel < burn)
		last_refusal = "the bunkers are dry"
		crew_message(SPAN_WARNING("<b>All stop!</b> The bunkers are dry."))
		speed = VESSEL_SPEED_STOP
		stop_sailing()
		return FALSE
	var/step = speed * VESSEL_TILES_PER_STEP
	// A blocked full step tries shorter ones, so the ship closes up to an
	// obstacle instead of stopping short of it.
	for (var/tiles = step, tiles >= 1, tiles--)
		var/sx = 0
		var/sy = 0
		switch (dir)
			if (EAST) sx = tiles
			if (WEST) sx = -tiles
			if (NORTH) sy = tiles
			if (SOUTH) sy = -tiles
		if (relocate(ox + sx, oy + sy, dir))
			fuel -= burn
			return TRUE
	crew_message(SPAN_WARNING("<b>All stop!</b> [capitalize(last_refusal)]."))
	speed = VESSEL_SPEED_STOP
	stop_sailing()
	return FALSE

// Turning swaps the long axis of the footprint about the box centre; the new
// box must be clear like any other move.
/datum/vessel/proc/turn_to(heading)
	if (heading == dir)
		return TRUE
	var/cx = ox + (box_w() - 1) / 2
	var/cy = oy + (box_h() - 1) / 2
	var/old_dir = dir
	dir = heading
	var/nx = round(cx - (box_w() - 1) / 2)
	var/ny = round(cy - (box_h() - 1) / 2)
	dir = old_dir
	return relocate(nx, ny, heading)

// Switches every deck light aboard.
/datum/vessel/proc/set_deck_lights(state)
	deck_lights_on = state
	for (var/turf/T in cells())
		for (var/obj/structure/lamp/lamp_small/alwayson/deck/L in T)
			L.lit = state
			L.do_light()

// ---- Damage control ----

// The compartments the decks below the waterline are divided into.
/datum/vessel/proc/compartments()
	. = list()
	if (!flooding)
		return
	for (var/cid in flooding.compartment_turfs)
		if (cid)
			. += cid

/datum/vessel/proc/flooded_compartments()
	. = 0
	for (var/cid in compartments())
		if (flooding.is_compartment_flooded(cid))
			.++

/datum/vessel/proc/sink_threshold()
	return VESSEL_SINK_COMPARTMENTS

// Called every second by the ship's flooding controller: the list grows
// with each flooded compartment, and at the threshold the ship goes down.
/datum/vessel/proc/damage_tick()
	if (!placed || sunk)
		return
	var/flooded = flooded_compartments()
	var/cap = max(VESSEL_SPEED_STOP, VESSEL_SPEED_FULL - flooded)
	if (cap != max_speed)
		var/list/speeds = list("all stop", "slow ahead", "half ahead", "full ahead")
		max_speed = cap
		if (flooded)
			crew_message(SPAN_WARNING("<b>The ship lists</b> with [flooded] compartment\s flooded: [speeds[cap + 1]] is all she will make."))
		else
			crew_message(SPAN_NOTICE("The ship rides level again."))
		if (speed > max_speed)
			speed = max_speed
			if (speed <= 0)
				stop_sailing()
	if (flooded >= sink_threshold())
		sink()

// The ship goes down. Fittings (anchored structures) and vehicles are lost
// with her; crew and loose cargo on the lower decks come up to the surface
// water above them, those on the upper decks fall to it, and those on the
// surface deck find themselves swimming where the deck was. Wreckage floats
// where she sank; the sea, rock and sky come back as for remove().
/datum/vessel/proc/sink()
	if (sunk || !placed)
		return
	sunk = TRUE
	crew_message(SPAN_DANGER("<b>Abandon ship!</b> [capitalize(name)] is going down!"))
	stop_sailing()
	var/list/surface = list()
	var/list/swimmers = list()
	for (var/turf/T in cells())
		if (T.z == base_z)
			surface += T
		var/turf/above = T.z == base_z ? T : locate(T.x, T.y, base_z)
		for (var/atom/movable/M in T)
			if (M.loc != T || QDELETED(M) || istype(M, /atom/movable/lighting_overlay) || istype(M, /atom/movable/lighting_fullbright))
				continue
			if (istype(M, /obj/structure/vehicleparts) || istype(M, /obj/effect/pseudovehicle))
				// The controls sit inside a frame: take them down with it.
				if (istype(M, /obj/structure/vehicleparts/frame))
					var/obj/structure/vehicleparts/frame/F = M
					if (F.axis && !QDELETED(F.axis))
						qdel(F.axis)
				qdel(M)
				continue
			if (istype(M, /obj/structure))
				var/obj/structure/S = M
				if (S.anchored || S.not_movable)
					qdel(S)
					continue
			if (isliving(M))
				swimmers += M
			if (above && above != T)
				M.forceMove(above)
	remove()
	var/wreckage = 0
	for (var/turf/T in shuffle(surface))
		if (wreckage >= 5)
			break
		if (istype(T, /turf/floor/beach/water))
			var/obj/structure/barricade/debris/D = new(T)
			D.name = "wreckage of the [name]"
			D.desc = "Splintered decking and twisted plating, all that floats of \the [name]."
			D.density = FALSE
			wreckage++
	for (var/mob/living/M in swimmers)
		if (M.client)
			to_chat(M, SPAN_DANGER("The sea closes over the decks and you are in the water."))
	qdel(src)

// Takes fuel oil into the bunkers; returns how much was taken.
/datum/vessel/proc/bunker(amount)
	var/taken = clamp(amount, 0, fuel_capacity - fuel)
	fuel += taken
	return taken

/datum/vessel/proc/hops_of_fuel()
	if (speed <= 0)
		return fuel >= VESSEL_FUEL_PER_STEP ? round(fuel / VESSEL_FUEL_PER_STEP) : 0
	return round(fuel / (speed * VESSEL_FUEL_PER_STEP))

// The first thing the surface deck would meet ahead of the bow within
// VESSEL_CHART_RANGE tiles, as "name, N tiles ahead", or null for open sea.
/datum/vessel/proc/ahead_text()
	if (!placed)
		return null
	var/datum/vessel_level/L = level_for_z(base_z)
	if (!L)
		return null
	var/dx = 0
	var/dy = 0
	switch (dir)
		if (EAST) dx = 1
		if (WEST) dx = -1
		if (NORTH) dy = 1
		if (SOUTH) dy = -1
	for (var/tiles = 1, tiles <= VESSEL_CHART_RANGE, tiles++)
		for (var/v = 0, v < beam, v++)
			var/u = length - 1
			if (!L.spec_at(u, v))
				continue
			var/turf/bow = cell_turf(L, u, v, ox, oy, dir)
			if (!bow)
				continue
			var/turf/T = locate(bow.x + dx * tiles, bow.y + dy * tiles, bow.z)
			if (!T)
				return "the edge of the world, [tiles] tile\s ahead"
			var/allowed = FALSE
			for (var/path in L.allowed)
				if (istype(T, path))
					allowed = TRUE
					break
			if (!allowed)
				return "[T.name], [tiles] tile\s ahead"
			for (var/atom/movable/M in T)
				if (M.loc == T && M.density && !istype(M, /atom/movable/lighting_overlay))
					return "[M.name], [tiles] tile\s ahead"
	return null

// The chart and telegraph read at the helm.
/datum/vessel/proc/chart_text()
	var/list/speeds = list("all stop", "slow ahead", "half ahead", "full ahead")
	var/list/lines = list()
	lines += "[capitalize(name)] at [ox + round((box_w() - 1) / 2)], [oy + round((box_h() - 1) / 2)], bow to the [dir2text(dir)], [speeds[speed + 1]], anchor [anchored ? "down" : "up"]."
	lines += "Bunkers: [fuel] of [fuel_capacity] units of fuel oil, [hops_of_fuel()] hop\s at [speed > 0 ? speeds[speed + 1] : "slow ahead"]."
	var/ahead = ahead_text()
	lines += ahead ? "Ahead: [ahead]." : "Ahead: open sea for [VESSEL_CHART_RANGE] tiles."
	var/list/comps = compartments()
	if (comps.len)
		var/flooded = flooded_compartments()
		lines += "Damage control: [flooded] of [comps.len] compartments flooded[flooded ? ", the ship lists and [speeds[max_speed + 1]] is all she will make; [sink_threshold()] flooded sinks her" : ""]."
	if (last_refusal)
		lines += "Last refusal: [last_refusal]."
	return jointext(lines, "<br>")

// ---- Saved state ----

// Everything a world save needs to bring the ship back: its type, place,
// telegraph and fuel, and what lay under each cell. The decks themselves are
// saved as turfs; the helm keeps this text and rebuilds the datum on load.
/datum/vessel/proc/save_state()
	var/list/state = list("type" = "[type]", "ox" = ox, "oy" = oy, "base_z" = base_z, "dir" = dir, "speed" = speed, "anchored" = anchored, "fuel" = fuel, "deck_lights" = deck_lights_on)
	var/list/decks = list()
	for (var/datum/vessel_level/L in levels)
		var/list/originals = list()
		for (var/key in L.originals)
			originals[key] = "[L.originals[key]]"
		decks += list(list("dz" = L.dz, "originals" = originals))
	state["decks"] = decks
	return json_encode(state)

// Rebuilds a placed vessel from save_state() text over decks that are already
// on the map, or returns null when the text is unusable.
/proc/vessel_restore_state(text)
	if (!text)
		return null
	var/list/state = json_decode(text)
	if (!islist(state))
		return null
	var/path = text2path(state["type"])
	if (!ispath(path, /datum/vessel))
		return null
	var/datum/vessel/V = new path
	V.ox = state["ox"]
	V.oy = state["oy"]
	V.base_z = state["base_z"]
	V.dir = state["dir"]
	V.speed = state["speed"]
	V.anchored = state["anchored"]
	V.fuel = state["fuel"]
	if (!isnull(state["deck_lights"]))
		V.deck_lights_on = state["deck_lights"]
	var/list/decks = state["decks"]
	for (var/datum/vessel_level/L in V.levels)
		L.z = V.base_z + L.dz
		L.originals = list()
		for (var/list/deck in decks)
			if (deck["dz"] != L.dz)
				continue
			var/list/originals = deck["originals"]
			for (var/key in originals)
				var/original = text2path(originals[key])
				if (original)
					L.originals[key] = original
	V.placed = TRUE
	// The deck tiles registered with whatever controller they found while
	// loading; they are the ship's now.
	for (var/turf/floor/sub_deck/T in V.deck_turfs())
		if (T.flooding_owner && T.flooding_owner != V.flooding)
			T.flooding_owner.unregister_turf(T)
	V.flooding.rebind_turfs(V.deck_turfs(), list())
	if (V.speed > 0 && !V.anchored)
		V.start_sailing()
	return V

// ---- Turf state carried across a hop ----

/turf/proc/vessel_capture()
	return null

/turf/proc/vessel_restore(list/state)
	return

/turf/wall/sub_hull/vessel_capture()
	return list("integrity" = hull_integrity, "breached" = breached, "shored" = shored, "inflow" = breach_inflow_rate)

/turf/wall/sub_hull/vessel_restore(list/state)
	hull_integrity = state["integrity"]
	breached = state["breached"]
	shored = state["shored"]
	breach_inflow_rate = state["inflow"]
	if (breached)
		overlays += image(icon = 'icons/obj/machines/submarine.dmi', icon_state = "breach_glow")

/turf/wall/sub_bulkhead/vessel_capture()
	return list("health" = health, "watertight" = watertight)

/turf/wall/sub_bulkhead/vessel_restore(list/state)
	health = state["health"]
	watertight = state["watertight"]
	if (health <= 0)
		icon_state = "damaged"

/turf/floor/sub_deck/vessel_capture()
	return list("water" = water_depth, "inflow" = water_inflow_rate, "fire" = fire_active, "fire_temperature" = fire_temperature, "fire_duration" = fire_duration)

/turf/floor/sub_deck/vessel_restore(list/state)
	water_depth = state["water"]
	water_inflow_rate = state["inflow"]
	fire_active = state["fire"]
	fire_temperature = state["fire_temperature"]
	fire_duration = state["fire_duration"]
	if (water_depth > 0)
		refresh_water_overlay()
