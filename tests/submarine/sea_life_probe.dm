// Sea life on the seabed: movement in the water, senses, each kind's
// behaviour, butchering and spawning through the ecology cycle.
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
/obj/map_metadata/sea_life_probe
	sea_layer_surface_z = 2
/obj/map_metadata/sea_life_probe/New()
	return
/mob/living/sea_life_probe/New()
	return
// A sealed diver (the fixture cannot build a full human).
/mob/living/sea_life_probe/diver/can_walk_seabed()
	return TRUE
/obj/covers/sea_life_probe_hull
	name = "probe hull"
var/sea_life_failures = 0
var/sea_life_runtime_error = FALSE
/proc/sea_life_check(condition, label)
	if (!condition)
		sea_life_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	sea_life_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Lets one AI tick play out (a swim step finishes within its interval).
/proc/sea_life_tick(mob/living/simple_animal/sea/A, n = 1)
	for (var/i = 1, i <= n, i++)
		A.handle_ai()
		sleep(A.swim_interval + 2)

/proc/sea_life_in_water(mob/living/simple_animal/sea/A)
	var/turf/T = get_turf(A)
	return sea_layer_cell(T) && !T.iscovered()

/proc/sea_life_checks()
	// Surface (z2): deep ocean. Below (z1): rock, with sea at x 4-29, y 2-29
	// and a rock pillar at x 15, y 10-12.
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			locate(x, y, 2).ChangeTurf(/turf/floor/beach/water/deep/saltwater)
			var/turf/B = locate(x, y, 1)
			if (x >= 4 && x <= 29 && y >= 2 && y <= 29 && !(x == 15 && y >= 10 && y <= 12))
				B.ChangeTurf(/turf/floor/beach/water/deep/saltwater/underwater/sea_layer)
			else
				B.ChangeTurf(/turf/wall/rockwall)
	seabed_zone_pass(1)
	sea_life_check(sea_zone_of(locate(5, 20, 1)) == SEA_ZONE_SHELF && sea_zone_of(locate(22, 20, 1)) == SEA_ZONE_OPEN, "the fixture has shelf and open water")

	// ---- Moving in the water ----
	var/mob/living/simple_animal/sea/shoal/F = new(locate(6, 20, 1))
	sea_life_check(F.can_walk_seabed() && sea_life_in_water(F), "a shoal lives in open sea")
	sea_life_check(!F.sea_can_enter(locate(3, 20, 1)), "it never swims into rock")
	var/turf/hull = locate(7, 24, 1)
	new /obj/covers/sea_life_probe_hull(hull)
	sea_life_check(hull.iscovered() && !F.sea_can_enter(hull), "it never swims into a boat's hull")
	var/mob/living/simple_animal/sea/kelp_turtle/K = new(locate(9, 6, 1))
	sea_life_check(K.sea_can_enter(locate(9, 7, 1)) && !K.sea_can_enter(locate(22, 20, 1)), "a kelp turtle keeps to the shelf")
	var/moved = 0
	var/stayed = TRUE
	var/turf/start = get_turf(F)
	for (var/i = 1, i <= 8, i++)
		sea_life_tick(F)
		if (!sea_life_in_water(F) || sea_zone_of(get_turf(F)) > F.zone_max)
			stayed = FALSE
	moved = get_dist(start, F)
	sea_life_check(moved > 0 && stayed, "a shoal swims about and stays in its waters (moved [moved])")

	// Out of its waters, it may only head back.
	var/mob/living/simple_animal/sea/kelp_turtle/lost = new(locate(18, 20, 1))
	var/here_zone = sea_zone_of(get_turf(lost))
	sea_life_check(here_zone > SEA_ZONE_SHELF && lost.sea_can_enter(locate(17, 20, 1)) && lost.sea_can_enter(locate(8, 20, 1)) && !K.sea_can_enter(locate(17, 20, 1)), "a turtle carried out to open water may swim back, but one on the shelf never leaves it")
	sea_life_tick(lost, 10)
	sea_life_check(sea_zone_of(get_turf(lost)) == SEA_ZONE_SHELF, "and it does swim back to the shelf (zone [sea_zone_of(get_turf(lost))] at [lost.x],[lost.y])")
	qdel(lost)

	// ---- Senses ----
	var/mob/living/simple_animal/sea/shoal/G = new(locate(20, 20, 1))
	var/mob/living/sea_life_probe/diver/D = new(locate(24, 20, 1))
	sea_life_check(sea_diver(D), "a person out in the water counts as a diver")
	sea_life_check(!G.sea_scare(), "a diver four tiles off without a lamp does not scare a shoal")
	D.light_range = 4
	sea_life_check(G.sea_scare() == get_turf(D), "a diver with a lit lamp does")
	D.light_range = 0
	D.forceMove(locate(22, 20, 1))
	sea_life_check(G.sea_scare() == get_turf(D), "a diver two tiles off does too")
	var/before = get_dist(G, D)
	sea_life_tick(G, 2)
	sea_life_check(get_dist(G, D) > before, "the shoal scatters away from the diver ([before] -> [get_dist(G, D)])")
	D.forceMove(locate(28, 28, 1))
	sleep(50)
	G.flee_from = null
	var/turf/noise_at = locate(G.x + 3, G.y, 1)
	sea_noise(noise_at, 20)
	sea_life_check(sea_noise_heard(get_turf(G)) == noise_at, "a sonar ping is heard within its range")
	sea_life_check(!sea_noise_heard(locate(29, 2, 1)) || get_dist(locate(29, 2, 1), noise_at) <= 20, "and not beyond it")
	for (var/list/N in sea_noises)
		N[5] = world.time - 7 SECONDS
	sea_life_check(!sea_noise_heard(get_turf(G)), "a noise fades after a few seconds")
	qdel(G)

	// ---- Shoals keep together ----
	var/mob/living/simple_animal/sea/shoal/darters/A1 = new(locate(6, 4, 1))
	var/mob/living/simple_animal/sea/shoal/darters/A2 = new(locate(10, 4, 1))
	sea_life_tick(A1, 2)
	sea_life_check(get_dist(A1, A2) <= 3, "a darter swims back to its school ([get_dist(A1, A2)] tiles)")
	qdel(A1)
	qdel(A2)

	// ---- Kelp turtle ----
	K.forceMove(locate(9, 6, 1))
	var/mob/living/sea_life_probe/diver/D2 = new(locate(10, 6, 1))
	K.lastattacker = D2
	K.adjustBruteLoss(10)
	K.do_behaviour("scared")
	sea_life_tick(K, 3)
	sea_life_check(get_dist(K, D2) > 1 && sea_zone_of(get_turf(K)) == SEA_ZONE_SHELF, "a hurt kelp turtle hurries away, staying on the shelf ([get_dist(K, D2)] tiles)")
	qdel(D2)

	// ---- Reef eel ----
	var/mob/living/simple_animal/sea/reef_eel/E = new(locate(4, 15, 1))
	sea_life_check(sea_crevice(get_turf(E)), "a reef eel's home is water against rock")
	var/mob/living/sea_life_probe/diver/prey = new(locate(9, 15, 1))
	sea_life_tick(E)
	sea_life_check(E.den == get_turf(E) && E.icon_state == "reef_eel_hidden" && !prey.getBruteLoss(), "it waits hidden in its crevice while divers pass at a distance")
	prey.forceMove(locate(6, 15, 1))
	for (var/i = 1, i <= 4 && !prey.getBruteLoss(), i++)
		sea_life_tick(E)
	sea_life_check(prey.getBruteLoss() > 0, "it lunges and bites a diver who swims close ([prey.getBruteLoss()] damage)")
	prey.forceMove(locate(20, 25, 1))
	sea_life_tick(E, 4)
	sea_life_check(get_turf(E) == E.den && E.icon_state == "reef_eel_hidden", "then it goes back into its crevice")

	// ---- Drift jelly ----
	var/mob/living/simple_animal/sea/drift_jelly/J = new(locate(20, 20, 1))
	sea_life_check(J.light_range == 2, "a drift jelly glows")
	var/mob/living/sea_life_probe/diver/stung = new(locate(20, 20, 1))
	J.handle_ai()
	sea_life_check(stung.getBurnLoss() > 0, "it stings a diver it touches ([stung.getBurnLoss()] burn)")
	J.death()
	sea_life_check(J.light_range == 0 && J.icon_state == "drift_jelly_dead", "a dead jelly goes dark")

	// ---- Butchering ----
	var/mob/living/simple_animal/sea/shoal/catch_fish = new(locate(12, 25, 1))
	catch_fish.death()
	sea_life_check(catch_fish.icon == 'icons/mob/sea_life.dmi' && catch_fish.icon_state == "shoal_dead", "a dead shoal shows dead fish")
	var/turf/site = locate(13, 25, 1)
	catch_fish.harvest_products(site, FALSE)
	var/fish = 0
	var/other = 0
	for (var/obj/item/I in site)
		if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/rawfish))
			fish++
		else
			other++
	sea_life_check(fish == 2 && !other, "butchering it gives raw fish and nothing else ([fish] fish, [other] other)")

	// ---- Art ----
	var/list/states = icon_states('icons/mob/sea_life.dmi')
	var/art = TRUE
	for (var/s in list("kelp_turtle", "kelp_turtle_dead", "reef_eel", "reef_eel_hidden", "reef_eel_dead", "drift_jelly", "drift_jelly_dead", "shoal_dead"))
		if (!(s in states))
			art = FALSE
	sea_life_check(art && ("fish1" in icon_states('icons/mob/fish.dmi')) && ("fish2" in icon_states('icons/mob/fish.dmi')), "every sea animal has its art")

	// ---- Spawning ----
	for (var/mob/living/simple_animal/sea/S in world)
		qdel(S)
	sleep(1)
	sea_life_table = list(
		new /datum/sea_species("probe shoal", /mob/living/simple_animal/sea/shoal, SEA_ZONE_SHELF, SEA_ZONE_OPEN, 20, 6, 2, 3),
		new /datum/sea_species("probe eel", /mob/living/simple_animal/sea/reef_eel, SEA_ZONE_SHELF, SEA_ZONE_OPEN, 20, 3, 1, 1, TRUE),
		new /datum/sea_species("probe turtle", /mob/living/simple_animal/sea/kelp_turtle, SEA_ZONE_SHELF, SEA_ZONE_SHELF, 20, 3, 1, 2))
	var/placed = 0
	for (var/i = 1, i <= 6, i++)
		placed += sea_life_cycle()
	var/total = 0
	var/good = TRUE
	var/list/bad = list()
	for (var/mob/living/simple_animal/sea/S in world)
		if (S.stat == DEAD || !S.loc)
			continue
		total++
		var/zone = sea_zone_of(get_turf(S))
		if (!sea_life_in_water(S) || zone < S.zone_min || zone > S.zone_max)
			good = FALSE
			bad += "[S] at [S.x],[S.y]"
		if (istype(S, /mob/living/simple_animal/sea/reef_eel) && !sea_crevice(get_turf(S)))
			good = FALSE
			bad += "eel off the rock at [S.x],[S.y]"
	sea_life_check(placed == total && total == 12, "the ecology cycle tops each kind up to its target ([total] placed): [sea_life_last_report]")
	sea_life_check(good, "every animal spawns in open water of its own zones, eels against rock [jointext(bad, "; ")]")
	sea_life_check(sea_life_cycle() == 0, "a full sea spawns nothing more")
	map.sea_life_cap = total - 2
	for (var/mob/living/simple_animal/sea/S in world)
		qdel(S)
	sleep(1)
	placed = 0
	for (var/i = 1, i <= 6, i++)
		placed += sea_life_cycle()
	sea_life_check(placed == total - 2, "sea life stops at its own cap ([placed])")
	map.sea_life_cap = initial(map.sea_life_cap)
	sea_life_table = sea_life_species()
	sea_life_check(sea_life_table.len == 5, "the sea has five kinds of animal")
	seabed_zone_counts = list(19745, 19987, 12352, 4004)
	var/list/targets = list()
	for (var/datum/sea_species/SP in sea_life_table)
		targets += "[SP.name] [sea_species_target(SP)]"
	world.log << "Gaia-sized targets: [jointext(targets, ", ")]"

/proc/sea_life_run()
	try
		sea_life_checks()
	catch(var/exception/e)
		sea_life_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = sea_life_failures, "runtime_error" = sea_life_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/sea_life_probe
		sea_life_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		sea_life_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		sea_life_run()
