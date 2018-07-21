/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen
	dropsound = 'sound/effects/drop_default.ogg'
	name = "Canteen"
	icon_state = "canteen_german"
	volume = 200
	w_class = 3 // fits in webbing unlike w_class = 4
	slot_flags = SLOT_BACK|SLOT_BELT
	desc = "A very large canteen for storing water."

/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/New()
	..()

/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/german
	icon_state = "canteen_german"
	name = "German Soldier's Canteen"
	isGlass = FALSE

/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/german/officer
	icon_state = "canteen_german_officer"
	name = "German Officer's Canteen"
	isGlass = FALSE

/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/pirates
	icon_state = "canteen_pirates"
	name = "Soviet Soldier's Canteen"

/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/pirates/officer
	icon_state = "canteen_pirates_officer"
	name = "Soviet Officer's Canteen"
	isGlass = FALSE