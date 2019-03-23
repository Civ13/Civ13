/mob/living/carbon/human/proc/make_nomad()
	verbs += /mob/living/carbon/human/proc/create_faction
	verbs += /mob/living/carbon/human/proc/abandon_faction
	verbs += /mob/living/carbon/human/proc/transfer_faction
	verbs += /mob/living/carbon/human/proc/become_leader

/////////////FACTIONS////////////////////////////
/mob/living/carbon/human/proc/create_faction()
	set name = "Create Faction"
	set category = "Faction"
	var/mob/living/carbon/human/U

	if (istype(src, /mob/living/carbon/human))
		U = src
	else
		return
	if (map.nomads == TRUE)
		if (U.civilization != "none")
			usr << "<span class='danger'>You are already in a faction. Abandon it first.</span>"
			return
		else
			var/choosename = russian_to_cp1251(input(src, "Choose a name for the faction:") as text|null)
			create_faction_pr(choosename)
			make_commander()
			make_title_changer()
			return
	else
		usr << "<span class='danger'>You cannot create a faction in this map.</span>"
		return

/mob/living/carbon/human/proc/create_faction_pr(var/newname = "none")
	if (!ishuman(src))
		return
	var/mob/living/carbon/human/H = src
	for(var/i = 1, i <= map.custom_faction_nr.len, i++)
		if (map.custom_faction_nr[i] == newname)
			usr << "<span class='danger'>That faction already exists. Choose another name.</span>"
			return
	if (newname != null && newname != "none")
		H.civilization = newname
		H.leader = TRUE
		H.faction_perms = list(1,1,1,1)
		map.custom_faction_nr += newname
		var/newnamev = list("[newname]" = list(map.default_research,map.default_research,map.default_research,H,0))
		map.custom_civs += newnamev
		usr << "<big>You are now the leader of the <b>[newname]</b> faction.</big>"
		return
	else
		return


/mob/living/carbon/human/proc/abandon_faction()
	set name = "Abandon Faction"
	set category = "Faction"
	var/mob/living/carbon/human/U

	if (istype(src, /mob/living/carbon/human))
		U = src
	else
		return
	if (map.nomads == TRUE)
		if (U.civilization == "none")
			usr << "You are not part of any faction."
			return
		else
			if (map.custom_civs[U.civilization][4] != null)
				if (map.custom_civs[U.civilization][4].real_name == U.real_name)
					map.custom_civs[U.civilization][4] = null
			U.civilization = "none"
			U.leader = FALSE
			U.faction_perms = list(0,0,0,0)
			usr << "You left your faction. You are now a Nomad."
			remove_commander()
	else
		usr << "<span class='danger'>You cannot leave a faction in this map.</span>"
		return


/mob/living/carbon/human/proc/transfer_faction()
	set name = "Transfer Faction Leadership"
	set category = "Faction"
	var/mob/living/carbon/human/U

	if (istype(src, /mob/living/carbon/human))
		U = src
	else
		return
	if (map.nomads == TRUE)
		if (U.civilization == "none")
			usr << "You are not part of any faction."
			return
		else
			if (map.custom_civs[U.civilization][4] != null)
				if (map.custom_civs[U.civilization][4].real_name == U.real_name)
					var/list/closemobs = list("Cancel")
					for (var/mob/living/carbon/human/M in range(4,loc))
						if (M.civilization == U.civilization)
							closemobs += M
					var/choice2 = WWinput(usr, "Who to nominate as the new Leader?", "Faction Leadership", "Cancel", closemobs)
					if (choice2 == "Cancel")
						return
					else
						map.custom_civs[U.civilization][4] = choice2
						visible_message("<big>[choice2] is the new leader of [U.civilization]!</big>")
						var/mob/living/carbon/human/CM = choice2
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

/mob/living/carbon/human/proc/become_leader()
	set name = "Become Faction Leader"
	set category = "Faction"
	var/mob/living/carbon/human/U

	if (istype(src, /mob/living/carbon/human))
		U = src
	else
		return
	if (map.nomads == TRUE)
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


/mob/living/carbon/human/proc/Add_Title()
	set name = "Give Faction Title"
	set category = "Officer"
	var/mob/living/carbon/human/U

	if (map.nomads == TRUE)
		if (istype(usr, /mob/living/carbon/human))
			var/mob/living/carbon/human/H = usr
			if (H.civilization == "none")
				usr << "You are not part of any faction."
				return
			else
				if (H.faction_perms[3] == 0)
					usr << "<span class='danger'>You don't have the permissions to give titles.</span>"
					return

				else
					var/list/closemobs = list("Cancel")
					for (var/mob/living/carbon/human/M in range(4,loc))
						if (M.civilization == H.civilization)
							closemobs += M
					var/choice2 = WWinput(usr, "Who to give a title to?", "Faction Title", "Cancel", closemobs)
					if (choice2 == "Cancel")
						return
					else
						U = choice2
						var/inp = russian_to_cp1251(input(usr, "Choose a title to give:") as text|null)
						if (inp == "" || !inp)
							return
						else
							U.title = inp
							U.fully_replace_character_name(U.real_name,"[U.title] [U.name]")
							usr << "[src] is now a [U.title]."
							return
	else
		usr << "<span class='danger'>You cannot give titles in this map.</span>"
		return

/mob/living/carbon/human/proc/Remove_Title()
	set name = "Remove Faction Title"
	set category = "Officer"
	var/mob/living/carbon/human/U

	if (map.nomads == TRUE)
		if (istype(usr, /mob/living/carbon/human))
			var/mob/living/carbon/human/H = usr
			if (H.civilization == "none")
				usr << "You are not part of any faction."
				return
			else
				if (H.faction_perms[3] == 0)
					usr << "<span class='danger'>You don't have the permissions to remove titles.</span>"
					return

				else
					var/list/closemobs = list("Cancel")
					for (var/mob/living/carbon/human/M in range(4,loc))
						if (M.civilization == H.civilization && M.title != "")
							closemobs += M
					var/choice2 = WWinput(usr, "Who to remove a title from?", "Faction Title", "Cancel", closemobs)
					if (choice2 == "Cancel")
						return
					else
						U = choice2
						if (U.title != "")
							U.fully_replace_character_name(U.real_name,replacetext(U.real_name,"[U.title] ",""))
							usr << "[src]'s title of [U.title] has been removed by [usr]."
							U.title = ""
							return
						else
							usr << "[src] has no title."
							return
	else
		usr << "<span class='danger'>You cannot give titles in this map.</span>"
		return
