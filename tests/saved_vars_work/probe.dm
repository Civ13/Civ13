#define FALSE 0
#define TRUE 1
var/probe_name_unions = 0
var/list/results = list()
var/list/counts = list()
var/list/samples = list()
var/failures = 0
var/work_failures = 0
var/cases = 0

/datum
	var/name = "fixture"
	var/map_storage_saved_vars = "name;dir"
	var/persistence_export_frame
	var/value = 1
	var/second = 2
	var/list/payload
/obj/item
/obj/structure/wild
/obj/map_metadata
/obj/covers
/turf/floor/dirt
	var/soil_nutrition = 80
	map_storage_saved_vars = "icon_state;name"
/datum/fixture
	var/tmp/hook_mode = 0
	var/tmp/hook_calls = 0
	var/tmp/list/hook_order = list()
	var/tmp/runtime_secret = "not durable"
/datum/fixture/persistence_runtime_var(key)
	hook_calls++
	hook_order += key
	if(hook_mode == 1) return TRUE
	if(hook_mode == 2 && key != "second") return TRUE
	if(hook_mode == 3 && key == "type") second = 123
	return (key in list("hook_mode", "hook_calls", "hook_order", "runtime_secret")) || ..()
/obj/item/fixture
	var/a01 = 0
	var/a02 = 0
	var/a03 = 0
	var/a04 = 0
	var/a05 = 0
	var/a06 = 0
	var/a07 = 0
	var/a08 = 0
	var/a09 = 0
	var/a10 = 0
	var/a11 = 0
	var/a12 = 0
	var/a13 = 0
	var/a14 = 0
	var/a15 = 0
	var/a16 = 0

/world
	maxx = 4
	maxy = 4
	maxz = 1
	tick_lag = 1
/world/OpenPort(port)
	if(port == "none") return ..()
	return FALSE
/world/New()
	..()
	OpenPort("none")
	spawn(1) run_probe()

/proc/capture(datum/D, candidate, counted = FALSE)
	var/list/keys
	if(counted)
		keys = candidate ? D.candidate_counted() : D.baseline_counted()
	else
		keys = candidate ? D.candidate_saved() : D.baseline_saved()
	var/list/values = list()
	for(var/key in keys)
		// Only compare values for valid vars; empty/custom allowlists are also checked.
		var/value = (key in D.vars) ? D.vars[key] : null
		if(istype(value, /matrix))
			var/matrix/M = value
			value = list(M.a, M.b, M.c, M.d, M.e, M.f)
		else if(islist(value) || istype(value, /datum)) value = "ref:\ref[value]"
		values += json_encode(list(key, value, keys[key]))
	return json_encode(values)

/proc/check(datum/D, label)
	cases++
	var/old = capture(D, FALSE)
	var/current = capture(D, TRUE)
	if(old != current)
		failures++
		if(results.len < 8) results += list(list("case"=label, "old"=old, "new"=current))
	probe_name_unions = 0
	D.baseline_counted()
	var/old_count = probe_name_unions
	probe_name_unions = 0
	D.candidate_counted()
	var/new_count = probe_name_unions
	if(new_count != min(old_count, 1)) work_failures++
	if(counts.len < 12) counts += list(list("case"=label, "baseline"=old_count, "candidate"=new_count))

/proc/timed(datum/D, candidate)
	var/start = world.timeofday
	for(var/i = 1 to 1000)
		if(candidate) D.candidate_saved()
		else D.baseline_saved()
	return (world.timeofday - start + 864000) % 864000

/proc/run_probe()
	var/list/types = list(/datum, /obj/item/fixture, /obj/structure, /obj/structure/wild, /obj/map_metadata, /obj/covers, /obj, /mob, /turf/floor/dirt)
	for(var/path in types)
		var/datum/D
		if(ispath(path, /turf)) D = new path(locate(2,2,1))
		else D = new path
		check(D, "[path]-initial")
		D.name = "changed name"
		D.value = 7
		D.payload = list("ordered", "ordered", "x"=5)
		D.payload += list(D.payload) // alias/cycle value remains the same reference
		check(D, "[path]-changed")
		for(var/text in list("", "name", "second;name;value", "value=one;second=two", "name;name;value"))
			D.map_storage_saved_vars = text
			check(D, "[path]-[text]")
			var/list/first = D.candidate_saved()
			first += "poison"
			if("poison" in D.candidate_saved()) failures++
		D.payload = null
		if(!isturf(D)) del(D)
	// Hook order, all-excluded behavior and mutations are tested with fresh twins.
	for(var/mode = 0 to 3)
		for(var/changed = 0 to 1)
			var/datum/fixture/A = new
			var/datum/fixture/B = new
			A.hook_mode = mode
			B.hook_mode = mode
			A.value = changed ? 22 : 1
			B.value = A.value
			if(mode == 2)
				A.second = 3
				B.second = 3
			var/list/ka = A.baseline_saved()
			var/list/kb = B.candidate_saved()
			cases++
			if(json_encode(ka) != json_encode(kb) || json_encode(A.hook_order) != json_encode(B.hook_order) || A.second != B.second) failures++
			del(A)
			del(B)
#ifdef BENCHMARK
	for(var/path in list(/datum, /obj/item/fixture, /mob))
		var/datum/D = new path
		D.value = 7
		for(var/i = 1 to 200)
			D.baseline_saved()
			D.candidate_saved()
		for(var/group = 1 to 5)
			for(var/order = 0 to 1)
				var/candidate = (group + order) % 2
				var/elapsed = timed(D, candidate)
				samples += list(list("type"="[path]", "group"=group, "candidate"=candidate, "calls"=1000, "elapsed_ds"=elapsed))
				sleep(1)
		del(D)
#endif
	text2file(json_encode(list("cases"=cases, "failures"=failures, "work_failures"=work_failures, "counts"=counts, "samples"=samples, "failure_samples"=results)), "result.json")
	del(world)
