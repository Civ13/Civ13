#define TRUE 1
#define FALSE 0
var/failures = 0
var/cases = 0
var/list/details = list()
var/list/samples = list()
var/list/parent_trace = list()
var/mutate_parent = FALSE
var/list/network_receipt = list()
/datum
	var/name = "fixture"
	var/map_storage_saved_vars = "name;dir"
	var/persistence_export_frame
	var/value = 1
	var/list/payload
/obj/item
/obj/structure/wild
/obj/map_metadata
/obj/covers
/mob/living/human
/turf/floor/dirt
	var/soil_nutrition = 80
	map_storage_saved_vars = "icon_state;name"
/client/New()
	del(src)
	return
/world/Topic()
	return null
/world
	hub = ""
	visibility = 0
	maxx = 4
	maxy = 4
	maxz = 1
	tick_lag = 1
/world/OpenPort(port)
	if(port == "none") return ..()
	return FALSE
/world/New()
	..()
	network_receipt["preclose_address"] = address
	network_receipt["preclose_port"] = port
	network_receipt["close_result"] = OpenPort("none")
	network_receipt["closed_port"] = port
	network_receipt["reopen_result"] = OpenPort(0)
	network_receipt["after_reopen_port"] = port
	if(network_receipt["closed_port"] != 0 || network_receipt["reopen_result"] != FALSE || port != 0)
		text2file(json_encode(network_receipt),"network-failure.json")
		world.log << "BUG: fixture network contract failed"
		del(world)
		return
	spawn(1) run_probe()
/proc/assert_equal(a, b, label)
	cases++
	if(a != b)
		failures++
		if(details.len < 12) details += list(list("label"=label, "baseline"=a, "candidate"=b))
/proc/capture(datum/D, candidate)
	var/list/keys = candidate ? D.candidate_saved() : D.baseline_saved()
	var/list/rows = list()
	for(var/key in keys)
		var/value = (key in D.vars) ? D.vars[key] : null
		if(istype(value, /matrix))
			var/matrix/M = value
			value = list(M.a,M.b,M.c,M.d,M.e,M.f)
		else if(islist(value) || istype(value, /datum)) value = "ref:\ref[value]"
		rows += json_encode(list(key,value,keys[key]))
	return json_encode(rows)
/proc/timed(datum/D, candidate)
	var/start = world.timeofday
	for(var/i = 1 to BENCH_CALLS)
		if(candidate) D.candidate_saved()
		else D.baseline_saved()
	return (world.timeofday - start + 864000) % 864000
/proc/run_probe()
	var/list/keys = list("lighting_reserved","lighting_reserved_clearance_enabled","appearance","light","light_sources","affecting_lights","lighting_overlay","corners","has_opaque_atom","window_coeff_dirty","next_calculate_window_coeff","hud_used","HUDneed","HUDinventory","HUDfrippery","HUDprocess","HUDtech","hands","pullin","purged","i_select","m_select","zone_sel","persistence_export_frame","next_click","next_move","may_do_after","may_do_mob","blackout_click_owner","blackout_click_client_ref","blackout_click_counts","blackout_click_started","blackout_click_expires","weak_reference","pickaxe_mining_owner","mining_in_progress","pickaxe_mining_action","next_animal_retaliation","original_target","snowfall_ground_index","snowfall_ground_generation","weather_snow_overlay","persistence_zone_id","corpse_decay_record","abandonment_index","exercise_equipment","name","Appearance","hudneed","",0,1,2.5,null,/obj,list("appearance"),new/datum)
	for(var/path in list(/datum,/atom/movable,/obj,/obj/item,/mob,/mob/living/human,/area,/turf/floor/dirt))
		var/datum/D = ispath(path,/turf) ? new path(locate(2,2,1)) : new path
		for(var/i = 1 to keys.len)
			var/key = keys[i]
			assert_equal(D.baseline_runtime(key),D.candidate_runtime(key),"[path] key [i]")
			for(var/mutate = 0 to 1)
				mutate_parent = mutate
				parent_trace = list()
				D.value = 1
				var/a = D.baseline_traced(key)
				var/old = json_encode(list(a,parent_trace,D.value))
				parent_trace = list()
				D.value = 1
				var/b = D.candidate_traced(key)
				assert_equal(old,json_encode(list(b,parent_trace,D.value)),"[path] trace [i] mutate [mutate]")
		mutate_parent = FALSE
		if(isturf(D))
			assert_equal(D.candidate_runtime("lighting_reserved"),TRUE,"new turf reserved policy")
		if(isarea(D))
			assert_equal(D.candidate_runtime("lighting_reserved_clearance_enabled"),TRUE,"new area clearance policy")
		for(var/text in list("name;dir","name;name;dir","name=x;dir=y","name%3Bdir;name","","light;appearance;name"))
			D.map_storage_saved_vars = text
			D.name = "changed"
			D.value = 7
			D.payload = list("x","x","a"=D)
			assert_equal(capture(D,FALSE),capture(D,TRUE),"[path] saved [text]")
			var/list/returned = D.candidate_saved()
			returned += "poison"
			assert_equal("poison" in D.candidate_saved(),FALSE,"returned list isolation")
		D.payload = null
		if(!isturf(D)) del(D)
#ifdef BENCHMARK
	for(var/path in list(/obj/item,/mob,/mob/living/human))
		var/datum/D = new path
		D.value = 7
		for(var/i = 1 to 200)
			D.baseline_saved()
			D.candidate_saved()
		for(var/group = 1 to 5)
			for(var/order = 0 to 1)
				var/candidate = (group + order) % 2
				var/elapsed = timed(D,candidate)
				samples += list(list("type"="[path]","group"=group,"candidate"=candidate,"calls"=BENCH_CALLS,"elapsed_ds"=elapsed))
				sleep(1)
		del(D)
#endif
	text2file(json_encode(list("cases"=cases,"failures"=failures,"details"=details,"samples"=samples,"network"=network_receipt)),"result.json")
	del(world)
