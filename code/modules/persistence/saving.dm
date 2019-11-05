////WORK IN PROGRESS - PERSISTENCE STUFF////
/datum/admins/proc/export()
	set category = "Server"
	set desc="Export Variables"
	set name="Export Savegame"
	var/confirm = WWinput(usr, "Are you sure you want to save the world? SERVER MIGHT FREEZE FOR A WHILE!", "Confirmation Required", "No", list("Yes", "No"))
	if (confirm == "No")
		return
	else
		world << "<big>SAVING THE WORLD IN 10 SECONDS. GAME WILL FREEZE!</big>"
		spawn(100)
			world.log << "Exporting mobs..."
			var/F = file("SQL/saves/mobs.txt")
			if (fexists(F))
				fdel(F)
			for (var/mob/M in mob_list)
				var/txtexport = list2text_assoc_mob(M)
				text2file(txtexport,F)
			world.log << "Finished exporting mobs to [F]."
			sleep(0)
			world.log << "Exporting turfs..."
			var/F1 = file("SQL/saves/turfs.txt")
			if (fexists(F1))
				fdel(F1)
			for (var/turf/T in new_turfs)
				text2file("TURF;[T.x];[T.y];[T.z];[T.type]",F1)
			world.log << "Finished exporting turfs to [F1]."
			sleep(0)
			world.log << "Exporting objs..."
			var/F2 = file("SQL/saves/objs.txt")
			if (fexists(F2))
				fdel(F2)
			for (var/obj/O in world)
				if (!istype(O, /obj/effect/decal))
					var/txtexport = list2text_assoc(O)
					text2file(txtexport,F2)
			world.log << "Finished exporting objs to [F2]."

//used for persistence variable saving. Ignores default values.
/proc/list2text_assoc(var/atom/A)
	. = list()
	if (istype(A, /obj/structure/wild) || (!istype(A, /obj/item) && !istype(A, /obj/structure) && !istype(A, /obj/map_metadata)))
		return "SIMPLE_OBJ;[A.x];[A.y];[A.z];[A.type]"
	else
		for (var/key in A.vars)
			if (A.vars[key] != initial(A.vars[key]))
				if (islist(A.vars[key]))
					if (isemptylist(A.vars[key]))
						. += "[key]=EMPTYLIST"
					else
						. += "[key]={{"
						for(var/i in A.vars[key])
							. += "[i]|"
						. += "}}"
				else
					. += "[key]=[A.vars[key]]"
		return "OBJECT;[A.x];[A.y];[A.z];[A.type];[list2text(.)]"

/proc/list2text_assoc_mob(var/mob/A)
	. = list()
	if (istype(A, /mob/living/carbon/human))
		for (var/key in A.vars)
			if (A.vars[key] != initial(A.vars[key]))
				if (islist(A.vars[key]))
					if (isemptylist(A.vars[key]))
						. += "[key]=EMPTYLIST"
					else
						. += "[key]={{"
						for(var/i in A.vars[key])
							. += "[i]|"
						. += "}}"
				else
					. += "[key]=[A.vars[key]]"
		return "HUMAN;[A.x];[A.y];[A.z];[list2text(.)]"
	else
		return "MOB;[A.x];[A.y];[A.z];[A.type];[A.stat]"
