// Region travel, any other item: whatever a traveller wears, holds or keeps in
// a bag, or a ship carries on her deck or in her chests, travels when no
// narrower kind (region_travel.dm, region_travel_gear.dm) fits. It is recorded
// as "item:<json>":
//
//   t  its type, an /obj/item that is not a grab or organ
//   v  every plain field that differs from a new one of its type: numbers,
//      text, and lists of them (names, colours, icon states, amounts, chapters)
//   m  fields that hold a material, by material name
//   r  its reagents, as list(id, volume) pairs
//   c  what it holds, each as its own record, a few levels deep
//
// Fields holding links to other things (a bag's owner, a gun's chambered
// round object) are process state and stay behind; the item rebuilds them as
// a new one does. Anything holding a creature never travels. The record is
// checked field by field on the way in, like every other entry.

#define REGION_TRAVEL_GENERIC_MAX 32768
#define REGION_TRAVEL_GENERIC_DEPTH 3
#define REGION_TRAVEL_GENERIC_CHILDREN 60
#define REGION_TRAVEL_GENERIC_FIELDS 96
#define REGION_TRAVEL_GENERIC_TEXT 8192
#define REGION_TRAVEL_GENERIC_LIST 128

// Fields never recorded nor set: identity, place, drawing state while held,
// forensic marks, and process-local links.
var/global/list/region_travel_generic_skip = list(
	"type", "parent_type", "vars", "contents", "loc", "x", "y", "z", "tag", "key", "ckey",
	"verbs", "locs", "overlays", "underlays", "vis_contents", "vis_locs", "appearance",
	"screen_loc", "layer", "plane", "mouse_opacity", "group", "reagents", "client",
	"animate_movement", "override", "glide_size",
	"fingerprints", "fingerprintshidden", "fingerprintslast", "suit_fibers",
	"gc_destroyed", "datum_flags", "weak_reference", "active_timers",
	"train_transfer_id", "train_transfer_journey", "train_transfer_digest")

// TRUE for things that are never cargo and never stop a trip: flick
// animations and speech bubbles (both named "overlay"), lighting, effects
// such as pointing arrows, and ghosts or admin observers.
/proc/region_travel_ignorable(atom/movable/M)
	return istype(M, /atom/movable/overlay) || istype(M, /obj/chat_text) || istype(M, /obj/effect) || istype(M, /atom/movable/lighting_overlay) || istype(M, /atom/movable/lighting_fullbright) || istype(M, /mob/observer)

/proc/region_travel_generic_type_ok(path)
	if(!ispath(path, /obj/item)) return FALSE
	for(var/denied in list(/obj/item/weapon/grab, /obj/item/organ))
		if(ispath(path, denied)) return FALSE
	return TRUE

/proc/region_travel_generic_field_ok(key)
	return istext(key) && length(key) <= 64 && !(key in region_travel_generic_skip)

// TRUE for a value that crosses as JSON and comes back the same.
/proc/region_travel_generic_value_ok(value, depth = 0)
	if(isnull(value)) return TRUE
	if(isnum(value)) return value == value && abs(value) < 1e15
	if(istext(value)) return length(value) <= REGION_TRAVEL_GENERIC_TEXT
	if(!islist(value) || depth >= 2) return FALSE
	var/list/L = value
	if(L.len > REGION_TRAVEL_GENERIC_LIST) return FALSE
	for(var/k in L)
		if(!istext(k) && !isnum(k)) return FALSE
		if(istext(k) && length(k) > 200) return FALSE
		if(istext(k) && !isnull(L[k]) && !region_travel_generic_value_ok(L[k], depth + 1)) return FALSE
	// A list that is partly keyed, or keyed by numbers, would not come back the same.
	var/text = json_encode(L)
	var/back
	try
		back = json_decode(text)
	catch
		return FALSE
	return json_encode(back) == text

// Per type: what each field holds on a new item, as JSON, or
// REGION_TRAVEL_GENERIC_RANDOM when new items differ (a pelt coat picks its
// colour as it is made). A field matching its default is left out; a field
// with no fixed default always travels, so the rebuilt item does not roll again.
var/global/list/region_travel_generic_defaults = list()
#define REGION_TRAVEL_GENERIC_RANDOM "\[random]"

/proc/region_travel_generic_wire(value)
	if(istype(value, /material))
		var/material/M = value
		return "material:[M.name]"
	if(!region_travel_generic_value_ok(value)) return null
	return json_encode(value)

/proc/region_travel_generic_default(obj/item/I, key)
	var/list/defaults = region_travel_generic_defaults[I.type]
	if(!defaults)
		defaults = list()
		region_travel_generic_defaults[I.type] = defaults
		var/list/samples = list()
		for(var/i in 1 to 3)
			var/obj/item/fresh = null
			try
				fresh = new I.type(null)
			catch
				fresh = null
			if(fresh)
				samples += fresh
		for(var/name in I.vars)
			if(!region_travel_generic_field_ok(name)) continue
			var/first = null
			var/agreed = TRUE
			for(var/obj/item/fresh in samples)
				var/wire = region_travel_generic_wire(fresh.vars[name])
				if(fresh == samples[1])
					first = wire
				else if(wire != first)
					agreed = FALSE
			if(!samples.len)
				first = region_travel_generic_wire(initial(I.vars[name]))
			defaults[name] = agreed ? first : REGION_TRAVEL_GENERIC_RANDOM
		for(var/obj/item/fresh in samples)
			qdel(fresh)
	return defaults[key]

// The record of item I, or null when it (or anything in it) cannot travel.
/proc/region_travel_generic_capture(obj/item/I, depth = 0)
	if(!istype(I) || QDELETED(I) || depth > REGION_TRAVEL_GENERIC_DEPTH || !region_travel_generic_type_ok(I.type)) return null
	var/list/fields = list()
	var/list/mats = list()
	for(var/key in I.vars)
		if(!region_travel_generic_field_ok(key) || I.persistence_runtime_var(key)) continue
		var/value = I.vars[key]
		var/wire = region_travel_generic_wire(value)
		// Links to other things stay behind; the item rebuilds them as a new one does.
		if(isnull(wire)) continue
		var/default = region_travel_generic_default(I, key)
		if(default != REGION_TRAVEL_GENERIC_RANDOM && wire == default) continue
		if(istype(value, /material))
			var/material/M = value
			mats[key] = M.name
		else
			fields[key] = value
	if(fields.len > REGION_TRAVEL_GENERIC_FIELDS) return null
	var/list/R = list("t" = "[I.type]")
	if(fields.len) R["v"] = fields
	if(mats.len) R["m"] = mats
	if(I.reagents && length(I.reagents.reagent_list))
		var/list/held = list()
		for(var/datum/reagent/A in I.reagents.reagent_list)
			if(!istext(A.id) || !isnum(A.volume)) return null
			held += list(list(A.id, round(A.volume, 0.01)))
		R["r"] = held
	else if(I.reagents)
		R["r"] = list()
	var/list/children = list()
	for(var/atom/movable/A in I.contents)
		if(region_travel_ignorable(A)) continue
		if(ismob(A)) return null
		var/list/child = region_travel_generic_capture(A, depth + 1)
		if(!child) return null
		children += list(child)
	if(children.len > REGION_TRAVEL_GENERIC_CHILDREN) return null
	if(children.len) R["c"] = children
	return R

// "item:<json>" for item I, or null when it cannot travel.
/proc/region_travel_generic_kind(obj/item/I)
	var/list/R = region_travel_generic_capture(I)
	if(!R) return null
	var/kind = "item:[json_encode(R)]"
	return region_travel_generic_record(kind) ? kind : null

// TRUE when item I differs from a new one of its type in a way the "type"
// kind would lose: a name, colour, material or other changed field.
/proc/region_travel_generic_has_state(obj/item/I)
	var/list/R = region_travel_generic_capture(I)
	return R && (length(R["v"]) || length(R["m"]))

/proc/region_travel_generic_record_valid(list/R, depth = 0)
	if(!islist(R) || depth > REGION_TRAVEL_GENERIC_DEPTH) return FALSE
	for(var/key in R)
		if(!(key in list("t", "v", "m", "r", "c"))) return FALSE
	var/path = istext(R["t"]) ? text2path(R["t"]) : null
	if(!region_travel_generic_type_ok(path)) return FALSE
	if(!isnull(R["v"]))
		var/list/fields = R["v"]
		if(!islist(fields) || fields.len > REGION_TRAVEL_GENERIC_FIELDS) return FALSE
		for(var/key in fields)
			if(!region_travel_generic_field_ok(key) || !region_travel_generic_value_ok(fields[key])) return FALSE
	if(!isnull(R["m"]))
		var/list/mats = R["m"]
		if(!islist(mats) || mats.len > 8) return FALSE
		for(var/key in mats)
			if(!region_travel_generic_field_ok(key) || !istext(mats[key]) || !get_material_by_name(mats[key])) return FALSE
	if(!isnull(R["r"]))
		var/list/held = R["r"]
		if(!islist(held) || held.len > 32) return FALSE
		for(var/list/pair in held)
			if(!islist(pair) || pair.len != 2 || !istext(pair[1]) || !chemical_reagents_list || !chemical_reagents_list[pair[1]]) return FALSE
			if(!isnum(pair[2]) || pair[2] < 0 || pair[2] > 100000) return FALSE
		for(var/pair in held)
			if(!islist(pair)) return FALSE
	if(!isnull(R["c"]))
		var/list/children = R["c"]
		if(!islist(children) || children.len > REGION_TRAVEL_GENERIC_CHILDREN) return FALSE
		for(var/child in children)
			if(!region_travel_generic_record_valid(child, depth + 1)) return FALSE
	return TRUE

// The checked record of an "item:" kind, or null.
/proc/region_travel_generic_record(kind)
	if(!istext(kind) || copytext(kind, 1, 6) != "item:" || length(kind) > REGION_TRAVEL_GENERIC_MAX) return null
	var/list/R
	try
		R = json_decode(copytext(kind, 6))
	catch
		return null
	return region_travel_generic_record_valid(R) ? R : null

/proc/region_travel_make_generic(kind, atom/where)
	var/list/R = region_travel_generic_record(kind)
	return R ? region_travel_generic_build(R, where) : null

// Builds record R at where, or sets up reuse (a part its holder made itself,
// such as a pocket) to match it. Returns the item.
/proc/region_travel_generic_build(list/R, atom/where, obj/item/reuse = null)
	var/path = text2path(R["t"])
	var/list/fields = R["v"]
	var/obj/item/I = reuse
	if(!I)
		if(ispath(path, /obj/item/stack) && fields && isnum(fields["amount"]) && fields["amount"] >= 1)
			I = new path(where, fields["amount"])
		else
			I = new path(where)
	if(QDELETED(I)) return null
	for(var/key in fields)
		if(!(key in I.vars)) continue
		var/value = fields[key]
		if(islist(value))
			var/list/L = value
			value = L.Copy()
		I.vars[key] = value
	var/list/mats = R["m"]
	for(var/key in mats)
		if(key in I.vars)
			I.vars[key] = get_material_by_name(mats[key])
	if(islist(R["r"]) && I.reagents)
		I.reagents.clear_reagents()
		for(var/list/pair in R["r"])
			if(pair[2] > 0)
				I.reagents.add_reagent(pair[1], pair[2], safety = TRUE)
	// Parts a new item made itself are matched by type and set up as recorded;
	// whatever it made that did not travel goes, so nothing is doubled.
	var/list/fresh = list()
	for(var/obj/item/A in I.contents)
		fresh += A
	for(var/list/child in R["c"])
		var/obj/item/match = null
		for(var/obj/item/A in fresh)
			if("[A.type]" == child["t"])
				match = A
				break
		if(match)
			fresh -= match
			region_travel_generic_build(child, I, match)
		else
			var/obj/item/made = region_travel_generic_build(child, I)
			if(made && istype(I, /obj/item/weapon/storage))
				made.on_enter_storage(I)
	for(var/obj/item/A in fresh)
		qdel(A)
	I.update_icon()
	return I

#undef REGION_TRAVEL_GENERIC_MAX
#undef REGION_TRAVEL_GENERIC_DEPTH
#undef REGION_TRAVEL_GENERIC_CHILDREN
#undef REGION_TRAVEL_GENERIC_FIELDS
#undef REGION_TRAVEL_GENERIC_TEXT
#undef REGION_TRAVEL_GENERIC_LIST
#undef REGION_TRAVEL_GENERIC_RANDOM
