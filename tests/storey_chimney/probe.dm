// Native probe for chimneys carrying heat upstairs
// (code/game/objects/storey_chimney.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/storey_chimney/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 8
	maxz = 3
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/ch_probe/New()
	return
/mob/living/human/ch_fixture
	m_intent = "stealth"
	var/mood_gain = 0
/mob/living/human/ch_fixture/New()
	return
/mob/living/human/ch_fixture/adaptStat(stat, amount)
	return
/mob/living/human/ch_fixture/update_body(update_icons = 1, forced = FALSE)
	return
/mob/living/human/ch_fixture/update_icons()
	return
/mob/living/human/ch_fixture/regenerate_icons()
	return
/mob/living/human/ch_fixture/adjust_mood(amount, reason)
	mood_gain += amount
var/ch_failures = 0
var/ch_runtime_error = FALSE
/proc/ch_check(condition, label)
	if (!condition)
		ch_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ch_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/ch_probe
		ch_checks()
	catch(var/exception/e)
		ch_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ch_failures, "runtime_error" = ch_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/ch_checks()
	var/obj/structure/oven/fireplace/FP = new(locate(5, 4, 1))
	FP.on = FALSE
	var/obj/structure/chimney/C1 = new(locate(5, 4, 2))
	ch_check(C1.chimney_heat() == 0, "a chimney over a cold hearth gives no heat")
	ch_check(C1.icon_state == "chimney_top" && !C1.smoking, "a lone chimney is a capped top, not smoking")
	FP.on = TRUE
	ch_check(C1.chimney_heat() == 1, "over a lit fireplace (2) it carries half the heat ([C1.chimney_heat()])")
	ch_check(building_heat_power(C1) == 1, "the room's heat counts the chimney")
	var/obj/structure/chimney/C2 = new(locate(5, 4, 3))
	ch_check(C1.icon_state == "chimney" && C2.icon_state == "chimney_top", "a stack shows the column below and the cap on top")
	ch_check(C2.chimney_heat() == 0.5, "the next storey up gets half again ([C2.chimney_heat()])")
	ch_check(C2.smoking && !C1.smoking, "only the top of the stack smokes")
	qdel(C2)
	ch_check(C1.icon_state == "chimney_top", "taking the top away caps the one below")
	var/obj/structure/chimney/cold = new(locate(8, 4, 2))
	ch_check(cold.chimney_heat() == 0, "a chimney over nothing gives no heat")
	var/obj/structure/chimney/ground = new(locate(8, 4, 1))
	ch_check(ground.chimney_heat() == 0, "a chimney on the ground has nothing below it")
