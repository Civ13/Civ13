////WORK IN PROGRESS - PERSISTENCE STUFF////
/datum/admins/proc/import()
	set category = "Server"
	set desc="Import Variables"
	set name="Import Savegame"

	//dont want this to be used for now
//	return
	//
	var/confirm = WWinput(usr, "Are you sure you want to load the world? SERVER MIGHT FREEZE FOR A WHILE!", "Confirmation Required", "No", list("Yes", "No"))
	if (confirm == "No")
		return
	else
		world.log << "Importing turfs..."
		var/F = file("SQL/saves/turfs.txt")
		if (fexists(F))
			var/tmpturfs = file2text(F)
			var/list/impturfs = splittext(tmpturfs, "\n")
			for (var/i in impturfs)
				var/list/impturfs2 = splittext(i, ";")
				if (impturfs[1] == "TURF")
					var/resultp = text2path(impturfs2[5])
					new resultp(locate(impturfs2[2],impturfs2[3],impturfs2[4]))
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
				if (impmobs2[1] == "MOB" && impmobs2[5] != "/mob/new_player")
					var/resultp = text2path(impmobs2[5])
					var/mob/newmob = new resultp(locate(impmobs2[2],impmobs2[3],impmobs2[4]))
					newmob.stat = impmobs2[6]
				else if (impmobs2[1] == "HUMAN")
					return
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
				var/list/impobjs2 = splittext(i, ";")
				if (impobjs2[1] == "SIMPLE_OBJ" && !findtext(impobjs2[5],"/obj/map_metadata"))
					var/resultp = text2path(impobjs2[5])
					var/mob/newmob = new resultp(locate(impobjs2[2],impobjs2[3],impobjs2[4]))
					newmob.stat = impobjs2[6]
				else if (impobjs2[1] == "OBJECT")
					if (!findtext(impobjs2[5],"/obj/map_metadata"))
						var/resultp = text2path(impobjs2[5])
						var/obj/newobj = new resultp(locate(impobjs2[2],impobjs2[3],impobjs2[4]))
						for (var/j=6, j<=impobjs2.len, j++)
							var/list/tempvars = splittext(impobjs2[j], "=")
							if (isnum(newobj.vars[tempvars[1]]))
								newobj.vars[tempvars[1]] = text2num(tempvars[2])
							else
								if (tempvars[2] == "EMPTYLIST")
									newobj.vars[tempvars[1]] = list()
								else
									if (findtext(tempvars[2], "{{"))
										tempvars[2] = replacetext(tempvars[2], "{{", "")
										tempvars[2] = replacetext(tempvars[2], "|}}", "")
										var/list/tempvarslist = splittext(tempvars[2], "|")
										newobj.vars[tempvars[1]] = tempvarslist
									else
										newobj.vars[tempvars[1]] = tempvars[2]
					else

		world.log << "Imported all objects."
		world.log << "Importing global settings..."
		world.log << "Finished all imports."