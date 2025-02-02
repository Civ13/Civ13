////////////////////////
/* Metal Rod and Wire */
////////////////////////

//Metal Rod
/obj/item/heatable/forged/rod
	name = "rod"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "rod"
	force = 5
	quenchable = FALSE
	handleable = FALSE
	draw_recipe = /obj/item/heatable/forged/thick

//Small Wire
/obj/item/heatable/forged/thick
	name = "thick guage wire"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "thickwire"
	force = 5
	quenchable = FALSE
	handleable = FALSE
	draw_recipe = /obj/item/heatable/forged/medium

/obj/item/heatable/forged/medium
	name = "medium guage wire"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "medwire"
	force = 5
	quenchable = FALSE
	handleable = FALSE
	draw_recipe = /obj/item/heatable/forged/small

/obj/item/heatable/forged/small
	name = "small guage wire"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "smallwire"
	force = 5
	quenchable = FALSE
	handleable = FALSE