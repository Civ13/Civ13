// Naval broadsides on SStimer, headless (run.py).
/world
	maxx = 40
	maxy = 40
	maxz = 1
	turf = /turf/floor/wood/ship
	area = /area

/mob/living/human/broadside_probe/New()
	return

var/nb_failures = 0
/proc/nb_check(cond, msg)
	if (!cond)
		nb_failures++
	text2file("[cond ? "ok" : "FAIL"]: [msg]\n", "nb_log.txt")

/world/Error(exception/e)
	nb_check(FALSE, "runtime error [e] [e.file]:[e.line]")

/world/New()
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	spawn(5)
		nb_run()

/obj/map_metadata/broadside_probe/New()
	return
/obj/map_metadata/broadside_probe/faction1_can_cross_blocks()
	return TRUE

/proc/nb_run()
	Master.start_timer_loop()
	try
		nb_cases()
	catch (var/exception/e)
		nb_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file("DONE\n", "nb_log.txt")
	del(world)

/proc/nb_area(x1, y1, x2, y2, path)
	var/area/A = locate(path)
	if (!A)
		A = new path
	for (var/turf/T in block(locate(x1, y1, 1), locate(x2, y2, 1)))
		A.contents += T

/proc/nb_gun(x, y, d, loaded = TRUE, path = /obj/structure/cannon)
	var/obj/structure/cannon/C = new path(locate(x, y, 1))
	C.dir = d
	C.explosion = FALSE // no explosion subsystem in the probe
	if (loaded)
		C.loaded += new /obj/item/cannon_ball(C)
	return C

/proc/nb_cases()
	map = new /obj/map_metadata/broadside_probe
	// British ship y 5-12, its north hull row y 13 in no man's land; pirates y 25-32.
	nb_area(5, 5, 35, 12, /area/caribbean/british/ship/main_deck)
	nb_area(5, 25, 35, 32, /area/caribbean/pirates/ship/main_deck)
	var/list/north = list(nb_gun(10, 12, NORTH), nb_gun(14, 12, NORTH), nb_gun(18, 12, NORTH))
	var/obj/structure/cannon/hull = nb_gun(22, 13, NORTH)
	north += hull
	var/obj/structure/cannon/south = nb_gun(12, 5, SOUTH)
	var/obj/structure/cannon/empty = nb_gun(26, 12, NORTH, FALSE)
	var/obj/structure/cannon/broken = nb_gun(28, 12, NORTH)
	broken.broken = TRUE
	var/obj/structure/cannon/enemy = nb_gun(14, 25, SOUTH)

	nb_check(broadside_ship_of(locate(20, 8, 1)) == "/area/caribbean/british/ship", "a deck tile belongs to its ship")
	nb_check(isnull(broadside_ship_of(locate(20, 20, 1))), "open water belongs to no ship")
	nb_check(broadside_gun_ship(hull) == "/area/caribbean/british/ship", "a gun set in the hull belongs to the deck behind it")
	var/list/sides = broadside_guns(locate(20, 8, 1))
	var/list/n = sides["[NORTH]"]
	nb_check(sides.len == 2 && n && n.len == 4, "loaded guns are grouped by the side they face")
	nb_check(!(empty in n) && !(broken in n), "unloaded and broken guns are left out")
	nb_check(!(enemy in n) && !(enemy in sides["[SOUTH]"]), "the other ship's guns never answer")
	nb_check(south in sides["[SOUTH]"], "the far side has its own group")

	nb_check(broadside_fire(n) == 4, "the whole north side is ordered to fire")
	sleep(60)
	var/still = 0
	for (var/obj/structure/cannon/C in north)
		if (C.loaded.len)
			still++
	nb_check(still == 0, "every gun on the ordered side fired")
	nb_check(south.loaded.len == 1 && enemy.loaded.len == 1, "the other side and the enemy stay loaded")
