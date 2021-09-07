/datum/proc/after_load()
	return
/datum/proc/before_save()
	return

/datum/proc/remove_saved(var/ind)
	var/A = src.type
	var/B = replacetext("[A]", "/", "-")
	var/savedvarparams = file2text("saved_vars/[B].txt")
	if(!savedvarparams)
		savedvarparams = ""
	var/list/saved_vars = params2list(savedvarparams)
	if(saved_vars.len < ind)
		message_admins("remove_saved saved_vars less than ind [src]")
		return
	saved_vars.Cut(ind, ind+1)
	savedvarparams = list2params(saved_vars)
	fdel("saved_vars/[B].txt")
	text2file(savedvarparams, "saved_vars/[B].txt")
/datum/proc/add_saved(var/mob/M)
	if(!check_rights(R_ADMIN, 1, M))
		return
	var/input = input(M, "Enter the name of the var you want to save", "Add var","") as text|null
	if(!hasvar(src, input))
		to_chat(M, "The [src] does not have this var")
		return
	
	var/A = src.type
	var/B = replacetext("[A]", "/", "-")
	var/C = B
	var/savedvarparams = file2text("saved_vars/[B].txt")
	message_admins("savedvarparams: | [savedvarparams] | saved_vars/[B].txt")
	if(!savedvarparams)
		savedvarparams = ""
	var/list/savedvars = params2list(savedvarparams)
	var/list/newvars = list()
	if(savedvars && savedvars.len)
		newvars = savedvars.Copy()
	var/list/found_vars = list()
	var/list/split = splittext(B, "-")
	var/list/subtypes = list()
	if(split && split.len)
		for(var/x in split)
			if(x == "") continue
			var/subtypes_text = ""
			for(var/xa in subtypes)
				subtypes_text += "-[xa]"
			var/savedvarparamss = file2text("saved_vars/[subtypes_text]-[x].txt")
			message_admins("savedvarparamss: [savedvarparamss] dir: saved_vars/[subtypes_text]-[x].txt")
			var/list/saved_vars = params2list(savedvarparamss)
			if(saved_vars && saved_vars.len)
				found_vars |= saved_vars
			subtypes += x
	if(found_vars && found_vars.len)
		savedvars |= found_vars
	if(savedvars.Find(input))
		to_chat(M, "The [src] already saves this var")
		return
	newvars |= input
	savedvarparams = list2params(newvars)
	fdel("saved_vars/[C].txt")
	text2file(savedvarparams, "saved_vars/[C].txt")
/datum/proc/get_saved_vars()
	var/list/to_save = list()
	to_save |= params2list(map_storage_saved_vars)
	var/A = src.type
	var/B = replacetext("[A]", "/", "-")
	var/savedvarparams = file2text("saved_vars/[B].txt")
	if(!savedvarparams)
		savedvarparams = ""
	var/list/savedvars = params2list(savedvarparams)
	if(savedvars && savedvars.len)
		
	for(var/v in savedvars)
		if(findtext(v, "\n"))
			var/list/split2 = splittext(v, "\n")
			to_save |= split2[1]
		else
			to_save |= v
	var/list/found_vars = list()
	var/list/split = splittext(B, "-")
	var/list/subtypes = list()
	if(split && split.len)
		for(var/x in split)
			if(x == "") continue
			var/subtypes_text = ""
			for(var/xa in subtypes)
				subtypes_text += "-[xa]"
			var/savedvarparamss = file2text("saved_vars/[subtypes_text]-[x].txt")
			var/list/saved_vars = params2list(savedvarparamss)
			for(var/v in saved_vars)
				if(findtext(v, "\n"))
					var/list/split2 = splittext(v, "\n")
					found_vars |= split2[1]
				else
					found_vars |= v
			subtypes += x
	if(found_vars && found_vars.len)
		to_save |= found_vars
	return to_save
/datum/proc/add_saved_var(var/mob/M)
	if(!check_rights(R_ADMIN, 1, M))
		return
	var/A = src.type
	var/B = replacetext("[A]", "/", "-")
	var/C = B
	var/found = 1
	var/list/found_vars = list()
	var/list/split = splittext(B, "-")
	var/list/subtypes = list()
	if(split && split.len)
		for(var/x in split)
			if(x == "") continue
			var/subtypes_text = ""
			for(var/xa in subtypes)
				subtypes_text += "-[xa]"
			var/savedvarparams = file2text("saved_vars/[subtypes_text]-[x].txt")
			message_admins("savedvarparams: [savedvarparams] dir: saved_vars/[subtypes_text]-[x].txt")
			var/list/saved_vars = params2list(savedvarparams)
			if(saved_vars && saved_vars.len)
				found_vars |= saved_vars
			subtypes += x
	var/savedvarparams = file2text("saved_vars/[C].txt")
	message_admins("savedvarparams: [savedvarparams] saved_vars/[C].txt")
	if(!savedvarparams)
		savedvarparams = ""
	var/list/saved_vars = params2list(savedvarparams)
	var/dat = "<b>Saved Vars:</b><br><hr>"
	dat += "<b><u>Inherited</u></b><br><hr>"
	for(var/x in found_vars)
		dat += "[x]<br>"
	dat += "<b><u>For this Object</u></b><br><hr>"
	var/ind = 0
	for(var/x in saved_vars)
		ind++
		dat += "[x] <a href='?_src_=savevars;Remove=[ind];Vars=\ref[src]'>(Remove)</a><br>"
	dat += "<hr><br>"
	dat += "<a href='?_src_=savevars;Vars=\ref[src];Add=1'>(Add new var)</a>"
	M << browse(dat, "window=roundstats;size=500x600")

proc/lagstopsleep()
	var/tickstosleep = 1
	do
		sleep(world.tick_lag*tickstosleep)
		tickstosleep *= 2 //increase the amount we sleep each time since sleeps are expensive (5-15 proc calls)
	while(world.tick_usage > 75 && (tickstosleep*world.tick_lag) < 32) //stop if we get to the point where we sleep for seconds at a time


proc/mdlist2params(list/l)
                           //This converts a multidimensional list into a set of parameters. The
                           //output is in the following format: "name1=value1&name2=(name3=value3)"
                           //Notes: This can convert normal lists as well as multidimensional lists
                           //Warning: Beware of circular references. This will cause in infinite loop.
                                //If you know there is going to be a circular reference, create a new list
                                //and pull out the reference
	if(!istype(l,/list)) return
	var/rvalue,e = 1
	for(var/a in l)
		if(istype(l[a],/list) && length(l[a]))
			rvalue += list2params(l.Copy(e,l.Find(a)))
			rvalue += "&[a]=([mdlist2params(l[a])])"
			e = l.Find(a) + 1
		else continue
	if(e == 1) rvalue += list2params(l)
	return rvalue

proc/params2mdlist(params) //This converts a parameter text string, output by mdlist2params(), into
                           //a multidimensional list.
                           //Notes: It will work for parameters output by list2params() as well.
    if(!istext(params)) return
    var/list/rlist = list()
    var/len = length(params)
    var/element = null
    var/a = 0,p_count = 1
    while(a <= len)
        a ++
        if(findtext(params,"&",a,a+1))
            rlist += params2list(copytext(params,1,a))
            params = copytext(params,a+1)
            len = length(params)
            a = 1
        if(findtext(params,"(",a,a+1))
            element = copytext(params,1,a-1)
            params = copytext(params,a+1)
            len = length(params)
            p_count = 1
            while(p_count > 0)
                a ++
                if(findtext(params,"(",a,a+1)) p_count ++
                if(findtext(params,")",a,a+1)) p_count --
                if(a >= len - 1) break
            rlist[element] = params2mdlist(copytext(params,1,a+1))
            params = copytext(params,a+2)
            len = length(params)
            a = 1
    rlist += params2list(copytext(params,1))
    return rlist

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
		list/ignore_types = list(/mob, /atom/movable/lighting_overlay)

		// If a text string is specified here, then you will be able to use this as a
		// backdoor password which will let you access any maps. This is primary for
		// developers who need to be able to access maps created by other people for
		// debugging purposes.
		backdoor_password = null

		// This text string is tacked onto all saved passwords so that their md5 values
		// will be different than what the password's hash would normally be, providing
		// a bit of extra protection against md5 hash directories.
		game_id = "SS13"
		list/allowed_locs = list(/obj/item/organ/internal/brain, /obj/item/device/mmi, /obj/mecha)



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
		if(backdoor)
			src.backdoor_password = backdoor
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
				var/mob/living/carbon/human/hum = object
				if(istype(hum, /mob/living/carbon/human))
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
						var/firstval = lis[1]
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
		if(istype(A, /turf/space) && (!A.contents || A.contents.len == 0))
			savefile.cd = "/entries/0"
			savefile["type"] = A.type
			savefile["content"] = ""
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
				changing_vars += "air_contents"
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



map_storage
	proc/Save_Char(client/C, var/datum/mind/H, var/mob/living/carbon/human/Firstbod, var/slot = 0)
		var/ckey = ""
		saving_references = list()
		existing_references = list()
		found_types = list()
		var/mob/current
		if(!H)
			message_admins("trying to save char without mind")
			return
		if(H.current && H.current.ckey && !Firstbod)
			ckey = H.current.ckey
			slot = H.char_slot
			current = H.current
		else if(Firstbod)
			ckey = C.ckey
			current = Firstbod

		if(findtext(ckey, "@"))
			var/list/nums = string_explode(ckey, "@")
			ckey = nums[2]
			message_admins("@ found, nums.len [nums.len]")
		fdel("char_saves/[ckey]/[slot].sav")
		var/savefile/savefile = new("char_saves/[ckey]/[slot].sav")
		var/bodyind = BuildVarDirectory(savefile, current, 1)
		var/mindind = BuildVarDirectory(savefile, H, 1)
		var/locind = 0
		if(istype(current.loc, /obj))
			var/foun = 0
			for(var/typ in allowed_locs)
				if(istype(current.loc, typ))
					foun = 1
					break
			if(foun)
				locind = BuildVarDirectory(savefile, current.loc, 1)
				current.loc.should_save = 0
		savefile.cd = "/data"
		savefile["body"] = bodyind
		savefile["mind"] = mindind
		savefile["loc"] = locind
		return 1
	proc/Load_Records(var/search, var/dir = 1) // gen = 1, med = 2, sec = 3
		message_admins("Load_Records ran!")
		all_loaded = list()
		existing_references = list()
		found_types = list()
		all_loaded = list()
		if(!search)
			return
		var/front_dir
		switch(dir)
			if(1)
				front_dir = "gen_records"
			if(2)
				front_dir = "med_records"
			if(3)
				front_dir = "sec_records"
		if(fexists("[front_dir]/[search].sav"))
			message_admins("FILE Found [front_dir]/[search].sav !")
			var/savefile/savefile = new("[front_dir]/[search].sav")
			var/recind = savefile["record"]
			var/datum/data/record/G = Load_Entry(savefile, 1)
			return G
		else
			message_admins("FILE DID NOT EXIST [front_dir]/[search].sav !")
			return 0
	proc/Save_Records()

		for(var/datum/data/record/G in data_core.general)
			saving_references = list()
			existing_references = list()
			var/name = G.fields["name"]
			var/fingerprint = G.fields["fingerprint"]
			fdel("gen_records/[name].sav")
			var/savefile/savefile = new("gen_records/[name].sav")
			savefile["record"] = BuildVarDirectory(savefile, G, 1)
			message_admins("savefile made! record: [savefile["record"]]")
			fcopy(savefile, "gen_records/[fingerprint].sav")
		for(var/datum/data/record/G in data_core.medical)
			saving_references = list()
			existing_references = list()
			var/name = G.fields["name"]
			var/dna = G.fields["b_dna"]
			fdel("med_records/[name].sav")
			var/savefile/savefile = new("med_records/[name].sav")
			savefile["record"] = BuildVarDirectory(savefile, G, 1)
			fcopy(savefile, "med_records/[dna].sav")
		for(var/datum/data/record/G in data_core.security)
			saving_references = list()
			existing_references = list()
			var/name = G.fields["name"]
			fdel("sec_records/[name].sav")
			var/savefile/savefile = new("sec_records/[name].sav")
			savefile["record"] = BuildVarDirectory(savefile, G, 1)
	proc/Load_Char(var/ckey, var/slot, var/datum/mind/M, var/transfer = 0)
		if(!ckey)
			message_admins("Load_Char without ckey")
			return
		if(!slot)
			message_admins("Load_char without slot")
			return
		all_loaded = list()
		existing_references = list()
		found_types = list()
		var/savefile/savefile = new("char_saves/[ckey]/[slot].sav")
		savefile.cd = "/data"
		var/bodyind = savefile["body"]
		var/mindind = savefile["mind"]
		var/locind = savefile["loc"]
		var/loc = null
		TICK_CHECK
		if(locind != "0")
			loc = Load_Entry(savefile, locind)
		var/mob/mob = Load_Entry(savefile, bodyind, nocontents = !transfer, species_override = 1)
		TICK_CHECK
		if(!mob)
			return
		if(!M)
			mob.mind = new()
			M = mob.mind
		var/datum/mind/mind = Load_Entry(savefile, mindind, null, null, M)
		TICK_CHECK
		for(var/datum/dat in all_loaded)
			dat.after_load()
		for(var/atom/movable/ob in all_loaded)
			ob.initialize()
			ob.after_load()
			if(ob.load_datums)
				if(ob.reagents)
					ob.reagents.my_atom = ob
			if(istype(ob, /turf/simulated))
				var/turf/simulated/Te = ob
				//Te.blocks_air = initial(Te.blocks_air)
				Te.new_air()

		if(transfer)
			M.transfer_to(mob)
		if(loc)
			mob.loc = loc
			return loc
		else
			return mob

	proc/Load_Char_Fast(var/ckey, var/slot, var/datum/mind/M, var/transfer = 0, var/announce = 0)
		if(!ckey)
			message_admins("Load_Char without ckey")
			return
		if(!slot)
			message_admins("Load_char without slot")
			return
		so_far = 0
		all_loaded = list()
		existing_references = list()
		found_types = list()
		all_loaded = list()
		var/savefile/savefile = new("char_saves/[ckey]/[slot].sav")
		savefile.cd = "/data"
		var/bodyind = savefile["body"]
		var/mindind = savefile["mind"]
		var/locind = savefile["loc"]
		savefile.cd = "/entries/[bodyind]"
		var/type = savefile["type"]
		var/mob/object = new type()
		var/obj/old_brain
		object.deleting = 1
		var/atom/movable/object2
		if(locind != "0" && locind != 0)
			savefile.cd = "/entries/[locind]"
			type = savefile["type"]
			object2 = new type()
		spawn(0)
			if(istype(object, /mob/living/carbon/human))
				var/mob/living/carbon/human/organ_donor = object
				organ_donor.disable_process = 1
				for(var/obj/x in organ_donor.internal_organs)
					qdel(x)
					qdel(x)
			var/loc = null
			TICK_CHECK
			if(locind != "0" && locind != 0)
				loc = Load_Entry(savefile, locind, replacement = object2, lag_fix = 1)
			var/mob/living/mob = Load_Entry(savefile, bodyind, replacement = object, nocontents = !transfer, species_override = 1, lag_fix = 1)
			TICK_CHECK
			if(!mob)
				return
			if(!M)
				mob.mind = new()
				M = mob.mind
			var/datum/mind/mind = Load_Entry(savefile, mindind, null, null, M, lag_fix = 1)
			TICK_CHECK
			for(var/datum/dat in all_loaded)
				dat.after_load()
			for(var/atom/movable/ob in all_loaded)
				ob.initialize()
				ob.after_load()
				if(ob.load_datums)
					if(ob.reagents)
						ob.reagents.my_atom = ob
				if(istype(ob, /turf/simulated))
					var/turf/simulated/Te = ob
					//Te.blocks_air = initial(Te.blocks_air)
					Te.new_air()
			message_admins("Char loaded!!! [all_loaded.len] instances")
			if(!mind.initial_account)
				message_admins("OMG! CHAR LOADED WITHOUT ACCOUNT!! [mob.real_name]")
				mind.initial_account = create_account(mob.real_name, 500)
			if(!mind.primary_cert)
				message_admins("OMG! CHAR LOADED WITHOUT PRIMARY CERT! [mob.real_name]")
				mind.primary_cert = job_master.GetCert("intern")
			if(transfer)
				M.transfer_to(mob)
			if(loc)
				mob.loc = loc
			TICK_CHECK
			if(istype(object, /mob/living/carbon/human))
				var/mob/living/carbon/human/organ_donor = object
				organ_donor.disable_process = 0
			if(mob.mind.primary_cert)
				mob.mind.assigned_job = mob.mind.primary_cert
				var/rank = get_default_title(mind.ranks[to_strings(mind.assigned_job.department_flag)], mind.assigned_job)
				var/rank_uid = mob.mind.primary_cert.uid
				job_master.EquipRankPersistant(mob, rank_uid, 1)
				data_core.manifest_inject(mob)

				ticker.minds |= mob.mind//Cyborgs and AIs handle this in the transform proc.	//TODO!!!!! ~Carn
				TICK_CHECK
				spawn(10)
					var/join_message = "has arrived on the station"
					AnnounceArrival(mob, rank, join_message)

		if(object2)
			return object2
		else
			return object
// Saves all of the turfs and objects within turfs to their own directories withn
// the specifeid savefile name. If objects or turfs have variables to keep track
// of, it will check to see if those variables have been modified and record the
// new values of any modified variables along with the object. It uses an object
// reference, which records each object type as a position in a list so that it
// can be references using a number instead of a fully written out type class.
// You can also specify a name and password for the map, along with any extra
// variables (in params format) that you want saved along with the map file.
	proc/Save(savefile/savefile, list/areas, extra)

		// Abort if no filename specified.
		if(!savefile)
			return 0
		saving_references = list()
		existing_references = list()
		found_types = list()
		// ***** MAP SECTION *****
		for(var/A in areas)
			for(var/turf/turf in get_area_turfs(A))
				var/ref = BuildVarDirectory(savefile, turf, 1)
				if(!ref)
					message_admins("[turf] failed to return a ref!")
				savefile.cd = "/map/[turf.z]/[turf.y]"
				savefile["[turf.x]"] = ref

		return 1
	proc/Save_World(list/areas)
		// ***** MAP SECTION *****
		var/backup_dir
		for(var/A in areas)
			saving_references = list()
			existing_references = list()
			found_types = list()
			var/B = replacetext("[A]", "/", "-")
			if(fexists("map_saves/[B].sav"))
				var/savefile/sav = new("map_saves/[B].sav")
				if(!backup_dir)
					var/i = 1
					var/found = 0
					while(!found)
						found = 1
						if(fexists("map_backups/[i]/[B].sav"))
							found = 0
							i++
						else
							backup_dir = "map_backups/[i]/"
				fcopy(sav, "[backup_dir][B].sav")
				fdel("map_saves/[B].sav")
			var/savefile/savefile = new("map_saves/[B].sav")
			for(var/turf/turf in get_area_turfs(A))
				var/ref = BuildVarDirectory(savefile, turf, 1)
				if(!ref)
					message_admins("[turf] failed to return a ref!")
				savefile.cd = "/map/[turf.z]/[turf.y]"
				savefile["[turf.x]"] = ref
				TICK_CHECK
		return 1
	proc/Save_World_Chunk(list/areas)
		// ***** MAP SECTION *****
		if(fexists(file("map_saves/recent/")))
			fcopy("map_saves/recent/", "map_saves/backup/[time2text(world.realtime, "MM-DD hh.mm.ss")]/")
			fdel("map_saves/recent/")

		for(var/z = 1, z < 2, z++)
			for(var/x = 1, x < 256, x += 15)
				for(var/y = 1, y < 256, y += 15)
					Save_Chunk(x, y, z)
					sleep(-1)

		return 1

	proc/Save_Chunk(tx, ty, z)
		saving_references = list()
		existing_references = list()
		found_types = list()
		tx = tx + 1 - tx % 15
		ty = ty + 1 - ty % 15
		for(var/x = tx, x < tx + 15, x++)
			for(var/y = ty, y < ty + 15, y++)

				var/turf/T = locate(x,y,z)
				if(!T)
					continue
				var/B = "[tx]-[ty]"
				var/savefile/savefile = new("map_saves/recent/[T.z]/[B].sav")
				var/ref = BuildVarDirectory(savefile, T, 1)
				if(!ref)
					message_admins("[T] failed to return a ref!")
				savefile.cd = "/map/[T.z]/[T.y]"
				savefile["[T.x]"] = ref
				TICK_CHECK

		return 1

	proc/Load_World_Chunk()
		var/watch = start_watch()
		log_startup_progress("Started Loading")
		for(var/z = 1, z < 2, z++)
			for(var/x = 1, x < 256, x += 15)
				message_admins("Loaded [x] out of 256")
				for(var/y = 1, y < 256, y += 15)
					Load_Chunk(x, y, z)
					sleep(-1)

	proc/Load_World(list/areas)

		for(var/A in areas)
			try
				var/watch = start_watch()
				existing_references = list()
				all_loaded = list()
				var/B = replacetext("[A]", "/", "-")
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
					ob.after_load()
					if(istype(ob, /obj))
						var/obj/obbie = ob
						if(obbie.load_datums)
							if(obbie.reagents)
								obbie.reagents.my_atom = ob
					if(istype(ob, /turf/simulated))
						var/turf/simulated/Te = ob
						//Te.blocks_air = initial(Te.blocks_air)
						Te.new_air()
				log_startup_progress("	Loaded [A] in [stop_watch(watch)]s.")
			catch(var/exception/e)
				message_admins("EXCEPTION IN MAP LOADING!! [e] on [e.file]:[e.line]")
	proc/Load_Chunk(tx, ty, tz, var/location = "recent")
		try
			tx = tx + 1 - tx % 15
			ty = ty + 1 - ty % 15

			existing_references = list()
			all_loaded = list()
			var/B = "[tx]-[ty]"
			if(!fexists(file("map_saves/[location]/[tz]/[B].sav")))
				return
			var/savefile/savefile = new("map_saves/[location]/[tz]/[B].sav")
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
				ob.after_load()
				if(istype(ob, /obj))
					var/obj/obbie = ob
					if(obbie.load_datums)
						if(obbie.reagents)
							obbie.reagents.my_atom = ob
				if(istype(ob, /turf/simulated))
					var/turf/simulated/Te = ob
					//Te.blocks_air = initial(Te.blocks_air)
					Te.new_air()
		catch(var/exception/e)
			message_admins("EXCEPTION IN MAP LOADING!! [e] on [e.file]:[e.line]")

// Loading a file is pretty straightforward - you specify the savefile to load from
// (make sure its an actual savefile, not just a file name), and if necessary you
// include the savefile's password as an argument. This will automatically check to
// make sure that the file provided is a valid map file, that the password matches,
// and that the verification values are what they're supposed to be (meaning the
// file has not been tampered with). Once everything is checked, it will resize the
// world map to fit the saved map, then unload all saved objects. Finally, any extra
// values that you included in the savefile will be returned by this function as
// an associative list.
	proc/Load(savefile/savefile, password)
		all_loaded = list()
		existing_references = list()
		// Make sure a map file is provided.
		if(!savefile)
			return
		savefile.cd = "/map"
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
		for(var/datum/dat in all_loaded)
			dat.after_load()
		for(var/atom/movable/ob in all_loaded)
			ob.initialize()
			ob.after_load()
			if(ob.load_datums)
				if(ob.reagents)
					ob.reagents.my_atom = ob
			if(istype(ob, /turf/simulated))
				var/turf/simulated/Te = ob
				//Te.blocks_air = initial(Te.blocks_air)
				Te.new_air()
/*************************************************************************
SUPPLEMENTARY FUNCTIONS
**************************************************************************/

map_storage

	// These is called routinely as the load and save functions make progress.
	// If you want to display how much of the map has been saved or loaded
	// somewhere, you can use this function to do it.

	proc/SaveOutput(percent)
		return

	proc/LoadOutput(percent)
		return

	// This is called when loading a map after all the verification and
	// password stuff is completed so that the map can have a fresh template
	// to work with.
	proc/ClearMap()
		for(var/turf/T in world)
			for(var/atom/movable/A in T)
				if(ismob(A))
					var/mob/M = A
					if(M.client)
						M.loc = null
						continue
				del(A)
			del(T)
		return
