// ============================================================
// What a crossing ship carries on deck besides items (ship_crossing.dm)
// ------------------------------------------------------------
// Animals and structures (barrels, tables, doors, troughs...) travel whole, as
// a world save keeps them: "g" deck entries holding a cargo record of the
// generic travel kind (persistence/region_travel_generic.dm). The dead travel
// as "b" entries: who they were, how they looked, what they wore and their
// wounds. A body is laid down dead again on arrival; nobody plays it.
//
// Carts, small boats and machines go the same way, empty, and engines with
// their fuel tanks coupled again; a canoe or motorboat takes her outboard
// and its tank inside her. A car, truck or light plane parked on deck goes
// whole, as a garage keeps it. Refused still: an animal a player or agent
// controls, anything ridden or strapped in, a loaded cart, a frame vehicle
// the garage record does not take, and a body that holds a creature.
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
	var/atom/movable/made = region_travel_make_generic(E[2], T, TRUE)
	if (istype(made, /obj/structure/vehicle))
		var/obj/structure/vehicle/V = made
		V.crossing_rebuilt()
	return made

// A cart or boat built again from a crossing record. An outboard clamped in
// her crossed inside her; it arrives stopped and coupled to her tank again,
// which the record cannot keep (the two are parts of her, not of each other).
/obj/structure/vehicle/proc/crossing_rebuilt()
	if (!engine || engine.loc != src)
		return
	engine.on = FALSE
	engine.fueltank = (fueltank && fueltank.loc == src) ? fueltank : null
	if (axis)
		engine.connections |= axis
	engine.update_icon()

// A canoe works her outboard from her own tank, never through the engine's.
/obj/structure/vehicle/raft/dugout/outrigger/crossing_rebuilt()
	motor_on = FALSE
	if (engine && engine.loc == src)
		engine.on = FALSE
		engine.fueltank = null
	update_icon()

// ---------------------------------------------------------------- engines

// An engine entry for engine M on deck or in the hold, list("e", kind) or
// list("e", kind, dx, dy) with where its fuel tank stands from it, or a
// sentence saying why it stays. It goes whole like any structure; the tank
// crosses as an item of its own, and the two are coupled again on arrival.
/proc/sea_crossing_engine_entry(obj/structure/engine/M)
	var/list/G = sea_crossing_cargo_entry(M)
	if (istext(G))
		return G
	var/list/E = list("e", G[2])
	var/obj/item/T = M.fueltank
	if (T && isturf(T.loc) && T.z == M.z && abs(T.x - M.x) <= 1 && abs(T.y - M.y) <= 1)
		E += list(T.x - M.x, T.y - M.y)
	return E

// TRUE when an "e" deck entry is well formed.
/proc/sea_crossing_engine_valid(list/E)
	if (!islist(E) || (E.len != 2 && E.len != 4) || !istext(E[2]))
		return FALSE
	var/list/R = region_travel_generic_record(E[2], TRUE)
	if (!R || !ispath(text2path(R["t"]), /obj/structure/engine))
		return FALSE
	if (E.len == 4)
		for (var/i = 3, i <= 4, i++)
			if (!isnum(E[i]) || E[i] != round(E[i]) || abs(E[i]) > 1)
				return FALSE
	return TRUE

// Builds an "e" entry at T, stopped: her crew start it again. Returns it.
/proc/sea_crossing_engine_build(list/E, turf/T)
	var/obj/structure/engine/M = region_travel_make_generic(E[2], T, TRUE)
	if (!istype(M))
		return null
	M.on = FALSE
	M.fueltank = null
	M.update_icon()
	return M

// Couples each engine built from record R to the barrel standing where its
// tank stood. made: everything the build put down.
/proc/sea_crossing_couple_tanks(list/R, list/made, turf/pivot)
	var/list/coupled = list()
	for (var/obj/structure/engine/M in made)
		if (M.fueltank)
			coupled[M.fueltank] = TRUE
	var/list/hold = islist(R["hold"]) ? R["hold"] : list()
	var/list/upper = islist(R["upper"]) ? R["upper"] : list()
	for (var/list/tile in R["tiles"] + hold + upper)
		for (var/list/E in tile[3])
			if (E[1] != "e" || E.len != 4)
				continue
			// The engine this entry made: the first uncoupled one of its type on its tile.
			var/list/G = region_travel_generic_record(E[2], TRUE)
			var/path = G ? text2path(G["t"]) : null
			var/obj/structure/engine/engine = null
			for (var/obj/structure/engine/M in made)
				if (M.type == path && !M.fueltank && M.x == pivot.x + tile[1] && M.y == pivot.y + tile[2])
					engine = M
					break
			if (!engine)
				continue
			var/turf/at = locate(engine.x + E[3], engine.y + E[4], engine.z)
			for (var/obj/item/weapon/reagent_containers/glass/barrel/B in at)
				if (!coupled[B])
					engine.fueltank = B
					B.anchored = TRUE
					coupled[B] = TRUE
					break

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

// ---------------------------------------------------------------- vehicles

// A car, truck or light plane parked on her deck crosses whole, the way a
// garage or a hangar keeps one: the vehicle codec's bounded record of its
// frames, wheels, engine, tank, seats and boot cargo (extraction/vehicle_codec.dm).
// What the codec refuses (a tank's turret, a heavy axis, something loose on
// its tiles) keeps her in port with the codec's reason.

#define SEA_CROSSING_VEHICLES_MAX 8

// Packs every vehicle standing on tiles. list("vehicles" = entries, "claimed"
// = every atom a record holds), or why not. deck: her main deck tiles; a
// vehicle anywhere else, or partly off her deck, cannot cross. pivot: her
// tiller's tile. Writes nothing: each part keeps whether it saves.
/proc/sea_crossing_pack_vehicles(list/tiles, list/deck, turf/pivot)
	var/list/entries = list()
	var/list/claimed = list()
	var/list/seen = list()
	var/list/on_deck = list()
	for (var/turf/T in deck)
		on_deck[T] = TRUE
	for (var/turf/T in tiles)
		for (var/obj/structure/vehicleparts/frame/F in T)
			var/obj/structure/vehicleparts/axis/A = F.axis
			if (F.loc != T || !A || QDELETED(A) || seen[A])
				continue
			seen[A] = TRUE
			for (var/obj/structure/vehicleparts/frame/O in A.components)
				if (!on_deck[get_turf(O)])
					return "drive \the [A.name] wholly onto her main deck"
			var/list/E = sea_crossing_vehicle_entry(A, pivot)
			if (istext(E))
				return E
			entries += list(E["entry"])
			claimed |= E["claimed"]
			if (entries.len > SEA_CROSSING_VEHICLES_MAX)
				return "she carries more than [SEA_CROSSING_VEHICLES_MAX] vehicles"
	return list("vehicles" = entries, "claimed" = claimed)

// One vehicle's entry, list(dx, dy, record) with its axis's tile from her
// pivot, and what it holds, or why it cannot cross.
/proc/sea_crossing_vehicle_entry(obj/structure/vehicleparts/axis/A, turf/pivot)
	var/turf/at = get_turf(A)
	if (!at || A.driver || A.moving || A.currentspeed || (A.engine && A.engine.on))
		return "stop \the [A.name], switch its engine off and get out of it"
	var/list/flags = list()
	for (var/obj/O in vehicle_storage_objects(A.components | list(A)))
		flags[O] = O.should_save
	var/datum/extraction_vehicle_codec/codec = new
	codec.ignore_ground = TRUE
	var/list/record = codec.encode(A)
	var/datum/extraction_vehicle_transfer/transfer = new
	transfer.ignore_ground = TRUE
	var/held = record && transfer.capture(A, TRUE)
	var/list/claimed = held ? vehicle_storage_objects(transfer.parts) : list()
	for (var/obj/O in claimed)
		if (!(O in flags))
			flags[O] = O.should_save
	// Encoding marks the parts unsaved for a garage; she is not gone yet.
	for (var/obj/O in flags)
		if (!QDELETED(O))
			O.should_save = flags[O]
	if (!held)
		var/why = codec.last_error || transfer.last_error
		return "\the [A.name] cannot be carried[why ? " ([why])" : ""]. Only a car or light plane that fits a garage, with nothing loose on it but what is in its boot, can cross"
	return list("entry" = list(at.x - pivot.x, at.y - pivot.y, record), "claimed" = claimed)

// TRUE when record R's vehicles are well formed.
/proc/sea_crossing_vehicles_ok(list/R)
	if (isnull(R["vehicles"]))
		return TRUE
	var/list/V = R["vehicles"]
	if (!islist(V) || !V.len || V.len > SEA_CROSSING_VEHICLES_MAX)
		return FALSE
	var/datum/extraction_vehicle_codec/codec = new
	codec.ignore_ground = TRUE
	for (var/list/E in V)
		if (!islist(E) || E.len != 3 || !isnum(E[1]) || !isnum(E[2]) || abs(E[1]) > 30 || abs(E[2]) > 30 || E[1] != round(E[1]) || E[2] != round(E[2]))
			return FALSE
		if (!codec.validate(E[3]))
			return FALSE
	return TRUE

// Builds record R's vehicles round pivot, parked as they stood. Returns
// everything made. One whose tiles are taken is put down beside her instead
// (sea_crossing_vehicle_ashore) or, failing that, lost and logged.
/proc/sea_crossing_build_vehicles(list/R, turf/pivot)
	. = list()
	for (var/list/E in R["vehicles"])
		var/turf/at = locate(pivot.x + E[1], pivot.y + E[2], pivot.z)
		var/obj/structure/vehicleparts/axis/A = sea_crossing_vehicle_decode(E[3], at)
		if (!A)
			log_game("Sea crossing: a vehicle of the [R["name"]] could not be parked on her deck at [pivot.x],[pivot.y],[pivot.z].")
			continue
		var/datum/extraction_vehicle_transfer/transfer = new
		transfer.ignore_ground = TRUE
		. += A
		if (transfer.capture(A, TRUE))
			. |= vehicle_storage_objects(transfer.parts)

// Decodes one vehicle record with its axis at T, saved like any vehicle. The axis, or null.
/proc/sea_crossing_vehicle_decode(list/record, turf/T)
	if (!T)
		return null
	var/datum/extraction_vehicle_codec/codec = new
	codec.ignore_ground = TRUE
	var/obj/structure/vehicleparts/axis/A = codec.decode(record, T)
	if (!istype(A))
		if (A)
			qdel(A)
		return null
	var/datum/extraction_vehicle_transfer/transfer = new
	transfer.ignore_ground = TRUE
	if (transfer.capture(A, TRUE))
		for (var/obj/O in vehicle_storage_objects(transfer.parts))
			O.should_save = initial(O.should_save)
	A.should_save = initial(A.should_save)
	return A

// A record's vehicles put down near T when no ship can be built: each at the
// first clear spot within a few tiles, or lost and logged.
/proc/sea_crossing_wreck_vehicles(list/R, turf/T)
	for (var/list/E in R["vehicles"])
		var/obj/structure/vehicleparts/axis/A = null
		for (var/turf/near in range(6, T))
			A = sea_crossing_vehicle_decode(E[3], near)
			if (A)
				break
		if (!A)
			log_game("Sea crossing: a vehicle of the [R["name"]] was lost with her: no clear ground near [T.x],[T.y],[T.z].")

// Takes the vehicles parked on tiles off her deck: every part and what is in
// its boot. They crossed in her record.
/proc/sea_crossing_strip_vehicles(list/tiles)
	var/list/seen = list()
	for (var/turf/T in tiles)
		for (var/obj/structure/vehicleparts/frame/F in T)
			var/obj/structure/vehicleparts/axis/A = F.axis
			if (!A || QDELETED(A) || seen[A])
				continue
			seen[A] = TRUE
			var/datum/extraction_vehicle_transfer/transfer = new
			transfer.ignore_ground = TRUE
			if (!transfer.capture(A, TRUE))
				continue
			for (var/obj/item/I in transfer.cargo)
				qdel(I)
			for (var/obj/O in transfer.parts - transfer.cargo)
				for (var/obj/child in O.contents.Copy())
					if (!istype(child, /atom/movable/lighting_overlay))
						qdel(child)
				if (istype(O, /obj/structure/vehicleparts/frame))
					O:broken = TRUE
				if (O != A)
					qdel(O)
			if (!QDELETED(A))
				qdel(A)

#undef SEA_CROSSING_VEHICLES_MAX
