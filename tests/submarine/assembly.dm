// Hand-built submarines (ships/submarine_assembly.dm): hull sections floated
// by hand and assembled from submarine controls, like a boat or a plane. Runs
// last, after clearing every boat the earlier checks built.

/proc/submarine_clear_boats()
	for (var/obj/structure/vehicleparts/axis/A in world)
		for (var/obj/O in A.components.Copy())
			if (istype(O, /obj/structure/vehicleparts/frame))
				var/obj/structure/vehicleparts/frame/F = O
				F.broken = TRUE
			qdel(O)
		qdel(A)
	for (var/turf/T in block(locate(5, 1, 2), locate(world.maxx, world.maxy, 2)))
		for (var/obj/O in T)
			if (istype(O, /obj/structure/vehicleparts/frame))
				var/obj/structure/vehicleparts/frame/F = O
				F.broken = TRUE
			qdel(O)

/proc/submarine_lay_sections(x1, y1, x2, y2)
	for (var/x = x1, x <= x2, x++)
		for (var/y = y1, y <= y2, y++)
			new /obj/structure/vehicleparts/frame/ship/steel/submarine/section(locate(x, y, 2))

/proc/submarine_hull_at(x, y)
	return locate(/obj/structure/vehicleparts/frame/ship/steel/submarine) in locate(x, y, 2)

/proc/submarine_assembly_checks()
	submarine_clear_boats()
	submarine_check(!(locate(/obj/structure/vehicleparts/frame) in block(locate(5, 1, 2), locate(world.maxx, world.maxy, 2))), "the sea is clear for the hand-built boats")

	// Research gates every crafted part.
	for (var/part in list("/obj/structure/vehicleparts/frame/ship/steel/submarine/section", "/obj/structure/vehicleparts/axis/ship/submarine/controls", "/obj/structure/vehicleparts/sub_station/loose", "/obj/structure/vehicleparts/sub_fitting/battery/loose", "/obj/structure/vehicleparts/sub_fitting/air/loose"))
		submarine_check(get_recipe_node_req(part) == "submarines", "Submarines research gates [part]")

	// A Scout's hull floated at x 10-12, y 10-14; its bow will be south.
	submarine_lay_sections(10, 10, 12, 14)
	var/obj/structure/vehicleparts/shipwheel/W = new(locate(11, 10, 2))
	new /obj/structure/engine/internal/diesel/premade/chiha(locate(11, 14, 2))
	new /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank(locate(11, 14, 2))
	var/obj/structure/vehicleparts/sub_fitting/battery/loose/battery = new(locate(10, 13, 2))
	new /obj/structure/vehicleparts/sub_fitting/air/loose(locate(12, 13, 2))

	// An ordinary rudder axis does not take submarine hull sections.
	var/obj/structure/vehicleparts/axis/ship/heavy/rudder = new(locate(11, 12, 2))
	var/datum/vehicle_survey/S = new(rudder)
	submarine_check(S.refusal && findtext(S.refusal, "must stand on one of the boat's ship frames"), "a ship's rudder axis does not take submarine hull sections ([S.refusal])")
	qdel(rudder)
	var/obj/structure/vehicleparts/axis/ship/submarine/controls/A = new(locate(11, 12, 2))
	S = new(A)
	submarine_check(!S.refusal && S.frames.len == 15 && S.helm == W && S.engine && S.tank && ("a ballast and periscope station to dive" in S.missing()), "the controls survey fifteen sections and ask for a ballast station ([S.refusal] / [english_list(S.missing())])")
	var/obj/structure/vehicleparts/sub_station/loose/station = new(locate(10, 11, 2))
	S = new(A)
	submarine_check(!S.refusal && !S.missing().len && S.station == station, "with a station it has everything a submarine needs")

	// Assembled bow south: the pen's Scout, tile for tile.
	submarine_check(isnull(A.assemble(SOUTH)) && A.hand_built && A.frames().len == 15 && A.hull_class == "scout", "the submarine controls assemble a hand-built Scout")
	var/list/hull_states = icon_states('icons/obj/vehicles/submarine_hull.dmi')
	var/shaped = TRUE
	for (var/x = 10, x <= 12, x++)
		for (var/y = 10, y <= 14, y++)
			var/obj/structure/vehicleparts/frame/ship/steel/submarine/F = submarine_hull_at(x, y)
			var/tile = "scout_[x - 9]_[y - 9]"
			if (!F || F.axis != A || F.hull_tile != tile || !("[tile]_deck" in hull_states))
				shaped = FALSE
	submarine_check(shaped, "every section takes its tile of the Scout's hull art")
	submarine_check(!(locate(/obj/structure/vehicleparts/frame/ship/steel/submarine/section) in block(locate(10, 10, 2), locate(12, 14, 2))), "no plain section is left in the hull")
	var/obj/structure/vehicleparts/frame/ship/steel/submarine/bow = submarine_hull_at(10, 10)
	var/obj/structure/vehicleparts/frame/ship/steel/submarine/engine_door = submarine_hull_at(11, 13)
	submarine_check(bow.w_front[1] == "sub_glass" && bow.w_right[1] == "sub_glass" && engine_door.door_walls().len == 1, "the bow is glazed and the engine room has its watertight door")
	submarine_check(istype(submarine_hull_at(10, 12), /obj/structure/vehicleparts/frame/ship/steel/submarine/hatch) && istype(submarine_hull_at(12, 12), /obj/structure/vehicleparts/frame/ship/steel/submarine/hatch), "both sides amidships are lock-out hatches")
	submarine_check(W.ship == A && A.engine && A.engine.fueltank && A.engine.engineclass == "engine", "the wheel steers it and the engine and tank are fitted")
	submarine_check(station.anchored && station.boat() == A && battery.anchored && battery.boat() == A && findtext(battery.reading(A), "attery"), "the station and the gauges are bolted down and read the boat")
	submarine_check(A.maxdist == 5 && A.speedlist[1] == 16, "it turns in a 5x5 square at the Scout's speed")

	// It dives and surfaces like a pen-built boat, and is not taken apart under the sea.
	submarine_check(isnull(A.change_depth(TRUE)) && A.submerged && submarine_frames_z(A, 1), "the hand-built boat dives")
	submarine_check(A.take_apart_refusal(null) == "she must be on the surface", "a submerged boat is not taken apart")
	submarine_check(isnull(A.change_depth(FALSE)) && !A.submerged && submarine_frames_z(A, 2), "and surfaces")
	submarine_check(A.do_matrix(A.dir, TURN_LEFT(A.dir), "left") && submarine_span(A, "x") == 5 && submarine_span(A, "y") == 3, "it turns inside its square")
	submarine_check(A.do_matrix(A.dir, TURN_RIGHT(A.dir), "right") && submarine_span(A, "x") == 3 && submarine_span(A, "y") == 5, "and turns back")

	// Taken apart, the shaped pieces assemble again with the bow north.
	submarine_check(isnull(A.take_apart_refusal(null)), "its builder may take it apart ([A.take_apart_refusal(null)])")
	A.take_apart()
	A.name = initial(A.name)
	submarine_check(!station.anchored && !battery.anchored && !A.components.len && !W.ship, "the station, gauges and wheel come loose")
	S = new(A)
	submarine_check(!S.refusal && S.frames.len == 15 && !S.missing().len, "the loose pieces survey as a hull again")
	var/why = A.assemble(EAST)
	submarine_check(why && findtext(why, "long side") && !A.components.len, "pointing the bow across the long side is refused ([why])")
	submarine_check(isnull(A.assemble(NORTH)) && A.dir == NORTH, "and reassembles bow north")
	var/obj/structure/vehicleparts/frame/ship/steel/submarine/north_bow = submarine_hull_at(12, 14)
	var/obj/structure/vehicleparts/frame/ship/steel/submarine/north_center = submarine_hull_at(11, 14)
	submarine_check(north_bow && north_bow.hull_tile == "scout_1_1" && north_center && north_center.hull_tile == "scout_2_1", "the north row is now the bow, starboard to the east")
	A.take_apart()
	for (var/obj/O in A.components.Copy())
		qdel(O)
	qdel(A)
	submarine_clear_boats()

	// Only the pen's two lengths and a three-section beam.
	for (var/list/size in list(list(3, 4), list(3, 6), list(4, 5)))
		submarine_lay_sections(10, 10, 9 + size[1], 9 + size[2])
		var/obj/structure/vehicleparts/axis/ship/submarine/controls/bad = new(locate(10, 10, 2))
		S = new(bad)
		submarine_check(S.refusal && findtext(S.refusal, "5 (a Scout) or 7 (an Explorer)"), "a [size[1]] by [size[2]] hull is refused ([S.refusal])")
		qdel(bad)
		submarine_clear_boats()

	// A 3 by 7 hull is an Explorer: two hatches, two doors and the slower speeds.
	submarine_lay_sections(10, 10, 16, 12)
	new /obj/structure/vehicleparts/shipwheel(locate(16, 11, 2))
	new /obj/structure/vehicleparts/sub_station/loose(locate(15, 10, 2))
	var/obj/structure/vehicleparts/axis/ship/submarine/controls/X = new(locate(13, 11, 2))
	submarine_check(isnull(X.assemble(WEST)) && X.hull_class == "explorer" && X.frames().len == 21 && X.maxdist == 7 && X.speedlist[1] == 18, "a 3 by 7 hull assembles bow west as an Explorer ([X.hull_class], [X.frames().len])")
	var/hatches = 0
	var/doors = 0
	var/explorer_art = TRUE
	for (var/obj/structure/vehicleparts/frame/ship/steel/submarine/XF in X.frames())
		if (istype(XF, /obj/structure/vehicleparts/frame/ship/steel/submarine/hatch))
			hatches++
		doors += XF.door_walls().len
		if (!("[XF.hull_tile]_deck" in hull_states) || !findtext(XF.hull_tile, "explorer_"))
			explorer_art = FALSE
	var/obj/structure/vehicleparts/frame/ship/steel/submarine/west_bow = submarine_hull_at(10, 12)
	submarine_check(hatches == 2 && doors == 2 && explorer_art && west_bow && west_bow.hull_tile == "explorer_1_1", "it has the Explorer's hull art, two lock-out hatches and two watertight doors, bow to the west")
	submarine_clear_boats()
