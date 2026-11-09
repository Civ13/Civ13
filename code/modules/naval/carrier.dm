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
	desc = "Steel flight deck plating."
	icon_state = "plating"

/turf/floor/plating/carrier_deck/island
	name = "island deck"
	desc = "The deck of the carrier's island."

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
// fuel bunker, crew quarters, hangar, magazine, forward compartment (sick bay
// and CIC), each behind a bulkhead with one blast door on the centreline.
/proc/carrier_hangar_level()
	var/datum/vessel_level/L = new
	L.dz = -1
	L.allowed = list(/turf/wall/rockwall, /turf/floor/beach/water/deep)
	var/wall = ".HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH."
	var/room = ".HeeeeBffBqqqBaaaaaaaaaaaaaaaaBmmBccccH."
	var/doors = ".Heeee1ff2qqq3aaaaaaLaaaaaaaaa4mm5ccccH."
	L.rows = list(wall, room, room, room, doors, room, room, room, wall)
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
	)
	return L

// The flight deck at the surface: plating from stern to bow, a ladder down to
// the hangar amidships and a ladder up to the island on the starboard side.
/proc/carrier_flight_deck_level()
	var/datum/vessel_level/L = new
	L.dz = 0
	L.allowed = list(/turf/floor/beach/water/deep)
	var/deck = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
	var/hatch = "FFFFFFFFFFFFFFFFFFFFKFFFFFFFFFFFFFFFFFFF"
	var/stair = "FFFFFFFFFFFFFFFFFFUFFFFFFFFFFFFFFFFFFFFF"
	L.rows = list(deck, deck, deck, deck, hatch, deck, stair, deck, deck)
	L.legend = list(
		"F" = list("turf" = /turf/floor/plating/carrier_deck),
		"K" = list("turf" = /turf/floor/plating/carrier_deck, "spawn" = list(/obj/structure/multiz/ladder)),
		"U" = list("turf" = /turf/floor/plating/carrier_deck, "spawn" = list(/obj/structure/multiz/ladder/up)),
	)
	return L

// The island on the open-air level: a 5x3 superstructure on the starboard
// side amidships with the helm, reached by the flight deck ladder.
/proc/carrier_island_level()
	var/datum/vessel_level/L = new
	L.dz = 1
	L.allowed = list(/turf/sky)
	var/empty = "........................................"
	var/top = "..................JIIII................."
	var/mid = "..................IIWII................."
	var/low = "..................IIIII................."
	L.rows = list(empty, empty, empty, empty, empty, empty, top, mid, low)
	L.legend = list(
		"I" = list("turf" = /turf/floor/plating/carrier_deck/island),
		"J" = list("turf" = /turf/floor/plating/carrier_deck/island, "spawn" = list(/obj/structure/multiz/ladder)),
		"W" = list("turf" = /turf/floor/plating/carrier_deck/island, "spawn" = list(/obj/structure/vessel_helm)),
	)
	return L

// Ladders spawned at runtime pair up here; map-placed ones pair in initialize().
/datum/vessel/carrier/relocate(x, y, heading)
	. = ..()
	if (.)
		for (var/turf/T in cells())
			for (var/obj/structure/multiz/M in T)
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
	desc = "The carrier's wheel and engine telegraph."
	icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	icon_state = "ship_wheel"
	anchored = TRUE
	density = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/datum/vessel/vessel

/obj/structure/vessel_helm/New(loc)
	..()
	vessel = vessel_at(get_turf(src))

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
	var/list/options = list("Full ahead", "Half ahead", "Slow ahead", "All stop", "Head north", "Head east", "Head south", "Head west", vessel.anchored ? "Weigh anchor" : "Drop anchor", "Cancel")
	var/choice = WWinput(H, status_text(), name, "Cancel", options)
	if (!choice || choice == "Cancel" || !vessel || get_dist(H, src) > 1)
		return
	switch (choice)
		if ("Full ahead") vessel.set_speed(VESSEL_SPEED_FULL)
		if ("Half ahead") vessel.set_speed(VESSEL_SPEED_HALF)
		if ("Slow ahead") vessel.set_speed(VESSEL_SPEED_SLOW)
		if ("All stop") vessel.set_speed(VESSEL_SPEED_STOP)
		if ("Weigh anchor") vessel.set_anchor(FALSE)
		if ("Drop anchor") vessel.set_anchor(TRUE)
		if ("Head north", "Head east", "Head south", "Head west")
			var/heading = text2dir(copytext(choice, 6))
			if (vessel.anchored)
				to_chat(H, SPAN_WARNING("Weigh anchor before coming about."))
				return
			if (!vessel.turn_to(heading))
				to_chat(H, SPAN_WARNING("The ship cannot come about here: [vessel.last_refusal]."))
				return
	vessel.crew_message(SPAN_NOTICE("[H] at the wheel: [choice]. [status_text()]"))

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
