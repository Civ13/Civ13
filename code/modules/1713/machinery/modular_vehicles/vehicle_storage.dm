// Vehicle storage: a garage (cars) or an aircraft hangar (planes) takes a
// stopped, empty vehicle parked in the 4x4 bay northeast of it off the map.
// The bounded vehicle codec turns the car or plane, its fuel, damage, key
// binding and boot cargo into a record and the parts are deleted, so nothing
// of it is simulated, rendered or walked by world saves. The structure keeps
// each record as JSON text in an ordinary saved field, so a world save (Gaia,
// Persistence rounds) carries stored vehicles like the rest of the structure.
// Retrieval rebuilds the same parts where the vehicle was parked.

#define VEHICLE_STORAGE_BAY 4
#define VEHICLE_STORAGE_TIME 50

// What may lie under a stored vehicle's footprint: roads, runways, floors
// laid as covers and stains. Nothing a player could leave as cargo.
/proc/vehicle_storage_ground(atom/movable/O)
	if (istype(O, /obj/covers))
		return !O.density
	return istype(O, /obj/effect/decal/cleanable)

/proc/vehicle_storage_bay(obj/structure/S)
	var/list/bay = list()
	if (!S || !isturf(S.loc))
		return bay
	for (var/dx = 1, dx <= VEHICLE_STORAGE_BAY, dx++)
		for (var/dy = 1, dy <= VEHICLE_STORAGE_BAY, dy++)
			var/turf/T = locate(S.x + dx, S.y + dy, S.z)
			if (T)
				bay += T
	return bay

/proc/vehicle_storage_is_aircraft(obj/structure/vehicleparts/axis/A)
	return istype(A, /obj/structure/vehicleparts/axis/aircraft)

// Vehicles of the requested kind whose whole turning square sits in the bay.
/proc/vehicle_storage_parked(obj/structure/S, aircraft)
	var/list/bay = vehicle_storage_bay(S)
	var/list/found = list()
	for (var/turf/T in bay)
		for (var/obj/structure/vehicleparts/frame/F in T)
			var/obj/structure/vehicleparts/axis/A = F.axis
			if (!A || QDELETED(A) || (A in found) || (vehicle_storage_is_aircraft(A) ? !aircraft : aircraft))
				continue
			var/inside = A.components.len > 0
			for (var/atom/movable/C in A.components)
				if (!(get_turf(C) in bay))
					inside = FALSE
					break
			if (inside)
				found += A
	return found

// Every object in the roots and their nested contents.
/proc/vehicle_storage_objects(list/roots)
	var/list/result = list()
	var/list/queue = roots.Copy()
	while (queue.len && result.len < 1024)
		var/obj/O = queue[queue.len]
		queue.len--
		if (!istype(O) || (O in result))
			continue
		result += O
		for (var/obj/child in O.contents)
			if (!istype(child, /atom/movable/lighting_overlay))
				queue += child
	return result

/proc/vehicle_storage_label(obj/structure/vehicleparts/axis/A)
	var/label = A.name
	if (A.reg_number)
		label = "[label] ([A.reg_number])"
	return label

// Decoded entry or null; the record itself is validated again by decode.
/proc/vehicle_storage_entry(text)
	if (!istext(text) || length(text) > 600000)
		return null
	var/list/entry
	try
		entry = json_decode(text)
	catch
		return null
	if (!islist(entry) || !islist(entry["record"]) || !istext(entry["name"]))
		return null
	if (!isnum(entry["rx"]) || !isnum(entry["ry"]) || entry["rx"] < 1 || entry["ry"] < 1 || entry["rx"] > VEHICLE_STORAGE_BAY || entry["ry"] > VEHICLE_STORAGE_BAY)
		return null
	return entry

/proc/vehicle_storage_key_held(mob/living/human/H, list/record)
	var/list/nodes = record["nodes"]
	if (!islist(nodes) || !nodes.len || !islist(nodes[1]))
		return FALSE
	var/list/scalars = nodes[1]["scalars"]
	if (!islist(scalars) || !scalars["keyed_vehicle_id"])
		return TRUE
	for (var/obj/item/vehicle_key/K in H.contents)
		if (K.loc == H && K.type == /obj/item/vehicle_key && K.vehicle_id == scalars["keyed_vehicle_id"] && K.key_generation == scalars["key_generation"])
			return TRUE
	return FALSE

// Encodes the parked vehicle into stored and removes it from the world.
/proc/vehicle_storage_store(obj/structure/S, list/stored, capacity, aircraft, mob/living/human/H)
	var/noun = aircraft ? "aircraft" : "vehicle"
	if (stored.len >= capacity)
		to_chat(H, SPAN_WARNING("\The [S] is full: it holds [capacity] [noun]\s."))
		return FALSE
	var/list/parked = vehicle_storage_parked(S, aircraft)
	if (!parked.len)
		to_chat(H, SPAN_WARNING("Park the [noun] entirely inside the 4x4 bay northeast of \the [S] first."))
		return FALSE
	var/obj/structure/vehicleparts/axis/A = parked[1]
	if (aircraft)
		var/obj/structure/vehicleparts/axis/aircraft/P = A
		if (P.airborne())
			to_chat(H, SPAN_WARNING("Land the aircraft first."))
			return FALSE
	if (!A.key_access(H))
		to_chat(H, SPAN_WARNING("You need this [noun]'s key to put it away."))
		return FALSE
	// Encode marks parts unsaved even when it refuses; give the flags back.
	var/list/flags = list()
	for (var/obj/O in vehicle_storage_objects(A.components | A.transporting))
		flags[O] = O.should_save
	for (var/turf/T in vehicle_storage_bay(S))
		for (var/obj/O in vehicle_storage_objects(T.contents))
			if (!(O in flags))
				flags[O] = O.should_save
	var/datum/extraction_vehicle_codec/codec = new
	codec.ignore_ground = TRUE
	var/list/record = codec.encode(A)
	var/datum/extraction_vehicle_transfer/transfer = new
	transfer.ignore_ground = TRUE
	if (!record || !transfer.capture(A, TRUE))
		for (var/obj/O in flags)
			if (!QDELETED(O))
				O.should_save = flags[O]
		var/reason = codec.last_error ? codec.last_error : transfer.last_error
		to_chat(H, SPAN_WARNING("\The [S] can't take it[reason ? ": [reason]" : ""]. Stop the engine, get everyone out and clear loose items off it."))
		return FALSE
	var/turf/at = get_turf(A)
	var/label = vehicle_storage_label(A)
	stored += json_encode(list("name" = label, "rx" = at.x - S.x, "ry" = at.y - S.y, "record" = record))
	for (var/obj/item/I in transfer.cargo)
		qdel(I)
	for (var/obj/O in transfer.parts - transfer.cargo)
		for (var/obj/child in O.contents.Copy())
			if (!istype(child, /atom/movable/lighting_overlay))
				qdel(child)
		// A whole frame deleted here is put away, not wrecked.
		if (istype(O, /obj/structure/vehicleparts/frame))
			O:broken = TRUE
		qdel(O)
	log_game("[key_name(H)] stored [label] in [S] at [S.x],[S.y],[S.z].")
	to_chat(H, SPAN_NOTICE("You put [label] away in \the [S]."))
	return TRUE

// Rebuilds stored[index] in the bay and drops it from stored.
/proc/vehicle_storage_retrieve(obj/structure/S, list/stored, index, mob/living/human/H)
	if (index < 1 || index > stored.len)
		return null
	var/list/entry = vehicle_storage_entry(stored[index])
	if (!entry)
		to_chat(H, SPAN_WARNING("That record is unreadable."))
		return null
	if (!vehicle_storage_key_held(H, entry["record"]))
		to_chat(H, SPAN_WARNING("You need the key for [entry["name"]] to take it out."))
		return null
	var/turf/destination = locate(S.x + entry["rx"], S.y + entry["ry"], S.z)
	var/list/bay = vehicle_storage_bay(S)
	if (!destination || !(destination in bay))
		return null
	for (var/list/node in entry["record"]["nodes"])
		if (islist(node) && !node["parent"] && isnum(node["dx"]) && isnum(node["dy"]))
			var/turf/target = locate(destination.x + node["dx"], destination.y + node["dy"], destination.z)
			if (!(target in bay))
				to_chat(H, SPAN_WARNING("[entry["name"]] no longer fits in the bay."))
				return null
	var/datum/extraction_vehicle_codec/codec = new
	codec.ignore_ground = TRUE
	var/obj/structure/vehicleparts/axis/A = codec.decode(entry["record"], destination)
	if (!A)
		to_chat(H, SPAN_WARNING("Clear the bay northeast of \the [S] of people, objects and other vehicles first."))
		return null
	stored.Cut(index, index + 1)
	// Decode builds account-owned parts; a world vehicle is saved with the map.
	var/datum/extraction_vehicle_transfer/transfer = new
	transfer.ignore_ground = TRUE
	if (transfer.capture(A, TRUE))
		for (var/obj/O in vehicle_storage_objects(transfer.parts))
			O.should_save = initial(O.should_save)
	A.should_save = initial(A.should_save)
	if (vehicle_storage_is_aircraft(A))
		A.add_transporting(FALSE)
	log_game("[key_name(H)] took [entry["name"]] out of [S] at [S.x],[S.y],[S.z].")
	to_chat(H, SPAN_NOTICE("You roll [entry["name"]] out of \the [S]."))
	return A

/proc/vehicle_storage_names(list/stored)
	var/list/names = list()
	for (var/i in 1 to stored.len)
		var/list/entry = vehicle_storage_entry(stored[i])
		names += entry ? entry["name"] : "unreadable record"
	return names

// The garage: stores cars (and other ground vehicles the codec supports).
/obj/structure/vehicle_garage
	name = "garage"
	desc = "A roller-door control post for a vehicle bay. Park a stopped, empty car in the 4x4 bay northeast of it to put it away; it waits here, off the road, until you take it out again."
	icon = 'icons/obj/structures.dmi'
	icon_state = "gate_control"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/aircraft = FALSE
	var/capacity = 3
	// One JSON vehicle record per stored vehicle; saved with the structure.
	var/list/stored_vehicles = list()
	var/tmp/busy = FALSE

/obj/structure/vehicle_garage/persistence_runtime_var(key)
	return key == "busy" || ..(key)

/obj/structure/vehicle_garage/after_load()
	..()
	busy = FALSE
	if (!islist(stored_vehicles))
		stored_vehicles = list()

/obj/structure/vehicle_garage/examine(mob/user, distance)
	..()
	var/list/names = vehicle_storage_names(stored_vehicles)
	to_chat(user, names.len ? "Stored ([names.len]/[capacity]): [english_list(names)]." : "It is empty ([capacity] spaces).")

/obj/structure/vehicle_garage/attack_hand(mob/living/human/H)
	if (busy || !istype(H) || !Adjacent(H))
		return
	var/noun = aircraft ? "aircraft" : "vehicle"
	var/list/options = list("Put away the parked [noun]" = "store")
	if (stored_vehicles.len)
		options["Take a [noun] out"] = "retrieve"
	var/list/names = vehicle_storage_names(stored_vehicles)
	var/text = names.len ? "Stored ([names.len]/[capacity]): [english_list(names)]." : "Nothing is stored ([capacity] spaces)."
	var/choice = WWinput(H, "[text] The bay is the 4x4 square northeast of this post.", name, "Cancel", options + list("Cancel"))
	if (!(choice in options) || busy || !Adjacent(H))
		return
	busy = TRUE
	if (!do_after(H, VEHICLE_STORAGE_TIME, src) || QDELETED(src) || !Adjacent(H))
		busy = FALSE
		return
	if (options[choice] == "store")
		vehicle_storage_store(src, stored_vehicles, capacity, aircraft, H)
	else
		var/list/stored_names = vehicle_storage_names(stored_vehicles)
		var/list/picks = list()
		for (var/i in 1 to stored_names.len)
			picks["[i]. [stored_names[i]]"] = i
		var/pick = picks.len == 1 ? picks[1] : WWinput(H, "Choose the [noun] to roll out into the bay.", name, "Cancel", picks + list("Cancel"))
		if (picks[pick] && Adjacent(H))
			vehicle_storage_retrieve(src, stored_vehicles, picks[pick], H)
	busy = FALSE

// Aircraft hangars store planes the same way, in the assembly bay.
/obj/structure/car_workshop/hangar
	var/storage_capacity = 2
	var/list/stored_vehicles = list()

/obj/structure/car_workshop/hangar/after_load()
	..()
	if (!islist(stored_vehicles))
		stored_vehicles = list()

/obj/structure/car_workshop/hangar/examine(mob/user, distance)
	..()
	var/list/names = vehicle_storage_names(stored_vehicles)
	to_chat(user, names.len ? "Hangared ([names.len]/[storage_capacity]): [english_list(names)]." : "No aircraft are hangared ([storage_capacity] spaces).")

/obj/structure/car_workshop/hangar/extra_options()
	. = list("Hangar the parked aircraft" = "store")
	if (stored_vehicles.len)
		.["Roll out a hangared aircraft"] = "retrieve"

/obj/structure/car_workshop/hangar/extra_action(mob/living/human/H, action)
	busy = TRUE
	if (!do_after(H, VEHICLE_STORAGE_TIME, src) || QDELETED(src) || !Adjacent(H))
		busy = FALSE
		return
	if (action == "store")
		vehicle_storage_store(src, stored_vehicles, storage_capacity, TRUE, H)
	else
		var/list/names = vehicle_storage_names(stored_vehicles)
		var/list/picks = list()
		for (var/i in 1 to names.len)
			picks["[i]. [names[i]]"] = i
		var/pick = picks.len == 1 ? picks[1] : WWinput(H, "Choose the aircraft to roll out into the bay.", name, "Cancel", picks + list("Cancel"))
		if (picks[pick] && Adjacent(H))
			vehicle_storage_retrieve(src, stored_vehicles, picks[pick], H)
	busy = FALSE

#undef VEHICLE_STORAGE_BAY
#undef VEHICLE_STORAGE_TIME
