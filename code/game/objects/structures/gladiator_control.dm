////////////Things related to gladiator mode: ledgers, match controls, beds for saving

//////////////////////////////////////////////////////////////
//////////////////////SCORE/LEDGER////////////////////////////
//////////////////////////////////////////////////////////////
/obj/structure/gladiator_ledger
	name = "gladiatorial ledger"
	desc = "A board showing the victories of all gladiators."
	icon = 'icons/obj/structures.dmi'
	icon_state = "nboard00"
	density = FALSE
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/arena_name = "Arena I"
	var/timer = 0
	var/list/toplist = list()
	var/showing = "Characters"

/obj/structure/gladiator_ledger/attack_hand(mob/user as mob)
	if (map.ID == MAP_GLADIATORS)
		var/obj/map_metadata/gladiators/GD = map
		if (istype(user, /mob/living/human))
			var/mob/living/human/H = user
			if (H.original_job_title == "Imperator" && timer <= world.time && H.client.ckey == "taislin")
				var/list/vlist = list("Cancel")
				for(var/mob/living/human/GLAD in world)
					var/area/A = get_area(GLAD)
					if (GLAD.original_job_title == "Gladiator" && GLAD.stat != DEAD && GLAD.client && A.name == arena_name)
						vlist += "[GLAD.name], [GLAD.client.ckey]"
				var/choice = WWinput(user, "Who to assign a victory point to?", "Match Results", "Cancel", vlist)
				if (choice == "Cancel" || vlist.len == 1)
					show_content(user)
				else
					var/list/splitdata = splittext(choice, ", ")
					var/done = FALSE
					for (var/i = 1, i <= GD.gladiator_stats.len, i++)
						if (GD.gladiator_stats[i][1] == splitdata[2] && GD.gladiator_stats[i][2] == splitdata[1] && GD.gladiator_stats[i][4] == 0)
							GD.gladiator_stats[i][5]++
							done = TRUE
							continue
					if (!done)
						var/statlist = "1,1,1,1,1,1,1,1,1,1"
						for(var/mob/living/human/GLAD1 in world)
							if (GLAD1.original_job_title == "Gladiator" && GLAD1.stat != DEAD && GLAD1.client && GLAD1.name ==splitdata[1] && GLAD1.client.ckey==splitdata[2])
								statlist = "[GLAD1.stats["strength"][1]],[GLAD1.stats["crafting"][1]],[GLAD1.stats["rifle"][1]],[GLAD1.stats["dexterity"][1]],[GLAD1.stats["swords"][1]],[GLAD1.stats["pistol"][1]],[GLAD1.stats["bows"][1]],[GLAD1.stats["medical"][1]],[GLAD1.stats["philosophy"][1]],[GLAD1.stats["machinegun"][1]],[GLAD1.stats["stamina"][1]]"
						GD.gladiator_stats += list(list(splitdata[2],splitdata[1],statlist,0,1,1))
					timer = world.time + 600
					world << "<big>[splitdata[1]] ([splitdata[2]]) was victorious!</big>"
					GD.save_gladiators()
			else
				show_content(user)
		else
			show_content(user)
	else
		return


/obj/structure/gladiator_ledger/examine(mob/user)
	..()
	if (in_range(user, src) || isghost(user))
		show_content(usr)
	return

/obj/structure/gladiator_ledger/proc/show_content(mob/user as mob)
	if (map.ID == MAP_GLADIATORS)
		var/obj/map_metadata/gladiators/GD = map
		toplist = list()
		if (!GD.gladiator_stats.len)
			return
		var/body = "<html><head><title>GLADIATORIAL LEDGER</title></head><b>GLADIATORIAL LEDGER</b><br><br>"
		switch(showing)
			if ("Characters")
				body += "<b>Characters</b> | <a href='?src=\ref[src];players=1'>Players</a><br><hr><br>"
				var/list/playerlist_ord = list()
				var/list/newtoplist = list()
				for (var/i = 1, i <= GD.gladiator_stats.len, i++)
					//														alive?						ckey						name						victories						matches
					toplist["[GD.gladiator_stats[i][2]]"] = list(text2num(GD.gladiator_stats[i][4]), GD.gladiator_stats[i][1], GD.gladiator_stats[i][2], text2num(GD.gladiator_stats[i][5]),text2num(GD.gladiator_stats[i][6]))
					playerlist_ord["[GD.gladiator_stats[i][2]]"] = text2num(GD.gladiator_stats[i][5])
				newtoplist = sortTim(playerlist_ord, /proc/cmp_numeric_dsc,TRUE)
				for (var/i in newtoplist)
					var/WR = ""
					if (toplist[i][5]!=0)
						WR = "[toplist[i][4]/toplist[i][5]*100]"
					if (toplist[i][1] == 0)
						body += "<b>[toplist[i][3]]</b> ([toplist[i][2]])</b>: <b>[toplist[i][4]]</b> victories in <b>[toplist[i][5]]</b> matches. W/R: <b>[WR]%</b></br>"
					else
						body += "<b>[toplist[i][3]]</b> ([toplist[i][2]]) <font color='red'><i>DECEASED</i></font>: <b>[toplist[i][4]]</b> victories in <b>[toplist[i][5]]</b> matches. W/R: <b>[WR]%</b></br>"

			if ("Players")
				body += "<a href='?src=\ref[src];characters=1'>Characters</a> | <b>Players</b><br><hr><br>"
				var/list/ckeylist = list()
				var/list/ckeylist_ord = list("n" = 0)
				var/list/newtoplist = list()
				for (var/i = 1, i <= GD.gladiator_stats.len, i++)
					if (ckeylist["[GD.gladiator_stats[i][1]]"])
						ckeylist["[GD.gladiator_stats[i][1]]"][1] += text2num(GD.gladiator_stats[i][5])
						ckeylist["[GD.gladiator_stats[i][1]]"][2] += text2num(GD.gladiator_stats[i][6])
						ckeylist_ord["[GD.gladiator_stats[i][1]]"] += text2num(GD.gladiator_stats[i][5])
					else
						ckeylist["[GD.gladiator_stats[i][1]]"] = list(text2num(GD.gladiator_stats[i][5]),text2num(GD.gladiator_stats[i][6]),"[GD.gladiator_stats[i][1]]")
						ckeylist_ord["[GD.gladiator_stats[i][1]]"] = text2num(GD.gladiator_stats[i][5])
				newtoplist = sortTim(ckeylist_ord, /proc/cmp_numeric_dsc,TRUE)
				for (var/ii in newtoplist)
					if (ckeylist[ii])
						var/WR = ""
						if (text2num(ckeylist[ii][2]) != 0)
							WR = "[text2num(ckeylist[ii][1])/text2num(ckeylist[ii][2])*100]"
						body += "<b>[ii]</b>: <b>[ckeylist[ii][1]]</b> victories in <b>[ckeylist[ii][2]]</b> matches. W/R: <b>[WR]%</b></br>"

		body += {"<br>
			</body></html>
		"}
		usr << browse(body,"window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=700x500")
	else
		return

/obj/structure/gladiator_ledger/Topic(href, href_list, hsrc)
	var/mob/user = usr

	if (!user)
		return
	if (href_list["characters"])
		showing = "Characters"
	if (href_list["players"])
		showing = "Players"
	show_content(user)
////////////////////////////////////////////////////////////////////
/////////////////////////////AUTO GLADIATOR CONTROL/////////////////
////////////////////////////////////////////////////////////////////

//Basically, this sets up the combats and winners when there's no Emperor.
//The emperor can also set it to auto if he has to go AFK or something.
/obj/structure/gladiator_control
	name = "gladiator combat organizer"
	desc = "A board showing the planned combats of the season."
	icon = 'icons/obj/structures.dmi'
	icon_state = "nboard05"
	density = FALSE
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE

	var/active_emperor = FALSE
	var/arena = "Arena I"

	var/combat_running = FALSE
	var/current_style = "1 vs 1"
	var/current_participants = 0
	var/automode = FALSE

	var/cooldown_timer = 0

	var/list/team1 = list()
	var/list/team2 = list()

	var/count_max = 2
	var/victory_min = 1
	var/teams = FALSE
	var/count = 0
/obj/structure/gladiator_control/New()
	..()
	spawn(1200)
		run_proc()

/obj/structure/gladiator_control/proc/pick_combat()
	if (human_clients_mob_list.len <= 8)
		current_style = "1 vs 1"
		return
	else if (human_clients_mob_list.len > 8 && human_clients_mob_list.len <= 16)
		current_style = pick("1 vs 1","2 vs 2","4 people free-for-all")
		return
	else
		current_style = pick("1 vs 1","2 vs 2","4 people free-for-all","6 people free-for-all")
		return

/obj/structure/gladiator_control/proc/run_proc()
	active_emperor = FALSE
/*
	for(var/mob/living/human/EMP in world)
		if (EMP.original_job_title == "Imperator" && EMP.stat == CONSCIOUS)
			active_emperor = TRUE
		else
			active_emperor = FALSE
*/
	if (!active_emperor || automode)
		if (combat_running == 1)
			prepare_combat()
		else if (combat_running == 0)
			if (world.time > cooldown_timer)
				pick_combat()
				combat_running = TRUE
				world << "<font size=3 color='yellow'>The next combat at the [arena] is going to be a <b>[current_style] match</b>!</font>"
		else if (combat_running == 2)
			check_combat()
	spawn(10)
		run_proc()

/obj/structure/gladiator_control/proc/prepare_combat()
	count = 0

	team1 = list()
	team2 = list()

	switch(current_style)
		if("1 vs 1")
			count_max = 2
			victory_min = 1
			teams = FALSE
		if("4 people free-for-all")
			count_max = 4
			victory_min = 1
			teams = FALSE
		if("6 people free-for-all")
			count_max = 6
			victory_min = 1
			teams = FALSE
		if("2 vs 2")
			count_max = 4
			victory_min = 2
			teams = TRUE
	var/area/A = get_area_name(arena)
	for(var/mob/living/human/GLAD in A)
		if (GLAD.original_job_title == "Gladiator" && GLAD.stat == CONSCIOUS)//&& GLAD.client)
			count++
	if (count == count_max)
		combat_running = 2
		var/obj/map_metadata/gladiators/G = map
		switch(arena)
			if ("Arena I")
				G.gracedown1 = FALSE
			if ("Arena II")
				G.gracedown2 = FALSE
			if ("Arena III")
				G.gracedown3 = FALSE
			if ("Arena IV")
				G.gracedown4 = FALSE
		world << "<font size=3 color='yellow'>The combat has started at <b>[arena]</b>!</font>"
		if (!teams)
			var/list/currlist = list()
			for(var/mob/living/human/H in A)
				if (H.original_job_title == "Gladiator" && H.stat == CONSCIOUS)
					currlist += H.name
			for(var/i = 1, i <= G.gladiator_stats.len, i++)
				if (G.gladiator_stats[i][2] in currlist)
					G.gladiator_stats[i][6]++
			var/flist = ""
			for(var/i=1,i<=currlist.len,i++)
				flist += "[currlist[i]], "
			flist += "."
			flist = replacetext(flist,", .",".")
			world << "<font size=2 color='yellow'>Fighters: [flist]</font>"
		else
			for(var/mob/living/human/H in A)
				if (H.original_job_title == "Gladiator" && H.stat == CONSCIOUS)
					if (team1.len < victory_min)
						team1 += H
					else
						team2 += H
				for(var/i = 1, i <= G.gladiator_stats.len, i++)
					if (G.gladiator_stats[i][2] == H)
						G.gladiator_stats[i][6]++
			var/flist = "Team 1: "
			for(var/i=1,i<=team1.len,i++)
				flist += "[team1[i]], "
			flist += ".<br> Team 2:"
			for(var/i=1,i<=team2.len,i++)
				flist += "[team2[i]], "
			flist = replacetext(flist,", .",".")
			world << "<font size=2 color='yellow'>[flist]</font>"

		for(var/obj/structure/gate/GATES in A)
			playsound(GATES, 'sound/effects/castle_gate.ogg', 100)
			GATES.icon_state = "s_gate_closing"
			GATES.density = TRUE
			spawn(30)
				GATES.icon_state = "s_gate0"
		for(var/obj/structure/simple_door/key_door/ancient/roman/DOORS in A)
			if (DOORS.state)
				DOORS.density = TRUE
				DOORS.Close()
		return
	else if (count > count_max && prob(10))
		world << "<font size=2 color='yellow'>Too many people at [arena]. There should be a maximum of <b>[count_max]</b>!</font>"
		return
	return

/obj/structure/gladiator_control/proc/check_combat()
	var/obj/map_metadata/gladiators/GD = map
	var/area/A = get_area_name(arena)
	var/count = 0
	for(var/mob/living/human/GLAD in A)
		if (GLAD.original_job_title == "Gladiator" && GLAD.stat == CONSCIOUS && !GLAD.surrendered)
			count++
	if (count == 1)
		var/mob/living/human/WINNER
		for(var/mob/living/human/GLAD in A)
			if (GLAD.original_job_title == "Gladiator" && GLAD.stat == CONSCIOUS && !GLAD.surrendered)
				WINNER = GLAD
		for(var/obj/structure/gate/GATES in A)
			playsound(GATES, 'sound/effects/castle_gate.ogg', 100)
			GATES.icon_state = "s_gate_opening"
			GATES.density = FALSE
			spawn(30)
				GATES.icon_state = "s_gate1"
		combat_running = 0
		if (!WINNER)
			return
		var/done = FALSE
		for (var/i = 1, i <= GD.gladiator_stats.len, i++)
			if (GD.gladiator_stats[i][1] == WINNER.client.ckey && GD.gladiator_stats[i][2] == WINNER.name && GD.gladiator_stats[i][4] == 0)
				GD.gladiator_stats[i][5]++
				done = TRUE
				continue
		if (!done && WINNER.client)
			var/statlist = "[WINNER.stats["strength"][1]],[WINNER.stats["crafting"][1]],[WINNER.stats["rifle"][1]],[WINNER.stats["dexterity"][1]],[WINNER.stats["swords"][1]],[WINNER.stats["pistol"][1]],[WINNER.stats["bows"][1]],[WINNER.stats["medical"][1]],[WINNER.stats["philosophy"][1]],[WINNER.stats["machinegun"][1]],[WINNER.stats["stamina"][1]]"
			GD.gladiator_stats += list(list(WINNER.client.ckey,WINNER.name,statlist,0,1,1))

		GD.save_gladiators()
		world << "<font size=3 color='yellow'>The combat in [arena] has ended! [WINNER] ([WINNER.client.ckey]) was victorious!</font>"
		switch(arena)
			if ("Arena I")
				GD.gracedown1 = TRUE
			if ("Arena II")
				GD.gracedown2 = TRUE
			if ("Arena III")
				GD.gracedown3 = TRUE
			if ("Arena IV")
				GD.gracedown4 = TRUE
		cooldown_timer = world.time+300
		spawn(60)
			for(var/obj/structure/functions/clean_arena1/CA1 in A)
				CA1.clean_proc_nomob()
		return

	else if (count == victory_min && victory_min > 1)
		for(var/mob/living/human/HH in team1)
			if (HH.stat != CONSCIOUS || HH.surrendered)
				team1 -= HH
		for(var/mob/living/human/HM in team2)
			if (HM.stat != CONSCIOUS || HM.surrendered)
				team2 -= HM
		if((team1.len == 0 && team2.len > 0) || (team2.len == 0 && team1.len > 0))
			var/list/winnerlist = list()
			for(var/mob/living/human/GLAD in A)
				if (GLAD.original_job_title == "Gladiator" && GLAD.stat == CONSCIOUS && !GLAD.surrendered)
					winnerlist += GLAD
			for (var/mob/living/human/k in winnerlist)
				var/done = FALSE
				for (var/i = 1, i <= GD.gladiator_stats.len, i++)
					if (GD.gladiator_stats[i][1] == k.client.ckey && GD.gladiator_stats[i][2] == k.name && GD.gladiator_stats[i][4] == 0)
						GD.gladiator_stats[i][5]++
						done = TRUE
						continue
				if (!done && k.client)
					var/statlist = "[k.stats["strength"][1]],[k.stats["crafting"][1]],[k.stats["rifle"][1]],[k.stats["dexterity"][1]],[k.stats["swords"][1]],[k.stats["pistol"][1]],[k.stats["bows"][1]],[k.stats["medical"][1]],[k.stats["philosophy"][1]],[k.stats["machinegun"][1]],[k.stats["stamina"][1]]"
					GD.gladiator_stats += list(list(k.client.ckey,k.name,statlist,0,1,1))
			GD.save_gladiators()

			var/flist = ""
			for(var/mob/living/human/H in winnerlist)
				flist += "[H] ([H.client.ckey]), "
			flist += "."
			flist = replacetext(flist,", .",".")
			world << "<font size=3 color='yellow'>The combat in [arena] has ended! Winners: [flist]</font>"

		for(var/obj/structure/gate/GATES in A)
			playsound(GATES, 'sound/effects/castle_gate.ogg', 100)
			GATES.icon_state = "s_gate_opening"
			GATES.density = FALSE
			spawn(30)
				GATES.icon_state = "s_gate1"
		combat_running = 0
		switch(arena)
			if ("Arena I")
				GD.gracedown1 = TRUE
			if ("Arena II")
				GD.gracedown2 = TRUE
			if ("Arena III")
				GD.gracedown3 = TRUE
			if ("Arena IV")
				GD.gracedown4 = TRUE
		cooldown_timer = world.time+300
		spawn(60)
			for(var/obj/structure/functions/clean_arena1/CA1 in A)
				CA1.clean_proc_nomob()
		return
/*
/obj/structure/gladiator_control/attack_hand(mob/user as mob)
	if (map.ID == MAP_GLADIATORS)
		if (istype(user, /mob/living/human))
			var/mob/living/human/H = user
			if (H.original_job_title == "Imperator")
				var/choice = WWinput(user,"Do you want to toggle the auto-matchmaking [automode ? "off" : "on"]?","Auto-matchmaking mode","Yes",list("Yes","No"))
				if (choice == "No")
					return
				else
					automode = !automode
					user << "<font size=2 color='yellow'>Auto-Matchmaking mode turned <b>[automode ? "ON" : "OFF"]</b>.</font>"
					return
*/
/obj/structure/gladiator_control/ranged
	current_style = "ranged"
/obj/structure/gladiator_control/ranged/pick_combat()
	current_style = pick("ranged")
	return

/obj/structure/gladiator_control/ranged/prepare_combat()
	count = 0
	count_max = 2
	victory_min = 1
	teams = FALSE

	var/obj/map_metadata/gladiators/G = map
	var/area/A = get_area_name(arena)

	for(var/mob/living/human/GLAD in A)
		if (GLAD.original_job_title == "Gladiator" && GLAD.stat == CONSCIOUS)//&& GLAD.client)
			count++

	if (count == count_max)
		combat_running = 2
		switch(arena)
			if ("Arena I")
				G.gracedown1 = FALSE
			if ("Arena II")
				G.gracedown2 = FALSE
			if ("Arena III")
				G.gracedown3 = FALSE
			if ("Arena IV")
				G.gracedown4 = FALSE

		world << "<font size=3 color='yellow'>The [current_style] combat has started at <b>[arena]</b>!</font>"
		var/list/currlist = list()
		for(var/mob/living/human/H in A)
			if (H.original_job_title == "Gladiator" && H.stat == CONSCIOUS)
				currlist += H.name
		for(var/i = 1, i <= G.gladiator_stats.len, i++)
			if (G.gladiator_stats[i][2] in currlist)
				G.gladiator_stats[i][6]++
		var/flist = ""
		for(var/i=1,i<=currlist.len,i++)
			flist += "[currlist[i]], "
		flist += "."
		flist = replacetext(flist,", .",".")
		world << "<font size=2 color='yellow'>Fighters: [flist]</font>"
		return
	else if (count > count_max && prob(10))
		world << "<font size=2 color='yellow'>Too many people at [arena]. There should be a maximum of <b>[count_max]</b>!</font>"
		return
	return

/obj/structure/gladiator_control/ranged/check_combat()
	var/obj/map_metadata/gladiators/GD = map
	var/area/A = get_area_name(arena)

	var/mob/living/human/WINNER
	var/count = 0
	for(var/mob/living/human/GLAD in A)
		if (GLAD.original_job_title == "Gladiator" && GLAD.stat == CONSCIOUS && !GLAD.surrendered)
			count++
	if (count == 1)
		for(var/mob/living/human/GLAD in A)
			if (GLAD.original_job_title == "Gladiator" && GLAD.stat == CONSCIOUS && !GLAD.surrendered)
				WINNER = GLAD
			if (!WINNER)
				return
			var/done = FALSE
			for (var/i = 1, i <= GD.gladiator_stats.len, i++)
				if (GD.gladiator_stats[i][1] == WINNER.client.ckey && GD.gladiator_stats[i][2] == WINNER.name && GD.gladiator_stats[i][4] == 0)
					GD.gladiator_stats[i][5]++
					done = TRUE
					continue
			if (!done && WINNER.client)
				var/statlist = "[WINNER.stats["strength"][1]],[WINNER.stats["crafting"][1]],[WINNER.stats["rifle"][1]],[WINNER.stats["dexterity"][1]],[WINNER.stats["swords"][1]],[WINNER.stats["pistol"][1]],[WINNER.stats["bows"][1]],[WINNER.stats["medical"][1]],[WINNER.stats["philosophy"][1]],[WINNER.stats["machinegun"][1]],[WINNER.stats["stamina"][1]]"
				GD.gladiator_stats += list(list(WINNER.client.ckey,WINNER.name,statlist,0,1,1))

			GD.save_gladiators()
			combat_running = 0
			world << "<font size=3 color='yellow'>The [current_style] match in [arena] has ended! [WINNER] ([WINNER.client.ckey]) was victorious!</font>"
			var/obj/map_metadata/gladiators/G = map

			switch(arena)
				if ("Arena I")
					G.gracedown1 = TRUE
				if ("Arena II")
					G.gracedown2 = TRUE
				if ("Arena III")
					G.gracedown3 = TRUE
				if ("Arena IV")
					G.gracedown4 = TRUE

			cooldown_timer = world.time+300
			spawn(60)
				for(var/obj/structure/functions/clean_arena1/CA1 in A)
					CA1.clean_proc_nomob()
			return
		return

/obj/structure/gladiator_control/wrestling
	var/timer = 10
	current_style = "unarmed"

/obj/structure/gladiator_control/wrestling/pick_combat()
	current_style = pick("unarmed","wrestling")
	return

/obj/structure/gladiator_control/wrestling/prepare_combat()
	count = 0
	count_max = 2
	victory_min = 1
	teams = FALSE

	var/obj/map_metadata/gladiators/G = map
	var/area/A = get_area_name(arena)
	var/area/B = get_area_name("Arena IV outer ring")

	for(var/mob/living/human/GLAD in A)
		if (GLAD.original_job_title == "Gladiator" && GLAD.stat == CONSCIOUS)//&& GLAD.client)
			count++
	for(var/mob/living/human/GLAD in B)
		if (GLAD.original_job_title == "Gladiator" && GLAD.stat == CONSCIOUS)//&& GLAD.client)
			count++
	if (count == count_max)
		combat_running = 2
		switch(arena)
			if ("Arena I")
				G.gracedown1 = FALSE
			if ("Arena II")
				G.gracedown2 = FALSE
			if ("Arena III")
				G.gracedown3 = FALSE
			if ("Arena IV")
				G.gracedown4 = FALSE

		world << "<font size=3 color='yellow'>The [current_style] combat has started at <b>[arena]</b>!</font>"
		var/list/currlist = list()
		for(var/mob/living/human/H in A)
			if (H.original_job_title == "Gladiator" && H.stat == CONSCIOUS)
				currlist += H.name
		for(var/i = 1, i <= G.gladiator_stats.len, i++)
			if (G.gladiator_stats[i][2] in currlist)
				G.gladiator_stats[i][6]++
		var/flist = ""
		for(var/i=1,i<=currlist.len,i++)
			flist += "[currlist[i]], "
		flist += "."
		flist = replacetext(flist,", .",".")
		world << "<font size=2 color='yellow'>Fighters: [flist]</font>"
		return
	else if (count > count_max && prob(10))
		world << "<font size=2 color='yellow'>Too many people at [arena]. There should be a maximum of <b>[count_max]</b>!</font>"
		return
	return

/obj/structure/gladiator_control/wrestling/check_combat()
	var/obj/map_metadata/gladiators/GD = map
	var/area/A = get_area_name(arena)
	var/area/B = get_area_name("Arena IV outer ring")
	var/turf/TGT = pick_area_turf(/area/caribbean/roman/armory/loot2)
	var/mob/living/human/WINNER
	var/count = 0
	for(var/mob/living/human/GLAD in A)
		GLAD.strip_nobasics(TGT, TRUE)
		if (GLAD.original_job_title == "Gladiator" && GLAD.stat == CONSCIOUS && !GLAD.surrendered)
			if (current_style == "wrestling" && !GLAD.lying && !GLAD.scrambling && !GLAD.prone)
				count++
			else if (current_style == "unarmed")
				count++
	for(var/obj/item/I in A)
		I.loc = TGT
	for(var/obj/item/II in B)
		II.loc = TGT
	if (current_style == "unarmed")
		for(var/mob/living/human/GLAD in B)
			if (GLAD.original_job_title == "Gladiator" && GLAD.stat == CONSCIOUS && !GLAD.surrendered)
				count++
	if (count == 1)
		for(var/mob/living/human/GLAD in A)
			if (GLAD.original_job_title == "Gladiator" && GLAD.stat == CONSCIOUS && !GLAD.surrendered)
				WINNER = GLAD
		if (current_style == "unarmed")
			for(var/mob/living/human/GLAD in B)
				if (GLAD.original_job_title == "Gladiator" && GLAD.stat == CONSCIOUS && !GLAD.surrendered)
					WINNER = GLAD
		timer--
		visible_message("<font size=1 color='yellow'>[arena]: Counter at [timer]...</font>")
		if (timer < 1)
			timer = 5
			combat_running = 0
			if (!WINNER)
				return
			var/done = FALSE
			for (var/i = 1, i <= GD.gladiator_stats.len, i++)
				if (GD.gladiator_stats[i][1] == WINNER.client.ckey && GD.gladiator_stats[i][2] == WINNER.name && GD.gladiator_stats[i][4] == 0)
					GD.gladiator_stats[i][5]++
					done = TRUE
					continue
			if (!done && WINNER.client)
				var/statlist = "[WINNER.stats["strength"][1]],[WINNER.stats["crafting"][1]],[WINNER.stats["rifle"][1]],[WINNER.stats["dexterity"][1]],[WINNER.stats["swords"][1]],[WINNER.stats["pistol"][1]],[WINNER.stats["bows"][1]],[WINNER.stats["medical"][1]],[WINNER.stats["philosophy"][1]],[WINNER.stats["machinegun"][1]],[WINNER.stats["stamina"][1]]"
				GD.gladiator_stats += list(list(WINNER.client.ckey,WINNER.name,statlist,0,1,1))

			GD.save_gladiators()
			world << "<font size=3 color='yellow'>The [current_style] match in [arena] has ended! [WINNER] ([WINNER.client.ckey]) was victorious!</font>"
			var/obj/map_metadata/gladiators/G = map
			switch(arena)
				if ("Arena I")
					G.gracedown1 = TRUE
				if ("Arena II")
					G.gracedown2 = TRUE
				if ("Arena III")
					G.gracedown3 = TRUE
				if ("Arena IV")
					G.gracedown4 = TRUE

			cooldown_timer = world.time+300
			spawn(60)
				for(var/obj/structure/functions/clean_arena1/CA1 in A)
					CA1.clean_proc_nomob()
			return
	else
		timer = 10
		return
////////////////////////////////////////////////////////////////////////////////
//////////////////////////////CLEANERS//////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

/obj/structure/functions/clean_arena1
	name = "Clean Arena"
	desc = "Clean the arena deleting bodies and moving equipment to the armory."
	var/arena = "Arena I"
	New()
		..()
		name = "Clear [arena]"
/obj/structure/functions/clean_arena1/attack_hand(mob/living/user)
	clean_proc(user)
/obj/structure/functions/clean_arena1/proc/clean_proc(mob/living/user)
	if (user)
		if (!istype(user, /mob/living/human))
			return
		else
			var/area/A = get_area(src.loc)
			for (var/mob/living/human/H in A)
				if (H.stat == DEAD)
					H.strip(H.loc,TRUE)
					qdel(H)
			for (var/obj/item/I in A)
				if (istype(I, /obj/item/organ) || istype(I,/obj/item/weapon/material/shard) || istype(I, /obj/item/weapon/reagent_containers/food))
					qdel(I)
				else
					I.loc = pick_area_turf(/area/caribbean/roman/armory/loot)
			for (var/obj/effect/decal/cleanable/C in A)
				qdel(C)
			if (A.name == "Arena IV")
				var/area/B = get_area_name("Arena IV outer ring")
				for (var/mob/living/human/H in B)
					if (H.stat == DEAD)
						H.strip(H.loc,TRUE)
						qdel(H)
				for (var/obj/item/I in B)
					if (istype(I, /obj/item/organ) || istype(I,/obj/item/weapon/material/shard) || istype(I, /obj/item/weapon/reagent_containers/food))
						qdel(I)
					else
						I.loc = pick_area_turf(/area/caribbean/roman/armory/loot)
				for (var/obj/effect/decal/cleanable/C in B)
					qdel(C)
	if (user)
		user << "[arena] cleared."
	return
/obj/structure/functions/clean_arena1/proc/clean_proc_nomob()
	var/area/A = get_area(src.loc)
	for (var/mob/living/human/H in A)
		if (H.stat == DEAD)
			H.strip(H.loc,TRUE)
			qdel(H)
	for (var/obj/item/I in A)
		if (istype(I, /obj/item/organ) || istype(I,/obj/item/weapon/material/shard) || istype(I, /obj/item/weapon/reagent_containers/food))
			qdel(I)
		else
			I.loc = pick_area_turf(/area/caribbean/roman/armory/loot)
	for (var/obj/effect/decal/cleanable/C in A)
		qdel(C)
	if (A.name == "Arena IV")
		var/area/B = get_area_name("Arena IV outer ring")
		for (var/mob/living/human/H in B)
			if (H.stat == DEAD)
				H.strip(H.loc,TRUE)
				qdel(H)
		for (var/obj/item/I in B)
			if (istype(I, /obj/item/organ) || istype(I,/obj/item/weapon/material/shard) || istype(I, /obj/item/weapon/reagent_containers/food) || istype(I,/obj/item/clothing/shoes/roman) || istype(I,/obj/item/clothing/under/celtic_green) || istype(I,/obj/item/clothing/under/celtic_red) || istype(I,/obj/item/clothing/under/celtic_blue))
				qdel(I)
			else
				I.loc = pick_area_turf(/area/caribbean/roman/armory/loot)
		for (var/obj/effect/decal/cleanable/C in B)
			qdel(C)
	return

/////////////////////////////////////////////////////
///////////////////SAVING BEDS///////////////////////
/////////////////////////////////////////////////////

//For gladiator mode
/obj/structure/bed/saving
	material = "wood"

/obj/structure/bed/saving/attack_hand(mob/living/human/user as mob)
	if (!istype(user, /mob/living/human))
		return
	if (!user.client)
		return
	if (user.original_job_title != "Gladiator")
		return
	if ((user.getOxyLoss() + user.getToxLoss() + user.getFireLoss() + user.getBruteLoss() > 35))
		user << "You are too damaged to save your character. Get surgery first."
		return
	var/choice = WWinput(user, "Do you want to save this character named [user.name]?", "Character Saving", "Yes", list("Yes","No"))
	if (choice == "No")
		return
	else
		var/done = FALSE
		var/obj/map_metadata/gladiators/GD = null
		if (istype(map, /obj/map_metadata/gladiators))
			GD = map
		if (!GD)
			return
		for (var/i = 1, i <= GD.gladiator_stats.len, i++)
			if (user && user.client && GD.gladiator_stats[1][1] == user.client.ckey && GD.gladiator_stats[1][2] == user.name && !done)
				var/statlist = "[user.stats["strength"][1]],[user.stats["crafting"][1]],[user.stats["rifle"][1]],[user.stats["dexterity"][1]],[user.stats["swords"][1]],[user.stats["pistol"][1]],[user.stats["bows"][1]],[user.stats["medical"][1]],[user.stats["philosophy"][1]],[user.stats["machinegun"][1]],[user.stats["stamina"][1]]"
				GD.gladiator_stats[1][3] = statlist
				done = TRUE
				GD.save_gladiators()
				qdel(user)
				user << "Saved sucessfully."
				return
		if (done == FALSE && user.client)
			var/statlist = "[user.stats["strength"][1]],[user.stats["crafting"][1]],[user.stats["rifle"][1]],[user.stats["dexterity"][1]],[user.stats["swords"][1]],[user.stats["pistol"][1]],[user.stats["bows"][1]],[user.stats["medical"][1]],[user.stats["philosophy"][1]],[user.stats["machinegun"][1]],[user.stats["stamina"][1]]"
			GD.gladiator_stats += list(list(user.client.ckey, user.name, statlist, 0,0,0))
			GD.save_gladiators()
			qdel(user)
			user << "Saved sucessfully."
			return

/////////////////////////////////////////////////////////////
////////////////PROFILE/LOADING/PROC/////////////////////////
/////////////////////////////////////////////////////////////
/mob/living/human/proc/check_profiles()
	spawn(10)
		if (map.ID == MAP_GLADIATORS && client)
			var/obj/map_metadata/gladiators/GD = map
			var/done = FALSE
			var/list/loadinglist = list("Cancel")
			if (GD.gladiator_stats.len && client)
				for (var/i = 1, i <= GD.gladiator_stats.len, i++)
					if (GD.gladiator_stats[i][1] == client.ckey && GD.gladiator_stats[i][4] == 0)
						loadinglist += GD.gladiator_stats[i][2]
						done = TRUE
			if (done == TRUE)
				var/input_msg = WWinput(src, "Welcome, [client.ckey]. Do you want to load any of your Gladiators?", "Load Gladiators", "Cancel", loadinglist)
				if (input_msg == "Cancel")
					done = FALSE
				else
					for (var/i = 1, i <= GD.gladiator_stats.len, i++)
						if (GD.gladiator_stats[i][1] == client.ckey && GD.gladiator_stats[i][2] == input_msg && GD.gladiator_stats[i][4] == 0)
							name = GD.gladiator_stats[i][2]
							real_name = name
							var/statsplit = splittext(GD.gladiator_stats[i][3],",")
							stats["strength"][1] = text2num(statsplit[1])
							stats["strength"][2] = text2num(statsplit[1])
							stats["crafting"][1] = text2num(statsplit[2])
							stats["crafting"][2] = text2num(statsplit[2])
							stats["rifle"][1] = text2num(statsplit[3])
							stats["rifle"][2] = text2num(statsplit[3])
							stats["dexterity"][1] = text2num(statsplit[4])
							stats["dexterity"][2] = text2num(statsplit[4])
							stats["swords"][1] = text2num(statsplit[5])
							stats["swords"][2] = text2num(statsplit[5])
							stats["pistol"][1] = text2num(statsplit[6])
							stats["pistol"][2] = text2num(statsplit[6])
							stats["bows"][1] = text2num(statsplit[7])
							stats["bows"][2] = text2num(statsplit[7])
							stats["medical"][1] = text2num(statsplit[8])
							stats["medical"][2] = text2num(statsplit[8])
							stats["philosophy"][1] = text2num(statsplit[9])
							stats["philosophy"][2] = text2num(statsplit[9])
							stats["machinegun"][1] = text2num(statsplit[10])
							stats["machinegun"][2] = text2num(statsplit[10])
							src << "<font size=2><b>Successfully loaded <b>[name]</b>.</font>"
							return
			if (done == FALSE)
				var/input_msg = WWinput(src, "Welcome, [client.ckey]. You have spawned as a gladiator named [name]. You can customize your name. Do you want to?", "Custom name", "No", list("Yes","No"))
				if (input_msg == "No")
					var/obj/map_metadata/gladiators/G = map
					var/statlist = "1,1,1,1,1,1,1,1,1,1"
					statlist = "[stats["strength"][1]],[stats["crafting"][1]],[stats["rifle"][1]],[stats["dexterity"][1]],[stats["swords"][1]],[stats["pistol"][1]],[stats["bows"][1]],[stats["medical"][1]],[stats["philosophy"][1]],[stats["machinegun"][1]],[stats["stamina"][1]]"
					G.gladiator_stats += list(list(client.ckey,name,statlist,0,0,0))
					return
				else
					var/input_name = input(src, "Choose the new name: (Max 25 characters)","Custom Name", name) as text
					input_name = sanitizeName(input_name, 25, FALSE)
					if (input_name != "" && input_name)
						name = input_name
						real_name = input_name
					if (!name || !real_name)
						name = capitalize(pick(first_names_male_roman)) + " " + capitalize(pick(middle_names_roman)) + " " + capitalize(pick(last_names_roman))
						real_name = name
					var/obj/map_metadata/gladiators/G = map
					var/statlist = "1,1,1,1,1,1,1,1,1,1"
					statlist = "[stats["strength"][1]],[stats["crafting"][1]],[stats["rifle"][1]],[stats["dexterity"][1]],[stats["swords"][1]],[stats["pistol"][1]],[stats["bows"][1]],[stats["medical"][1]],[stats["philosophy"][1]],[stats["machinegun"][1]],[stats["stamina"][1]]"
					G.gladiator_stats += list(list(client.ckey,name,statlist,0,0,0))
					return