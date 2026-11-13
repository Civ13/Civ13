// Boat davits and carried craft (code/modules/craft/deck_berth.dm,
// docs/craft-core.md): a davit on a built hull hoists a boat of ship frames
// into its cradle with its crew and cargo, the boat is carried by the ship
// through a hop and a turn, stays off the chart's boat list, cannot sail off
// the deck, and is lowered over a side with open water; a vehicle parked in
// the cradle is carried too; crafts nest without rings.
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

/datum/craft_drive/probe_push
	thrust = 1000

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

// The steps a half minute covers at her speed: a gliding hull makes one tile
// a step. TRUE when every step moved her.
/proc/hull_leg(datum/craft/C)
	var/steps = 0
	while (steps < C.speed * VESSEL_TILES_PER_STEP)
		if (!C.sail_tick())
			return FALSE
		steps++
	return steps > 0

/proc/boat_whole_in(obj/structure/vehicleparts/axis/A, list/cells)
	var/n = 0
	for (var/obj/structure/vehicleparts/frame/F in A.components)
		if (!(F.loc in cells))
			return FALSE
		n++
	return n > 0

/proc/boat_afloat(obj/structure/vehicleparts/axis/A)
	var/n = 0
	for (var/obj/structure/vehicleparts/frame/F in A.components)
		if (!deck_berth_water(F.loc) || craft_at(F.loc))
			return FALSE
		n++
	return n > 0

/proc/naval_checks()
	naval_fixture()
	// ---- A davit ashore ----
	var/obj/structure/berth/deck/ashore = new(locate(10, 20, 2))
	naval_check((ashore in deck_berths) && isnull(ashore.ship()) && findtext(ashore.cradle_refusal(), "must stand on a ship's deck") && findtext(ashore.status_text(), "cannot be worked"), "a davit ashore cannot be worked ([ashore.status_text()])")
	qdel(ashore)
	naval_check(!(ashore in deck_berths), "and leaves the list when it goes")

	// ---- The Wren: 8 by 5, with a davit whose cradle is 4 by 3 ----
	for (var/x = 40, x <= 47, x++)
		for (var/y = 10, y <= 14, y++)
			hull_lay(x, y)
	var/obj/structure/hull_tiller/tiller = new(locate(40, 12, 2))
	naval_check(isnull(tiller.commission("Wren", EAST)), "the Wren is commissioned")
	var/datum/craft/C = tiller.craft
	var/obj/structure/berth/deck/davit = new(locate(41, 13, 2))
	davit.set_dir(EAST)
	davit.berth_length = 4
	davit.berth_beam = 3
	var/list/cells = davit.cradle()
	var/list/room = deck_berth_box(cells)
	naval_check(davit.ship() == C && cells.len == 12 && room[1] == 42 && room[2] == 11 && room[3] == 45 && room[4] == 13, "her davit's cradle is the 4 by 3 tiles of deck east of it ([cells.len]: [room[1]],[room[2]] to [room[3]],[room[4]])")
	naval_check(isnull(davit.cradle_refusal()) && findtext(davit.status_text(), "It is empty") && (davit in C.davits()), "the cradle is on her deck and empty ([davit.status_text()])")
	davit.berth_length = 5
	davit.berth_beam = 5
	naval_check(findtext(davit.cradle_refusal(), "reaches past her deck"), "a cradle wider than her deck is refused ([davit.cradle_refusal()])")
	davit.berth_length = 4
	davit.berth_beam = 3

	// ---- The Teal: a 3 by 2 boat lying off her port quarter ----
	for (var/dx = 0, dx < 3, dx++)
		for (var/dy = 0, dy < 2, dy++)
			new /obj/structure/vehicleparts/frame/ship(locate(46 + dx, 16 + dy, 2))
	var/obj/structure/vehicleparts/axis/ship/boat = new(locate(46, 16, 2))
	new /obj/structure/vehicleparts/shipwheel(locate(46, 17, 2))
	new /obj/structure/vehicleparts/movement/sail/premade(locate(47, 16, 2))
	boat.name = "Teal"
	var/why = boat.assemble(EAST)
	naval_check(isnull(why) && deck_berth_frames(boat).len == 6 && boat_afloat(boat), "the Teal is assembled on the water ([why])")
	var/mob/living/human/naval_probe/sailor = new(locate(47, 17, 2))
	var/obj/structure/closet/crate/box = new(locate(48, 16, 2))
	var/list/near = davit.boats_in_reach()
	naval_check(near.len == 1 && near[near[1]] == boat, "the davit finds the Teal within reach ([near.len])")
	naval_check(findtext(C.sea_chart_text(), "Ship: Teal") && !findtext(C.sea_chart_text(), "In her davits"), "afloat, she is a boat on the Wren's chart")

	// Refusals, each in plain words.
	var/obj/structure/vehicleparts/axis/ship/far = new(locate(60, 40, 2))
	var/obj/structure/vehicleparts/frame/ship/far_frame = new(locate(60, 40, 2))
	far_frame.axis = far
	far.components += far_frame
	naval_check(findtext(davit.hoist_plan(far), "out of reach") && !(far in davit.boats_in_reach()), "a boat far off is out of reach")
	qdel(far_frame)
	qdel(far)
	davit.berth_length = 2
	davit.berth_beam = 2
	naval_check(findtext(davit.hoist_plan(boat), "too big as it lies: 3 by 2 against a cradle of 2 by 2"), "a cradle too small refuses her ([davit.hoist_plan(boat)])")
	davit.berth_length = 4
	davit.berth_beam = 3
	var/obj/structure/probe_rock/rock = new(locate(43, 12, 2))
	naval_check(findtext(davit.hoist_plan(boat), "stands in the cradle"), "something solid in the cradle refuses her ([davit.hoist_plan(boat)])")
	qdel(rock)
	C.anchored = FALSE
	C.speed = 1
	naval_check(findtext(davit.hoist_plan(boat), "she must be stopped"), "a ship under way does not hoist")
	C.speed = 0
	C.anchored = TRUE
	boat.moving = TRUE
	naval_check(findtext(davit.hoist_plan(boat), "under way"), "nor is a boat under way hoisted")
	boat.moving = FALSE
	naval_check(findtext(davit.launch(EAST), "cradle is empty"), "an empty cradle has nothing to lower")

	// ---- Hoisting ----
	var/list/plan = davit.hoist_plan(boat)
	naval_check(islist(plan) && plan[1] == -4 && plan[2] == -5, "the plan sets her in the cradle's south-west corner ([islist(plan) ? "[plan[1]],[plan[2]]" : plan])")
	why = davit.hoist(boat)
	var/datum/craft/vehicle/teal = craft_of_axis(boat, FALSE)
	naval_check(isnull(why) && boat_whole_in(boat, davit.cradle()) && boat.anchor, "she is hoisted whole into the cradle with her anchor down ([why])")
	naval_check((sailor.loc in davit.cradle()) && (box.loc in davit.cradle()), "her sailor and her crate came aboard in her")
	naval_check(teal && teal.carrier == C && (teal in C.carried) && teal.berth == davit && davit.occupant == teal && teal.top_carrier() == C, "the Teal is berthed at the davit and carried by the Wren")
	naval_check(boat.in_cradle() == davit && davit.held() == boat && findtext(davit.status_text(), "It holds Teal"), "the davit holds her ([davit.status_text()])")
	var/text = C.sea_chart_text()
	naval_check(findtext(text, "In her davits: Teal.") && !findtext(text, "Ship: Teal"), "the chart lists her in the Wren's davits and no longer as a boat in sight")
	boat.anchor = FALSE
	naval_check(!boat.do_vehicle_check() && !boat.moving, "in the cradle she does not sail off the deck")
	naval_check(findtext(davit.hoist_plan(boat), "the cradle holds Teal"), "a full cradle takes no second boat")

	// ---- Carried through a hop and a turn ----
	var/turf/O = C.body.origin()
	var/turf/sailor_was = get_turf(sailor)
	naval_check(C.body.move_to(O.x + 3, O.y, EAST), "the Wren hops three tiles east ([C.body.last_refusal])")
	naval_check(davit.x == 44 && boat_whole_in(boat, davit.cradle()) && sailor.x == sailor_was.x + 3 && teal.carrier == C && teal.berth == davit, "the davit, the Teal and her sailor went with her and she is still carried")
	naval_check(C.body.turn_to(NORTH), "the Wren comes about to the north ([C.body.last_refusal])")
	naval_check(davit.dir == NORTH && davit.cradle().len == 12 && boat_whole_in(boat, davit.cradle()) && boat.dir == NORTH, "the cradle turned with her deck and still holds the Teal, now bow north ([dir2text(davit.dir)], [dir2text(boat.dir)])")
	naval_check(davit.refresh() == teal && teal.carrier == C && C.carried.len == 1, "and she is still carried after the turn")

	// ---- Lowering ----
	var/ways = 0
	for (var/way in cardinal)
		if (islist(davit.launch_plan(boat, way)))
			ways++
	naval_check(ways == 4, "with open sea all round she can be lowered over any side ([ways])")
	var/list/down = davit.launch_plan(boat, EAST)
	var/obj/structure/probe_rock/reef = null
	if (islist(down))
		var/turf/first = get_turf(boat)
		reef = new(locate(first.x + down[1], first.y + down[2], 2))
		var/list/further = davit.launch_plan(boat, EAST)
		naval_check(islist(further) && further[1] > down[1], "a rock where she would land moves the landing further out ([islist(further) ? further[1] : further] against [down[1]])")
		qdel(reef)
	C.anchored = FALSE
	C.speed = 1
	naval_check(findtext(davit.launch(EAST), "she must be stopped"), "a ship under way does not lower")
	C.speed = 0
	C.anchored = TRUE
	why = davit.launch(EAST)
	naval_check(isnull(why) && boat_afloat(boat) && deck_berth_water(sailor.loc) && deck_berth_water(box.loc), "the Teal is lowered to the water east of her with her sailor and crate ([why])")
	naval_check(isnull(teal.carrier) && !C.carried.len && isnull(teal.berth) && isnull(davit.occupant) && isnull(boat.in_cradle()), "afloat she is carried by nobody and the cradle is empty")
	text = C.sea_chart_text()
	naval_check(findtext(text, "Ship: Teal") && !findtext(text, "In her davits"), "and she is a boat on the chart again")
	boat.anchor = FALSE
	naval_check(isnull(boat.in_cradle()), "afloat, the cradle no longer holds her back")

	// ---- A lost davit sets her down ----
	why = davit.hoist(boat)
	naval_check(isnull(why) && teal.carrier == C, "hoisted again she is carried again ([why])")
	qdel(davit)
	naval_check(isnull(teal.carrier) && !C.carried.len && isnull(teal.berth), "a davit that is destroyed lets her go")

	// ---- A davit on a turf-built ship: the carrier's flight deck ----
	var/datum/vessel/carrier/V = carrier_lay_down(locate(22, 30, 2), EAST)
	naval_check(istype(V) && V.placed, "a carrier is laid down bow east")
	if (istype(V))
		var/datum/craft/big = craft_of_vessel(V)
		var/obj/structure/berth/deck/flight = new(locate(30, 31, 2))
		flight.set_dir(NORTH)
		flight.berth_length = 3
		flight.berth_beam = 2
		naval_check(flight.ship() == big && isnull(flight.cradle_refusal()) && flight.sea_z() == 2, "a davit on her flight deck has its cradle on her deck ([flight.cradle_refusal()])")
		var/list/teal_box = deck_berth_box(deck_berth_frames(boat))
		naval_check(boat.shift_vehicle_level(2, 30 - teal_box[1], 25 - teal_box[2]) && boat_afloat(boat), "the Teal lies off the carrier's quarter")
		why = flight.hoist(boat)
		naval_check(isnull(why) && boat_whole_in(boat, flight.cradle()) && teal.carrier == big && teal.berth == flight, "the carrier's davit hoists her onto the flight deck ([why])")
		var/turf/boat_was = get_turf(boat)
		naval_check(big.body.move_to(V.ox + 2, V.oy, EAST), "the carrier moves two tiles east ([V.last_refusal])")
		var/turf/boat_now = get_turf(boat)
		naval_check(boat_now.x == boat_was.x + 2 && flight.x == 32 && boat_whole_in(boat, flight.cradle()) && teal.carrier == big && flight.occupant == teal, "and the Teal rides her deck, still carried")
		why = flight.launch(SOUTH)
		naval_check(isnull(why) && boat_afloat(boat) && isnull(teal.carrier) && !big.carried.len, "she is lowered over the carrier's side to the water ([why])")

	// ---- A vehicle parked in a cradle ----
	var/turf/TO = get_turf(tiller)
	var/obj/structure/berth/deck/second = null
	for (var/turf/T in C.body.cells())
		if (T == TO || (locate(/obj/structure/vehicleparts) in T))
			continue
		for (var/way in cardinal)
			var/obj/structure/berth/deck/trial = new(T)
			trial.set_dir(way)
			trial.berth_length = 2
			trial.berth_beam = 2
			var/clear = isnull(trial.cradle_refusal())
			for (var/turf/K in trial.cradle())
				if ((locate(/obj/structure) in K))
					clear = FALSE
			if (clear)
				second = trial
				break
			qdel(trial)
		if (second)
			break
	naval_check(!isnull(second), "there is clear deck for a second, 2 by 2 cradle")
	if (second)
		var/obj/structure/vehicleparts/axis/car = new(get_turf(second.cradle()[1]))
		car.name = "deck car"
		for (var/turf/K in second.cradle())
			var/obj/structure/vehicleparts/frame/F = new(K)
			F.axis = car
			car.components += F
		var/datum/craft/parked = second.refresh()
		naval_check(parked && parked == craft_of_axis(car, FALSE) && parked.carrier == C && (parked in C.all_carried()), "a vehicle parked wholly in a cradle is carried by the ship")
		var/obj/structure/vehicleparts/frame/gone = locate() in second.cradle()[1]
		car.components -= gone
		qdel(gone)
		var/obj/structure/vehicleparts/frame/off = new(locate(60, 50, 2))
		off.axis = car
		car.components += off
		naval_check(isnull(second.refresh()) && isnull(parked.carrier) && !C.carried.len, "one that no longer stands wholly in it is not")

	// ---- Nesting ----
	var/datum/craft/A1 = new
	var/datum/craft/A2 = new
	var/datum/craft/A3 = new
	naval_check(A1.take_aboard(A2) && A2.take_aboard(A3) && A3.top_carrier() == A1, "crafts nest: a craft carried by a carried craft")
	var/list/all = A1.all_carried()
	naval_check(all.len == 2 && all[1] == A2 && all[2] == A3, "all_carried lists them nearest first")
	naval_check(!A3.take_aboard(A1) && !A1.take_aboard(A1) && isnull(A1.carrier), "a craft cannot carry what carries it, nor itself")
	naval_check(A1.take_aboard(A3) && A3.carrier == A1 && !(A3 in A2.carried), "taken aboard another, a craft leaves its old carrier")
	naval_check(A1.set_down(A3) && isnull(A3.carrier) && !A2.set_down(A3), "and is set down only by the one that carries it")
	qdel(A1)
	naval_check(isnull(A2.carrier), "a carrier that goes lets go of what it carried")

	// ---- Who may work a davit ----
	var/obj/structure/berth/deck/third = new(get_turf(tiller))
	var/mob/living/human/naval_probe/stranger = new(locate(5, 5, 2))
	stranger.real_name = "Stranger"
	naval_check(isnull(third.hand_refusal(stranger)), "an unregistered ship's davit is worked by anyone")
	C.register = new /datum/craft_register
	C.register.party = "probe party"
	naval_check(findtext(third.hand_refusal(stranger), "not of her crew"), "a registered ship's davit refuses a stranger")
	C.register.crew["Stranger"] = CRAFT_ROLE_HAND
	naval_check(isnull(third.hand_refusal(stranger)), "and works for a listed hand")

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
