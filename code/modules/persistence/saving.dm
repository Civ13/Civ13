////WORK IN PROGRESS - PERSISTENCE STUFF////
/datum/admins/proc/export_savegame()
	set category = "Server"
	set desc="Export Variables"
	set name="Export Savegame"
	var/confirm = WWinput(usr, "Are you sure you want to save the world? SERVER MIGHT FREEZE FOR A WHILE!", "Confirmation Required", "No", list("Yes", "No"))
	if (confirm == "No")
		return
	else
		do_export()
		return

//used for persistence variable saving. Ignores default values.
/proc/list2text_assoc(var/atom/A)
	. = list()
	if (istype(A, /obj/structure/wild) || (!istype(A, /obj/item) && !istype(A, /obj/structure) && !istype(A, /obj/map_metadata)&& !istype(A, /obj/covers)))
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
	if (istype(A, /mob/living/human))
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

/obj/map_metadata/proc/savegame()
	spawn(27000)
		do_export()
		savegame()

/proc/do_export()
	world << "<i><b>Saving the game... Might lag for a few seconds.</b></i>"
	var/F0 = file("SQL/saves/map.txt")
	if (fexists(F0))
		fcopy(F0,file("SQL/saves/old/map.txt"))
		fdel(F0)
	var/F = file("SQL/saves/mobs.txt")
	if (fexists(F))
		fcopy(F,file("SQL/saves/old/mobs.txt"))
		fdel(F)
	var/F1 = file("SQL/saves/turfs.txt")
	if (fexists(F1))
		fcopy(F1,file("SQL/saves/old/turfs.txt"))
		fdel(F1)
	var/F2 = file("SQL/saves/objs.txt")
	if (fexists(F2))
		fcopy(F2,file("SQL/saves/old/objs.txt"))
		fdel(F2)
	world.log << "Started saving at [time2text(world.realtime,"YYYY-MM-DD-(hh-mm-ss)")]."
	spawn(10)
		world.log << "Exporting metadata..."
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
		world.log << "Exporting mobs..."
		for (var/mob/M in mob_list)
			var/txtexport = list2text_assoc_mob(M)
			text2file(txtexport,F)
		sleep(0)
		world.log << "Exporting turfs..."
		for (var/turf/T in new_turfs)
			text2file("TURF;[T.x];[T.y];[T.z];[T.type]",F1)
		sleep(0)
		world.log << "Exporting objs..."
		for (var/obj/O in world)
			if (!istype(O, /obj/effect/decal) && !istype(O, /obj/screen))
				var/txtexport = list2text_assoc(O)
				text2file(txtexport,F2)
	sleep(1)
	world.log << "Finished saving at [time2text(world.realtime,"YYYY-MM-DD-(hh-mm-ss)")]."
	world << "<i><b>Finished saving.</b></i>"
	return