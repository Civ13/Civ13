// Mouse nest probe: settle growth, starving, the step clamp, the registry,
// emitted mice and the wild burrow target. Run with:
//   python3 tests/ecology_spawning/run_linux.py . tests/mouse_nests/probe.dm
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
/obj/map_metadata/mouse_probe/New()
	return
var/mouse_failures = 0
var/mouse_runtime_error = FALSE
/proc/mouse_check(condition, label)
	if (!condition)
		mouse_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	mouse_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/mouse_probe
		var/area/A = get_area(locate(1, 1, 1))
		A.location = AREA_OUTSIDE
		A.climate = "temperate"
		for (var/turf/T in block(locate(1, 1, 1), locate(20, 20, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		season = SEASON_SUMMER
		mouse_settle_checks()
		mouse_mob_checks()
		mouse_burrow_target_checks()
	catch(var/exception/e)
		mouse_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = mouse_failures, "runtime_error" = mouse_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/mouse_minutes_ago(minutes)
	return trap_minutes_text(trap_now_minutes() - minutes)

/proc/mouse_settle_checks()
	var/now = trap_now_minutes()
	var/obj/structure/mouse_nest/burrow/B = new(locate(5, 5, 1))
	mouse_check(B in mouse_nest_list, "a new burrow registers itself")
	mouse_check(B.icon_state == "burrow", "a burrow uses the burrow sprite")
	B.population = 0
	B.last_settle = mouse_minutes_ago(15)
	mouse_check(B.settle(now) == 3, "15 minutes settle three 5-minute steps")
	mouse_check(B.population == 2, "a burrow regrows to its floor of 2 and holds there without food (got [B.population])")
	mouse_check(B.settle(now) == 0, "a fresh settle applies nothing")

	B.last_settle = mouse_minutes_ago(100000)
	mouse_check(B.settle(now) == 12, "a long gap is clamped to 12 steps")

	season = SEASON_WINTER
	B.population = 0
	B.last_settle = mouse_minutes_ago(10)
	B.settle(now)
	mouse_check(B.population == 0, "an outdoor burrow does not breed in winter")
	season = SEASON_SUMMER

	var/obj/structure/mouse_nest/H = new(locate(10, 10, 1))
	H.population = 2
	H.last_settle = mouse_minutes_ago(5)
	H.settle(now)
	mouse_check(!QDELETED(H) && H.population == 1, "a house nest with no food loses a mouse each step")
	H.last_settle = mouse_minutes_ago(5)
	H.settle(now)
	mouse_check(QDELETED(H), "a starved house nest disappears")
	mouse_check(!(H in mouse_nest_list), "a deleted nest leaves the registry")

	var/obj/structure/mouse_nest/S = new(locate(12, 12, 1))
	S.population = 2
	S.update_icon()
	mouse_check(S.icon_state == "nest_light", "a small house nest looks light")
	S.population = 5
	S.update_icon()
	mouse_check(S.icon_state == "nest_used", "a middling house nest looks used")
	S.population = 8
	S.update_icon()
	mouse_check(S.icon_state == "nest_overrun", "a full house nest looks overrun")
	S.last_settle = mouse_minutes_ago(500)
	S.after_load()
	mouse_check(trap_minutes(S.last_settle) >= now, "loading restarts the settle clock")
	mouse_check(S.persistence_runtime_var("out_mice"), "out mice are never saved with the nest")
	qdel(S)
	qdel(B)

/proc/mouse_mob_checks()
	var/obj/structure/mouse_nest/N = new(locate(8, 8, 1))
	N.population = 4
	var/mob/living/simple_animal/mouse/M = new(locate(9, 8, 1))
	M.set_home(N)
	mouse_check(M in N.out_mice, "an emitted mouse is tracked by its nest")
	mouse_check(!M.should_save, "an emitted mouse is not saved")
	mouse_check(M in mouse_out_list, "an emitted mouse counts toward the world cap")
	N.mouse_returned(M)
	mouse_check(N.population == 4 && !(M in N.out_mice), "a mouse going home keeps the population")
	mouse_check(QDELETED(M) && !(M in mouse_out_list), "a mouse going home leaves the map")

	var/mob/living/simple_animal/mouse/K = new(locate(9, 8, 1))
	K.set_home(N)
	K.death()
	mouse_check(N.population == 3, "a killed mouse is one fewer in its nest")
	mouse_check(!(K in mouse_out_list), "a dead mouse leaves the out list")

	var/mob/living/simple_animal/mouse/L = new(locate(9, 8, 1))
	L.set_home(N)
	qdel(N)
	mouse_check(isnull(L.home) && L.stray, "digging out a nest strays the mice outside it")
	qdel(L)

	var/area/A = get_area(locate(1, 1, 1))
	time_of_day = "Midday"
	mouse_check(!mouse_active_time(locate(3, 3, 1)), "outdoor mice stay in at midday")
	time_of_day = "Night"
	mouse_check(mouse_active_time(locate(3, 3, 1)), "outdoor mice come out at night")
	time_of_day = "Midday"
	A.location = AREA_INSIDE
	mouse_check(mouse_active_time(locate(3, 3, 1)), "indoor mice keep their own hours")
	A.location = AREA_OUTSIDE

	var/mob/living/simple_animal/mouse/T = new(locate(4, 4, 1))
	mouse_check(T.behaviour == "scared" && T.melee_damage_upper == 0, "mice are timid")
	qdel(T)

/proc/mouse_burrow_target_checks()
	var/datum/ecology_spawner/E = new
	E.habitat_hits = list("temperate|[ECO_GRASS]" = 600)
	var/datum/ecology_species/S = E.mouse_burrow_species()
	mouse_check(S.target == 1, "6,400 habitat tiles hold one burrow (got [S.target])")
	E.habitat_hits = list("temperate|[ECO_GRASS]" = 30000)
	S = E.mouse_burrow_species()
	mouse_check(S.target == 30, "a huge land is capped at 30 burrows (got [S.target])")
	E.habitat_hits = list("desert|[ECO_SAND]" = 30000)
	S = E.mouse_burrow_species()
	mouse_check(S.target == 0, "deserts hold no burrows")
