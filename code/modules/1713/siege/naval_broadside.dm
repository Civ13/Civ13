// ============================================================
// Broadsides
// ------------------------------------------------------------
// A ship's captain blows the boatswain's call and every loaded black-powder
// gun on one side of the ship fires in a ripple, each where its crew aimed
// it. The guns are the ordinary cannons; this only adds the order.
// ============================================================

#define BROADSIDE_RANGE 20        // Guns this far from the captain can answer the call.
#define BROADSIDE_RIPPLE 3        // Ticks between one gun and the next.
#define BROADSIDE_COOLDOWN 100    // Ticks before the call can be blown again.

// The ship a turf belongs to, as the area path up to ".../ship", or null.
/proc/broadside_ship_of(turf/T)
	if (!istype(T))
		return null
	var/area/A = get_area(T)
	if (!A)
		return null
	var/path = "[A.type]"
	var/at = findtext(path, "/ship")
	if (!at)
		return null
	return copytext(path, 1, at + 5)

// The ship a gun stands on. Guns set into the hull stand in the hull's area,
// so the deck behind the gun decides.
/proc/broadside_gun_ship(obj/structure/cannon/C)
	. = broadside_ship_of(get_turf(C))
	if (!.)
		. = broadside_ship_of(get_step(C, turn(C.dir, 180)))

// Black-powder guns only: not tanks, rockets or modern naval turrets.
/proc/broadside_gun_ok(obj/structure/cannon/C)
	return istype(C) && !istype(C, /obj/structure/cannon/modern) && !istype(C, /obj/structure/cannon/rocket) && !C.broken && C.loaded.len

// Loaded guns on the ship that holds turf T, grouped by the way they face:
// list("[dir]" = list(guns)).
/proc/broadside_guns(turf/T)
	. = list()
	var/ship = broadside_ship_of(T)
	if (!ship)
		return
	for (var/obj/structure/cannon/C in range(BROADSIDE_RANGE, T))
		if (C.z != T.z || !broadside_gun_ok(C) || broadside_gun_ship(C) != ship)
			continue
		var/key = "[C.dir]"
		if (!.[key])
			.[key] = list()
		.[key] += C

// Fires the guns in order, one every BROADSIDE_RIPPLE ticks. Returns how many.
/proc/broadside_fire(list/guns)
	var/n = 0
	for (var/obj/structure/cannon/C in guns)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(broadside_fire_gun), C), 1 + n * BROADSIDE_RIPPLE)
		n++
	return n

/proc/broadside_fire_gun(obj/structure/cannon/C)
	if (QDELETED(C) || !broadside_gun_ok(C))
		return FALSE
	// Guns never aimed still point the way the map set them.
	var/facing = dir2angle(C.dir)
	if (abs(C.azimuth - facing) > 45 && abs(C.azimuth - facing) < 315)
		C.azimuth = facing
	C.max_distance = C.maxrange
	C.get_target_coords()
	C.discharge(null)
	return TRUE

/obj/item/weapon/whistle/broadside
	name = "boatswain's call"
	desc = "A captain's whistle. Blow it on deck and every loaded gun on one side of the ship fires."
	var/tmp/next_call = 0

/obj/item/weapon/whistle/broadside/attack_self(mob/user as mob)
	if (world.time < next_call)
		to_chat(user, SPAN_WARNING("The crews are still sponging out. Wait a moment."))
		return
	if (map && !map.faction1_can_cross_blocks() && !map.faction2_can_cross_blocks())
		to_chat(user, SPAN_WARNING("You can't fire yet."))
		return
	var/turf/T = get_turf(user)
	if (!broadside_ship_of(T))
		to_chat(user, SPAN_WARNING("You need to be aboard your ship to order a broadside."))
		return
	var/list/sides = broadside_guns(T)
	if (!sides.len)
		to_chat(user, SPAN_WARNING("No gun on this ship is loaded."))
		return
	var/key = sides[1]
	if (sides.len > 1)
		var/list/choices = list()
		for (var/k in sides)
			choices["[dir2text(text2num(k))] side ([length(sides[k])] guns)"] = k
		var/picked = player_input(user, "Which side fires?", "Broadside", null, "list", choices, TRUE)
		if (!picked || !choices[picked] || QDELETED(src) || loc != user)
			return
		key = choices[picked]
		sides = broadside_guns(get_turf(user))
		if (!sides[key])
			return
	next_call = world.time + BROADSIDE_COOLDOWN
	playsound(get_turf(user), whistle_sound, 100, FALSE, 5)
	user.visible_message(SPAN_DANGER("[user] blows the boatswain's call: \"Fire!\""))
	broadside_fire(sides[key])

#undef BROADSIDE_RANGE
#undef BROADSIDE_RIPPLE
#undef BROADSIDE_COOLDOWN

// Ship captains on the Naval Battle get the call.
/proc/broadside_give_call(mob/living/human/H)
	if (!istype(H) || !map || map.ID != MAP_NAVAL)
		return FALSE
	var/obj/item/weapon/whistle/broadside/B = new(H)
	if (!H.equip_to_slot_if_possible(B, slot_r_store, disable_warning = TRUE) && !H.put_in_hands(B))
		B.forceMove(get_turf(H))
	H.add_note("Broadside", "Use your <b>boatswain's call</b> on deck: every loaded gun on the side you pick fires, each where its crew aimed it.")
	return TRUE
