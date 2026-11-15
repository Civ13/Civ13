/obj/structure/fish
	name = "fish"
	desc = "There seems to be a bunch of fish here."
	icon = 'icons/mob/fish.dmi'
	icon_state = "fish2"
	var/counter = 2
	anchored = TRUE
	var/species = "fish"
	not_movable = TRUE
	not_disassemblable = TRUE
/obj/structure/fish/salmon
	name = "salmon"
	desc = "Salmons. Don't let bears get near!"
	icon = 'icons/mob/fish.dmi'
	icon_state = "salmon"
	counter = 2
	anchored = TRUE
	species = "salmon"
/obj/structure/fish/cod
	name = "codfish"
	desc = "Seems like theres some cod's around here..."
	icon = 'icons/mob/fish.dmi'
	icon_state = "cod"
	counter = 1
	anchored = TRUE
	species = "cod"
/obj/structure/fish/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
	if (istype(W, /obj/item/weapon/fishing) && counter > 0)
		H.visible_message("[H] starts fishing.")
		if (istype(W, /obj/item/weapon/fishing/modern))
			if (do_after(H, 120, src))
				if (counter <= 0)
					return
				if (prob(40))
					to_chat(H, "You got a fish!")
					counter = (counter-1)
					if (species == "salmon")
						new/obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon(H.loc)
					else if (species == "cod")
						new/obj/item/weapon/reagent_containers/food/snacks/rawfish/cod(H.loc)
					else
						new/obj/item/weapon/reagent_containers/food/snacks/rawfish(H.loc)
					if (counter <= 0)
						invisibility = 101
					get_fish()
					return
				else
					to_chat(H, "You can't seem to get anything to bite...")
					return
		else
			if (do_after(H, 150, src))
				if (counter <= 0)
					return
				if (prob(30))
					to_chat(H, "You got a fish!")
					counter = (counter-1)
					if (species == "salmon")
						new/obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon(H.loc)
					else if (species == "cod")
						new/obj/item/weapon/reagent_containers/food/snacks/rawfish/cod(H.loc)
					else
						new/obj/item/weapon/reagent_containers/food/snacks/rawfish(H.loc)
					if (counter <= 0)
						invisibility = 101
					get_fish()
					return
				else
					to_chat(H, "You can't seem to get anything to bite...")
					return
	else if (istype(W, /obj/item/weapon/branch) && counter > 0)
		var/obj/item/weapon/branch/B = W
		if (B.sharpened)
			H.visible_message("[H] starts fishing.")
			if (do_after(H, 120, src))
				if (counter <= 0)
					return
				if (prob(20))
					to_chat(H, "You got a fish!")
					counter = (counter-1)
					if (species == "salmon")
						new/obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon(H.loc)
					else if (species == "cod")
						new/obj/item/weapon/reagent_containers/food/snacks/rawfish/cod(H.loc)
					else
						new/obj/item/weapon/reagent_containers/food/snacks/rawfish(H.loc)
					if (counter <= 0)
						invisibility = 101
					get_fish()
					return
				else
					to_chat(H, "You can't seem to get anything to bite...")
					return
/obj/structure/fish/proc/get_fish()
	if (counter < 2)
		spawn(rand(3000,3600))
			counter = (counter+1)
			if (invisibility == 101)
				invisibility = 0
				update_icon()

/obj/structure/anthill
	name = "anthill"
	desc = "A hill of giant red ants. Keep your food away!"
	icon = 'icons/mob/animal.dmi'
	icon_state = "anthill"
	anchored = TRUE

/obj/structure/anthill/New()
	..()
	check_food()

/obj/structure/anthill/proc/check_food()
	var/done = FALSE
	for (var/obj/item/weapon/reagent_containers/food/FD in range(6, src))
		if (done == FALSE)
			new/obj/structure/ants(FD.loc)
			done = TRUE
	spawn(600) // 1 minute 
		check_food()

/obj/structure/anthill/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/branch))
		var/obj/item/weapon/branch/B = W
		user.visible_message(SPAN_WARNING("[user] starts poking inside \the [src] with \the [B]."), SPAN_WARNING("You start poking inside \the [src] with \the [B]."))
		if (do_after(user, 120, src))
			if (prob(75))
				to_chat(user, SPAN_WARNING("You get some ants on \the [src]!"))
				B.ants = TRUE
				B.icon_state = "ant_stick"
			else
				to_chat(user, SPAN_NOTICE("You can't seem to get any ants to react..."))
				return
	else if (istype(W, /obj/item/weapon/reagent_containers) && W.reagents.has_reagent("water", 10)) // If holds reagents and has 10 units of water.
		W.reagents.remove_reagent("water", 10)
		user.visible_message(SPAN_NOTICE("[user] pours water onto \the [src], destroying it!"), SPAN_NOTICE("You pour water onto \the [src], destroying it!"))
		visible_message(SPAN_WARNING("A bunch of red ants suddenly rush out of \the destroyed [src]!"))
		new/obj/structure/ants(loc) // The ants delete in 1 minute if they do not find food.
		qdel(src) // Delete the ant-hill.

/obj/structure/ants
	name = "red ants"
	desc = "A bunch of red ants."
	icon = 'icons/mob/animal.dmi'
	icon_state = "ants"
	anchored = FALSE
	layer = 4

/obj/structure/ants/New()
	..()
	check_food()
	spawn(600) // 1 minute
		if (src)
			qdel(src)

/obj/structure/ants/proc/check_food()
	spawn(400)
		var/done = FALSE
		var/msg_sent = FALSE
		for (var/obj/item/weapon/reagent_containers/food/FD in src.loc)
			if (msg_sent == FALSE)
				visible_message("The ants eat \the [FD]!")
				msg_sent = TRUE
			done = TRUE
			qdel(FD)
		if (done == TRUE)
			qdel(src)
		else
			check_food()
