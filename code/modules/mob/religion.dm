///////////////////////RELIGION/////////////////////////
/mob/living/carbon/human/proc/create_religion()
	set name = "Create Religion"
	set category = "Faction"
	var/mob/living/carbon/human/U

	if (istype(src, /mob/living/carbon/human))
		U = src
	else
		return
	if (map.nomads == TRUE)
		if (U.civilization != "none")
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
		H.religion = newname
		map.custom_religion_nr += newname
		var/choosetype = "default"
		var/choosesymbol = "star"
		var/choosecolor1 = "#000000"
		var/choosecolor2 = "#FFFFFF"
		choosetype = WWinput(src, "Choose a focus for the new religion:", "Religion Creation", "Cancel", list("Cancel","Combat","Knowledge","Production"))
		if (choosetype == "Cancel")
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
		H.religion_type = choosetype
		map.custom_religion_nr += newname
		//////////////////////////////////////creator, type, points, symbol, color1, color2
		var/newnamev = list("[newname]" = list(H,choosetype,0, choosesymbol,choosecolor1,choosecolor2))
		map.custom_religions += newnamev
		usr << "<big>You are now the leader of the <b>[newname]</b> religion.</big>"
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
		else if (U.religious_leader)
			usr << "<span class='danger'>You cannot leave a religion you founded!</span>"
			return
		else
			if (map.custom_religions[U.religion][1] != null)
				if (map.custom_religions[U.religion][1].real_name == U.real_name)
					map.custom_religions[U.religion][1] = null
			U.religion = "none"
			U.religion_type = "none"
			U.religious_leader = FALSE
			usr << "You left your religion. You are now an atheist."
	else
		usr << "<span class='danger'>You cannot leave your religion in this map.</span>"
		return


/mob/living/carbon/human/proc/religion_check()
	for (var/obj/item/clothing/CT in contents)
		for (var/obj/item/clothing/accessory/armband/talisman/T in CT.contents)
			if (T.religion == "none")
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
	else if (user.religion != religion && religion != "none" && !user.religious_leader)
		user << "You start reading the [title]..."
		if (do_after(user, 900, src))
			var/choice = WWinput(user, "After reading the [title], you feel attracted to the [religion] religion. Do you want to convert?", "[title]", "Yes", list("Yes","No"))
			if (choice == "No")
				return
			else if (choice == "Yes")
				user.religion = religion
				user.religious_leader = FALSE
				user.religion_type = religion_type
				user << "<big>You convert to the [religion] religion!</big>"
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