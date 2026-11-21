// ============================================================
// Driving a carriage over a shared map edge (docs/americas-regions.md)
// ------------------------------------------------------------
// A carriage whose team has reached the border of a land that carries on
// (region_edge.dm) cannot step further; its driver is asked instead. On a
// yes the driver gets down and leaves as an ordinary region traveller, and
// the carriage goes in their payload as a record: its type and condition, the
// team in harness (kind, name, health) and the crates on its seats with what
// is shut inside them. The far side builds it a few tiles in, facing inland,
// team harnessed and crates loaded, and the driver climbs back up.
//
// Packing is all or nothing, like a ship (naval/ship_crossing.dm): passengers
// get down and walk, and anything aboard that cannot be rebuilt exactly (a
// barrel, a wild or laden animal, a hitched cart) is named and keeps the
// carriage on this side. The carriage is taken off the ground the moment it
// is recorded, so nothing aboard can change afterwards; a driver who could not
// leave gets it built again where it stood.
// ============================================================

#define REGION_EDGE_WAGON_ASK_COOLDOWN 300
#define REGION_EDGE_WAGON_TEAM_MAX 4
#define REGION_EDGE_WAGON_SEATS 5
#define REGION_EDGE_WAGON_CRATE_ITEMS_MAX 60

/obj/structure/region_gate/land_edge
	// The carriage this driver got down from, until it is recorded.
	var/obj/structure/vehicle/carriage/wagon = null
	// Its record once taken off the ground, with where and how it stood.
	var/list/wagon_record = null
	var/turf/wagon_from = null
	var/wagon_facing = SOUTH

// Records the carriage and takes it off the ground. Null when there is none.
/obj/structure/region_gate/land_edge/proc/pack_wagon(mob/living/human/H)
	if (!wagon || QDELETED(wagon))
		return null
	var/record = region_edge_wagon_record(wagon)
	if (!islist(record))
		return null
	wagon_record = record
	wagon_from = get_turf(wagon)
	wagon_facing = wagon.facing
	region_edge_wagon_strip(wagon)
	wagon = null
	return wagon_record

// A driver who stayed, or could not leave, gets the carriage back as it was.
/obj/structure/region_gate/land_edge/proc/release_wagon()
	if (wagon_record && wagon_from)
		region_edge_wagon_build(wagon_record, wagon_from, wagon_facing)
	wagon_record = null
	wagon = null

// ---------------------------------------------------------------- the record

/proc/region_edge_wagon_draft_ok(path)
	return ispath(path, /mob/living/simple_animal/horse) || ispath(path, /mob/living/simple_animal/cattle)

// list(type, health, team, cargo) for a carriage nobody sits on, or a sentence
// saying what keeps it from crossing. team is a list of list(type, name,
// health); cargo a list of list(seat, crate type, list(list(kind, amount))).
/proc/region_edge_wagon_record(obj/structure/vehicle/carriage/C, mob/living/human/allowed_driver = null)
	if (!istype(C) || QDELETED(C) || !isturf(C.loc))
		return "There is no carriage to take across."
	if (C.driver && C.driver != allowed_driver)
		return "Someone else holds the reins."
	if (C.hitched_cart)
		return "Unhitch the cart behind \the [C] first; a cart crosses pulled by hand."
	var/list/team = list()
	for (var/mob/living/simple_animal/A in C.team)
		if (QDELETED(A) || A.stat == DEAD || A.wild || A.rider || !region_edge_wagon_draft_ok(A.type))
			return "\The [A] cannot make the crossing in harness. Take it out first."
		for (var/atom/movable/M in A)
			return "\The [A] carries something. Unload it first."
		var/label = (istext(A.name) && length(A.name) <= 40 && !findtext(A.name, "<") && !findtext(A.name, "\"")) ? A.name : initial(A.name)
		team += list(list("[A.type]", label, clamp(round(A.health), 1, A.maxHealth)))
	var/list/cargo = list()
	for (var/seat = 1 to REGION_EDGE_WAGON_SEATS)
		var/atom/movable/A = C.seats[seat]
		if (!A)
			continue
		if (ismob(A))
			return "Passengers have to get down and walk across themselves."
		var/obj/structure/closet/crate/crate = A
		if (!istype(crate) || crate.opened)
			return "\The [A] cannot cross on \the [C]. Only shut crates can; unload it first."
		var/list/held = list()
		for (var/atom/movable/M in crate)
			if (region_travel_ignorable(M))
				continue
			var/list/entry = istype(M, /obj/item) ? region_travel_worn_entry(M) : null
			if (!entry)
				return "\The [crate] on \the [C] cannot cross with [M.name] in it. Take that out first."
			held += list(entry)
		if (held.len > REGION_EDGE_WAGON_CRATE_ITEMS_MAX)
			return "\The [crate] on \the [C] holds too much to cross."
		cargo += list(list(seat, "[crate.type]", held))
	var/list/record = list("[C.type]", clamp(round(C.health), 1, initial(C.health)), team, cargo)
	return region_edge_wagon_valid(record) ? record : "\The [C] cannot make the crossing."

/proc/region_edge_wagon_valid(list/R)
	if (!islist(R) || R.len != 4 || !istext(R[1]) || !isnum(R[2]))
		return FALSE
	var/obj/structure/vehicle/carriage/path = text2path(R[1])
	if (!ispath(path, /obj/structure/vehicle/carriage) || R[2] < 1 || R[2] > initial(path.health) || R[2] != round(R[2]))
		return FALSE
	var/list/team = R[3]
	var/list/cargo = R[4]
	if (!islist(team) || team.len > REGION_EDGE_WAGON_TEAM_MAX || !islist(cargo) || cargo.len > REGION_EDGE_WAGON_SEATS)
		return FALSE
	var/horses = 0
	for (var/entry in team)
		var/list/M = entry
		if (!region_edge_mount_valid(M, TRUE) || !region_edge_wagon_draft_ok(text2path(M[1])))
			return FALSE
		if (ispath(text2path(M[1]), /mob/living/simple_animal/horse))
			horses++
	// One kind to a team, as the harness asks.
	if (horses && horses != team.len)
		return FALSE
	var/list/seats = list()
	for (var/entry in cargo)
		var/list/L = entry
		if (!islist(L) || L.len != 3 || !isnum(L[1]) || L[1] < 1 || L[1] > REGION_EDGE_WAGON_SEATS || L[1] != round(L[1]) || (L[1] in seats))
			return FALSE
		seats += L[1]
		if (!istext(L[2]) || !ispath(text2path(L[2]), /obj/structure/closet/crate))
			return FALSE
		var/list/held = L[3]
		if (!islist(held) || held.len > REGION_EDGE_WAGON_CRATE_ITEMS_MAX)
			return FALSE
		for (var/item in held)
			var/list/E = item
			if (!islist(E) || E.len != 2 || !region_travel_worn_valid(E[1], E[2]))
				return FALSE
	return TRUE

// Takes a recorded carriage off the ground with its team and loaded crates.
/proc/region_edge_wagon_strip(obj/structure/vehicle/carriage/C)
	var/turf/T = get_turf(C)
	for (var/atom/movable/A in C.team.Copy() + C.seats.Copy())
		if (!A)
			continue
		C.let_off(A, T)
		if (ismob(A) && !istype(A, /mob/living/simple_animal))
			continue
		for (var/atom/movable/M in A)
			qdel(M)
		qdel(A)
	qdel(C)

// Builds the recorded carriage with its corner at T, facing that way.
/proc/region_edge_wagon_build(list/R, turf/T, facing)
	if (!region_edge_wagon_valid(R) || !istype(T))
		return null
	var/path = text2path(R[1])
	var/obj/structure/vehicle/carriage/C = new path(T)
	if (facing in cardinal)
		C.facing = facing
		C.apply_shape()
	C.health = R[2]
	for (var/list/M in R[3])
		var/mob/living/simple_animal/A = region_edge_mount_build(M, T, TRUE)
		if (A)
			C.hitch(A)
	for (var/list/L in R[4])
		var/crate_path = text2path(L[2])
		var/obj/structure/closet/crate/crate = new crate_path(T)
		// A shut crate takes in what lies on its tile; that is not its load.
		for (var/atom/movable/M in crate)
			M.forceMove(T)
		for (var/list/E in L[3])
			var/obj/item/I = region_travel_make_worn(E[1], E[2], T)
			if (I)
				I.forceMove(crate)
		crate.update_capacity(length(crate.contents))
		crate.update_icon()
		C.take_seat(crate, L[1])
	C.lay_out()
	C.update_fittings()
	return C

// The corner for an arriving carriage near T: clear ground for its footprint
// and its team's lane, facing that way. T itself when nowhere nearby is clear.
/proc/region_edge_wagon_corner(turf/T, facing, team_size)
	var/lane = team_size ? 4 : 0
	for (var/reach = 0 to 10)
		for (var/dx = -reach to reach)
			for (var/dy = -reach to reach)
				if (max(abs(dx), abs(dy)) != reach)
					continue
				var/turf/corner = locate(T.x + dx, T.y + dy, T.z)
				if (!corner)
					continue
				var/list/cells = carriage_cells(corner.x, corner.y, corner.z, facing, lane)
				if (!cells)
					continue
				var/clear = TRUE
				for (var/turf/cell in cells)
					if (!region_edge_ground(cell, TRUE))
						clear = FALSE
						break
					for (var/atom/movable/M in cell)
						if (M.density && !istype(M, /atom/movable/lighting_overlay))
							clear = FALSE
							break
					if (!clear)
						break
				if (clear)
					return corner
	return T

// ---------------------------------------------------------------- leaving

// Called when a driven carriage cannot step off the map. TRUE when its driver
// was asked about travelling on (the step itself still does not happen).
/obj/structure/vehicle/carriage/proc/region_edge_reached(m_dir)
	var/mob/living/human/H = driver
	var/list/links = region_edge_links()
	if (!istype(H) || !links || z != map.edge_crossing_z || m_dir != facing)
		return FALSE
	var/side = null
	for (var/name in links)
		if (region_edge_dir(name) == m_dir)
			side = name
	if (!side)
		return FALSE
	// Only on the land itself, and only once its lane touches the border.
	var/a = (side == "north" || side == "south") ? x : y
	var/id = region_edge_destination(side, a)
	var/list/span = id ? region_edge_span(side, id) : null
	if (!span || a < span[1] || a + 1 > span[2])
		return FALSE
	if (H.region_edge_asking || world.time < H.region_edge_asked_at + REGION_EDGE_WAGON_ASK_COOLDOWN)
		return FALSE
	if (!H.client && !agent_travel_account(H))
		return FALSE
	H.region_edge_asking = TRUE
	H.region_edge_asked_at = world.time
	H.region_edge_drive(side, src)
	return TRUE

// Asks and waits on its own, like region_edge_cross() for a walker.
/mob/living/human/proc/region_edge_drive(side, obj/structure/vehicle/carriage/C)
	set waitfor = FALSE
	var/record = region_edge_wagon_record(C, src)
	if (!islist(record))
		to_chat(src, SPAN_WARNING(record))
		region_edge_asking = FALSE
		return
	var/turf/T = get_turf(C)
	var/id = region_edge_destination(side, region_edge_along(side, T))
	if (!id)
		region_edge_asking = FALSE
		return
	var/obj/structure/region_gate/land_edge/gate = new(T)
	gate.destination = id
	gate.crossing = list(side, region_edge_fraction(side, id, T), id)
	// The reins cannot travel in a hand: the driver gets down for the crossing.
	C.stopmovementloop()
	C.let_off(src, T)
	if (!buckled && !driver_vehicle && loc == T)
		gate.wagon = C
		gate.travel(src)
	// travel() returns once they left, said no or were refused.
	if (QDELETED(src) && gate.wagon_record)
		log_game("Region travel: a carriage ([gate.wagon_record[1]]) crossed the edge with its driver.")
		gate.wagon_record = null
	if (!QDELETED(gate))
		qdel(gate)
	if (!QDELETED(src))
		region_edge_asking = FALSE
		region_edge_asked_at = world.time

// ---------------------------------------------------------------- arriving

/proc/region_edge_wagon_arrived(mob/living/human/H, list/P, side)
	if (!islist(P["wagon"]))
		return
	var/facing = turn(region_edge_dir(side), 180)
	var/list/team = P["wagon"][3]
	var/turf/corner = region_edge_wagon_corner(get_turf(H), facing, length(team))
	var/obj/structure/vehicle/carriage/C = region_edge_wagon_build(P["wagon"], corner, facing)
	if (C)
		to_chat(H, SPAN_NOTICE("You drove \the [C] across. Climb back up to take the reins."))

// A departure replayed after a reload: the save still holds the carriage.
/proc/region_edge_wagon_replayed(mob/living/human/H, list/P)
	if (!region_edge_wagon_valid(P["wagon"]))
		return
	var/path = text2path(P["wagon"][1])
	for (var/obj/structure/vehicle/carriage/C in range(4, H))
		if (C.type == path && (!C.driver || C.driver == H))
			log_game("Region travel: replayed the crossing of the carriage [C.name]; it leaves again.")
			if (C.driver)
				C.let_off(C.driver, get_turf(C))
			region_edge_wagon_strip(C)
			return

#undef REGION_EDGE_WAGON_ASK_COOLDOWN
#undef REGION_EDGE_WAGON_TEAM_MAX
#undef REGION_EDGE_WAGON_SEATS
#undef REGION_EDGE_WAGON_CRATE_ITEMS_MAX
