// The craft core (code/modules/craft/, docs/craft-core.md): a turf-built
// vessel is a craft through a template body that forwards to it; moves and
// turns made through the body reach the craft's hooks; drives add up to a
// push per tile of hull; a register decides who may steer; berths answer a
// docking request with a ticket; charts hold tokens, sites and hazards; a
// plane pool hands out levels.
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
var/naval_research_done = FALSE
/obj/map_metadata/naval_probe/New()
	return
/obj/map_metadata/naval_probe/is_node_done(faction, node_id)
	return naval_research_done
/mob/living/human/naval_probe/New()
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

/obj/structure/probe_gun
	name = "probe gun"
	anchored = TRUE
/obj/structure/probe_rock
	name = "probe rock"
	anchored = TRUE
	density = TRUE

// A plank laid the way a player lays one, with its first update already run.
/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

/proc/hull_planks(turf/T)
	. = 0
	for (var/obj/covers/C in T)
		.++

/proc/naval_checks()
	naval_fixture()
	// A shallow bay to build in, with the deep sea beyond x 60.
	for (var/x = 22, x <= 60, x++)
		for (var/y = 4, y <= 50, y++)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water)
	var/turf/sample = locate(40, 20, 2)
	var/shallow = sample.water_level
	naval_check(shallow > 0, "the bay is shallow water ([shallow])")

	// ---- What is and is not a hull ----
	var/obj/structure/hull_tiller/loose = new(locate(50, 40, 2))
	naval_check(findtext(loose.commission("Nothing", EAST), "floor built over water") && !loose.craft, "a tiller standing in the water commissions nothing")
	qdel(loose)
	// A jetty: planks from the sand (x 20) out over the water.
	hull_lay(20, 30)
	hull_lay(21, 30)
	hull_lay(22, 30)
	var/obj/structure/hull_tiller/jetty = new(locate(22, 30, 2))
	naval_check(findtext(jetty.commission("Jetty", EAST), "joined to the shore") && !jetty.craft, "a jetty joined to the shore is not a hull ([jetty.commission("Jetty", EAST)])")
	qdel(jetty)
	// Too many planks.
	for (var/x = 24, x <= 38, x++)
		for (var/y = 34, y <= 47, y++)
			hull_lay(x, y)
	var/obj/structure/hull_tiller/big = new(locate(24, 34, 2))
	naval_check(findtext(big.commission("Ark", EAST), "too large") && !big.craft, "more than [BUILT_HULL_MAX_TILES] tiles of floor is too large a hull")
	qdel(big)

	// ---- Commissioning: an L of eleven planks ----
	for (var/x = 30, x <= 34, x++)
		hull_lay(x, 10)
		hull_lay(x, 11)
	var/obj/covers/corner = hull_lay(30, 12)
	var/turf/under = locate(30, 12, 2)
	naval_check(under.water_level == 0 && corner.origin_water_level == shallow, "a plank keeps the water under it")
	var/obj/structure/hull_tiller/tiller = new(locate(32, 10, 2))
	naval_check(isnull(tiller.commission("Wren", EAST)) && tiller.craft, "the hull around the tiller is commissioned")
	var/datum/craft/C = tiller.craft
	var/datum/craft_body/built/B = C.body
	naval_check(istype(B) && C.name == "Wren" && B.tile_count() == 11 && C.mass() == 11 && (C in crafts), "she is a craft of eleven tiles named Wren ([B.tile_count()])")
	naval_check(craft_at(locate(30, 12, 2)) == C && craft_at(locate(34, 11, 2)) == C && !craft_at(locate(31, 12, 2)) && !craft_at(locate(35, 10, 2)), "the craft is the planks and nothing else")
	var/turf/O = B.origin()
	naval_check(O.x == 30 && O.y == 10 && B.heading() == EAST && B.length_tiles() == 5 && B.beam_tiles() == 3, "her box is 5 long and 3 across from 30,10")
	naval_check(corner.afloat, "her planks are marked afloat, so a load on the deep sea does not sink them")
	naval_check(findtext(tiller.status_text(), "11 tiles") && findtext(tiller.status_text(), "anchor down"), "the tiller reads her out ([tiller.status_text()])")

	// ---- Under way ----
	var/obj/item/weapon/reagent_containers/glass/bucket/bucket = new(locate(34, 11, 2))
	var/obj/structure/probe_gun/gun = new(locate(31, 11, 2))
	gun.dir = NORTH
	var/mob/living/human/naval_probe/ann = new(locate(33, 10, 2))
	ann.real_name = "Ann"
	ann.civilization = "Reds"
	naval_check(isnull(C.next_hop()) && !C.sail_tick(), "at anchor she goes nowhere")
	C.set_anchor(FALSE)
	C.set_speed(VESSEL_SPEED_FULL)
	naval_check(C.speed == VESSEL_SPEED_SLOW, "a hull with no drive makes slow ahead at most")
	var/list/hop = C.next_hop()
	naval_check(hop && hop[1] == 32 && hop[2] == 10, "the next hop is two tiles east")
	naval_check(C.warn_tick() == 5 && C.path_markers.len == 5 && hull_planks(locate(35, 10, 2)) == 0, "the five tiles of water she will cover are marked, and nothing has moved")
	naval_check(C.sail_tick() && tiller.x == 34 && tiller.y == 10 && !C.path_markers.len, "the hop carries the tiller two tiles east and clears the marks ([tiller.x],[tiller.y])")
	naval_check(bucket.x == 36 && bucket.y == 11 && gun.x == 33 && ann.x == 35 && ann.y == 10 && corner.x == 32 && corner.y == 12, "planks, cargo, gun and sailor ride along")
	naval_check(hull_planks(locate(30, 10, 2)) == 0 && hull_planks(locate(31, 11, 2)) == 0 && hull_planks(locate(36, 10, 2)) == 1 && hull_planks(locate(34, 10, 2)) == 1, "no plank is left behind or doubled")
	var/turf/left = locate(30, 12, 2)
	var/turf/reached = locate(36, 11, 2)
	var/turf/kept = locate(33, 10, 2)
	naval_check(left.water_level == shallow && reached.water_level == 0 && kept.water_level == 0 && corner.origin_water_level == shallow, "the water closes behind her and stays out from under her")
	naval_check(craft_at(locate(36, 11, 2)) == C && !craft_at(locate(30, 10, 2)) && B.contains(get_turf(tiller)), "the craft is where the planks are now")
	naval_check(B.last_move_ms < 250, "the hop took [B.last_move_ms] ms")

	// ---- Something in the way ----
	var/obj/structure/probe_rock/rock = new(locate(38, 10, 2))
	naval_check(C.sail_tick() && tiller.x == 35, "a rock two tiles off the bow leaves a one-tile hop ([tiller.x])")
	naval_check(!C.sail_tick() && tiller.x == 35 && C.speed == VESSEL_SPEED_STOP && findtext(C.last_refusal, "probe rock in the way"), "hard against it she stops with the reason ([C.last_refusal])")
	qdel(rock)
	hull_lay(38, 11)
	C.set_speed(VESSEL_SPEED_SLOW)
	naval_check(!C.sail_tick() && findtext(C.last_refusal, "built floor in the way"), "someone else's floor stops her too ([C.last_refusal])")
	for (var/obj/covers/other in locate(38, 11, 2))
		qdel(other)

	// ---- Coming about ----
	// The tiller is the pivot at 35,10. Bow east, the bucket lies at +2,+1.
	naval_check(C.order_turn(NORTH) && C.turning_to == NORTH && B.dir == EAST && C.path_markers.len > 0, "a turn at the tiller marks her swing first ([C.path_markers.len])")
	naval_check(!C.sail_tick() && tiller.x == 35, "and she waits for it")
	naval_check(C.finish_turn() && B.dir == NORTH && !C.path_markers.len && tiller.x == 35 && tiller.y == 10, "then she comes about around the tiller")
	naval_check(bucket.x == 34 && bucket.y == 12 && gun.dir == WEST && B.length_tiles() == 5 && B.beam_tiles() == 3, "what was two ahead and one to port still is ([bucket.x],[bucket.y], gun [dir2text(gun.dir)])")
	naval_check(hull_planks(locate(35, 12, 2)) == 1 && hull_planks(locate(37, 10, 2)) == 0 && B.tile_count() == 11, "her planks swung with her")
	var/total = 0
	for (var/turf/T in B.cells())
		total += hull_planks(T)
	naval_check(total == 11, "every tile of the hull has its one plank ([total])")
	naval_check(B.turn_to(SOUTH) && B.dir == SOUTH && gun.dir == EAST && tiller.x == 35, "she goes about half a circle in one move")
	naval_check(B.turn_to(NORTH), "and back")

	// ---- The edge of the bay: land refuses her ----
	var/turf/shoal = locate(35, 15, 2)
	shoal.ChangeTurf(/turf/floor/beach/sand)
	C.set_speed(VESSEL_SPEED_SLOW)
	naval_check(C.sail_tick() && tiller.y == 12, "she closes up to the shoal ([tiller.y])")
	naval_check(!C.sail_tick() && findtext(C.last_refusal, "ahead at 35,15"), "and stops at it ([C.last_refusal])")
	shoal.ChangeTurf(/turf/floor/beach/water)

	// ---- Refit ----
	C.set_anchor(TRUE)
	hull_lay(tiller.x + 1, tiller.y)
	hull_lay(tiller.x + 2, tiller.y)
	naval_check(B.tile_count() == 11 && !B.contains(locate(tiller.x + 2, tiller.y, 2)), "new planks are not hers until she is refitted")
	naval_check(isnull(tiller.commission()) && B.tile_count() == 13 && B.contains(locate(tiller.x + 2, tiller.y, 2)) && C.name == "Wren" && B.dir == NORTH, "a refit takes them in and keeps her name and heading ([B.tile_count()])")

	// ---- Papers ----
	var/mob/living/human/naval_probe/bob = new(get_step(tiller, WEST))
	bob.real_name = "Bob"
	bob.civilization = "Blues"
	naval_check(C.helm_access(bob) == CRAFT_HELM_FREE, "an unregistered hull answers to anyone")
	C.register = new /datum/craft_register
	C.register.claim(ann)
	naval_check(C.helm_access(ann) == CRAFT_HELM_FREE && C.helm_access(bob) == CRAFT_HELM_CHAINED, "registered, she is chained to a stranger while her owners are away")

	// ---- Saved by the tiller ----
	C.set_anchor(FALSE)
	C.set_speed(VESSEL_SPEED_SLOW)
	tiller.before_save()
	naval_check(length(tiller.hull_state) && length(tiller.register_state), "the tiller saves the hull and her papers")
	var/list/cells_were = B.cells()
	tiller.craft = null
	qdel(B)
	qdel(C)
	naval_check(!crafts.len && !craft_at(get_turf(tiller)), "with the craft gone the planks are only planks")
	tiller.after_load()
	C = tiller.craft
	B = C ? C.body : null
	var/same = istype(B) && B.tile_count() == 13
	if (same)
		for (var/turf/T in cells_were)
			if (!B.contains(T))
				same = FALSE
	naval_check(same && C.name == "Wren" && B.dir == NORTH && !C.anchored && C.speed == VESSEL_SPEED_SLOW, "the load finds the same hull around the tiller, under way as she was")
	naval_check(C.register && C.helm_access(bob) == CRAFT_HELM_CHAINED && C.helm_access(ann) == CRAFT_HELM_FREE, "with her papers")
	naval_check(C.sail_tick() && tiller.y == 14, "and she sails on ([tiller.y])")

	// ---- Sails ----
	var/obj/structure/vehicleparts/movement/sail/mast = new(locate(tiller.x - 1, tiller.y, 2))
	naval_check(B.contains(get_turf(mast)) && C.fit_drives() == 1 && C.thrust() == 0 && C.max_speed() == VESSEL_SPEED_SLOW, "a bare mast pushes nothing")
	mast.sails = new /obj/item/sail(mast)
	naval_check(C.fit_drives() == 1 && C.thrust() == 31 && C.max_speed() == VESSEL_SPEED_HALF, "a rigged mast pushes her thirteen tiles at half ahead ([C.thrust()])")
	naval_check(findtext(tiller.status_text(), "Under 1 sail: half ahead at best"), "the tiller says so ([tiller.status_text()])")
	C.set_speed(VESSEL_SPEED_FULL)
	naval_check(C.speed == VESSEL_SPEED_HALF && mast.sails_on && mast.icon_state == "sail2", "sails alone never make full ahead, and the sail is set while she is under way")
	var/y_was = tiller.y
	naval_check(C.sail_tick() && tiller.y == y_was + 4 && mast.y == y_was + 4, "half ahead is four tiles a hop, mast and all ([tiller.y])")
	C.set_anchor(TRUE)
	naval_check(!mast.sails_on && mast.icon_state == "sail1", "at anchor the sail is furled")
	C.set_anchor(FALSE)
	qdel(mast.sails)
	mast.sails = null
	naval_check(C.sail_tick() && C.speed == VESSEL_SPEED_SLOW && tiller.y == y_was + 6, "with the sail gone she loses way to slow ahead ([tiller.y])")
	mast.sails = new /obj/item/sail(mast)
	var/datum/craft_drive/fitted/sail/drive = new(mast)
	C.add_drive(drive)
	mast.forceMove(locate(50, 8, 2))
	naval_check(!drive.ready() && drive.push() == 0, "a mast that is no longer aboard pushes nothing")
	qdel(mast)
	naval_check(C.fit_drives() == 0, "and is forgotten at the next look")

	// ---- Engines ----
	var/obj/structure/engine/internal/hotbulb/engine = new(locate(tiller.x - 1, tiller.y, 2))
	naval_check(B.contains(get_turf(engine)) && C.fit_drives() == 1 && C.thrust() == 0 && C.max_speed() == VESSEL_SPEED_SLOW, "an engine that is not running pushes nothing")
	naval_check(findtext(tiller.status_text(), "no engine is running"), "and the tiller says so ([tiller.status_text()])")
	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/bunker = new(get_turf(tiller))
	bunker.reagents.add_reagent("diesel", 30)
	engine.fueltank = bunker
	engine.on = TRUE
	naval_check(C.fit_drives() == 1 && C.thrust() == 66 && C.max_speed() == VESSEL_SPEED_FULL, "running, a hot bulb engine pushes her thirteen tiles at full ahead ([C.thrust()])")
	naval_check(findtext(tiller.status_text(), "Under 1 engine: full ahead at best. Her drives push 66; 13 tiles of hull need 13 for half ahead and 26 from engines for full ahead."), "the tiller says what she needs ([tiller.status_text()])")
	C.set_speed(VESSEL_SPEED_FULL)
	y_was = tiller.y
	naval_check(C.speed == VESSEL_SPEED_FULL && C.sail_tick() && tiller.y == y_was + 6 && engine.y == y_was + 6 && bunker.y == y_was + 6, "full ahead is six tiles a hop, engine and tank and all ([tiller.y])")
	naval_check(bunker.reagents.get_reagent_amount("diesel") == 3, "the hop burns 27 units from her tank at full ahead ([bunker.reagents.get_reagent_amount("diesel")])")
	C.set_speed(VESSEL_SPEED_SLOW)
	bunker.reagents.add_reagent("diesel", 9)
	C.burn_drives()
	naval_check(bunker.reagents.get_reagent_amount("diesel") == 3, "slow ahead burns a third of that ([bunker.reagents.get_reagent_amount("diesel")])")
	C.set_speed(VESSEL_SPEED_FULL)
	C.burn_drives()
	naval_check(!engine.on && bunker.reagents.get_reagent_amount("diesel") == 3, "a tank that cannot pay for a hop stalls the engine")
	naval_check(C.sail_tick() && C.speed == VESSEL_SPEED_SLOW && tiller.y == y_was + 8, "and she loses way to slow ahead ([tiller.y])")
	engine.on = TRUE
	engine.broken = TRUE
	naval_check(C.fit_drives() == 1 && C.thrust() == 0, "a broken engine pushes nothing")
	engine.broken = FALSE
	var/obj/structure/vehicleparts/frame/bed = new(get_turf(engine))
	naval_check(C.fit_drives() == 0, "an engine fitted to a vehicle's frame is that vehicle's, not hers")
	qdel(bed)
	qdel(engine)
	qdel(bunker)
	C.fit_drives()

	// ---- Wiring rides along ----
	var/list/planks = B.cells()
	var/obj/structure/cable/c1 = new(planks[1])
	var/obj/structure/cable/c2 = new(planks[2])
	var/obj/structure/cable/c3 = new(planks[3])
	var/obj/structure/cable/ashore = new(locate(60, 55, 2))
	c1.connections = list(c2)
	c2.connections = list(c1, c3)
	c3.connections = list(c2, ashore)
	ashore.connections = list(c3)
	var/obj/structure/engine/internal/hotbulb/dynamo = new(planks[1])
	dynamo.connections = list(c1)
	c1.connections += dynamo
	var/obj/structure/probe_gun/lamp = new(planks[3])
	lamp.powersource = c3
	lamp.powered = TRUE
	c3.connections += lamp
	var/obj/structure/probe_gun/quay_lamp = new(locate(60, 54, 2))
	quay_lamp.powersource = c2
	quay_lamp.powered = TRUE
	c2.connections += quay_lamp
	var/turf/corner_was = B.origin()
	var/moved = FALSE
	for (var/list/step in list(list(1, 0), list(-1, 0), list(0, 1), list(0, -1)))
		if (B.can_move_to(corner_was.x + step[1], corner_was.y + step[2], B.heading()))
			moved = B.move_to(corner_was.x + step[1], corner_was.y + step[2], B.heading())
			break
	naval_check(moved && B.contains(get_turf(c1)) && B.contains(get_turf(c3)) && get_turf(c1) != planks[1], "the cables hop with her")
	naval_check((c2 in c1.connections) && (c1 in c2.connections) && (c3 in c2.connections) && (c2 in c3.connections), "and are still joined to each other")
	naval_check((dynamo in c1.connections) && (c1 in dynamo.connections) && lamp.powersource == c3 && lamp.powered && (lamp in c3.connections), "her engine and her lamp are still on the grid")
	naval_check(!(ashore in c3.connections) && !(c3 in ashore.connections), "the cable to the shore has parted")
	naval_check(!(quay_lamp in c2.connections) && !quay_lamp.powersource && !quay_lamp.powered, "and the lamp on the quay is off her grid")
	naval_check(isnull(craft_rigid_cargo), "nothing is being carried once she has arrived")
	c1.tiledir = "horizontal"
	c1.update_icon()
	var/turned_to = turn(B.heading(), 90)
	naval_check(B.turn_to(turned_to) && c1.tiledir == "vertical" && c1.icon_state == "vertical" && (c2 in c1.connections), "a quarter turn lays an east-west cable north-south and keeps it joined ([c1.tiledir])")
	c2.forceMove(locate(58, 55, 2))
	naval_check(!(c2 in c1.connections) && !(c2 in c3.connections) && !c2.connections.len, "a cable dragged off her by hand still drops its links")
	for (var/obj/wired in list(c1, c2, c3, ashore, dynamo, lamp, quay_lamp))
		qdel(wired)
	C.fit_drives()

	// ---- Striking her ----
	tiller.decommission()
	naval_check(!corner.afloat, "struck, her planks are plain planks")
	naval_check(!tiller.craft && !crafts.len && hull_planks(get_turf(tiller)) == 1, "struck, she is planks again and the planks stay")
	naval_check(isnull(tiller.commission("Wren", NORTH)) && crafts.len == 1, "and can be commissioned again")
	qdel(tiller)
	naval_check(!crafts.len, "a hull whose tiller is gone is no craft")

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
