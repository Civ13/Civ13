
/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/custom
	icon = 'icons/obj/custom_containers.dmi'
	var/uncolored = TRUE
	var/image/color1
	var/image/color2
	var/topcolor = "#000000"
	var/undercolor = "#FFFFFF"
	New()
		..()
		color1 = image(icon, "[icon_state]_label1")
		color2 = image(icon, "[icon_state]_label2")
		overlays += color1
		overlays += color2
		update_icon()
/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/custom/New()
	..()
	fluid_image = image('icons/obj/custom_containers.dmi', "fluid-[glass_type]")
	update_icon()

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/custom/update_icon()
	..()
	overlays.Cut()
	if (reagents.total_volume > 0)
		if (!fluid_image)
			fluid_image = image('icons/obj/custom_containers.dmi', "fluid-[glass_type]")
		fluid_image.color = reagents.get_color()
		overlays += fluid_image
	overlays += color1
	overlays += color2

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/custom/fastfoodcup
	volume = 40
	name = "fast food cup"
	desc = "A plastic fast food cup."
	icon_state = "fastfoodcup"
	item_state = "beer"
	value = 1


/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/custom/attack_self(mob/user as mob)
	if (uncolored)
		var/input = WWinput(user, "Logo Symbol - Choose the logo symbol color:", "Main Color" , "#000000", "color")
		if (input == null || input == "")
			return
		else

			topcolor= input

		input = WWinput(user, "Background color - Choose the background color:", "Background Color" , "#FFFFFF", "color")
		if (input == null || input == "")
			return
		else

			undercolor= input
		uncolored = FALSE
		color1.color = topcolor
		color2.color = undercolor
		update_icon()
	else
		..()


/obj/item/weapon/reagent_containers/food/drinks/plastic
	icon = 'icons/obj/custom_containers.dmi'
	var/uncolored = TRUE
	var/image/color1
	var/image/color2
	var/topcolor = "#000000"
	var/undercolor = "#FFFFFF"
	var/image/fluid_image
	New()
		..()
		color1 = image(icon, "[icon_state]_label1")
		color2 = image(icon, "[icon_state]_label2")
		overlays += color1
		overlays += color2
		fluid_image = image('icons/obj/custom_containers.dmi', "fluid-[icon_state]")
		update_icon()

	on_reagent_change()
		update_icon()

/obj/item/weapon/reagent_containers/food/drinks/plastic/attack_self(mob/user as mob)
	if (uncolored)
		var/input = WWinput(user, "Logo Symbol - Choose the logo symbol color:", "Main Color" , "#000000", "color")
		if (input == null || input == "")
			return
		else

			topcolor= input

		input = WWinput(user, "Background color - Choose the background color:", "Background Color" , "#FFFFFF", "color")
		if (input == null || input == "")
			return
		else

			undercolor= input
		uncolored = FALSE
		color1.color = topcolor
		color2.color = undercolor
		update_icon()
	else
		..()

/obj/item/weapon/reagent_containers/food/drinks/plastic/update_icon()
	overlays.Cut()
	if (reagents.total_volume > 0)
		if (!fluid_image)
			fluid_image = image('icons/obj/custom_containers.dmi', "fluid-[icon_state]")
		fluid_image.color = reagents.get_color()
		overlays += fluid_image
	overlays += color1
	overlays += color2
	return

/obj/item/weapon/reagent_containers/food/drinks/plastic/cola
	volume = 70
	name = "plastic bottle"
	desc = "A plastic bottle."
	icon_state = "cola"
	item_state = "beer"
	value = 3

/obj/item/weapon/reagent_containers/food/drinks/plastic/condiment
	volume = 25
	name = "condiment bottle"
	desc = "A plastic condiment bottle."
	icon_state = "condiment"
	item_state = "beer"
	value = 0.5

/obj/item/weapon/reagent_containers/food/drinks/plastic/tallcan
	volume = 50
	name = "tall can"
	desc = "A metallic tall can."
	icon_state = "tallcan"
	item_state = "beer"
	value = 1

/obj/item/weapon/reagent_containers/food/drinks/plastic/sodacan
	volume = 30
	name = "soda can"
	desc = "A metallic soda can."
	icon_state = "sodacan"
	item_state = "beer"
	value = 0.75

/obj/item/weapon/reagent_containers/food/drinks/plastic/gallonjug
	volume = 160
	name = "gallon jug"
	desc = "A gallon-sized jug."
	icon_state = "gallonjug"
	item_state = "beer"
	value = 1.25

/obj/item/weapon/reagent_containers/food/drinks/plastic/carton
	volume = 50
	name = "carton"
	desc = "A cardboard milk-style carton."
	icon_state = "carton"
	item_state = "beer"
	value = 1


//Small bottles
/obj/item/weapon/reagent_containers/food/drinks/bottle/small/custom
	icon = 'icons/obj/custom_containers.dmi'
	volume = 35
	var/uncolored = TRUE
	var/image/color1
	var/image/color2
	var/topcolor = "#000000"
	var/undercolor = "#FFFFFF"
	var/image/fluid_image
	New()
		..()
		color1 = image(icon, "[icon_state]_label1")
		color2 = image(icon, "[icon_state]_label2")
		overlays += color1
		overlays += color2
		fluid_image = image('icons/obj/custom_containers.dmi', "fluid-[icon_state]")
		update_icon()

	on_reagent_change()
		update_icon()

/obj/item/weapon/reagent_containers/food/drinks/bottle/small/custom/attack_self(mob/user as mob)
	if (uncolored)
		var/input = WWinput(user, "Logo Symbol - Choose the logo symbol color:", "Main Color" , "#000000", "color")
		if (input == null || input == "")
			return
		else

			topcolor= input

		input = WWinput(user, "Background color - Choose the background color:", "Background Color" , "#FFFFFF", "color")
		if (input == null || input == "")
			return
		else

			undercolor= input
		uncolored = FALSE
		color1.color = topcolor
		color2.color = undercolor
		update_icon()
	else
		..()

/obj/item/weapon/reagent_containers/food/drinks/bottle/small/custom/update_icon()
	overlays.Cut()
	if (reagents.total_volume > 0)
		if (!fluid_image)
			fluid_image = image('icons/obj/custom_containers.dmi', "fluid-[icon_state]")
		fluid_image.color = reagents.get_color()
		overlays += fluid_image
	overlays += color1
	overlays += color2
	return


/obj/item/weapon/reagent_containers/food/drinks/bottle/small/custom/beer
	volume = 40
	name = "beer bottle"
	desc = "A glass beer bottle."
	icon_state = "normalbeer"
	item_state = "beer"
	value = 1

/obj/item/weapon/reagent_containers/food/drinks/bottle/small/custom/fancybeer
	volume = 50
	name = "fancy beer bottle"
	desc = "A fancy glass beer bottle."
	icon_state = "fancybeer"
	item_state = "beer"
	value = 1.5

/obj/item/weapon/storage/foodbox
	name = "food box"
	desc = "A box. Contains food."
	icon_state = "foodbox"
	item_state = "foodbox"
	w_class = ITEM_SIZE_SMALL
	max_w_class = 2
	max_storage_space = 5
	flammable = TRUE
	icon = 'icons/obj/custom_containers.dmi'
	var/uncolored = TRUE
	var/image/color1
	var/image/color2
	var/topcolor = "#000000"
	var/undercolor = "#FFFFFF"
	New()
		..()
		color1 = image(icon, "[icon_state]_label1")
		color2 = image(icon, "[icon_state]_label2")
		overlays += color1
		overlays += color2
		update_icon()

/obj/item/weapon/storage/foodbox/attack_self(mob/user as mob)
	if (uncolored)
		var/input = WWinput(user, "Logo Symbol - Choose the logo symbol color:", "Main Color" , "#000000", "color")
		if (input == null || input == "")
			return
		else

			topcolor= input

		input = WWinput(user, "Background color - Choose the background color:", "Background Color" , "#FFFFFF", "color")
		if (input == null || input == "")
			return
		else

			undercolor= input
		uncolored = FALSE
		color1.color = topcolor
		color2.color = undercolor
		update_icon()
	else
		..()

/obj/item/weapon/storage/foodbox/update_icon()
	overlays.Cut()
	overlays += color1
	overlays += color2

/obj/item/weapon/storage/foodbox/chippack
	name = "chip pack"
	desc = "A small pack of food."
	icon_state = "chippack"
	item_state = "chippack"
	w_class = ITEM_SIZE_TINY
	max_w_class = 1
	max_storage_space = 3