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
// Packing is all or nothing: anything aboard that cannot be rebuilt exactly
// (an engine, a barrel, an animal, a body) keeps her in port, and the crew are
// told what to put ashore. Once packed, the ship is taken off the water before
// anyone leaves, so nothing aboard can be picked up twice. A ship whose crew
// could not leave is built again where she lay.
// ============================================================

#define SEA_CROSSING_EDGE 4
// The record is bounded twice: by tiles (BUILT_HULL_MAX_TILES) and by text.
#define SEA_CROSSING_RECORD_MAX 40000
#define SEA_CROSSING_ITEMS_MAX 400
#define SEA_CROSSING_CHEST_ITEMS_MAX 30
#define SEA_CROSSING_ANCHOR_DEPTH 60

// ---------------------------------------------------------------- the gate

// The way a crossing crew leave: a hidden gate standing where the tiller was.
/obj/structure/region_gate/sea_crossing
	name = "open sea"
	desc = "Open water beyond the edge of the chart."
	invisibility = 101
	icon = null
	// The voyage fields the next crew member carries (travel_extra()).
	var/list/pending = null

/obj/structure/region_gate/sea_crossing/accepts_arrivals()
	return FALSE

/obj/structure/region_gate/sea_crossing/ship_crossing()
	return TRUE

/obj/structure/region_gate/sea_crossing/travel_extra(mob/living/human/H)
	return pending

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

// The sides of the map a ship arrives on: a land's coasts first, then the rest.
/proc/sea_crossing_sides()
	. = list()
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

// TRUE when every offset round (x, y, z) is free deep water inside the map.
/proc/sea_crossing_fits(list/offsets, x, y, z)
	for (var/list/O in offsets)
		var/turf/T = locate(x + O[1], y + O[2], z)
		if (!T || !sea_crossing_water(T))
			return FALSE
	return TRUE

// Where a ship with these offsets is built: off the first side in sides that
// has room, as near the edge as she fits. Returns a turf for her pivot, or null.
/proc/sea_crossing_anchorage(list/offsets, list/sides)
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
					if (sea_crossing_fits(offsets, x, y, z))
						return P
	return null

// ---------------------------------------------------------------- the record

// What a closet, mast or floor on her deck records, or a text reason why it cannot cross.
/proc/sea_crossing_item_entry(obj/item/I)
	var/kind = region_travel_item_kind(I)
	if (!kind)
		return null
	if (kind == "type")
		return list("[I.type]", 1)
	if (copytext(kind, 1, 6) == "ammo:")
		return list(kind, region_travel_ammo_count(I))
	if (copytext(kind, 1, 7) == "stack:")
		var/obj/item/stack/S = I
		return list(kind, S.amount)
	return list(kind, 1)

/proc/sea_crossing_closet_ok(path)
	return ispath(path, /obj/structure/closet) && !ispath(path, /obj/structure/closet/body_bag)

/proc/sea_crossing_cover_ok(path)
	return ispath(path, /obj/covers) && !ispath(path, /obj/covers/repairedfloor/rope/boarding)

/proc/sea_crossing_sail_ok(path)
	return ispath(path, /obj/structure/vehicleparts/movement/sail)

// Packs the hull of tiller T: list("record" = record, "crew" = humans aboard)
// or a text reason. Writes nothing.
/proc/sea_crossing_pack(obj/structure/hull_tiller/tiller)
	var/datum/craft/C = tiller.craft
	var/datum/craft_body/built/B = C ? C.body : null
	if (!istype(B) || !B.placed())
		return "She is not commissioned."
	var/list/crew = list()
	var/list/refused = list()
	var/list/tiles = list()
	var/items = 0
	for (var/list/O in B.offsets)
		var/turf/T = locate(B.px + O[1], B.py + O[2], B.z)
		if (!T)
			return "Part of her lies off the map."
		var/list/entries = list()
		for (var/atom/movable/M in T)
			if (M.loc != T || QDELETED(M) || M == tiller)
				continue
			if (istype(M, /atom/movable/lighting_overlay) || istype(M, /atom/movable/lighting_fullbright) || istype(M, /obj/effect) || M.craft_left_behind())
				continue
			if (ishuman(M))
				var/mob/living/human/H = M
				if (H.stat == DEAD)
					refused |= H.real_name ? "the body of [H.real_name]" : "a body"
				else
					crew += H
				continue
			if (ismob(M))
				refused |= M.name
				continue
			if (sea_crossing_cover_ok(M.type))
				var/obj/covers/F = M
				entries += list(list("c", "[F.type]", F.dir, round(F.health)))
				continue
			if (sea_crossing_sail_ok(M.type))
				var/obj/structure/vehicleparts/movement/sail/S = M
				if (S.axis)
					refused |= S.name
					continue
				entries += list(list("s", "[S.type]", S.dir, S.sails ? 1 : 0, S.broken ? 1 : 0))
				continue
			if (sea_crossing_closet_ok(M.type))
				var/obj/structure/closet/K = M
				var/list/held = list()
				for (var/atom/movable/inside in K)
					var/list/entry = istype(inside, /obj/item) ? sea_crossing_item_entry(inside) : null
					if (!entry)
						refused |= "[inside.name] in \the [K.name]"
						continue
					held += list(entry)
				if (held.len > SEA_CROSSING_CHEST_ITEMS_MAX)
					refused |= "half of what is in \the [K.name]"
				items += held.len
				entries += list(list("k", "[K.type]", K.dir, held))
				continue
			if (istype(M, /obj/item))
				var/list/entry = sea_crossing_item_entry(M)
				if (!entry)
					refused |= M.name
					continue
				items++
				entries += list(list("i", entry[1], entry[2]))
				continue
			refused |= M.name
		tiles += list(list(O[1], O[2], entries))
	if (refused.len)
		return "Put these ashore first, they cannot make the crossing: [english_list(refused.len > 8 ? refused.Copy(1, 9) + list("and more") : refused)]."
	if (items > SEA_CROSSING_ITEMS_MAX)
		return "She carries too much loose cargo to cross. Stow it in chests or put some ashore."
	var/list/record = list("v" = 1, "name" = B.hull_name, "dir" = B.dir, "from" = list(B.px, B.py, B.z),
		"papers" = (C.register && C.register.party) ? C.register.register_state() : "", "tiles" = tiles)
	if (length(json_encode(record)) > SEA_CROSSING_RECORD_MAX)
		return "She is too big and too laden to cross. Put some of her cargo ashore."
	return list("record" = record, "crew" = crew)

// TRUE when a record could be built: types, numbers and items all as packing makes them.
/proc/sea_crossing_record_ok(list/R)
	if (!islist(R) || R["v"] != 1 || !istext(R["name"]) || length(R["name"]) > 40 || !(R["dir"] in cardinal))
		return FALSE
	if (!istext(R["papers"]) || length(R["papers"]) > 4000)
		return FALSE
	var/list/from = R["from"]
	if (!islist(from) || from.len != 3)
		return FALSE
	for (var/v in from)
		if (!isnum(v) || v < 1 || v > 1000 || v != round(v))
			return FALSE
	var/list/tiles = R["tiles"]
	if (!islist(tiles) || !tiles.len || tiles.len > BUILT_HULL_MAX_TILES)
		return FALSE
	var/list/seen = list()
	var/has_pivot = FALSE
	var/items = 0
	for (var/list/tile in tiles)
		if (!islist(tile) || tile.len != 3 || !isnum(tile[1]) || !isnum(tile[2]) || abs(tile[1]) > 30 || abs(tile[2]) > 30 || tile[1] != round(tile[1]) || tile[2] != round(tile[2]))
			return FALSE
		var/key = "[tile[1]],[tile[2]]"
		if (seen[key])
			return FALSE
		seen[key] = TRUE
		if (!tile[1] && !tile[2])
			has_pivot = TRUE
		var/list/entries = tile[3]
		if (!islist(entries) || entries.len > 40)
			return FALSE
		var/floors = 0
		for (var/list/E in entries)
			if (!islist(E) || !E.len)
				return FALSE
			switch (E[1])
				if ("c")
					if (E.len != 4 || !sea_crossing_cover_ok(text2path(E[2])) || !(E[3] in alldirs + list(0)) || !isnum(E[4]) || E[4] < 0 || E[4] > 100000)
						return FALSE
					floors++
				if ("s")
					if (E.len != 5 || !sea_crossing_sail_ok(text2path(E[2])) || !(E[3] in alldirs + list(0)) || !(E[4] in list(0, 1)) || !(E[5] in list(0, 1)))
						return FALSE
				if ("k")
					if (E.len != 4 || !sea_crossing_closet_ok(text2path(E[2])) || !(E[3] in alldirs + list(0)) || !islist(E[4]) || length(E[4]) > SEA_CROSSING_CHEST_ITEMS_MAX)
						return FALSE
					for (var/list/I in E[4])
						if (!islist(I) || I.len != 2 || !istext(I[1]) || !isnum(I[2]) || !region_travel_item_path(I[1], I[2]))
							return FALSE
						items++
				if ("i")
					if (E.len != 3 || !istext(E[2]) || !isnum(E[3]) || !region_travel_item_path(E[2], E[3]))
						return FALSE
					items++
				else
					return FALSE
		if (!floors)
			return FALSE
	return has_pivot && items <= SEA_CROSSING_ITEMS_MAX

// Builds a ship from record R with her tiller at pivot. Returns the tiller,
// or null (nothing is left half built: a failed commission strips her again).
/proc/sea_crossing_build(list/R, turf/pivot, voyage = null)
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
			var/path = E[1] == "i" ? null : text2path(E[2])
			switch (E[1])
				if ("c")
					var/obj/covers/F = new path(T)
					F.dir = E[3]
					F.health = min(F.maxhealth, E[4])
					F.updateturf()
					made += F
				if ("s")
					var/obj/structure/vehicleparts/movement/sail/S = new path(T)
					S.dir = E[3]
					if (S.sails)
						qdel(S.sails)
						S.sails = null
					if (E[4])
						S.sails = new /obj/item/sail(S)
					S.broken = E[5] ? TRUE : FALSE
					S.update_icon()
					made += S
				if ("k")
					var/obj/structure/closet/K = new path(T)
					K.dir = E[3]
					// A premade chest fills itself; only what crossed goes in.
					for (var/atom/movable/inside in K)
						qdel(inside)
					for (var/list/I in E[4])
						var/obj/item/made_item = region_travel_make_item(I[1], I[2], T)
						if (made_item)
							made_item.forceMove(K)
					made += K
				if ("i")
					var/obj/item/loose = region_travel_make_item(E[2], E[3], T)
					if (loose)
						made += loose
	var/obj/structure/hull_tiller/tiller = new(pivot)
	var/problem = tiller.commission(R["name"], R["dir"])
	if (problem)
		log_game("Sea crossing: the [R["name"]] could not be commissioned at [pivot.x],[pivot.y],[pivot.z]: [problem].")
		qdel(tiller)
		for (var/atom/movable/A in made)
			if (istype(A, /obj/structure/closet))
				for (var/atom/movable/inside in A)
					qdel(inside)
			qdel(A)
		return null
	tiller.craft.anchored = TRUE
	tiller.crossing_voyage = voyage
	if (voyage)
		sea_crossing_tillers |= tiller
	if (length(R["papers"]))
		tiller.craft.register = craft_register_restore(R["papers"])
	tiller.craft.fit_drives()
	return tiller

// Everything a record holds, put down at T when no ship can be built: her
// floors and masts are lost, nothing carried is.
/proc/sea_crossing_wreck(list/R, turf/T)
	if (!islist(R) || !istype(T))
		return
	for (var/list/tile in R["tiles"])
		for (var/list/E in tile[3])
			if (E[1] == "k")
				for (var/list/I in E[4])
					region_travel_make_item(I[1], I[2], T)
			else if (E[1] == "i")
				region_travel_make_item(E[2], E[3], T)

// Takes the packed ship off the water: every floor, mast, chest and thing on her deck.
// The tiller itself and any gate stay; the caller deals with them.
/proc/sea_crossing_strip(obj/structure/hull_tiller/tiller)
	var/datum/craft_body/built/B = tiller.body()
	if (!istype(B))
		return
	var/list/turfs = B.cells()
	tiller.decommission()
	for (var/turf/T in turfs)
		for (var/atom/movable/M in T)
			if (M.loc != T || M == tiller || ismob(M) || istype(M, /obj/structure/region_gate) || istype(M, /atom/movable/lighting_overlay) || istype(M, /atom/movable/lighting_fullbright) || M.craft_left_behind())
				continue
			if (istype(M, /obj/covers) || istype(M, /obj/item) || istype(M, /obj/structure) || istype(M, /obj/effect))
				qdel(M)

// ---------------------------------------------------------------- leaving

/obj/structure/hull_tiller
	// The voyage a ship built from a crossing came on, so her crew find her.
	var/crossing_voyage = null

// Why she cannot leave the map now, or null.
/obj/structure/hull_tiller/proc/crossing_refusal(mob/living/human/H)
	if (!craft)
		return "She is not commissioned."
	var/datum/craft_body/built/B = craft.body
	if (!istype(B) || !B.at_map_edge())
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
	var/reason = crossing_refusal(H)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	var/list/places = sea_crossing_destinations()
	if (!places.len)
		to_chat(H, SPAN_WARNING("No land across the sea is known from here."))
		return
	var/choice = WWinput(H, "Leave these waters with everyone and everything aboard? Your crew go with her and carry on there.", craft.name, "Stay", places + list("Stay"))
	if (!choice || choice == "Stay" || !places[choice] || get_dist(H, src) > 1)
		return
	// Leaving a land nobody settled or claimed, the captain may give it up (land_choices.dm).
	var/abandon = abandon_choice(H)
	var/by = H.ckey
	var/result = cross(places[choice], H)
	if (result)
		to_chat(H, SPAN_WARNING(result))
	else if (abandon)
		expedition_land_ask("abandon", by)

// Sends her to region id. Null when she left, else why not. Sleeps. voyage:
// the voyage she makes the crossing on (ship_voyage.dm), else a new one.
/obj/structure/hull_tiller/proc/cross(id, mob/living/human/notify = null, voyage = null)
	var/reason = crossing_refusal(notify)
	if (reason)
		return reason
	var/list/peer = shard_group.peers[id]
	if (!peer)
		return "That land is not known here."
	if (peer["state"] != "UP")
		var/woke = shard_group.wake_peer(id, notify)
		if (woke)
			return woke
		if (QDELETED(src) || !craft)
			return "The crossing was called off."
		reason = crossing_refusal(notify)
		if (reason)
			return reason
	var/list/packed = sea_crossing_pack(src)
	if (istext(packed))
		return packed
	var/list/crew = packed["crew"]
	if (!crew.len)
		return "Nobody is aboard to sail her."
	for (var/mob/living/human/H in crew)
		var/problem = null
		if (H.client ? IsGuestKey(H.client.key) : !agent_travel_account(H))
			problem = "only players with a BYOND account can make the crossing"
		else if (H.stat != CONSCIOUS || H.restrained())
			problem = "[H.real_name] cannot make the crossing like this"
		else
			var/list/items = H.region_travel_items()
			if (istext(items))
				problem = "[H.real_name]: [items]"
		if (problem)
			return "She cannot leave: [problem]"
	var/list/record = packed["record"]
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
		else
			H.persistence_owner_ckey = agent_travel_account(H)
		H.forceMove(gate)
	log_game("Sea crossing: the [record["name"]] ([length(record["tiles"])] tiles, [crew.len] crew) leaves [pivot.x],[pivot.y],[pivot.z] for [id] (voyage [voyage]).")
	sea_crossing_strip(src)
	// The struck tiller leaves the water too; it is deleted once she is away.
	loc = null
	var/carried = FALSE
	var/departed = 0
	var/list/stayed = list()
	for (var/mob/living/human/H in crew)
		if (QDELETED(H) || H.loc != gate)
			continue
		gate.pending = list("voyage" = voyage)
		if (!carried)
			gate.pending["ship"] = record
		var/result = gate.depart(H)
		if (result == "departed")
			departed++
			if (!carried)
				carried = TRUE
		else
			stayed += H
			to_chat(H, SPAN_WARNING("You stay behind: [result]"))
	gate.pending = null
	if (!carried)
		// Nobody could take her: she is built again where she lay.
		var/obj/structure/hull_tiller/again = sea_crossing_build(record, pivot)
		if (!again)
			sea_crossing_wreck(record, pivot)
		for (var/mob/living/human/H in stayed)
			H.forceMove(pivot)
		qdel(gate)
		log_game("Sea crossing: nobody could take the [record["name"]] to [id]; she lies where she was.")
		return "Nobody could make the crossing."
	// She has gone; whoever could not follow is put ashore.
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
		// A crossing refused at the far side comes back where she left, if the water is still free.
		if (!incoming)
			var/list/from = R["from"]
			if (sea_crossing_fits(offsets, from[1], from[2], from[3]))
				pivot = locate(from[1], from[2], from[3])
		if (!pivot)
			pivot = sea_crossing_anchorage(offsets, incoming ? sea_crossing_sides() : cardinal)
		if (pivot)
			tiller = sea_crossing_build(R, pivot, P["voyage"])
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
		to_chat(H, SPAN_NOTICE(incoming ? "The [tiller.craft.name] lies at anchor off an unknown coast." : "The crossing was turned back. The [tiller.craft.name] lies at anchor where she set out."))
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
		sea_crossing_strip(tiller)
		qdel(tiller)
		log_game("Sea crossing: replayed the [R["name"]]'s departure; she leaves again.")

#undef SEA_CROSSING_EDGE
#undef SEA_CROSSING_RECORD_MAX
#undef SEA_CROSSING_ITEMS_MAX
#undef SEA_CROSSING_CHEST_ITEMS_MAX
#undef SEA_CROSSING_ANCHOR_DEPTH
