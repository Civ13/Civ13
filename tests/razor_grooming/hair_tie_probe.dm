// Isolated native smoke test for physical hair length, cover and travel.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/razor_grooming/hair_tie_probe.dm 300
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/hair_tie_probe/New()
	return
var/hair_tie_failures = 0
var/hair_tie_runtime_error = FALSE
/proc/hair_tie_check(condition, label)
	if (!condition)
		hair_tie_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	hair_tie_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	sleep(1)
	try
		config = new
		config.webhook_can_fire = FALSE
		makeDatumRefLists()
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		movementMachine = new
		map = new /obj/map_metadata/hair_tie_probe
		Master.start_timer_loop()
		hair_tie_checks()
	catch(var/exception/e)
		hair_tie_check(FALSE, "exception [e] [e.file]:[e.line] [e.desc]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = hair_tie_failures, "runtime_error" = hair_tie_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/hair_tie_checks()
	map.persistence = FALSE
	var/turf/T = locate(5, 5, 1)
	var/mob/living/human/H = new(T)
	H.persistence_owner_ckey = "hairtietest"
	H.real_name = "Tomas Reed"
	H.gender = MALE
	H.age = 30
	H.h_style = "Shoulder-length Hair"
	H.h_growth = 2.99
	map.civilizations = TRUE
	hair_tie_check(!H.toggle_hair_tie() && H.hair_dusty_work_delay(120) == 120, "short hair is unaffected")
	H.h_growth = 3
	hair_tie_check(H.hair_dusty_work_delay(120) == 126, "loose shoulder-length hair adds five percent to dusty work")
	hair_tie_check(abs(H.drying_rate(20) - 0.009) < 0.00001 && abs(H.drying_rate(10) - 0.0018) < 0.00001, "loose long hair slows drying in warm and cold air")
	var/obj/item/clothing/mask/M = new(H)
	M.body_parts_covered = FACE
	H.wear_mask = M
	hair_tie_check(H.hair_dusty_work_delay(120) == 126, "a face covering without scalp coverage does not control the hair")
	H.wear_mask = null
	var/obj/item/clothing/suit/storage/coat/fur/C = new(H)
	H.wear_suit = C
	C.body_parts_covered &= ~HEAD
	hair_tie_check(H.hair_dusty_work_delay(120) == 126, "hood down leaves hair loose for work")
	C.body_parts_covered |= HEAD
	hair_tie_check(H.hair_dusty_work_delay(120) == 120, "hood up keeps hair out of dusty work")
	H.wear_suit = null
	H.sleeping = 4
	hair_tie_check(!H.toggle_hair_tie(), "a sleeping character cannot toggle the tie")
	H.sleeping = 0
	H.r_hair = 96
	hair_tie_check(H.toggle_hair_tie() && H.hair_tied_back && H.h_style == "Shoulder-length Hair" && H.h_growth == 3 && H.r_hair == 96, "tying back only changes the physical tie")
	hair_tie_check(H.hair_dusty_work_delay(120) == 120 && abs(H.drying_rate(20) - 0.01) < 0.00001, "tying restores normal work and drying")
	hair_tie_check("hair_tied_back" in H.get_saved_vars(), "character snapshot selects the tie")
	var/payload = H.region_travel_payload(list())
	var/list/P = json_decode(payload)
	hair_tie_check(P["hair_tied_back"] == 1 && !("hair_tied_back" in P["look"]), "travel emits an optional top-level field")
	var/list/decoded = region_travel_decode(payload)
	hair_tie_check(islist(decoded) && decoded["hair_tied_back"] == 1, "the tie survives the travel wire format")
	if (decoded)
		var/mob/living/human/arrival = region_travel_build(decoded, T)
		hair_tie_check(arrival.hair_tied_back && arrival.hair_dusty_work_delay(120) == 120, "region arrival restores the tied state")
		decoded["hair_tied_back"] = "1"
		var/list/fallback = region_travel_decode(json_encode(decoded))
		var/mob/living/human/loose = fallback ? region_travel_build(fallback, T) : null
		hair_tie_check(loose && !loose.hair_tied_back && loose.hair_dusty_work_delay(120) == 126, "invalid optional data arrives loose without blocking travel")
	hair_tie_check(H.toggle_hair_tie() && !H.hair_tied_back, "letting hair down reverses the tie")
	var/list/untied = json_decode(H.region_travel_payload(list()))
	hair_tie_check(!("hair_tied_back" in untied), "loose hair does not need an optional field")
	var/obj/structure/brazier/B = new(T)
	B.on = TRUE
	H.life_heat_scan_until = 0
	hair_tie_check(abs(H.drying_rate(20) - 0.03) < 0.00001, "lit fire dries loose hair at the unchanged rate")
	B.on = FALSE
	H.life_heat_scan_until = 0
	map.civilizations = FALSE
	hair_tie_check(H.hair_dusty_work_delay(120) == 120 && abs(H.drying_rate(20) - 0.01) < 0.00001, "non-civilization rules have no hair penalties")
