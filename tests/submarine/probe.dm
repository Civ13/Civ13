// Player submarines: the sea layer under deep ocean, diving, surfacing,
// submerged movement, the periscope, contacts and the submarine pen.
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 2
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/submarine_probe
	sea_layer_surface_z = 2
/obj/map_metadata/submarine_probe/New()
	return
/mob/living/submarine_probe/New()
	return
// A diver sealed in a diving suit (the fixture cannot build a full human).
/mob/living/submarine_probe/diver/can_walk_seabed()
	return TRUE
/obj/covers/submarine_probe_raft
	name = "probe raft"
var/submarine_failures = 0
var/submarine_runtime_error = FALSE
/proc/submarine_check(condition, label)
	if (!condition)
		submarine_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	submarine_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// How many tiles the boat's hull sections span along "x" or "y".
/proc/submarine_span(obj/structure/vehicleparts/axis/ship/submarine/S, axis)
	var/low = 1000
	var/high = 0
	for (var/obj/structure/vehicleparts/frame/F in S.frames())
		var/v = axis == "x" ? F.x : F.y
		low = min(low, v)
		high = max(high, v)
	return high - low + 1

/proc/submarine_turf(x, y, z)
	var/turf/T = locate(x, y, z)
	return T

/proc/submarine_frames_z(obj/structure/vehicleparts/axis/ship/submarine/S, z)
	var/list/F = S.frames()
	if (!F.len)
		return FALSE
	for (var/obj/structure/vehicleparts/frame/FR in F)
		if (FR.z != z)
			return FALSE
	return TRUE

/proc/submarine_front_y(obj/structure/vehicleparts/axis/ship/submarine/S)
	. = 1000
	for (var/obj/structure/vehicleparts/frame/F in S.frames())
		. = min(., F.y)

/proc/submarine_checks()
	// Surface (z2): land at x 1-3, shallows at x 4, deep ocean from x 5.
	// Below (z1): solid rock, with an old tunnel dug at x 25-27, y 3.
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/S = locate(x, y, 2)
			if (x <= 3)
				S.ChangeTurf(/turf/floor/dirt)
			else if (x == 4)
				S.ChangeTurf(/turf/floor/beach/water/shallowsaltwater)
			else
				S.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
			var/turf/B = locate(x, y, 1)
			B.ChangeTurf(/turf/wall/rockwall)
	for (var/x = 25, x <= 27, x++)
		locate(x, 3, 1).ChangeTurf(/turf/floor/dirt)

	// The sea layer opens only under open ocean, keeping a rock shell.
	submarine_check(sea_layer_z() == 1, "the sea layer lies on the level below the surface")
	var/opened = sea_layer_build(2, 1)
	submarine_check(opened > 300, "rock under the open ocean opens to the sea ([opened] cells)")
	submarine_check(sea_layer_cell(locate(15, 15, 1)), "a cell under open ocean is sea")
	submarine_check(submarine_turf(2, 15, 1).type == /turf/wall/rockwall, "rock under land stays rock")
	submarine_check(submarine_turf(5, 15, 1).type == /turf/wall/rockwall && sea_layer_cell(locate(6, 15, 1)), "a rock shell stays under the coast, sea starts one tile out")
	submarine_check(submarine_turf(24, 4, 1).type == /turf/wall/rockwall && submarine_turf(26, 4, 1).type == /turf/wall/rockwall && submarine_turf(26, 3, 1).type == /turf/floor/dirt, "an old tunnel keeps its rock shell and is not flooded")
	submarine_check(submarine_turf(1, 1, 1).type == /turf/wall/rockwall, "the map corner under land stays rock")
	submarine_check(sea_layer_build(2, 1) == 0, "a second pass changes nothing")

	// Depth zones by distance from the nearest rock.
	var/marked = seabed_zone_pass(1)
	submarine_check(seabed_zones_ready && marked == opened, "every sea cell gets a depth zone ([marked] of [opened])")
	var/zone_total = 0
	for (var/n in seabed_zone_counts)
		zone_total += n
	submarine_check(zone_total == marked, "the zone counts add up ([json_encode(seabed_zone_counts)])")
	submarine_check(sea_zone_of(locate(6, 15, 1)) == SEA_ZONE_SHELF && sea_zone_of(locate(11, 15, 1)) == SEA_ZONE_SHELF, "the six cells off the coast are the shelf")
	submarine_check(sea_zone_of(locate(12, 15, 1)) == SEA_ZONE_OPEN && sea_zone_of(locate(14, 15, 1)) == SEA_ZONE_OPEN, "farther out is open water")
	submarine_check(sea_zone_of(locate(22, 22, 1)) == SEA_ZONE_DEEP, "far from any rock is the deep")
	submarine_check(sea_zone_of(locate(26, 6, 1)) == SEA_ZONE_SHELF, "the water around an old tunnel's rock is shelf again")
	submarine_check(!sea_zone_of(locate(2, 15, 1)), "rock has no depth zone")
	var/turf/open_sea = locate(15, 15, 1)
	submarine_check(!open_sea.outside_air_breathable() && open_sea.outside_ambient_c() == 8, "open sea has no air and is cold (got [open_sea.outside_ambient_c()])")
	submarine_check(locate(7, 15, 1).outside_ambient_c() == 14 && locate(22, 22, 1).outside_ambient_c() == 4, "the deep is colder than the shelf")

	// After a save load the pass waits for the world to settle first.
	sea_layer_ready_at = 0
	submarine_check(!sea_layer_settled() && sea_layer_ready_at == world.time, "the pass waits once the world is first seen ready")
	sea_layer_ready_at = world.time - 30 SECONDS
	submarine_check(!sea_layer_settled(), "the pass still waits half a minute after the world is ready")
	sea_layer_ready_at = world.time - 61 SECONDS
	submarine_check(sea_layer_settled(), "the pass starts a minute after the world is ready")

	// Nobody walks or swims into the sea layer.
	var/mob/living/submarine_probe/swimmer = new(locate(26, 3, 1))
	var/turf/sea = locate(15, 15, 1)
	submarine_check(!sea.CanPass(swimmer, sea), "a mob cannot enter open sea")
	submarine_check(!submarine_turf(5, 15, 2).CanPass(swimmer, submarine_turf(5, 15, 2)), "deep water on the surface still blocks a mob (unchanged)")

	// A submarine builds as a working ship: 15 hull frames, wheel, station, engine.
	var/obj/structure/vehicleparts/axis/ship/submarine/S = build_submarine(locate(10, 10, 2), "probe boat")
	submarine_check(istype(S) && S.frames().len == 15, "the submarine builds fifteen hull frames ([S ? S.frames().len : 0])")
	submarine_check(S && S.engine && S.engine.fueltank && (S in ship_axes), "an engine, a fuel tank and the ship registry are connected")
	var/obj/structure/vehicleparts/shipwheel/W = locate() in locate(13, 10, 2)
	submarine_check(W && W.ship == S, "the ship wheel steers this boat")
	var/obj/structure/vehicleparts/sub_station/station = locate() in locate(12, 11, 2)
	submarine_check(station && station.boat() == S, "the ballast and periscope station belongs to this boat")
	var/obj/structure/vehicleparts/frame/F1 = locate() in locate(12, 12, 2)
	submarine_check(F1 && !F1.noroof && F1.w_left[1] == "" && F1.w_right[1] == "", "the hull is roofed with open hatches amidships")
	submarine_check(!S.submerged && S.periscope_turf() == get_turf(S), "a new boat floats on the surface")

	// The Scout's hull: every section shows its own tile of the boat's
	// drawing, the bow is glazed, the engine room lies behind a watertight
	// door and the stern quarters are sealed.
	var/list/hull_states = icon_states('icons/obj/vehicles/submarine_hull.dmi')
	var/hull_art = TRUE
	for (var/obj/structure/vehicleparts/frame/ship/steel/submarine/HF in S.frames())
		if (!("[HF.hull_tile]_deck" in hull_states) || !("[HF.hull_tile]_roof" in hull_states) || HF.icon_state != "[HF.hull_tile]_deck" || !HF.roof || HF.roof.icon_state != "[HF.hull_tile]_roof" || HF.roof.dir != HF.dir)
			hull_art = FALSE
	submarine_check(S.hull_class == "scout" && S.hull_square() == 5 && hull_art, "every Scout hull section draws its own deck and roof tile")
	var/obj/structure/vehicleparts/frame/ship/steel/submarine/bow = locate() in locate(13, 10, 2)
	submarine_check(bow && bow.hull_tile == "scout_2_1" && bow.w_front[1] == "sub_glass" && !bow.w_front[2] && bow.w_front[3], "the bow is glass: it blocks the way but not the view")
	var/obj/structure/vehicleparts/frame/ship/steel/submarine/door = locate() in locate(13, 13, 2)
	var/mob/living/submarine_probe/walker = new(locate(13, 13, 2))
	submarine_check(door && door.door_walls().len == 1 && !door.CheckExit(walker, locate(13, 12, 2)), "the watertight door to the engine room starts shut")
	submarine_check(door && door.toggle_doors() && door.CheckExit(walker, locate(13, 12, 2)) && door.overlays.len == 1, "opening the door lets the crew through")
	submarine_check(door && door.toggle_doors() && !door.CheckExit(walker, locate(13, 12, 2)), "shutting it closes the way again")
	door.toggle_doors()
	var/obj/structure/vehicleparts/frame/ship/steel/submarine/quarter = locate() in locate(12, 14, 2)
	submarine_check(quarter && !quarter.CheckExit(walker, locate(13, 14, 2)) && !quarter.CheckExit(walker, locate(12, 13, 2)) && !bow.toggle_doors(), "the stern quarters are sealed and a plain section has no door")
	qdel(walker)
	var/obj/structure/vehicleparts/sub_fitting/battery/cells = locate() in locate(12, 13, 2)
	var/obj/structure/vehicleparts/sub_fitting/air/flasks = locate() in locate(14, 13, 2)
	submarine_check(cells && cells.boat() == S && findtext(cells.reading(S), "attery") && flasks && flasks.boat() == S && findtext(flasks.reading(S), "bank") && (locate(/obj/structure/closet/dive_locker) in locate(14, 11, 2)), "the battery bank, air bank and dive locker are fitted and read the boat")

	// Crew and cargo aboard.
	var/mob/living/submarine_probe/crew = new(locate(13, 13, 2))
	var/obj/structure/closet/crate/cargo = new(locate(13, 12, 2))
	submarine_check(submarine_turf(15, 15, 1).CanPass(crew, submarine_turf(15, 15, 1)) == FALSE, "the sea refuses a mob with no hull over it")

	// Diving.
	S.moving = TRUE
	submarine_check(findtext(S.depth_refusal(TRUE), "stop"), "a moving boat must stop before it dives")
	S.moving = FALSE
	var/obj/covers/submarine_probe_raft/raft = new(locate(13, 14, 2))
	submarine_check(!S.depth_refusal(TRUE), "a stopped boat over open sea may dive")
	submarine_check(!S.change_depth(TRUE), "the boat dives")
	submarine_check(S.submerged && submarine_frames_z(S, 1), "every hull frame is on the sea layer")
	submarine_check(crew.z == 1 && cargo.z == 1 && station.z == 1 && W.z == 1 && S.engine.z == 1, "crew, cargo and machinery go down with the boat")
	var/turf/crew_here = get_turf(crew)
	submarine_check(crew_here.CanPass(crew, crew_here), "inside the hull the crew can move")
	submarine_check(!submarine_turf(15, 13, 1).CanPass(crew, crew_here), "the crew cannot leave a submerged boat")

	// Divers: the open sea lets them through, but never straight in or out of a boat.
	var/turf/hull_air = get_turf(crew)
	submarine_check(hull_air.outside_air_breathable() && isnull(hull_air.outside_ambient_c()), "inside the hull there is air")
	var/mob/living/submarine_probe/diver/diver = new(locate(20, 20, 1))
	submarine_check(locate(21, 20, 1).CanPass(diver, locate(21, 20, 1)), "a diver walks the open seabed")
	var/mob/living/submarine_probe/diver/inside = new(locate(12, 12, 1))
	submarine_check(!locate(11, 12, 1).CanPass(inside, locate(11, 12, 1)), "a diver cannot step out of a submerged boat past the lock-out hatch")
	diver.forceMove(locate(11, 12, 1))
	submarine_check(!locate(12, 12, 1).CanPass(diver, locate(12, 12, 1)), "a diver cannot step into a submerged boat past the lock-out hatch")
	var/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch/starboard = locate() in locate(12, 12, 1)
	var/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch/port = locate() in locate(14, 12, 1)
	submarine_check(starboard && starboard.boat() == S && port && port.boat() == S, "both side hatches are lock-out hatches of this boat")
	submarine_check(port && port.lockout_exit() == locate(15, 12, 1), "the port hatch opens onto the seabed beside it")
	locate(15, 12, 1).ChangeTurf(/turf/wall/rockwall)
	submarine_check(port && !port.lockout_exit(), "rock against the hull keeps the hatch shut")
	locate(15, 12, 1).ChangeTurf(/turf/floor/beach/water/deep/saltwater/underwater/sea_layer)
	var/obj/item/weapon/shoring_kit/dropped = new(locate(20, 22, 1))
	locate(20, 22, 1).Entered(dropped)
	qdel(inside)

	// Hull air: the crew breathe one ledger; the blowers spend the air bank.
	submarine_check(S.hull_volume() == 15 && S.air_bank == 6000 && S.air_breathers() == 1, "the hull holds 15 tiles of air, a full bank and one breather (got [S.hull_volume()], [S.air_bank], [S.air_breathers()])")
	S.air_step(2000)
	submarine_check(S.hull_air.breathable() && S.air_bank < 6000, "half an hour submerged: the blowers keep the air fresh from the bank ([S.air_report()])")
	S.air_bank = 0
	S.air_step(5000)
	submarine_check(!S.hull_air.breathable() && findtext(S.air_report(), "NOT BREATHABLE"), "with the bank empty the air goes stale ([S.air_report()])")
	submarine_check(!hull_air.outside_air_breathable(), "stale hull air cannot be breathed")
	submarine_check(!S.blow_chamber(), "an empty bank cannot blow the lock-out chamber")
	S.air_bank = 100
	submarine_check(S.blow_chamber() && S.air_bank == 40, "blowing the chamber dry costs 60 bank air")
	submarine_check(S.bank_oxygen(50) == 40 * 0.21 && S.air_bank == 0, "a bottle takes only the oxygen the bank still holds")
	S.air_bank = 6000

	// Battery, floodlights, hull depth and sonar.
	submarine_check(S.battery == 5400 && S.hull_rating == SEA_ZONE_OPEN && !S.hull_leaks, "a new boat has a full battery and a hull rated for open water")
	S.set_floodlights(TRUE)
	submarine_check(S.floodlight_source == W && W.light_range == 7, "the floodlights shine from the bow")
	S.systems_step(100)
	submarine_check(S.battery == 5300, "the floodlights drain the battery while submerged (got [S.battery])")
	S.hull_rating = SEA_ZONE_SHELF
	S.hull_pressure_step(100)
	submarine_check(S.hull_leaks == 1, "deeper than its rating the hull springs a leak")
	S.hull_rating = SEA_ZONE_OPEN
	var/bank_before = S.air_bank
	S.air_step(100)
	var/leak_cost = bank_before - S.air_bank
	S.hull_leaks = 0
	bank_before = S.air_bank
	S.air_step(100)
	submarine_check(leak_cost > (bank_before - S.air_bank), "a leaking hull costs the air bank more ([leak_cost] vs [bank_before - S.air_bank])")
	var/list/sonar = S.sonar_lines()
	submarine_check(findtext(sonar[1], "open water") && findtext(sonar[2], "west"), "a sonar ping reports the depth and the rock to the west ([jointext(sonar, " | ")])")
	S.battery = 0
	S.battery_draw(1)
	submarine_check(!S.floodlight_source && !W.light_range, "a flat battery puts the floodlights out")
	submarine_check(!S.do_vehicle_check(), "a flat battery stops the submerged boat")
	submarine_check(!S.sonar_ping(crew), "a flat battery cannot ping")
	S.battery = 5400
	S.set_floodlights(FALSE)
	submarine_check(S.change_depth(TRUE) == "The boat is already submerged.", "a second dive is refused")
	var/turf/boat_here = get_turf(S)
	submarine_check(S.periscope_turf() == locate(boat_here.x, boat_here.y, 2), "the periscope looks at the surface straight above")

	// Surfacing is refused under anything floating.
	submarine_check(findtext(S.depth_refusal(FALSE), "probe raft"), "the boat cannot surface under a raft")
	qdel(raft)
	submarine_check(!S.depth_refusal(FALSE), "with the raft gone it may surface")
	var/turf/above_bow = submarine_turf(12, 10, 2)
	var/obj/structure/vehicle/raft/real_raft = new(above_bow)
	submarine_check(findtext(S.depth_refusal(FALSE), "[real_raft.name]"), "a moored raft above blocks surfacing too")
	qdel(real_raft)
	submarine_check(!S.depth_refusal(FALSE), "with both gone it may surface")

	// Contacts: ships and aircraft on the surface, submerged boats by sonar.
	var/obj/structure/vehicleparts/axis/ship/submarine/surface_ship = build_submarine(locate(20, 20, 2), "surface ship")
	var/obj/structure/vehicleparts/axis/ship/submarine/deep_boat = build_submarine(locate(18, 3, 2), "deep boat")
	submarine_check(deep_boat && !deep_boat.change_depth(TRUE), "a second boat dives")
	var/list/lines = S.contacts()
	var/text = jointext(lines, "\n")
	submarine_check(findtext(text, "Ship: surface ship"), "the periscope sees the surface ship ([text])")
	submarine_check(findtext(text, "Sonar: a submerged boat"), "sonar hears the other submerged boat")
	submarine_check(!findtext(text, "deep boat"), "sonar does not name the other boat")
	var/list/surface_lines = surface_ship.contacts()
	submarine_check(!findtext(jointext(surface_lines, "\n"), "submerged"), "a surface ship cannot see submerged boats ([jointext(surface_lines, "|")])")

	// Submerged movement follows the sea layer and stops at the seabed.
	var/obj/structure/engine/internal/E = S.engine
	E.fueltank.reagents.add_reagent(E.fuels[1], 100, safety = TRUE)
	E.on = TRUE
	S.anchor = FALSE
	S.moving = TRUE
	S.currentspeed = 1
	var/front = submarine_front_y(S)
	submarine_check(S.do_vehicle_check() && S.do_move(), "the submerged boat moves through open sea")
	submarine_check(submarine_front_y(S) == front - 1 && submarine_frames_z(S, 1) && crew.z == 1, "it moves a tile south on the sea layer with its crew")
	var/turf/ahead = locate(13, submarine_front_y(S) - 1, 1)
	ahead.ChangeTurf(/turf/wall/rockwall)
	submarine_check(!S.do_vehicle_check() && !S.moving, "rock ahead stops the boat")
	ahead.ChangeTurf(/turf/floor/beach/water/deep/saltwater/underwater/sea_layer)
	E.on = FALSE

	// Surfacing brings everyone back up.
	S.moving = FALSE
	submarine_check(!S.change_depth(FALSE), "the boat surfaces")
	submarine_check(!S.submerged && submarine_frames_z(S, 2) && crew.z == 2 && cargo.z == 2, "the boat, crew and cargo are back on the surface")
	S.air_step(10)
	submarine_check(S.hull_air.breathable() && !S.hull_air.co2 && S.air_bank == 500 && S.air_breathable(), "on the surface the hatches air the boat out and the compressor refills the bank ([S.air_report()])")
	S.battery = 0
	S.systems_step(10)
	submarine_check(S.battery == 450, "on the surface the diesel charges the battery")

	// Diving needs open sea under every frame: not beside the coast.
	var/obj/structure/vehicleparts/axis/ship/submarine/coaster = build_submarine(locate(2, 20, 2), "coaster")
	submarine_check(coaster && findtext(coaster.depth_refusal(TRUE), "seabed"), "a boat by the coast cannot dive ([coaster ? coaster.depth_refusal(TRUE) : "none"])")

	// Research and the submarine pen.
	if (!research_nodes.len)
		build_research_tree()
	var/datum/research_node/N = get_research_node("submarines")
	submarine_check(N && ("combustion" in N.prereqs) && ("wagons_ships" in N.prereqs) && N.era_tier == 6, "Submarines research follows ships and combustion")
	submarine_check(get_recipe_node_req("/obj/structure/car_workshop/submarine_pen") == "submarines", "Submarines research gates the pen (got [get_recipe_node_req("/obj/structure/car_workshop/submarine_pen")])")
	for (var/gear in list("/obj/item/clothing/suit/pressure_suit/diving", "/obj/item/clothing/head/pressure_helmet/diving", "/obj/item/pressure_tank/diving"))
		submarine_check(get_recipe_node_req(gear) == "submarines", "Submarines research gates [gear]")
	for (var/gear in list("/obj/item/clothing/suit/pressure_suit/diving/hard", "/obj/item/clothing/head/pressure_helmet/diving/hard", "/obj/item/sub_hull_plating"))
		submarine_check(get_recipe_node_req(gear) == "naval_aviation", "Naval Aviation research gates [gear]")
	submarine_check(new /obj/item/clothing/suit/pressure_suit/diving/hard(locate(1, 1, 2)).depth_rating == SEA_ZONE_DEEP, "the hard dive suit is built for the deep")
	var/obj/item/clothing/suit/pressure_suit/diving/dress = new(locate(1, 1, 2))
	submarine_check(dress.depth_rating == SEA_ZONE_SHELF && !dress.has_heater && !new /obj/item/clothing/suit/pressure_suit(locate(1, 1, 2)).depth_rating, "the diving dress is built for the shelf; a space suit is not for diving")
	sleep(70)
	submarine_check(!QDELETED(dropped) && get_turf(dropped) == locate(20, 22, 1), "things dropped on the seabed stay there")
	var/obj/structure/car_workshop/submarine_pen/pen = new(locate(3, 23, 2))
	submarine_check(pen.model_size("Scout submarine") == 5 && pen.costs("Scout submarine")["steel"] == 90 && pen.model_size("Explorer submarine") == 7 && pen.costs("Explorer submarine")["steel"] == 140 && pen.largest_model_size() == 5 && !pen.allowed(null), "the pen builds the Scout and the Explorer, after Submarines research, and fits where a Scout does")
	submarine_check(!pen.complete_assembly("Scout submarine"), "an empty pen builds nothing")
	pen.stock = list("steel" = 100, "glass" = 5, "cloth" = 0, "cable" = 12, "wheels" = 0)
	submarine_check(!pen.complete_assembly("Scout submarine"), "a pen whose bay reaches the shallows builds nothing")
	qdel(pen)
	pen = new(locate(20, 24, 2))
	pen.stock = list("steel" = 100, "glass" = 5, "cloth" = 0, "cable" = 12, "wheels" = 0)
	var/obj/structure/vehicleparts/axis/ship/submarine/built = pen.complete_assembly("Scout submarine")
	submarine_check(istype(built) && built.frames().len == 15, "the pen launches a submarine into its bay of deep sea")
	if (istype(built))
		var/obj/structure/engine/internal/BE = built.engine
		submarine_check(BE.fueltank && !BE.fueltank.reagents.total_volume, "the launched boat has an empty tank")
		submarine_check(built.keyed_vehicle_id && pen.stock["steel"] == 10 && pen.stock["cable"] == 0, "the pen issues keys and spends its inputs")

	// The Explorer: 21 hull sections in a 7x7 turning square.
	var/obj/structure/vehicleparts/axis/ship/submarine/explorer/X = build_submarine(locate(23, 8, 2), "explorer", /obj/structure/vehicleparts/axis/ship/submarine/explorer)
	submarine_check(istype(X) && X.frames().len == 21 && X.hull_square() == 7 && X.maxdist == 7 && X.hull_volume() == 21, "the Explorer builds 21 hull sections in a 7x7 square ([X ? X.frames().len : 0], [X ? X.maxdist : 0])")
	if (istype(X))
		var/explorer_art = TRUE
		var/hatches = 0
		var/doors = 0
		for (var/obj/structure/vehicleparts/frame/ship/steel/submarine/XF in X.frames())
			if (!("[XF.hull_tile]_deck" in hull_states) || !("[XF.hull_tile]_roof" in hull_states))
				explorer_art = FALSE
			if (istype(XF, /obj/structure/vehicleparts/frame/ship/steel/submarine/hatch))
				hatches++
			doors += XF.door_walls().len
		var/obj/structure/vehicleparts/shipwheel/XW = locate() in locate(28, 8, 2)
		submarine_check(explorer_art && hatches == 2 && doors == 2 && XW && XW.ship == X && X.floodlight_holder() == XW && X.engine && X.engine.fueltank, "the Explorer has its own hull art, two lock-out hatches, two watertight doors, a wheel and an engine")
		submarine_check(submarine_span(X, "x") == 3 && submarine_span(X, "y") == 7, "it lies 3 wide and 7 long")
		submarine_check(X.do_matrix(X.dir, TURN_LEFT(X.dir), "left") && submarine_span(X, "x") == 7 && submarine_span(X, "y") == 3 && X.frames().len == 21, "the Explorer turns left inside its square ([submarine_span(X, "x")]x[submarine_span(X, "y")])")
		var/turned = TRUE
		for (var/obj/structure/vehicleparts/frame/ship/steel/submarine/XF in X.frames())
			if (XF.dir != X.dir || XF.roof.dir != X.dir)
				turned = FALSE
		submarine_check(turned && get_turf(XW) && submarine_at(get_turf(XW)) == X, "every section and its roof face the new heading and the wheel stays aboard")
		submarine_check(X.do_matrix(X.dir, TURN_RIGHT(X.dir), "right") && submarine_span(X, "x") == 3 && submarine_span(X, "y") == 7 && get_turf(XW) == locate(28, 8, 2), "turning right brings it back where it lay")
		submarine_check(vehicle_rotation_target(5, "right", "1,2") == "2,5" && vehicle_rotation_target(5, "left", "1,2") == "4,1" && vehicle_rotation_target(7, "right", "1,2") == "2,7" && vehicle_rotation_target(7, "left", "1,2") == "6,1", "a 7x7 square turns by the same rule as the 5x5 table")

/proc/submarine_run()
	try
		submarine_checks()
	catch(var/exception/e)
		submarine_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = submarine_failures, "runtime_error" = submarine_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/submarine_probe
		submarine_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		submarine_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		submarine_run()
