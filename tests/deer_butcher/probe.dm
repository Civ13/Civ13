// Native probe: a carcass in a flowing river stays put so it can be butchered.
// A doe killed in a shallow river used to drift one tile per current pulse
// (looking like it walked off), interrupting the butchering, and then sank
// once the current carried it into deep water.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/deer_butcher/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 15
	maxy = 15
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/db_probe/New()
	return
/mob/living/human/db_probe/New()
	return
/mob/living/human/db_probe/update_icons()
	return
/mob/living/human/db_probe/get_active_hand()
	return locate(/obj/item/weapon/material/kitchen/utensil/knife/flint) in src
// The fixture has no client; everything else in the harvest guard stays real.
/mob/living/simple_animal/deer/female/db_probe/harvest_valid(mob/user, obj/item/tool, turf/site, require_client = TRUE)
	return ..(user, tool, site, FALSE)

var/db_failures = 0
var/db_runtime_error = FALSE
/proc/db_check(condition, label)
	if (!condition)
		db_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	db_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	spawn(0)
		try
			GLOB.all_observable_events = list()
			GLOB.moved_event = new
			GLOB.dir_set_event = new
			GLOB.destroyed_event = new
			movementMachine = new
			map = new /obj/map_metadata/db_probe
			db_run()
		catch(var/exception/e)
			db_check(FALSE, "exception [e] [e.file]:[e.line]")
		text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = db_failures, "runtime_error" = db_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
		del(world)

// One river-current pulse over every water tile, as /process/river_current does.
/proc/db_current_pulse()
	river_moved.Cut()
	for (var/turf/floor/beach/water/W in block(locate(1, 1, 1), locate(15, 15, 1)))
		W.river_current_step()

/proc/db_run()
	for (var/turf/T in block(locate(1, 1, 1), locate(15, 15, 1)))
		T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
	// Column 8 is a shallow river flowing south into deep water at y <= 3.
	var/datum/river_flow/flow = new
	flow.z_level = 1
	for (var/y = 15, y >= 1, y--)
		var/turf/R = locate(8, y, 1)
		R.ChangeTurf(y <= 3 ? /turf/floor/beach/water/deep : /turf/floor/beach/water, FALSE, FALSE)
		flow.rows += ".......s......."
	map.river_flow_cache = flow
	map.river_flow_loaded = TRUE
	db_check(river_current_direction(locate(8, 10, 1)) == SOUTH, "fixture river flows south")

	var/mob/living/human/db_probe/H = new(locate(7, 10, 1))
	H.stat = CONSCIOUS
	H.targeted_organ = "chest"
	H.a_intent = I_HARM
	var/obj/item/weapon/material/kitchen/utensil/knife/flint/K = new(H)
	var/mob/living/simple_animal/deer/female/db_probe/D = new(locate(8, 10, 1))
	D.adjustBruteLoss(D.maxHealth - 1)
	D.attackby(K, H)
	db_check(D.stat == DEAD, "the doe dies in the river")
	var/turf/death_turf = D.loc

	// The living current still carries a live animal.
	var/mob/living/simple_animal/deer/female/db_probe/swimmer = new(locate(8, 13, 1))
	walk(swimmer, 0)
	db_current_pulse()
	db_check(swimmer.y == 12, "the current still carries a living deer downstream")
	db_check(!QDELETED(D) && D.loc == death_turf, "the current leaves the carcass where it died")
	qdel(swimmer)

	// Butcher it across several current pulses, as the player did.
	H.loc = get_step(death_turf, WEST)
	spawn(0)
		D.attackby(K, H)
	for (var/i = 1, i <= 40, i++)
		sleep(1)
		if (i % 5 == 0)
			db_current_pulse()
	var/meat = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/meat/M in world)
		meat++
	db_check(QDELETED(D) && meat > 0, "butchering in the river finishes with [meat] meat")

	// A carcass left in the shallows never reaches deep water to sink.
	var/mob/living/simple_animal/deer/female/db_probe/left = new(locate(8, 6, 1))
	left.adjustBruteLoss(left.maxHealth * 2)
	db_check(left.stat == DEAD, "a second doe dies in the shallows")
	for (var/i = 1, i <= 6, i++)
		db_current_pulse()
	sleep(70)
	db_check(!QDELETED(left) && left.y == 6, "an unbutchered carcass stays in the shallows")
