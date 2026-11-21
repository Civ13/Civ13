// Region travel, any other item: whatever a traveller wears, holds or keeps in
// a bag, or a ship carries on her deck or in her chests, travels when no
// narrower kind (region_travel.dm, region_travel_gear.dm) fits. It is recorded
// as "item:<json>":
//
//   t  its type, an /obj/item that is not a grab or organ
//   v  every saved plain field that differs from a new one of its type:
//      numbers, text, and lists of them (names, colours, icon states, amounts,
//      chapters). A field a new item sets at random always travels.
//   n  numbers JSON would round (six significant digits), as full text
//   y  fields that hold a type, as its path text
//   m  fields that hold a material, by material name
//   r  its reagents, as list(id, volume) pairs
//   c  what it holds, each as its own record, a few levels deep
//   l  fields that point at what it holds (a gun's magazine, a uniform's
//      accessories), as the index or indices of those records in c
//   p  fields of a held thing that point back at its holder (an accessory's suit)
//
// Fields holding links to anything else are process state and stay behind;
// the item rebuilds them as a new one does. Temporary (tmp) fields never
// travel. Anything holding a creature never travels. The record is checked
// field by field on the way in, and a field that does not fit is skipped
// rather than stopping the arrival.
//
// A ship's deck (naval/ship_crossing.dm) also carries cargo that is not an
// item: a structure (a barrel, a table, a door) or an animal. Such a record is
// only ever the whole of one deck entry, never inside anything, and only the
// callers that ask for cargo ("root") accept one. It travels the way a world
// save keeps it: its saved fields, contents and reagents, rebuilt as a load does.

#define REGION_TRAVEL_GENERIC_MAX 131072
#define REGION_TRAVEL_GENERIC_DEPTH 6
#define REGION_TRAVEL_GENERIC_NODES 1500
#define REGION_TRAVEL_GENERIC_CHILDREN 300
#define REGION_TRAVEL_GENERIC_FIELDS 96
#define REGION_TRAVEL_GENERIC_TEXT 8192
#define REGION_TRAVEL_GENERIC_LIST 128
#define REGION_TRAVEL_GENERIC_SAMPLES 5
#define REGION_TRAVEL_GENERIC_VOLUME 10000
// A field new items do not agree on (a pelt coat picks its colour as it is made).
#define REGION_TRAVEL_GENERIC_RANDOM "\[random]"

// Fields never recorded nor set: identity, place, drawing state while held,
// forensic marks, and process-local links.
var/global/list/region_travel_generic_skip = list(
	"type", "parent_type", "vars", "contents", "loc", "x", "y", "z", "tag", "key", "ckey",
	"verbs", "locs", "overlays", "underlays", "vis_contents", "vis_locs", "appearance",
	"screen_loc", "layer", "plane", "mouse_opacity", "group", "reagents", "client",
	"animate_movement", "override", "glide_size", "particles", "filters", "transform",
	"fingerprints", "fingerprintshidden", "fingerprintslast", "suit_fibers", "invisibility", "status_flags",
	"gc_destroyed", "gcDestroyed", "datum_flags", "weak_reference", "active_timers",
	"train_transfer_id", "train_transfer_journey", "train_transfer_digest")

// Per type: the fields worth looking at, and what each holds on new items.
var/global/list/region_travel_generic_keys = list()
var/global/list/region_travel_generic_defaults = list()

// TRUE for things that are never cargo and never stop a trip: flick
// animations and speech bubbles (both named "overlay"), lighting, effects
// such as pointing arrows, and ghosts or admin observers.
/proc/region_travel_ignorable(atom/movable/M)
	return istype(M, /atom/movable/overlay) || istype(M, /obj/chat_text) || istype(M, /obj/effect) || istype(M, /atom/movable/lighting_overlay) || istype(M, /atom/movable/lighting_fullbright) || istype(M, /mob/observer)

/proc/region_travel_generic_type_ok(path, root = FALSE)
	if(root && region_travel_generic_cargo_type_ok(path)) return TRUE
	if(!ispath(path, /obj/item)) return FALSE
	for(var/denied in list(/obj/item/weapon/grab, /obj/item/hand_hold, /obj/item/organ))
		if(ispath(path, denied)) return FALSE
	return TRUE

// Deck cargo that is not an item. Masts, benches, chests and the helm have
// narrower deck entries; vehicles, engines and trails are never cargo.
/proc/region_travel_generic_cargo_type_ok(path)
	if(ispath(path, /mob/living/simple_animal)) return TRUE
	if(!ispath(path, /obj/structure)) return FALSE
	// Nor what only an admin or the map places: spawners, traders, printers,
	// level links, docks and helms, which a forged record must never create.
	for(var/denied in list(/obj/structure/vehicleparts, /obj/structure/vehicle, /obj/structure/hull_tiller, /obj/structure/region_gate,
		/obj/structure/engine, /obj/structure/animalspawner, /obj/structure/money_printer, /obj/structure/event_stash,
		/obj/structure/npc_vendor, /obj/structure/specialist_trader, /obj/structure/supplier, /obj/structure/multiz,
		/obj/structure/docking_port, /obj/structure/chart_helm, /obj/structure/vessel_helm, /obj/structure/cargo_hold))
		if(ispath(path, denied)) return FALSE
	return TRUE

/proc/region_travel_generic_field_ok(key)
	return istext(key) && length(key) <= 64 && !(key in region_travel_generic_skip)

// TRUE for a number that comes back from JSON unchanged.
/proc/region_travel_generic_exact_num(value)
	if(!isnum(value) || value != value || abs(value) >= 1e15) return FALSE
	// Whole numbers of six digits or fewer always come back exactly.
	if(value == round(value) && abs(value) < 100000) return TRUE
	var/list/back = json_decode(json_encode(list(value)))
	return back[1] == value

// TRUE for a value that crosses as JSON and comes back the same.
/proc/region_travel_generic_value_ok(value, depth = 0)
	if(isnull(value)) return TRUE
	// A number inside a list may come back rounded to six digits; a field
	// that is itself an inexact number travels as text instead (see "n").
	if(isnum(value)) return depth ? (value == value && abs(value) < 1e15) : region_travel_generic_exact_num(value)
	if(istext(value)) return length(value) <= REGION_TRAVEL_GENERIC_TEXT
	if(!islist(value) || depth >= 2) return FALSE
	var/list/L = value
	if(L.len > REGION_TRAVEL_GENERIC_LIST) return FALSE
	for(var/k in L)
		if(istext(k))
			if(length(k) > 200) return FALSE
			if(!isnull(L[k]) && !region_travel_generic_value_ok(L[k], depth + 1)) return FALSE
		else if(isnum(k))
			if(k != k || abs(k) >= 1e15) return FALSE
		else
			return FALSE
	// A list that is partly keyed, or keyed by numbers, would not come back the same.
	var/text = json_encode(L)
	var/back
	try
		back = json_decode(text)
	catch
		return FALSE
	return json_encode(back) == text

// How a field value is compared with a new item's: JSON, or null for a link.
/proc/region_travel_generic_wire(value)
	if(istype(value, /material))
		var/material/M = value
		return "material:[M.name]"
	if(ispath(value))
		return "path:[value]"
	if(isnum(value) && !region_travel_generic_exact_num(value))
		return (value == value && abs(value) < 1e15) ? "num:[num2text(value, 20)]" : null
	if(!region_travel_generic_value_ok(value)) return null
	return json_encode(value)

// The saved, non-runtime fields of I's type worth looking at.
/proc/region_travel_generic_fields_of(atom/movable/I)
	var/list/keys = region_travel_generic_keys[I.type]
	if(!keys)
		keys = list()
		for(var/key in I.vars)
			if(!region_travel_generic_field_ok(key) || !issaved(I.vars[key])) continue
			if(!persistence_runtime_var_instance_keys[key] && persistence_runtime_field(I, key)) continue
			keys += key
		region_travel_generic_keys[I.type] = keys
	return keys

// What field key holds on new items of I's type, as a wire value, or RANDOM.
/proc/region_travel_generic_default(atom/movable/I, key)
	var/list/defaults = region_travel_generic_defaults[I.type]
	if(!defaults)
		defaults = list()
		region_travel_generic_defaults[I.type] = defaults
		var/list/samples = list()
		// Only items are sampled: a new animal or structure starts its own
		// work as it is made, so deck cargo is compared with its type's values.
		for(var/i in 1 to (istype(I, /obj/item) ? REGION_TRAVEL_GENERIC_SAMPLES : 0))
			var/atom/movable/fresh = null
			try
				fresh = new I.type(null)
			catch
				fresh = null
			if(fresh)
				samples += fresh
		for(var/name in region_travel_generic_fields_of(I))
			var/first = null
			var/agreed = TRUE
			var/index = 0
			for(var/atom/movable/fresh in samples)
				var/wire = region_travel_generic_wire(fresh.vars[name])
				if(++index == 1)
					first = wire
				else if(wire != first)
					agreed = FALSE
			if(!samples.len)
				first = region_travel_generic_wire(initial(I.vars[name]))
			defaults[name] = agreed ? first : REGION_TRAVEL_GENERIC_RANDOM
		for(var/atom/movable/fresh in samples)
			qdel(fresh)
	return defaults[key]

// The record of item I, or null when it (or anything in it) cannot travel.
// count is a one-item list shared by the whole tree, bounding its size.
// root: I may be deck cargo (a structure or an animal) rather than an item.
/proc/region_travel_generic_capture(atom/movable/I, depth = 0, atom/movable/parent = null, list/count = null, root = FALSE)
	if(!count) count = list(0)
	if(!istype(I) || QDELETED(I) || depth > REGION_TRAVEL_GENERIC_DEPTH || !region_travel_generic_type_ok(I.type, root && !depth)) return null
	count[1] = count[1] + 1
	if(count[1] > REGION_TRAVEL_GENERIC_NODES) return null
	// Saving first lets an item write down what it keeps in runtime fields
	// (a cartridge its bullet's type), exactly as a world save does.
	try
		I.before_save()
	catch
		return null
	var/list/R = list("t" = "[I.type]")
	// What it holds first, so fields that point at those things can name them.
	var/list/children = list()
	var/list/index = list()
	for(var/atom/movable/A in I.contents)
		if(region_travel_ignorable(A)) continue
		if(ismob(A)) return null
		var/list/child = region_travel_generic_capture(A, depth + 1, I, count)
		if(!child) return null
		children += list(child)
		index[A] = children.len
	if(children.len > REGION_TRAVEL_GENERIC_CHILDREN) return null
	if(children.len) R["c"] = children
	var/list/fields = list()
	var/list/nums = list()
	var/list/paths = list()
	var/list/mats = list()
	var/list/links = list()
	var/list/back = list()
	for(var/key in region_travel_generic_fields_of(I))
		if(persistence_runtime_var_instance_keys[key] && I.persistence_runtime_var(key)) continue
		var/value = I.vars[key]
		if(isnull(value) || isnum(value) || istext(value))
			// Cheap first test: unchanged plain fields are most of them.
			if(value == initial(I.vars[key]) && region_travel_generic_default(I, key) == region_travel_generic_wire(value)) continue
		else if(parent && value == parent)
			back += key
			continue
		else if(istype(value, /atom) && index[value])
			links[key] = index[value]
			continue
		else if(islist(value) && length(value))
			var/list/L = value
			var/list/at = list()
			for(var/item in L)
				if(!istype(item, /atom) || !index[item] || !isnull(L[item])) break
				at += index[item]
			if(at.len == L.len)
				links[key] = at
				continue
		var/wire = region_travel_generic_wire(value)
		// Links to anything else stay behind; the item rebuilds them as a new one does.
		if(isnull(wire)) continue
		var/default = region_travel_generic_default(I, key)
		// Left out only when a new item holds the same and never changes it as
		// it is made: a field New() sets, even to one value, always travels, so
		// a colour picked at random is never picked again on arrival.
		if(wire == default && (islist(value) || istype(value, /material) || wire == region_travel_generic_wire(initial(I.vars[key])))) continue
		if(istype(value, /material))
			var/material/M = value
			mats[key] = M.name
		else if(copytext(wire, 1, 5) == "num:")
			nums[key] = copytext(wire, 5)
		else if(copytext(wire, 1, 6) == "path:")
			paths[key] = copytext(wire, 6)
		else
			fields[key] = value
	if(fields.len + nums.len + paths.len > REGION_TRAVEL_GENERIC_FIELDS) return null
	if(fields.len) R["v"] = fields
	if(nums.len) R["n"] = nums
	if(paths.len) R["y"] = paths
	if(mats.len) R["m"] = mats
	if(links.len) R["l"] = links
	if(back.len) R["p"] = back
	if(I.reagents && length(I.reagents.reagent_list))
		var/list/held = list()
		for(var/datum/reagent/A in I.reagents.reagent_list)
			if(!istext(A.id) || !isnum(A.volume)) return null
			held += list(list(A.id, round(A.volume, 0.01)))
		R["r"] = held
	else if(I.reagents)
		R["r"] = list()
	return R

/proc/region_travel_generic_encode(list/R)
	if(!R) return null
	var/kind = "item:[json_encode(R)]"
	return region_travel_generic_record(kind) ? kind : null

// "item:<json>" for item I, or null when it cannot travel.
/proc/region_travel_generic_kind(obj/item/I)
	return region_travel_generic_encode(region_travel_generic_capture(I))

// The kind for an item the "type" kind would rebuild: "type" when a new one
// would be the same, else the whole item, so a name, colour, material or
// loaded magazine is not lost. Never refuses what "type" would take.
/proc/region_travel_generic_or_type(obj/item/I)
	var/list/R = region_travel_generic_capture(I)
	if(!R || !(length(R["v"]) || length(R["n"]) || length(R["m"]) || length(R["l"])))
		return "type"
	return region_travel_generic_encode(R) || "type"

/proc/region_travel_generic_index_ok(value, children)
	return isnum(value) && value >= 1 && value <= children && value == round(value)

/proc/region_travel_generic_record_valid(list/R, depth = 0, list/count = null, root = FALSE)
	if(!count) count = list(0)
	if(!islist(R) || depth > REGION_TRAVEL_GENERIC_DEPTH) return FALSE
	count[1] = count[1] + 1
	if(count[1] > REGION_TRAVEL_GENERIC_NODES) return FALSE
	for(var/key in R)
		if(!(key in list("t", "v", "n", "y", "m", "r", "c", "l", "p"))) return FALSE
	var/path = istext(R["t"]) ? text2path(R["t"]) : null
	if(!region_travel_generic_type_ok(path, root && !depth)) return FALSE
	if(!isnull(R["v"]))
		var/list/fields = R["v"]
		if(!islist(fields) || fields.len > REGION_TRAVEL_GENERIC_FIELDS) return FALSE
		for(var/key in fields)
			if(!region_travel_generic_field_ok(key) || !region_travel_generic_value_ok(fields[key])) return FALSE
	if(!isnull(R["n"]))
		var/list/nums = R["n"]
		if(!islist(nums) || nums.len > REGION_TRAVEL_GENERIC_FIELDS) return FALSE
		for(var/key in nums)
			if(!region_travel_generic_field_ok(key) || !istext(nums[key]) || length(nums[key]) > 40) return FALSE
			var/number = text2num(nums[key])
			if(!isnum(number) || number != number) return FALSE
	if(!isnull(R["y"]))
		var/list/paths = R["y"]
		if(!islist(paths) || paths.len > REGION_TRAVEL_GENERIC_FIELDS) return FALSE
		for(var/key in paths)
			if(!region_travel_generic_field_ok(key) || !istext(paths[key]) || length(paths[key]) > 200 || !ispath(text2path(paths[key]))) return FALSE
	if(!isnull(R["m"]))
		var/list/mats = R["m"]
		if(!islist(mats) || mats.len > 8) return FALSE
		for(var/key in mats)
			if(!region_travel_generic_field_ok(key) || !istext(mats[key]) || !get_material_by_name(mats[key])) return FALSE
	if(!isnull(R["r"]))
		var/list/held = R["r"]
		if(!islist(held) || held.len > 32) return FALSE
		var/total = 0
		for(var/pair in held)
			if(!islist(pair)) return FALSE
			var/list/P = pair
			if(P.len != 2 || !istext(P[1]) || !chemical_reagents_list || !chemical_reagents_list[P[1]]) return FALSE
			if(!isnum(P[2]) || P[2] < 0 || P[2] > REGION_TRAVEL_GENERIC_VOLUME) return FALSE
			total += P[2]
		// The largest container in the game holds a few thousand units.
		if(total > REGION_TRAVEL_GENERIC_VOLUME) return FALSE
	var/children = 0
	if(!isnull(R["c"]))
		var/list/C = R["c"]
		if(!islist(C) || C.len > REGION_TRAVEL_GENERIC_CHILDREN) return FALSE
		for(var/child in C)
			if(!region_travel_generic_record_valid(child, depth + 1, count)) return FALSE
		children = C.len
	if(!isnull(R["l"]))
		var/list/links = R["l"]
		if(!islist(links) || links.len > REGION_TRAVEL_GENERIC_FIELDS) return FALSE
		for(var/key in links)
			if(!region_travel_generic_field_ok(key)) return FALSE
			var/at = links[key]
			if(islist(at))
				var/list/A = at
				if(!A.len || A.len > REGION_TRAVEL_GENERIC_CHILDREN) return FALSE
				for(var/i in A)
					if(!region_travel_generic_index_ok(i, children)) return FALSE
			else if(!region_travel_generic_index_ok(at, children))
				return FALSE
	if(!isnull(R["p"]))
		var/list/back = R["p"]
		if(!islist(back) || back.len > 8 || !depth) return FALSE
		for(var/key in back)
			if(!region_travel_generic_field_ok(key)) return FALSE
	return TRUE

// The checked record of an "item:" kind, or null. root: deck cargo is allowed.
/proc/region_travel_generic_record(kind, root = FALSE)
	if(!istext(kind) || copytext(kind, 1, 6) != "item:" || length(kind) > REGION_TRAVEL_GENERIC_MAX) return null
	var/list/R
	try
		R = json_decode(copytext(kind, 6))
	catch
		return null
	return region_travel_generic_record_valid(R, 0, null, root) ? R : null

// Builds an "item:" kind at where the way a world load restores a saved item:
// constructed as a restore (no first-spawn work such as starting contents,
// random looks or initial reagents), fields applied, then after_load() for
// everything in it, which rebuilds what derives from saved fields (an
// accessory's verbs, a garment's dye).
/proc/region_travel_make_generic(kind, atom/where, root = FALSE)
	var/list/R = region_travel_generic_record(kind, root)
	if(!R) return null
	var/atom/movable/I = region_travel_generic_build(R, where)
	if(!I) return null
	var/list/tree = list(I)
	for(var/i = 1, i <= tree.len, i++)
		var/atom/A = tree[i]
		for(var/obj/item/inside in A.contents)
			tree += inside
	for(var/atom/movable/A in tree)
		try
			A.after_load()
		catch(var/exception/e)
			log_game("Region travel: [A.type] did not finish rebuilding: [e.name] ([e.file]:[e.line]).")
		A.persistence_restore_finished()
	return I

// TRUE when field key of I may be set from a record at all.
/proc/region_travel_generic_link_ok(atom/movable/I, key)
	return (key in I.vars) && region_travel_generic_field_ok(key) && issaved(I.vars[key])

// Sets one field from a record; a value of another class than the item's own,
// or one the engine refuses, is skipped so the arrival goes on.
/proc/region_travel_generic_set(atom/movable/I, key, value)
	if(!(key in I.vars) || !region_travel_generic_field_ok(key) || !issaved(I.vars[key])) return
	var/current = I.vars[key]
	if(!isnull(value) && !isnull(current))
		if(isnum(value) != isnum(current) || istext(value) != istext(current) || islist(value) != islist(current)) return
	if(islist(value))
		var/list/L = value
		value = L.Copy()
	try
		I.vars[key] = value
	catch
		return

// Builds record R at where, or sets up reuse (a part its holder made itself,
// such as a pocket) to match it. Returns the item.
/proc/region_travel_generic_build(list/R, atom/where, atom/movable/reuse = null, atom/movable/parent = null)
	var/path = text2path(R["t"])
	var/list/fields = R["v"]
	var/atom/movable/I = reuse
	if(!I)
		if(ispath(path, /obj/item/stack) && fields && isnum(fields["amount"]))
			var/obj/item/stack/S = path
			fields["amount"] = clamp(round(fields["amount"]), 1, max(1, initial(S.max_amount)))
			persistence_saved_atom_construction++
			try
				I = new path(where, fields["amount"])
			catch
				I = null
			persistence_saved_atom_construction--
		else
			persistence_saved_atom_construction++
			try
				I = new path(where)
			catch
				I = null
			persistence_saved_atom_construction--
	if(!I || QDELETED(I)) return null
	for(var/key in fields)
		region_travel_generic_set(I, key, fields[key])
	var/list/nums = R["n"]
	for(var/key in nums)
		region_travel_generic_set(I, key, text2num(nums[key]))
	var/list/paths = R["y"]
	for(var/key in paths)
		if(region_travel_generic_link_ok(I, key) && (isnull(I.vars[key]) || ispath(I.vars[key])))
			I.vars[key] = text2path(paths[key])
	var/list/mats = R["m"]
	for(var/key in mats)
		if(region_travel_generic_link_ok(I, key) && (isnull(I.vars[key]) || istext(I.vars[key]) || istype(I.vars[key], /material)))
			I.vars[key] = get_material_by_name(mats[key])
	var/list/held = R["r"]
	if(islist(held))
		var/volume = 0
		for(var/list/pair in held)
			volume += pair[2]
		if(!I.reagents && volume > 0)
			I.create_reagents(volume)
		if(I.reagents)
			I.reagents.clear_reagents()
			if(I.reagents.maximum_volume < volume)
				I.reagents.maximum_volume = volume
			for(var/list/pair in held)
				if(pair[2] > 0)
					I.reagents.add_reagent(pair[1], pair[2], safety = TRUE)
	for(var/key in R["p"])
		if(parent && region_travel_generic_link_ok(I, key) && (isnull(I.vars[key]) || isdatum(I.vars[key])))
			try
				I.vars[key] = parent
			catch
				continue
	// Parts a new item made itself are matched by type and set up as recorded;
	// whatever it made that did not travel goes, so nothing is doubled.
	var/list/fresh = list()
	for(var/obj/item/A in I.contents)
		fresh += A
	var/list/made = list()
	for(var/list/child in R["c"])
		var/obj/item/match = null
		for(var/obj/item/A in fresh)
			if("[A.type]" == child["t"])
				match = A
				break
		var/atom/movable/C
		if(match)
			fresh -= match
			C = region_travel_generic_build(child, I, match, I)
		else
			C = region_travel_generic_build(child, I, null, I)
			if(istype(C, /obj/item) && istype(I, /obj/item/weapon/storage))
				var/obj/item/stored = C
				stored.on_enter_storage(I)
		made += C
	if(fresh.len)
		// A field the record does not set must not point at what goes.
		for(var/key in I.vars)
			if(key in region_travel_generic_skip) continue
			var/value = I.vars[key]
			try
				if(istype(value, /atom) && (value in fresh))
					I.vars[key] = null
				else if(islist(value))
					var/list/L = value
					L -= fresh
			catch
				continue
		for(var/obj/item/A in fresh)
			qdel(A)
	var/list/links = R["l"]
	for(var/key in links)
		if(!region_travel_generic_link_ok(I, key)) continue
		var/at = links[key]
		// A list link only into a list field, a single one only into a link field.
		if(islist(at) ? !(isnull(I.vars[key]) || islist(I.vars[key])) : !(isnull(I.vars[key]) || isdatum(I.vars[key]))) continue
		var/value
		if(islist(at))
			var/list/things = list()
			for(var/i in at)
				if(made[i]) things += made[i]
			value = things
		else
			value = made[at]
		try
			I.vars[key] = value
		catch
			continue
	// As a world load does once an entry's fields are in: the item rebuilds
	// what it keeps from them (a cartridge's bullet from its type).
	var/list/saved = list()
	for(var/part in list("v", "n", "y", "m", "l"))
		var/list/names = R[part]
		for(var/key in names)
			saved += key
	try
		I.persistence_import_fields(saved)
	catch
		log_game("Region travel: [I.type] did not take its fields.")
	// A part held inside another (a cartridge's bullet) may not draw itself yet.
	if(!reuse)
		try
			if(isobj(I))
				var/obj/O = I
				O.update_icon()
			else if(ismob(I))
				var/mob/M = I
				M.update_icons()
		catch
			. = I
	return I

#undef REGION_TRAVEL_GENERIC_MAX
#undef REGION_TRAVEL_GENERIC_DEPTH
#undef REGION_TRAVEL_GENERIC_NODES
#undef REGION_TRAVEL_GENERIC_CHILDREN
#undef REGION_TRAVEL_GENERIC_FIELDS
#undef REGION_TRAVEL_GENERIC_TEXT
#undef REGION_TRAVEL_GENERIC_LIST
#undef REGION_TRAVEL_GENERIC_SAMPLES
#undef REGION_TRAVEL_GENERIC_VOLUME
#undef REGION_TRAVEL_GENERIC_RANDOM
