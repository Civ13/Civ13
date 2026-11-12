// Degaussing (code/modules/naval/degaussing.dm, docs/naval-mines.md): a
// wiping station takes 70% off a steel hull lying alongside and the wipe wears
// off as she sails; a degaussing coil takes 80% off while it has power and
// trips out without it; a wiped hull passes a magnetic mine that would have
// felt her; the owner of the craft keeps the wipe for a save.
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

// The steps a half minute covers at her speed: a gliding hull makes one tile
// a step. TRUE when every step moved her.
/proc/hull_leg(datum/craft/C)
	var/steps = 0
	while (steps < C.speed * VESSEL_TILES_PER_STEP)
		if (!C.sail_tick())
			return FALSE
		steps++
	return steps > 0


// A steel plate laid the way a player lays one.
/proc/hull_plate(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/steelplating/C = new(T)
	C.updateturf()
	return C

// The blasts are recorded, not set off: the fixture has no explosion config.
var/list/mine_blasts = list()
/obj/structure/naval_mine/blast_at(turf/hit)
	mine_blasts += hit

/proc/hull_steps(datum/craft/C, n)
	for (var/i = 1, i <= n, i++)
		if (!C.sail_tick())
			return FALSE
	return TRUE

// Wired power is answered by the probe.
var/probe_power = FALSE
/obj/structure/wiping_station/draw_cable_power()
	return powerneeded > 0 ? probe_power : FALSE

/proc/naval_checks()
	naval_fixture()
	for (var/x = 22, x <= 68, x++)
		for (var/y = 4, y <= 56, y++)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water)

	// ---- A steel hull of twenty plates, off the beach ----
	for (var/x = 22, x <= 26, x++)
		for (var/y = 30, y <= 33, y++)
			hull_plate(x, y)
	var/obj/structure/hull_tiller/tiller = new(locate(24, 31, 2))
	naval_check(isnull(tiller.commission("Iron Duke", EAST)) && tiller.craft, "a steel hull is commissioned")
	var/datum/craft/S = tiller.craft
	naval_check(S.magnetic_signature() == 20 && S.magnetic_factor() == 1, "unwiped and with no coil she shows her whole 20")

	// ---- Wiping ----
	var/obj/structure/wiping_station/station = new(locate(20, 31, 2))
	naval_check(station.alongside() == S, "the station on the beach finds her alongside")
	naval_check(findtext(station.wipe_problem(S), "cable"), "an empty station asks for cable ([station.wipe_problem(S)])")
	var/obj/item/stack/cable_coil/coil_stack = new(locate(20, 30, 2))
	coil_stack.amount = 30
	var/mob/living/human/naval_probe/wiper = new(locate(20, 30, 2))
	station.attackby(coil_stack, wiper)
	naval_check(station.cable == 30 && (QDELETED(coil_stack) || coil_stack.amount == 0), "feeding it a coil of thirty fills it with thirty lengths ([station.cable])")
	probe_power = FALSE
	naval_check(!station.wipe(S) && S.magnetic_wipe == 0 && station.cable == 30, "without power the wiping does not take and no cable is used")
	probe_power = TRUE
	naval_check(station.wipe(S) && S.magnetic_wipe == 70 && station.cable == 10, "powered, it wipes 70% off and uses twenty lengths")
	naval_check(abs(S.magnetic_signature() - 6) < 0.01 && findtext(tiller.status_text(), "Magnetic signature: faint (wiped, 70% off)"), "wiped, she shows 6, read as faint ([tiller.status_text()])")
	naval_check(findtext(station.wipe_problem(S), "cable"), "ten lengths are not enough for another")
	tiller.before_save()
	naval_check(tiller.magnetic_wipe == 70, "the tiller keeps her wipe for a save")

	// ---- A magnetic mine beside her course: wiped, she passes ----
	var/obj/structure/naval_mine/magnetic/beside = new(locate(36, 34, 2))
	S.set_anchor(FALSE)
	S.set_speed(VESSEL_SPEED_SLOW)
	naval_check(hull_steps(S, 10) && !QDELETED(beside) && !mine_blasts.len, "a wiped hull passes a magnetic mine one tile off her course")
	naval_check(abs(S.magnetic_wipe - 69) < 0.01, "ten tiles wear 1% of the wipe off ([S.magnetic_wipe])")
	S.magnetic_wipe = 0
	naval_check(hull_steps(S, 1) && QDELETED(beside) && mine_blasts.len == 1, "with the wipe gone the same mine goes off")
	S.set_speed(VESSEL_SPEED_STOP)

	// ---- A coil with no engine aboard trips out ----
	var/turf/deck = get_turf(tiller)
	var/obj/structure/degaussing_coil/coil = new(locate(deck.x - 1, deck.y, 2))
	coil.anchored = TRUE
	coil.on = TRUE
	naval_check(S.running_coil() == coil && abs(S.magnetic_signature() - 4) < 0.01 && findtext(S.magnetic_text(), "degaussing coil on"), "a running coil takes 80% off: 20 shows as 4")
	S.magnetic_moved(1)
	naval_check(!coil.on && S.magnetic_signature() == 20, "with no engine running aboard the coil trips out")

	// ---- A coil on a submarine runs on her battery ----
	var/obj/structure/vehicleparts/axis/ship/submarine/boat = build_submarine(locate(50, 40, 2), "Probe boat")
	var/datum/craft/B = craft_of_axis(boat)
	var/obj/structure/vehicleparts/frame/inside = boat.components[1]
	var/obj/structure/degaussing_coil/sub_coil = new(get_turf(inside))
	sub_coil.anchored = TRUE
	var/mob/living/human/naval_probe/sailor = new(get_turf(inside))
	sub_coil.attack_hand(sailor)
	naval_check(sub_coil.on && sub_coil.aboard() == B && abs(B.magnetic_signature() - 6) < 0.01, "switched on aboard a Scout it takes her 30 down to 6")
	var/battery = boat.battery
	B.magnetic_moved(10)
	naval_check(sub_coil.on && boat.battery == battery - 10, "ten tiles cost ten battery units ([battery - boat.battery])")
	boat.battery = 5
	B.magnetic_moved(10)
	naval_check(!sub_coil.on, "a flat battery trips it out")
	boat.before_save()
	naval_check(boat.magnetic_wipe == 0, "the boat's axis saves her wipe")

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
