// Ships as cargo carriers (code/modules/craft/craft_cargo.dm, docs/craft-core.md#cargo):
// one rule says what a moving hull carries; a built hull steps with crates,
// carts, boats, machines, animals and loose things on deck and in her hold,
// and leaves ghosts, flick overlays and mines where they were. A ship with a
// hold crosses the sea: the hold, its ladder and its cargo are packed, the
// rock closes behind her, and she is built again with the hold hollowed out
// under her, or with its cargo stowed on deck where no ground takes a hold.
// An engine crosses whole and is coupled to its fuel tank again.
/world
	hub = ""
	hub_password = ""
	maxx = 70
	maxy = 60
	maxz = 3
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/naval_probe/New()
	return
/mob/living/human/naval_probe/New()
	return
/mob/observer/probe_ghost/New()
	return
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Rock under everything, sand ashore (x 1-20) and deep sea beyond, sky above.
/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/wall/rockwall)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(x <= 20 ? /turf/floor/beach/sand : /turf/floor/beach/water/deep/saltwater)
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)

/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

/proc/count_in(turf/T, path)
	. = 0
	for (var/atom/movable/M in T)
		if (istype(M, path))
			.++

/proc/naval_checks()
	naval_fixture()

	// ---- One rule for what rides ----
	var/turf/spot = locate(30, 10, 2)
	var/mob/observer/probe_ghost/ghost = new(spot)
	var/atom/movable/overlay/flick = new(spot)
	var/obj/structure/naval_mine/mine = new(spot)
	var/obj/structure/closet/crate/box = new(spot)
	var/obj/machinery/microscope/scope = new(spot)
	var/mob/living/simple_animal/goat/goat = new(spot)
	naval_check(!ghost.craft_cargo() && !flick.craft_cargo(), "ghosts and flick overlays are never cargo")
	naval_check(!mine.craft_cargo(), "a mine laid in the water stays where it was laid")
	naval_check(box.craft_cargo() && scope.craft_cargo() && goat.craft_cargo(), "crates, machines and animals are cargo")
	for (var/atom/movable/A in list(ghost, flick, mine, box, scope, goat))
		qdel(A)

	// ---- The Petrel: 4 x 3 planks, a hold of two tiles under her bow, a ladder down ----
	for (var/x = 40, x <= 43, x++)
		for (var/y = 30, y <= 32, y++)
			hull_lay(x, y)
	var/obj/covers/hold_a = hull_hold_lay(locate(43, 31, 1))
	var/obj/covers/hold_b = hull_hold_lay(locate(43, 32, 1))
	naval_check(hold_a && hold_b && hold_a.hold_origin == "[/turf/wall/rockwall]", "a hold of two tiles is hollowed out of the rock under her bow")
	var/obj/structure/multiz/ladder/down = new(locate(43, 31, 2))
	var/obj/structure/multiz/ladder/up/up = new(locate(43, 31, 1))
	down.find_target()
	up.find_target()
	naval_check(down.target == up && up.target == down, "a ladder joins her deck to the hold")
	var/obj/structure/hull_tiller/tiller = new(locate(41, 31, 2))
	naval_check(isnull(tiller.commission("Petrel", EAST)) && tiller.craft, "the Petrel is commissioned")
	var/datum/craft_body/built/B = tiller.body()
	naval_check(B && B.tile_count() == 12 && B.lower_tile_count() == 2, "she has 12 tiles of deck and 2 of hold ([B ? B.lower_tile_count() : "none"])")

	// Cargo on deck: a crate of planks, a raft, a shopping cart, a microscope, a goat, a crowbar.
	var/obj/structure/closet/crate/chest = new(locate(40, 30, 2))
	for (var/atom/movable/A in chest)
		qdel(A)
	new /obj/item/stack/material/wood(chest, 20)
	var/obj/structure/vehicle/raft/raft = new(locate(40, 32, 2))
	var/obj/structure/shopping_cart/cart = new(locate(42, 30, 2))
	var/obj/machinery/microscope/microscope = new(locate(42, 32, 2))
	var/mob/living/simple_animal/goat/deck_goat = new(locate(40, 31, 2))
	var/obj/item/weapon/crowbar/bar = new(locate(41, 32, 2))
	// In the hold: a barrel of water and a sack of planks.
	var/obj/item/weapon/reagent_containers/glass/barrel/cask = new(locate(43, 32, 1))
	cask.reagents.add_reagent("water", 100)
	var/obj/item/stack/material/wood/hold_planks = new(locate(43, 31, 1), 15)
	// Never aboard: a ghost and a flick animation on her deck.
	var/mob/observer/probe_ghost/watcher = new(locate(42, 31, 2))
	var/atom/movable/overlay/sparkle = new(locate(42, 31, 2))

	// ---- One step east ----
	var/turf/O = B.origin()
	naval_check(B.move_to(O.x + 1, O.y, EAST), "she steps one tile east ([B.last_refusal])")
	naval_check(chest.x == 41 && raft.x == 41 && cart.x == 43 && microscope.x == 43 && deck_goat.x == 41 && bar.x == 42, "the crate, raft, cart, microscope, goat and crowbar ride along")
	naval_check(cask.x == 44 && cask.z == 1 && hold_planks.x == 44 && hold_planks.z == 1, "the hold's cask and planks ride along below the waterline")
	naval_check(watcher.x == 42 && sparkle.x == 42, "the ghost and the flick overlay stay where they were")
	naval_check(down.x == 44 && up.x == 44 && down.target == up, "her ladder and its foot ride along, still paired")
	qdel(watcher)
	qdel(sparkle)

	// ---- Packing her with her hold ----
	var/list/packed = sea_crossing_pack(tiller)
	naval_check(islist(packed), "with a hold she packs for the crossing ([istext(packed) ? packed : "ok"])")
	var/list/R = islist(packed) ? packed["record"] : list()
	naval_check(length(R["hold"]) == 2 && sea_crossing_record_ok(R), "the record holds her two hold tiles and is valid")
	var/text = json_encode(R)
	naval_check(findtext(text, "/obj/structure/vehicle/raft") && findtext(text, "/obj/structure/shopping_cart") && findtext(text, "/obj/machinery/microscope"), "the raft, the cart and the microscope are in it")
	naval_check(findtext(text, "\"l\",\"/obj/structure/multiz/ladder\"") && findtext(text, "\"l\",\"/obj/structure/multiz/ladder/up\""), "so is the ladder, both ends")
	naval_check(isnull(tiller.crossing_refusal()) || !findtext(tiller.crossing_refusal(), "hold"), "a hold no longer keeps her in port")
	var/list/bad = json_decode(text)
	bad["hold"] += list(list(9, 9, list(list("c", "/obj/covers/steelplating/hold", 2, 100))))
	naval_check(!sea_crossing_record_ok(bad), "a hold tile under no deck tile is refused")
	bad = json_decode(text)
	var/list/hold_tile = bad["hold"][1]
	hold_tile[3] += list(list("l", "/obj/structure/probe_nothing", 2))
	naval_check(!sea_crossing_record_ok(bad), "a ladder entry that is not a ladder is refused")
	// A loaded cart stays until it is unloaded.
	var/obj/item/weapon/crowbar/riding = new(cart.loc)
	raft.ontop_o += riding
	var/refusal = sea_crossing_pack(tiller)
	naval_check(istext(refusal) && findtext(refusal, "unload"), "a loaded raft keeps her in port ([refusal])")
	raft.ontop_o -= riding
	qdel(riding)

	// ---- Off the water ----
	sea_crossing_strip(tiller)
	qdel(tiller)
	var/left = 0
	for (var/x = 40, x <= 45, x++)
		for (var/y = 30, y <= 32, y++)
			for (var/z = 1, z <= 2, z++)
				var/turf/T = locate(x, y, z)
				left += count_in(T, /obj/covers) + count_in(T, /obj/structure) + count_in(T, /obj/item) + count_in(T, /obj/machinery)
	naval_check(!left, "stripped, nothing of her is left on the water or in the hold ([left])")
	naval_check(istype(locate(44, 31, 1), /turf/wall/rockwall) && istype(locate(44, 32, 1), /turf/wall/rockwall), "the rock closes where her hold was")

	// ---- The far side, with rock below ----
	var/list/offsets = list()
	for (var/list/tile in R["tiles"])
		offsets += list(list(tile[1], tile[2]))
	var/list/hold_offsets = sea_crossing_hold_offsets(R)
	var/turf/anchorage = sea_crossing_anchorage(offsets, list(EAST), hold_offsets)
	naval_check(anchorage && anchorage.z == 2, "an anchorage with rock under her hold is found off the east edge")
	var/obj/structure/hull_tiller/built = sea_crossing_build(R, anchorage, "v-1")
	var/datum/craft_body/built/NB = built ? built.body() : null
	naval_check(NB && NB.tile_count() == 12 && NB.lower_tile_count() == 2, "she is built with her hold ([NB ? NB.lower_tile_count() : "none"])")
	if (NB)
		var/turf/bow = locate(anchorage.x + 2, anchorage.y, 2)
		var/turf/bow_hold = locate(bow.x, bow.y, 1)
		var/obj/structure/multiz/ladder/new_down = locate() in bow
		var/obj/structure/multiz/ladder/up/new_up = locate() in bow_hold
		naval_check(new_down && new_up && new_down.target == new_up && new_up.target == new_down, "her ladder is built again, paired with its foot in the hold")
		naval_check(locate(/obj/item/stack/material/wood) in bow_hold, "the planks are in the hold")
		var/obj/item/weapon/reagent_containers/glass/barrel/new_cask = locate() in locate(bow.x, bow.y + 1, 1)
		naval_check(new_cask && new_cask.reagents.get_reagent_amount("water") == 100, "the cask is in the hold with its water")
		naval_check(locate(/obj/structure/vehicle/raft) in locate(anchorage.x - 1, anchorage.y + 1, 2), "the raft is on deck where it lay")
		naval_check(locate(/obj/structure/shopping_cart) in locate(anchorage.x + 1, anchorage.y - 1, 2), "so is the cart")
		naval_check(locate(/obj/machinery/microscope) in locate(anchorage.x + 1, anchorage.y + 1, 2), "so is the microscope")
		naval_check(locate(/mob/living/simple_animal/goat) in locate(anchorage.x - 1, anchorage.y, 2), "and the goat")
		// She sails on with her hold through the rock.
		var/turf/NO = NB.origin()
		naval_check(NB.move_to(NO.x - 1, NO.y, EAST) && NB.lower_tile_count() == 2, "the rebuilt hold sails with her ([NB.last_refusal])")

	// ---- No ground for a hold: its cargo is stowed on deck ----
	for (var/x = 21, x <= world.maxx, x++)
		for (var/y = 1, y <= 20, y++)
			var/turf/G = locate(x, y, 1)
			G.ChangeTurf(/turf/floor/dirt)
	var/turf/open = locate(50, 10, 2)
	naval_check(sea_crossing_fits(offsets, open.x, open.y, open.z) && !sea_crossing_fits(offsets, open.x, open.y, open.z, hold_offsets), "dirt below takes her deck but not her hold")
	var/obj/structure/hull_tiller/bare = sea_crossing_build(R, open, "v-2")
	var/datum/craft_body/built/BB = bare ? bare.body() : null
	naval_check(BB && BB.lower_tile_count() == 0, "she is built without a hold")
	if (BB)
		var/turf/bow = locate(open.x + 2, open.y, 2)
		naval_check(locate(/obj/item/stack/material/wood) in bow, "the hold's planks are stowed on the deck above it")
		naval_check(locate(/obj/item/weapon/reagent_containers/glass/barrel) in locate(bow.x, bow.y + 1, 2), "so is the cask")
		naval_check(!(locate(/obj/structure/multiz) in bow) && istype(locate(bow.x, bow.y, 1), /turf/floor/dirt), "no ladder down to nothing, and the dirt is left alone")

	// ---- An engine crosses with its fuel tank ----
	for (var/x = 25, x <= 27, x++)
		for (var/y = 45, y <= 47, y++)
			hull_lay(x, y)
	var/obj/structure/engine/internal/diesel/motor = new(locate(25, 46, 2))
	motor.enginesize = 5000
	motor.maxpower = initial(motor.maxpower) * 5
	motor.name = "5000cc [initial(motor.name)]"
	var/obj/item/weapon/reagent_containers/glass/barrel/tank = new(locate(25, 45, 2))
	tank.anchored = TRUE
	tank.reagents.add_reagent("diesel", 200)
	motor.fueltank = tank
	motor.on = TRUE
	var/obj/structure/hull_tiller/tug_tiller = new(locate(26, 46, 2))
	naval_check(isnull(tug_tiller.commission("Tug", EAST)), "the Tug is commissioned")
	var/list/tug_packed = sea_crossing_pack(tug_tiller)
	naval_check(islist(tug_packed), "an engine no longer keeps her in port ([istext(tug_packed) ? tug_packed : "ok"])")
	var/list/TR = islist(tug_packed) ? tug_packed["record"] : list()
	naval_check(findtext(json_encode(TR), "\"e\",") && sea_crossing_record_ok(TR), "the engine is an engine entry and the record is valid")
	var/list/bad_engine = json_decode(json_encode(TR))
	for (var/list/tile in bad_engine["tiles"])
		for (var/list/E in tile[3])
			if (E[1] == "e")
				E[3] = 5
	naval_check(!sea_crossing_record_ok(bad_engine), "a fuel tank more than a tile from its engine is refused")
	sea_crossing_strip(tug_tiller)
	qdel(tug_tiller)
	naval_check(QDELETED(motor) && QDELETED(tank), "stripped, her engine and its tank leave the water")
	var/list/tug_offsets = list()
	for (var/list/tile in TR["tiles"])
		tug_offsets += list(list(tile[1], tile[2]))
	var/turf/tug_at = sea_crossing_anchorage(tug_offsets, list(NORTH))
	var/obj/structure/hull_tiller/tug = tug_at ? sea_crossing_build(TR, tug_at, "v-3") : null
	naval_check(tug && tug.craft, "the Tug is built off the north edge")
	if (tug)
		var/obj/structure/engine/internal/diesel/new_motor = locate() in locate(tug_at.x - 1, tug_at.y, 2)
		naval_check(new_motor && new_motor.enginesize == 5000 && new_motor.maxpower == initial(new_motor.maxpower) * 5 && new_motor.name == motor.name, "her engine is the same 5000cc diesel ([new_motor ? "[new_motor.name] [new_motor.maxpower]" : "none"])")
		naval_check(new_motor && !new_motor.on, "it arrives stopped")
		var/obj/item/weapon/reagent_containers/glass/barrel/new_tank = new_motor ? new_motor.fueltank : null
		naval_check(new_tank && new_tank.loc == locate(tug_at.x - 1, tug_at.y - 1, 2) && new_tank.anchored && new_tank.reagents.get_reagent_amount("diesel") == 200, "its tank is coupled again, where it stood, with its diesel")
		var/found = FALSE
		for (var/datum/craft_drive/fitted/engine/D in tug.craft.drives)
			if (D.source == new_motor)
				found = TRUE
		naval_check(found, "the engine is one of her drives again")

	// ---- Carts, boats and machines go whole ----
	var/list/kinds = list(/obj/structure/vehicle/raft, /obj/structure/vehicle/raft/dugout, /obj/structure/vehicle/raft/dugout/outrigger,
		/obj/structure/shopping_cart, /obj/structure/carriage, /obj/machinery/microscope, /obj/machinery/washing_machine)
	var/turf/yard = locate(60, 50, 2)
	for (var/path in kinds)
		var/atom/movable/thing = new path(yard)
		var/list/E = sea_crossing_cargo_entry(thing)
		var/atom/movable/again = islist(E) ? sea_crossing_cargo_build(E, yard) : null
		naval_check(again && again.type == path, "[path] crosses whole ([istext(E) ? E : "ok"])")
		qdel(thing)
		if (again)
			qdel(again)

/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/naval_probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
