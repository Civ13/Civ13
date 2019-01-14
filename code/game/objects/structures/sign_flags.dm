/obj/structure/sign/flag
	var/ripped = FALSE
	icon = 'icons/obj/decals.dmi'
	flammable = TRUE
/obj/structure/sign/flag/attack_hand(mob/user as mob)
	if (!ripped)
		playsound(loc, 'sound/items/poster_ripped.ogg', 100, TRUE)
		for (var/i = FALSE to 3)
			if (do_after(user, 10))
				playsound(loc, 'sound/items/poster_ripped.ogg', 100, TRUE)
			else
				return
		visible_message("<span class='warning'>[user] rips [src]!</span>" )
		qdel(src)

/obj/structure/sign/flag/red
	name = "\improper red banner"
	desc = "A red linen banner."
	icon_state = "red_banner"
/obj/structure/sign/flag/red2
	name = "\improper red banner"
	desc = "A red linen banner, with golden trims."
	icon_state = "red_banner2"

/obj/structure/sign/flag/blue
	name = "\improper blue banner"
	desc = "A blue linen banner."
	icon_state = "blue_banner"
/obj/structure/sign/flag/blue2
	name = "\improper blue banner"
	desc = "A blue linen banner, with golden trims."
	icon_state = "blue_banner2"

/obj/structure/sign/flag/templar1
	name = "\improper templar banner"
	desc = "A white banner with the red cross of the templars in the middle."
	icon_state = "templar_banner1"

/obj/structure/sign/flag/templar2
	name = "\improper templar banner"
	desc = "A white banner with the red cross of the templars in the middle."
	icon_state = "templar_banner2"

/obj/structure/sign/flag/jihad1
	name = "\improper black islamic flag"
	desc = "A black flag with Allah written in Arabic."
	icon_state = "jihad1"

/obj/structure/sign/flag/jihad2
	name = "\improper green islamic flag"
	desc = "A green flag with Allah written in Arabic."
	icon_state = "jihad2"

/obj/structure/sign/flag/jihad3
	name = "\improper red islamic banner"
	desc = "A red banner with three moons."
	icon_state = "jihad3"

/obj/structure/sign/flag/jihad4
	name = "\improper green islamic banner"
	desc = "A greeb banner with the shadada."
	icon_state = "jihad4"

/obj/structure/sign/clock
	name = "\improper Broken clock"
	desc = "Stopped at 5 o'clock."
	icon_state = "clock"

/obj/structure/sign/wide
	icon = 'icons/obj/decals_wide.dmi'
	bound_x = 32

/obj/structure/sign/wide/carpet
	name = "\improper Carpet"
	desc = "A low quality carpet dangling on the wall."
	icon = 'icons/obj/decals_wide.dmi'
	icon_state = "carpet"
	layer = OBJ_LAYER - 0.1


/obj/structure/sign/flag/medical
	name = "Medical flag"
	desc = "A flag with the universally recognized symbol for medicine."
	icon_state = "medical_flag"

/obj/structure/sign/flag/japanese
	name = "Imperial Japanese Flag"
	desc = "A flag with the imperial japanese flag."
	icon_state = "japanese"


/obj/structure/sign/flag/custom
	name = "flag"
	desc = "A flag."
	icon_state = "f_white"

/obj/item/flagmaker
	name = "custom flag maker"
	desc = "A white cotton sheet and some colored ink."
	icon = 'icons/obj/decals.dmi'
	icon_state = "flagmaker"
	var/new_icon_state = "White"

/obj/item/flagmaker/attack_self(mob/user)
	var/list/display1 = list("White", "Black", "Yellow", "Blue", "Red", "Green", "Cancel")

	var/choice1 = WWinput(user, "What background color do you want for the flag?", "Flag Maker", "Cancel", display1)
	if (choice1 == "Cancel")
		return
	if (choice1 == "White")
		new_icon_state = "f_white"
		icon_state = "f_white"
	if (choice1 == "Black")
		new_icon_state = "f_black"
		icon_state = "f_black"
	if (choice1 == "Yellow")
		new_icon_state = "f_yellow"
		icon_state = "f_yellow"
	if (choice1 == "Blue")
		new_icon_state = "f_blue"
		icon_state = "f_blue"
	if (choice1 == "Red")
		new_icon_state = "f_red"
		icon_state = "f_red"
	if (choice1 == "Green")
		new_icon_state = "f_green"
		icon_state = "f_green"

	var/list/display2 = list("White", "Black", "Yellow", "Blue", "Red", "Green", "No")

	var/choice2 = WWinput(user, "Add a left-half color?", "Flag Maker", "No", display2)
	if (choice2 == "No")
		icon_state = new_icon_state
	if (choice2 == "White")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fl_white")
		overlays += flag_left
	if (choice2 == "Black")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fl_black")
		overlays += flag_left
	if (choice2 == "Yellow")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fl_yellow")
		overlays += flag_left
	if (choice2 == "Blue")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fl_blue")
		overlays += flag_left
	if (choice2 == "Red")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fl_red")
		overlays += flag_left
	if (choice2 == "Green")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fl_green")
		overlays += flag_left
	var/list/display3 = list("White", "Black", "Yellow", "Blue", "Red", "Green", "No")

	var/choice3 = WWinput(user, "Add a right-half color?", "Flag Maker", "No", display3)
	if (choice3 == "No")
		icon_state = new_icon_state
	if (choice3 == "White")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fr_white")
		overlays += flag_left
	if (choice3 == "Black")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fr_black")
		overlays += flag_left
	if (choice3 == "Yellow")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fr_yellow")
		overlays += flag_left
	if (choice3 == "Blue")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fr_blue")
		overlays += flag_left
	if (choice3 == "Red")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fr_red")
		overlays += flag_left
	if (choice3 == "Green")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fr_green")
		overlays += flag_left
	var/list/display4 = list("White", "Black", "Yellow", "Blue", "Red", "Green", "No")

	var/choice4 = WWinput(user, "Add a left-third color?", "Flag Maker", "No", display4)
	if (choice4 == "No")
		icon_state = new_icon_state
	if (choice4 == "White")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f1_white")
		overlays += flag_left
	if (choice4 == "Black")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f1_black")
		overlays += flag_left
	if (choice4 == "Yellow")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f1_yellow")
		overlays += flag_left
	if (choice4 == "Blue")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f1_blue")
		overlays += flag_left
	if (choice4 == "Red")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f1_red")
		overlays += flag_left
	if (choice4 == "Green")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f1_green")
		overlays += flag_left

	var/list/display5 = list("White", "Black", "Yellow", "Blue", "Red", "Green", "No")

	var/choice5 = WWinput(user, "Add a center-third color?", "Flag Maker", "No", display5)
	if (choice5 == "No")
		icon_state = new_icon_state
	if (choice5 == "White")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f2_white")
		overlays += flag_left
	if (choice5 == "Black")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f2_black")
		overlays += flag_left
	if (choice5 == "Yellow")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f2_yellow")
		overlays += flag_left
	if (choice5 == "Blue")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f2_blue")
		overlays += flag_left
	if (choice5 == "Red")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f2_red")
		overlays += flag_left
	if (choice5 == "Green")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f2_green")
		overlays += flag_left

	var/list/display6 = list("White", "Black", "Yellow", "Blue", "Red", "Green", "No")

	var/choice6 = WWinput(user, "Add a right-third color?", "Flag Maker", "No", display6)
	if (choice6 == "No")
		icon_state = new_icon_state
	if (choice6 == "White")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f3_white")
		overlays += flag_left
	if (choice6 == "Black")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f3_black")
		overlays += flag_left
	if (choice6 == "Yellow")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f3_yellow")
		overlays += flag_left
	if (choice6 == "Blue")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f3_blue")
		overlays += flag_left
	if (choice6 == "Red")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f3_red")
		overlays += flag_left
	if (choice6 == "Green")
		var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f3_green")
		overlays += flag_left

	var/list/display8 = list("White Cross", "Black Cross", "Blue Cross", "Red Cross", "Green Cross", "No")
	var/choice8 = WWinput(user, "Add a cross?", "Flag Maker", "No", display8)
	if (choice8 == "No")
		icon_state = new_icon_state
	if (choice8 == "White Cross")
		var/image/cross = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_bigcross2")
		overlays += cross
	if (choice8 == "Black Cross")
		var/image/cross = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_bigcross0")
		overlays += cross
	if (choice8 == "Blue Cross")
		var/image/cross = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_bigcross3")
		overlays += cross
	if (choice8 == "Red Cross")
		var/image/cross = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_bigcross1")
		overlays += cross
	if (choice8 == "Green Cross")
		var/image/cross = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_bigcross4")
		overlays += cross

	var/list/display9 = list("White Saltire", "Black Saltire", "Blue Saltire", "Red Saltire", "Green Saltire", "No")
	var/choice9 = WWinput(user, "Add a saltire?", "Flag Maker", "No", display9)
	if (choice9 == "No")
		icon_state = new_icon_state
	if (choice9 == "White Saltire")
		var/image/saltire = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_saltire2")
		overlays += saltire
	if (choice9 == "Black Saltire")
		var/image/saltire = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_saltire0")
		overlays += saltire
	if (choice9 == "Blue Saltire")
		var/image/saltire = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_saltire3")
		overlays += saltire
	if (choice9 == "Red Saltire")
		var/image/saltire = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_saltire1")
		overlays += saltire
	if (choice9 == "Green Saltire")
		var/image/saltire = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_saltire4")
		overlays += saltire

	var/list/display7 = list("White Star", "Black Star", "Golden Star", "White Moon", "Black Moon", "Golder Moon", "White Cross", "Black Cross", "Golden Cross","Red Circle","Red Sun","White Skull", "White Peace Sign", "Black Peace Sign", "No")

	var/choice7 = WWinput(user, "Add a symbol?", "Flag Maker", "No", display7)
	if (choice7 == "No")
		icon_state = new_icon_state
	if (choice7 == "White Star")
		var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_star0")
		overlays += flag_symbol
	if (choice7 == "Black Star")
		var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_star2")
		overlays += flag_symbol
	if (choice7 == "Golden Star")
		var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_star1")
		overlays += flag_symbol
	if (choice7 == "White Moon")
		var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_moon0")
		overlays += flag_symbol
	if (choice7 == "Black Moon")
		var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_moon2")
		overlays += flag_symbol
	if (choice7 == "Golden Moon")
		var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_moon1")
		overlays += flag_symbol
	if (choice7 == "White Cross")
		var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_cross0")
		overlays += flag_symbol
	if (choice7 == "Black Cross")
		var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_cross2")
		overlays += flag_symbol
	if (choice7 == "Golden Cross")
		var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_cross1")
		overlays += flag_symbol
	if (choice7 == "Red Circle")
		var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_circle0")
		overlays += flag_symbol
	if (choice7 == "Red Sun")
		var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_sun1")
		overlays += flag_symbol
	if (choice7 == "Black Peace Sign")
		var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_peace0")
		overlays += flag_symbol
	if (choice7 == "White Peace Sign")
		var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_peace1")
		overlays += flag_symbol
	if (choice7 == "White Skull")
		var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_skull0")
		overlays += flag_symbol

	var/_name = input(usr, "Name the flag:") as text|null
	if (_name == "" || _name == null)
		name = "flag"
	else
		name = sanitize(_name, 50)

	var/obj/structure/sign/flag/custom/CF = new/obj/structure/sign/flag/custom(user.loc)
	CF.overlays = overlays
	CF.icon_state = new_icon_state
	qdel(src)
	return