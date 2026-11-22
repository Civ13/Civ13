// Strait booms (code/modules/naval/strait_boom.dm, docs/ocean-regions.md):
// laying a boom from a winch to the far shore, a raised boom stopping a hull,
// lowering it for a toll, ramming it at full speed, mending and cutting it,
// and the named straits.
/world
	hub = ""
	hub_password = ""
	maxx = 600
	maxy = 300
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/naval_research_done = FALSE
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

/obj/map_metadata/nomads/ocean/probe
	ocean = "probe"
/obj/map_metadata/nomads/ocean/probe/New()
	return
/obj/map_metadata/nomads/ocean/probe/is_node_done(faction, node_id)
	return naval_research_done

/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/W = locate(x, y, 1)
			W.ChangeTurf(/turf/floor/beach/water/deep/saltwater)

/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 1)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

// A 5 by 3 hull with a rigged mast, bow east, its corner at (x, y).
/proc/sea_ship(x, y, ship_name)
	for (var/dx = 0, dx < 5, dx++)
		for (var/dy = 0, dy < 3, dy++)
			hull_lay(x + dx, y + dy)
	var/obj/structure/hull_tiller/tiller = new(locate(x + 1, y + 1, 1))
	var/obj/structure/vehicleparts/movement/sail/mast = new(locate(x + 3, y + 1, 1))
	mast.sails = new /obj/item/sail(mast)
	naval_check(isnull(tiller.commission(ship_name, EAST)), "the [ship_name] is commissioned")
	return tiller

/proc/naval_checks()
	naval_fixture()
	persistence_player_restore_ready = TRUE

	// A narrows at x 200: shore at y 50 and y 60, water between.
	var/turf/south = locate(200, 50, 1)
	var/turf/north = locate(200, 60, 1)
	south.ChangeTurf(/turf/floor/grass)
	north.ChangeTurf(/turf/floor/grass)
	var/obj/structure/strait_winch/W = new(south)
	W.set_dir(NORTH)
	var/list/todo = W.lay_todo()
	naval_check(islist(todo) && todo.len == 9, "the boom would span the nine tiles of water to the far shore ([islist(todo) ? todo.len : todo])")
	W.lay_segments(todo)
	var/list/S = W.segments()
	naval_check(S.len == 9 && W.boom_raised(), "laid, the boom runs nine tiles and is raised")
	var/list/again = W.lay_todo()
	naval_check(islist(again) && !again.len, "a whole boom needs nothing more")

	var/obj/structure/strait_winch/W2 = new(locate(300, 50, 1))
	W2.set_dir(NORTH)
	naval_check(istext(W2.lay_todo()), "with no far shore in reach there is no boom to lay ([W2.lay_todo()])")
	qdel(W2)

	// A raised boom stops her.
	var/obj/structure/hull_tiller/tiller = sea_ship(190, 54, "Wren")
	var/datum/craft/C = tiller.craft
	var/datum/craft_body/built/B = C.body
	naval_check(B.move_to(195, 54, EAST), "she sails up to the boom ([B.last_refusal])")
	naval_check(!B.move_to(196, 54, EAST) && findtext(B.last_refusal, "boom"), "the raised boom stops her ([B.last_refusal])")

	// A paid toll lowers it, and it comes back up.
	W.lower(null, 0)
	naval_check(!W.boom_raised(), "lowered, the boom sinks")
	naval_check(B.move_to(196, 54, EAST), "and she sails over it ([B.last_refusal])")
	W.raise()
	var/kept_down = 0
	for (var/obj/structure/strait_boom/X in W.segments())
		if (X.lowered)
			kept_down++
	naval_check(W.segments().len == 9 && kept_down == 3, "the boom stays where it lies, and down under her hull ([W.segments().len] segments, [kept_down] down)")
	naval_check(B.move_to(190, 54, EAST), "she backs off ([B.last_refusal])")
	W.raise()
	naval_check(W.boom_raised() && !(locate(/obj/structure/strait_boom) in locate(200, 55, 1)).lowered, "wound up once she is clear, the boom is raised again")

	// Slower than full ahead she cannot ram it.
	naval_check(B.move_to(195, 54, EAST), "she comes up to it again ([B.last_refusal])")
	C.speed = VESSEL_SPEED_HALF
	naval_check(!C.boom_ram(), "at half ahead she does not break it")
	var/planks = 0
	for (var/turf/T in B.cells())
		for (var/obj/covers/P in T)
			planks++
	C.speed = VESSEL_SPEED_FULL
	var/holes_before = C.ledger ? C.ledger.holes : 0
	naval_check(C.boom_ram(), "at full ahead she rams it")
	var/broke = 0
	for (var/obj/structure/strait_boom/X in W.segments())
		if (X.broken)
			broke++
	var/planks_after = 0
	for (var/turf/T in B.cells())
		for (var/obj/covers/P in T)
			planks_after++
	naval_check(broke == 3, "the three segments across her bow break ([broke])")
	naval_check(planks_after == planks - 3 && C.ledger && C.ledger.holes > holes_before, "her bow is stove in ([planks] planks, now [planks_after]; holes [C.ledger ? C.ledger.holes : "?"])")
	naval_check(C.speed == VESSEL_SPEED_SLOW, "and she loses way")
	naval_check(B.move_to(196, 54, EAST), "she gets through the gap ([B.last_refusal])")
	naval_check(W.boom_raised(), "the rest of the boom stays up")

	// Mending takes iron only for the broken segments.
	var/list/mend = W.lay_todo()
	naval_check(islist(mend) && mend.len == 3, "the owner mends three segments ([islist(mend) ? mend.len : mend])")

	// Cutting breaks one segment.
	var/obj/structure/strait_boom/first = S[1]
	first.break_segment()
	naval_check(first.broken && !first.density, "a cut segment lets water through")

	// Named straits.
	naval_check(strait_named_at(locate(92, 131, 1), "mediterranean") == "Strait of Gibraltar", "the Strait of Gibraltar is named")
	naval_check(isnull(strait_named_at(locate(300, 200, 1), "mediterranean")), "open water is not a strait")

	// The winch takes its boom with it.
	qdel(W)
	var/left = 0
	for (var/obj/structure/strait_boom/X in world)
		if (!QDELETED(X))
			left++
	naval_check(left == 0, "a winch pulled down takes its boom ([left])")
	naval_check(!naval_runtime_error, "no runtime errors")

/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	chart_hazards_off = TRUE
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/nomads/ocean/probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
