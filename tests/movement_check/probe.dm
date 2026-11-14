// Headless probe for Check Movement (code/modules/1713/movement_check.dm):
// a real human's listed body costs add up to movement_delay(), and the report
// names each cause. Run: python3 tests/ecology_spawning/run_linux.py . tests/movement_check/probe.dm
/world
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf/floor/dirt

/obj/map_metadata/movement_check_probe/New()
	map = src

var/movement_check_failures = 0
var/movement_check_runtime_error = FALSE
/proc/movement_check_probe(condition, label)
	if (!condition)
		movement_check_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"

/world/Error(exception/e)
	movement_check_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/movement_check_probe
		makeDatumRefLists()
		movement_check_probe_run()
	catch(var/exception/e)
		movement_check_probe(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = movement_check_failures, "runtime_error" = movement_check_runtime_error, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/movement_check_body_total(mob/living/human/H)
	. = 0
	var/list/parts = H.movement_check_body_parts()
	for (var/label in parts)
		. += parts[label]

/proc/movement_check_probe_run()
	var/mob/living/human/H = new(locate(5, 5, 1))
	H.next_calculate_tally = -1
	movement_check_probe(abs(movement_check_body_total(H) - H.movement_delay()) < 0.001, "rested body adds up ([movement_check_body_total(H)] vs [H.movement_delay()])")
	H.nutrition = 120
	H.water = 60
	H.mood = 30
	H.next_calculate_tally = -1
	var/list/parts = H.movement_check_body_parts()
	movement_check_probe(parts.len >= 3 && abs(movement_check_body_total(H) - H.movement_delay()) < 0.001, "hungry, thirsty, glum body adds up ([movement_check_body_total(H)] vs [H.movement_delay()])")
	var/list/report = H.movement_check_report()
	var/text = jointext(report, "\n")
	text2file(text, "report.txt")
	world.log << text
	movement_check_probe(findtext(text, "hunger") && findtext(text, "thirst") && findtext(text, "low mood"), "report names the causes")
	movement_check_probe(findtext(text, "a step takes about"), "report gives the step time")
	movement_check_probe(findtext(text, "There are no hills on this map."), "report reads the ground")
	// Shallow water underfoot is listed with its cost.
	var/turf/W = locate(6, 5, 1)
	W.ChangeTurf(/turf/floor/beach/water/shallowsaltwater)
	H.loc = locate(6, 5, 1)
	var/list/ground = H.movement_check_ground_parts(H.loc)
	movement_check_probe(ground.len == 1 && ground[ground[1]] == 3, "shallow water costs 3 ([json_encode(ground)])")
	H.loc = locate(5, 5, 1)
	H.nutrition = H.max_nutrition
	H.water = H.max_water
	H.mood = 100
	H.next_calculate_tally = -1
	text = jointext(H.movement_check_report(), "\n")
	movement_check_probe(findtext(text, "Nothing on you or under you is slowing you down."), "rested report is clear")
