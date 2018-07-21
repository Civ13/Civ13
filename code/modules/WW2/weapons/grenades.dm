/obj/item/weapon/grenade/explosive
	slot_flags = SLOT_BELT|SLOT_MASK
	throw_speed = 2

/obj/item/weapon/grenade/explosive/stgnade
	name = "Stielgranate 41"
	icon_state = "stgnade"
	explosion_size = 4
	num_fragments = 37

/obj/item/weapon/grenade/explosive/rgd
	name = "RGD-33"
	icon_state = "rgd"
	explosion_size = 4
	num_fragments = 37

/obj/item/weapon/grenade/explosive/kamikaze
	name = "Kamikaze Charge"
	icon_state = "kamikaze"
	explosion_size = 6
	num_fragments = 80
	big_bomb = TRUE
	throw_speed = 1
	throw_range = FALSE
	nothrow = TRUE

/obj/item/weapon/grenade/explosive/f1
	name = "f1 grenade"
	icon_state = "rgd5"
	explosion_size = 3
	num_fragments = 75

/obj/item/weapon/grenade/explosive/type91
	name = "Type 91 grenade"
	icon_state = "type91"
	explosion_size = 4
	num_fragments = 37

/obj/item/weapon/grenade/explosive/type97
	name = "Type 97 grenade"
	icon_state = "type97"
	explosion_size = 3
	num_fragments = 75

/obj/item/weapon/grenade/explosive/mk2
	name = "MKII grenade"
	icon_state = "mk2"
	explosion_size = 3
	num_fragments = 75


/obj/item/weapon/grenade/explosive/l2a2
	name = "l2a2 grenade"
	icon_state = "l2a2"
	explosion_size = 3
	num_fragments = 75

/obj/item/weapon/grenade/smokebomb
	slot_flags = SLOT_BELT|SLOT_MASK

/obj/item/weapon/grenade/smokebomb/german
	desc = "German smoke grenade. Won't blow up."
	name = "German Smoke grenade"
	icon = 'icons/obj/grenade.dmi'
	icon_state = "smoke_grenade"
	det_time = 20

/obj/item/weapon/grenade/smokebomb/pirates
	desc = "Soviet smoke grenade. Won't blow up."
	name = "Soviet Smoke grenade"
	icon = 'icons/obj/grenade.dmi'
	icon_state = "smoke_grenade"
	det_time = 20

/obj/item/weapon/grenade/smokebomb/usa
	desc = "American smoke grenade. Won't blow up."
	name = "M18 smoke grenade"
	icon = 'icons/obj/grenade.dmi'
	icon_state = "m18smoke"
	det_time = 20

/obj/item/weapon/grenade/smokebomb/japan
	desc = "Japanese smoke grenade. Won't blow up."
	name = "Japanese smoke grenade"
	icon = 'icons/obj/grenade.dmi'
	icon_state = "japsmoke"
	det_time = 20


/obj/item/weapon/storage/box/smoke_grenades
	name = "box of smoke grenades"
	icon_state = "flashbang"

/obj/item/weapon/storage/box/smoke_grenades/New()
	..()
	for (var/i = 0; i < 7; i++)
		new /obj/item/ammo_casing/grenade/smoke(src)