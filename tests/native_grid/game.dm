/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 2
	turf = /turf
	visibility = 0
/world/OpenPort(port)
	return port == "none" ? ..() : FALSE
/obj/map_metadata/grid_fixture/New()
	return
/mob/living/human/grid_fixture/New()
	species = new /datum/species/human
	return
var/native_grid_failures = 0
/proc/native_grid_check(condition, label)
	if (!condition)
		native_grid_failures++
	world.log << "[condition ? "PASS" : "FAIL:"] [label]"
/world/Error(exception/e)
	native_grid_failures++
	world.log << "runtime error: [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	movementMachine = new
	map = new /obj/map_metadata/grid_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.ordinal_age = 8
	try
		native_grid_check(!world.port, "offline fixture")
		var/mob/living/human/grid_fixture/H = new(locate(2,2,1))
		var/obj/item/stack/cable_coil/coil = new(H)
		coil.amount = 3
		H.l_hand = coil
		var/obj/structure/cable/A = coil.place_turf(locate(2,2,1),H,EAST)
		native_grid_check(A && coil.amount == 2, "one paid cable placed")
		native_grid_check(!coil.place_turf(locate(2,2,1),H,EAST) && coil.amount == 2, "duplicate placement spends nothing")
		var/obj/structure/cable/B = coil.place_turf(locate(3,2,1),H,EAST)
		native_grid_check(B && coil.amount == 1 && (B in A.connections) && (A in B.connections), "adjacent paid reciprocal connection")
		native_grid_check(!coil.place_turf(locate(6,2,1),H,EAST) && coil.amount == 1, "remote placement spends nothing")
		H.l_hand = null
		native_grid_check(!coil.place_turf(locate(2,3,1),H,NORTH) && coil.amount == 1, "dropped tool rejected")
		H.l_hand = coil
		H.stat = DEAD
		native_grid_check(!coil.place_turf(locate(2,3,1),H,NORTH), "dead actor rejected")
		H.stat = CONSCIOUS
		H.loc = locate(3,2,1)
		var/obj/structure/cable/C = coil.place_turf(locate(4,2,1),H,EAST)
		native_grid_check(C && coil.amount == 0 && !coil.loc && H.l_hand != coil, "last piece consumed and empty coil removed")
		var/obj/item/weapon/wirecutters/cutters = new(H)
		H.r_hand = cutters
		B.attackby(cutters,H)
		native_grid_check(!B.loc && !(B in A.connections) && !(B in C.connections), "cut removes cable and reciprocal links")
		var/obj/item/stack/cable_coil/salvage = locate(/obj/item/stack/cable_coil) in locate(3,2,1)
		native_grid_check(salvage && salvage.amount == 1, "cut salvages exactly one piece")
		var/obj/item/stack/cable_coil/crossing_coil = new(H)
		crossing_coil.amount = 2
		H.l_hand = crossing_coil
		var/obj/structure/cable/V = crossing_coil.place_turf(locate(4,2,1),H,NORTH)
		native_grid_check(V && !(V in C.connections) && !(C in V.connections), "crossing directions remain separate without connector")
		H.loc = locate(4,2,1)
		var/obj/item/connector/junction = new(H)
		H.l_hand = junction
		junction.attack_self(H)
		native_grid_check(junction.anchored && junction.junction_pairs.len == 1 && (C in V.connections) && (V in C.connections), "connector merges crossing")
		var/obj/item/weapon/wrench/wrench = new(H)
		H.r_hand = wrench
		junction.attackby(wrench,H)
		native_grid_check(!junction.anchored && !junction.turflist.len && !(V in C.connections) && !(C in V.connections), "unfastening splits and releases entries")
		junction.attackby(wrench,H)
		junction.forceMove(locate(5,2,1))
		native_grid_check(!junction.anchored && !junction.junction_pairs.len && !(V in C.connections), "connector movement disconnects")
		junction.forceMove(H)
		H.l_hand = junction
		junction.attack_self(H)
		H.r_hand = cutters
		V.attackby(cutters,H)
		native_grid_check(!(V in junction.turflist) && !(V in junction.connections) && !junction.junction_pairs.len, "cut forgets connector references")
		qdel(H)
		A.name = "saved cable A"
		C.name = "saved cable C"
		// A same-tile reciprocal junction exercises typed reference lists.
		var/obj/structure/cable/J = new(A.loc)
		J.name = "saved junction"
		A.connections |= J
		J.connections |= A
		var/obj/item/connector/saved_connector = new(A.loc)
		saved_connector.name = "saved connector"
		saved_connector.anchored = TRUE
		saved_connector.connect_cables()
		A.rebuild_supply()
		var/old_identity = A.component_id
		native_grid_check(map_storage.Save_World(), "production world export")
		native_grid_check(map_storage.validate_world_save(), "production save preflight")
		map_storage.ClearMap()
		native_grid_check(map_storage.Load_World(), "production world import")
		A = locate(/obj/structure/cable) in locate(2,2,1)
		J = null
		for (var/obj/structure/cable/candidate in locate(2,2,1))
			if (candidate.name == "saved junction")
				J = candidate
			else if (candidate.name == "saved cable A")
				A = candidate
		native_grid_check(A && J && (J in A.connections) && (A in J.connections), "native cable graph references restored")
		saved_connector = locate(/obj/item/connector) in locate(2,2,1)
		native_grid_check(saved_connector && saved_connector.anchored && saved_connector.junction_pairs.len == 1, "connector ownership saved")
		if (A && J)
			A.rebuild_supply()
			native_grid_check(A.component_id && A.component_id == J.component_id && A.component_id != old_identity, "runtime identities rebuilt after import")
			if (saved_connector)
				saved_connector.junction_pairs.Cut()
				saved_connector.after_load()
				native_grid_check(saved_connector.junction_pairs.len == 1, "legacy connector ownership reconstructed")
				saved_connector.disconnect_cables()
				native_grid_check(!(A in J.connections) && !(J in A.connections), "restored connector can split restored network")
	catch (var/exception/e)
		native_grid_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit"=world.params["tested_commit"],"failures"=native_grid_failures,"byond_build"=world.byond_build)),"result.json")
	del(world)
