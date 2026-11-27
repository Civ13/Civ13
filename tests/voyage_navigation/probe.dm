// Native regression for the scripted Voyage map, with no client or encounter assets.
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 6
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/voyage/navigation_probe
	var/list/loads = list()
/obj/map_metadata/voyage/navigation_probe/New()
	return
/obj/map_metadata/voyage/navigation_probe/check_roundend_conditions()
	return
/obj/map_metadata/voyage/navigation_probe/calc_speed()
	return 100
/obj/map_metadata/voyage/navigation_probe/load_map(mapname = "ship1", location = "random")
	loads += mapname
/obj/map_metadata/voyage/navigation_probe/clear_map()
	return
/mob/living/human/navigation_probe/New()
	icon_update = FALSE
	return
/obj/structure/voyage/shipwheel/navigation_probe
	var/response = "Approach island"
	var/prompt_mutation
	var/wait_mutation
	var/list/seen_options
	var/waits = 0
/obj/structure/voyage/shipwheel/navigation_probe/choose_course(mob/living/human/H, course, default_course, list/options)
	seen_options = options
	if (prompt_mutation)
		mutate(prompt_mutation, H)
	return response
/obj/structure/voyage/shipwheel/navigation_probe/turn_wheel(mob/living/human/H)
	waits++
	if (wait_mutation)
		mutate(wait_mutation, H)
	return TRUE
/obj/structure/voyage/shipwheel/navigation_probe/proc/mutate(change, mob/living/human/H)
	var/obj/map_metadata/voyage/navigation_probe/M = map
	switch (change)
		if ("advance")
			M.latitude++
		if ("anchor")
			M.ship_anchored = TRUE
		if ("replace")
			M.mapgen["[M.latitude],[M.longitude]"][3] = "fort"
		if ("walk")
			H.forceMove(locate(6,6,1))

var/voyage_navigation_failures = 0
var/voyage_navigation_runtime_error = FALSE
/proc/voyage_check(result, description)
	if (!result)
		voyage_navigation_failures++
	world.log << "[result ? "PASS" : "FAIL"]: [description]"
/world/Error(exception/e)
	voyage_navigation_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		voyage_navigation_checks()
	catch(var/exception/e)
		voyage_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = voyage_navigation_failures, "runtime_error" = voyage_navigation_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/voyage_navigation_checks()
	var/obj/map_metadata/voyage/navigation_probe/M = new
	map = M
	var/turf/deck = locate(2,2,1)
	var/mob/living/human/navigation_probe/H = new(deck)
	H.stat = CONSCIOUS
	var/obj/structure/voyage/shipwheel/navigation_probe/W = new(deck)
	M.mapgen = list("21,71" = list(21,71,"island"), "22,71" = list(22,71,"sea"), "23,71" = list(23,71,"ship1_spanish"), "24,71" = list(24,71,"ship2_merchant"))
	M.islands = list(list("island1",21,71,-1))
	M.ship_anchored = FALSE
	M.navmoving = TRUE

	W.prompt_mutation = "advance"
	W.attack_hand(H)
	voyage_check(!M.nav_approach && M.navdirection == "North" && W.waits == 0, "stale prompt cannot steer at a different cell")
	M.latitude = 21
	W.prompt_mutation = null
	W.wait_mutation = "advance"
	W.attack_hand(H)
	voyage_check(!M.nav_approach && M.navdirection == "North" && W.waits == 1, "movement during the turn prevents a stale approach")
	M.latitude = 21
	W.wait_mutation = "replace"
	W.attack_hand(H)
	voyage_check(!M.nav_approach, "a replaced destination cannot be approached during the turn")
	M.mapgen["21,71"][3] = "island"
	W.wait_mutation = "anchor"
	W.response = "East"
	W.attack_hand(H)
	voyage_check(M.navdirection == "North" && M.ship_anchored, "a lowered anchor cancels a cardinal turn")
	M.ship_anchored = FALSE
	W.wait_mutation = "walk"
	W.attack_hand(H)
	voyage_check(M.navdirection == "North", "leaving wheel reach cancels the turn")
	H.forceMove(deck)
	W.wait_mutation = null
	W.response = null
	W.attack_hand(H)
	voyage_check(M.navdirection == "North" && !M.nav_approach, "cancel leaves the existing course untouched")

	W.response = "Approach island"
	W.attack_hand(H)
	voyage_check(M.navigation_course() == "island" && M.navdirection == "North", "valid approach keeps its preceding cardinal heading")
	M.mapgen["21,71"][3] = "sea"
	M.nav()
	voyage_check(!M.inzone && !M.loads.len && !M.nav_approach && M.latitude == 22, "vanished queued destination never opens an encounter")
	M.latitude = 21
	M.mapgen["21,71"][3] = "island"
	W.attack_hand(H)
	M.nav()
	voyage_check(M.inzone && M.loads.len == 1, "valid island order opens exactly one encounter")
	M.abandon_event()
	voyage_check(!M.nav_approach && !M.inzone && M.navigation_course() == "North" && M.islands[1][4] > world.time, "departure restores the heading and retains the island cooldown")
	W.attack_hand(H)
	voyage_check(!M.nav_approach, "reapproaching during the cooldown is rejected")
	M.nav()
	voyage_check(M.latitude == 22 && M.loads.len == 1, "first leg after departure sails away without reopening the encounter")

	M.ships = list(list(1,"spanish",23,71), list(1,"pirates",23,71), list(2,"merchant",24,71))
	M.nav()
	voyage_check(M.inzone && M.loads.len == 2 && M.loads[2] == "ship1_spanish", "automatic encounter lands on the recorded ship")
	M.abandon_event()
	voyage_check(M.ships.len == 1 && M.ships[1][3] == 24 && M.mapgen["23,71"][3] == "sea", "departure removes all co-located rows and clears only their chart cell")
	W.response = "Approach ship"
	W.attack_hand(H)
	voyage_check(!("Approach ship" in W.seen_options) && !M.nav_approach, "departed ship is no longer offered at the wheel")
	M.check_ships()
	voyage_check(M.loads.len == 2, "returning to the retired cell does not load the encounter again")
	M.nav()
	voyage_check(M.inzone && M.loads.len == 3 && M.loads[3] == "ship2_merchant", "distinct ship encounter remains reachable")
