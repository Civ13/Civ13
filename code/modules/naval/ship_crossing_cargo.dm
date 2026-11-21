// ============================================================
// What a crossing ship carries on deck besides items (ship_crossing.dm)
// ------------------------------------------------------------
// Animals and structures (barrels, tables, doors, troughs...) travel whole, as
// a world save keeps them: "g" deck entries holding a cargo record of the
// generic travel kind (persistence/region_travel_generic.dm). The dead travel
// as "b" entries: who they were, how they looked, what they wore and their
// wounds. A body is laid down dead again on arrival; nobody plays it.
//
// Carts, small boats and machines go the same way, empty. Refused still: an
// animal a player or agent controls, anything ridden or strapped in, a loaded
// cart, a frame vehicle or engine, and a body that holds a creature.
// ============================================================

#define SEA_CROSSING_BODY_ITEMS_MAX 40

// A cargo entry for an animal or structure M on deck, list("g", kind), or a
// sentence saying why it stays. A person's cargo never goes without them.
/proc/sea_crossing_cargo_entry(atom/movable/M)
	if (ismob(M))
		var/mob/living/simple_animal/A = M
		if (!istype(A))
			return "[M.name] cannot make the crossing"
		if (A.client || A.ckey || agent_characters[A])
			return "[A.name] is somebody; they must make the crossing themselves"
		if (A.rider)
			return "[A.rider.real_name] must get down from [A.name] first"
	else if (istype(M, /obj))
		var/obj/O = M
		// Living crew get up when she leaves; anyone else strapped in stays put.
		var/mob/living/sat = O.buckled_mob
		if (sat && !(ishuman(sat) && sat.stat != DEAD))
			return "[sat.name] is strapped into [O.name]"
		// A cart or boat goes empty. Living crew riding it get off as she leaves.
		if (istype(O, /obj/structure/vehicle))
			var/obj/structure/vehicle/V = O
			if (length(V.ontop_o))
				return "unload \the [V.name] first"
			for (var/mob/living/rider in V.ontop | list(V.driver))
				if (!(ishuman(rider) && rider.stat != DEAD))
					return "[rider.name] must get off \the [V.name] first"
	var/list/R = region_travel_generic_capture(M, 0, null, null, TRUE)
	var/kind = R ? "item:[json_encode(R)]" : null
	if (!kind || !region_travel_generic_record(kind, TRUE))
		return "[M.name] cannot make the crossing"
	return list("g", kind)

// TRUE when a "g" deck entry is well formed.
/proc/sea_crossing_cargo_valid(list/E)
	return islist(E) && E.len == 2 && istext(E[2]) && !!region_travel_generic_record(E[2], TRUE)

// Builds a "g" entry at T. Returns what was made, or null.
/proc/sea_crossing_cargo_build(list/E, turf/T)
	return region_travel_make_generic(E[2], T, TRUE)

// ---------------------------------------------------------------- the dead

// A body entry for dead human H, list("b", record), or a sentence saying why it stays.
/proc/sea_crossing_body_entry(mob/living/human/H)
	if (!istype(H) || H.stat != DEAD)
		return "a body cannot make the crossing"
	var/label = H.real_name ? "the body of [H.real_name]" : "a body"
	var/list/look = list()
	for (var/name in region_travel_look_vars)
		look[name] = H.vars[name]
	if (!(look["h_style"] in hair_styles_list))
		look -= "h_style"
	if (!(look["f_style"] in facial_hair_styles_list))
		look -= "f_style"
	var/list/items = list()
	var/list/known = list()
	for (var/slot_name in region_travel_slots)
		var/obj/item/I = H.get_equipped_item(region_travel_slots[slot_name])
		if (!I)
			continue
		var/list/entry = region_travel_worn_entry(I)
		if (!entry)
			return "[I.name] on [label] cannot make the crossing"
		items += list(list(slot_name, entry[1], entry[2]))
		known += I
	for (var/atom/movable/A in H)
		if (istype(A, /obj/item/organ) || istype(A, /obj/item/weapon/grab) || (A in known) || region_travel_ignorable(A))
			continue
		return "[A.name] on [label] cannot make the crossing"
	if (items.len > SEA_CROSSING_BODY_ITEMS_MAX)
		return "[label] carries too much to cross"
	var/name = H.real_name
	if (!istext(name) || !length(name) || length(name) > MAX_NAME_LEN)
		name = "Unknown"
	var/list/B = list("name" = name, "gender" = H.gender, "age" = clamp(round(H.age), 1, 200), "look" = look, "items" = items,
		"brute" = clamp(round(H.getBruteLoss()), 0, 200), "burn" = clamp(round(H.getBurnLoss()), 0, 200), "dir" = (H.dir in cardinal) ? H.dir : SOUTH)
	return list("b", B)

// TRUE when a "b" deck entry is well formed.
/proc/sea_crossing_body_valid(list/E)
	if (!islist(E) || E.len != 2 || !islist(E[2]))
		return FALSE
	var/list/B = E[2]
	for (var/key in B)
		if (!(key in list("name", "gender", "age", "look", "items", "brute", "burn", "dir")))
			return FALSE
	if (!istext(B["name"]) || !length(B["name"]) || length(B["name"]) > MAX_NAME_LEN)
		return FALSE
	if (!(B["gender"] in list(MALE, FEMALE, PLURAL, NEUTER)))
		return FALSE
	if (!isnum(B["age"]) || B["age"] < 1 || B["age"] > 200)
		return FALSE
	for (var/field in list("brute", "burn"))
		if (!isnum(B[field]) || B[field] < 0 || B[field] > 200)
			return FALSE
	if (!(B["dir"] in cardinal))
		return FALSE
	if (!islist(B["look"]) || !islist(B["items"]) || length(B["items"]) > SEA_CROSSING_BODY_ITEMS_MAX)
		return FALSE
	for (var/name in B["look"])
		if (!(name in region_travel_look_vars))
			return FALSE
		var/value = B["look"][name]
		if (name == "h_style")
			if (!istext(value) || !(value in hair_styles_list))
				return FALSE
		else if (name == "f_style")
			if (!istext(value) || !(value in facial_hair_styles_list))
				return FALSE
		else if (!isnum(value) || value < -255 || value > 255)
			return FALSE
	for (var/list/entry in B["items"])
		if (!islist(entry) || entry.len != 3 || !(entry[1] in region_travel_slots) || !region_travel_worn_valid(entry[2], entry[3]))
			return FALSE
	return TRUE

// Lays a "b" entry's body down at T, dressed as it was and dead. Returns it.
/proc/sea_crossing_body_build(list/E, turf/T)
	var/list/B = E[2]
	var/mob/living/human/H = new /mob/living/human(T)
	// Never a newcomer: no identity rolled, no job, no starting kit.
	H.persistence_restored = TRUE
	H.gender = B["gender"]
	H.age = B["age"]
	H.fully_replace_character_name(H.real_name, B["name"])
	for (var/name in B["look"])
		H.vars[name] = B["look"][name]
	var/list/later = list()
	for (var/list/entry in B["items"])
		var/obj/item/I = region_travel_make_worn(entry[2], entry[3], T)
		if (!I)
			continue
		if (!H.equip_to_slot_if_possible(I, region_travel_slots[entry[1]], FALSE, TRUE))
			later[I] = region_travel_slots[entry[1]]
	for (var/obj/item/I in later)
		if (!H.equip_to_slot_if_possible(I, later[I], FALSE, TRUE))
			I.forceMove(T)
	if (B["brute"] || B["burn"])
		H.take_overall_damage(B["brute"], B["burn"], "travel")
	H.set_dir(B["dir"])
	H.death()
	H.update_hair(FALSE)
	H.update_body(FALSE)
	H.regenerate_icons()
	return H

#undef SEA_CROSSING_BODY_ITEMS_MAX
