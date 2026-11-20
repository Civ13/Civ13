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
var/hull_probe_watched = FALSE
// Nobody has a client here; the probe says when a player is near.
/datum/vehicle_offset/hull/watched()
	return hull_probe_watched
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
// Writes down the glide it had when it was moved: the engine draws a move at
// the glide a thing has at that moment.
/obj/structure/probe_glide_spy
	var/moved_at_glide = -1

/obj/structure/probe_glide_spy/forceMove(atom/destination)
	. = ..()
	moved_at_glide = glide_size

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
		if (C.loc == T)
			.++

// The steps a half minute covers at her speed: a gliding hull makes one tile
// a step. TRUE when every step moved her.
/proc/hull_leg(datum/craft/C)
	var/steps = 0
	while (steps < C.speed * VESSEL_TILES_PER_STEP)
		if (!C.sail_tick())
			return FALSE
		steps++
	return steps > 0

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
	// The plank's own update a moment after it is laid finds the water gone
	// already; it must keep the level it found first, or the sea stays drained
	// where she was built once she sails (2026-11-17 report).
	sleep(10)
	naval_check(under.water_level == 0 && corner.origin_water_level == shallow, "a plank still keeps the water under it after its own update ([corner.origin_water_level])")
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
	naval_check(hop && hop[1] == 31 && hop[2] == 10 && C.glides() && C.sail_tiles() == 1 && C.sail_interval() == 150, "her next step is one tile east, and slow ahead is a tile every fifteen seconds ([C.sail_interval()])")
	naval_check(C.warn_tick() == 3 && C.path_markers.len == 3 && hull_planks(locate(35, 10, 2)) == 0, "the three tiles of water she will cover are marked, and nothing has moved ([C.path_markers.len])")
	// ---- Each step is drawn as a glide (craft/glide.dm) ----
	var/slow_glide = craft_glide_size(150)
	var/corner_glide = corner.glide_size
	var/mob/living/human/naval_probe/free = new(locate(32, 10, 2))
	free.step_x = 5
	free.pixel_x = 3
	var/free_glide = free.glide_size
	var/obj/structure/probe_gun/overboard = new(locate(32, 11, 2))
	// Live report (2026-11-15): a log stack shoved across her deck crept a
	// tile over half a minute. Her pace is for her own steps only.
	var/obj/item/stack/material/wood/logs = new(locate(33, 11, 2))
	var/logs_glide = logs.glide_size
	var/obj/structure/probe_glide_spy/spy = new(locate(30, 12, 2))
	naval_check(C.sail_tick() && tiller.x == 33 && !C.path_markers.len, "one step carries the tiller one tile east and clears the marks ([tiller.x])")
	naval_check(corner.glide_size == slow_glide && tiller.glide_size == slow_glide && ann.glide_size == slow_glide && slow_glide > 0 && slow_glide < 1, "planks, tiller and a sailor square on her tile glide for the whole step ([corner.glide_size])")
	naval_check(free.x == 33 && free.step_x == 5 && free.pixel_x == 3 && free.glide_size == free_glide, "a sailor standing off-centre is carried, keeps her place and offset, and is slid by animation, not by glide")
	naval_check(logs.x == 34 && logs.glide_size == slow_glide && logs.craft_glide_was == B.glide_was, "a log stack on her deck rides her step at her pace ([logs.glide_size])")
	// Ship report (2026-11-15): she still jumped a tile at a time in a real
	// client. Her pace has to be on a thing as it moves, not given after.
	naval_check(spy.x == 31 && spy.moved_at_glide == slow_glide, "her first step moves a thing at her pace already ([spy.moved_at_glide])")
	qdel(spy)
	logs.Move(locate(33, 11, 2), WEST)
	naval_check(logs.x == 33 && logs.glide_size == logs_glide && !logs.craft_glide_was && !(logs in B.glide_was), "pushed along her deck, it moves at its own pace, not hers ([logs.glide_size] vs [logs_glide])")
	naval_check(!logs.persistence_runtime_var("glide_size"), "its own glide is saved as usual")
	overboard.forceMove(locate(50, 8, 2))
	naval_check(C.sail_tick() && tiller.x == 34 && overboard.glide_size != slow_glide && corner.glide_size == slow_glide, "a thing taken off her deck has its own glide back at her next step")
	naval_check(logs.x == 34 && logs.glide_size == slow_glide && logs.persistence_runtime_var("glide_size") && logs.persistence_runtime_var("craft_glide_was"), "her next step takes it again, and a save never keeps her pace on it")
	logs.forceMove(locate(50, 9, 2))
	naval_check(logs.glide_size == logs_glide && !logs.craft_glide_was, "taken overboard, it has its own glide back at once")
	qdel(logs)
	qdel(overboard)
	qdel(free)
	C.set_speed(VESSEL_SPEED_STOP)
	B.glide_rest_now()
	naval_check(corner.glide_size == corner_glide && ann.glide_size != slow_glide && !length(B.glide_was), "stopped, everything aboard glides at its own pace again")
	C.set_speed(VESSEL_SPEED_SLOW)
	naval_check(tiller.x == 34 && tiller.y == 10 && !C.path_markers.len, "two steps have carried the tiller to 34,10 ([tiller.x],[tiller.y])")
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
	naval_check(C.sail_tick() && tiller.x == 35, "with a rock two tiles off the bow she closes up to it ([tiller.x])")
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
	// A turn is shown swinging round (craft/glide.dm): a thing that moved one
	// tile glides, a thing that moved further is slid and keeps its own glide.
	var/near_swung = 0
	var/far_slid = 0
	var/swing_glide = craft_glide_size(glide_turn_time())
	for (var/atom/movable/swung in B.glide_was)
		if (swung.glide_size == swing_glide)
			near_swung++
	for (var/turf/deck in B.cells())
		for (var/obj/covers/plank in deck)
			if (!(plank in B.glide_was) && !plank.pixel_x && !plank.pixel_y)
				far_slid++
	naval_check(near_swung + far_slid >= 11 && far_slid > 0, "after her swing every plank either glides a tile or was slid further and ends square on its tile ([near_swung] glide, [far_slid] slid)")
	B.glide_rest_now()
	naval_check(!length(B.glide_was), "after the turn everything has its own glide back")
	naval_check(B.turn_to(NORTH), "and back")
	B.glide_rest_now()

	// ---- The edge of the bay: land refuses her ----
	var/turf/shoal = locate(35, 15, 2)
	shoal.ChangeTurf(/turf/floor/beach/sand)
	C.set_speed(VESSEL_SPEED_SLOW)
	naval_check(hull_leg(C) && tiller.y == 12, "she closes up to the shoal ([tiller.y])")
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
	naval_check(hull_leg(C) && tiller.y == 14, "and she sails on ([tiller.y])")

	// ---- Sails ----
	var/obj/structure/vehicleparts/movement/sail/mast = new(locate(tiller.x - 1, tiller.y, 2))
	naval_check(B.contains(get_turf(mast)) && C.fit_drives() == 1 && C.thrust() == 0 && C.max_speed() == VESSEL_SPEED_SLOW, "a bare mast pushes nothing")
	mast.sails = new /obj/item/sail(mast)
	naval_check(C.fit_drives() == 1 && C.thrust() == 31 && C.max_speed() == VESSEL_SPEED_HALF, "a rigged mast pushes her thirteen tiles at half ahead ([C.thrust()])")
	naval_check(findtext(tiller.status_text(), "Under 1 sail: half ahead at best"), "the tiller says so ([tiller.status_text()])")
	C.set_speed(VESSEL_SPEED_FULL)
	naval_check(C.speed == VESSEL_SPEED_HALF && mast.sails_on && mast.icon_state == "sail2", "sails alone never make full ahead, and the sail is set while she is under way")
	var/y_was = tiller.y
	naval_check(C.sail_interval() == 75 && hull_leg(C) && tiller.y == y_was + 4 && mast.y == y_was + 4, "half ahead is four tiles in the half minute, mast and all ([tiller.y])")
	C.set_anchor(TRUE)
	naval_check(!mast.sails_on && mast.icon_state == "sail1", "at anchor the sail is furled")
	// ---- Points of sail (naval/points_of_sail.dm): she heads north ----
	var/wind_was = map.winddirection
	map.winddirection = "East"
	naval_check(point_of_sail(NORTH) == SAIL_POINT_BEAM && C.thrust() == 31 && findtext(tiller.status_text(), "Her sails are on a beam reach"), "with the wind on her beam the sail gives its full push ([tiller.status_text()])")
	map.winddirection = "South"
	naval_check(point_of_sail(NORTH) == SAIL_POINT_RUNNING && C.thrust() == 23 && C.max_speed() == VESSEL_SPEED_HALF && findtext(tiller.status_text(), "running before the wind"), "running dead before the wind she is a little slower ([C.thrust()])")
	map.winddirection = "North"
	naval_check(point_of_sail(NORTH) == SAIL_POINT_BEATING && C.thrust() == 8 && C.max_speed() == VESSEL_SPEED_SLOW && findtext(tiller.status_text(), "beating into the wind"), "beating into the wind one sail cannot drive her past slow ahead ([C.thrust()])")
	naval_check(point_of_sail(NORTHEAST) == SAIL_POINT_CLOSE && point_of_sail(SOUTHEAST) == SAIL_POINT_BROAD && sail_delay_factor(NORTHEAST) == SAIL_DELAY_CLOSE && sail_delay_factor(SOUTHEAST) == SAIL_DELAY_REACH, "close-hauled and broad reaches sit between")
	naval_check(sail_step_delay(3) == 7 && sail_delay_factor(EAST) == SAIL_DELAY_REACH && sail_delay_factor(SOUTH) == SAIL_DELAY_RUNNING && sail_delay_factor(NORTH) == SAIL_DELAY_BEATING, "a frame ship's step: a reach is fastest, a run 1.3 times and a beat 3.5 times as long")
	map.winddirection = wind_was
	C.set_anchor(FALSE)
	qdel(mast.sails)
	mast.sails = null
	naval_check(hull_leg(C) && C.speed == VESSEL_SPEED_SLOW && tiller.y == y_was + 6, "with the sail gone she loses way to slow ahead ([tiller.y])")
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
	naval_check(findtext(tiller.status_text(), "Under 1 engine: full ahead at best. Her drives push 66; 13 tiles of hull need 13 for half ahead and 26 from engines or oars for full ahead."), "the tiller says what she needs ([tiller.status_text()])")
	C.set_speed(VESSEL_SPEED_FULL)
	y_was = tiller.y
	naval_check(C.speed == VESSEL_SPEED_FULL && C.sail_interval() == 50 && hull_leg(C) && tiller.y == y_was + 6 && engine.y == y_was + 6 && bunker.y == y_was + 6, "full ahead is six tiles in the half minute, engine and tank and all ([tiller.y])")
	naval_check(bunker.reagents.get_reagent_amount("diesel") == 3, "those six tiles burn 27 units from her tank at full ahead ([bunker.reagents.get_reagent_amount("diesel")])")
	C.set_speed(VESSEL_SPEED_SLOW)
	bunker.reagents.add_reagent("diesel", 9)
	C.burn_drives()
	naval_check(bunker.reagents.get_reagent_amount("diesel") == 3, "slow ahead burns a third of that ([bunker.reagents.get_reagent_amount("diesel")])")
	C.set_speed(VESSEL_SPEED_FULL)
	C.burn_drives()
	naval_check(!engine.on && bunker.reagents.get_reagent_amount("diesel") == 3, "a tank that cannot pay for a hop stalls the engine")
	naval_check(hull_leg(C) && C.speed == VESSEL_SPEED_SLOW && tiller.y == y_was + 8, "and she loses way to slow ahead ([tiller.y])")
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

	// ---- Rowing benches (naval/rowing_bench.dm) ----
	var/list/benches = list()
	var/list/rowers = list()
	var/list/deck = B.cells()
	for (var/i = 1, i <= 7, i++)
		var/turf/seat = deck[i]
		var/obj/structure/bed/chair/wood/rowing_bench/RB = new(seat)
		benches += RB
		var/mob/living/human/naval_probe/R = new(seat)
		R.real_name = "Rower [i]"
		R.stats = list("stamina" = list(100, 100))
		rowers += R
	naval_check(C.fit_drives() == 7 && C.thrust() == 0 && C.max_speed() == VESSEL_SPEED_SLOW, "empty benches push nothing")
	for (var/i = 1, i <= 7, i++)
		var/obj/structure/bed/chair/wood/rowing_bench/RB = benches[i]
		var/mob/living/human/naval_probe/R = rowers[i]
		R.buckled = RB
		RB.buckled_mob = R
	naval_check(C.fit_drives() == 7 && C.thrust() == 7 * CRAFT_OAR_THRUST && C.max_speed() == VESSEL_SPEED_FULL && !C.sustained_full_ahead(), "seven manned benches row her thirteen tiles at full ahead, but not for a voyage ([C.thrust()])")
	naval_check(findtext(tiller.status_text(), "Under 7 manned benches of oars: full ahead at best"), "the tiller counts the oars ([tiller.status_text()])")
	C.set_speed(VESSEL_SPEED_FULL)
	var/obj/structure/bed/chair/wood/rowing_bench/first = benches[1]
	var/mob/living/human/naval_probe/stroke = rowers[1]
	naval_check(C.speed == VESSEL_SPEED_FULL && C.sail_interval() == 50, "at full ahead she is rowed six tiles in the half minute")
	C.burn_drives()
	naval_check(stroke.stats["stamina"][1] == 100 - 3 * OAR_STAMINA_PER_STEP, "and each rower spends [3 * OAR_STAMINA_PER_STEP] stamina for it ([stroke.stats["stamina"][1]])")
	C.set_speed(VESSEL_SPEED_SLOW)
	C.burn_drives()
	naval_check(stroke.stats["stamina"][1] == 100 - 4 * OAR_STAMINA_PER_STEP, "slow ahead costs a third of that ([stroke.stats["stamina"][1]])")
	for (var/mob/living/human/naval_probe/R in rowers)
		R.stats["stamina"][1] = OAR_MIN_STAMINA - 1
	naval_check(C.fit_drives() == 7 && C.thrust() == 0 && C.max_speed() == VESSEL_SPEED_SLOW, "spent rowers cannot pull: she is poled at slow ahead")
	for (var/mob/living/human/naval_probe/R in rowers)
		R.stats["stamina"][1] = 100
	stroke.buckled = null
	first.buckled_mob = null
	naval_check(C.fit_drives() == 7 && C.thrust() == 6 * CRAFT_OAR_THRUST && C.max_speed() == VESSEL_SPEED_HALF, "a rower who leaves the bench takes its push with him ([C.thrust()])")
	C.set_speed(VESSEL_SPEED_STOP)
	// Bare probe mobs have no species, so they are unseated by hand.
	for (var/obj/structure/bed/chair/wood/rowing_bench/RB in benches)
		if (RB.buckled_mob)
			RB.buckled_mob.buckled = null
			RB.buckled_mob = null
		qdel(RB)
	for (var/mob/living/human/naval_probe/R in rowers)
		R.loc = null
	naval_check(C.fit_drives() == 0, "benches taken off leave no drive")
	if (!research_nodes.len)
		build_research_tree()
	var/obj/structure/hull_tiller/steering_oar/oar = new
	var/datum/research_node/oared = research_nodes["oared_ships"]
	naval_check(istype(oar, /obj/structure/hull_tiller) && oared && oared.era_tier == 1 && get_recipe_node_req("/obj/structure/hull_tiller/steering_oar") == "oared_ships" && get_recipe_node_req("/obj/structure/bed/chair/wood/rowing_bench") == "oared_ships", "the steering oar is a tiller, and both are taught by Oared Ships")
	qdel(oar)

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

	// ---- Sailing by pixels (craft/vehicle_offset_hull.dm) ----
	// A second hull, three by two, bow east, out in the bay.
	for (var/x = 45, x <= 47, x++)
		hull_lay(x, 25)
		hull_lay(x, 26)
	var/obj/structure/hull_tiller/skiff = new(locate(45, 25, 2))
	naval_check(isnull(skiff.commission("Skiff", EAST)) && skiff.craft, "a second hull is commissioned for pixel sailing")
	var/datum/craft/P = skiff.craft
	var/obj/covers/bow_plank = locate(/obj/covers) in locate(47, 26, 2)
	var/mob/living/human/naval_probe/deckhand = new(locate(46, 26, 2))
	var/obj/item/weapon/reagent_containers/glass/bucket/pail = new(locate(46, 25, 2))
	hull_probe_watched = TRUE
	P.set_anchor(FALSE)
	P.set_speed(VESSEL_SPEED_SLOW)
	naval_check(P.offset_sails() && P.hop_timer && P.offset_period() == 150 / 32, "under way she pulses a pixel at a time ([P.offset_period()] ds)")
	P.offset_tick()
	var/datum/vehicle_offset/hull/HO = P.offset_mover
	naval_check(HO && skiff.x == 45 && skiff.step_x == 1 && bow_plank.step_x == 1 && deckhand.step_x == 1 && pail.step_x == 1, "the first pulse moves her deck, tiller, cargo and crew one pixel east together")
	naval_check(P.path_markers.len == 2, "starting to cover the water ahead marks it ([P.path_markers.len])")
	naval_check((deckhand in HO.carried) && (bow_plank in HO.footprint) && vehicle_offset_riders[deckhand] == HO, "everyone aboard is carried; her planks are her body")
	// Place a fresh fitting while the deck is visibly off its turf centre.
	var/list/craft_deck = vessel_building_deck_at(deckhand)
	var/datum/ship_construction/fitting = new(deckhand, craft_deck)
	var/obj/structure/cellar_pump/lever/deck_pump = new(fitting.target(deckhand))
	fitting.align(deck_pump)
	naval_check(deck_pump.loc == deckhand.loc && deck_pump.step_x == HO.ox && vehicle_offset_riders[deck_pump] == HO, "a fresh fitting is centred on the moving deck immediately")
	// A step under way checks nobody else moved the walker; the deck carrying
	// them is not somebody else, so the step goes on from where she put them.
	var/datum/human_subtile_transaction/walk = new
	walk.actor = deckhand
	walk.expected = deckhand.human_subtile_snapshot()
	deckhand.human_subtile_transaction = walk
	P.offset_tick()
	naval_check(deckhand.step_x == 2 && human_subtile_same(walk.expected, deckhand.human_subtile_snapshot()), "a step in progress goes on from where her deck carried the walker")
	// Moved by someone else since the walk's last pulse: the deck does not hide it.
	var/list/stale = walk.expected.Copy()
	stale["sx"] = stale["sx"] - 5
	walk.expected = stale
	P.offset_tick()
	naval_check(!human_subtile_same(walk.expected, deckhand.human_subtile_snapshot()) && walk.expected["sx"] == stale["sx"], "a walker moved by someone else is not carried on by the deck")
	walk.expected = deckhand.human_subtile_snapshot()
	for (var/i = 4 to 15)
		P.offset_tick()
	naval_check(human_subtile_same(walk.expected, deckhand.human_subtile_snapshot()), "the step keeps up with her deck pulse after pulse")
	deckhand.human_subtile_transaction = null
	naval_check(skiff.x == 45 && skiff.step_x == 15 && bow_plank.x == 47 && bow_plank.step_x == 15 && hull_planks(locate(48, 26, 2)) == 0, "fifteen pulses in she is half a tile on and still on her own tiles")
	// Newcomers are judged by her deck as it is drawn, half a tile on.
	var/mob/living/human/naval_probe/boarder = new(locate(46, 25, 2))
	boarder.step_x = -16
	var/mob/living/human/naval_probe/swimmer = new(locate(45, 26, 2))
	swimmer.step_x = -16
	var/datum/human_subtile_transaction/boarding = new
	boarding.actor = boarder
	boarding.expected = boarder.human_subtile_snapshot()
	boarder.human_subtile_transaction = boarding
	HO.sync()
	naval_check(human_subtile_same(boarding.expected, boarder.human_subtile_snapshot()), "someone boarding mid-step goes on with the step from the plank they are filed on")
	boarder.human_subtile_transaction = null
	boarding.actor = null
	var/list/boarded = HO.carried[boarder]
	naval_check(boarded && boarder.x == 45 && boarder.step_x == 16 && boarded[1] == 1, "someone boarding is filed on the plank under their centre and carried from there ([boarder.x],[boarder.step_x], own [boarded ? boarded[1] : "none"])")
	naval_check(!(swimmer in HO.carried) && swimmer.x == 45 && swimmer.step_x == -16, "someone whose centre is over the water astern is not taken aboard")
	qdel(boarder)
	qdel(swimmer)
	naval_check(fitting.target(deckhand) == deckhand.loc && deck_pump.step_x == HO.ox, "carried motion does not cancel stationary work")
	// The deckhand walks three pixels aft as she sails.
	deckhand.step_x -= 3
	naval_check(!fitting.target(deckhand), "actually walking on deck still interrupts the work")
	// That was the walk's own pulse, so its snapshot is where the deckhand stands.
	walk.expected = deckhand.human_subtile_snapshot()
	deckhand.human_subtile_transaction = walk
	P.offset_tick()
	naval_check(human_subtile_same(walk.expected, deckhand.human_subtile_snapshot()), "the step survives her whole-tile move as the offset wraps")
	deckhand.human_subtile_transaction = null
	walk.actor = null
	naval_check(skiff.x == 46 && skiff.step_x == -16 && bow_plank.x == 48 && bow_plank.step_x == -16 && !P.path_markers.len, "past half a tile her own move carries her a tile on and the offset wraps ([skiff.x],[skiff.step_x])")
	naval_check(deckhand.x == 47 && deckhand.step_x == -19 && pail.x == 47 && pail.step_x == -16, "the deckhand keeps the three pixels walked; the pail rides ([deckhand.x],[deckhand.step_x])")
	naval_check(hull_planks(locate(45, 25, 2)) == 0 && hull_planks(locate(48, 25, 2)) == 1 && P.tiles_since_burn == 1, "her planks moved a tile and her drives paid for it")
	naval_check(deck_pump.x == 47 && deck_pump.step_x == HO.ox, "the new fitting crosses a world tile with her deck")
	// Someone pulled off her deck is no longer carried.
	pail.forceMove(locate(52, 40, 2))
	P.offset_tick()
	naval_check(!(pail in HO.carried) && !vehicle_offset_riders[pail] && pail.step_x >= -16 && pail.step_x < 16, "a thing taken off her is dropped and filed by its own centre ([pail.step_x])")
	// Nobody near: she squares on her tiles and hops whole tiles.
	hull_probe_watched = FALSE
	var/square_x = skiff.x
	P.offset_tick()
	naval_check(!skiff.step_x && !bow_plank.step_x && !HO.carried.len && skiff.x == square_x, "with nobody near she squares on her tiles")
	for (var/i = 2 to 32)
		P.offset_tick()
	naval_check(skiff.x == square_x + 1 && !skiff.step_x, "and hops a whole tile at her pace ([skiff.x])")
	// Unwatched, a hop that trims her pace sets the pulse again.
	P.speed = VESSEL_SPEED_HALF
	P.start_sailing()
	for (var/i = 1 to 32)
		if (P.speed != VESSEL_SPEED_HALF)
			break
		P.offset_tick()
	naval_check(P.speed == VESSEL_SPEED_SLOW && P.sailing_at == VESSEL_SPEED_SLOW && P.hop_timer, "unwatched, a hop that loses her way restarts her pulse at the new pace ([P.sailing_at])")
	// A save squares her too.
	hull_probe_watched = TRUE
	P.offset_tick()
	naval_check(skiff.step_x == 1, "watched again, she creeps on by pixels")
	persistence_save_in_progress = TRUE
	P.offset_tick()
	naval_check(!skiff.step_x && !HO.carried.len && !P.offset_sails(), "a save squares her and stops the pixels")
	persistence_save_in_progress = FALSE
	// A rock ahead stops her flush with her tile, all stop with the reason.
	var/obj/structure/probe_rock/reef = new(locate(bow_plank.x + 2, 25, 2))
	P.set_speed(VESSEL_SPEED_SLOW)
	var/pulses = 0
	while (P.speed > 0 && pulses < 100)
		P.offset_tick()
		pulses++
	naval_check(P.speed == VESSEL_SPEED_STOP && !skiff.step_x && bow_plank.x == reef.x - 1 && findtext(P.last_refusal, "probe rock in the way"), "hard against a rock she stops square with the reason ([P.last_refusal], [pulses] pulses)")
	qdel(reef)
	// Coming about: she holds while the turn is marked, then squares and turns.
	P.set_speed(VESSEL_SPEED_SLOW)
	P.offset_tick()
	P.offset_tick()
	naval_check(skiff.step_x == 2, "under way again")
	naval_check(P.order_turn(NORTH), "a turn is ordered under way ([P.last_refusal])")
	P.offset_tick()
	naval_check(skiff.step_x == 2, "she holds her offset while the turn is marked")
	naval_check(P.finish_turn() && !skiff.step_x && !bow_plank.step_x && P.body.heading() == NORTH, "and comes about square on her tiles")
	P.offset_tick()
	naval_check(skiff.step_y == 1 && !skiff.step_x, "then creeps north")
	naval_check(deck_pump.step_x == skiff.step_x && deck_pump.step_y == skiff.step_y, "the new fitting follows turn and subsequent northward pulse")
	// A step taken on deck just before all stop is kept when she squares.
	var/deck_y = (deckhand.y * 32 + deckhand.step_y) - (skiff.y * 32 + skiff.step_y)
	deckhand.step_y += 2
	P.set_speed(VESSEL_SPEED_STOP)
	naval_check(!skiff.step_y && !P.hop_timer, "all stop squares her")
	naval_check((deckhand.y * 32 + deckhand.step_y) - (skiff.y * 32 + skiff.step_y) == deck_y + 2, "and the deckhand keeps the step just taken")
	naval_check(!deck_pump.step_x && !deck_pump.step_y && !vehicle_offset_riders[deck_pump], "the new fitting squares and releases with the hull")
	qdel(deck_pump)
	qdel(fitting)
	qdel(deckhand)
	qdel(pail)
	qdel(skiff)
	for (var/x = 40, x <= 55, x++)
		for (var/y = 20, y <= 32, y++)
			for (var/obj/covers/plank in locate(x, y, 2))
				qdel(plank)
	naval_check(crafts.len == 1, "the second hull is gone ([crafts.len])")

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
