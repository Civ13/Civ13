/mob/living/human/proc/make_nomad()
	if (map.nomads)
		verbs += /mob/living/human/proc/create_faction
		verbs += /mob/living/human/proc/abandon_faction
		verbs += /mob/living/human/proc/transfer_faction
		verbs += /mob/living/human/proc/become_leader
		verbs += /mob/proc/faction_list
		verbs += /mob/proc/religion_list
		verbs += /mob/living/human/proc/create_company
		verbs += /mob/living/human/proc/transfer_company_stock

/mob/living/human/proc/make_nation()
	if (map.civilizations)
		verbs += /mob/living/human/proc/create_faction
		verbs += /mob/living/human/proc/abandon_faction
		verbs += /mob/living/human/proc/transfer_faction
		verbs += /mob/living/human/proc/become_leader
		verbs += /mob/proc/religion_list
		verbs += /mob/living/human/proc/create_religion
		verbs += /mob/living/human/proc/abandon_religion
		verbs += /mob/living/human/proc/create_company
		verbs += /mob/living/human/proc/transfer_company_stock

/mob/living/human/proc/make_tribesman()
	verbs += /mob/living/human/proc/transfer_faction
	verbs += /mob/living/human/proc/become_leader
	verbs += /mob/proc/faction_list
	verbs += /mob/proc/religion_list
	verbs += /mob/living/human/proc/create_religion
	verbs += /mob/living/human/proc/abandon_religion
	verbs += /mob/living/human/proc/clergy
	verbs += /mob/living/human/proc/create_company
	verbs += /mob/living/human/proc/transfer_company_stock

/mob/living/human/proc/make_businessman()
	verbs += /mob/living/human/proc/create_company
	verbs += /mob/living/human/proc/transfer_company_stock

/mob/New()
	..()
	if (map && map.nomads)
		verbs += /mob/proc/faction_list
		verbs += /mob/proc/religion_list
/////////////FACTIONS////////////////////////////
/mob/living/human/proc/create_faction()
	set name = "Create Faction"
	set category = "Faction"
	var/mob/living/human/U

	if (istype(src, /mob/living/human))
		U = src
	else
		return

	if (map.nomads == TRUE || map.ID == MAP_NATIONSRP || map.ID == MAP_NATIONSRP_TRIPLE || map.ID == MAP_NATIONSRPMED || map.ID == MAP_NATIONSRP_WW2 || map.ID == MAP_NATIONSRP_COLDWAR || map.ID == MAP_NATIONSRP_COLDWAR_CAMPAIGN || map.ID == MAP_NOMADS_PERSISTENCE_BETA)
		if (U.civilization != "none")
			usr << "<span class='danger'>You are already in a faction. Abandon it first.</span>"
			return
		else
			var/choosename = input(src, "Choose a name for the faction:") as text|null
			if (choosename != null && choosename != "")
				create_faction_pr(choosename)
				make_commander()
				make_title_changer()
				return
	else
		usr << "<span class='danger'>You cannot create a faction in this map.</span>"
		return

/mob/living/human/proc/create_faction_pr(var/newname = "none")
	if (!ishuman(src))
		return
	var/mob/living/human/H = src
	for(var/i = 1, i <= map.custom_faction_nr.len, i++)
		if (map.custom_faction_nr[i] == newname)
			usr << "<span class='danger'>That faction already exists. Choose another name.</span>"
			return
	if (newname != null && newname != "none")
		var/choosecolor1 = "#000000"
		var/choosecolor2 = "#FFFFFF"
		var/choosesymbol = "star"
		choosesymbol = WWinput(src, "Choose a symbol for the new faction:", "Faction Creation", "Cancel", list("Cancel","star","sun","moon","cross","big cross","saltire"))
		if (choosesymbol == "Cancel")
			return
		choosecolor1 = WWinput(H, "Choose main/symbol color:", "Color" , "#000000", "color")
		if (choosecolor1 == null || choosecolor1 == "")
			return

		choosecolor2 = WWinput(H, "Choose the secondary/background color:", "Color" , "#FFFFFF", "color")
		if (choosecolor2 == null || choosecolor2 == "")
			return

		H.civilization = newname
		H.leader = TRUE
		H.faction_perms = list(1,1,1,1)
		map.custom_faction_nr += newname
												//ind						mil					med			leader money	symbol	main color	backcolor, sales tax, business tax
		var/newnamev = list("[newname]" = list(map.default_research,map.default_research,map.default_research,H,0,choosesymbol,choosecolor1,choosecolor2,10,10))
		map.custom_civs += newnamev
		usr << "<big>You are now the leader of the <b>[newname]</b> faction.</big>"
		return
	else
		return


/mob/living/human/proc/abandon_faction()
	set name = "Abandon Faction"
	set category = "Faction"
	var/mob/living/human/U

	if (istype(src, /mob/living/human))
		U = src
	else
		return
	if (map.nomads == TRUE || map.ID == MAP_NATIONSRP || map.ID == MAP_NATIONSRP_TRIPLE || map.ID == MAP_NATIONSRPMED || map.ID == MAP_NATIONSRP_WW2 || map.ID == MAP_NATIONSRP_COLDWAR || map.ID == MAP_NATIONSRP_COLDWAR_CAMPAIGN || map.ID == MAP_NOMADS_PERSISTENCE_BETA)
		if (U.civilization == "none")
			usr << "You are not part of any faction."
			return
		else
			var/confirmation = WWinput(src, "Are you sure you want to leave your faction? You won't be able to re-join it for 24 hours, and everyone will know you're a former member.", "", "Stay in faction", list("Leave", "Stay in faction"))
			if (confirmation == "Stay in faction")
				return
			else
				faction_leaving_proc()
	else
		usr << "<span class='danger'>You cannot leave a faction in this map.</span>"
		return


/mob/living/human/proc/faction_leaving_proc()
	if (civilization == null || civilization == "none")
		return FALSE
	left_factions += list(list(civilization,world.realtime+864000)) //24 hours
	if (map.custom_civs[civilization][4] != null)
		if (map.custom_civs[civilization][4].real_name == real_name)
			map.custom_civs[civilization][4] = null
	civilization = "none"
	name = replacetext(real_name,"[title] ","")
	title = ""
	leader = FALSE
	faction_perms = list(0,0,0,0)
	src << "You left your faction. You are now a Nomad."
	remove_commander()
	return TRUE

/mob/living/human/proc/transfer_faction()
	set name = "Transfer Faction Leadership"
	set category = "Faction"
	var/mob/living/human/U

	if (istype(src, /mob/living/human))
		U = src
	else
		return
	if (map.civilizations == TRUE || map.ID == MAP_NATIONSRP || map.ID == MAP_NATIONSRP_TRIPLE || map.ID == MAP_NATIONSRPMED || map.ID == MAP_NATIONSRP_WW2 || map.ID == MAP_NATIONSRP_COLDWAR || map.ID == MAP_NATIONSRP_COLDWAR_CAMPAIGN || map.ID == MAP_NOMADS_PERSISTENCE_BETA)
		if (U.civilization == "none")
			usr << "You are not part of any faction."
			return
		else
			if (map.custom_civs[U.civilization][4] != null)
				if (map.custom_civs[U.civilization][4].real_name == U.real_name)
					var/list/closemobs = list("Cancel")
					for (var/mob/living/human/M in range(4,loc))
						if (M.civilization == U.civilization)
							closemobs += M
					var/choice2 = WWinput(usr, "Who to nominate as the new Leader?", "Faction Leadership", "Cancel", closemobs)
					if (choice2 == "Cancel")
						return
					else
						map.custom_civs[U.civilization][4] = choice2
						visible_message("<big>[choice2] is the new leader of [U.civilization]!</big>")
						var/mob/living/human/CM = choice2
						CM.make_commander()
						CM.make_title_changer()
						CM.leader = TRUE
						CM.faction_perms = list(1,1,1,1)
						U.leader = FALSE
						U.faction_perms = list(0,0,0,0)
						U.remove_title_changer()
						U.remove_commander()
				else
					usr << "<span class='danger'You are not the Leader, so you can't transfer the faction's leadership.</span>"
					return
			else
				usr << "<span class='danger'There is no Leader, so you can't transfer the faction's leadership.</span>"

	else
		usr << "<span class='danger'>You cannot transfer leadership of a faction in this map.</span>"
		return

/mob/living/human/proc/become_leader()
	set name = "Become Faction Leader"
	set category = "Faction"
	var/mob/living/human/U

	if (istype(src, /mob/living/human))
		U = src
	else
		return
	if (map.civilizations == TRUE || map.ID == MAP_NATIONSRP || map.ID == MAP_NATIONSRP_TRIPLE || map.ID == MAP_NATIONSRPMED || map.ID == MAP_NATIONSRP_WW2 || map.ID == MAP_NATIONSRP_COLDWAR || map.ID == MAP_NATIONSRP_COLDWAR_CAMPAIGN || map.ID == MAP_NOMADS_PERSISTENCE_BETA)
		if (U.civilization == "none")
			usr << "You are not part of any faction."
			return
		else
			if (map.custom_civs[U.civilization][4] != null)
				usr << "<span class='danger'>There already is a Leader of the faction. He must transfer the leadership or be removed first.</span>"
				return

			else if (map.custom_civs[U.civilization][4] == null)
				map.custom_civs[U.civilization][4] = U
				visible_message("<big>[U] is now the Leader of [U.civilization]!</big>")
				U.leader = TRUE
				U.faction_perms = list(1,1,1,1)
				U.make_title_changer()
				make_commander()
	else
		usr << "<span class='danger'>You cannot become a Leader in this map.</span>"
		return


/mob/living/human/proc/Add_Title()
	set name = "Give Faction Title"
	set category = "Officer"
	var/mob/living/human/U

	if (map.civilizations == TRUE)
		if (istype(usr, /mob/living/human))
			var/mob/living/human/H = usr
			if (H.civilization == "none")
				usr << "You are not part of any faction."
				return
			else
				if (H.faction_perms[3] == 0)
					usr << "<span class='danger'>You don't have the permissions to give titles.</span>"
					return

				else
					var/list/closemobs = list("Cancel")
					for (var/mob/living/human/M in range(4,loc))
						if (M.civilization == H.civilization)
							closemobs += M
					var/choice2 = WWinput(usr, "Who to give a title to?", "Faction Title", "Cancel", closemobs)
					if (choice2 == "Cancel")
						return
					else
						U = choice2
						var/inp = input(usr, "Choose a title to give:") as text|null
						if (inp == "" || !inp)
							return
						else
							U.title = inp
							U.name = "[U.title] [U.name]"
							usr << "[src] is now a [U.title]."
							return
	else if (map.ID == MAP_VOYAGE)
		var/list/closemobs = list("Cancel")
		for (var/mob/living/human/M in range(4,loc))
			if (M.original_job_title == "Pirate" || M.title != "")
				if(M.title != "Captain" && M.title != "Boatswain" && M.title != "Quartermaster")
					closemobs += M
		var/choice2 = WWinput(usr, "Who to assign a job to?", "Job Assignment", "Cancel", closemobs)
		if (choice2 == "Cancel" || !choice2)
			return
		else
			U = choice2
			var/list/optlist = list("Cancel","Sailor","Swabber","Carpenter","Nurse","Cannonier","Cook","Marine","Sergeant","Navigator","Deputy Boatswain","Deputy Quartermaster")
			var/inp = WWinput(usr, "Choose a job to give:","Job Assignment","Cancel",optlist)
			if (inp == "Cancel" || !inp)
				return
			else
				if (inp == "Sailor")
					U.original_job_title = "Pirate"
					U.fully_replace_character_name(U.real_name,replacetext(U.real_name,"[U.title] ",""))
					U.title = ""
				else
					U.title = inp
					U.original_job_title = inp
					U.name = "[U.title] [U.name]"
				usr << "[U.real_name] has been assigned the job of [inp]."
				var/job_msg = "You have been assigned to the job of [inp]."
				WWalert(U, job_msg, "Job Assignment")
				return
	else
		usr << "<span class='danger'>You cannot give titles in this map.</span>"
		return

/mob/living/human/proc/Remove_Title()
	set name = "Remove Faction Title"
	set category = "Officer"
	var/mob/living/human/U

	if (map.civilizations == TRUE)
		if (istype(usr, /mob/living/human))
			var/mob/living/human/H = usr
			if (H.civilization == "none")
				usr << "You are not part of any faction."
				return
			else
				if (H.faction_perms[3] == 0)
					usr << "<span class='danger'>You don't have the permissions to remove titles.</span>"
					return

				else
					var/list/closemobs = list("Cancel")
					for (var/mob/living/human/M in range(4,loc))
						if (M.civilization == H.civilization && M.title != "")
							closemobs += M
					var/choice2 = WWinput(usr, "Who to remove a title from?", "Faction Title", "Cancel", closemobs)
					if (choice2 == "Cancel")
						return
					else
						U = choice2
						if (U && U.title != "")
							U.fully_replace_character_name(U.real_name,replacetext(U.real_name,"[U.title] ",""))
							usr << "[src]'s title of [U.title] has been removed by [usr]."
							U.title = ""
							return
						else
							usr << "[src] has no title."
							return
	else if (map.ID == MAP_VOYAGE)
		var/list/closemobs = list("Cancel")
		for (var/mob/living/human/M in range(4,loc))
			if ((M.original_job_title != "Pirate") && M.title != "")
				closemobs += M
		var/choice2 = WWinput(usr, "Who to remove a job from?", "Job Assignment", "Cancel", closemobs)
		if (choice2 == "Cancel")
			return
		else
			U = choice2
			if (U && U.title != "")
				U.fully_replace_character_name(U.real_name,replacetext(U.real_name,"[U.title] ",""))
				usr << "[U]'s job of [U.title] has been removed by [usr]."
				U.original_job_title = "Pirate"
				U.title = ""
				WWalert(U,"Your job has been removed. You are now a basic sailor.","Job Assignment")
				return
			else
				usr << "[U] has no job assigned."
				return
	else
		usr << "<span class='danger'>You cannot give titles in this map.</span>"
		return

////////////////POSTERS, BANNERS, ETC//////////////////////////////



/obj/structure/banner/faction
	name = "faction banner"
	icon = 'icons/obj/banners.dmi'
	icon_state = "banner_a"
	desc = "A white banner."
	var/bstyle = "banner_a"
	var/faction = "none"
	var/symbol = "cross"
	var/color1 = "#000000"
	var/color2 = "#FFFFFF"
	flammable = TRUE
	layer = 3.21

/obj/structure/banner/faction/banner_a
	bstyle = "banner_a"
/obj/structure/banner/faction/banner_b
	bstyle = "banner_b"
/obj/structure/banner/faction/New()
	..()
	invisibility = 101
	spawn(10)
		if (faction != "none" && map)
			name = "[faction]'s banner"
			desc = "This is a [faction] banner."
			icon_state = bstyle
			var/image/overc = image("icon" = icon, "icon_state" = "[bstyle]_1")
			overc.color = color1
			overlays += overc
			var/image/overc1 = image("icon" = icon, "icon_state" = "[bstyle]_2")
			overc1.color = color2
			overlays += overc1
			var/image/overs = image("icon" = icon, "icon_state" = "b_[map.custom_civs[faction][6]]")
			overs.color = color1
			overlays += overs
		update_icon()
		invisibility = 0


/obj/structure/banner/faction/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (W.sharp)
		user << "You start ripping off the [src]..."
		if (do_after(user, 130, src))
			visible_message("[user] rips the [src]!")
			qdel(src)
	else
		..()
/obj/structure/banner/faction/team
	var/team = null
	name = "team banner"
	desc = "A sports team banner."

/obj/structure/banner/faction/team/New()
	..()
	assign_team()

/obj/structure/banner/faction/team/attackby(obj/item/weapon/W as obj, mob/user as mob)
	return

/obj/structure/banner/faction/team/attack_hand(mob/user as mob)
	return

/obj/structure/banner/faction/team/proc/assign_team(new_team = null)
	if (!new_team)
		new_team = src.team
	if (!new_team)
		return
	if (map && map.ID == MAP_FOOTBALL)
		var/obj/map_metadata/football/FM = map
		if (FM.team1 == src.team)
			color1 = FM.teams[src.team][FM.team1_kit]["shirt_color"]
			color2 = FM.teams[src.team][FM.team1_kit]["shorts_color"]
		else if  (FM.team2 == src.team)
			color1 = FM.teams[src.team][FM.team2_kit]["shirt_color"]
			color2 = FM.teams[src.team][FM.team2_kit]["shorts_color"]
		else
			color1 = FM.teams[src.team]["main uniform"]["shirt_color"]
			color2 = FM.teams[src.team]["main uniform"]["shorts_color"]
		var/image/overc = image("icon" = icon, "icon_state" = "[bstyle]_1")
		overc.color = color1
		overlays += overc
		var/image/overc1 = image("icon" = icon, "icon_state" = "[bstyle]_2")
		overc1.color = color2
		overlays += overc1
		name = "[src.team] banner"
		update_icon()
/obj/structure/banner/faction/team/team1

/obj/structure/banner/faction/team/team2

/obj/item/weapon/poster/faction
	name = "rolled faction poster"
	icon = 'icons/obj/banners.dmi'
	icon_state = "poster_rolled"
	desc = "A rolled poster."
	var/faction = "none"
	var/color1 = "#000000"
	var/color2 = "#FFFFFF"
	var/bstyle = "prop_lead"
	flammable = TRUE
	force = 0
	flags 

/obj/item/weapon/poster/faction/lead
	bstyle = "prop_lead"
/obj/item/weapon/poster/faction/work
	bstyle = "prop_work"
/obj/item/weapon/poster/faction/mil1
	bstyle = "prop_mil1"
/obj/item/weapon/poster/faction/mil2
	bstyle = "prop_mil2"
	
/obj/structure/poster/faction/red
	faction = "Redmenia"
	color2 = "#d60000"
	color1 = "#FFFFFF"
/obj/structure/poster/faction/red/lead
	icon_state = "prop_lead"
	bstyle = "prop_lead"
/obj/structure/poster/faction/red/work
	icon_state = "prop_work"
	bstyle = "prop_work"
/obj/structure/poster/faction/red/mil1
	icon_state = "prop_mil1"
	bstyle = "prop_mil1"
/obj/structure/poster/faction/red/mil2
	icon_state = "prop_mil2"
	bstyle = "prop_mil2"

/obj/structure/poster/faction/blue
	faction = "Blugoslavia"
	color2 = "#0000d6"
	color1 = "#FFD700"
/obj/structure/poster/faction/blue/lead
	icon_state = "prop_lead"
	bstyle = "prop_lead"
/obj/structure/poster/faction/blue/work
	icon_state = "prop_work"
	bstyle = "prop_work"
/obj/structure/poster/faction/blue/mil1
	icon_state = "prop_mil1"
	bstyle = "prop_mil1"
/obj/structure/poster/faction/blue/mil2
	icon_state = "prop_mil2"
	bstyle = "prop_mil2"
/obj/item/weapon/poster/faction/New()
	..()
	spawn(10)
		if (faction != "none")
			name = "rolled [faction]'s poster"
			desc = "This is a rolled [faction] propaganda poster. Ready to deploy."

/obj/structure/poster/faction
	name = "faction propaganda poster"
	icon = 'icons/obj/banners.dmi'
	icon_state = "prop_lead"
	desc = "A blank poster."
	var/faction = "none"
	var/color1 = "#000000"
	var/color2 = "#FFFFFF"
	var/bstyle = "prop_lead"
	flammable = TRUE
	layer = 3.2
/obj/structure/poster/faction/New()
	..()
	invisibility = 101
	spawn(10)
		if (faction != "none")
			name = "[faction]'s poster"
			desc = "This is a [faction] propaganda poster."
			var/image/overc = image("icon" = icon, "icon_state" = "[bstyle]_c1")
			overc.color = color1
			overlays += overc
			var/image/overc1 = image("icon" = icon, "icon_state" = "[bstyle]_c2")
			overc1.color = color2
			overlays += overc1
			var/image/overs = image("icon" = icon, "icon_state" = "[bstyle]_base")
			overlays += overs
		update_icon()
		invisibility = 0
/obj/structure/poster/faction/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (W.sharp)
		user << "You start ripping off the [src]..."
		if (do_after(user, 70, src))
			visible_message("[user] rips the [src]!")
			overlays.Cut()
			icon_state = "poster_ripped"
			color = color2
			update_icon()
	else
		..()

/mob/proc/faction_list()
	set name = "Check Faction List"
	set category = "Faction"
	if (map && map.civilizations)
		map.facl = list()
		for (var/i=1,i<=map.custom_faction_nr.len,i++)
			var/nu = 0
			map.facl += list(map.custom_faction_nr[i] = nu)

		for (var/relf in map.facl)
			map.facl[relf] = 0
			for (var/mob/living/human/H in world)
				if (relf == H.civilization && H.stat != DEAD)
					map.facl[relf] += 1

		var/body = "<html><head><title>Faction List</title></head><b>FACTION LIST</b><br><br>"
		for (var/relf in map.facl)
			if (map.facl[relf] > 0)
				body += "<b>[relf]</b>: [map.facl[relf]] members.</br>"
		body += {"<br>
			</body></html>
		"}

		usr << browse(body,"window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=250x450")
	else
		return
