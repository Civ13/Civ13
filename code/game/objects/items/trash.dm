//Items labled as 'trash' for the trash bag.
//TODO: Make this an item var or something...

//Added by Jack Rost
/obj/item/trash
	icon = 'icons/obj/trash.dmi'
	w_class = 2.0
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

/obj/item/trash/money
	name = "Money"
	desc = "A pile of banknotes."
	icon_state = "money"
	flammable = TRUE

/obj/item/trash/attack(mob/M as mob, mob/living/user as mob)
	return
