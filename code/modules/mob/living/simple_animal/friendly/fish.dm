/obj/structure/fish
	name = "fish"
	desc = "There seems to be a bunch of fish here."
	icon = 'icons/mob/fish.dmi'
	icon_state = "fish2"
	var/counter = 2
	anchored = TRUE
	var/species = "fish"

/obj/structure/fish/salmon
	name = "salmon"
	desc = "Salmons. Don't let bears get near!"
	icon = 'icons/mob/fish.dmi'
	icon_state = "salmon"
	counter = 2
	anchored = TRUE
	species = "salmon"

/obj/structure/fish/attackby(var/obj/item/stack/W as obj, var/mob/living/carbon/human/H as mob)
	if (istype(W, /obj/item/weapon/fishing) && counter > 0)
		H.visible_message("[H] starts fishing.")
		if (do_after(H, 150, src))
			if (prob(30))
				H << "You got a fish!"
				counter = (counter-1)
				if (species == "salmon")
					new/obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon(H.loc)
				else
					new/obj/item/weapon/reagent_containers/food/snacks/rawfish(H.loc)
				if (counter <= 0)
					invisibility = 101
				get_fish()
				return
			else
				H << "You can't seem to get anything to bite..."
				return

/obj/structure/fish/proc/get_fish()
	if (counter < 2)
		spawn(rand(3000,3600))
			counter = (counter+1)
			if (invisibility == 101)
				invisibility = 0
				update_icon()