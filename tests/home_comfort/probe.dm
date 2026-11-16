// Native probe: the room a character sleeps in is judged, and its tier pays
// through the resting mood, the resting cap and being well rested.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/home_comfort/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/hc_probe/New()
	return
/mob/living/human/hc_probe/New()
	return
/mob/living/human/hc_probe/update_icons()
	return
/obj/covers/hc_wall
	wall = TRUE
	density = TRUE
	var/hc_finished = FALSE
/obj/covers/hc_wall/New()
	return
/obj/covers/hc_wall/home_finished()
	return hc_finished
/obj/covers/hc_floor
	wall = FALSE
/obj/covers/hc_floor/New()
	return
/obj/structure/simple_door/hc_door/New()
	return
/obj/structure/bed/hc_bed/New()
	return
/obj/structure/bed/bedroll/hc_roll/New()
	return
/obj/structure/bed/chair/hc_chair/New()
	return
/obj/structure/table/hc_table/New()
	return
/obj/structure/lamp/hc_lamp/New()
	return
/obj/structure/painting_frame/hc_painting/New()
	return
/obj/structure/plant_pot/hc_pot/New()
	return
/obj/structure/sign/custom/hc_sign/New()
	return
/obj/item/trash/hc_trash/New()
	return

var/hc_failures = 0
var/hc_runtime_error = FALSE
/proc/hc_check(condition, label)
	if (!condition)
		hc_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	hc_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		map = new /obj/map_metadata/hc_probe
		map.nomads = TRUE
		map.civilizations = TRUE
		hc_checks()
	catch(var/exception/e)
		hc_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = hc_failures, "runtime_error" = hc_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/hc_human(x, y)
	var/mob/living/human/hc_probe/H = new(locate(x, y, 1))
	H.stat = CONSCIOUS
	H.has_hunger_and_thirst = TRUE
	H.species = new /datum/species/human
	H.hygiene = 150
	H.bodytemperature = 290
	H.nutrition = H.max_nutrition
	H.water = H.max_water
	H.diet_reserves = list()
	for (var/group in diet_groups)
		H.diet_reserves[group] = 0
	return H

/proc/hc_rest(mob/living/human/H)
	H.refresh_mood_rest()
	return H.mood_rest

/proc/hc_judge(x = 5, y = 5)
	return home_comfort_judge(locate(x, y, 1))

/proc/hc_sleep_and_wake(mob/living/human/H)
	H.inducedSSD = TRUE
	H.sleeping = 66
	hc_rest(H)
	H.inducedSSD = FALSE
	H.sleeping = 0
	return hc_rest(H)

/proc/hc_checks()
	var/area/here = get_area(locate(5, 5, 1))
	here.location = AREA_OUTSIDE
	var/list/judged = hc_judge()
	hc_check(!judged["tiles"] && judged["tier"] == 0, "open ground is no room")

	// A 5x5 room (3..7) inside walls on rows and columns 2 and 8.
	here.location = AREA_INSIDE
	var/list/walls = list()
	for (var/x = 2, x <= 8, x++)
		for (var/y = 2, y <= 8, y++)
			if (x == 2 || x == 8 || y == 2 || y == 8)
				var/obj/covers/hc_wall/W = new(locate(x, y, 1))
				W.health = 100
				W.maxhealth = 100
				walls += W
	judged = hc_judge()
	hc_check(judged["tiles"] == 25 && judged["points"] == 2 && judged["tier"] == 0, "a bare room is clean and sound but bare ([judged["tiles"]] [judged["points"]])")

	new /obj/structure/bed/hc_bed(locate(3, 3, 1))
	new /obj/structure/bed/chair/hc_chair(locate(4, 3, 1))
	judged = hc_judge()
	hc_check(judged["points"] == 2, "a bed and a chair without a table is not a set")
	new /obj/structure/table/hc_table(locate(5, 3, 1))
	judged = hc_judge()
	hc_check(judged["points"] == 3 && judged["tier"] == 1, "a bed, a seat and a table make it cosy")
	new /obj/structure/bed/chair/hc_chair(locate(6, 3, 1))
	new /obj/structure/table/hc_table(locate(7, 3, 1))
	judged = hc_judge()
	hc_check(judged["points"] == 3, "more furniture of the same kinds adds nothing")

	new /obj/structure/lamp/hc_lamp(locate(3, 7, 1))
	new /obj/structure/painting_frame/hc_painting(locate(4, 7, 1))
	judged = hc_judge()
	hc_check(judged["points"] == 5 && judged["tier"] == 2, "a light and a painting make it comfortable")

	var/obj/structure/plant_pot/hc_pot/pot = new(locate(5, 7, 1))
	judged = hc_judge()
	hc_check(judged["points"] == 5, "an empty pot is no plant")
	pot.filled = TRUE
	judged = hc_judge()
	hc_check(judged["points"] == 6, "a filled pot is")

	var/obj/structure/sign/custom/hc_sign/sign = new(locate(5, 8, 1))
	judged = hc_judge()
	hc_check(judged["points"] == 6, "a blank sign does not name the house")
	sign.name = "The Mill House"
	judged = hc_judge()
	hc_check(judged["points"] == 7 && judged["tier"] == 3, "a named sign on the wall makes it fine")

	for (var/x = 3, x <= 7, x++)
		for (var/y = 3, y <= 4, y++)
			new /obj/covers/hc_floor(locate(x, y, 1))
	judged = hc_judge()
	hc_check(judged["points"] == 7, "a floor two-fifths covered does not count")
	for (var/x = 3, x <= 7, x++)
		new /obj/covers/hc_floor(locate(x, 5, 1))
	judged = hc_judge()
	hc_check(judged["points"] == 8, "covered over half, it does")

	for (var/obj/covers/hc_wall/W in walls)
		W.hc_finished = TRUE
	judged = hc_judge()
	hc_check(judged["points"] == 9 && judged["tier"] == 4 && !length(judged["missing"]), "finished walls make it splendid")

	// Upkeep.
	var/list/trash = list()
	for (var/i = 1, i <= 3, i++)
		trash += new /obj/item/trash/hc_trash(locate(6, 6, 1))
	judged = hc_judge()
	hc_check(judged["points"] == 8 && ("a clean room" in judged["missing"]), "rubbish lowers it")
	for (var/obj/item/trash/T in trash)
		T.loc = null
	var/obj/covers/hc_wall/cracked = locate(/obj/covers/hc_wall) in locate(2, 5, 1)
	cracked.health = 40
	judged = hc_judge()
	hc_check(judged["points"] == 8 && ("sound walls" in judged["missing"]), "a cracked wall lowers it")
	cracked.health = 100

	// A door counts as wall.
	var/obj/covers/hc_wall/gap = locate(/obj/covers/hc_wall) in locate(8, 5, 1)
	gap.loc = null
	new /obj/structure/simple_door/hc_door(locate(8, 5, 1))
	judged = hc_judge()
	hc_check(judged["tiles"] == 25, "a door closes the room")

	// Sleeping there: the tier is noted while asleep and pays after waking.
	var/mob/living/human/H = hc_human(5, 5)
	hc_check(hc_rest(H) == 55 && H.mood_rest_parts["a roof over your head"] == 3, "awake, before sleeping there, it is just a roof ([H.mood_rest])")
	hc_check(hc_sleep_and_wake(H) == 60 && H.home_comfort == 4 && H.mood_rest_parts["a splendid home"] == 8 && !("a roof over your head" in H.mood_rest_parts), "a splendid home replaces the roof ([H.mood_rest] [json_encode(H.mood_rest_parts)])")
	hc_check(H.home_well_rested() && H.home_rest_hunger_mult() < 1, "and the sleeper wakes well rested")
	H.loc = locate(15, 15, 1)
	hc_check(hc_rest(H) == 58, "the home counts away from it, like the bed")

	// The cap: everything good together rests above 75 only with a fine home.
	H.hygiene = 250
	H.bodytemperature = H.species.body_temperature
	for (var/group in diet_groups)
		H.diet_reserves[group] = 100
	H.sleep_comfort = 8
	H.loc = locate(5, 5, 1)
	hc_check(hc_rest(H) == 79 && mood_tier(H.mood_rest) == MOOD_TIER_GOOD, "a splendid home lifts the cap to 79, still good ([H.mood_rest])")
	H.home_comfort = 3
	hc_check(hc_rest(H) == 77, "a fine home lifts it to 77 ([H.mood_rest])")
	H.home_comfort = 2
	hc_check(hc_rest(H) == 75, "a comfortable one does not ([H.mood_rest])")

	// Rest wears off.
	H.well_rested_until = world.time - 1
	hc_check(!H.home_well_rested() && H.home_rest_hunger_mult() == 1, "being well rested wears off")

	// A bare room: no lift, no rest bonus.
	for (var/obj/structure/S in range(10, locate(5, 5, 1)))
		if (!istype(S, /obj/structure/simple_door))
			S.loc = null
	for (var/obj/covers/hc_floor/F in range(10, locate(5, 5, 1)))
		F.loc = null
	for (var/obj/covers/hc_wall/W in walls)
		W.hc_finished = FALSE
	H.well_rested_until = 0
	hc_sleep_and_wake(H)
	hc_check(H.home_comfort == 0 && !H.home_well_rested() && H.mood_rest_parts["a roof over your head"] == 3, "a bare room gives just the roof ([H.home_comfort])")

	// Battle maps ignore it.
	H.home_comfort = 4
	map.nomads = FALSE
	map.civilizations = FALSE
	hc_check(hc_rest(H) == 50, "a battle map ignores the home ([H.mood_rest])")
