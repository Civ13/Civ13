//Items labled as 'trash' for the trash bag.
//TODO: Make this an item var or something...

//Added by Jack Rost
/obj/item/trash
	icon = 'icons/obj/trash.dmi'
	w_class = ITEM_SIZE_SMALL
	desc = "This is rubbish."
	value = 0

/obj/item/kitchen/plate
	name = "plate"
	desc = "a common plate."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "plate"
	dropsound = 'sound/effects/drop_glass.ogg'

/obj/item/kitchen/snack_bowl
	name = "bowl"
	desc = "a common bowl."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "snack_bowl"
	dropsound = 'sound/effects/drop_glass.ogg'
	value = 4

/obj/item/kitchen/wood_bowl
	name = "wood bowl"
	desc = "a common wood bowl."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "wood_bowl"
	value = 2
	flammable = TRUE

/obj/item/kitchen/snack_bowl/New()
	..()
	pixel_x = rand(-5,5)

/obj/item/kitchen/wood_bowl/New()
	..()
	pixel_x = rand(-5,5)
/obj/item/trash/tray
	name = "tray"
	desc = "a common tray."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "tray"

/obj/item/trash/candle
	name = "candle"
	icon = 'icons/obj/candle.dmi'
	icon_state = "candle4"
	flammable = TRUE

/obj/item/trash/candle/lard
	name = "lard candle"
	icon = 'icons/obj/candle.dmi'
	icon_state = "candle4_lard"
	flammable = TRUE
	attackby(obj/item/W as obj, mob/user as mob)
		if(istype(W, /obj/item/weapon/reagent_containers/glass))
			var/obj/item/weapon/reagent_containers/glass/G = W
			if(!G.is_open_container())
				user << "<span class='notice'>\The [G.name] is closed.</span>"
				return
			if(!G.reagents.get_free_space())
				user << "<span class='notice'>[G.name] is full.</span>"
				return
			user << "You smash the [src.name] inside the [G.name], creating lard."
			G.reagents.add_reagent("lard", 1)
			qdel(src)
			return
		else
			return ..()

/obj/item/trash/money
	name = "Money"
	desc = "A pile of banknotes."
	icon_state = "money"
	flammable = TRUE

/obj/item/trash/attack(mob/M as mob, mob/living/user as mob)
	return
