//from https://github.com/Persistent-SS13/Persistent-SS13/blob/master/code/modules/world_save/Map%20Storage.dm
//7-september-2021

//needs to be defined for some atoms
/datum/proc/after_load()
	return
/datum/proc/before_save()
	return

/datum/proc/get_saved_vars()
	var/list/to_save = list()
	if  (!istype(src, /mob) && ((istype(src, /turf) || istype(src, /obj/structure/wild) || (!istype(src, /obj/item) && !istype(src, /obj/structure) && !istype(src, /obj/map_metadata) && !istype(src, /obj/covers)))))
		to_save |= params2list(map_storage_saved_vars)
	else
		for (var/key in src.vars)
			if (src.vars[key] != initial(src.vars[key]) && key != "verbs" && key != "locs" && key != "group")
				to_save |= key
	return to_save

var/map_storage/map_storage = new("SS13")
/*************************************************************************
ATOM ADDITIONS
**************************************************************************/
datum
	var
		load_contents = 0
		should_save = 1
		map_storage_saved_vars = ""
		safe_list_vars = ""
atom
	map_storage_saved_vars = "density;icon_state;dir;name;pixel_x;pixel_y;id"
	load_contents = 1
/*************************************************************************
MAP STORAGE DATUM
**************************************************************************/
map_storage

	var
		// These are atom types for the map saver to ignore. Objects of these type will
		// not be saved with everything else.
		list/ignore_types = list(/mob/new_player, /atom/movable/lighting_overlay)

		// This text string is tacked onto all saved passwords so that their md5 values
		// will be different than what the password's hash would normally be, providing
		// a bit of extra protection against md5 hash directories.
		game_id = "SS13"

		// INTERNAL VARIABLES - SHOULD NOT BE ALTERED BY USERS

		// List of object types. This will be converted to params and encrypted when saved.
		list/object_reference = list()
		list/obj_references = list()
		list/existing_references = list()
		list/saving_references = list()
		list/all_loaded = list()
		list/found_types = list()
		var/per_pause = 200
		var/so_far = 0
	New(game_id, backdoor, ignore)
		..()
		if(game_id)
			src.game_id = game_id
		if(ignore)
			src.ignore_types = ignore
		return

	proc/Load_Entry(savefile/savefile, var/ind, var/turf/old_turf, var/atom/starting_loc, var/atom/replacement, var/nocontents = 0, var/species_override = 0, var/lag_fix = 0)
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
			var/atom/movable/object
			if(!type)
				return
			if(lag_fix)
				so_far++
				if(so_far > per_pause)
					sleep(10)
					so_far = 0
			if(old_turf)
			//	old_turf.blocks_air = 1
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
			if(species_override)
				var/mob/living/human/hum = object
				if(istype(hum, /mob/living/human))
					var/x = savefile["species"]
					if(x)
						var/list/fixed = string_explode(x, "entry")
						if(fixed)
							x = fixed[2]
							var/datum/species/S = Load_Entry(savefile, x, lag_fix = lag_fix)
							savefile.cd = "/entries/[ind]"
							hum.set_species(S.name)

			for(var/v in savefile.dir)
				savefile.cd = "/entries/[ind]"
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
					object.vars[v] = list()
				else
					savefile.cd = "/entries/[ind]"
					object.vars[v] = savefile[v]
				savefile.cd = "/entries/[ind]"
				TICK_CHECK
			savefile.cd = ".."
			return object
		catch(var/exception/e)
			message_admins("EXCEPTION IN LOAD ENTRY!! [e] on [e.file]:[e.line]")

	proc/BuildVarDirectory(savefile/savefile, atom/A, var/contents = 0)
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
		savefile["type"] = A.type
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
			savefile["content"] = final_params
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
					savefile["[v]"] = "**entry[conparams]"
				else if(istype(A.vars[v], /datum))
					var/atom/movable/varob = A.vars[v]
					var/conparams = BuildVarDirectory(savefile, varob, 1)
					if(!conparams)
						continue
					savefile.cd = "/entries/[ref]"
					savefile["[v]"] = "**entry[conparams]"
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
							savefile["[v]"] = "**list[list2params(fixed_list)]"
						else
							if(A.vars[v] != initial(A.vars[v]))
								savefile.cd = "/entries/[ref]"
								savefile["[v]"] = "**emptylist"
				else if(A.vars[v] != initial(A.vars[v]) || v == "pixel_x" || v == "pixel_y")
					savefile.cd = "/entries/[ref]"
					savefile["[v]"] = A.vars[v]
			else
				// message_admins("trying to save an invalid var |[v]|")
		savefile.cd = ".."
		return ref



// Returns true if the value is purely numeric, return false if there are non-numeric
// characters contained within the text string.
	proc/IsNumeric(text)
		if(isnum(text))
			return 1
		for(var/n in 1 to length(text))
			var/ascii = text2ascii(text, n)
			if(ascii < 45 || ascii > 57)
				return 0
			if(ascii == 47)
				return 0
		return 1

// If the value is numeric, convert it to a number and return the number value. If
// the value is text, then return it as it is.
	proc/Numeric(text)
		if(islist(text))
			return text
		if(IsNumeric(text))
			return text2num(text)
		else
			if(findtext(text, "e+"))
				var/list/nums = string_explode(text, "e+")
				if(nums.len > 1 && nums.len < 3)
					var/integer = text2num(nums[1])
					var/exp = text2num(nums[2])
					if(IsNumeric(integer) && IsNumeric(exp))
						return integer*10**exp
			return text



// Saves all of the turfs and objects within turfs to their own directories withn
// the specifeid savefile name. If objects or turfs have variables to keep track
// of, it will check to see if those variables have been modified and record the
// new values of any modified variables along with the object. It uses an object
// reference, which records each object type as a position in a list so that it
// can be references using a number instead of a fully written out type class.
// You can also specify a name and password for the map, along with any extra
// variables (in params format) that you want saved along with the map file.
	proc/Save_World()
		// ***** MAP SECTION *****
		var/backup_dir = "map_backups/"
		var/F0 = file("map_saves/map.txt")
		if (fexists(F0))
			fcopy(F0,file("map_backups/map.txt"))
			fdel(F0)
		text2file(map.ID,F0)
		text2file(map.age,F0)
		text2file(map.ordinal_age,F0)
		text2file(map.default_research,F0)
		text2file(map.autoresearch,F0)
		text2file(map.autoresearch_mult,F0)
		text2file(map.chad_mode,F0)
		text2file(map.chad_mode_plus,F0)
		text2file(map.gamemode,F0)
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
					savefile["[turf.x]"] = ref
					TICK_CHECK
			log_startup_progress("	Saved z-level [A].")
		log_startup_progress("Finished saving.")
		return 1

	proc/Load_World()
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
		log_startup_progress("Finished loading.")

/*************************************************************************
SUPPLEMENTARY FUNCTIONS
**************************************************************************/
	// This is called when loading a map after all the verification and
	// password stuff is completed so that the map can have a fresh template
	// to work with.
	proc/ClearMap()
		sleep(1)
		world.log << "Clearing mobs..."
		for (var/mob/mob in world)
			if (!istype(mob, /mob/new_player))
				qdel(mob)
		sleep(1)
		world.log << "Clearing objects..."
		for (var/obj/object in world)
			qdel(object)
		return

/datum/data/record
	var/name = "record"
	var/size = 5.0
	var/list/fields = list(  )
	map_storage_saved_vars = "fields"
	safe_list_vars = "fields"