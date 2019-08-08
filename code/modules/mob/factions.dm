/mob/living/carbon/human/proc/make_nomad()
	if (map.nomads)
		verbs += /mob/living/carbon/human/proc/create_faction
		verbs += /mob/living/carbon/human/proc/abandon_faction
		verbs += /mob/living/carbon/human/proc/transfer_faction
		verbs += /mob/living/carbon/human/proc/become_leader
		verbs += /mob/living/carbon/human/proc/faction_list
		verbs += /mob/living/carbon/human/proc/religion_list
/mob/living/carbon/human/proc/make_tribesman()
		verbs += /mob/living/carbon/human/proc/transfer_faction
		verbs += /mob/living/carbon/human/proc/become_leader
		verbs += /mob/living/carbon/human/proc/faction_list
		verbs += /mob/living/carbon/human/proc/religion_list
		verbs += /mob/living/carbon/human/proc/create_religion
		verbs += /mob/living/carbon/human/proc/abandon_religion
		verbs += /mob/living/carbon/human/proc/clergy
//	verbs += /mob/living/carbon/human/proc/create_company
//	verbs += /mob/living/carbon/human/proc/transfer_company_stock
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
		var/choosecolor1 = "#000000"
		var/choosecolor2 = "#FFFFFF"
		var/choosesymbol = "star"
		choosesymbol = WWinput(src, "Choose a symbol for the new faction:", "Faction Creation", "Cancel", list("Cancel","star","sun","moon","cross","big cross","saltire"))
		if (choosesymbol == "Cancel")
			return
		choosecolor1 = input(H, "Choose the main/symbol hex color (without the #):", "Color" , "000000")
		if (choosecolor1 == null || choosecolor1 == "")
			return
		else
			choosecolor1 = uppertext(choosecolor1)
			if (lentext(choosecolor1) != 6)
				return
			var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
			for (var/i = 1, i <= 6, i++)
				var/numtocheck = 0
				if (i < 6)
					numtocheck = copytext(choosecolor1,i,i+1)
				else
					numtocheck = copytext(choosecolor1,i,0)
				if (!(numtocheck in listallowed))
					return
			choosecolor1 = addtext("#",choosecolor1)

		choosecolor2 = input(H, "Choose the secondary/background hex color (without the #):", "Color" , "FFFFFF")
		if (choosecolor2 == null || choosecolor2 == "")
			return
		else
			choosecolor2 = uppertext(choosecolor2)
			if (lentext(choosecolor2) != 6)
				return
			var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
			for (var/i = 1, i <= 6, i++)
				var/numtocheck = 0
				if (i < 6)
					numtocheck = copytext(choosecolor2,i,i+1)
				else
					numtocheck = copytext(choosecolor2,i,0)
				if (!(numtocheck in listallowed))
					return
			choosecolor2 = addtext("#",choosecolor2)
		H.civilization = newname
		H.leader = TRUE
		H.faction_perms = list(1,1,1,1)
		map.custom_faction_nr += newname
		var/newnamev = list("[newname]" = list(map.default_research,map.default_research,map.default_research,H,0,choosesymbol,choosecolor1,choosecolor2))
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
	if (map.civilizations == TRUE)
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
	if (map.civilizations == TRUE)
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

	if (map.civilizations == TRUE)
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

	if (map.civilizations == TRUE)
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
						if (U && U.title != "")
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
		if (faction != "none")
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

/obj/item/weapon/poster/faction/lead
	bstyle = "prop_lead"
/obj/item/weapon/poster/faction/work
	bstyle = "prop_work"
/obj/item/weapon/poster/faction/mil1
	bstyle = "prop_mil1"
/obj/item/weapon/poster/faction/mil2
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

////////////////////////////////////////////////////////////////////////////
///////////////////////////////////Companies////////////////////////////////
////////////////////////////////////////////////////////////////////////////

/mob/living/carbon/human/proc/create_company()
	set name = "Create Company"
	set category = "Faction"
	var/mob/living/carbon/human/U

	if (istype(src, /mob/living/carbon/human))
		U = src
	else
		return
	if (map.civilizations == TRUE)
		var/choosename = russian_to_cp1251(input(U, "Choose a name for the company:") as text|null)
		create_company_pr(choosename)
		return
	else
		U << "<span class='danger'>You cannot create a company in this map.</span>"
		return

/mob/living/carbon/human/proc/create_company_pr(var/newname = "none")
	if (!ishuman(src))
		return
	var/mob/living/carbon/human/H = src
	for(var/i = 1, i <= map.custom_faction_nr.len, i++)
		if (map.custom_company_nr[i] == newname)
			usr << "<span class='danger'>That company already exists. Choose another name.</span>"
			return
	if (newname != null && newname != "none")
		var/choosecolor1 = "#000000"
		var/choosecolor2 = "#FFFFFF"
		choosecolor1 = input(H, "Choose the main hex color (without the #):", "Color" , "000000")
		if (choosecolor1 == null || choosecolor1 == "")
			return
		else
			choosecolor1 = uppertext(choosecolor1)
			if (lentext(choosecolor1) != 6)
				return
			var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
			for (var/i = 1, i <= 6, i++)
				var/numtocheck = 0
				if (i < 6)
					numtocheck = copytext(choosecolor1,i,i+1)
				else
					numtocheck = copytext(choosecolor1,i,0)
				if (!(numtocheck in listallowed))
					return
			choosecolor1 = addtext("#",choosecolor1)

		choosecolor2 = input(H, "Choose the secondary/background hex color (without the #):", "Color" , "FFFFFF")
		if (choosecolor2 == null || choosecolor2 == "")
			return
		else
			choosecolor2 = uppertext(choosecolor2)
			if (lentext(choosecolor2) != 6)
				return
			var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
			for (var/i = 1, i <= 6, i++)
				var/numtocheck = 0
				if (i < 6)
					numtocheck = copytext(choosecolor2,i,i+1)
				else
					numtocheck = copytext(choosecolor2,i,0)
				if (!(numtocheck in listallowed))
					return
			choosecolor2 = addtext("#",choosecolor2)
		map.custom_company_nr += newname
		var/list/newnamev = list("[newname]" = list(list(H,100)))
		map.custom_company += newnamev
		usr << "<big>You now own <b>100%</b> of the new company [newname].</big>"
		return
	else
		return

/mob/living/carbon/human/proc/transfer_company_stock()
	set name = "Transfer Company Stock"
	set category = "Faction"
	var/mob/living/carbon/human/H
	if (istype(src, /mob/living/carbon/human))
		H = src
	else
		return
	if (map.civilizations == TRUE)
		var/found = FALSE
		var/list/currlist = list()
		var/list/currlist_ind = list("Cancel")
		for (var/cname in map.custom_company_nr)
			for (var/i = 1, i <= map.custom_company[cname].len, i++)
				if (map.custom_company[cname][i][1] == H)
					currlist += list("[cname]" = list(map.custom_company[cname][i][2]))
					currlist_ind += cname
					found = TRUE
		if (!found)
			usr << "You do not own any stocks."
			return
		else
			var/compchoice = WWinput(H, "Which company to transfer stock ownership?", "Stock Transfer", "Cancel", currlist_ind)
			if (compchoice == "Cancel")
				return
			else
				var/compchoice_amt = input(H, "You own [currlist[compchoice][1]]% of [compchoice]. How much do you want to transfer? (1 to [currlist[compchoice][1]])") as num|null
				compchoice_amt = round(compchoice_amt)
				if (compchoice_amt > currlist[compchoice][1])
					compchoice_amt = currlist[compchoice][1]
				else if (compchoice_amt <= 0)
					return
				var/list/closemobs = list("Cancel")
				for (var/mob/living/carbon/human/M in range(4,loc))
					if (M.stat != DEAD)
						closemobs += M
				var/choice2 = WWinput(usr, "Who to transfer the stocks to?", "Stock Transfer", "Cancel", closemobs)
				if (choice2 == "Cancel")
					return
				else
					var/mob/living/carbon/human/CM = choice2
					for(var/l=1, l <= map.custom_company[compchoice].len, l++)
						if (map.custom_company[compchoice][l][1] == H)
							var/currb = map.custom_company[compchoice][l][2]
							map.custom_company[compchoice][l][2] = currb-compchoice_amt

					for(var/l=1,  l <= map.custom_company[compchoice].len, l++)
						if (map.custom_company[compchoice][l][1] == CM)
							var/currb = map.custom_company[compchoice][l][2]
							map.custom_company[compchoice][l][2] = currb+compchoice_amt
							return
					map.custom_company[compchoice] += list(list(CM,compchoice_amt))
					H << "Transfered [compchoice_amt]% of [compchoice] to [CM]."
					CM << "You received [compchoice_amt]% of [compchoice] from [H]."
					return


	else
		usr << "<span class='danger'>You cannot transfer company ownership on this map.</span>"
		return

/mob/living/carbon/human/proc/faction_list()
	set name = "Check Faction List"
	set category = "Faction"
	if (map && map.civilizations)
		map.facl = list()
		for (var/i=1,i<=map.custom_faction_nr.len,i++)
			var/nu = 0
			map.facl += list(map.custom_faction_nr[i] = nu)

		for (var/relf in map.facl)
			map.facl[relf] = 0
			for (var/mob/living/carbon/human/H in world)
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


/mob/living/carbon/human/proc/religion_list()
	set name = "Check Religion List"
	set category = "Faction"
	if (map && map.civilizations)

		var/body = "<html><head><title>Religion List</title></head><b>RELIGION LIST</b><br><br>"
		for (var/rel in map.custom_religions)
			body += "<b>[rel]</b>: [map.custom_religions[rel][3]] points.</br>"
		body += {"<br>
			</body></html>
		"}

		usr << browse(body,"window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=250x450")
	else
		return