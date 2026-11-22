// ============================================================
// Watertight compartments (docs/hull-ledger.md "Compartments")
// ------------------------------------------------------------
// A built hull keeps one bilge (hull_ledger.dm) until her builders part her
// with watertight bulkheads. A bulkhead, or a watertight door that is shut,
// standing on a tile of her main deck or of her hold below it divides her:
// the tiles that join each other round it are one compartment, with its own
// water. A watertight door that stands open joins the compartments on either
// side, and their water evens out between them.
//
// So a hole floods only the compartment it opens into, up to that
// compartment's brim, and a pump or a bailer lifts the water of the
// compartment they stand in. She founders when she is full, as before, or
// when compartments holding more than half her tiles are flooded: one
// flooded compartment of several she can carry home.
//
// Nothing about a compartment is a turf or an object: a compartment is a
// set of her tiles by their place in her offsets (built_body.dm), which a
// step or a turn never reorders, and a share of the ledger's water. The
// ledger's water stays the sum of them all, so everything that reads it
// (weight, depth, the film on her deck) works as before, and a hull with
// no bulkhead behaves exactly as she always did.
// ============================================================

// The share of its brim at which a compartment counts as flooded.
#define HULL_BAY_FLOODED 0.98

/datum/hull_ledger
	// Bucketfuls in each compartment, by compartment number. Saved, keyed
	// by the first of her tiles in it.
	var/tmp/list/bay_water = list()
	// The compartment of each of her tiles, by place in her offsets.
	var/tmp/list/cell_bay = list()
	// Tiles in each compartment.
	var/tmp/list/bay_size = list()
	// The first of her tiles in each compartment: its key in the record.
	var/tmp/list/bay_first = list()
	// Set when a bulkhead or a watertight door changes, so the next look
	// maps her compartments again.
	var/tmp/bays_dirty = TRUE
	// Saved water by key, waiting for her compartments to be mapped.
	var/tmp/list/bays_saved = null
	// Compartments her crew has been told are flooded, by key.
	var/tmp/list/bays_told = list()

// ---- What divides her ----

/obj/structure/hull_bulkhead
	name = "watertight bulkhead"
	desc = "A steel bulkhead set athwart a ship from her bottom to her deck. Water on one side of it stays there: a hull parted by bulkheads floods one compartment at a time."
	icon = 'icons/turf/wall_masks.dmi'
	icon_state = "sub0"
	density = TRUE
	opacity = TRUE
	anchored = TRUE
	not_movable = TRUE
	health = 400

/obj/structure/hull_bulkhead/New()
	..()
	hull_compartments_changed(get_turf(src))

/obj/structure/hull_bulkhead/Destroy()
	var/turf/T = get_turf(src)
	. = ..()
	hull_compartments_changed(T)

/obj/structure/hull_bulkhead/examine(mob/user, distance = -1)
	..()
	var/datum/hull_ledger/L = hull_ledger_at(get_turf(src))
	if (L && L.bays_split())
		to_chat(user, SPAN_NOTICE("It parts the [L.craft.name] into [L.bay_water.len] compartments."))

/obj/structure/simple_door/key_door/anyone/fire_door/steel/watertight
	name = "watertight"
	desc = "A steel door in a watertight bulkhead, with rubber seals and dogs that clamp it to its frame. Shut, it keeps water on one side of it; open, the compartments on either side flood together. It swings shut after every passage."

/obj/structure/simple_door/key_door/anyone/fire_door/steel/watertight/door_opened()
	..()
	hull_compartments_changed(get_turf(src))

/obj/structure/simple_door/key_door/anyone/fire_door/steel/watertight/door_closed()
	..()
	hull_compartments_changed(get_turf(src))

// TRUE when what stands on T parts the water: a bulkhead, or a watertight
// door that is shut.
/proc/hull_divides(turf/T)
	if (!T)
		return FALSE
	if (locate(/obj/structure/hull_bulkhead) in T)
		return TRUE
	for (var/obj/structure/simple_door/key_door/anyone/fire_door/steel/watertight/D in T)
		if (!D.state)
			return TRUE
	return FALSE

// Something that parts her changed at T: her compartments are mapped again
// at the next look.
/proc/hull_compartments_changed(turf/T)
	if (!T || !hull_ledgers.len)
		return
	var/datum/craft/C = craft_holding(T)
	if (C && C.ledger)
		C.ledger.bays_dirty = TRUE

// ---- Mapping her compartments ----

// TRUE when she is parted into more than one compartment.
/datum/hull_ledger/proc/bays_split()
	if (bays_dirty)
		bays_map()
	return bay_water.len > 1

// Her tile i by its place in her offsets, from a tile of any deck she has.
/datum/hull_ledger/proc/bay_cell_index(turf/T)
	var/datum/craft_body/built/B = craft ? craft.body : null
	if (!T || !istype(B) || !B.placed())
		return 0
	if (T.z != B.z)
		T = locate(T.x, T.y, B.z)
		if (!T)
			return 0
	if (!B.contains(T))
		return 0
	var/dx = T.x - B.px
	var/dy = T.y - B.py
	for (var/i = 1, i <= B.offsets.len, i++)
		var/list/O = B.offsets[i]
		if (O[1] == dx && O[2] == dy)
			return i
	return 0

// The compartment T lies in, or 0.
/datum/hull_ledger/proc/bay_at(turf/T)
	if (!bays_split())
		return bay_water.len ? 1 : 0
	var/i = bay_cell_index(T)
	return i && i <= cell_bay.len ? cell_bay[i] : 0

// Bucketfuls a compartment holds when full.
/datum/hull_ledger/proc/bay_capacity(b)
	return capacity() * bay_size[b] / max(1, tiles)

// The water where T is: its compartment's, or the whole bilge's.
/datum/hull_ledger/proc/water_at(turf/T)
	var/b = bay_at(T)
	if (!b || bay_water.len < 2)
		return water
	return bay_water[b]

// Walks her tiles into compartments and shares the water out again: each
// tile keeps the depth of water it had, so nothing is made or lost.
/datum/hull_ledger/proc/bays_map()
	bays_dirty = FALSE
	var/datum/craft_body/built/B = craft ? craft.body : null
	if (!istype(B) || !B.placed())
		return
	var/n = B.offsets.len
	// Each tile's depth of water before the change.
	var/list/depth = list()
	var/old_bays = bay_water.len
	bays_sync()
	if (old_bays > 1 && cell_bay.len == n)
		for (var/i = 1, i <= n, i++)
			var/b = cell_bay[i]
			depth += (b && bay_size[b]) ? bay_water[b] / bay_size[b] : 0
	else
		var/even = water / max(1, n)
		for (var/i = 1, i <= n, i++)
			depth += even
	// Which tiles part the water.
	var/list/index = list()
	var/list/divides = list()
	var/list/main = B.cells()
	var/list/hold = B.lower_cells(main)
	var/any = FALSE
	for (var/i = 1, i <= n, i++)
		var/list/O = B.offsets[i]
		index["[O[1]],[O[2]]"] = i
		var/parts = FALSE
		if (i <= main.len && hull_divides(main[i]))
			parts = TRUE
		else if (i <= hold.len && hull_divides(hold[i]))
			parts = TRUE
		divides += parts
		if (parts)
			any = TRUE
	cell_bay = new /list(n)
	bay_size = list()
	bay_first = list()
	if (!any)
		for (var/i = 1, i <= n, i++)
			cell_bay[i] = 1
		bay_size += n
		bay_first += 1
		bay_water = list(water)
		bays_told = list()
		return
	// Open tiles that join each other make a compartment.
	var/count = 0
	for (var/i = 1, i <= n, i++)
		if (cell_bay[i] || divides[i])
			continue
		count++
		cell_bay[i] = count
		bay_first += i
		bay_size += 1
		var/list/queue = list(i)
		while (queue.len)
			var/j = queue[queue.len]
			queue.len--
			var/list/O = B.offsets[j]
			for (var/d in cardinal)
				var/k = index["[O[1] + (d == EAST ? 1 : (d == WEST ? -1 : 0))],[O[2] + (d == NORTH ? 1 : (d == SOUTH ? -1 : 0))]"]
				if (!k || cell_bay[k] || divides[k])
					continue
				cell_bay[k] = count
				bay_size[count]++
				queue += k
	// A dividing tile holds water with the first compartment beside it, so
	// every tile of her is in one and the brims add up to hers.
	for (var/pass = 1, pass <= 2, pass++)
		for (var/i = 1, i <= n, i++)
			if (cell_bay[i])
				continue
			var/list/O = B.offsets[i]
			for (var/d in cardinal)
				var/k = index["[O[1] + (d == EAST ? 1 : (d == WEST ? -1 : 0))],[O[2] + (d == NORTH ? 1 : (d == SOUTH ? -1 : 0))]"]
				if (k && cell_bay[k])
					cell_bay[i] = cell_bay[k]
					bay_size[cell_bay[k]]++
					break
	for (var/i = 1, i <= n, i++)
		if (!cell_bay[i])
			// Walled in by bulkheads all round: a compartment of its own.
			count++
			cell_bay[i] = count
			bay_first += i
			bay_size += 1
	bay_water = new /list(count)
	for (var/b = 1, b <= count, b++)
		bay_water[b] = 0
	for (var/i = 1, i <= n, i++)
		bay_water[cell_bay[i]] += depth[i]
	// A record read back before her compartments were mapped.
	if (bays_saved)
		var/list/saved = bays_saved
		bays_saved = null
		var/matched = 0
		for (var/b = 1, b <= count, b++)
			var/w = saved["[bay_first[b]]"]
			if (isnum(w))
				bay_water[b] = clamp(w, 0, bay_capacity(b))
				matched++
		if (matched == count)
			water = 0
			for (var/b = 1, b <= count, b++)
				water += bay_water[b]
		bays_sync()

// Keeps the compartments' water adding up to the ledger's: something that
// set the bilge outright (hauled out, drained in dock) is shared out by
// what each compartment held, or by its tiles when they were all dry.
/datum/hull_ledger/proc/bays_sync()
	if (!bay_water.len)
		return
	if (bay_water.len == 1)
		bay_water[1] = water
		return
	var/sum = 0
	for (var/w in bay_water)
		sum += w
	if (abs(sum - water) < 0.01)
		return
	if (water <= 0)
		for (var/b = 1, b <= bay_water.len, b++)
			bay_water[b] = 0
		return
	for (var/b = 1, b <= bay_water.len, b++)
		if (sum > 0)
			bay_water[b] = bay_water[b] * water / sum
		else
			bay_water[b] = water * bay_size[b] / max(1, tiles)

/datum/hull_ledger/proc/bays_total()
	water = 0
	for (var/w in bay_water)
		water += w

// Water comes in at T, or along her whole length when T is null, up to cap
// of her capacity shared out by tiles.
/datum/hull_ledger/proc/bays_add(amount, cap, turf/at)
	bays_sync()
	var/b = at ? bay_at(at) : 0
	if (b)
		var/brim = cap * bay_size[b] / max(1, tiles)
		bay_water[b] = max(bay_water[b], min(brim, bay_water[b] + amount))
	else
		for (var/c = 1, c <= bay_water.len, c++)
			var/share = bay_size[c] / max(1, tiles)
			var/brim = cap * share
			bay_water[c] = max(bay_water[c], min(brim, bay_water[c] + amount * share))
	bays_total()
	bays_check_flooded()

// Water goes out at T, or from wherever it lies deepest when T is null.
// Returns what came out.
/datum/hull_ledger/proc/bays_remove(amount, turf/at)
	bays_sync()
	amount = max(0, amount)
	. = 0
	var/b = at ? bay_at(at) : 0
	if (b)
		. = min(bay_water[b], amount)
		bay_water[b] -= .
		if (bay_water[b] < 0.01)
			bay_water[b] = 0
	else
		var/total = water
		if (total <= 0)
			return 0
		for (var/c = 1, c <= bay_water.len, c++)
			var/take = min(bay_water[c], amount * bay_water[c] / total)
			bay_water[c] -= take
			. += take
	bays_total()
	bays_check_flooded()

// Her holes let the sea into the compartments they open into: inflow is
// the bucketfuls through all of them this step. A hole that cannot be
// found on her (a count read back before her floors were) floods her along
// her length.
/datum/hull_ledger/proc/flood_holes(inflow)
	if (inflow <= 0 || holes <= 0)
		return
	if (!bays_split())
		add_water(inflow, capacity())
		return
	var/per_hole = inflow / holes
	var/datum/craft_body/built/B = craft.body
	var/list/main = B.cells()
	var/list/hold = B.lower_cells(main)
	var/found = 0
	for (var/i = 1, i <= main.len && found < holes, i++)
		var/turf/T = main[i]
		if (hole_at(T))
			found++
			add_water(per_hole, capacity(), T)
	for (var/i = 1, i <= hold.len && found < holes, i++)
		var/turf/L = hold[i]
		if (L && (locate(/obj/covers/steelplating/hold/breach) in L))
			found++
			add_water(per_hole, capacity(), L)
	if (found < holes)
		add_water(per_hole * (holes - found), capacity())

// Tiles of her in flooded compartments.
/datum/hull_ledger/proc/flooded_tiles()
	. = 0
	if (!bays_split())
		return water >= capacity() * HULL_BAY_FLOODED ? tiles : 0
	for (var/b = 1, b <= bay_water.len, b++)
		if (bay_water[b] >= bay_capacity(b) * HULL_BAY_FLOODED)
			. += bay_size[b]

// TRUE when she has lost her buoyancy: full to the brim (share of her
// capacity), or flooded through more than half her length.
/datum/hull_ledger/proc/founders(share = 1)
	if (water >= capacity() * share - 0.01)
		return TRUE
	return bays_split() && flooded_tiles() * 2 > tiles

// Her crew hears when a compartment floods, and when it is pumped out.
/datum/hull_ledger/proc/bays_check_flooded()
	if (!craft || bay_water.len < 2)
		return
	for (var/b = 1, b <= bay_water.len, b++)
		var/key = "[bay_first[b]]"
		var/flooded = bay_water[b] >= bay_capacity(b) * HULL_BAY_FLOODED
		if (flooded && !bays_told[key])
			bays_told[key] = TRUE
			var/left = tiles - flooded_tiles()
			craft.crew_message(SPAN_DANGER("<b>The [bay_name(b)] of the [craft.name] is flooded!</b> Keep its watertight doors shut. [left * 2 > tiles ? "Her other compartments keep her afloat." : "She cannot float with more of her flooded."]"))
		else if (!flooded && bays_told[key] && bay_water[b] < bay_capacity(b) * limit() / capacity())
			bays_told -= key
			craft.crew_message(SPAN_NOTICE("The [bay_name(b)] of the [craft.name] is pumped down below awash."))

// A compartment by its place along her, from the bow.
/datum/hull_ledger/proc/bay_name(b)
	var/list/order = bays_bow_to_stern()
	var/at = order.Find(b)
	if (at == 1)
		return "forward compartment"
	if (at == order.len)
		return "after compartment"
	return "compartment [at] of [order.len] from her bow"

// Her compartments in order from bow to stern, by how far forward their
// tiles lie on average.
/datum/hull_ledger/proc/bays_bow_to_stern()
	. = list()
	var/datum/craft_body/built/B = craft ? craft.body : null
	if (!istype(B) || bay_water.len < 2)
		return list(1)
	var/list/fore = new /list(bay_water.len)
	for (var/b = 1, b <= fore.len, b++)
		fore[b] = 0
	for (var/i = 1, i <= B.offsets.len && i <= cell_bay.len, i++)
		var/list/O = B.offsets[i]
		var/list/R = ship_draught_bow_up(O[1], O[2], B.dir)
		fore[cell_bay[i]] += R[2]
	var/list/left = list()
	for (var/b = 1, b <= fore.len, b++)
		left += b
	while (left.len)
		var/best = left[1]
		for (var/b in left)
			if (fore[b] / bay_size[b] > fore[best] / bay_size[best])
				best = b
		. += best
		left -= best

// The compartments for the tiller's account of her.
/datum/hull_ledger/proc/bays_text()
	if (!bays_split())
		return ""
	var/list/parts = list()
	for (var/b in bays_bow_to_stern())
		var/share = bay_capacity(b) ? bay_water[b] / bay_capacity(b) : 0
		var/state = "dry"
		if (share >= HULL_BAY_FLOODED)
			state = "<b>flooded</b>"
		else if (share >= limit() / capacity())
			state = "awash"
		else if (bay_water[b] >= 1)
			state = "[round(bay_water[b])] bucketful\s"
		parts += "[bay_name(b)] [state]"
	return " Her bulkheads part her into [bay_water.len] compartments: [jointext(parts, ", ")]."

// The compartments' water for her saved record, by key.
/datum/hull_ledger/proc/bays_to_list()
	if (!bays_split())
		return null
	. = list()
	for (var/b = 1, b <= bay_water.len, b++)
		.["[bay_first[b]]"] = round(bay_water[b], 0.01)

/datum/hull_ledger/proc/bays_from_list(list/saved)
	if (!islist(saved) || !saved.len)
		return
	bays_saved = saved.Copy()
	bays_dirty = TRUE

// ---- Her draught ----

/datum/design_check/ship/compartments
	order = 72

/datum/design_check/ship/compartments/ship_check(datum/ship_draught/D, datum/design_report/R)
	var/list/walls = D.piece_cells("WB") + D.piece_cells("WT")
	for (var/level in D.decks)
		if (level != "-1")
			continue
		var/list/L = D.decks[level]
		for (var/key in L)
			var/list/C = L[key]
			if (C[1] == "WB" || C[1] == "WT")
				walls |= key
	if (!walls.len)
		if (D.size_class() == HULL_CLASS_SHIP)
			R.note("She has no watertight bulkheads: one hole floods all of her. Bulkheads with watertight doors across her part her into compartments, and she stays afloat while no more than half of her is flooded.", null, "WB")
		return
	// Her compartments with every watertight door shut.
	var/list/bay = list()
	var/list/sizes = list()
	for (var/key in D.cells)
		if ((key in walls) || bay[key])
			continue
		var/n = sizes.len + 1
		sizes += 1
		bay[key] = n
		var/list/queue = list(key)
		while (queue.len)
			var/k = queue[queue.len]
			queue.len--
			for (var/d in cardinal)
				var/next = ship_draught_step_key(k, d)
				if (!D.cells[next] || (next in walls) || bay[next])
					continue
				bay[next] = n
				sizes[n]++
				queue += next
	if (sizes.len < 2)
		R.warning("Her bulkheads do not part her: water can still reach every tile round them. Run each bulkhead right across her, side to side.", walls, "WB")
		return
	var/biggest = 0
	for (var/n in sizes)
		biggest = max(biggest, n)
	if (biggest * 2 > D.cells.len)
		R.warning("One compartment holds [biggest] of her [D.cells.len] tiles: if it floods she founders. Part her so that no compartment holds more than half of her.", null, "WB")
	else
		R.note("Her bulkheads part her into [sizes.len] compartments, none more than half of her: she floats with any one of them flooded.", null, "WB")

#undef HULL_BAY_FLOODED
