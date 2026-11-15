// Huey air assault on SStimer, headless (run.py).
/world
	maxx = 60
	maxy = 60
	maxz = 1
	turf = /turf/floor/grass
	area = /area/caribbean/huey_probe

/area/caribbean/huey_probe
	name = "probe jungle"
	location = AREA_OUTSIDE

/mob/living/human/huey_probe/New()
	return

var/hp_failures = 0
/proc/hp_check(cond, msg)
	if (!cond)
		hp_failures++
	text2file("[cond ? "ok" : "FAIL"]: [msg]\n", "hp_log.txt")

/world/Error(exception/e)
	hp_check(FALSE, "runtime error [e] [e.file]:[e.line]")

/world/New()
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	spawn(5)
		hp_run()

/obj/map_metadata/huey_probe
	ID = MAP_HUE
/obj/map_metadata/huey_probe/New()
	return
/obj/map_metadata/huey_probe/faction1_can_cross_blocks()
	return TRUE
/obj/map_metadata/huey_probe/faction2_can_cross_blocks()
	return TRUE

/proc/hp_run()
	Master.start_timer_loop()
	try
		hp_cases()
	catch (var/exception/e)
		hp_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file("DONE\n", "hp_log.txt")
	del(world)

/proc/hp_man(faction, x, y)
	var/mob/living/human/huey_probe/M = new(locate(x, y, 1))
	M.faction_text = faction
	M.m_intent = "stealth" // no footstep sounds without the movement process
	return M

/obj/structure/hp_wall
	name = "probe wall"
	density = TRUE
	anchored = TRUE

/proc/hp_cases()
	map = new /obj/map_metadata/huey_probe
	// The American start sits in a walled yard; the clear pad is outside it.
	for (var/turf/T in block(locate(8, 8, 1), locate(12, 12, 1)))
		if (T.x != 10 || T.y != 10)
			new /obj/structure/hp_wall(T)
	latejoin_turfs = list("JoinLateRN" = list(locate(10, 10, 1)))
	var/obj/structure/huey/H = huey_deploy()
	hp_check(istype(H) && huey_of(AMERICAN) == H, "a Huey is put on a pad near the American start")
	if (!H)
		return
	var/turf/home = get_turf(H)
	hp_check(huey_can_land(home) && get_dist(home, locate(10, 10, 1)) <= 25, "the pad is clear ground near the start ([home.x],[home.y])")
	hp_check(!huey_deploy(), "only one Huey per round")
	hp_check(!huey_can_land(locate(10, 10, 1)), "a walled yard is no landing spot")

	var/mob/living/human/huey_probe/grunt = hp_man(AMERICAN, home.x + 1, home.y)
	var/mob/living/human/huey_probe/vc = hp_man(VIETNAMESE, home.x - 1, home.y)
	H.attack_hand(vc)
	hp_check(vc.loc != H && !(vc in H.passengers), "the enemy is waved off")
	H.attack_hand(grunt)
	hp_check(grunt.loc == H && (grunt in H.passengers), "a soldier climbs aboard")
	hp_check(!H.call_lift(), "with no landing zone she stays on the ground")
	var/list/zones = huey_zones()
	hp_check(zones.len == 9, "a passenger can pick from nine parts of the map ([zones.len])")

	// Smoke marks the LZ and calls the lift.
	var/turf/smoke = locate(45, 45, 1)
	hp_check(huey_mark_lz(smoke, grunt) && H.lz && get_dist(H.lz, smoke) <= 6, "signal smoke marks the landing zone")
	hp_check(H.state == "boarding", "lift-off is called")
	sleep(160)
	hp_check(H.state == "outbound" && H.plane == ROOF_PLANE && H.shadow, "she lifts off over the roofs with her shadow below")
	// A second smoke during the flight waits for the next lift.
	var/turf/second = locate(45, 15, 1)
	huey_mark_lz(second, grunt)
	var/turf/second_lz = H.lz
	sleep(120)
	hp_check(grunt.loc != H && isturf(grunt.loc) && get_dist(grunt, smoke) <= 8, "the soldier is set down at the smoke ([grunt.x],[grunt.y])")
	hp_check(!H.passengers.len, "the cabin is empty after the drop")
	sleep(200)
	hp_check(H.state == "parked" && get_turf(H) == home && !H.shadow, "she flies home and parks on the pad")
	hp_check(H.lz == second_lz && second_lz, "the smoke popped during the flight waits for the next lift")
