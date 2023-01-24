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
	var/F0 = file("map_saves/map.txt")
	if (fexists(F0))
		fcopy(F0,file("map_backups/map.txt"))
		fdel(F0)
	text2file(map.ID,F0)
	text2file("[map.age]",F0)
	text2file("[map.ordinal_age]",F0)
	text2file("[map.default_research]",F0)
	text2file("[map.autoresearch]",F0)
	text2file("[map.autoresearch_mult]",F0)
	text2file("[map.chad_mode]",F0)
	text2file("[map.chad_mode_plus]",F0)
	text2file("[map.gamemode]",F0)
	text2file(time2text(world.realtime,"YYYY-MM-DD-(hh-mm-ss)"),F0)
	log_startup_progress("	Saved metadata.")
	for(var/A = 1, A <= world.maxz, A++)
		saving_references = list()
		existing_references = list()
		found_types = list()
		if(fexists("map_saves/[A].sav"))
			var/savefile/sav = new("map_saves/[A].sav")
			if(fexists("map_backups/[A].sav"))
				fdel("map_backups/[A].sav")
			fcopy(sav, "[backup_dir][A].sav")
			fdel("map_saves/[A].sav")
		var/savefile/savefile = new("map_saves/[A].sav")
		for(var/turf/turf in world)
			if (turf.z == A)
				var/ref = BuildVarDirectory(savefile, turf, 1)
				if(!ref)
					message_admins("[turf] failed to return a ref!")
				savefile.cd = "/map/[turf.z]/[turf.y]"
				savefile["[turf.x]"] << ref
				TICK_CHECK
		log_startup_progress("	Saved z-level [A].")
	log_startup_progress("Finished saving.")
	return 1

/map_storage/proc/BuildVarDirectory(savefile/savefile, atom/A, var/contents = 0)
	if(!A.should_save)
		return 0
	var/ind = saving_references.Find(A)
	var/ref = 0
	if(ind)
		return ind
	saving_references += A
	ref = saving_references.len
	A.before_save()
	savefile.cd = "/entries/[ref]"
	if (A.type)
		savefile["type"] << A.type
	var/list/content_refs = list()
	if(A.load_contents)
		var/atom/movable/Ad = A
		if(contents)
			for(var/obj/content in Ad.contents)
				if(content.loc != Ad) continue
				var/conparams = BuildVarDirectory(savefile, content, 1)
				savefile.cd = "/entries/[ref]"
				if(!conparams)
					continue
				content_refs += "[conparams]"
			for(var/mob/mcontent in Ad.contents)
				if(mcontent.loc != Ad) continue
				var/mconparams = BuildVarDirectory(savefile, mcontent, 1)
				savefile.cd = "/entries/[ref]"
				if(!mconparams)
					continue
				content_refs += "[mconparams]"
		var/final_params = list2params(content_refs)
		savefile.cd = "/entries/[ref]"
		savefile["content"] << final_params
	var/list/changing_vars
	if(found_types.Find(A.type))
		changing_vars = found_types[A.type]
	else
		changing_vars = A.get_saved_vars()
		found_types["[A.type]"] = changing_vars
	
	var/list/old_vars = params2list(A.map_storage_saved_vars)
	var/list/safe_lists = params2list(A.safe_list_vars)
	if(istype(A, /atom/movable))
		var/atom/movable/AM = A
		if(contents && AM.load_datums)
			changing_vars += "reagents"
	for(var/v in changing_vars)
		if(!old_vars.Find(v))
			savefile.cd = "/entries/[ref]"
		if(A.vars.Find(v))
			if(istype(A.vars[v], /obj))
				var/atom/movable/varob = A.vars[v]
				var/conparams = BuildVarDirectory(savefile, varob, 1)
				if(!conparams)
					continue
				savefile.cd = "/entries/[ref]"
				savefile["[v]"] << "**entry[conparams]"
			else if(istype(A.vars[v], /datum))
				var/atom/movable/varob = A.vars[v]
				var/conparams = BuildVarDirectory(savefile, varob, 1)
				if(!conparams)
					continue
				savefile.cd = "/entries/[ref]"
				savefile["[v]"] << "**entry[conparams]"
			else if(istype(A.vars[v], /list))
				if(safe_lists.Find(v))
					savefile["[v]"] << A.vars[v]
				else
					var/list/lis = A.vars[v]
					if(lis.len)
						var/list/fixed_list = list()
						for(var/firstval in lis)
							if(istype(firstval, /obj))
								var/conparams = BuildVarDirectory(savefile, firstval, 1)
								if(!conparams)
									continue
								fixed_list += "**entry[conparams]"
							else if(istype(firstval, /datum))
								var/conparams = BuildVarDirectory(savefile, firstval, 1)
								if(!conparams)
									continue
								fixed_list += "**entry[conparams]"
							else
								fixed_list += firstval
						savefile.cd = "/entries/[ref]"
						savefile["[v]"] << "**list[list2params(fixed_list)]"
					else
						if(A.vars[v] != initial(A.vars[v]))
							savefile.cd = "/entries/[ref]"
							savefile["[v]"] << "**emptylist"
			else if(A.vars[v] != initial(A.vars[v]) || v == "pixel_x" || v == "pixel_y")
				savefile.cd = "/entries/[ref]"
				savefile["[v]"] << A.vars[v]
		else
			// message_admins("trying to save an invalid var |[v]|")
	savefile.cd = ".."
	return ref
