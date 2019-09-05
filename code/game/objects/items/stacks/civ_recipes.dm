/*
/////////////////////////////AGES///////////////////////
0-15 Stone Age (?-3000 B.C.)
15-20 Copper Age (3000 BC to 500 B.C.)
20-30 Bronze Age (500 B.C. to 400 A.D.)
30-45 Dark Ages (400 to 700)
45-60 Middle Ages (700 to 1450)
60-80 Renaissance (1450 to 1650)
80-90 Imperial Age (1650 to 1780)
90-100 Napoleonic Age (1780 to 1850)
100-120 Industrial Age (1850 to 1895)
120-147 Early Modern Era (1896 to 1933)
145-175 World War II (1934 to 1957)
175-210 Cold War (1958 to 1984)
210- Modern Era (1985 to 2020)
///////////////////////////////////////////////////////
*/

/material/proc/get_recipes_civs(var/civ = "none", var/mob/living/carbon/human/user, var/forced=FALSE)
	if (map && map.civilizations)
		var/list/current_res = list(0,0,0)
		if ((civ == "Nomad" || map.ID == MAP_TRIBES) && user)
			if (user.civilization == "none")
				current_res = list(map.default_research,map.default_research,map.default_research)
			else
				current_res = map.custom_civs[user.civilization]
		else
			if (civ == "Civilization A Citizen")
				current_res = map.civa_research
			else if (civ == "Civilization B Citizen")
				current_res = map.civb_research
			else if (civ == "Civilization C Citizen")
				current_res = map.civc_research
			else if (civ == "Civilization D Citizen")
				current_res = map.civd_research
			else if (civ == "Civilization E Citizen")
				current_res = map.cive_research
			else if (civ == "Civilization F Citizen")
				current_res = map.civf_research
		generate_recipes_civs(current_res)
	else
		if (!recipes || forced)
			var/list/current_res = list(0,0,0)
			if (map)
				switch (map.ordinal_age)
					if (0)
						current_res = list(0,0,0)
					if (1)
						current_res = list(35,35,35)
					if (2)
						current_res = list(60,60,60)
					if (3)
						current_res = list(85,85,85)
					if (4)
						current_res = list(105,105,105)
					if (5)
						current_res = list(125,125,125)
					if (6)
						current_res = list(152,152,152)
					if (7)
						current_res = list(185,185,185)
					if (8)
						current_res = list(210,210,210)
			generate_recipes_civs(current_res)
	return recipes

/material/proc/generate_recipes_civs(var/list/current_res = list(0,0,0))

	recipes = list()
	if (hardness>=40 && current_res[1] > 8)
		recipes += new/datum/stack_recipe("[display_name] fork", /obj/item/weapon/material/kitchen/utensil/fork, TRUE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name] knife", /obj/item/weapon/material/kitchen/utensil/knife, TRUE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name] spoon", /obj/item/weapon/material/kitchen/utensil/spoon, TRUE, _on_floor = TRUE, _supplied_material = "[name]")
	for(var/i in craftlist_list)
		if(i[1]== "[type]/" && current_res[1]>=text2num(i[9]) && current_res[2]>=text2num(i[10]) && current_res[3]>=text2num(i[11]) && map && map.ordinal_age <= text2num(i[12]))
			var/supmat = i[13]
			if (supmat == "null")
				supmat = null
			if (i[8] == "none")
				recipes += new/datum/stack_recipe(i[2], text2path(i[3]), text2num(i[4]),  _time = text2num(i[5]), _one_per_turf = text2num(i[6]), _on_floor = text2num(i[7]), _supplied_material = supmat)
			else
				var/exists = FALSE
				for (var/datum/stack_recipe_list/A in recipes)
					if (A.title == i[8])
						exists = TRUE
						A.recipes += new/datum/stack_recipe(i[2], text2path(i[3]), text2num(i[4]),  _time = text2num(i[5]), _one_per_turf = text2num(i[6]), _on_floor = text2num(i[7]), _supplied_material = supmat)
				if (!exists)
					recipes += new/datum/stack_recipe_list(i[8], list(new/datum/stack_recipe(i[2], text2path(i[3]), text2num(i[4]),  _time = text2num(i[5]), _one_per_turf = text2num(i[6]), _on_floor = text2num(i[7]), _supplied_material = supmat)))
