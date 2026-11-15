// Native probe for clay tablets, board games and the ice house
// (code/modules/1713/small_ancient.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/small_ancient/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 8
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/sa_probe/New()
	return
/mob/living/human/sa_fixture
	m_intent = "stealth"
	var/mood_gain = 0
/mob/living/human/sa_fixture/New()
	return
/mob/living/human/sa_fixture/adaptStat(stat, amount)
	return
/mob/living/human/sa_fixture/update_body(update_icons = 1, forced = FALSE)
	return
/mob/living/human/sa_fixture/update_icons()
	return
/mob/living/human/sa_fixture/regenerate_icons()
	return
/mob/living/human/sa_fixture/adjust_mood(amount, reason)
	mood_gain += amount
var/sa_failures = 0
var/sa_runtime_error = FALSE
/proc/sa_check(condition, label)
	if (!condition)
		sa_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	sa_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/sa_probe
		sa_checks()
	catch(var/exception/e)
		sa_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = sa_failures, "runtime_error" = sa_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/sa_checks()
	// Clay tablets.
	var/obj/item/weapon/paper/clay_tablet/T = new(locate(2, 2, 1))
	sa_check(!T.flammable && T.icon_state == "clay_tablet", "a wet tablet is blank clay and won't burn")
	T.info = "Twelve jars of barley."
	T.update_icon()
	sa_check(T.icon_state == "clay_tablet_words", "writing shows on it")
	sa_check(T.fire_tablet() && T.fired && T.icon_state == "clay_tablet_fired_words" && T.info == "Twelve jars of barley.", "firing keeps the same tablet and its writing")
	sa_check(!T.fire_tablet(), "a fired tablet isn't fired twice")
	sa_check(istype(new /obj/item/weapon/pen/stylus, /obj/item/weapon/pen), "a stylus writes like a pen")

	// Board games need a partner.
	var/obj/item/game_board/senet/S = new(locate(5, 5, 1))
	var/mob/living/human/sa_fixture/A = new(locate(5, 4, 1))
	sa_check(!S.play(A), "no game without someone beside you")
	sa_check(S.icon_state == "senet", "the boards have their sprites")

	// Ice house: snow keeps it cold, and it melts.
	var/obj/structure/closet/ice_house/IH = new(locate(8, 2, 1))
	sa_check(!IH.is_cold(), "an empty ice house is not cold")
	var/obj/item/weapon/snowwall/SN = new(locate(8, 3, 1))
	IH.attackby(SN, A)
	sa_check(IH.cold == 60 && QDELETED(SN) && (IH in processing_objects), "a snow pile packs in an hour of cold")
	IH.cold = 1
	IH.melt_seconds = 59
	IH.last_tick = world.time - 20
	IH.process_interval(2)
	sa_check(IH.cold == 0 || get_temp(IH) <= 0, "the snow melts away unless it freezes")
