/obj/item/weapon/storage/bible
	name = "The Holy Bible"
	desc = "Apply to head repeatedly."
	icon_state ="bible"
	item_state = "bible"
	throw_speed = TRUE
	throw_range = 5
	w_class = 3.0
	var/mob/affecting = null
/obj/item/weapon/storage/bible/orthodox
	icon_state ="orthodoxbible"
	item_state = "orthodoxbible"

/obj/item/weapon/storage/bible/booze
	name = "bible"
	desc = "To be applied to the head repeatedly."
	icon_state ="bible"

/obj/item/weapon/storage/bible/booze/New()
	..()
	new /obj/item/weapon/reagent_containers/food/drinks/bottle/small/beer(src)
	new /obj/item/weapon/reagent_containers/food/drinks/bottle/small/beer(src)