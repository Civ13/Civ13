////WORK IN PROGRESS - PERSISTENCE STUFF////
/datum/admins/proc/import_savegame()
	set category = "Server"
	set desc="Import Variables"
	set name="Import Savegame"

	//dont want this to be used for now
//	return
	//
	var/mapfile = file("SQL/saves/map.txt")
	if (!fexists(mapfile))
		usr << "The savefile does not exist or is corrupted!"
		return
	var/loaded_metadata = file2text(mapfile)
	var/list/parsed_metadata = splittext(loaded_metadata, "\n")
	if (map.ID != parsed_metadata[1])
		usr << "Different maps! Start a round in the right map first, then load."
		return
	var/confirm = WWinput(usr, "Are you sure you want to load the world? SERVER MIGHT FREEZE FOR A WHILE!", "Confirmation Required", "No", list("Yes", "No"))
	if (confirm == "No")
		return
	else
		world << "<big><b>Loading a game, please wait...</b></big>"
		sleep(1)
		world.log << "Importing turfs..."
		var/F = file("SQL/saves/turfs.txt")
		if (fexists(F))
			var/tmpturfs = file2text(F)
			var/list/impturfs = splittext(tmpturfs, "\n")
			for (var/i in impturfs)
				var/list/impturfs2 = splittext(i, ";")
				if (impturfs2[1] == "TURF")
					var/resultp = text2path(impturfs2[5])
					world.log << "[impturfs2[5]]"
					var/turf/T
					T = locate(text2num(impturfs2[2]),text2num(impturfs2[3]),text2num(impturfs2[4]))
					T.ChangeTurf(resultp)
		world.log << "Imported all turfs."
		sleep(1)
		world.log << "Clearing mobs..."
		for (var/mob/mob in world)
			if (!istype(mob, /mob/new_player))
				qdel(mob)
		world.log << "Importing mobs..."
		var/F2 = file("SQL/saves/mobs.txt")
		if (fexists(F2))
			var/tmpmobs = file2text(F2)
			var/list/impmobs = splittext(tmpmobs, "\n")
			for (var/i in impmobs)
				var/list/impmobs2 = splittext(i, ";")
				if (impmobs2.len >= 5 && impmobs2[1] == "MOB" && impmobs2[5] != "/mob/new_player" && impmobs2[5] != "/mob/observer")
					var/resultp = text2path(impmobs2[5])
					var/mob/newmob = new resultp(locate(text2num(impmobs2[2]),text2num(impmobs2[3]),text2num(impmobs2[4])))
					newmob.stat = text2num(impmobs2[6])
//				else if (impmobs2[1] == "HUMAN")
//					return
		world.log << "Imported all mobs."
		sleep(1)
		world.log << "Clearing objects..."
		for (var/obj/object in world)
			if (!istype(object, /obj/map_metadata))
				qdel(object)
		world.log << "Importing objects..."
		var/F3 = file("SQL/saves/objs.txt")
		if (fexists(F3))
			var/tmpobjs = file2text(F3)
			var/list/impobjs = splittext(tmpobjs, "\n")
			for (var/i in impobjs)
//				i = replacetext(i, "|;","|")
				var/list/impobjs2 = splittext(i, ";")
				if (impobjs2.len >= 5 && /*impobjs2[1] == "SIMPLE_OBJ" &&*/ !findtext(impobjs2[5],"/obj/map_metadata") && !findtext(impobjs2[5],"/obj/effects/lobby_image"))
					var/resultp = text2path(impobjs2[5])
					var/obj/tmpobj = new resultp(locate(text2num(impobjs2[2]),text2num(impobjs2[3]),text2num(impobjs2[4])))
					if (impobjs2[1] == "OBJECT")
						for (var/j=6, j<=impobjs2.len, j++)
							var/list/tempvars = splittext(impobjs2[j], "=")
							if (tempvars.len == 2)
								if (tempvars[1] == "name")
									tmpobj.name = tempvars[2]
								else if (tempvars[1] == "desc")
									tmpobj.desc = tempvars[2]
								else if (tempvars[1] == "dir")
									tmpobj.dir = text2num(tempvars[2])
								else if (tempvars[1] == "icon_state")
									tmpobj.icon_state = tempvars[2]
/*
				else if (impobjs2[1] == "OBJECT")
					if (!findtext(impobjs2[5],"/obj/map_metadata"))
						var/resultp = text2path(impobjs2[5])
						var/obj/newobj = new resultp(locate(impobjs2[2],impobjs2[3],impobjs2[4]))
						for (var/j=6, j<=impobjs2.len, j++)
							var/list/tempvars = splittext(impobjs2[j], "=")
							if (tempvars.len == 2)
								var/tonum = text2num(tempvars[2])
								if (tonum && isnum(tonum))
									newobj.vars[tempvars[1]] = tonum
								else
									if (tempvars[2] != "EMPTYLIST")
/*
										if (findtext(tempvars[2], "{{"))
											tempvars[2] = replacetext(tempvars[2], "{{", "")
											tempvars[2] = replacetext(tempvars[2], "|}}", "")
											var/list/tempvarslist = splittext(tempvars[2], "|")
											newobj.vars[tempvars[1]] = tempvarslist
										else
											newobj.vars[tempvars[1]] = tempvars[2]
*/
										if (!islist(newobj.vars[tempvars[1]]))
											newobj.vars[tempvars[1]] = tempvars[2]
*/
		world.log << "Imported all objects."
		world.log << "Importing metadata..."
		var/F4 = file("SQL/saves/map.txt")
		if (fexists(F4))
			var/tmpmeta = file2text(F4)
			var/list/tmpmeta_list = splittext(tmpmeta,"\n")
			map.age = tmpmeta_list[2]
			map.ordinal_age = text2num(tmpmeta_list[3])
			map.default_research = text2num(tmpmeta_list[4])
			map.autoresearch = text2num(tmpmeta_list[5])
			map.autoresearch_mult = text2num(tmpmeta_list[6])
			map.chad_mode = text2num(tmpmeta_list[7])
			map.chad_mode_plus = text2num(tmpmeta_list[8])
			map.gamemode = tmpmeta_list[8]
		world.log << "Imported metadata."
		world.log << "Importing global settings..."
		sleep(1)
		world.log << "Finished all imports."