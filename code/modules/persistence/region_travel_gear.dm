// Region travel, worn gear: what a traveller wears or holds may also be a
// material tool or weapon, or a bag with things in it. These two kinds exist
// only for the character's own slots (region_travel_items); freight, landers
// and ship holds keep building by region_travel_item_kind() alone.
//
//   "gear:<json>"  a /obj/item/weapon/material item: type, material, quality,
//                  health and, for an assembled tool, its head and handle.
//   "round:<type>" one live arrow, bolt or cartridge exactly as a new one of
//                  its type (a tipped or altered one does not travel).
//   "bag:<json>"   a /obj/item/weapon/storage item and what it holds, one
//                  level deep. A bag inside a bag does not travel.
//
// Both are checked field by field on the way in, like every other entry.

#define REGION_TRAVEL_BAG_ITEMS_MAX 60

// How a worn or held item travels, or null when it cannot. Anything no
// narrower kind fits travels whole as "item:" (region_travel_generic.dm).
/proc/region_travel_worn_kind(obj/item/I)
	var/kind = region_travel_held_kind(I)
	if(kind) return kind
	kind = region_travel_bag_kind(I)
	if(kind) return kind
	return region_travel_generic_kind(I)

// How an item inside a bag travels: a narrow kind, else whole as "item:".
/proc/region_travel_held_kind(obj/item/I)
	var/kind = region_travel_item_kind(I)
	// Rebuilding by type alone would lose a name, colour or material.
	if(kind == "type")
		return region_travel_generic_or_type(I)
	if(kind) return kind
	return region_travel_loose_kind(I)

// TRUE for a kind built by region_travel_make_loose: gear, a round or a whole item.
/proc/region_travel_loose_prefix(kind)
	return istext(kind) && (copytext(kind, 1, 6) == "gear:" || copytext(kind, 1, 7) == "round:" || copytext(kind, 1, 6) == "item:")

// Gear or a single round: the kinds that may also sit in a bag.
/proc/region_travel_loose_kind(obj/item/I)
	return region_travel_gear_kind(I) || region_travel_round_kind(I)

/proc/region_travel_loose_valid(kind, amount)
	if(amount != 1) return FALSE
	if(copytext(kind, 1, 6) == "item:") return !!region_travel_generic_record(kind)
	if(copytext(kind, 1, 6) == "gear:") return !!region_travel_gear_record(kind)
	if(copytext(kind, 1, 7) == "round:") return !!region_travel_round_path(kind)
	return FALSE

/proc/region_travel_make_loose(kind, atom/where)
	if(copytext(kind, 1, 6) == "gear:") return region_travel_make_gear(kind, where)
	if(copytext(kind, 1, 6) == "item:") return region_travel_make_generic(kind, where)
	var/path = region_travel_round_path(kind)
	return path ? new path(where) : null

/proc/region_travel_round_kind(obj/item/ammo_casing/C)
	if(!istype(C) || QDELETED(C) || !C.BB || !ispath(C.projectile_type) || C.BB.type != C.projectile_type) return null
	if(C.btype != initial(C.btype) || C.name != initial(C.name) || C.contents.len != 1) return null
	if(C.reagents && C.reagents.total_volume) return null
	var/kind = "round:[C.type]"
	return region_travel_round_path(kind) ? kind : null

/proc/region_travel_round_path(kind)
	if(!istext(kind) || copytext(kind, 1, 7) != "round:") return null
	var/obj/item/ammo_casing/path = text2path(copytext(kind, 7))
	if(!ispath(path, /obj/item/ammo_casing) || !ispath(initial(path.projectile_type))) return null
	return path

/proc/region_travel_gear_kind(obj/item/weapon/material/G)
	if(!istype(G) || QDELETED(G) || !G.material || length(G.contents)) return null
	if(G.health <= 0 || G.maxhealth <= 0) return null
	var/list/record = list("t" = "[G.type]", "m" = G.material.name, "q" = round(G.crafting_quality, 0.01),
		"mh" = round(G.maxhealth, 0.01), "h" = round(min(G.health, G.maxhealth), 0.01))
	if(G.tool_head_material && G.tool_handle_material)
		record["p"] = list(G.tool_head_material, G.tool_handle_material, G.tool_head_quality, G.tool_handle_quality, G.tool_head_condition, G.tool_handle_condition)
	var/speed = region_travel_gear_speed(G)
	if(speed) record["s"] = round(speed, 0.01)
	var/kind = "gear:[json_encode(record)]"
	return region_travel_gear_record(kind) ? kind : null

// The work speed a tool family keeps on the item itself (pickaxes and shovels
// as usespeed, hatchets as chopping_speed), or null.
/proc/region_travel_gear_speed(obj/item/weapon/material/G, set_to = null)
	for(var/name in list("usespeed", "chopping_speed"))
		if(name in G.vars)
			if(set_to) G.vars[name] = set_to
			return isnum(G.vars[name]) ? G.vars[name] : null
	return null

// The checked record of a "gear:" kind, or null when any field is out of bounds.
/proc/region_travel_gear_record(kind)
	if(!istext(kind) || copytext(kind, 1, 6) != "gear:" || length(kind) > 400) return null
	var/list/R
	try
		R = json_decode(copytext(kind, 6))
	catch
		return null
	if(!islist(R)) return null
	for(var/key in R)
		if(!(key in list("t", "m", "q", "mh", "h", "p", "s"))) return null
	var/path = istext(R["t"]) ? text2path(R["t"]) : null
	if(!ispath(path, /obj/item/weapon/material)) return null
	if(!istext(R["m"]) || !get_material_by_name(R["m"])) return null
	if(!isnum(R["q"]) || R["q"] < 0.1 || R["q"] > 3) return null
	if(!isnum(R["mh"]) || R["mh"] < 1 || R["mh"] > 10000) return null
	if(!isnum(R["h"]) || R["h"] <= 0 || R["h"] > R["mh"]) return null
	if(!isnull(R["s"]) && (!isnum(R["s"]) || R["s"] < 0.1 || R["s"] > 10)) return null
	if(!isnull(R["p"]))
		var/list/parts = R["p"]
		if(!islist(parts) || parts.len != 6) return null
		for(var/i in 1 to 2)
			if(!istext(parts[i]) || !get_material_by_name(parts[i])) return null
		for(var/i in 3 to 4)
			if(!isnum(parts[i]) || parts[i] < 0.5 || parts[i] > 2) return null
		for(var/i in 5 to 6)
			if(!isnum(parts[i]) || parts[i] < 0 || parts[i] > 1) return null
	return R

/proc/region_travel_make_gear(kind, atom/where)
	var/list/R = region_travel_gear_record(kind)
	if(!R) return null
	var/path = text2path(R["t"])
	var/obj/item/weapon/material/G = new path(where, R["m"])
	if(QDELETED(G) || !G.material) return null
	G.crafting_quality = R["q"]
	var/list/parts = R["p"]
	if(parts)
		G.tool_head_material = parts[1]
		G.tool_handle_material = parts[2]
		G.tool_head_quality = parts[3]
		G.tool_handle_quality = parts[4]
		G.tool_head_condition = parts[5]
		G.tool_handle_condition = parts[6]
	G.update_force()
	G.maxhealth = R["mh"]
	G.health = R["h"]
	if(R["s"]) region_travel_gear_speed(G, R["s"])
	return G

// Names of the things in a bag that cannot travel inside it.
/proc/region_travel_bag_blockers(obj/item/weapon/storage/B)
	. = list()
	for(var/atom/movable/A in B.contents)
		// An empty false bottom stays behind; a full one has to be emptied first.
		if(istype(A, /obj/false_bottom) && !length(A.contents))
			continue
		var/obj/item/I = A
		if(!istype(I) || !(region_travel_item_kind(I) || region_travel_loose_kind(I) || region_travel_generic_kind(I)))
			. += A.name

/proc/region_travel_bag_kind(obj/item/weapon/storage/B)
	if(!istype(B) || QDELETED(B) || B.shown_contents_count() > REGION_TRAVEL_BAG_ITEMS_MAX) return null
	if(length(region_travel_bag_blockers(B))) return null
	var/list/held = list()
	for(var/obj/item/I in B.contents)
		var/kind = region_travel_held_kind(I) || region_travel_generic_kind(I)
		var/amount = 1
		if(kind == "type")
			kind = "[I.type]"
		else if(copytext(kind, 1, 6) == "gear:" || copytext(kind, 1, 7) == "round:" || copytext(kind, 1, 6) == "item:")
			amount = 1
		else if(copytext(kind, 1, 6) == "ammo:")
			amount = region_travel_ammo_count(I)
		else if(istype(I, /obj/item/stack))
			var/obj/item/stack/S = I
			amount = S.amount
		held += list(list(kind, amount))
	var/kind = "bag:[json_encode(list("t" = "[B.type]", "c" = held))]"
	return region_travel_bag_record(kind) ? kind : null

// The checked record of a "bag:" kind, or null when any field is out of bounds.
/proc/region_travel_bag_record(kind)
	if(!istext(kind) || copytext(kind, 1, 5) != "bag:") return null
	var/list/R
	try
		R = json_decode(copytext(kind, 5))
	catch
		return null
	if(!islist(R) || R.len != 2) return null
	var/path = istext(R["t"]) ? text2path(R["t"]) : null
	if(!ispath(path, /obj/item/weapon/storage)) return null
	var/list/held = R["c"]
	if(!islist(held) || held.len > REGION_TRAVEL_BAG_ITEMS_MAX) return null
	for(var/list/entry in held)
		if(!islist(entry) || entry.len != 2 || !istext(entry[1]) || !isnum(entry[2])) return null
		if(region_travel_loose_prefix(entry[1]))
			if(!region_travel_loose_valid(entry[1], entry[2])) return null
		else if(!region_travel_item_path(entry[1], entry[2]))
			return null
	// Every entry was a list: a stray scalar would have been skipped above.
	for(var/entry in held)
		if(!islist(entry)) return null
	return R

/proc/region_travel_make_bag(kind, atom/where)
	var/list/R = region_travel_bag_record(kind)
	if(!R) return null
	var/path = text2path(R["t"])
	var/obj/item/weapon/storage/B = new path(where)
	if(QDELETED(B)) return null
	// A new bag may come filled; it arrives holding exactly what travelled.
	B.startswith = null
	for(var/atom/movable/A in B.contents)
		qdel(A)
	for(var/list/entry in R["c"])
		var/obj/item/I = region_travel_loose_prefix(entry[1]) ? region_travel_make_loose(entry[1], B) : region_travel_make_item(entry[1], entry[2], B)
		if(I) I.on_enter_storage(B)
	B.update_icon()
	return B

// list(kind, amount) for one item as a worn entry writes it, or null when it
// cannot travel. For loads that travel beside the traveller (a pulled cart).
/proc/region_travel_worn_entry(obj/item/I)
	var/kind = region_travel_worn_kind(I)
	if(!kind) return null
	if(kind == "type") return list("[I.type]", 1)
	if(copytext(kind, 1, 6) == "ammo:") return list(kind, region_travel_ammo_count(I))
	if(copytext(kind, 1, 7) == "stack:")
		var/obj/item/stack/S = I
		return list(kind, S.amount)
	return list(kind, 1)

// TRUE when a worn entry (kind, amount) may be rebuilt.
/proc/region_travel_worn_valid(kind, amount)
	if(!istext(kind) || !isnum(amount)) return FALSE
	if(region_travel_loose_prefix(kind)) return region_travel_loose_valid(kind, amount)
	if(copytext(kind, 1, 5) == "bag:") return amount == 1 && !!region_travel_bag_record(kind)
	return !!region_travel_item_path(kind, amount)

// Makes one worn entry at T as it left, or null when it is not allowed.
/proc/region_travel_make_worn(kind, amount, turf/T)
	if(region_travel_loose_prefix(kind)) return region_travel_make_loose(kind, T)
	if(copytext(kind, 1, 5) == "bag:") return region_travel_make_bag(kind, T)
	return region_travel_make_item(kind, amount, T)

// TRUE when the item a reloaded body holds is the one a recorded entry took.
// Gear and bags match by type: their wear or load may be older in the save.
/proc/region_travel_worn_matches(obj/item/I, kind)
	if(copytext(kind, 1, 6) == "gear:")
		var/list/R = region_travel_gear_record(kind)
		return R && istype(I, /obj/item/weapon/material) && "[I.type]" == R["t"]
	if(copytext(kind, 1, 5) == "bag:")
		var/list/R = region_travel_bag_record(kind)
		return R && istype(I, /obj/item/weapon/storage) && "[I.type]" == R["t"]
	if(copytext(kind, 1, 7) == "round:")
		return istype(I, /obj/item/ammo_casing) && "[I.type]" == copytext(kind, 7)
	if(copytext(kind, 1, 6) == "item:")
		var/list/R = region_travel_generic_record(kind)
		return R && "[I.type]" == R["t"]
	var/own = region_travel_item_kind(I)
	return own == "type" ? "[I.type]" == kind : own == kind

#undef REGION_TRAVEL_BAG_ITEMS_MAX
