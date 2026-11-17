// Native probe for storey stores: loft drying, upstairs mice, flood rot
// (code/modules/1713/storey_stores.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/storey_stores/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 8
	maxz = 2
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/ss_probe/New()
	return
/mob/living/human/ss_fixture
	m_intent = "stealth"
	var/mood_gain = 0
/mob/living/human/ss_fixture/New()
	return
/mob/living/human/ss_fixture/adaptStat(stat, amount)
	return
/mob/living/human/ss_fixture/update_body(update_icons = 1, forced = FALSE)
	return
/mob/living/human/ss_fixture/update_icons()
	return
/mob/living/human/ss_fixture/regenerate_icons()
	return
/mob/living/human/ss_fixture/adjust_mood(amount, reason)
	mood_gain += amount
var/ss_failures = 0
var/ss_runtime_error = FALSE
/proc/ss_check(condition, label)
	if (!condition)
		ss_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ss_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/ss_probe
		ss_checks()
	catch(var/exception/e)
		ss_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ss_failures, "runtime_error" = ss_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/area/ss_loft
	location = AREA_INSIDE
/area/ss_roof
	location = AREA_OUTSIDE

/proc/ss_checks()
	above_ground_level_cache["2"] = TRUE // z2 stands for a building storey over the ground
	var/area/ss_loft/loft = new
	loft.contents += locate(2, 2, 2)
	var/area/ss_roof/roof = new
	roof.contents += locate(5, 2, 2)
	var/turf/ground = locate(2, 2, 1)
	var/turf/upstairs = locate(2, 2, 2)
	var/turf/rooftop = locate(5, 2, 2)
	ss_check(!turf_in_loft(ground), "the ground floor is not a loft")
	ss_check(turf_in_loft(upstairs), "a roofed room upstairs is a loft")
	ss_check(!turf_in_loft(rooftop), "an open roof is not a loft")

	var/obj/structure/dehydrator/D = new(ground)
	ss_check(D.dry_step() == 150, "a dehydrator on the ground dries at the usual pace")
	D.loc = upstairs
	ss_check(D.dry_step() == 225, "a dehydrator in a loft dries half again as fast")
	D.loc = rooftop
	ss_check(D.dry_step() == 150, "a dehydrator on an open roof dries at the usual pace")

	ss_check(mouse_nest_site_error(upstairs) == "upstairs", "mice don't nest upstairs ([mouse_nest_site_error(upstairs)])")
	ss_check(mouse_nest_site_error(ground) != "upstairs", "mice can still nest on the ground floor ([mouse_nest_site_error(ground)])")

	ss_check(flood_rots(new /obj/item/weapon/reagent_containers/food/snacks/grown/wheat), "floodwater rots wheat")
	ss_check(!flood_rots(new /obj/item/weapon/reagent_containers/food/condiment/flour), "flour is ruined the old way, not rotted")
