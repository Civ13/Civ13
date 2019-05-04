/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen
	dropsound = 'sound/effects/drop_default.ogg'
	name = "Canteen"
	icon_state = "canteen_german"
	volume = 200
	w_class = 3 // fits in webbing unlike w_class = 4
	slot_flags = SLOT_BACK|SLOT_BELT
	desc = "A very large canteen for storing water."

/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/full/New()
	..()
	reagents.add_reagent("water", 200)