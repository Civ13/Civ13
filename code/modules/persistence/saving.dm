// Saves all of the turfs and objects within turfs to their own directories withn
// the specifeid savefile name. If objects or turfs have variables to keep track
// of, it will check to see if those variables have been modified and record the
// new values of any modified variables along with the object. It uses an object
// reference, which records each object type as a position in a list so that it
// can be references using a number instead of a fully written out type class.
// You can also specify a name and password for the map, along with any extra
// variables (in params format) that you want saved along with the map file.
// Yield before consuming most of the game tick, including inside dense graphs.
// Native savefile writes, list copies and fcopy calls remain nonpreemptible.
/map_storage/proc/save_work_check()
	saving_work++
	if(saving_work >= 1024 || world.tick_usage-saving_slice_start >= 20 || world.tick_usage >= 80)
		saving_work = 0
		sleep(world.tick_lag)
		saving_slice_start = world.tick_usage

/map_storage/proc/Save_World()
	clear_bookkeeping()
	// ***** MAP SECTION *****
	var/backup_dir = "map_backups/"
	// Back up the whole previous completed generation before overwriting any
	// level. A per-level rolling backup mixed old and new levels after failures.
	if(fexists("map_saves/save_complete.txt"))
		if(fexists("map_backups/save_complete.txt"))
			if(!fdel("map_backups/save_complete.txt"))
				throw EXCEPTION("Could not invalidate backup marker; existing save retained")
		for(var/name in flist("map_saves/"))
			save_work_check()
			if(name == "map.txt" || copytext(name, max(1, length(name)-3)) == ".sav")
				if(!fcopy("map_saves/[name]", "[backup_dir][name]"))
					throw EXCEPTION("Could not back up [name]; existing save retained")
		sleep(world.tick_lag)
		if(!fcopy("map_saves/save_complete.txt", "[backup_dir]save_complete.txt"))
			throw EXCEPTION("Could not mark completed backup; existing save retained")
	// Remove the completion marker first: if this save dies partway through, the
	// marker's absence tells the startup autoload not to trust map_saves/.
	if (fexists("map_saves/save_complete.txt"))
		if(!fdel("map_saves/save_complete.txt"))
			throw EXCEPTION("Could not invalidate completion marker; existing save retained")
	var/F0 = file("map_saves/map.txt")
	if (fexists(F0))
		if(!fdel(F0))
			throw EXCEPTION("Could not replace save metadata")
	var/list/metadata = list(map.ID, "[map.age]", "[map.ordinal_age]", "[map.default_research]", "[map.autoresearch]", "[map.autoresearch_mult]", "[map.chad_mode]", "[map.chad_mode_plus]", "[map.gamemode]", time2text(world.realtime,"YYYY-MM-DD-(hh-mm-ss)"))
	if(!text2file(jointext(metadata, "\n"), F0))
		throw EXCEPTION("Could not write world-save metadata")
	log_startup_progress("	Saved metadata.")
	for(var/A = 1, A <= world.maxz, A++)
		saving_z = A
		saving_grid_refs = list()
		saving_owners = list()
		saving_content_flags = list()
		saving_lists = list()
		saving_reference_pins = list()
		saving_list_pins = list()
		saving_references = list()
		existing_references = list()
		found_types = list()
		if(fexists("map_saves/[A].sav"))
			if(!fdel("map_saves/[A].sav"))
				throw EXCEPTION("Could not replace saved level [A]")
		var/savefile/savefile = new("map_saves/[A].sav")
		savefile["/format_version"] << 2
		savefile["/maxx"] << world.maxx
		savefile["/maxy"] << world.maxy
		savefile["/maxz"] << world.maxz
		// Visit only this level instead of rescanning the entire world for each z.
		for(var/y = 1, y <= world.maxy, y++)
			for(var/x = 1, x <= world.maxx, x++)
				var/turf/T = locate(x, y, A)
				var/ref = BuildVarDirectory(savefile, T, 1, TRUE)
				if(!ref)
					throw EXCEPTION("Turf [x],[y],[A] could not be saved")
				savefile["/map/[A]/[y]/[x]"] << ref
				save_work_check()
		// Each movable belongs to its first captured parent, regardless of later
		// live movement. Assemble edges after discovery to avoid duplicate placement.
		var/list/edges = list()
		for(var/i = 1, i <= saving_owners.len, i++)
			edges += list(list())
			save_work_check()
		for(var/i = 1, i <= saving_owners.len, i++)
			var/owner = saving_owners[i]
			if(owner)
				var/list/children = edges[owner]
				children += "[i]"
			save_work_check()
		for(var/i = 1, i <= saving_owners.len, i++)
			if(saving_content_flags[i])
				var/list/children = edges[i]
				var/list/chunks = list()
				for(var/start = 1, start <= children.len, start += 500)
					chunks += list2params(children.Copy(start, min(start+500, children.len+1)))
					save_work_check()
				// params2list truncates oversized strings. Keep legacy text for
				// small contents, and bounded text chunks for dense containers.
				savefile["[entry_path(savefile, i)]/content"] << (chunks.len > 1 ? chunks : (chunks.len ? chunks[1] : ""))
			save_work_check()
		sleep(world.tick_lag)
		savefile.Flush()
		savefile = null
		sleep(world.tick_lag)
		log_startup_progress("	Saved z-level [A].")
	clear_bookkeeping()
	if(!text2file(time2text(world.realtime,"YYYY-MM-DD-(hh-mm-ss)"),"map_saves/save_complete.txt"))
		throw EXCEPTION("Could not write save completion marker")
	log_startup_progress("Finished saving.")
	return 1

/map_storage/proc/BuildVarDirectory(savefile/F, datum/A, contents = 0, traversal = FALSE)
	if(!A || istype(A, /client))
		return 0
	var/grid_key
	if(isturf(A))
		var/turf/T = A
		grid_key = "[T.x],[T.y],[T.z]"
		if(saving_grid_refs[grid_key])
			return saving_grid_refs[grid_key]
	if(!A.should_save || istype(A, /obj/map_metadata))
		return 0
	for(var/ignored in ignore_types)
		if(istype(A, ignored))
			return 0
	var/identity = "\ref[A]"
	if(istype(A, /atom/movable))
		var/atom/movable/M = A
		var/list/previous = saving_world_movables[identity]
		if(previous && previous["atom"] == A && previous["z"] != saving_z)
			if(traversal) return 0
			throw EXCEPTION("Cross-level object reference cannot be represented in per-level save files: [A.type]")
		var/turf/location = get_saved_turf(M)
		if(location && location.z != saving_z)
			throw EXCEPTION("Cross-level object reference cannot be represented in per-level save files: [A.type]")
	var/ind = saving_references[identity]
	if(ind && saving_reference_pins[ind] == A)
		return ind
	var/ref = saving_reference_pins.len + 1
	saving_reference_pins += A
	saving_references[identity] = ref
	if(grid_key) saving_grid_refs[grid_key] = ref
	saving_owners += 0
	saving_content_flags += FALSE
	A.before_save()
	if(!A)
		throw EXCEPTION("Object deleted by before_save")
	// Capture all fields and discovery handles before the first explicit yield.
	// Never dereference A after it: native deletion nulls pinned references too.
	var/saved_type = A.type
	var/capture_contents = A.load_contents && contents
	var/list/children = list()
	var/atom/owner
	if(istype(A, /atom/movable))
		var/atom/movable/M = A
		owner = M.loc
		saving_world_movables[identity] = list("atom" = A, "z" = saving_z)
	if(capture_contents && istype(A, /atom))
		var/atom/container = A
		children = container.contents.Copy()
	var/list/keys = A.get_saved_vars()
	if(istype(A, /atom/movable))
		var/atom/movable/M = A
		if(contents && M.load_datums) keys |= "reagents"
	var/list/values = list()
	var/list/saved_keys = list()
	for(var/key in keys)
		if(A.persistence_runtime_var(key) || key in list("loc", "locs", "pixloc", "contents", "vars", "type", "parent_type", "x", "y", "z", "vis_locs", "client", "key", "ckey"))
			continue
		if(A.vars.Find(key))
			saved_keys += key
			values += list(A.vars[key])
	F["[entry_path(F, ref)]/type"] << saved_type
	saving_content_flags[ref] = capture_contents
	// Capturing ancestors also covers objects discovered through saved variables
	// before their turf is scanned. Pins terminate parent/child reference cycles.
	if(owner && !istype(owner, /area))
		saving_owners[ref] = BuildVarDirectory(F, owner, 1, TRUE)
	save_work_check()
	for(var/atom/movable/child in children)
		if(child && child.loc == A)
			BuildVarDirectory(F, child, 1, TRUE)
		save_work_check()
	for(var/i = 1, i <= saved_keys.len, i++)
		var/encoded = encode_saved_value(F, values[i])
		F["[entry_path(F, ref)]/[saved_keys[i]]"] << encoded
		save_work_check()
	return ref

// Nested movables have z=0; walk their containment chain without game helpers.
/map_storage/proc/get_saved_turf(atom/A)
	while(A && !isturf(A))
		A = A.loc
	return A

// Typed envelopes preserve literal marker strings and associative/nested lists.
// Lists are indexed separately so aliases and cycles survive a round trip.
/map_storage/proc/encode_saved_value(savefile/F, value)
	if(istype(value, /obj/map_metadata))
		return list("kind" = "map")
	if(istype(value, /area))
		var/area/AR = value
		var/turf/T = locate(/turf) in AR
		if(!T)
			throw EXCEPTION("Referenced area has no world turf: [AR.type]")
		return list("kind" = "area", "x" = T.x, "y" = T.y, "z" = T.z, "type" = AR.type)
	if(islist(value))
		var/list/L = value
		var/id = saving_lists["\ref[L]"]
		if(!id || saving_list_pins[id] != L)
			id = saving_list_pins.len + 1
			saving_list_pins += list(L)
			saving_lists["\ref[L]"] = id
			var/list/snapshot = L.Copy()
			F["/lists/[id]/length"] << snapshot.len
			for(var/i = 1, i <= snapshot.len, i++)
				save_work_check()
				TICK_CHECK
				var/key = snapshot[i]
				var/encoded_key = encode_saved_value(F, key)
				var/encoded_value = encode_saved_value(F, (isnum(key) || isnull(key)) ? null : snapshot[key])
				F["/lists/[id]/[i]/key"] << encoded_key
				F["/lists/[id]/[i]/value"] << encoded_value
		return list("kind" = "list", "ref" = id)
	if(isturf(value))
		var/turf/T = value
		return list("kind" = "turf", "x" = T.x, "y" = T.y, "z" = T.z)
	if(istype(value, /datum))
		var/id = BuildVarDirectory(F, value, 1)
		return list("kind" = "entry", "ref" = id)
	return list("kind" = "value", "value" = value)
