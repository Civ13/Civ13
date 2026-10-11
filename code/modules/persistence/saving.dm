// Saves all of the turfs and objects within turfs to their own directories withn
// the specifeid savefile name. If objects or turfs have variables to keep track
// of, it will check to see if those variables have been modified and record the
// new values of any modified variables along with the object. It uses an object
// reference, which records each object type as a position in a list so that it
// can be references using a number instead of a fully written out type class.
// You can also specify a name and password for the map, along with any extra
// variables (in params format) that you want saved along with the map file.
/map_storage/proc/Save_World()
	// ***** MAP SECTION *****
	var/backup_dir = "map_backups/"
	// Back up the whole previous completed generation before overwriting any
	// level. A per-level rolling backup mixed old and new levels after failures.
	if(fexists("map_saves/save_complete.txt"))
		if(fexists("map_backups/save_complete.txt"))
			if(!fdel("map_backups/save_complete.txt"))
				throw EXCEPTION("Could not invalidate backup marker; existing save retained")
		for(var/name in flist("map_saves/"))
			if(name == "map.txt" || copytext(name, max(1, length(name)-3)) == ".sav")
				if(!fcopy("map_saves/[name]", "[backup_dir][name]"))
					throw EXCEPTION("Could not back up [name]; existing save retained")
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
		saving_lists = list()
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
		for(var/turf/turf in world)
			if (turf.z == A)
				var/ref = BuildVarDirectory(savefile, turf, 1)
				if(!ref)
					throw EXCEPTION("Turf [turf.x],[turf.y],[turf.z] could not be saved")
				savefile.cd = "/map/[turf.z]/[turf.y]"
				savefile["[turf.x]"] << ref
				TICK_CHECK
		log_startup_progress("	Saved z-level [A].")
	clear_bookkeeping()
	if(!text2file(time2text(world.realtime,"YYYY-MM-DD-(hh-mm-ss)"),"map_saves/save_complete.txt"))
		throw EXCEPTION("Could not write save completion marker")
	log_startup_progress("Finished saving.")
	return 1

/map_storage/proc/BuildVarDirectory(savefile/savefile, datum/A, var/contents = 0)
	if(!A || istype(A, /client))
		return 0
	if(!A.should_save)
		return 0
	if(istype(A, /obj/map_metadata))
		return 0
	for(var/ignored in ignore_types)
		if(istype(A, ignored))
			return 0
	if(istype(A, /atom/movable))
		var/atom/movable/movable = A
		if(movable.z && movable.z != saving_z)
			throw EXCEPTION("Cross-level object reference cannot be represented in per-level save files: [A.type]")
	var/ind = saving_references["\ref[A]"]
	var/ref = 0
	if(ind)
		return ind
	ref = saving_references.len + 1
	saving_references["\ref[A]"] = ref
	A.before_save()
	savefile.cd = entry_path(savefile, ref)
	if (A.type)
		savefile["type"] << A.type
	var/list/content_refs = list()
	if(A.load_contents)
		var/atom/movable/Ad = A
		if(contents)
			for(var/obj/content in Ad.contents)
				if(content.loc != Ad) continue
				var/conparams = BuildVarDirectory(savefile, content, 1)
				savefile.cd = entry_path(savefile, ref)
				if(!conparams)
					continue
				content_refs += "[conparams]"
			for(var/mob/mcontent in Ad.contents)
				if(mcontent.loc != Ad) continue
				var/mconparams = BuildVarDirectory(savefile, mcontent, 1)
				savefile.cd = entry_path(savefile, ref)
				if(!mconparams)
					continue
				content_refs += "[mconparams]"
		var/final_params = list2params(content_refs)
		savefile.cd = entry_path(savefile, ref)
		savefile["content"] << final_params
	var/list/changing_vars
	// Changed variables depend on the instance, not just its type.
	changing_vars = A.get_saved_vars()
	
	if(istype(A, /atom/movable))
		var/atom/movable/AM = A
		if(contents && AM.load_datums)
			changing_vars += "reagents"
	for(var/v in changing_vars)
		// Location is reconstructed by the map grid and contents graph. Saving it
		// recursively used to create turf entries outside that graph.
		if(v in list("loc", "locs", "pixloc", "contents", "vars", "type", "parent_type", "x", "y", "z", "vis_locs", "client", "key", "ckey"))
			continue
		if(A.vars.Find(v))
			var/value = encode_saved_value(savefile, A.vars[v])
			savefile.cd = entry_path(savefile, ref)
			savefile[v] << value
			continue
	savefile.cd = ".."
	return ref

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
		if(!id)
			id = saving_lists.len + 1
			saving_lists["\ref[L]"] = id
			F["/lists/[id]/length"] << L.len
			for(var/i = 1, i <= L.len, i++)
				TICK_CHECK
				var/key = L[i]
				var/encoded_key = encode_saved_value(F, key)
				var/encoded_value = encode_saved_value(F, (isnum(key) || isnull(key)) ? null : L[key])
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
