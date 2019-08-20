/mob/living/carbon/human/make_nomad()
	..()
	if (map.nomads)
		verbs += /mob/living/carbon/human/proc/create_religion
		verbs += /mob/living/carbon/human/proc/abandon_religion
		verbs += /mob/living/carbon/human/proc/clergy

///////////////////////RELIGION/////////////////////////
/mob/living/carbon/human/proc/create_religion()
	set name = "Create Religion"
	set category = "Faction"
	var/mob/living/carbon/human/U

	if (istype(src, /mob/living/carbon/human))
		U = src
	else
		return
	if (map.nomads == TRUE || map.ID == MAP_TRIBES)
		if (U.religion != "none")
			usr << "<span class='danger'>You are already member of a religion. Abandon it first.</span>"
			return
		else
			if (U.getStatCoeff("philosophy") < 2.49)
				usr << "<span class='danger'>Your philosophy skill is too low. You need 2.5 or more to create a religion.</span>"
				return
			var/choosename = russian_to_cp1251(input(src, "Choose a name for the new religion:") as text|null)
			create_religion_pr(choosename)
			return
	else
		usr << "<span class='danger'>You cannot create a religion in this map.</span>"
		return

/mob/living/carbon/human/proc/create_religion_pr(var/newname = "none")
	if (!ishuman(src))
		return
	var/mob/living/carbon/human/H = src
	for(var/i = 1, i <= map.custom_religion_nr.len, i++)
		if (map.custom_religion_nr[i] == newname)
			usr << "<span class='danger'>That religion already exists. Choose another name.</span>"
			return
	if (newname != null && newname != "none")
		var/choosetype = "Knowledge"
		var/chooseclergy = "Shamans"
		var/choosesymbol = "star"
		var/choosecolor1 = "#000000"
		var/choosecolor2 = "#FFFFFF"
		choosetype = WWinput(src, "Choose a focus for the new religion:", "Religion Creation", "Cancel", list("Cancel","Combat","Knowledge","Production"))
		if (choosetype == "Cancel")
			return
		var/list/clergychoices = list("Cancel","Shamans","Priests")
		if (map.ordinal_age == 1)
			clergychoices = list("Cancel","Shamans","Cultists","Priests")
		else if (map.ordinal_age >= 2)
			clergychoices = list("Cancel","Shamans","Cultists","Priests","Monks","Clerics")

		chooseclergy = WWinput(src, "Choose a clergy organization for your new religion:", "Religion Creation", "Cancel", clergychoices)
		if (chooseclergy == "Cancel")
			return
		choosesymbol = WWinput(src, "Choose a symbol for the new religion:", "Religion Creation", "Cancel", list("Cancel","Star","Sun","Moon","Skull","Hammer","Scales","Cross","Tree"))
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

		H.religion = newname
		H.religious_leader = TRUE
		H.religious_clergy = chooseclergy
		H.religion_type = choosetype
		H.religion_style = chooseclergy
		map.custom_religion_nr += newname
		//////////////////////////////////////creator, type, points, symbol, color1, color2, clergy style
		var/newnamev = list("[newname]" = list(H,choosetype,0, choosesymbol,choosecolor1,choosecolor2,chooseclergy))
		map.custom_religions += newnamev
		usr << "<big>You are now the leader of the <b>[newname]</b> religion.</big>"
		switch(chooseclergy)
			if ("Shamans")
				if (H.gender == "male")
					H.fully_replace_character_name(H.real_name,"Elder Shaman [H.name]")
				else
					H.fully_replace_character_name(H.real_name,"Elder Shamaness [H.name]")
			if ("Priests")
				if (H.gender == "male")
					H.fully_replace_character_name(H.real_name,"High Priest [H.name]")
				else
					H.fully_replace_character_name(H.real_name,"High Priestess [H.name]")
			if ("Monks")
				if (H.gender == "male")
					H.fully_replace_character_name(H.real_name,"Father [H.name]")
				else
					H.fully_replace_character_name(H.real_name,"Mother [H.name]")
			if ("Clerics")
				H.fully_replace_character_name(H.real_name,"Prophet [H.name]")
		return
	else
		return

/mob/living/carbon/human/proc/abandon_religion()
	set name = "Abandon Religion"
	set category = "Faction"
	var/mob/living/carbon/human/U

	if (istype(src, /mob/living/carbon/human))
		U = src
	else
		return
	if (map.nomads == TRUE)
		if (U.religion == "none")
			usr << "<span class='danger'>You are not part of any religion.</span>"
			return
		else if (U.religious_leader || U.religious_clergy != FALSE)
			usr << "<span class='danger'>You cannot leave a religion while part of its clergy!</span>"
			return
		else
			if (map.custom_religions[U.religion][1] != null)
				if (map.custom_religions[U.religion][1].real_name == U.real_name)
					map.custom_religions[U.religion][1] = null
			U.religion = "none"
			U.religion_type = "none"
			U.religion_style = "none"
			U.religious_leader = FALSE
			usr << "You left your religion. You are now an atheist."
	else
		usr << "<span class='danger'>You cannot leave your religion in this map.</span>"
		return

/mob/living/carbon/human/proc/clergy()
	set name = "Join the Clergy"
	set category = "Faction"
	var/mob/living/carbon/human/U

	if (istype(src, /mob/living/carbon/human))
		U = src
	else
		return
	if (map.nomads == TRUE)
		if (U.religion == "none")
			usr << "<span class='danger'>You are not part of any religion.</span>"
			return
		else if (U.religious_leader || U.religious_clergy != FALSE)
			usr << "<span class='danger'>You are already part of the clergy!</span>"
			return
		else
			switch(map.custom_religions[U.religion][7])

				if ("Shamans")
					U.religious_clergy = "Shamans"
					U << "<big>You become a Shaman for the [U.religion]!</big>"
					if (U.gender == "male")
						U.fully_replace_character_name(U.real_name,"Shaman [U.name]")
					else
						U.fully_replace_character_name(U.real_name,"Shamaness [U.name]")
					return

				if ("Priests")
					if (U.getStatCoeff("philosophy") < 1.75)
						U << "<span class='danger'>Your philosophy skill is too low. You need 1.75 or more to become a priest.</span>"
						return
					else
						U.religious_clergy = "Priests"
						U << "<big>You become a Priest for the [U.religion]!</big>"
						if (U.gender == "male")
							U.fully_replace_character_name(U.real_name,"Priest [U.name]")
						else
							U.fully_replace_character_name(U.real_name,"Priestess [U.name]")
						return

				if ("Monks")
					if (U.getStatCoeff("philosophy") < 1.5)
						U << "<span class='danger'>Your philosophy skill is too low. You need 1.5 or more to become a monk.</span>"
						return
					else
						U.religious_clergy = "Monks"
						U << "<big>You become a Monk for the [U.religion]!</big>"
						if (U.gender == "male")
							U.fully_replace_character_name(U.real_name,"Brother [U.name]")
						else
							U.fully_replace_character_name(U.real_name,"Sister [U.name]")
						return

				if ("Clerics")
					if (U.getStatCoeff("philosophy") < 2.2)
						U << "<span class='danger'>Your philosophy skill is too low. You need 2.2 or more to become a cleric.</span>"
						return
					else
						U.religious_clergy = "Clerics"
						U << "<big>You become a Cleric for the [U.religion]!</big>"
						if (U.gender == "male")
							U.fully_replace_character_name(U.real_name,"Venerable [U.name]")
						else
							U.fully_replace_character_name(U.real_name,"Venerable [U.name]")
						return

				if ("Cultists")
					U.religious_clergy = "Cultists"
					U << "<big>You become a Cultist of the [U.religion]!</big>"
	else
		usr << "<span class='danger'>You cannot join the clergy on this map.</span>"
		return
/mob/living/carbon/human/proc/religion_check()
	for (var/obj/item/clothing/CT in contents)
		for (var/obj/item/clothing/accessory/armband/talisman/T in CT.contents)
			if (T.religion == "none" || religion == "none")
				return FALSE
			else
				return religion_type



/obj/item/weapon/book/holybook
	name = "holy book"
	icon_state = "holybook"
	title = "Holy Book"
	desc = "A blank book."
	var/religion = "none"
	var/religion_type = "none"
	flammable = TRUE

/obj/item/weapon/book/holybook/New()
	..()
	spawn(10)
		if (religion != "none")
			name = "[title]"
			desc = "This is the [title], the holy book of the [religion] religion. Written by [author]."
			var/image/overc = image("icon" = icon, "icon_state" = "holybook_o1")
			overc.color = map.custom_religions[religion][6]
			overlays += overc
			var/image/overs = image("icon" = icon, "icon_state" = "holybook_[map.custom_religions[religion][4]]")
			overs.color = map.custom_religions[religion][5]
			overlays += overs
			update_icon()

/obj/item/weapon/book/holybook/attack_self(var/mob/living/carbon/human/user as mob)
	if (user.religion == religion && religion != "none")
		user << "You stare at the glorious holy book of your religion."
	else if (user.religion != religion && religion != "none" && !user.religious_leader && user.religious_clergy == FALSE)
		if (user.religion != "none")
			if (map.custom_religions[user.religion][7] == "Clerics")
				user << "You can't abandon a Clerical religion!"
				return
		user << "You start reading the [title]..."
		if (do_after(user, 900, src))
			var/choice = WWinput(user, "After reading the [title], you feel attracted to the [religion] religion. Do you want to convert?", "[title]", "Yes", list("Yes","No"))
			if (choice == "No")
				return
			else if (choice == "Yes")
				user.religion = religion
				user.religious_leader = FALSE
				user.religion_type = religion_type
				user.religion_style = map.custom_religions[religion][7]
				user << "<big>You convert to the [religion] religion!</big>"
				if (map.custom_religions[religion][7] == "Clerics")
					map.custom_religions[religion][3] += 15
				return



/obj/item/weapon/poster/religious
	name = "rolled religious poster"
	icon = 'icons/obj/library.dmi'
	icon_state = "poster_rolled"
	desc = "A rolled poster."
	var/religion = "none"
	var/symbol = "Cross"
	var/color1 = "#000000"
	var/color2 = "#FFFFFF"
	flammable = TRUE
	force = 0

/obj/item/weapon/poster/religious/New()
	..()
	spawn(10)
		if (religion != "none")
			name = "rolled [religion]'s poster"
			desc = "This is a rolled [religion] religion propaganda poster. Ready to deploy."

/obj/structure/poster/religious
	name = "religious poster"
	icon = 'icons/obj/library.dmi'
	icon_state = "poster_base"
	desc = "A blank poster."
	var/religion = "none"
	var/symbol = "Cross"
	var/color1 = "#000000"
	var/color2 = "#FFFFFF"
	flammable = TRUE
	layer = 3.2
/obj/structure/poster/religious/New()
	..()
	invisibility = 101
	spawn(10)
		if (religion != "none")
			name = "[religion]'s poster"
			desc = "This is a [religion] religion propaganda poster."
			var/image/overc = image("icon" = icon, "icon_state" = "poster_base_o1")
			overc.color = map.custom_religions[religion][6]
			overlays += overc
			var/image/overc1 = image("icon" = icon, "icon_state" = "poster_base_o2")
			overc1.color = map.custom_religions[religion][5]
			overlays += overc1
			var/image/overs = image("icon" = icon, "icon_state" = "holybook_[map.custom_religions[religion][4]]")
			overs.color = map.custom_religions[religion][5]
			overlays += overs
		transform = matrixangle(rand(-9,9))
		update_icon()
		invisibility = 0
/obj/structure/poster/religious/attackby(obj/item/weapon/W as obj, mob/user as mob)
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

obj/structure/altar
	name = "religious altar"
	icon = 'icons/obj/cross.dmi'
	icon_state = "wood_altar"
	desc = "A religious altar."
	var/religion = "none"
	var/symbol = "Cross"
	var/color1 = "#000000"
	var/color2 = "#FFFFFF"
	flammable = TRUE
	var/health = 70
	var/session = FALSE
/obj/structure/altar/New()
	..()
	invisibility = 101
	spawn(10)
		if (religion != "none")
			name = "[religion]'s altar"
			desc = "This is a altar dedicated to the [religion] religion."
			var/image/overc = image("icon" = icon, "icon_state" = "thin_banner_1")
			overc.color = map.custom_religions[religion][6]
			overlays += overc
			var/image/overc1 = image("icon" = icon, "icon_state" = "thin_banner_2")
			overc1.color = map.custom_religions[religion][5]
			overlays += overc1
			var/image/overs = image("icon" = icon, "icon_state" = "holybook_[map.custom_religions[religion][4]]")
			overs.color = map.custom_religions[religion][5]
			overlays += overs
		update_icon()
		invisibility = 0

/obj/structure/altar/attackby(obj/item/W as obj, mob/living/carbon/human/user as mob)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	if (user.a_intent == I_HELP && user.religion == religion && user.religious_clergy == "Cultists")
		if (istype(W, /obj/item/clothing/accessory/armband/talisman))
			var/obj/item/clothing/accessory/armband/talisman/T = W
			if (T.religion != religion)
				user << "You start destroying \the [W] in the name of your religion, [religion]..."
				if (do_after(user, 100, src))
					user << "You destroy \the [W]!"
					map.custom_religions[religion][3] += 3
					qdel(W)
					return
		else if (istype(W, /obj/item/weapon/book/holybook))
			var/obj/item/weapon/book/holybook/T = W
			if (T.religion != religion)
				user << "You start destroying \the [W] in the name of your religion, [religion]..."
				if (do_after(user, 100, src))
					user << "You destroy \the [W]!"
					map.custom_religions[religion][3] += 10
					qdel(W)
					return
		return
	switch(W.damtype)
		if ("fire")
			if (flammable)
				health -= W.force * TRUE
			else
				health -= W.force * 0.20
		else
			health -= W.force * 0.20
	playsound(get_turf(src), 'sound/effects/wood_cutting.ogg', 100)
	user.do_attack_animation(src)
	try_destroy()
	..()

/obj/structure/altar/proc/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		qdel(src)
		return


obj/structure/altar/attack_hand(mob/living/carbon/human/H as mob)
	if (H.religion == religion && (H.religious_clergy == "Priests" || H.religious_leader) && H.religion_style == "Priests")
		var/choice = WWinput(H, "What action do you want to perform?", "[religion]'s Altar", "Cancel", list("Cancel", "Worshipping Session", "Conversion"))
		switch(choice)
			if ("Cancel")
				return
			if ("Worshipping Session")
				if (!session)
					session = TRUE
					visible_message("[H] starts holding a worshipping session of the [religion] religion...")
					var/list/currlist = list()
					for (var/mob/living/carbon/human/A in range(3, loc))
						if (A.stat == 0 && A != H && A.religion == religion)
							currlist += A
					if (do_after(H, 600, src))
						var/list/currlist2 = list()
						for (var/mob/living/carbon/human/AA in range(3, loc))
							if (AA.stat == 0 && (AA in currlist))
								currlist2 += AA
						map.custom_religions[religion][3] += currlist2.len*0.8
						visible_message("[H] finishes the worshipping session of the [religion] religion.")
						session = FALSE
						return
					else
						session = FALSE
						return

			if ("Conversion")
				var/list/closemobs = list("Cancel")
				for (var/mob/living/carbon/human/M in range(2,loc))
					if (M.religion != religion && M.religious_clergy == FALSE && M.religion_style != "Clerics")
						closemobs += M
				var/choice3 = WWinput(H, "Who do you want to convert?", "[religion]'s Altar", "Cancel", closemobs)
				if (choice3 == "Cancel")
					return
				else
					var/mob/living/carbon/human/choice2 = choice3
					var/answer = WWinput(choice2, "[H] asks you to convert to his religion, [H.religion]. Will you accept?", null, "Yes", list("Yes","No"))
					if (answer == "Yes")
						usr << "[choice2] accepts your offer. They are worshipping [H.religion]."
						src << "You accept [H]'s offer. You are now worshipping [H.religion]."
						choice2.religion = H.religion
						choice2.religious_leader = FALSE
						choice2.religion_type = H.religion_type
						choice2.religion_style = H.religion_style
						return
					else if (answer == "No")
						usr << "[closemobs] has rejected your offer."
						return
					else
						return
	else
		..()

obj/structure/altar/wood
	name = "wood altar"
	icon_state = "wood_altar"
	flammable = TRUE
	health = 70

obj/structure/altar/stone
	name = "stone altar"
	icon_state = "stone_altar"
	flammable = FALSE
	health = 160

obj/structure/altar/marble
	name = "marble altar"
	icon_state = "marble_altar"
	flammable = FALSE
	health = 110

obj/structure/altar/iron
	name = "iron altar"
	icon_state = "iron_altar"
	flammable = FALSE
	health = 120



/obj/structure/banner/religious
	name = "religious banner"
	icon = 'icons/obj/cross.dmi'
	icon_state = "wall_banner"
	desc = "A white banner."
	var/religion = "none"
	var/symbol = "Cross"
	var/color1 = "#000000"
	var/color2 = "#FFFFFF"
	flammable = TRUE
	layer = 3.21

/obj/structure/banner/religious/New()
	..()
	invisibility = 101
	spawn(10)
		if (religion != "none")
			name = "[religion]'s banner"
			desc = "This is a [religion] religion banner."
			var/image/overc = image("icon" = icon, "icon_state" = "wall_banner_1")
			overc.color = map.custom_religions[religion][6]
			overlays += overc
			var/image/overc1 = image("icon" = icon, "icon_state" = "wall_banner_2")
			overc1.color = map.custom_religions[religion][5]
			overlays += overc1
			var/image/overs = image("icon" = icon, "icon_state" = "banner_[map.custom_religions[religion][4]]")
			overs.color = map.custom_religions[religion][5]
			overlays += overs
		update_icon()
		invisibility = 0

/obj/structure/banner/religious/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (W.sharp)
		user << "You start ripping off the [src]..."
		if (do_after(user, 130, src))
			visible_message("[user] rips the [src]!")
			qdel(src)
	else
		..()
