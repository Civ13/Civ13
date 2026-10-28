// Test-only control extension. Never include in a production entrypoint.
var/global/representative_phase = "idle"
var/global/representative_error
var/global/list/representative_receipt
var/global/representative_heartbeat = 0

/obj/structure/closet/crate
	var/representative_marker = 0

/hook/startup/proc/representative_heartbeat_start()
	spawn(0)
		while(TRUE)
			sleep(world.tick_lag)
			representative_heartbeat++
	return TRUE

/proc/representative_crate()
	if(!fexists("full-map-fixture.json")) return null
	var/list/F = json_decode(file2text("full-map-fixture.json"))
	var/turf/T = locate(F["x"], F["y"], F["z"])
	var/obj/structure/closet/crate/found
	for(var/obj/structure/closet/crate/C in T)
		if(C.name == F["crate"])
			if(found) throw EXCEPTION("Duplicate representative crate")
			found = C
	return found

/proc/full_map_probe_status()
	var/list/S = representative_base_status()
	var/obj/structure/closet/crate/C = representative_crate()
	S["representative"] = list("phase" = representative_phase, "error" = representative_error, "heartbeat" = representative_heartbeat, "marker" = C ? C.representative_marker : null, "receipt" = representative_receipt)
	var/list/boundaries = list()
	for(var/level = 1, level <= world.maxz, level++)
		var/turf/first = locate(1,1,level)
		var/turf/last = locate(world.maxx,world.maxy,level)
		boundaries["[level]"] = list("first" = first ? "[first.type]" : null, "last" = last ? "[last.type]" : null)
	S["representative_boundaries"] = boundaries
	return S

/proc/representative_save_action(action)
	if(!full_map_probe_ready()) return "rejected"
	if(action == "census")
		if(representative_phase != "idle") return "rejected"
		representative_phase = "census_pending"
		spawn(0)
			try
				var/list/counts = list()
				var/total = 0
				for(var/atom/movable/A in world)
					var/key = "[A.type]"
					var/previous = counts[key]
					counts[key] = isnum(previous) ? previous + 1 : 1
					total++
					if(total % 1024 == 0) sleep(world.tick_lag)
				if(fexists("representative-census.json") || !text2file(json_encode(list("source" = world.params["tested_commit"], "session" = full_map_probe_session, "counts" = counts, "total" = total, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz)), "representative-census.json")) throw EXCEPTION("Census output failed")
				representative_phase = "census_complete"
			catch(var/exception/E)
				representative_error = E.name
				representative_phase = "failed"
		return json_encode(full_map_probe_status())
	if((action == "first" && representative_phase != "idle" && representative_phase != "census_complete") || (action == "second" && representative_phase != "first_complete")) return "rejected"
	var/obj/structure/closet/crate/C = representative_crate()
	if(!C) return "rejected"
	// The executor must retain the imported seed outside this new empty output.
	if(action == "first" && fexists("map_saves/save_complete.txt")) return "rejected"
	representative_phase = "[action]_pending"
	spawn(0)
		try
			C.representative_marker = action == "first" ? (world.params["representative_role"] == "seed" ? 0 : 1) : 2
			if(!ticker.savemap()) throw EXCEPTION("Representative production save refused")
			var/list/I = persistence_restart.current_identity()
			// Identity and complete-file hashes come from actual production readers.
			representative_receipt = list("identity" = I, "marker" = C.representative_marker, "session" = full_map_probe_session)
			representative_phase = "[action]_complete"
		catch(var/exception/E)
			representative_error = E.name
			representative_phase = "failed"
	return json_encode(full_map_probe_status())
