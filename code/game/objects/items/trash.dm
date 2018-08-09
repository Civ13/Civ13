//Items labled as 'trash' for the trash bag.
//TODO: Make this an item var or something...

//Added by Jack Rost
/obj/item/trash
	icon = 'icons/obj/trash.dmi'
	w_class = 2.0
	desc = "This is rubbish."


/obj/item/trash/plate
	name = "plate"
	icon_state = "plate"
	dropsound = 'sound/effects/drop_glass.ogg'

/obj/item/trash/snack_bowl
	name = "bowl"
	icon_state = "snack_bowl"
	dropsound = 'sound/effects/drop_glass.ogg'

/obj/item/trash/wood_bowl
	name = "wood bowl"
	icon_state = "wood_bowl"

/obj/item/trash/snack_bowl/New()
	..()
	pixel_x = rand(-5,5)

/obj/item/trash/wood_bowl/New()
	..()
	pixel_x = rand(-5,5)
/obj/item/trash/tray
	name = "tray"
	icon_state = "tray"

/obj/item/trash/candle
	name = "candle"
	icon = 'icons/obj/candle.dmi'
	icon_state = "candle4"

/obj/item/trash/money
	name = "Money"
	desc = "A pile of banknotes."
	icon_state = "money"

/obj/item/trash/attack(mob/M as mob, mob/living/user as mob)
	return
