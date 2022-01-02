//Rad stuff and special grown goes here.
//food.dmi
/obj/item/weapon/reagent_containers/food/snacks/grown/greenpotato
	name = "green potato"
	icon_state = "green_potato"
	desc = "Left in the sun too long, looks weird."
	color = "#8b7355"
	nutriment_desc = list("potato" = TRUE)
	decay = 70*800
	satisfaction = -3
	New()
		..()
		reagents.add_reagent("solanine", 10)