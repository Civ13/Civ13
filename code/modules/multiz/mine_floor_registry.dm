// Packed multi-depth mining, Phase 1: the floor registry schema and its validator.
// docs/multi-depth-mining.md ("Identity and first-version boundaries", "Ordered delivery").
//
// Nothing here is instantiated by the game. There is no global registry, no save hook,
// no allocation, no generation and no entrance; later phases wire those in. The procs
// are pure: they read only their arguments and never touch the world, so a refused
// registry changes nothing.
//
// Durable key: (world lineage, mine id, depth). A mine id is an opaque integer issued from
// the header counter and never recycled; depth is geology order (1 = shallowest), not a z.
// Physical planes and rectangles live only in placement records.
//
// Schema version 1 (JSON object, every field required, unknown fields refused):
//   schema        MINE_REGISTRY_SCHEMA_VERSION
//   lineage       world lineage text, [A-Za-z0-9_-], 1..MINE_REGISTRY_LINEAGE_MAX
//   generation    committed world save generation this registry belongs to (0..MAX_INT)
//   next_mine_id  next id to issue; every recorded id is below it (1..MAX_INT)
//   limits        {mines, depth, floors, side, border}, each 1..its hard cap
//   mines         [{id, deepest, created}]: deepest = 0 for an issued mine with no floor yet
//   floors        [{mine, depth, width, height, generator, seed, created}]
//   placements    [{mine, depth, z, x1, y1, x2, y2, border, generation}]
// Every depth 1..deepest of every mine has exactly one floor and exactly one fixed placement.
// A rectangle includes its border: x2 - x1 + 1 == width + 2 * border (same for y).

/datum/mine_registry
	var/lineage
	var/generation = 0
	var/next_mine_id = 1
	var/list/limits
	// Durable records, in canonical order after decode.
	var/list/mines = list()       // /datum/mine_registry_mine
	var/list/floors = list()      // /datum/mine_registry_floor (placement inline)
	// Runtime lookups rebuilt on decode; never encoded.
	var/tmp/list/mine_index = list()   // "[id]" -> mine
	var/tmp/list/floor_index = list()  // "[mine]/[depth]" -> floor

/datum/mine_registry_mine
	var/id
	var/deepest = 0
	var/created = 0

/datum/mine_registry_floor
	var/mine_id
	var/depth
	var/width
	var/height
	var/generator
	var/seed
	var/created
	// Fixed placement (version 1 floors are resident and never move).
	var/z
	var/x1
	var/y1
	var/x2
	var/y2
	var/border
	var/placement_generation

/proc/mine_registry_int(value, low, high)
	return isnum(value) && value == round(value) && value >= low && value <= high

// Null when R is an object holding exactly the fields named, otherwise the reason.
/proc/mine_registry_fields_error(R, list/fields, label)
	if (!islist(R))
		return "[label] is not an object"
	var/list/L = R
	if (length(L) != length(fields))
		for (var/k in L)
			if (!istext(k) || !(k in fields))
				return "[label] has an unknown field"
		return "[label] is missing a field"
	for (var/k in L)
		if (!istext(k) || !(k in fields))
			return "[label] has an unknown field"
	for (var/k in fields)
		if (!(k in L))
			return "[label] is missing [k]"
	return null

/proc/mine_registry_lineage_ok(value)
	if (!istext(value) || length(value) < 1 || length(value) > MINE_REGISTRY_LINEAGE_MAX)
		return FALSE
	var/regex/shape = regex("^\[A-Za-z0-9_-]+$")
	return shape.Find(value) ? TRUE : FALSE

// Decode registry text. Returns a /datum/mine_registry, or a text reason when refused.
// expected_lineage: this world's lineage. maxx/maxy/maxz: the physical planes placements
// must fit. reserved: list of list(z, x1, y1, x2, y2) no placement may touch (compiled
// terrain, practice rooms, building levels and other owners' regions).
/proc/mine_registry_from_json(text, expected_lineage, maxx, maxy, maxz, list/reserved)
	if (!istext(text))
		return "registry text is missing"
	if (length(text) > MINE_REGISTRY_MAX_TEXT)
		return "registry text is too long"
	var/data
	try
		data = json_decode(text)
	catch
		return "registry text is not JSON"
	return mine_registry_decode(data, expected_lineage, maxx, maxy, maxz, reserved)

/proc/mine_registry_decode(data, expected_lineage, maxx, maxy, maxz, list/reserved)
	// The header comes first so an unknown version is refused before anything else is read.
	if (!islist(data))
		return "registry is not an object"
	var/list/D = data
	if (!("schema" in D) || !isnum(D["schema"]))
		return "registry has no schema version"
	if (D["schema"] != MINE_REGISTRY_SCHEMA_VERSION)
		return "unsupported registry schema [D["schema"]]"
	var/error = mine_registry_fields_error(D, list("schema", "lineage", "generation", "next_mine_id", "limits", "mines", "floors", "placements"), "registry")
	if (error)
		return error
	if (!mine_registry_lineage_ok(D["lineage"]))
		return "registry lineage is malformed"
	if (!mine_registry_lineage_ok(expected_lineage))
		return "expected lineage is malformed"
	if (D["lineage"] != expected_lineage)
		return "registry belongs to another world"
	if (!mine_registry_int(D["generation"], 0, MINE_REGISTRY_MAX_INT))
		return "registry generation is invalid"
	if (!mine_registry_int(D["next_mine_id"], 1, MINE_REGISTRY_MAX_INT))
		return "next mine id is invalid"
	if (!mine_registry_int(maxx, 1, MINE_REGISTRY_MAX_INT) || !mine_registry_int(maxy, 1, MINE_REGISTRY_MAX_INT) || !mine_registry_int(maxz, 1, MINE_REGISTRY_MAX_INT))
		return "plane bounds are invalid"

	var/list/limits = D["limits"]
	error = mine_registry_fields_error(limits, list("mines", "depth", "floors", "side", "border"), "limits")
	if (error)
		return error
	if (!mine_registry_int(limits["mines"], 1, MINE_REGISTRY_MAX_MINES) || !mine_registry_int(limits["depth"], 1, MINE_REGISTRY_MAX_DEPTH) || !mine_registry_int(limits["floors"], 1, MINE_REGISTRY_MAX_FLOORS) || !mine_registry_int(limits["side"], 1, MINE_REGISTRY_MAX_SIDE) || !mine_registry_int(limits["border"], 1, MINE_REGISTRY_MAX_BORDER))
		return "limits exceed the hard caps"

	// Counts are bounded before any record is walked.
	if (!islist(D["mines"]) || !islist(D["floors"]) || !islist(D["placements"]))
		return "record lists are missing"
	var/list/mine_list = D["mines"]
	var/list/floor_list = D["floors"]
	var/list/placement_list = D["placements"]
	if (length(mine_list) > limits["mines"])
		return "too many mines"
	if (length(floor_list) > limits["floors"])
		return "too many floors"
	if (length(placement_list) != length(floor_list))
		return "placement count does not match floor count"
	if (reserved && (!islist(reserved) || length(reserved) > MINE_REGISTRY_MAX_RESERVED))
		return "too many reserved regions"

	for (var/r in reserved)
		if (!islist(r) || length(r) != 5)
			return "reserved region is malformed"
		var/list/Q = r
		for (var/n in Q)
			if (!mine_registry_int(n, 1, MINE_REGISTRY_MAX_INT))
				return "reserved region is malformed"
		if (Q[2] > Q[4] || Q[3] > Q[5])
			return "reserved region is malformed"

	var/datum/mine_registry/R = new
	R.lineage = D["lineage"]
	R.generation = D["generation"]
	R.next_mine_id = D["next_mine_id"]
	R.limits = list("mines" = limits["mines"], "depth" = limits["depth"], "floors" = limits["floors"], "side" = limits["side"], "border" = limits["border"])

	for (var/entry in mine_list)
		error = mine_registry_fields_error(entry, list("id", "deepest", "created"), "mine")
		if (error)
			return error
		var/list/E = entry
		if (!mine_registry_int(E["id"], 1, R.next_mine_id - 1))
			return "mine id is invalid or not yet issued"
		if (R.mine_index["[E["id"]]"])
			return "duplicate mine [E["id"]]"
		if (!mine_registry_int(E["deepest"], 0, R.limits["depth"]))
			return "mine [E["id"]] depth is out of range"
		if (!mine_registry_int(E["created"], 0, R.generation))
			return "mine [E["id"]] creation receipt is invalid"
		var/datum/mine_registry_mine/M = new
		M.id = E["id"]
		M.deepest = E["deepest"]
		M.created = E["created"]
		R.mine_index["[M.id]"] = M
		R.mines += M

	for (var/entry in floor_list)
		error = mine_registry_fields_error(entry, list("mine", "depth", "width", "height", "generator", "seed", "created"), "floor")
		if (error)
			return error
		var/list/E = entry
		if (!mine_registry_int(E["mine"], 1, MINE_REGISTRY_MAX_INT) || !mine_registry_int(E["depth"], 1, MINE_REGISTRY_MAX_DEPTH))
			return "floor identity is invalid"
		var/key = "[E["mine"]]/[E["depth"]]"
		var/datum/mine_registry_mine/M = R.mine_index["[E["mine"]]"]
		if (!M)
			return "floor [key] belongs to no mine"
		if (E["depth"] > M.deepest)
			return "floor [key] is below its mine's deepest floor"
		if (R.floor_index[key])
			return "duplicate floor [key]"
		if (!mine_registry_int(E["width"], 1, R.limits["side"]) || !mine_registry_int(E["height"], 1, R.limits["side"]))
			return "floor [key] size is invalid"
		if (!mine_registry_int(E["generator"], 1, MINE_REGISTRY_MAX_INT) || !mine_registry_int(E["seed"], 0, MINE_REGISTRY_MAX_INT))
			return "floor [key] generator is invalid"
		if (!mine_registry_int(E["created"], M.created, R.generation))
			return "floor [key] creation receipt is invalid"
		var/datum/mine_registry_floor/F = new
		F.mine_id = E["mine"]
		F.depth = E["depth"]
		F.width = E["width"]
		F.height = E["height"]
		F.generator = E["generator"]
		F.seed = E["seed"]
		F.created = E["created"]
		R.floor_index[key] = F
		R.floors += F

	// A committed identity with no record is corruption; it is never a request to generate.
	for (var/datum/mine_registry_mine/M in R.mines)
		for (var/depth = 1 to M.deepest)
			if (!R.floor_index["[M.id]/[depth]"])
				return "floor [M.id]/[depth] is missing"

	for (var/entry in placement_list)
		error = mine_registry_fields_error(entry, list("mine", "depth", "z", "x1", "y1", "x2", "y2", "border", "generation"), "placement")
		if (error)
			return error
		var/list/E = entry
		if (!mine_registry_int(E["mine"], 1, MINE_REGISTRY_MAX_INT) || !mine_registry_int(E["depth"], 1, MINE_REGISTRY_MAX_DEPTH))
			return "placement identity is invalid"
		var/key = "[E["mine"]]/[E["depth"]]"
		var/datum/mine_registry_floor/F = R.floor_index[key]
		if (!F)
			return "placement [key] has no floor"
		if (F.placement_generation)
			return "duplicate placement [key]"
		if (!mine_registry_int(E["border"], 1, R.limits["border"]) || !mine_registry_int(E["generation"], 1, MINE_REGISTRY_MAX_INT))
			return "placement [key] border or generation is invalid"
		if (!mine_registry_int(E["z"], 1, maxz) || !mine_registry_int(E["x1"], 1, maxx) || !mine_registry_int(E["y1"], 1, maxy) || !mine_registry_int(E["x2"], 1, maxx) || !mine_registry_int(E["y2"], 1, maxy))
			return "placement [key] is outside the planes"
		if (E["x2"] - E["x1"] + 1 != F.width + 2 * E["border"] || E["y2"] - E["y1"] + 1 != F.height + 2 * E["border"])
			return "placement [key] does not match its floor size"
		F.z = E["z"]
		F.x1 = E["x1"]
		F.y1 = E["y1"]
		F.x2 = E["x2"]
		F.y2 = E["y2"]
		F.border = E["border"]
		F.placement_generation = E["generation"]

	// Containment and disjointness, before anything could act on a placement.
	R.sort_records()
	for (var/i = 1 to length(R.floors))
		var/datum/mine_registry_floor/A = R.floors[i]
		for (var/list/Q in reserved)
			if (Q[1] == A.z && A.x1 <= Q[4] && Q[2] <= A.x2 && A.y1 <= Q[5] && Q[3] <= A.y2)
				return "placement [A.mine_id]/[A.depth] overlaps a reserved region"
		for (var/j = i + 1 to length(R.floors))
			var/datum/mine_registry_floor/B = R.floors[j]
			if (A.z == B.z && A.x1 <= B.x2 && B.x1 <= A.x2 && A.y1 <= B.y2 && B.y1 <= A.y2)
				return "placements [A.mine_id]/[A.depth] and [B.mine_id]/[B.depth] overlap"

	return R

/datum/mine_registry/proc/sort_records()
	// Insertion sort: lists are capped at MINE_REGISTRY_MAX_FLOORS.
	for (var/i = 2 to length(mines))
		var/datum/mine_registry_mine/M = mines[i]
		var/j = i - 1
		while (j >= 1)
			var/datum/mine_registry_mine/P = mines[j]
			if (P.id <= M.id)
				break
			mines[j + 1] = P
			j--
		mines[j + 1] = M
	for (var/i = 2 to length(floors))
		var/datum/mine_registry_floor/F = floors[i]
		var/j = i - 1
		while (j >= 1)
			var/datum/mine_registry_floor/P = floors[j]
			if (P.mine_id < F.mine_id || (P.mine_id == F.mine_id && P.depth <= F.depth))
				break
			floors[j + 1] = P
			j--
		floors[j + 1] = F

// The canonical durable form: fixed field order and record order, so equal registries
// encode to equal text.
/datum/mine_registry/proc/to_list()
	var/list/mine_out = list()
	for (var/datum/mine_registry_mine/M in mines)
		mine_out[++mine_out.len] = list("id" = M.id, "deepest" = M.deepest, "created" = M.created)
	var/list/floor_out = list()
	var/list/placement_out = list()
	for (var/datum/mine_registry_floor/F in floors)
		floor_out[++floor_out.len] = list("mine" = F.mine_id, "depth" = F.depth, "width" = F.width, "height" = F.height, "generator" = F.generator, "seed" = F.seed, "created" = F.created)
		placement_out[++placement_out.len] = list("mine" = F.mine_id, "depth" = F.depth, "z" = F.z, "x1" = F.x1, "y1" = F.y1, "x2" = F.x2, "y2" = F.y2, "border" = F.border, "generation" = F.placement_generation)
	return list("schema" = MINE_REGISTRY_SCHEMA_VERSION, "lineage" = lineage, "generation" = generation, "next_mine_id" = next_mine_id, "limits" = list("mines" = limits["mines"], "depth" = limits["depth"], "floors" = limits["floors"], "side" = limits["side"], "border" = limits["border"]), "mines" = mine_out, "floors" = floor_out, "placements" = placement_out)

/datum/mine_registry/proc/to_json()
	return json_encode(to_list())

// Whether a floor identity may ever be generated. Only the next depth of an issued mine,
// within the limits, is new; a committed depth without its record is corruption.
/datum/mine_registry/proc/floor_state(mine, depth)
	var/datum/mine_registry_mine/M = mine_registry_int(mine, 1, MINE_REGISTRY_MAX_INT) ? mine_index["[mine]"] : null
	if (!M || !mine_registry_int(depth, 1, limits["depth"]))
		return MINE_FLOOR_UNKNOWN
	if (floor_index["[mine]/[depth]"])
		return MINE_FLOOR_PRESENT
	if (depth <= M.deepest)
		return MINE_FLOOR_CORRUPT
	if (depth == M.deepest + 1 && length(floors) < limits["floors"])
		return MINE_FLOOR_NEW
	return MINE_FLOOR_UNKNOWN

// Issue a fresh opaque mine id, never reusing one. Null when the counter or the mine
// limit is exhausted. The caller commits it with the next coherent world save.
/datum/mine_registry/proc/issue_mine_id()
	if (length(mines) >= limits["mines"] || next_mine_id >= MINE_REGISTRY_MAX_INT)
		return null
	var/datum/mine_registry_mine/M = new
	M.id = next_mine_id++
	M.created = generation
	mines += M
	mine_index["[M.id]"] = M
	return M.id
