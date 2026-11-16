// Native probe for kept bee colonies (code/modules/1713/kept_hives.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/kept_hives/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 24
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/wild_bee_probe/New()
	return
/mob/living/human/wild_bee_probe/New()
	return
/mob/living/human/wild_bee_probe/adaptStat(statname, multiplier = 1, source = null)
	return
// A bare probe body has no icons to update: hands are just slots here.
/mob/living/human/wild_bee_probe/put_in_hands(obj/item/W)
	W.loc = src
	l_hand = W
	return TRUE
/mob/living/human/wild_bee_probe/drop_from_inventory(obj/item/W, atom/target = null)
	if (l_hand == W)
		l_hand = null
	if (r_hand == W)
		r_hand = null
	W.loc = target ? target : loc
	return TRUE

var/wb_failures = 0
var/wb_runtime_error = FALSE
/proc/wb_check(condition, label)
	if (!condition)
		wb_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	wb_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/wild_bee_probe
		populate_material_list()
		wild_bee_checks()
	catch(var/exception/e)
		wb_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = wb_failures, "runtime_error" = wb_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
	return

/proc/wb_count(turf/T, item_type)
	var/count = 0
	for (var/obj/item/I in T)
		if (istype(I, item_type))
			count++
	return count

/proc/wild_bee_checks()
	var/area/A = get_area(locate(1, 1, 1))
	A.location = AREA_OUTSIDE
	A.climate = "temperate"
	season = SEASON_SPRING

	// A swarm from a strong colony hangs nearby and goes into an empty hive.
	var/turf/home = locate(5, 5, 1)
	var/obj/structure/kept_hive/parent = new(home)
	wb_check(!parent.occupied && !parent.anchored && parent.icon_state == "log_hive", "a new hive is empty and can be pulled")
	parent.settle(90)
	var/obj/structure/bee_swarm_cluster/S = cast_swarm(parent, 40)
	wb_check(istype(S) && get_dist(S, parent) <= 2 && S.loc != parent.loc, "a swarm hangs near its colony")
	var/mob/living/human/wild_bee_probe/keeper = new(get_turf(S))
	S.attack_hand(keeper)
	wb_check(!QDELETED(S), "a swarm needs an empty hive next to it")
	var/turf/beside = get_step(get_turf(S), EAST)
	if (beside == home)
		beside = get_step(get_turf(S), WEST)
	var/obj/structure/kept_hive/skep/skep = new(beside)
	S.attack_hand(keeper)
	wb_check(QDELETED(S) && skep.occupied && skep.strength == 40 && skep.anchored && skep.icon_state == "skep_bees", "shaking a swarm in settles the colony and fixes the hive in place")
	wb_check(keeper.bee_chase_until == 0, "swarming bees do not sting")

	// Growth with forage, stores capped, honey eaten in winter, death when empty.
	season = SEASON_SUMMER
	for (var/i = 1, i <= 8, i++)
		new /obj/structure/farming/plant/wheat(locate(10 + i, 9, 1))
	var/turf/apiary = locate(14, 8, 1)
	var/obj/structure/kept_hive/clay/C = new(apiary)
	C.settle(30)
	for (var/i = 1, i <= 60, i++)
		C.colony_tick(TRUE, FALSE)
	wb_check(C.strength > 30 && C.combs > 0 && C.combs <= C.max_combs, "a colony grows and stores comb in season with forage")
	var/obj/structure/kept_hive/bare = new(locate(2, 11, 1))
	bare.settle(30)
	for (var/i = 1, i <= 30, i++)
		bare.colony_tick(TRUE, FALSE)
	wb_check(bare.strength < 30 && bare.combs == 0, "with no forage a colony dwindles")
	C.combs = 3
	C.strength = 100
	for (var/i = 1, i <= 200 && C.combs > 0, i++)
		C.colony_tick(FALSE, FALSE)
	wb_check(C.combs == 0 && C.occupied, "out of season the colony eats its stored comb")
	for (var/i = 1, i <= 400 && C.occupied, i++)
		C.colony_tick(FALSE, FALSE)
	wb_check(!C.occupied && C.strength == 0 && C.icon_state == "clay_hive", "with no comb left the colony dies out")

	// Swarming season: a strong colony casts swarms and loses strength.
	var/obj/structure/kept_hive/strong = new(locate(20, 3, 1))
	strong.settle(100)
	strong.forage = 16
	strong.forage_at = world.time
	for (var/i = 1, i <= 200 && strong.strength >= 80, i++)
		strong.colony_tick(TRUE, TRUE)
	wb_check(strong.strength < 80 && (locate(/obj/structure/bee_swarm_cluster) in range(2, strong)), "a strong colony swarms in spring")

	// Cutting comb: smoked takes a comb and costs brood; unsmoked brings stings.
	var/obj/structure/kept_hive/H = new(locate(3, 3, 1))
	H.settle(60)
	H.combs = 2
	var/mob/living/human/wild_bee_probe/cutter = new(locate(3, 3, 1))
	var/obj/item/weapon/material/kitchen/utensil/knife/K = new(locate(3, 3, 1))
	H.smoked_until = world.time + 600
	H.attackby(K, cutter)
	wb_check(H.combs == 1 && H.strength == 52 && wb_count(locate(3, 3, 1), /obj/item/weapon/reagent_containers/food/snacks/honeycomb) == 1, "cutting comb from a smoked hive gives honeycomb and kills some brood")
	wb_check(cutter.bee_chase_until == 0, "a smoked hive does not sting")
	H.smoked_until = 0
	spawn(0) H.attackby(K, cutter)
	sleep(2)
	wb_check(cutter.bee_chase_until > world.time, "cutting comb without smoke brings stings")
	cutter.bee_chase_until = 0
	sleep(70)

	// The registry drives the colony tick every third minute.
	kept_hive_cycle_count = 0
	var/before = H.strength
	H.forage = 16
	H.forage_at = world.time
	kept_hive_cycle()
	kept_hive_cycle()
	wb_check(H.strength == before, "colonies wait for the third minute")
	wb_check(kept_hive_cycle() > 0, "the third minute ticks every kept hive")
