// ============================================================
// Ships between worlds (boat expeditions, docs/ship-crossing.md)
// ------------------------------------------------------------
// A built hull (built_hull.dm) lying off the edge of the map can leave this
// world for a land across the sea (an EXPEDITION region, expedition_land.dm)
// or, from such a land, for the mainland. Like a crewed flight (lander.dm),
// the crew travel as ordinary region travellers (region_travel.dm). The ship
// itself goes as a record in the first crew member's payload: her floors,
// masts, chests and what lies on her deck, by type and by the travel kinds
// characters already use. The destination builds her from the record off its
// own sea edge, anchored, and the rest of the crew come aboard there.
//
// Animals, the dead and structures on deck (barrels, tables, troughs) go too
// (ship_crossing_cargo.dm). Packing is all or nothing: anything aboard that
// cannot be rebuilt exactly (an engine, a ridden animal, a player's animal)
// keeps her in port, and the crew are told what to put ashore. Once packed,
// the ship is taken off the water before anyone leaves, so nothing aboard can
// be picked up twice. A ship whose crew could not leave is built again where
// she lay.
// ============================================================

#define SEA_CROSSING_EDGE 4
// The record is bounded twice: by tiles (BUILT_HULL_MAX_TILES) and by text.
#define SEA_CROSSING_RECORD_MAX 196608
#define SEA_CROSSING_ITEMS_MAX 400
#define SEA_CROSSING_CHEST_ITEMS_MAX 30
#define SEA_CROSSING_ANCHOR_DEPTH 60
// Animals, bodies and structures on her deck.
#define SEA_CROSSING_CARGO_MAX 40
// Deciseconds a hold outlives its deadline while a crossing is still busy with
// it, so a crossing that never came back cannot keep her bound for ever.
#define SEA_CROSSING_HOLD_GRACE 600

// ---------------------------------------------------------------- the gate

// The way a crossing crew leave: a hidden gate standing where the tiller was.
/obj/structure/region_gate/sea_crossing
	name = "open sea"
	desc = "Open water beyond the edge of the chart."
	invisibility = 101
	icon = null
	// The voyage fields each crew member carries (travel_extra()), by mob.
	var/list/pending = null

/obj/structure/region_gate/sea_crossing/accepts_arrivals()
	return FALSE

/obj/structure/region_gate/sea_crossing/ship_crossing()
	return TRUE

/obj/structure/region_gate/sea_crossing/travel_extra(mob/living/human/H)
	return pending ? pending[H] : null

/obj/structure/region_gate/sea_crossing/attack_hand(mob/living/human/user)
	return

/obj/structure/region_gate/sea_crossing/attack_ghost(mob/user)
	return

// ---------------------------------------------------------------- where

// TRUE when one of the hull's tiles lies within SEA_CROSSING_EDGE of the map edge.
/datum/craft_body/built/proc/at_map_edge()
	for (var/turf/T in cells())
		if (T.x <= SEA_CROSSING_EDGE || T.y <= SEA_CROSSING_EDGE || T.x > world.maxx - SEA_CROSSING_EDGE || T.y > world.maxy - SEA_CROSSING_EDGE)
			return TRUE
	return FALSE

// "Name" = region id of every land a ship can cross to from here, now.
/proc/sea_crossing_destinations()
	. = list()
	if (!shard_group || !shard_group.enabled)
		return
	for (var/id in shard_group.peers)
		var/list/peer = shard_group.peers[id]
		if (shard_group.kind == "EXPEDITION")
			// From a land across the sea, home to the mainland.
			if (id != shard_group.mainland)
				continue
		else if (peer["kind"] != "EXPEDITION")
			continue
		// A free slot answers as plain "A New Land"; one holding a land names it.
		else if (peer["state"] == "UP" && peer["map"] == "A New Land")
			continue
		if (peer["state"] == "STOPPED" || !(peer["state"] == "UP" || shard_group.peer_wakeable(id)))
			continue
		.["[peer["name"]]"] = id

// The sides of the map a ship arrives on: the coasts facing the continent
// she sailed from (sea_lanes.dm), a land's coasts, then the rest.
/proc/sea_crossing_sides(from = null)
	. = sea_lane_sides(from)
	var/list/land = expedition_land()
	if (land && islist(land["coast"]))
		for (var/side in land["coast"])
			var/d = text2dir_side(side)
			if (d && !(d in .))
				. += d
	for (var/d in cardinal)
		if (!(d in .))
			. += d

/proc/text2dir_side(side)
	switch (side)
		if ("N") return NORTH
		if ("S") return SOUTH
		if ("E") return EAST
		if ("W") return WEST
	return null

// A tile a ship can be built on: deep water with nothing standing in it.
/proc/sea_crossing_water(turf/T)
	if (!istype(T, /turf/floor/beach/water/deep))
		return FALSE
	if (locate(/obj/covers) in T)
		return FALSE
	if (vessel_at(T) || craft_at(T))
		return FALSE
	for (var/atom/movable/M in T)
		if (M.density && !istype(M, /atom/movable/lighting_overlay))
			return FALSE
	return TRUE

// TRUE when every offset round (x, y, z) is free deep water inside the map,
// with no floor beside her.
// hold: offsets of her hold, which must also find rock or deep water free on
// the level below (sea_crossing_hold_ground). upper: offsets of her upper
// deck, which must find open air free on the building level above.
/proc/sea_crossing_fits(list/offsets, x, y, z, list/hold = null, list/upper = null)
	var/list/mine = list()
	for (var/list/O in offsets)
		mine["[O[1]],[O[2]]"] = TRUE
	for (var/list/O in offsets)
		var/turf/T = locate(x + O[1], y + O[2], z)
		if (!T || !sea_crossing_water(T))
			return FALSE
		// A floor beside her would join her to another hull or the shore,
		// and she could not be commissioned (built_hull_survey()).
		for (var/d in cardinal)
			var/list/step = list(O[1] + (d == EAST ? 1 : d == WEST ? -1 : 0), O[2] + (d == NORTH ? 1 : d == SOUTH ? -1 : 0))
			if (mine["[step[1]],[step[2]]"])
				continue
			var/turf/N = locate(x + step[1], y + step[2], z)
			if (N && hull_floor_in(N))
				return FALSE
	if (length(hold))
		var/lz = multiz_level_below(z)
		if (!lz)
			return FALSE
		for (var/list/O in hold)
			if (!sea_crossing_hold_ground(locate(x + O[1], y + O[2], lz)))
				return FALSE
	if (length(upper))
		var/uz = building_upper_z(z)
		var/tz = uz ? building_upper_z(uz) : 0
		if (!uz)
			return FALSE
		for (var/list/O in upper)
			// An offset of her second deck above is list(x, y, 2).
			var/second = O.len >= 3 && O[3] == 2
			if (second && !tz)
				return FALSE
			if (built_hull_upper_refusal(locate(x + O[1], y + O[2], second ? tz : uz)))
				return FALSE
	return TRUE

// The offsets of a record's hold tiles, or an empty list.
/proc/sea_crossing_hold_offsets(list/R)
	. = list()
	if (islist(R) && islist(R["hold"]))
		for (var/list/tile in R["hold"])
			. += list(list(tile[1], tile[2]))

// The offsets of a record's upper deck tiles, then of her second deck above
// as list(x, y, 2), or an empty list.
/proc/sea_crossing_upper_offsets(list/R)
	. = list()
	if (islist(R) && islist(R["upper"]))
		for (var/list/tile in R["upper"])
			. += list(list(tile[1], tile[2]))
	if (islist(R) && islist(R["top"]))
		for (var/list/tile in R["top"])
			. += list(list(tile[1], tile[2], 2))

// Where a ship with these offsets is built: off the first side in sides that
// has room, as near the edge as she fits. Returns a turf for her pivot, or null.
/proc/sea_crossing_anchorage(list/offsets, list/sides, list/hold = null, list/upper = null)
	var/list/B = list(0, 0, 0, 0)
	for (var/list/O in offsets)
		B[1] = min(B[1], O[1])
		B[2] = min(B[2], O[2])
		B[3] = max(B[3], O[1])
		B[4] = max(B[4], O[2])
	for (var/side in sides)
		for (var/depth = 2, depth <= SEA_CROSSING_ANCHOR_DEPTH, depth += 2)
			for (var/z = world.maxz, z >= 1, z--)
				var/along_max = (side == NORTH || side == SOUTH) ? world.maxx : world.maxy
				var/start = rand(0, 4)
				for (var/a = 1 + start, a <= along_max, a += 5)
					var/x
					var/y
					switch (side)
						if (NORTH)
							x = a
							y = world.maxy - depth - B[4]
						if (SOUTH)
							x = a
							y = 1 + depth - B[2]
						if (EAST)
							x = world.maxx - depth - B[3]
							y = a
						else
							x = 1 + depth - B[1]
							y = a
					if (x + B[1] < 1 || y + B[2] < 1 || x + B[3] > world.maxx || y + B[4] > world.maxy)
						continue
					var/turf/P = locate(x, y, z)
					if (!P || !sea_crossing_water(P))
						continue
					if (sea_crossing_fits(offsets, x, y, z, hold, upper))
						return P
	return null

// ---------------------------------------------------------------- the record

// What an item on her deck or in a chest records, list(kind, amount), or null
// when it cannot cross. Anything a traveller could carry can (region_travel_gear.dm).
/proc/sea_crossing_item_entry(obj/item/I)
	return region_travel_worn_entry(I)

/proc/sea_crossing_closet_ok(path)
	return ispath(path, /obj/structure/closet) && !ispath(path, /obj/structure/closet/body_bag)

/proc/sea_crossing_cover_ok(path)
	return ispath(path, /obj/covers) && !ispath(path, /obj/covers/repairedfloor/rope/boarding)

/proc/sea_crossing_roof_ok(path)
	return ispath(path, /obj/roof)

/proc/sea_crossing_sail_ok(path)
	return ispath(path, /obj/structure/vehicleparts/movement/sail)

/proc/sea_crossing_bench_ok(path)
	return ispath(path, /obj/structure/bed/chair/wood/rowing_bench)

// Her gunwales, bulwarks and any other built railing cross as part of her
// hull, not as cargo (hull_sides.dm).
/proc/sea_crossing_rail_ok(path)
	return ispath(path, /obj/structure/railing/built)

// Her belt armour is part of her hull, not cargo (hull_armour.dm).
/proc/sea_crossing_armour_ok(path)
	return ispath(path, /obj/structure/hull_armour)

/proc/sea_crossing_helm_ok(path)
	return ispath(path, /obj/structure/hull_tiller)

// Ladders that cross with her, rebuilt in pairs between her deck and hold.
/proc/sea_crossing_ladder_ok(path)
	return path in list(/obj/structure/multiz/ladder, /obj/structure/multiz/ladder/up, /obj/structure/multiz/ladder/placed, /obj/structure/multiz/ladder/up/placed)

// Packs the hull of tiller T: list("record" = record, "crew" = humans aboard)
// or a text reason. Writes nothing. Her hold (hull_hold.dm) packs as
// record["hold"], tile by tile like her deck, and her upper deck (the upper
// faces of the roofs over her deck, built_body.dm) as record["upper"].
/proc/sea_crossing_pack(obj/structure/hull_tiller/tiller)
	var/datum/craft/C = tiller.craft
	var/datum/craft_body/built/B = C ? C.body : null
	if (!istype(B) || !B.placed())
		return "She is not commissioned."
	// crew: humans aboard; refused: what stays, by name; blocking: what is
	// marked on deck for a moment so the crew can find it.
	var/list/S = list("crew" = list(), "refused" = list(), "blocking" = list(), "items" = 0, "cargo" = 0)
	var/list/tiles = list()
	var/list/hold = list()
	var/list/upper = list()
	var/list/top = list()
	var/list/deck = B.cells()
	var/list/lower = B.lower_cells(deck)
	var/list/above = B.upper_cells(deck)
	var/list/atop = B.top_cells(above)
	// Cars, trucks and light planes parked on her deck go whole (ship_crossing_cargo.dm).
	var/list/vehicles = sea_crossing_pack_vehicles(deck + lower + above + atop, deck, get_turf(tiller))
	if (istext(vehicles))
		return "She cannot cross yet: [vehicles]."
	var/list/claimed = list()
	for (var/atom/movable/M in vehicles["claimed"])
		claimed[M] = TRUE
	S["claimed"] = claimed
	var/list/carried_vehicles = vehicles["vehicles"]
	S["cargo"] = carried_vehicles.len
	for (var/i = 1, i <= B.offsets.len, i++)
		var/list/O = B.offsets[i]
		var/turf/T = deck[i]
		if (!T)
			return "Part of her lies off the map."
		tiles += list(list(O[1], O[2], sea_crossing_pack_tile(T, tiller, S)))
		var/turf/L = lower[i]
		if (L)
			hold += list(list(O[1], O[2], sea_crossing_pack_tile(L, tiller, S)))
		var/turf/U = above[i]
		if (U)
			// A roof here carries her second deck above, which goes too.
			upper += list(list(O[1], O[2], sea_crossing_pack_tile(U, tiller, S, T, atop[i])))
		var/turf/A = atop[i]
		if (A)
			top += list(list(O[1], O[2], sea_crossing_pack_tile(A, tiller, S, U)))
	var/list/refused = S["refused"]
	if (refused.len)
		sea_crossing_mark(S["blocking"])
		return "Put these ashore first, they cannot make the crossing (arrows on deck mark them): [english_list(refused.len > 8 ? refused.Copy(1, 9) + list("and more") : refused)]."
	if (S["items"] > SEA_CROSSING_ITEMS_MAX)
		return "She carries too much loose cargo to cross. Stow it in chests or put some ashore."
	if (S["cargo"] > SEA_CROSSING_CARGO_MAX)
		return "She carries too many animals, bodies, carts and fittings to cross. Put some ashore."
	var/list/record = list("v" = 1, "name" = B.hull_name, "dir" = B.dir, "from" = list(B.px, B.py, B.z),
		"papers" = (C.register && C.register.party) ? C.register.register_state() : "", "tiles" = tiles, "helm" = "[tiller.type]")
	if (hold.len)
		record["hold"] = hold
	if (upper.len)
		record["upper"] = upper
	if (top.len)
		record["top"] = top
	if (carried_vehicles.len)
		record["vehicles"] = carried_vehicles
	// Her bilge, seams, patches and bottom cross with her (hull_ledger.dm).
	if (C.ledger)
		record["ledger"] = C.ledger.to_list()
	if (length(json_encode(record)) > SEA_CROSSING_RECORD_MAX)
		return "She is too big and too laden to cross. Put some of her cargo ashore."
	return list("record" = record, "crew" = S["crew"])

// The deck entries for what stands on tile T of her deck, hold or upper deck.
// S holds what the whole packing gathers (see sea_crossing_pack). below: for
// a tile of her upper deck, the deck tile under it, whose roof the floor here
// is the upper face of.
/proc/sea_crossing_pack_tile(turf/T, obj/structure/hull_tiller/tiller, list/S, turf/below = null, turf/carried_above = null)
	var/list/entries = list()
	var/list/crew = S["crew"]
	var/list/refused = S["refused"]
	var/list/blocking = S["blocking"]
	var/list/claimed = S["claimed"]
	for (var/atom/movable/M in T)
		if (M.loc != T || QDELETED(M) || M == tiller)
			continue
		// A vehicle's parts and boot cargo are in its own record.
		if (claimed && claimed[M])
			continue
		// Flick animations and speech bubbles (both named "overlay") can be left lying on a tile; they are not cargo.
		// Ghosts and admin observers float over the deck; they are not aboard (craft_cargo.dm).
		if (region_travel_ignorable(M) || !M.craft_cargo())
			continue
		if (ishuman(M))
			var/mob/living/human/H = M
			if (H.stat != DEAD)
				crew += H
				continue
			// The dead are carried home (ship_crossing_cargo.dm).
			var/body = sea_crossing_body_entry(H)
			if (istext(body))
				refused |= body
				blocking |= H
				continue
			S["cargo"] = S["cargo"] + 1
			entries += list(body)
			continue
		if (ismob(M))
			var/animal = sea_crossing_cargo_entry(M)
			if (istext(animal))
				refused |= animal
				blocking |= M
				continue
			S["cargo"] = S["cargo"] + 1
			entries += list(animal)
			continue
		if (sea_crossing_cover_ok(M.type))
			var/obj/covers/F = M
			// The upper face of the roof below is built again on that roof ("f").
			var/obj/roof/face_of = below ? F.building_roof() : null
			entries += list(list((face_of && face_of.loc == below) ? "f" : "c", "[F.type]", F.dir, clamp(round(F.health), 0, 1000000)))
			continue
		// A roof goes as a roof; the floor on top of a roof over her deck goes
		// with her upper deck, and the floor on a roof on her upper deck with
		// her second deck above. A storey above that would be left in the air.
		if (sea_crossing_roof_ok(M.type))
			var/obj/roof/RF = M
			if (below && RF.building_floor() && (!carried_above || RF.building_floor().loc != carried_above))
				refused |= "the floor above \the [RF.name] on her upper deck"
				blocking |= RF
				continue
			entries += list(list("u", "[RF.type]", clamp(round(RF.health), 0, 100000)))
			continue
		if (sea_crossing_sail_ok(M.type))
			var/obj/structure/vehicleparts/movement/sail/SL = M
			if (SL.axis)
				refused |= SL.name
				blocking |= SL
				continue
			// How her sail is carried and whether it is torn go with her (hull_rigging.dm).
			entries += list(list("s", "[SL.type]", SL.dir, SL.sails ? 1 : 0, SL.broken ? 1 : 0, SL.canvas, SL.torn ? 1 : 0))
			continue
		if (sea_crossing_bench_ok(M.type))
			entries += list(list("o", "[M.type]", M.dir))
			continue
		if (sea_crossing_rail_ok(M.type))
			entries += list(list("r", "[M.type]", M.dir))
			continue
		if (sea_crossing_armour_ok(M.type))
			entries += list(list("a", "[M.type]"))
			continue
		// A ladder between her deck and hold is built again in pairs.
		if (sea_crossing_ladder_ok(M.type))
			entries += list(list("l", "[M.type]", M.dir))
			continue
		if (sea_crossing_closet_ok(M.type))
			var/obj/structure/closet/K = M
			var/list/held = list()
			for (var/atom/movable/inside in K)
				if (region_travel_ignorable(inside))
					continue
				var/list/entry = istype(inside, /obj/item) ? sea_crossing_item_entry(inside) : null
				if (!entry)
					refused |= "[inside.name] in \the [K.name]"
					blocking |= K
					continue
				held += list(entry)
			if (held.len > SEA_CROSSING_CHEST_ITEMS_MAX)
				refused |= "half of what is in \the [K.name]"
				blocking |= K
			S["items"] = S["items"] + held.len
			entries += list(list("k", "[K.type]", K.dir, held))
			continue
		if (istype(M, /obj/item))
			var/list/entry = sea_crossing_item_entry(M)
			if (!entry)
				refused |= M.name
				blocking |= M
				continue
			S["items"] = S["items"] + 1
			entries += list(list("i", entry[1], entry[2]))
			continue
		// An engine goes whole, with where its fuel tank stands beside it, so
		// the two are coupled again on arrival (sea_crossing_couple_tanks).
		if (istype(M, /obj/structure/engine))
			var/list/engine = sea_crossing_engine_entry(M)
			if (istext(engine))
				refused |= engine
				blocking |= M
				continue
			S["cargo"] = S["cargo"] + 1
			entries += list(engine)
			continue
		// A barrel, a table, a cart, a canoe, a machine: anything else goes whole.
		var/structure = sea_crossing_cargo_entry(M)
		if (istext(structure))
			refused |= structure
			blocking |= M
			continue
		S["cargo"] = S["cargo"] + 1
		entries += list(structure)
	return entries

// Points an arrow over each thing that stops a crossing, for a few seconds,
// as a player points (Point To). At most once every few seconds per tile.
var/global/list/sea_crossing_marked = list()
/proc/sea_crossing_mark(list/blocking)
	for (var/atom/movable/M in blocking)
		var/turf/T = get_turf(M)
		if (!T || world.time < sea_crossing_marked[T])
			continue
		sea_crossing_marked[T] = world.time + 100
		var/obj/effect/decal/point/P = new(T)
		P.name = "[M.name] (cannot make the crossing)"
		QDEL_IN(P, 100)
	// Forget old marks so the list stays small.
	if (sea_crossing_marked.len > 200)
		sea_crossing_marked.Cut()

// Measures what crossing would carry now, without moving anything: the
// refusal text, or the share of the record budget she fills, 0 to 100. A
// voyage asks before she sails (ship_voyage.dm), so a ship too big or too
// laden is told at the tiller, not at landfall minutes later. The tile caps
// bind long before this budget does: a 200-tile battleship with a full hold,
// turrets, racks and crates fills about an eighth of it
// (tests/naval_carrier/passage_probe.dm), so a record never needs splitting.
/proc/sea_crossing_load(obj/structure/hull_tiller/tiller)
	var/list/packed = sea_crossing_pack(tiller)
	if (istext(packed))
		return packed
	return round(100 * length(json_encode(packed["record"])) / SEA_CROSSING_RECORD_MAX)

// TRUE when a record could be built: types, numbers and items all as packing makes them.
/proc/sea_crossing_record_ok(list/R)
	if (!islist(R) || R["v"] != 1 || !istext(R["name"]) || length(R["name"]) > 40 || !(R["dir"] in cardinal))
		return FALSE
	if (!istext(R["papers"]) || length(R["papers"]) > 4000)
		return FALSE
	if (!isnull(R["ledger"]))
		var/list/ledger = R["ledger"]
		if (!islist(ledger) || ledger.len > 16)
			return FALSE
		for (var/key in ledger)
			if (!istext(key) || !isnum(ledger[key]))
				return FALSE
	if (!isnull(R["helm"]) && (!istext(R["helm"]) || !sea_crossing_helm_ok(text2path(R["helm"]))))
		return FALSE
	var/list/from = R["from"]
	if (!islist(from) || from.len != 3)
		return FALSE
	for (var/v in from)
		// Coordinates, not sizes: the Americas maps run past 1000 tiles.
		if (!isnum(v) || v < 1 || v > 4096 || v != round(v))
			return FALSE
	var/list/tiles = R["tiles"]
	if (!islist(tiles) || !tiles.len || tiles.len > BUILT_HULL_MAX_TILES)
		return FALSE
	// counts: items, animals and structures, and whether her pivot is there.
	var/list/counts = list(0, 0, FALSE)
	var/list/seen = sea_crossing_tiles_ok(tiles, counts)
	if (!seen)
		return FALSE
	// Her hold lies only under her own deck, one tile under each at most.
	if (!isnull(R["hold"]))
		var/list/hold = R["hold"]
		if (!islist(hold) || !hold.len || hold.len > tiles.len || tiles.len + hold.len > BUILT_HULL_MAX_DECK_TILES)
			return FALSE
		var/list/below = sea_crossing_tiles_ok(hold, counts)
		if (!below)
			return FALSE
		for (var/key in below)
			if (!seen[key])
				return FALSE
	// Her upper deck stands only over her own deck, and may be a ladder's top
	// with no floor.
	if (!isnull(R["upper"]))
		var/list/upper = R["upper"]
		var/list/hold_tiles = islist(R["hold"]) ? R["hold"] : list()
		if (!islist(upper) || !upper.len || upper.len > tiles.len || tiles.len + hold_tiles.len + upper.len > BUILT_HULL_MAX_DECK_TILES)
			return FALSE
		var/list/up = sea_crossing_tiles_ok(upper, counts, FALSE)
		if (!up)
			return FALSE
		for (var/key in up)
			if (!seen[key])
				return FALSE
		// Her second deck above stands only over her upper deck.
		if (!isnull(R["top"]))
			var/list/top = R["top"]
			if (!islist(top) || !top.len || top.len > upper.len || tiles.len + hold_tiles.len + upper.len + top.len > BUILT_HULL_MAX_DECK_TILES)
				return FALSE
			var/list/high = sea_crossing_tiles_ok(top, counts, FALSE)
			if (!high)
				return FALSE
			for (var/key in high)
				if (!up[key])
					return FALSE
	else if (!isnull(R["top"]))
		return FALSE
	if (!sea_crossing_vehicles_ok(R))
		return FALSE
	var/has_pivot = counts[3]
	var/items = counts[1]
	var/cargo = counts[2]
	return has_pivot && items <= SEA_CROSSING_ITEMS_MAX && cargo <= SEA_CROSSING_CARGO_MAX

// The tile keys of a record's deck, hold or upper deck tiles ("x,y" = TRUE),
// or null when any tile is not well formed. counts gathers items, animals and
// structures, and whether the pivot was seen: list(items, cargo, pivot).
// floored: every tile has a floor; a tile of her upper deck may be only the
// top of a ladder.
/proc/sea_crossing_tiles_ok(list/tiles, list/counts, floored = TRUE)
	var/list/seen = list()
	var/has_pivot = FALSE
	var/items = 0
	var/cargo = 0
	for (var/list/tile in tiles)
		if (!islist(tile) || tile.len != 3 || !isnum(tile[1]) || !isnum(tile[2]) || abs(tile[1]) > 30 || abs(tile[2]) > 30 || tile[1] != round(tile[1]) || tile[2] != round(tile[2]))
			return null
		var/key = "[tile[1]],[tile[2]]"
		if (seen[key])
			return null
		seen[key] = TRUE
		if (!tile[1] && !tile[2])
			has_pivot = TRUE
		var/list/entries = tile[3]
		if (!islist(entries) || entries.len > 40)
			return null
		var/floors = 0
		for (var/list/E in entries)
			if (!islist(E) || !E.len)
				return null
			switch (E[1])
				if ("c", "f")
					if (E.len != 4 || !sea_crossing_cover_ok(text2path(E[2])) || !(E[3] in alldirs + list(0)) || !isnum(E[4]) || E[4] < 0 || E[4] > 1000000)
						return null
					floors++
				if ("u")
					if (E.len != 3 || !sea_crossing_roof_ok(text2path(E[2])) || !isnum(E[3]) || E[3] < 0 || E[3] > 100000)
						return null
				if ("s")
					if ((E.len != 5 && E.len != 7) || !sea_crossing_sail_ok(text2path(E[2])) || !(E[3] in alldirs + list(0)) || !(E[4] in list(0, 1)) || !(E[5] in list(0, 1)))
						return null
					if (E.len == 7 && (!(E[6] in list(0, 1, 2)) || !(E[7] in list(0, 1))))
						return null
				if ("o")
					if (E.len != 3 || !sea_crossing_bench_ok(text2path(E[2])) || !(E[3] in alldirs + list(0)))
						return null
				if ("r")
					if (E.len != 3 || !sea_crossing_rail_ok(text2path(E[2])) || !(E[3] in cardinal))
						return null
				if ("a")
					if (E.len != 2 || !sea_crossing_armour_ok(text2path(E[2])))
						return null
				if ("k")
					if (E.len != 4 || !sea_crossing_closet_ok(text2path(E[2])) || !(E[3] in alldirs + list(0)) || !islist(E[4]) || length(E[4]) > SEA_CROSSING_CHEST_ITEMS_MAX)
						return null
					for (var/list/I in E[4])
						if (!islist(I) || I.len != 2 || !istext(I[1]) || !isnum(I[2]) || !region_travel_worn_valid(I[1], I[2]))
							return null
						items++
				if ("i")
					if (E.len != 3 || !istext(E[2]) || !isnum(E[3]) || !region_travel_worn_valid(E[2], E[3]))
						return null
					items++
				if ("g")
					if (!sea_crossing_cargo_valid(E))
						return null
					cargo++
				if ("b")
					if (!sea_crossing_body_valid(E))
						return null
					cargo++
				if ("l")
					if (E.len != 3 || !sea_crossing_ladder_ok(text2path(E[2])) || !(E[3] in alldirs + list(0)))
						return null
				if ("e")
					if (!sea_crossing_engine_valid(E))
						return null
					cargo++
				else
					return null
		if (!floors && floored)
			return null
	counts[1] += items
	counts[2] += cargo
	if (has_pivot)
		counts[3] = TRUE
	return seen

// Builds a ship from record R with her tiller at pivot. Returns the tiller,
// or null (nothing is left half built: a failed commission strips her again).
// Her hold is hollowed out under her deck where the ground below takes it
// (rock or deep water); where it does not, what the hold carried is stowed on
// the deck above instead and only its floor is lost.
/proc/sea_crossing_build(list/R, turf/pivot, voyage = null, skip_mobs = FALSE)
	if (!sea_crossing_record_ok(R) || !istype(pivot))
		return null
	var/list/offsets = list()
	for (var/list/tile in R["tiles"])
		offsets += list(list(tile[1], tile[2]))
	if (!sea_crossing_fits(offsets, pivot.x, pivot.y, pivot.z))
		return null
	var/list/made = list()
	for (var/list/tile in R["tiles"])
		var/turf/T = locate(pivot.x + tile[1], pivot.y + tile[2], pivot.z)
		if (!T)
			for (var/atom/movable/A in made)
				qdel(A)
			return null
		for (var/list/E in tile[3])
			var/atom/movable/thing = sea_crossing_build_entry(E, T, skip_mobs)
			if (thing)
				made += thing
	var/list/hold_made = list()
	var/list/hollowed = list()
	var/lz = multiz_level_below(pivot.z)
	for (var/list/tile in R["hold"])
		var/turf/T = locate(pivot.x + tile[1], pivot.y + tile[2], pivot.z)
		var/turf/L = lz ? locate(T.x, T.y, lz) : null
		var/in_hold = L && sea_crossing_hold_ground(L)
		if (in_hold)
			hollowed[L] = "[L.type]"
		for (var/list/E in tile[3])
			if (!in_hold && (E[1] == "c" || E[1] == "l"))
				continue
			var/atom/movable/thing = sea_crossing_build_entry(E, in_hold ? L : T, skip_mobs, in_hold)
			if (thing)
				hold_made += thing
	if (R["hold"] && !hollowed.len)
		log_game("Sea crossing: no ground for the hold of the [R["name"]] at [pivot.x],[pivot.y],[pivot.z]; her hold cargo is stowed on deck.")
	// Her upper deck goes on the roofs over her deck where the building level
	// above has open air for it; where it has none, the roofs stay roofs and
	// what stood up there is stowed on the deck below.
	var/list/upper_made = list()
	var/uz = building_upper_z(pivot.z)
	var/stowed_upper = FALSE
	for (var/list/tile in R["upper"])
		var/turf/T = locate(pivot.x + tile[1], pivot.y + tile[2], pivot.z)
		var/turf/U = uz ? locate(T.x, T.y, uz) : null
		var/room = U && !built_hull_upper_refusal(U)
		if (!room)
			stowed_upper = TRUE
		for (var/list/E in tile[3])
			if (!room && (E[1] == "c" || E[1] == "f" || E[1] == "l"))
				continue
			var/atom/movable/thing = sea_crossing_build_entry(E, room ? U : T, skip_mobs)
			if (!thing)
				continue
			upper_made += thing
			// The roof under her upper face takes it again (building_levels.dm).
			if (E[1] == "f")
				var/obj/roof/RF = locate(/obj/roof) in T
				if (!RF || RF.building_pair_id || !building_link(RF, thing))
					upper_made -= thing
					qdel(thing)
				else if (istype(thing, /obj/covers/repairedfloor))
					var/obj/covers/face = thing
					face.building_take_upper_face(RF)
	if (stowed_upper)
		log_game("Sea crossing: no open air above the [R["name"]] at [pivot.x],[pivot.y],[pivot.z]; her upper deck cargo is stowed on deck.")
	// Her second deck above goes on the roofs on her upper deck the same way;
	// where either deck above could not be built, what stood up there is
	// stowed on her deck.
	var/tz = uz ? building_upper_z(uz) : 0
	var/stowed_top = FALSE
	for (var/list/tile in R["top"])
		var/turf/T = locate(pivot.x + tile[1], pivot.y + tile[2], pivot.z)
		var/turf/U = uz ? locate(T.x, T.y, uz) : null
		var/turf/A = tz ? locate(T.x, T.y, tz) : null
		var/obj/roof/RU = U ? (locate(/obj/roof) in U) : null
		var/room = A && RU && !RU.building_pair_id && !built_hull_upper_refusal(A)
		if (!room)
			stowed_top = TRUE
		for (var/list/E in tile[3])
			if (!room && (E[1] == "c" || E[1] == "f" || E[1] == "l"))
				continue
			var/atom/movable/thing = sea_crossing_build_entry(E, room ? A : T, skip_mobs)
			if (!thing)
				continue
			upper_made += thing
			if (E[1] == "f")
				if (!building_link(RU, thing))
					upper_made -= thing
					qdel(thing)
				else if (istype(thing, /obj/covers/repairedfloor))
					var/obj/covers/face = thing
					face.building_take_upper_face(RU)
	if (stowed_top)
		log_game("Sea crossing: no open air two levels above the [R["name"]] at [pivot.x],[pivot.y],[pivot.z]; her second deck cargo is stowed on deck.")
	// Her vehicles are parked again once her deck is down.
	made += sea_crossing_build_vehicles(R, pivot)
	sea_crossing_couple_tanks(R, made + hold_made + upper_made, pivot)
	// Each ladder finds its other end; one with none (its hold could not be
	// hollowed or its upper deck built here) is taken down.
	for (var/obj/structure/multiz/ladder/LD in made + hold_made + upper_made)
		LD.find_target()
	for (var/obj/structure/multiz/ladder/LD in made + hold_made + upper_made)
		if (!LD.target)
			made -= LD
			hold_made -= LD
			upper_made -= LD
			qdel(LD)
	var/helm = istext(R["helm"]) ? text2path(R["helm"]) : null
	if (!sea_crossing_helm_ok(helm))
		helm = /obj/structure/hull_tiller
	var/obj/structure/hull_tiller/tiller = new helm(pivot)
	var/problem = tiller.commission(R["name"], R["dir"])
	if (problem)
		log_game("Sea crossing: the [R["name"]] could not be commissioned at [pivot.x],[pivot.y],[pivot.z]: [problem].")
		qdel(tiller)
		for (var/atom/movable/A in upper_made + made + hold_made)
			if (QDELETED(A))
				continue
			if (istype(A, /obj/structure/closet) || istype(A, /mob))
				for (var/atom/movable/inside in A)
					qdel(inside)
			qdel(A)
		for (var/turf/L in hollowed)
			L.ChangeTurf(hull_hold_origin_path(hollowed[L]))
		return null
	tiller.craft.anchored = TRUE
	tiller.crossing_voyage = voyage
	if (voyage)
		sea_crossing_tillers |= tiller
	if (length(R["papers"]))
		tiller.craft.register = craft_register_restore(R["papers"])
	tiller.craft.fit_drives()
	// She arrives as she left: wet, worn and foul, or dry, tight and clean.
	if (islist(R["ledger"]) && tiller.craft.ledger)
		tiller.craft.ledger.from_list(R["ledger"])
	return tiller

// Ground under her deck that can take her hold as she is built: rock or
// deep water with nothing standing in it (hull_hold.dm).
/proc/sea_crossing_hold_ground(turf/L)
	if (!L || !hull_hold_ground(L))
		return FALSE
	for (var/atom/movable/M in L)
		if (M.loc == L && (istype(M, /obj/covers) || (M.density && M.craft_cargo())))
			return FALSE
	return TRUE

// Builds one deck entry E at T. in_hold: T is a tile of her hold, and a floor
// hollows it first. Returns what was made, or null.
/proc/sea_crossing_build_entry(list/E, turf/T, skip_mobs = FALSE, in_hold = FALSE)
	var/path = E[1] == "i" ? null : text2path(E[2])
	switch (E[1])
		if ("u")
			var/obj/roof/RF = new path(T)
			RF.health = min(initial(RF.health), E[3])
			return RF
		if ("c", "f")
			// A floor of her hold hollows its tile first (hull_hold.dm).
			var/obj/covers/F = (in_hold && !istype(T, /turf/floor/plating/ship_hold)) ? hull_hold_lay(T, path) : new path(T)
			if (!F)
				return null
			F.dir = E[3]
			F.health = min(F.maxhealth, E[4])
			F.updateturf()
			return F
		if ("s")
			var/obj/structure/vehicleparts/movement/sail/S = new path(T)
			S.dir = E[3]
			if (S.sails)
				qdel(S.sails)
				S.sails = null
			if (E[4])
				S.sails = new /obj/item/sail(S)
			S.broken = E[5] ? TRUE : FALSE
			if (E.len >= 7)
				S.canvas = E[6]
				S.torn = E[7] ? TRUE : FALSE
			S.update_icon()
			return S
		if ("o")
			var/obj/structure/bed/chair/wood/rowing_bench/O = new path(T)
			O.set_dir(E[3])
			return O
		if ("r")
			var/obj/structure/railing/R = new path(T)
			R.set_dir(E[3])
			return R
		if ("a")
			return new path(T)
		if ("k")
			var/obj/structure/closet/K = new path(T)
			K.dir = E[3]
			// A premade chest fills itself; only what crossed goes in.
			for (var/atom/movable/inside in K)
				qdel(inside)
			for (var/list/I in E[4])
				var/obj/item/made_item = region_travel_make_worn(I[1], I[2], T)
				if (made_item)
					made_item.forceMove(K)
			return K
		if ("i")
			var/obj/item/loose = region_travel_make_worn(E[2], E[3], T)
			if (loose)
				return loose
		if ("g")
			if (skip_mobs && sea_crossing_entry_mob(E))
				return null
			var/atom/movable/thing = sea_crossing_cargo_build(E, T)
			if (thing)
				return thing
		if ("e")
			return sea_crossing_engine_build(E, T)
		if ("l")
			var/obj/structure/multiz/ladder/LD = new path(T)
			LD.set_dir(E[3])
			return LD
		if ("b")
			if (skip_mobs)
				return null
			var/mob/living/human/body = sea_crossing_body_build(E, T)
			if (body)
				return body
	return null

// Everything a record holds, put down at T when no ship can be built: her
// floors and masts are lost, nothing carried is, the animals and dead included.
/proc/sea_crossing_wreck(list/R, turf/T, skip_mobs = FALSE)
	if (!islist(R) || !istype(T))
		return
	var/list/hold = islist(R["hold"]) ? R["hold"] : list()
	var/list/upper = islist(R["upper"]) ? R["upper"] : list()
	var/list/top = islist(R["top"]) ? R["top"] : list()
	sea_crossing_wreck_vehicles(R, T)
	for (var/list/tile in R["tiles"] + hold + upper + top)
		for (var/list/E in tile[3])
			if (E[1] == "k")
				for (var/list/I in E[4])
					region_travel_make_worn(I[1], I[2], T)
			else if (E[1] == "i")
				region_travel_make_worn(E[2], E[3], T)
			else if (E[1] == "g" && !(skip_mobs && sea_crossing_entry_mob(E)))
				sea_crossing_cargo_build(E, T)
			else if (E[1] == "e")
				sea_crossing_engine_build(E, T)
			else if (E[1] == "b" && !skip_mobs)
				sea_crossing_body_build(E, T)

// Takes the packed ship off the water: every floor, mast, chest and thing on her deck.
// The tiller itself and any gate stay; the caller deals with them. cargo: the
// animals and dead she packed go too (her living crew are never on deck then).
// hold: they wait inside it instead, until the crossing is known to have gone
// (sea_crossing_cargo_gone) or failed; returns them, each with the turf it left.
/proc/sea_crossing_strip(obj/structure/hull_tiller/tiller, cargo = FALSE, atom/movable/hold = null)
	var/list/parked = list()
	var/datum/craft_body/built/B = tiller.body()
	if (!istype(B))
		return parked
	var/list/deck = B.cells()
	// Her upper deck goes first, so nothing up there falls to a deck already
	// cleared; her hold goes too, and the ground it was hollowed from closes
	// again (hull_hold.dm).
	var/list/turfs = list()
	var/list/above = B.upper_cells(deck)
	for (var/turf/A in B.top_cells(above))
		turfs += A
	for (var/turf/U in above)
		turfs += U
	turfs += deck
	var/list/origin = list()
	for (var/turf/L in B.lower_cells(deck))
		var/obj/covers/HC = hull_hold_cover(L)
		origin[L] = HC ? HC.hold_origin : "[/turf/wall/rockwall]"
		turfs += L
	tiller.decommission()
	sea_crossing_strip_vehicles(turfs)
	for (var/turf/T in turfs)
		// What stands on a tile first, then its floors and roofs.
		for (var/pass = 1, pass <= 2, pass++)
			for (var/atom/movable/M in T)
				if ((pass == 2) != (istype(M, /obj/covers) || istype(M, /obj/roof)))
					continue
				if (cargo && M.loc == T && sea_crossing_packed_mob(M))
					if (hold)
						parked[M] = T
						M.forceMove(hold)
					else
						sea_crossing_cargo_gone(M)
					continue
				if (M.loc != T || M == tiller || ismob(M) || istype(M, /obj/structure/region_gate) || !M.craft_cargo())
					continue
				if (istype(M, /obj/structure))
					sea_crossing_empty(M, T)
				if (istype(M, /obj/covers) || istype(M, /obj/roof) || istype(M, /obj/item) || istype(M, /obj/structure) || istype(M, /obj/effect) || istype(M, /obj/machinery))
					qdel(M)
	var/old_bulk = wall_bulk_placement
	wall_bulk_placement = TRUE
	for (var/turf/L in origin)
		L.ChangeTurf(hull_hold_origin_path(origin[L]))
	wall_bulk_placement = old_bulk
	return parked

// Deletes what structure M holds before M itself goes: it crossed in M's
// record, and many structures put their contents down as they are deleted,
// which would leave a second copy behind. A creature inside is put out at T.
/proc/sea_crossing_empty(atom/movable/M, turf/T)
	for (var/atom/movable/inside in M)
		if (ismob(inside))
			inside.forceMove(T)
		else
			qdel(inside)

// An animal or body that crossed is removed from here. A player still in
// their dead body watches it go as a ghost.
/proc/sea_crossing_cargo_gone(mob/living/L)
	if (QDELETED(L))
		return
	if (L.client)
		L.ghostize()
	qdel(L)

// TRUE for a deck entry that rebuilds a creature: a body, or an animal's record.
/proc/sea_crossing_entry_mob(list/E)
	if (E[1] == "b")
		return TRUE
	if (E[1] != "g")
		return FALSE
	var/list/R = region_travel_generic_record(E[2], TRUE)
	return R && ispath(text2path(R["t"]), /mob)

// TRUE for a mob a crossing packed as cargo: an animal nobody plays, or a body.
/proc/sea_crossing_packed_mob(atom/movable/M)
	if (!ismob(M) || region_travel_ignorable(M))
		return FALSE
	var/mob/living/L = M
	if (istype(L, /mob/living/simple_animal))
		var/mob/living/simple_animal/A = L
		return !A.client && !A.ckey && !agent_characters[A] && !A.rider
	return ishuman(L) && L.stat == DEAD

// ---------------------------------------------------------------- leaving

/obj/structure/hull_tiller
	// The voyage a ship built from a crossing came on, so her crew find her.
	var/crossing_voyage = null
	// The crossing she is bound to while a world is woken for her, or null:
	// "op", "region", "voyage", "state" ("plotting" a voyage's course,
	// "asking" the doorman, "committed" once it took the wake or did not
	// answer, "departing"), "until" (world.time) and "busy" (a crossing is
	// at work on it). Nothing else may send her anywhere meanwhile.
	var/tmp/list/crossing_hold = null
	// An admin is sending her (region_admin_send.dm): she may leave from
	// anywhere on the water, and who sent her rides with the crew.
	var/tmp/admin_crossing = FALSE
	var/tmp/admin_crossing_by = null

// Why she cannot leave the map now, or null.
/obj/structure/hull_tiller/proc/crossing_refusal(mob/living/human/H)
	if (!craft)
		return "She is not commissioned."
	var/datum/craft_body/built/B = craft.body
	if (!istype(B))
		return "She is not commissioned."
	if (!admin_crossing && !B.at_map_edge())
		return "She must lie off the edge of the chart, within [SEA_CROSSING_EDGE] tiles of open sea's end, to leave these waters."
	if (craft.speed || craft.turning_to)
		return "Ring all stop first."
	if (craft.grapple)
		return craft.grapple_refusal()
	if (!transfer_bridge.ready())
		return "No word can be sent across the sea right now."
	if (persistence_save_active())
		return "Wait a moment: the world is being saved."
	return null

/obj/structure/hull_tiller/proc/crossing_menu(mob/living/human/H)
	var/reason = crossing_menu_refusal(H)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	var/list/places = sea_crossing_destinations()
	if (!places.len)
		to_chat(H, SPAN_WARNING("No land across the sea is known from here."))
		return
	reason = landfall_rest_refusal()
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	var/choice = WWinput(H, "Leave these waters with everyone and everything aboard? Your crew go with her and carry on there.", craft.name, "Stay", places + list("Stay"))
	if (!choice || choice == "Stay" || !places[choice] || get_dist(H, src) > 1)
		return
	// The prompt slept: another of her crew may have sent her somewhere meanwhile.
	reason = crossing_menu_refusal(H, places[choice])
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	// Leaving a land nobody settled or claimed, the captain may give it up (land_choices.dm).
	var/abandon = abandon_choice(H)
	var/by = H.ckey
	var/result = cross(places[choice], H)
	if (result)
		to_chat(H, SPAN_WARNING(result))
	else if (abandon)
		expedition_land_ask("abandon", by)

// Why "Leave these waters" cannot send her (to id) now, or null.
/obj/structure/hull_tiller/proc/crossing_menu_refusal(mob/living/human/H, id = null)
	if (voyage)
		return "She is on a voyage. Her crew sail on with it."
	return crossing_refusal(H) || crossing_hold_refusal(id)

// ---------------------------------------------------------------- holding her course

// Her hold, dropped once it is past its deadline and nobody is at work on it.
/obj/structure/hull_tiller/proc/crossing_hold_current()
	var/list/hold = crossing_hold
	// Her crew leaving one by one can take a while: a departure is given longer.
	if (hold && world.time >= hold["until"] + (hold["busy"] ? (hold["state"] == "departing" ? SEA_CROSSING_HOLD_GRACE * 5 : SEA_CROSSING_HOLD_GRACE) : 0))
		log_game("Sea crossing: [craft ? "the [craft.name]" : "a ship"] stops holding her course for [hold["region"] || "her voyage"] (op [hold["op"]], [hold["state"]]).")
		crossing_hold = null
	return crossing_hold

// The name of the land she holds her course for.
/obj/structure/hull_tiller/proc/crossing_hold_name(list/hold)
	var/list/peer = hold && hold["region"] ? shard_group.peers[hold["region"]] : null
	return peer ? peer["name"] : (hold && hold["region"] ? hold["region"] : "her course")

// What her tiller says while she holds her course, or "".
/obj/structure/hull_tiller/proc/crossing_hold_text()
	var/list/hold = crossing_hold_current()
	if (!hold)
		return ""
	var/name = crossing_hold_name(hold)
	switch (hold["state"])
		if ("plotting")
			return "Her course is being sent to the world chart."
		if ("asking")
			return "Word is being sent ahead to [name]. She holds her course for it."
		if ("departing")
			return "She is leaving for [name]."
	var/minutes = max(1, round((hold["until"] - world.time) / 600, 1))
	return "Bound for [name]: word was sent ahead and its harbour is made ready. She holds her course for it, about [minutes] minute\s more at most."

// Why she may not be sent to id now because of her hold, or null. Only the
// land she is bound for, and only once nobody is already at work on it.
/obj/structure/hull_tiller/proc/crossing_hold_refusal(id = null)
	var/list/hold = crossing_hold_current()
	if (!hold)
		return null
	if (hold["state"] == "plotting")
		return "Her course is being sent to the world chart. Wait a moment."
	var/name = crossing_hold_name(hold)
	if (id != hold["region"])
		return "She is bound for [name]: word was sent ahead. She holds her course until it answers."
	if (hold["busy"])
		return "She is already waiting on word from [name]."
	return null

/obj/structure/hull_tiller/proc/crossing_hold_take(state, region = null, voyage_id = null, until = 600)
	crossing_hold = list("op" = "[num2text(world.time, 20)]-[rand(100000, 999999)]", "region" = region, "voyage" = voyage_id,
		"state" = state, "until" = world.time + until, "busy" = TRUE)
	return crossing_hold

// Lets go of hold if it is still hers; a stale continuation never clears a newer one.
/obj/structure/hull_tiller/proc/crossing_hold_release(list/hold)
	if (hold && crossing_hold == hold)
		crossing_hold = null

/obj/structure/hull_tiller/proc/crossing_hold_is(list/hold)
	return !QDELETED(src) && craft && crossing_hold == hold

// TRUE while hold is hers and, for a voyage, that voyage is still the one she sails.
/obj/structure/hull_tiller/proc/crossing_continues(list/hold, voyage_id)
	if (!crossing_hold_is(hold))
		return FALSE
	return !voyage_id || (islist(voyage) && voyage["id"] == voyage_id)

// TRUE while she should keep waiting on the land hold is bound for.
/obj/structure/hull_tiller/proc/crossing_waits(list/hold, voyage_id)
	return crossing_continues(hold, voyage_id) && world.time < hold["until"]

// Wakes region id for her crossing and holds her course for it. The hold,
// once the land answers; otherwise why not. Sleeps. A definite refusal before
// the doorman took the wake lets her go; once it took it (or did not answer,
// so it may have) she is bound there until it answers or the wake runs out.
/obj/structure/hull_tiller/proc/crossing_wake(id, mob/living/human/notify, voyage_id)
	var/list/hold = crossing_hold_current()
	var/name = shard_group.peers[id]["name"]
	if (hold)
		// Bound here already: no second word is sent, she waits on the first.
		hold["busy"] = TRUE
		if (voyage_id)
			hold["voyage"] = voyage_id
	else
		hold = crossing_hold_take("asking", id, voyage_id)
		var/list/asked = shard_group.ask_wake(id)
		if (!crossing_continues(hold, voyage_id))
			return "The crossing was called off."
		switch (asked["result"])
			if ("up")
				return hold
			if ("refused")
				crossing_hold_release(hold)
				return asked["reason"]
		var/eta = asked["eta"]
		hold["state"] = "committed"
		hold["woke"] = TRUE
		hold["until"] = world.time + (eta + 60) * 10
		log_game("Sea crossing: the [craft.name] is bound for [id]: the wake was [asked["result"]] (op [hold["op"]], eta [eta] s[voyage_id ? ", voyage [voyage_id]" : ""]).")
		if (notify)
			to_chat(notify, SPAN_NOTICE(shard_group.wake_notice(id, eta)))
		craft.crew_message(SPAN_NOTICE("Word is sent ahead to [name]. The [craft.name] holds her course for it and waits."))
	if (shard_group.peers[id]["state"] == "UP" || shard_group.await_peer(id, hold["until"], CALLBACK(src, PROC_REF(crossing_waits), hold, voyage_id)))
		if (!crossing_continues(hold, voyage_id))
			return "The crossing was called off."
		return hold
	if (!crossing_continues(hold, voyage_id))
		return "The crossing was called off."
	// The wake ran out: the end of this hold. A voyage may ask again.
	log_game("Sea crossing: [id] did not answer the [craft.name] in time (op [hold["op"]]).")
	crossing_hold_release(hold)
	return "[name] did not answer in time. Try again in a while."

// Sends her to region id. Null when she left, else why not. Sleeps. voyage:
// the voyage she makes the crossing on (ship_voyage.dm), else a new one.
// Whatever she is bound for holds until she leaves or it ends (crossing_wake()).
/obj/structure/hull_tiller/proc/cross(id, mob/living/human/notify = null, voyage = null, list/sea_edge = null)
	var/reason = crossing_refusal(notify)
	if (reason)
		return reason
	var/list/peer = shard_group.peers[id]
	if (!peer)
		return "That land is not known here."
	if (shard_group.peer_transfers_held(id))
		return "No ship can make landfall there for now: that land is closed to arrivals. Ask an admin."
	// An admin's send (region_admin_send.dm) overrides what she was bound for.
	if (admin_crossing)
		crossing_hold = null
	else
		if (voyage ? (!islist(src.voyage) || src.voyage["id"] != voyage) : src.voyage)
			return voyage ? "That voyage is over." : "She is on a voyage. Her crew sail on with it."
		reason = crossing_hold_refusal(id)
		if (reason)
			return reason
	var/list/hold = null
	if (peer["state"] != "UP")
		var/woke = crossing_wake(id, notify, voyage)
		if (istext(woke))
			return woke
		hold = woke
		hold["state"] = "departing"
	else
		hold = crossing_hold_current() || crossing_hold_take("departing", id, voyage)
		hold["busy"] = TRUE
		hold["state"] = "departing"
	. = cross_away(id, voyage, hold, sea_edge)
	if (. && crossing_hold_is(hold))
		// She stays: a land that took the wake stays hers until it runs out.
		hold["busy"] = FALSE
		hold["state"] = "committed"
		if (!hold["woke"] || hold["until"] <= world.time)
			crossing_hold_release(hold)

// The rest of a crossing, once the land answers: she is packed and her crew
// go. Null when she left, else why not.
/obj/structure/hull_tiller/proc/cross_away(id, voyage, list/hold, list/sea_edge = null)
	// The wake slept: whatever changed meanwhile is asked again before she is touched.
	if (!crossing_continues(hold, voyage))
		return "The crossing was called off."
	var/reason = crossing_refusal()
	if (reason)
		return reason
	var/list/packed = sea_crossing_pack(src)
	if (istext(packed))
		return packed
	var/list/crew = packed["crew"]
	if (!crew.len)
		return "Nobody is aboard to sail her."
	// Who set out on her voyage (ship_voyage.dm): one of them who logged out at
	// sea still goes with her (live report 2026-11-19: a crew stuck off the
	// coast because a crewmate had logged out on the way).
	var/list/sailed = (voyage && islist(src.voyage) && islist(src.voyage["crew"])) ? src.voyage["crew"] : list()
	for (var/mob/living/human/H in crew)
		var/problem = null
		var/logged_out = !H.client && H.persistence_owner_ckey && (admin_crossing || (H.persistence_owner_ckey in sailed))
		// An admin's crossing (region_admin_send.dm) also takes a logged-out player's body.
		if (H.client && IsGuestKey(H.client.key))
			problem = "[H.real_name] plays as a guest, and only players with a BYOND account can make the crossing"
		else if (!H.client && !logged_out && !agent_travel_account(H))
			problem = H.persistence_owner_ckey ? "[H.real_name] is logged out. Wake them or put them ashore" : "[H.real_name] has no player to go with them. Put them ashore"
		else if ((logged_out ? H.stat == DEAD : H.stat != CONSCIOUS) || H.restrained())
			problem = "[H.real_name] cannot make the crossing like this"
		else
			var/list/items = H.region_travel_items()
			if (istext(items))
				problem = "[H.real_name]: [items]"
		if (problem)
			return "She cannot leave: [problem]"
	var/list/record = packed["record"]
	// Never strip her for a record the far side (or a rebuild here) would refuse.
	if (!sea_crossing_record_ok(record))
		log_game("Sea crossing: the [record["name"]] made a record that does not pass its own check at [x],[y],[z]; she stays.")
		return "She cannot be made ready for the crossing here. Ask an admin."
	if (!voyage)
		voyage = "[shard_group.region || "world"]-[num2text(world.realtime, 20)]-[rand(1000, 9999)]"
	var/turf/pivot = get_turf(src)
	var/obj/structure/region_gate/sea_crossing/gate = new(pivot)
	gate.destination = id
	// Everyone waits inside the gate while she is taken off the water, so
	// nobody stands in the sea and nothing aboard can be picked up twice.
	for (var/mob/living/human/H in crew)
		H.stop_pulling()
		if (H.buckled)
			H.buckled.unbuckle_mob()
		if (H.client)
			H.record_persistence_owner()
		else if (agent_travel_account(H))
			H.persistence_owner_ckey = agent_travel_account(H)
		// A logged-out player's body keeps its owner (checked above).
		H.forceMove(gate)
	log_game("Sea crossing: the [record["name"]] ([length(record["tiles"])] tiles, [crew.len] crew) leaves [pivot.x],[pivot.y],[pivot.z] for [id] (voyage [voyage]).")
	// The animals and dead wait in the gate too: they go only once she has.
	var/list/parked = sea_crossing_strip(src, TRUE, gate)
	// The struck tiller leaves the water too; it is deleted once she is away.
	loc = null
	// The whole crew go as one party in one transfer (region_travel.dm), the
	// first of them carrying her record: crew sent one by one waited on each
	// other's transfer and could be left behind (HMS Gnome 2, 2026-11-15).
	var/list/aboard = list()
	gate.pending = list()
	for (var/mob/living/human/H in crew)
		if (QDELETED(H) || H.loc != gate)
			continue
		var/list/extra = list("voyage" = voyage)
		if (admin_crossing_by)
			extra["admin_send"] = region_admin_send_crew_landing(H, id, admin_crossing_by)
		if (!aboard.len)
			extra["ship"] = record
			if (islist(sea_edge))
				extra["sea_edge"] = sea_edge
		gate.pending[H] = extra
		aboard += H
	var/list/party = gate.depart_party(aboard)
	gate.pending = null
	var/list/gone = party["departed"]
	var/list/refused = party["stayed"]
	var/departed = gone.len
	// Her record went with the first of them, or with nobody.
	var/carried = aboard.len && (aboard[1] in gone)
	var/list/stayed = list()
	for (var/mob/living/human/H in crew)
		if (H in gone)
			continue
		stayed += H
		var/result = refused[H] || "the crossing could not take you"
		log_game("Sea crossing: [key_name(H)] stays behind from the [record["name"]]: [result]")
		to_chat(H, SPAN_WARNING("You stay behind: [result]"))
	if (!carried)
		// Nobody could take her: she is built again where she lay, and the
		// animals and dead who waited are put back aboard as they were.
		var/obj/structure/hull_tiller/again = sea_crossing_build(record, pivot, null, TRUE)
		if (!again)
			sea_crossing_wreck(record, pivot, TRUE)
		for (var/mob/M in parked)
			if (!QDELETED(M))
				M.forceMove(again ? parked[M] : pivot)
		for (var/mob/living/human/H in stayed)
			H.forceMove(pivot)
		qdel(gate)
		log_game("Sea crossing: nobody could take the [record["name"]] to [id]; she lies where she was.")
		return "Nobody could make the crossing."
	// She has gone, and her animals and dead with her.
	for (var/mob/M in parked)
		sea_crossing_cargo_gone(M)
	// Whoever could not follow is put ashore.
	var/turf/ashore = region_travel_arrival_turf() || pivot
	for (var/mob/living/human/H in stayed)
		H.forceMove(ashore)
		to_chat(H, SPAN_WARNING("The [record["name"]] sailed without you. You are put ashore."))
	log_game("Sea crossing: the [record["name"]] left for [id] with [departed] of [crew.len] crew.")
	qdel(gate)
	if (!QDELETED(src))
		qdel(src)
	return null

// ---------------------------------------------------------------- arriving

// TRUE when a travel payload's crossing fields are absent or well formed.
/proc/sea_crossing_payload_ok(list/P)
	if (isnull(P["voyage"]))
		return isnull(P["ship"])
	if (!istext(P["voyage"]) || !length(P["voyage"]) || length(P["voyage"]) > 64)
		return FALSE
	return isnull(P["ship"]) || sea_crossing_record_ok(P["ship"])

// Ships built from a crossing this round, so their crew find them.
var/global/list/sea_crossing_tillers = list()

/proc/sea_crossing_ship(voyage)
	for (var/obj/structure/hull_tiller/T in sea_crossing_tillers.Copy())
		if (QDELETED(T))
			sea_crossing_tillers -= T
		else if (T.crossing_voyage == voyage && T.craft)
			return T
	return null

// Where an arriving (or refused) crew member of a crossing appears. The one
// carrying the ship builds her first; the rest come aboard her.
/proc/sea_crossing_arrival_turf(list/P, incoming)
	if (!islist(P) || !istext(P["voyage"]))
		return null
	var/obj/structure/hull_tiller/tiller = sea_crossing_ship(P["voyage"])
	if (!tiller && islist(P["ship"]))
		var/list/R = P["ship"]
		var/list/offsets = list()
		for (var/list/tile in R["tiles"])
			offsets += list(list(tile[1], tile[2]))
		var/turf/pivot = null
		var/list/hold = sea_crossing_hold_offsets(R)
		var/list/upper = sea_crossing_upper_offsets(R)
		// A crossing refused at the far side comes back where she left, if the water is still free.
		if (!incoming)
			var/list/from = R["from"]
			if (sea_crossing_fits(offsets, from[1], from[2], from[3]))
				pivot = locate(from[1], from[2], from[3])
		// Over a linked map edge (ship_edge_crossing.dm): the matching place on the facing edge.
		if (!pivot && incoming && islist(P["sea_edge"]))
			if (hold.len || upper.len)
				pivot = sea_edge_anchorage(offsets, P["sea_edge"], P["from"], hold, upper)
			if (!pivot)
				pivot = sea_edge_anchorage(offsets, P["sea_edge"], P["from"])
		var/list/sides = incoming ? sea_crossing_sides(P["from"]) : cardinal
		// Water with ground below for her hold and open air above for her
		// upper deck first; failing that, any water (what her hold or upper
		// deck carried is then stowed on deck).
		if (!pivot && (hold.len || upper.len))
			pivot = sea_crossing_anchorage(offsets, sides, hold, upper)
		if (!pivot)
			pivot = sea_crossing_anchorage(offsets, sides)
		if (pivot)
			tiller = sea_crossing_build(R, pivot, P["voyage"])
		if (tiller && incoming)
			tiller.landfall_at = world.time // her crew rest before the next voyage (ship_voyage.dm)
		if (tiller)
			log_game("Sea crossing: the [R["name"]] [incoming ? "made landfall" : "came back"] at [pivot.x],[pivot.y],[pivot.z] (voyage [P["voyage"]]).")
		else
			var/turf/ashore = region_travel_arrival_turf()
			if (ashore)
				sea_crossing_wreck(R, ashore)
			message_admins("Sea crossing: no anchorage for the [html_encode(R["name"])]; her cargo was put ashore and her hull lost.")
			log_game("Sea crossing: no anchorage for the [R["name"]] (voyage [P["voyage"]]); cargo put ashore.")
			return ashore
	if (!tiller)
		return null
	var/datum/craft_body/built/B = tiller.body()
	var/list/deck = B ? B.cells() : list()
	return deck.len ? pick(deck) : get_turf(tiller)

/proc/sea_crossing_arrived(mob/living/human/H, list/P, incoming)
	if (!istype(H) || !islist(P) || !istext(P["voyage"]))
		return
	var/obj/structure/hull_tiller/tiller = sea_crossing_ship(P["voyage"])
	if (tiller && get_dist(H, tiller) <= 30)
		to_chat(H, SPAN_NOTICE(incoming ? "The [tiller.craft.name] lies at anchor off [continent_place(P["from"]) ? "the coast" : "an unknown coast"]." : "The crossing was turned back. The [tiller.craft.name] lies at anchor where she set out."))
	else if (islist(P["ship"]))
		to_chat(H, SPAN_WARNING("There was no water to bring her in. What she carried is ashore here."))

// A departure replayed after a reload: the save still holds the ship that left.
/proc/sea_crossing_replayed(mob/living/human/H, list/P)
	if (!istype(H) || !islist(P) || !islist(P["ship"]))
		return
	var/list/R = P["ship"]
	var/list/from = R["from"]
	var/turf/T = locate(from[1], from[2], from[3])
	var/obj/structure/hull_tiller/tiller = T ? locate(/obj/structure/hull_tiller) in T : null
	if (tiller && tiller.craft && tiller.craft.name == R["name"])
		sea_crossing_strip(tiller, TRUE)
		qdel(tiller)
		log_game("Sea crossing: replayed the [R["name"]]'s departure; she leaves again.")

#undef SEA_CROSSING_EDGE
#undef SEA_CROSSING_RECORD_MAX
#undef SEA_CROSSING_ITEMS_MAX
#undef SEA_CROSSING_CHEST_ITEMS_MAX
#undef SEA_CROSSING_ANCHOR_DEPTH
#undef SEA_CROSSING_CARGO_MAX
#undef SEA_CROSSING_HOLD_GRACE
