/map_storage/proc/Load_Entry(savefile/savefile, var/ind, var/turf/old_turf, var/atom/starting_loc, var/atom/replacement, var/nocontents = 0, var/lag_fix = 0)
	try
		TICK_CHECK
		var/nextContents
		if(nocontents)
			nextContents = 2
		if(existing_references["[ind]"])
			if(starting_loc)
				var/atom/movable/A = existing_references["[ind]"]
				A.loc = starting_loc
			return existing_references["[ind]"]
		savefile.cd = "/entries/[ind]"
		var/type = savefile["type"]
		if (!findtext("[type]","/turf/"))
			return
		var/atom/movable/object
		if(!type)
			return
		if(lag_fix)
			so_far++
			if(so_far > per_pause)
				sleep(10)
				so_far = 0
		if(old_turf)
			var/finished = 0
			while(!finished)
				finished = 1
			var/xa = old_turf.x
			var/ya = old_turf.y
			var/za = old_turf.z
			old_turf.ChangeTurf(type, FALSE, FALSE)
			object = locate(xa,ya,za)
		else if(replacement)
			object = replacement
		else
			object = new type(starting_loc)
		if(!object)
			message_admins("object not created, ind: [ind] type:[type]")
			return
		all_loaded += object
		existing_references["[ind]"] = object
		for(var/v in savefile.dir)
			savefile.cd = "/entries/[ind]"
			if(object.persistence_runtime_var(v))
				continue
			if(v == "type")
				continue
			else if(v == "content")
				if(nocontents != 2)
					var/list/refs = params2list(savefile[v])
					var/finished = 0
					while(!finished)
						finished = 1
						for(var/obj/ob in object.contents)
							if(ob.loc != object) continue
							finished = 0
							ob.forceMove(locate(200, 100, 2))
							ob.Destroy()
					for(var/x in refs)
						Load_Entry(savefile, x, null, object, nocontents = nextContents, lag_fix = lag_fix)
			else if(findtext(savefile[v], "**list"))
				var/x = savefile[v]
				var/list/fixed = string_explode(x, "list")
				x = fixed[2]
				var/list/lis = params2list(x)
				var/list/final_list = list()
				if(lis.len)
					for(var/xa in lis)
						if(findtext(xa, "**entry"))
							var/list/fixed2 = string_explode(xa, "entry")
							var/y = fixed2[2]
							var/atom/movable/A = Load_Entry(savefile, y, lag_fix = lag_fix)
							final_list += A
						else
							final_list += "**unique**"
							final_list[final_list.len] = Numeric(xa)
				object.vars[v] = final_list
			else if(findtext(savefile[v], "**entry"))
				var/x = savefile[v]
				var/list/fixed = string_explode(x, "entry")
				x = fixed[2]
				var/atom/movable/A = Load_Entry(savefile, x, nocontents = nextContents, lag_fix = lag_fix)
				object.vars[v] = A
			else if(savefile[v] == "**null")
				object.vars[v] = null
			else if(v == "req_access_txt")
				object.vars[v] = savefile[v]
			else if(savefile[v] == "**emptylist")
				continue
			else
				savefile.cd = "/entries/[ind]"
				object.vars[v] = savefile[v]
			savefile.cd = "/entries/[ind]"
			TICK_CHECK
		savefile.cd = ".."
		if (ishuman(object))
			var/mob/living/human/H = object
			H.rejuvenate()
			if (!H.name && savefile["name"])
				H.name = savefile["name"]
		return object
	catch(var/exception/e)
		message_admins("EXCEPTION IN LOAD ENTRY!! [e] on [e.file]:[e.line], v: [savefile["type"]]")
/map_storage/proc/Load_World()
	for(var/B = 1, B <= world.maxz, B++)
		try
			var/watch = start_watch()
			existing_references = list()
			all_loaded = list()
			if(!fexists("map_saves/[B].sav"))
				continue
			var/savefile/savefile = new("map_saves/[B].sav")
			savefile.cd = "/map"
			TICK_CHECK
			for(var/z in savefile.dir)
				savefile.cd = "/map/[z]"
				for(var/y in savefile.dir)
					savefile.cd = "/map/[z]/[y]"
					for(var/x in savefile.dir)
						var/turf_ref = savefile["[x]"]
						if(!turf_ref)
							message_admins("turf_ref not found, x: [x]")
							continue
						var/turf/old_turf = locate(text2num(x), text2num(y), text2num(z))
						Load_Entry(savefile, turf_ref, old_turf)
						savefile.cd = "/map/[z]/[y]"
						TICK_CHECK
			for(var/i in 1 to all_loaded.len)
				var/datum/ob = all_loaded[i]
				if (ob)
					ob.after_load()
				if(istype(ob, /obj))
					var/obj/obbie = ob
					if(obbie.load_datums)
						if(obbie.reagents)
							obbie.reagents.my_atom = ob
			log_startup_progress("	Loaded z-level [B] in [stop_watch(watch)]s.")
		catch(var/exception/e)
			message_admins("EXCEPTION IN MAP LOADING!! [e] on [e.file]:[e.line]")
	clear_bookkeeping()
	log_startup_progress("Finished loading.")

// Restores the world-level state written at the top of Save_World(). Load_World()
// only rebuilds turfs (see the /turf/ check in Load_Entry()), so without this the
// epoch and research progress would reset to map defaults on every reload.
/map_storage/proc/load_map_metadata()
	if (!map || !fexists("map_saves/map.txt"))
		return FALSE
	var/list/meta = splittext(file2text("map_saves/map.txt"), "\n")
	if (meta.len < 9 || meta[1] != map.ID)
		return FALSE
	map.age = meta[2]
	map.ordinal_age = text2num(meta[3])
	map.default_research = text2num(meta[4])
	map.autoresearch = text2num(meta[5])
	map.autoresearch_mult = text2num(meta[6])
	map.chad_mode = text2num(meta[7])
	map.chad_mode_plus = text2num(meta[8])
	map.gamemode = meta[9]
	map.age1_done = (map.ordinal_age >= 1)
	map.age2_done = (map.ordinal_age >= 2)
	map.age3_done = (map.ordinal_age >= 3)
	map.age4_done = (map.ordinal_age >= 4)
	map.age5_done = (map.ordinal_age >= 5)
	map.age6_done = (map.ordinal_age >= 6)
	map.age7_done = (map.ordinal_age >= 7)
	map.age8_done = (map.ordinal_age >= 8)
	log_startup_progress("	Restored world metadata (epoch: [map.age], research: [map.default_research]).")
	return TRUE