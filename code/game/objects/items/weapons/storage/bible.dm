/obj/item/weapon/storage/bible
	name = "The Holy Bible"
	desc = "Apply to head repeatedly."
	icon_state ="bible"
	item_state = "bible"
	throw_speed = TRUE
	throw_range = 5
	w_class = ITEM_SIZE_NORMAL
	var/mob/affecting = null

/obj/item/weapon/storage/bible/orthodox
	name = "The Holy Bible"
	icon_state ="orthodoxbible"
	item_state = "orthodoxbible"
	desc = "The orthodox bible."
	flags = FALSE

/obj/item/weapon/storage/bible/quran
	name = "The Quran"
	icon_state ="koran"
	item_state = "koran"
	desc ="Muslim holy book."

/obj/item/weapon/storage/bible/talmud
	name = "The Talmud"
	icon_state ="talmud"
	item_state = "talmud"
	desc ="Jewish holy book."

/obj/item/weapon/storage/bible/booze
	name = "bible"
	desc = "To be applied to the head repeatedly."
	icon_state ="bible"

/obj/item/weapon/storage/bible/booze/New()
	..()
	new /obj/item/weapon/reagent_containers/food/drinks/bottle/small/beer(src)
	new /obj/item/weapon/reagent_containers/food/drinks/bottle/small/beer(src)