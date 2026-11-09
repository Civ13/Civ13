// The aircraft carrier: a turf-built vessel (vessel.dm) of three decks on
// three stacked levels. The hangar deck lies below the waterline on the level
// under the surface (Gaia's cave level, the sea layer), the flight deck is the
// surface level and the island stands on the open-air level above.
//
// Ship coordinates: u runs stern (0) to bow (39), v port (0) to starboard (8).
// The hangar deck is a hull of submarine pressure-hull and bulkhead turfs
// around six watertight compartments; its deck tiles report to the carrier's
// own flooding controller through vessel_at().

#define CARRIER_LENGTH 40
#define CARRIER_BEAM 9

// ---- Turfs ----

/turf/floor/plating/carrier_deck
	name = "flight deck"
	desc = "Steel flight deck plating. Aircraft take off and land on it like a runway."
	icon_state = "plating"
	// The deck is a runway; the island deck above is not.
	var/runway = TRUE
	// A blast tears the plating open: no runway until it is welded shut.
	var/cratered = FALSE

/turf/floor/plating/carrier_deck/aircraft_runway()
	return runway && !cratered

// Deck plating is never torn out of the ship: a blast craters it.
/turf/floor/plating/carrier_deck/ex_act(severity)
	switch(severity)
		if (1)
			crater()
		if (2)
			if (prob(60))
				crater()
		if (3)
			if (prob(15))
				crater()

/turf/floor/plating/carrier_deck/proc/crater(quiet = FALSE)
	if (cratered)
		return
	cratered = TRUE
	name = "cratered [initial(name)]"
	overlays += image(icon = 'icons/turf/damage_overlays.dmi', icon_state = pick("damaged1", "damaged2", "damaged3"))
	if (!quiet)
		visible_message(SPAN_DANGER("The deck plating buckles and tears open!"))

/turf/floor/plating/carrier_deck/proc/repair_crater()
	if (!cratered)
		return
	cratered = FALSE
	name = initial(name)
	overlays.Cut()

/turf/floor/plating/carrier_deck/attackby(obj/item/weapon/W, mob/user)
	if (istype(W, /obj/item/weapon/weldingtool) && cratered)
		to_chat(user, SPAN_NOTICE("You begin welding new plating over the crater..."))
		if (do_after(user, 100, src) && cratered)
			repair_crater()
			to_chat(user, SPAN_NOTICE("The deck is whole again."))
		return
	..()

// Craters ride a hop with the deck.
/turf/floor/plating/carrier_deck/vessel_capture()
	return list("cratered" = cratered)

/turf/floor/plating/carrier_deck/vessel_restore(list/state)
	if (state["cratered"])
		crater(TRUE)

/turf/floor/plating/carrier_deck/aircraft_deck()
	return runway

// The arresting wires across the after deck: a plane that touches down on
// them is caught and stopped on the spot.
/turf/floor/plating/carrier_deck/wires
	name = "arresting wires"
	desc = "Steel flight deck plating with arresting wires stretched across it. A landing plane's tailhook catches here."

/turf/floor/plating/carrier_deck/wires/arrests_aircraft()
	return TRUE

// The deck elevator platform: a 4x4 square that moves with the hangar
// elevator floor below it (vessel_lever/elevator).
/turf/floor/plating/carrier_deck/elevator
	name = "deck elevator"
	desc = "The platform of an aircraft elevator, flush with the flight deck. The lever beside it lowers whatever stands on it to the hangar."

// Catapult track at the bow: runway like the rest, but the catapult lever
// beside it throws a plane standing on it straight into the air.
/turf/floor/plating/carrier_deck/catapult
	name = "catapult track"
	desc = "Steel flight deck plating with the catapult shuttle track let into it. A plane parked on the track, nose to the bow, is launched by the lever beside it."

// A sponson at each corner of the deck for a mounted gun: not runway.
/turf/floor/plating/carrier_deck/gun_tub
	name = "gun tub"
	desc = "A railed sponson at the deck's edge for a mounted gun. Planes keep off it."
	runway = FALSE

/turf/floor/plating/carrier_deck/island
	name = "island deck"
	desc = "The deck of the carrier's island."
	runway = FALSE

/turf/wall/sub_hull/carrier
	name = "carrier hull"
	desc = "The riveted steel hull of an aircraft carrier, below the waterline."

/turf/wall/sub_bulkhead/carrier
	name = "carrier bulkhead"

/turf/floor/sub_deck/carrier
	name = "hangar deck floor"

/turf/floor/sub_deck/carrier/forward
	name = "forward compartment floor"
	compartment_id = CARRIER_COMP_FORWARD

/turf/floor/sub_deck/carrier/magazine
	name = "magazine floor"
	compartment_id = CARRIER_COMP_MAGAZINE

/turf/floor/sub_deck/carrier/hangar
	name = "hangar deck floor"
	compartment_id = CARRIER_COMP_HANGAR

/turf/floor/sub_deck/carrier/hangar/elevator
	name = "hangar elevator floor"
	desc = "The floor of an aircraft elevator, flush with the hangar deck. The lever beside it lifts whatever stands on it to the flight deck."

/turf/floor/sub_deck/carrier/quarters
	name = "crew quarters floor"
	compartment_id = CARRIER_COMP_QUARTERS

/turf/floor/sub_deck/carrier/bunker
	name = "fuel bunker floor"
	compartment_id = CARRIER_COMP_BUNKER

/turf/floor/sub_deck/carrier/engine_room
	name = "engine room floor"
	compartment_id = CARRIER_COMP_ENGINE_ROOM

// ---- The ship ----

/datum/vessel/carrier
	name = "aircraft carrier"
	length = CARRIER_LENGTH
	beam = CARRIER_BEAM

/datum/vessel/carrier/New()
	..()
	levels += carrier_hangar_level()
	levels += carrier_flight_deck_level()
	levels += carrier_island_level()

// The hangar deck, one level under the surface. Stern to bow: engine room,
// fuel bunker (with the bunker filling point), crew quarters, hangar,
// magazine with two bomb racks, forward compartment (sick bay and CIC), each behind a bulkhead
// with one blast door on the centreline. Two 4x4 elevator floors sit on the
// port side of the hangar, under the flight deck elevators, each with its
// lever on the tile aft of it.
/proc/carrier_hangar_level()
	var/datum/vessel_level/L = new
	L.dz = -1
	L.allowed = list(/turf/wall/rockwall, /turf/floor/beach/water/deep)
	var/wall = ".HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH."
	var/room = ".HeeeeBffBqqqBaaaaaaaaaaaaaaaaBmmBccccH."
	var/lift = ".HeeeeBffBqqqBEEEEaaaaaaaaEEEEBmRBccccH."
	var/lever = ".HeeeeBTfBqqqBEEEEVaaaaaaVEEEEBmmBccccH."
	var/doors = ".Heeee1ff2qqq3EEEEaaLaaaaaEEEE4mm5ccccH."
	L.rows = list(wall, lift, lever, lift, doors, room, room, room, wall)
	L.legend = list(
		"H" = list("turf" = /turf/wall/sub_hull/carrier),
		"B" = list("turf" = /turf/wall/sub_bulkhead/carrier),
		"e" = list("turf" = /turf/floor/sub_deck/carrier/engine_room),
		"f" = list("turf" = /turf/floor/sub_deck/carrier/bunker),
		"q" = list("turf" = /turf/floor/sub_deck/carrier/quarters),
		"a" = list("turf" = /turf/floor/sub_deck/carrier/hangar),
		"m" = list("turf" = /turf/floor/sub_deck/carrier/magazine),
		"c" = list("turf" = /turf/floor/sub_deck/carrier/forward),
		"1" = list("turf" = /turf/floor/sub_deck/carrier/bunker, "spawn" = list(/obj/structure/simple_door/blast)),
		"2" = list("turf" = /turf/floor/sub_deck/carrier/quarters, "spawn" = list(/obj/structure/simple_door/blast)),
		"3" = list("turf" = /turf/floor/sub_deck/carrier/hangar, "spawn" = list(/obj/structure/simple_door/blast)),
		"4" = list("turf" = /turf/floor/sub_deck/carrier/magazine, "spawn" = list(/obj/structure/simple_door/blast)),
		"5" = list("turf" = /turf/floor/sub_deck/carrier/forward, "spawn" = list(/obj/structure/simple_door/blast)),
		"L" = list("turf" = /turf/floor/sub_deck/carrier/hangar, "spawn" = list(/obj/structure/multiz/ladder/up)),
		"E" = list("turf" = /turf/floor/sub_deck/carrier/hangar/elevator),
		"V" = list("turf" = /turf/floor/sub_deck/carrier/hangar, "spawn" = list(/obj/structure/vessel_lever/elevator)),
		"T" = list("turf" = /turf/floor/sub_deck/carrier/bunker, "spawn" = list(/obj/structure/vessel_bunker)),
		"R" = list("turf" = /turf/floor/sub_deck/carrier/magazine, "spawn" = list(/obj/structure/shellrack/bombs)),
	)
	return L

// The flight deck at the surface: plating from stern to bow, every tile a
// runway but the four gun tubs at the corners. Arresting wires cross the
// after deck (u 6-9), two elevator platforms lie on the port side over the
// hangar elevators with their levers beside them, the catapult track runs
// along the port side of the bow (u 35-38) with its lever aft of it, deck
// lights stand along both edges, a ladder goes down to the hangar amidships
// and another up to the island on the starboard side.
/proc/carrier_flight_deck_level()
	var/datum/vessel_level/L = new
	L.dz = 0
	L.allowed = list(/turf/floor/beach/water/deep)
	var/edge = "GFFlFFAAAAFFlFFFlFFFlFFFlFFFlFFFlFFFlFFG"
	var/cat1 = "FFFFFFAAAAFFFFEEEEFFFFFFFFEEEEFFFFFCCCCF"
	var/cat2 = "FFFFFFAAAAFFFFEEEEVFFFFFFVEEEEFFFFYCCCCF"
	var/hatch = "FFFFFFAAAAFFFFEEEEFFKFFFFFEEEEFFFFFFFFFF"
	var/deck = "FFFFFFAAAAFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
	var/stair = "FFFFFFAAAAFFFFFFFFUFFFFFFFFFFFFFFFFFFFFF"
	L.rows = list(edge, cat1, cat2, cat1, hatch, deck, stair, deck, edge)
	L.legend = list(
		"F" = list("turf" = /turf/floor/plating/carrier_deck),
		"A" = list("turf" = /turf/floor/plating/carrier_deck/wires),
		"E" = list("turf" = /turf/floor/plating/carrier_deck/elevator),
		"C" = list("turf" = /turf/floor/plating/carrier_deck/catapult),
		"G" = list("turf" = /turf/floor/plating/carrier_deck/gun_tub),
		"l" = list("turf" = /turf/floor/plating/carrier_deck, "spawn" = list(/obj/structure/lamp/lamp_small/alwayson/deck)),
		"V" = list("turf" = /turf/floor/plating/carrier_deck, "spawn" = list(/obj/structure/vessel_lever/elevator)),
		"Y" = list("turf" = /turf/floor/plating/carrier_deck, "spawn" = list(/obj/structure/vessel_lever/catapult)),
		"K" = list("turf" = /turf/floor/plating/carrier_deck, "spawn" = list(/obj/structure/multiz/ladder)),
		"U" = list("turf" = /turf/floor/plating/carrier_deck, "spawn" = list(/obj/structure/multiz/ladder/up)),
	)
	return L

// The island on the open-air level: a 5x3 superstructure on the starboard
// side amidships with the helm, the radar set and two searchlights, reached
// by the flight deck ladder.
/proc/carrier_island_level()
	var/datum/vessel_level/L = new
	L.dz = 1
	L.allowed = list(/turf/sky)
	var/empty = "........................................"
	var/top = "..................JIIII................."
	var/mid = "..................IIWIR................."
	var/low = "..................SIIIS................."
	L.rows = list(empty, empty, empty, empty, empty, empty, top, mid, low)
	L.legend = list(
		"I" = list("turf" = /turf/floor/plating/carrier_deck/island),
		"J" = list("turf" = /turf/floor/plating/carrier_deck/island, "spawn" = list(/obj/structure/multiz/ladder)),
		"W" = list("turf" = /turf/floor/plating/carrier_deck/island, "spawn" = list(/obj/structure/vessel_helm)),
		"R" = list("turf" = /turf/floor/plating/carrier_deck/island, "spawn" = list(/obj/structure/vessel_radar)),
		"S" = list("turf" = /turf/floor/plating/carrier_deck/island, "spawn" = list(/obj/structure/searchlight)),
	)
	return L

// Ladders spawned at runtime pair up here; map-placed ones pair in initialize().
// Planes taxi over the deck ladders, so a vehicle must not crush them
// (add_transporting leaves ladders and levers where they stand).
/datum/vessel/carrier/relocate(x, y, heading)
	. = ..()
	if (.)
		for (var/turf/T in cells())
			for (var/obj/structure/multiz/M in T)
				M.crushable = FALSE
				M.find_target()

// Lays a carrier down with its south-west corner at origin, bow to heading.
// Returns the vessel, or null with the reason in the last vessel's refusal.
/proc/carrier_lay_down(turf/origin, heading = EAST)
	if (!origin)
		return null
	var/datum/vessel/carrier/C = new
	if (!C.place(origin.x, origin.y, origin.z, heading))
		var/reason = C.last_refusal
		qdel(C)
		return list("refused" = reason)
	return C

// ---- Helm ----

// The ship's wheel on the island: speed, heading and anchor. The chart,
// telegraph and bridge fittings of later phases build on it.
/obj/structure/vessel_helm
	name = "ship's wheel"
	desc = "The ship's wheel and engine telegraph."
	icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	icon_state = "ship_wheel"
	anchored = TRUE
	density = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/tmp/datum/vessel/vessel
	// The ship's save_state() text, written before a save and read on load:
	// the decks come back as turfs, the vessel datum from this.
	var/vessel_state = ""

/obj/structure/vessel_helm/New(loc)
	..()
	vessel = vessel_at(get_turf(src))

/obj/structure/vessel_helm/before_save()
	..()
	if (vessel && vessel.placed)
		vessel_state = vessel.save_state()

// After a load the decks are on the map but no vessel claims them yet: the
// helm rebuilds its ship from the saved state, once.
/obj/structure/vessel_helm/after_load()
	..()
	vessel = vessel_at(get_turf(src))
	if (!vessel && vessel_state)
		vessel = vessel_restore_state(vessel_state)

/obj/structure/vessel_helm/proc/status_text()
	if (!vessel)
		return "The wheel is not connected to a ship."
	var/list/speeds = list("all stop", "slow ahead", "half ahead", "full ahead")
	return "[capitalize(vessel.name)]: [speeds[vessel.speed + 1]], bow to the [dir2text(vessel.dir)], anchor [vessel.anchored ? "down" : "up"]."

/obj/structure/vessel_helm/examine(mob/user)
	..()
	to_chat(user, status_text())

/obj/structure/vessel_helm/attack_hand(mob/living/human/H)
	if (!istype(H) || !vessel)
		return ..()
	var/list/options = list("Chart", "Full ahead", "Half ahead", "Slow ahead", "All stop", "Head north", "Head east", "Head south", "Head west", vessel.anchored ? "Weigh anchor" : "Drop anchor", vessel.deck_lights_on ? "Deck lights off" : "Deck lights on", "Cancel")
	var/choice = WWinput(H, status_text(), name, "Cancel", options)
	if (!choice || choice == "Cancel" || !vessel || get_dist(H, src) > 1)
		return
	if (choice == "Chart")
		to_chat(H, vessel.chart_text())
		return
	if ((choice in list("Full ahead", "Half ahead", "Slow ahead")) && vessel.fuel < vessel.fuel_burn(VESSEL_SPEED_SLOW))
		to_chat(H, SPAN_WARNING("The bunkers are dry: pour fuel oil into the bunker filling point below decks first."))
		return
	switch (choice)
		if ("Full ahead") vessel.set_speed(VESSEL_SPEED_FULL)
		if ("Half ahead") vessel.set_speed(VESSEL_SPEED_HALF)
		if ("Slow ahead") vessel.set_speed(VESSEL_SPEED_SLOW)
		if ("All stop") vessel.set_speed(VESSEL_SPEED_STOP)
		if ("Weigh anchor") vessel.set_anchor(FALSE)
		if ("Drop anchor") vessel.set_anchor(TRUE)
		if ("Deck lights on") vessel.set_deck_lights(TRUE)
		if ("Deck lights off") vessel.set_deck_lights(FALSE)
		if ("Head north", "Head east", "Head south", "Head west")
			var/heading = text2dir(copytext(choice, 6))
			if (vessel.anchored)
				to_chat(H, SPAN_WARNING("Weigh anchor before coming about."))
				return
			if (!vessel.turn_to(heading))
				to_chat(H, SPAN_WARNING("The ship cannot come about here: [vessel.last_refusal]."))
				return
	vessel.crew_message(SPAN_NOTICE("[H] at the wheel: [choice]. [status_text()]"))

// ---- Bunkers ----

// The filling point in the fuel bunker compartment. Pour diesel or petroleum
// from any container into it; the ship burns VESSEL_FUEL_PER_STEP units per
// telegraph step on every hop. The fuel itself is the vessel's ledger, so it
// rides along and is saved with the helm.
/obj/structure/vessel_bunker
	name = "bunker filling point"
	desc = "The filling valve of the ship's fuel bunkers. Pour diesel or petroleum into it."
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "ballast"
	anchored = TRUE
	density = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/tmp/datum/vessel/vessel

/obj/structure/vessel_bunker/proc/ship()
	if (!vessel)
		vessel = vessel_at(get_turf(src))
	return vessel

/obj/structure/vessel_bunker/examine(mob/user)
	..()
	var/datum/vessel/V = ship()
	to_chat(user, V ? "The bunkers hold [V.fuel] of [V.fuel_capacity] units of fuel oil." : "The valve is not connected to a ship.")

// Pouring: takes every unit of diesel and petroleum the container holds, up
// to what the bunkers have room for. Other reagents stay in the container.
/obj/structure/vessel_bunker/attackby(obj/item/I, mob/living/human/H)
	var/obj/item/weapon/reagent_containers/C = I
	if (!istype(C) || !C.reagents)
		return ..()
	var/datum/vessel/V = ship()
	if (!V)
		to_chat(H, SPAN_WARNING("The valve is not connected to a ship."))
		return
	var/poured = 0
	for (var/fuel_id in list("diesel", "petroleum"))
		var/have = C.reagents.get_reagent_amount(fuel_id)
		if (have <= 0)
			continue
		var/taken = V.bunker(have)
		if (taken > 0)
			C.reagents.remove_reagent(fuel_id, taken)
			poured += taken
	if (!poured)
		to_chat(H, SPAN_WARNING(V.fuel >= V.fuel_capacity ? "The bunkers are full." : "\The [C] holds no diesel or petroleum."))
		return
	to_chat(H, SPAN_NOTICE("You pour [poured] units of fuel oil into the bunkers: [V.fuel] of [V.fuel_capacity]."))

// ---- Aircraft elevator ----

// How far from its lever an elevator platform's tiles can lie. The two
// platforms are nine tiles apart, so each lever reaches only its own.
#define VESSEL_ELEVATOR_REACH 5

// A lever on a vessel's deck. Planes taxi over it: vehicles neither crush
// nor carry it (axis.dm keeps /obj/structure/vessel_lever where it stands).
/obj/structure/vessel_lever
	icon = 'icons/obj/vehicles/train_lever.dmi'
	icon_state = "lever_none"
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	crushable = FALSE
	var/tmp/datum/vessel/vessel
	var/tmp/busy = FALSE

/obj/structure/vessel_lever/New(loc)
	..()
	vessel = vessel_at(get_turf(src))

/obj/structure/vessel_lever/proc/ship()
	if (!vessel)
		vessel = vessel_at(get_turf(src))
	return vessel

// The lever beside an elevator platform. On the flight deck it lowers what
// stands on the platform to the hangar; in the hangar it lifts it to the
// flight deck. Aircraft move whole (every frame must be on the platform),
// crew and cargo tile by tile.
/obj/structure/vessel_lever/elevator
	name = "elevator lever"
	desc = "The control lever of an aircraft elevator. Pull it to move whatever stands on the platform beside it to the other deck."

// The platform tiles this lever serves, on its own level.
/obj/structure/vessel_lever/elevator/proc/platform()
	. = list()
	var/turf/here = get_turf(src)
	if (!here)
		return
	for (var/turf/T in range(VESSEL_ELEVATOR_REACH, here))
		if (T.z == here.z && (istype(T, /turf/floor/plating/carrier_deck/elevator) || istype(T, /turf/floor/sub_deck/carrier/hangar/elevator)))
			. += T

// The level the platform moves to: down from the flight deck, up from the hangar.
/obj/structure/vessel_lever/elevator/proc/target_z()
	var/turf/here = get_turf(src)
	if (!here)
		return 0
	return istype(here, /turf/floor/plating/carrier_deck) ? multiz_level_below(here.z) : multiz_level_above(here.z)

/obj/structure/vessel_lever/elevator/examine(mob/user)
	..()
	var/turf/here = get_turf(src)
	to_chat(user, istype(here, /turf/floor/plating/carrier_deck) ? "This lever lowers the platform to the hangar." : "This lever raises the platform to the flight deck.")

/obj/structure/vessel_lever/elevator/attack_hand(mob/living/human/H)
	if (!istype(H))
		return ..()
	var/result = operate(H)
	if (result)
		to_chat(H, SPAN_WARNING(result))

// Moves the platform's load. Returns null when done, else the reason it stayed.
/obj/structure/vessel_lever/elevator/proc/operate(mob/user)
	if (busy)
		return "The elevator is already moving."
	var/list/tiles = platform()
	if (!tiles.len)
		return "The lever is not connected to a platform."
	var/to_z = target_z()
	if (!to_z)
		return "There is no deck to move the platform to."
	var/turf/here = get_turf(src)
	var/list/aircraft = list()
	var/list/loose = list()
	for (var/turf/T in tiles)
		for (var/atom/movable/M in T)
			if (M.loc != T || QDELETED(M) || istype(M, /atom/movable/lighting_overlay) || istype(M, /atom/movable/lighting_fullbright))
				continue
			if (istype(M, /obj/structure/vehicleparts/frame))
				var/obj/structure/vehicleparts/frame/F = M
				var/obj/structure/vehicleparts/axis/aircraft/A = F.axis
				if (!istype(A))
					return "[F.name] is not an aircraft; only aircraft, crew and cargo ride the elevator."
				aircraft |= A
				continue
			if (istype(M, /obj/structure/vehicleparts))
				continue
			loose += M
	for (var/obj/structure/vehicleparts/axis/aircraft/A in aircraft)
		if (A.airborne() || A.moving)
			return "[A.name] must be parked before the elevator moves."
		for (var/obj/structure/vehicleparts/frame/F in A.frames())
			if (!(get_turf(F) in tiles))
				return "[A.name] is not fully on the platform."
		var/hit = A.clear_at_level(to_z)
		if (hit)
			return "[hit] is in the way of [A.name] on the other deck."
	for (var/atom/movable/M in loose)
		var/turf/D = locate(M.x, M.y, to_z)
		if (!D || D.density)
			return "The other deck is blocked under [M.name]."
	busy = TRUE
	for (var/obj/structure/vehicleparts/axis/aircraft/A in aircraft)
		A.aircraft_shift(to_z)
	for (var/atom/movable/M in loose)
		if (QDELETED(M) || M.z != here.z)
			continue
		M.forceMove(locate(M.x, M.y, to_z))
	busy = FALSE
	var/down = to_z < here.z
	for (var/turf/T in tiles)
		T.visible_message(SPAN_NOTICE("The elevator platform [down ? "sinks to the hangar" : "rises to the flight deck"]."))
		break
	if (user)
		to_chat(user, SPAN_NOTICE("You pull the lever and the platform [down ? "sinks to the hangar" : "rises to the flight deck"] with [aircraft.len] aircraft and [loose.len] other thing\s on it."))
	return null

#undef VESSEL_ELEVATOR_REACH

// ---- Catapult ----

// How far from its lever the catapult track can lie.
#define VESSEL_CATAPULT_REACH 5

// The catapult lever beside the track at the bow. A plane parked on the
// track with its nose to the bow and its engine running is thrown into the
// air at full throttle, no takeoff roll needed.
/obj/structure/vessel_lever/catapult
	name = "catapult lever"
	desc = "The firing lever of the bow catapult. A plane parked on the track beside it, nose to the bow with its engine running, is thrown into the air."

/obj/structure/vessel_lever/catapult/proc/track()
	. = list()
	var/turf/here = get_turf(src)
	if (!here)
		return
	for (var/turf/floor/plating/carrier_deck/catapult/T in range(VESSEL_CATAPULT_REACH, here))
		if (T.z == here.z)
			. += T

/obj/structure/vessel_lever/catapult/attack_hand(mob/living/human/H)
	if (!istype(H))
		return ..()
	var/result = launch(H)
	if (result)
		to_chat(H, SPAN_WARNING(result))

// Launches the plane on the track. Returns null when it flew, else why not.
/obj/structure/vessel_lever/catapult/proc/launch(mob/user)
	if (busy)
		return "The catapult is still being run back."
	var/list/tiles = track()
	if (!tiles.len)
		return "The lever is not connected to a catapult."
	var/datum/vessel/V = ship()
	var/obj/structure/vehicleparts/axis/aircraft/A
	for (var/turf/T in tiles)
		for (var/obj/structure/vehicleparts/frame/F in T)
			if (istype(F.axis, /obj/structure/vehicleparts/axis/aircraft))
				A = F.axis
				break
		if (A)
			break
	if (!A)
		return "There is no aircraft on the catapult."
	if (A.airborne())
		return "[A.name] is already flying."
	for (var/obj/structure/vehicleparts/frame/F in A.frames())
		if (!(get_turf(F) in tiles))
			return "[A.name] is not fully on the catapult track."
	if (V && A.dir != V.dir)
		return "[A.name] must point its nose to the bow ([dir2text(V.dir)])."
	if (!A.check_engine())
		return "[A.name]'s engine is not running."
	var/turf/here = get_turf(A)
	var/up = multiz_level_above(here.z)
	if (!up)
		return "There is no open sky above to launch into."
	var/hit = A.clear_at_level(up)
	if (hit)
		return "[hit] is in the way above the catapult."
	busy = TRUE
	A.visible_message(SPAN_WARNING("The catapult fires and hurls \the [A] off the bow!"))
	if (!A.aircraft_shift(up))
		busy = FALSE
		return "The catapult jammed."
	A.runway_roll = 0
	A.set_flight_state(AIRCRAFT_LOW)
	A.currentspeed = A.speeds
	A.reverse = FALSE
	A.startmovementloop()
	busy = FALSE
	return null

#undef VESSEL_CATAPULT_REACH

// ---- Deck lights ----

// A deck edge light. Unpowered, lit while the helm has the deck lights on,
// and left where it stands by vehicles rolling over it like every lamp.
/obj/structure/lamp/lamp_small/alwayson/deck
	name = "deck light"
	desc = "A low shielded lamp at the edge of the flight deck, switched from the wheel."
	brightness_color = "#ffffff"
	light_amt = 3
	not_movable = TRUE
	var/lit = TRUE

/obj/structure/lamp/lamp_small/alwayson/deck/do_light()
	if (!lit)
		set_light(0)
		on = FALSE
		update_icon()
		return
	..()

// ---- Radar ----

// The island radar set: ships, aircraft and other vessels within range,
// with distance and bearing from the island.
/obj/structure/vessel_radar
	name = "radar set"
	desc = "The carrier's air and surface search radar. Use it to read the contacts around the ship."
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "transponder"
	anchored = TRUE
	density = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/tmp/datum/vessel/vessel

/obj/structure/vessel_radar/proc/ship()
	if (!vessel)
		vessel = vessel_at(get_turf(src))
	return vessel

// Lines describing every contact in range. The ship herself is left out.
/obj/structure/vessel_radar/proc/contacts()
	. = list()
	var/turf/here = get_turf(src)
	var/datum/vessel/V = ship()
	if (!here)
		return
	var/turf/surface = V ? locate(here.x, here.y, V.base_z) : locate(here.x, here.y, multiz_level_below(here.z) || here.z)
	if (!surface)
		surface = here
	for (var/obj/structure/vehicleparts/axis/ship/S in ship_axes)
		var/turf/T = get_turf(S)
		if (!T || T.z != surface.z || get_dist(T, surface) > VESSEL_RADAR_RANGE)
			continue
		. += "Ship: [S.name], [get_dist(T, surface)] tiles [submarine_bearing(surface, T)], heading [dir2text(S.dir)][S.moving ? "" : ", stopped"]."
	for (var/datum/vessel/O in naval_vessels)
		if (O == V || !O.placed || O.base_z != surface.z)
			continue
		var/turf/T = locate(O.ox + round((O.box_w() - 1) / 2), O.oy + round((O.box_h() - 1) / 2), O.base_z)
		if (!T || get_dist(T, surface) > VESSEL_RADAR_RANGE)
			continue
		. += "Vessel: [O.name], [get_dist(T, surface)] tiles [submarine_bearing(surface, T)], bow to the [dir2text(O.dir)][O.speed > 0 && !O.anchored ? "" : ", stopped"]."
	for (var/obj/structure/vehicleparts/axis/aircraft/A in airborne_aircraft)
		var/turf/T = get_turf(A)
		if (!T || multiz_level_below(T.z) != surface.z)
			continue
		var/turf/below = locate(T.x, T.y, surface.z)
		if (!below || get_dist(below, surface) > VESSEL_RADAR_RANGE)
			continue
		. += "Aircraft: [A.name], [get_dist(below, surface)] tiles [submarine_bearing(surface, below)], heading [dir2text(A.dir)][A.flight_state == AIRCRAFT_CRUISE ? ", high" : ", low"]."

/obj/structure/vessel_radar/attack_hand(mob/living/human/H)
	if (!istype(H))
		return ..()
	var/list/lines = contacts()
	to_chat(H, SPAN_NOTICE("The radar sweeps [VESSEL_RADAR_RANGE] tiles around the ship."))
	if (!lines.len)
		to_chat(H, "No contacts.")
		return
	for (var/line in lines)
		to_chat(H, line)

/obj/structure/vessel_radar/examine(mob/user)
	..()
	var/list/lines = contacts()
	to_chat(user, lines.len ? "[lines.len] contact\s on the screen." : "The screen is clear.")

// ---- Admin spawn ----

// Admin test spawn: lays a carrier with this tile as its south-west corner,
// bow to the east. It needs 40x9 of deep water with a level below and above.
/obj/effect/vessel_spawner/carrier
	name = "aircraft carrier spawner"
	icon = 'icons/obj/vehicles/vehicleeffects.dmi'
	icon_state = "4x4"
	invisibility = 101

/obj/effect/vessel_spawner/carrier/New(loc)
	..()
	addtimer(CALLBACK(src, PROC_REF(build)), 1)

/obj/effect/vessel_spawner/carrier/proc/build()
	var/result = carrier_lay_down(get_turf(src), EAST)
	if (islist(result))
		var/list/R = result
		world.log << "carrier spawner at [x],[y],[z] refused: [R["refused"]]"
		message_admins("Carrier spawn at [x],[y],[z] refused: [R["refused"]].")
	qdel(src)

#undef CARRIER_LENGTH
#undef CARRIER_BEAM
