var/list/area_list = list()
var/parity_failures = 0
var/bound_failures = 0
var/comparisons = 0
var/baseline_slots = 0
var/candidate_slots = 0
var/replacements = 0
/area/forest
/area/forest/jungle
/area/desert
/turf/other
/turf/dirt
/turf/dirt/winter
/turf/dirt/jungle
/obj/inert
/mob/inert
/proc/even_column(turf/T)
	return !(T.x % 2)
/proc/selected(list/input, type)
	var/list/result = list()
	for(var/turf/T in input)
		if(istype(T, type)) result += T
	return result
/proc/compare(list/a, list/b)
	comparisons++
	if(a.len != b.len)
		parity_failures++
		return
	for(var/i in 1 to a.len)
		if(a[i] != b[i]) parity_failures++
/proc/check_selection(area_type, turf_type, list/predicates)
	var/list/original = baseline_area_turfs(area_type, predicates)
	var/list/expected = selected(original, turf_type)
	var/list/actual = get_area_turfs(area_type, predicates, turf_type)
	compare(expected, selected(actual, turf_type))
	if(actual.len != expected.len) bound_failures++
	baseline_slots += original.len
	candidate_slots += actual.len
	return actual
/world
	maxx = WIDTH
	maxy = HEIGHT
	maxz = 1
	turf = /turf/other
/world/OpenPort(port)
	if(port == "none")
		return ..()
	return FALSE
/world/Error(exception/E)
	world.log << "runtime error: [E]"
	return ..()
/world/New()
	..()
	world.OpenPort("none")
	if(world.port)
		world.log << "PORT_OPEN"
		del(world)
		return
	var/area/forest/F = new
	var/area/forest/jungle/J = new
	var/area/desert/D = new
	area_list = list(J, D, F)
	for(var/turf/T in world)
		var/area/target_area = T.x % 3 ? F : (T.x % 2 ? J : D)
		target_area.contents += T
		if(!((T.x + T.y) % 8))
			if(T.x % 2) new /turf/dirt/jungle(T)
			else new /turf/dirt/winter(T)
	var/list/owned = list()
	var/list/locations = list()
	for(var/i in 1 to 20000)
		var/obj/inert/O = new(locate(1 + i % WIDTH, 1 + i % HEIGHT, 1))
		owned += O
		locations += O.loc
	for(var/i in 1 to 80)
		var/mob/inert/M = new(locate(1 + i % WIDTH, 1 + i % HEIGHT, 1))
		owned += M
		locations += M.loc
	compare(baseline_area_turfs(/area/forest), get_area_turfs(/area/forest))
	compare(baseline_area_turfs("/area/forest"), get_area_turfs("/area/forest"))
	compare(baseline_area_turfs(F), get_area_turfs(F))
	for(var/cycle in 1 to 16)
		var/list/chosen = check_selection(/area/forest, /turf/dirt)
		check_selection(/area/forest/jungle, /turf/dirt/jungle)
		check_selection(F, /turf/dirt/winter)
		check_selection("/area/forest", /turf/dirt, list(/proc/even_column))
		var/list/old_snapshot = baseline_area_turfs(/area/forest)
		var/changed = 0
		for(var/turf/dirt/T in chosen)
			if(changed >= 256) break
			changed++
			replacements++
			if(cycle % 2) new /turf/dirt/jungle(T)
			else new /turf/dirt/winter(T)
		compare(selected(old_snapshot, /turf/dirt), selected(baseline_area_turfs(/area/forest), /turf/dirt))
	for(var/i in 1 to owned.len)
		var/atom/movable/A = owned[i]
		comparisons++
		if(!A || A.loc != locations[i]) parity_failures++
	var/list/samples = list()
	for(var/mode in list("sparse", "dominant", "unfiltered"))
		for(var/pair in 1 to 4)
			for(var/order in 1 to 2)
				var/candidate = pair % 2 ? order == 2 : order == 1
				sleep(1)
				var/start = world.timeofday
				var/slots = 0
				var/peak_slots = 0
				var/visits = 0
				for(var/call_index in 1 to 4)
					var/type = mode == "sparse" ? /turf/dirt : /turf/other
					var/list/work = candidate ? get_area_turfs(/area/forest, null, mode == "unfiltered" ? null : type) : baseline_area_turfs(/area/forest)
					slots += work.len
					peak_slots = max(peak_slots, work.len)
					if(mode == "sparse")
						for(var/turf/dirt/T in work)
							visits++
					else
						for(var/turf/other/T in work)
							visits++
				samples += list(list("mode"=mode, "pair"=pair, "candidate"=candidate, "calls"=4, "slots"=slots, "peak_slots"=peak_slots, "visits"=visits, "elapsed_ds"=world.timeofday-start))
	text2file(json_encode(list("cycles"=16, "replacements"=replacements, "distractors"=owned.len, "comparisons"=comparisons, "parity_failures"=parity_failures, "bound_failures"=bound_failures, "baseline_slots"=baseline_slots, "candidate_slots"=candidate_slots, "samples"=samples)), "result.json")
	del(world)
