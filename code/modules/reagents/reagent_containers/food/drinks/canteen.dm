/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen
	dropsound = 'sound/effects/drop_default.ogg'
	name = "canteen"
	icon_state = "canteen_german"
	volume = 200
	w_class = ITEM_SIZE_NORMAL // fits in webbing unlike w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_ID|SLOT_BELT
	desc = "A very large canteen for storing water."

/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/full/New()
	..()
	reagents.add_reagent("water", 200)

/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/ww2
	dropsound = 'sound/effects/drop_default.ogg'
	name = "canteen"
	icon_state = "canteen_german"
	volume = 200
	w_class = ITEM_SIZE_NORMAL // fits in webbing unlike w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BELT|SLOT_ID
	desc = "A very large canteen for storing water."
	isGlass = FALSE

/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/ww2/New()
	..()
	reagents.add_reagent("water", 200)

/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/ww2/german
	dropsound = 'sound/effects/drop_default.ogg'
	name = "German canteen"
	icon_state = "canteen_german"
	volume = 200
	w_class = ITEM_SIZE_NORMAL // fits in webbing unlike w_class = ITEM_SIZE_LARGE
	desc = "A very large canteen for storing water."
/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/ww2/jap
	dropsound = 'sound/effects/drop_default.ogg'
	name = "Japanese canteen"
	icon_state = "canteen_jap"
	item_state = "canteen_jap"
	volume = 200
	w_class = ITEM_SIZE_NORMAL // fits in webbing unlike w_class = ITEM_SIZE_LARGE
	desc = "A very large canteen for storing water."
	icon_override = 'icons/mob/pouch.dmi'
/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/ww2/jap/New()
	..()
	reagents.add_reagent("water", 200)
/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/ww2/us
	dropsound = 'sound/effects/drop_default.ogg'
	name = "American canteen"
	icon_state = "canteen_us"
	volume = 200
	w_class = ITEM_SIZE_NORMAL // fits in webbing unlike w_class = ITEM_SIZE_LARGE
	desc = "A very large canteen for storing water."
/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/ww2/us/New()
	..()
	reagents.add_reagent("water", 200)

/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/ww2/rus
	dropsound = 'sound/effects/drop_default.ogg'
	name = "Russian canteen"
	icon_state = "canteen_soviet"
	volume = 200
	w_class = ITEM_SIZE_NORMAL // fits in webbing unlike w_class = ITEM_SIZE_LARGE
	desc = "A very large canteen for storing water."
/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/ww2/rus/New()
	..()
	reagents.add_reagent("water", 200)