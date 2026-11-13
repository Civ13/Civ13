// Dream Seeker probe: client cost of many idle animals while the player walks.
// Manual tool, never compiled by CI (see README.md). Included at the end of a
// copy of civ13.dme so it can wrap game procs.
var/global/datum/animal_fps_probe/animal_fps_probe = new

/datum/animal_fps_probe
	var/list/marks = list()
	var/started_tod = 0
	var/client/C
	var/mob/living/human/H
	var/turf/centre
	var/list/animals = list()
	var/list/props = list()
	// Per-phase counters, filled by the wrappers below.
	var/los_refreshes = 0
	var/los_refresh_ds = 0
	var/los_target_refreshes = 0
	var/image_adds = 0
	var/image_removes = 0

/datum/animal_fps_probe/New()
	started_tod = world.timeofday
	spawn(10)
		drive()

/datum/animal_fps_probe/proc/mark(name)
	var/row = list("phase" = name, "wall_s" = (world.timeofday - started_tod) / 10, "realtime" = world.realtime)
	marks += list(row)
	world.log << "FPSPROBE [name]"
	fdel("probe-marks.json")
	text2file(json_encode(marks), "probe-marks.json")

/datum/animal_fps_probe/proc/set_phase(label)
	fdel("probe-phase.txt")
	text2file(label, "probe-phase.txt")

/datum/animal_fps_probe/proc/open_turf(turf/T)
	if(!istype(T, /turf/floor/grass) || T.density || !ecology_outdoor_climate(T))
		return FALSE
	for(var/atom/movable/A in T)
		if(A.density || A.opacity)
			return FALSE
	return TRUE

/datum/animal_fps_probe/proc/find_centre()
	for(var/tries in 1 to 400000)
		var/turf/T = locate(rand(30, world.maxx - 30), rand(30, world.maxy - 30), rand(1, world.maxz))
		if(!open_turf(T))
			continue
		var/good = 0
		for(var/turf/U in range(8, T))
			if(open_turf(U))
				good++
		// A clear field: at least 85% open grass in a 17x17 square.
		if(good >= 245)
			return T
	return null

/datum/animal_fps_probe/proc/walk_phase(label, seconds, walking = TRUE)
	set_phase(label)
	los_refreshes = 0
	los_refresh_ds = 0
	los_target_refreshes = 0
	image_adds = 0
	image_removes = 0
	world.Profile(PROFILE_CLEAR)
	world.Profile(PROFILE_START)
	var/cpu = 0
	var/map_cpu = 0
	var/samples = 0
	var/max_images = 0
	var/steps = 0
	var/dir = EAST
	var/until = world.time + seconds * 10
	var/next_turn = world.time + 40
	if(walking)
		H.forceMove(centre)
		C.startmovingright()
	while(world.time < until)
		sleep(2)
		cpu += world.cpu
		map_cpu += world.map_cpu
		samples++
		max_images = max(max_images, C.images.len)
		if(walking && world.time >= next_turn)
			next_turn = world.time + 40
			steps++
			if(dir == EAST)
				C.stopmovingright()
				dir = WEST
				C.startmovingleft()
			else
				C.stopmovingleft()
				dir = EAST
				C.startmovingright()
	if(walking)
		C.stopmovingright()
		C.stopmovingleft()
	world.Profile(PROFILE_STOP)
	fdel("profile-[label].json")
	text2file(world.Profile(PROFILE_REFRESH, null, "json"), "profile-[label].json")
	mark("[label]: animals=[animals.len] props=[props.len] avg_cpu=[round(cpu / samples, 0.1)] avg_map_cpu=[round(map_cpu / samples, 0.1)] los_refresh=[los_refreshes] los_refresh_ms=[los_refresh_ds * 100] los_targets=[los_target_refreshes] image_adds=[image_adds] image_removes=[image_removes] max_images=[max_images] turns=[steps] at=[H.x],[H.y]")
	set_phase("idle")
	sleep(30)

/datum/animal_fps_probe/proc/spawn_animals(count, anchor)
	var/list/types = list(/mob/living/simple_animal/cattle/cow, /mob/living/simple_animal/sheep, /mob/living/simple_animal/goat, /mob/living/simple_animal/deer/male, /mob/living/simple_animal/deer/female, /mob/living/simple_animal/pig_gilt, /mob/living/simple_animal/rabbit, /mob/living/simple_animal/horse)
	var/list/spots = list()
	for(var/turf/U in range(9, centre))
		if(abs(U.y - centre.y) > 1 && open_turf(U))
			spots += U
	for(var/i in 1 to min(count, spots.len))
		var/turf/U = pick_n_take(spots)
		var/T = pick(types)
		var/mob/living/simple_animal/A = new T(U)
		if(anchor)
			A.anchored = TRUE
			A.wander = FALSE
			A.stop_automated_movement = TRUE
		animals += A

/datum/animal_fps_probe/proc/clear_animals()
	for(var/mob/living/simple_animal/A in animals)
		qdel(A)
	animals.Cut()

// Same icons as plain objects, to tell mob cost from icon cost.
/datum/animal_fps_probe/proc/spawn_props(count)
	var/list/types = list(/mob/living/simple_animal/cattle/cow, /mob/living/simple_animal/sheep, /mob/living/simple_animal/goat, /mob/living/simple_animal/deer/male, /mob/living/simple_animal/deer/female, /mob/living/simple_animal/pig_gilt, /mob/living/simple_animal/rabbit, /mob/living/simple_animal/horse)
	var/list/spots = list()
	for(var/turf/U in range(9, centre))
		if(abs(U.y - centre.y) > 1 && open_turf(U))
			spots += U
	for(var/i in 1 to min(count, spots.len))
		var/turf/U = pick_n_take(spots)
		var/mob/living/simple_animal/T = pick(types)
		var/obj/effect/O = new /obj/effect(U)
		O.icon = initial(T.icon)
		O.icon_state = initial(T.icon_state)
		O.layer = MOB_LAYER
		O.mouse_opacity = 1
		props += O

/datum/animal_fps_probe/proc/drive()
	while(!(ticker && ticker.current_state == GAME_STATE_PLAYING))
		if(ticker && ticker.current_state == GAME_STATE_PREGAME)
			ticker.pregame_timeleft = 1
			ticker.admin_started = TRUE
			round_progressing = TRUE
		sleep(10)
	mark("playing")
	set_phase("waiting for client")
	while(!clients.len)
		sleep(10)
	C = clients[1]
	mark("client [C.ckey]")
	sleep(100)
	centre = find_centre()
	if(!centre)
		mark("no clear field found")
		return
	H = new /mob/living/human(centre)
	H.ckey = C.ckey
	sleep(50)
	C = H.client
	mark("field [centre.x],[centre.y],[centre.z] view=[C.view] fps=[C.fps]")
	sleep(100)
	walk_phase("walk-none", 20)
	spawn_animals(80, TRUE)
	sleep(50)
	walk_phase("walk-80-still", 20)
	walk_phase("stand-80-still", 20, FALSE)
	clear_animals()
	spawn_props(80)
	sleep(50)
	walk_phase("walk-80-props", 20)
	for(var/obj/O in props)
		qdel(O)
	props.Cut()
	spawn_animals(80, FALSE)
	sleep(50)
	walk_phase("walk-80-free", 20)
	clear_animals()
	sleep(30)
	walk_phase("walk-none-again", 20)
	set_phase("done")
	mark("done")

/datum/los_presenter/refresh(datum/los_snapshot/S)
	var/t = world.tick_usage
	. = ..()
	animal_fps_probe.los_refreshes++
	animal_fps_probe.los_refresh_ds += (world.tick_usage - t) * world.tick_lag / 100

/datum/los_presenter/refresh_targets(datum/los_snapshot/S, list/targets)
	. = ..()
	animal_fps_probe.los_target_refreshes++
