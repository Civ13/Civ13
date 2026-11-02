// Frozen startup loop from master397ef71e9; offline compatibility data.
/proc/loader_fixture()
	var/all_craft_lists = flist("config/crafting/")

	for (var/i in all_craft_lists)
		var/current_list = "global"
		var/F3 = file("config/crafting/[i]")
		current_list = replacetext(i,"material_recipes_","")
		current_list = replacetext(current_list,".txt","")
		if (fexists(F3) && findtext(i,"material_recipes"))
			var/list/craftlist_temp = file2list(F3,"\n")
			for (var/j in craftlist_temp)
				if (findtext(j, ",") && findtext(j,"RECIPE: ") && !(findtext(j,"//")))
					var/tmpj = replacetext(j, "RECIPE: ", "")
					var/list/current = splittext(tmpj, ",")
					craftlist_lists[current_list] += list(current)
					if (current.len != 13)
						world.log << "Error! Recipe [current[2]] has a length of [current.len] (should be 13) ([current_list])."
		else
			admin_notice("<span class='danger'>Failed to load crafting recipes!</span>", R_DEBUG)
