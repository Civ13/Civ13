
/obj/structure/closet/fridge
	name = "refrigerator"
	icon_state = "fridge1"
	icon_closed = "fridge"
	icon_opened = "fridgeopen"
	storage_capacity = MOB_MEDIUM
	powerneeded = 5

/obj/structure/closet/fridge/update_icon()
	if (!opened)
		icon_state = icon_closed
	else
		icon_state = icon_opened


