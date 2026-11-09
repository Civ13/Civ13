// Piece-by-piece projects (docs/piece-projects.md): a plan is a list of
// stages, each a number of pieces with a material cost per piece. Players
// bring the materials for the next piece in turn until the project is
// finished. The holder (the slipway post, a vehicle workshop) keeps only the
// plan's name, the number of pieces fitted and what has been paid towards
// the next piece, so a half-built project saves with three plain vars.

/datum/piece_plan
	var/name = "project"
	var/node = null           // research node, where the holder checks one
	var/blurb = ""
	// Stages in order: list("name", "pieces", "cost" = material -> per piece,
	// "part" = what the stage builds, "verb" = what one piece is).
	var/list/stages = list()

/datum/piece_plan/proc/total_pieces()
	. = 0
	for (var/list/stage in stages)
		. += stage["pieces"]

/datum/piece_plan/proc/total_cost()
	. = list()
	for (var/list/stage in stages)
		var/list/cost = stage["cost"]
		for (var/key in cost)
			.[key] = (.[key] || 0) + cost[key] * stage["pieces"]

// list(stage index, piece index within it), both from 1, for the piece after
// the first done pieces; null when the project is finished.
/datum/piece_plan/proc/next_piece(done)
	var/left = done
	for (var/i in 1 to stages.len)
		var/list/stage = stages[i]
		if (left < stage["pieces"])
			return list(i, left + 1)
		left -= stage["pieces"]
	return null

// The number of pieces done when next_piece() returned next.
/datum/piece_plan/proc/index_of(list/next)
	. = next[2] - 1
	for (var/i in 1 to next[1] - 1)
		var/list/stage = stages[i]
		. += stage["pieces"]

// What the next piece still needs after paid: material -> amount.
/datum/piece_plan/proc/still_needed(done, list/paid)
	. = list()
	var/list/next = next_piece(done)
	if (!next)
		return
	var/list/stage = stages[next[1]]
	var/list/cost = stage["cost"]
	for (var/key in cost)
		var/left = cost[key] - ((paid && paid[key]) || 0)
		if (left > 0)
			.[key] = left

// How many pieces of each stage are fitted: "stage index" -> count.
/datum/piece_plan/proc/stage_progress(done)
	. = list()
	var/left = done
	for (var/i in 1 to stages.len)
		var/list/stage = stages[i]
		var/n = min(left, stage["pieces"])
		.["[i]"] = n
		left -= n

// "Building a X: 3 of 16 pieces fitted. Stage 2 of 6, Frames: the next ..."
/datum/piece_plan/proc/progress_text(done, list/paid)
	var/list/next = next_piece(done)
	if (!next)
		return null
	var/list/stage = stages[next[1]]
	return "Building a [name]: [done] of [total_pieces()] pieces fitted. Stage [next[1]] of [stages.len], [stage["name"]]: the next [stage["verb"]] ([next[2]] of [stage["pieces"]]) needs [piece_cost_text(still_needed(done, paid))]."

/proc/piece_cost_text(list/cost)
	var/list/parts = list()
	for (var/key in cost)
		parts += "[cost[key]] [key]"
	return english_list(parts)

// What material a held stack pays as, or null.
/proc/piece_material(obj/item/I)
	if (istype(I, /obj/item/stack/material/wood))
		return "wood"
	if (istype(I, /obj/item/stack/material/steel))
		return "steel"
	if (istype(I, /obj/item/stack/material/glass))
		return "glass"
	if (istype(I, /obj/item/stack/material/rope))
		return "rope"
	if (istype(I, /obj/item/stack/cable_coil))
		return "cable"
	if (is_cloth_sheet(I))
		return "cloth"
	return null

// Pays what S can towards the next piece of plan D. paid is updated in place.
// Returns list(amount taken, TRUE if the piece is now fully paid).
/proc/piece_pay(datum/piece_plan/D, done, list/paid, obj/item/stack/S)
	var/key = piece_material(S)
	var/list/needed = D.still_needed(done, paid)
	if (!key || !needed[key])
		return list(0, FALSE)
	var/take = min(S.amount, needed[key])
	if (take <= 0 || !S.use(take))
		return list(0, FALSE)
	paid[key] = (paid[key] || 0) + take
	var/list/left = D.still_needed(done, paid)
	return list(take, !left.len)

// Splits list L into n consecutive shares, as even as they come.
/proc/piece_split(list/L, n)
	. = list()
	var/start = 1
	for (var/i in 1 to n)
		var/stop = round(L.len * i / n)
		var/list/share = list()
		for (var/j = start, j <= stop, j++)
			share += list(L[j])
		. += list(share)
		start = stop + 1
