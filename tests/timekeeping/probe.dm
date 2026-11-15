// Native probe for timekeeping and lighthouses (code/modules/1713/timekeeping.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/timekeeping/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 12
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/tk_probe/New()
	return
/area/tk_indoors
	location = AREA_INSIDE
/mob/living/human/tk_fixture
	m_intent = "stealth"
	var/list/heard = list()
/mob/living/human/tk_fixture/New()
	human_mob_list |= src
/mob/living/human/tk_fixture/adaptStat(stat, amount)
	return
/mob/living/human/tk_fixture/update_body(update_icons = 1, forced = FALSE)
	return
/mob/living/human/tk_fixture/update_icons()
	return
/mob/living/human/tk_fixture/regenerate_icons()
	return
/proc/tk_heard(mob/living/human/tk_fixture/H, text)
	for (var/line in H.heard)
		if (findtext(line, text))
			return TRUE
	return FALSE
var/tk_failures = 0
var/tk_runtime_error = FALSE
/proc/tk_check(condition, label)
	if (!condition)
		tk_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	tk_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/tk_probe
		tk_checks()
	catch(var/exception/e)
		tk_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = tk_failures, "runtime_error" = tk_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/tk_checks()
	// Rough clock readings.
	time_of_day = "Midday"
	game_hour = 60 // 12:00
	tk_check(rough_clock(60) == "about noon", "noon reads as noon ([rough_clock(60)])")
	time_of_day = "Afternoon"
	game_hour = 35 // 3:35 PM
	tk_check(rough_clock(60) == "about 4 o'clock in the afternoon", "the hour rounds to the nearest ([rough_clock(60)])")
	tk_check(rough_clock(30) == "about half past 3 in the afternoon", "the water clock reads the half hour ([rough_clock(30)])")

	// Sundial: no shadow at night or indoors.
	var/obj/structure/sundial/SD = new(locate(2, 2, 1))
	time_of_day = "Night"
	tk_check(findtext(SD.reading(), "no shadow"), "no shadow at night")
	time_of_day = "Midday"
	var/area/tk_indoors/IN = new
	IN.contents += locate(3, 2, 1)
	var/obj/structure/sundial/SD2 = new(locate(3, 2, 1))
	tk_check(findtext(SD2.reading(), "roof"), "no sun under a roof")

	// Water clock: fill, read, drain.
	var/obj/structure/water_clock/WC = new(locate(5, 2, 1))
	tk_check(WC.icon_state == "water_clock_empty" && findtext(WC.reading(), "dry"), "an empty water clock is dry")
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(locate(5, 3, 1))
	B.reagents.add_reagent("water", 50)
	var/mob/living/human/tk_fixture/U = new(locate(5, 4, 1))
	WC.attackby(B, U)
	tk_check(WC.water == 50 && WC.icon_state == "water_clock" && (WC in processing_objects), "filling sets it running")
	tk_check(findtext(WC.reading(), "half past"), "a running water clock reads the half hour")
	WC.water = 1
	WC.drip_seconds = 59
	WC.last_tick = world.time - 20
	WC.process_interval(2)
	tk_check(WC.water == 0 && WC.icon_state == "water_clock_empty", "it runs dry")

	// Hourglass.
	var/obj/item/hourglass/HG = new(locate(6, 2, 1))
	HG.turns = 1
	HG.icon_state = "hourglass_running"
	HG.run_out(2)
	tk_check(HG.icon_state == "hourglass_running", "an old turn's timer doesn't stop a new one")
	HG.run_out(1)
	tk_check(HG.icon_state == "hourglass", "the sand runs out")

	// Tower clock tolls the hour on the bell, heard far off.
	var/obj/structure/tower_clock/TC = new(locate(10, 6, 1))
	var/obj/structure/bell/BL = new(locate(11, 6, 1))
	var/obj/structure/clock_face/CF = new(locate(10, 7, 1))
	tk_check(CF.pixel_y == 32, "a south-facing clock face shows on the wall behind")
	tk_check(findtext(CF.reading(), "stopped"), "a clock face is stopped while the clock is unwound")
	var/mob/living/human/tk_fixture/FAR = new(locate(35, 6, 1))
	TC.wound = 10
	TC.start_running()
	tk_check(findtext(CF.reading(), "hand stands at"), "a wound clock drives the face")
	tk_check(TC.strike(4), "the clock strikes on the bell beside it")
	tk_check(get_dist(FAR, BL) > 7 && BL.ring(4) >= 1, "people far away hear it")

	// Lighthouse beacon.
	var/obj/structure/lighthouse_beacon/LB = new(locate(20, 10, 1))
	var/obj/item/stack/ore/coal/C = new(locate(20, 9, 1))
	C.amount = 5
	LB.attackby(C, U)
	tk_check(LB.fuel == 20 && C.amount == 4, "coal fuels the beacon")
	LB.light_up()
	tk_check(LB.lit && LB.icon_state == "beacon_lit" && LB.is_open_flame(), "lit, it shows and burns")
	var/mob/living/human/tk_fixture/SAILOR = new(locate(30, 2, 1))
	var/turf/ST = get_turf(SAILOR)
	ST.ChangeTurf(/turf/floor/beach/water/deep)
	time_of_day = "Night"
	tk_check(LB.shine() == 1, "a sailor on the water sees the light at night")
	tk_check(LB.shine() == 0, "and isn't told again straight away")
	time_of_day = "Midday"
	LB.told = list()
	tk_check(LB.shine() == 0, "no one is told by day")
	LB.fuel = 1
	LB.burn_seconds = 59
	LB.last_tick = world.time - 20
	LB.process_interval(2)
	tk_check(!LB.lit && LB.icon_state == "beacon", "it burns out with no fuel")
