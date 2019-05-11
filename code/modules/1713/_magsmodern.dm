/obj/item/ammo_magazine/ak47
	name = "AK-47 magazine (7.62x39mm)"
	icon_state = "ak47"
	mag_type = MAGAZINE
	caliber = "a762x39"
	ammo_type = /obj/item/ammo_casing/a762x39
	max_ammo = 30
	weight = 0.7
	multiple_sprites = TRUE
/obj/item/ammo_magazine/ak74
	name = "AK-74 magazine (5.45x39mm)"
	icon_state = "ak74"
	mag_type = MAGAZINE
	caliber = "a545x39"
	ammo_type = /obj/item/ammo_casing/a545x39
	max_ammo = 30
	weight = 0.5
	multiple_sprites = TRUE

/obj/item/ammo_magazine/m16
	name = "M16 magazine (5.56x45mm)"
	icon_state = "m16"
	mag_type = MAGAZINE
	caliber = "a556x45"
	ammo_type = /obj/item/ammo_casing/a556x45
	max_ammo = 30
	weight = 0.5
	multiple_sprites = TRUE

/obj/item/ammo_magazine/m14
	name = "M14 magazine (7.62x51mm)"
	icon_state = "m14"
	mag_type = MAGAZINE
	caliber = "a762x51"
	ammo_type = /obj/item/ammo_casing/a762x51
	max_ammo = 20
	weight = 0.45
	multiple_sprites = TRUE

/obj/item/ammo_magazine/pkm
	name = "PKM ammo belt"
	icon_state = "maximbelt"
	mag_type = MAGAZINE
	caliber = "a762x54_weak"
	w_class = 4
	matter = list(DEFAULT_WALL_MATERIAL = 4500)
	ammo_type = /obj/item/ammo_casing/a762x54/weak
	max_ammo = 250
	multiple_sprites = TRUE
	var/slot = "decor"
	var/obj/item/clothing/under/has_suit = null		//the suit the tie may be attached to
	var/image/inv_overlay = null	//overlay used when attached to clothing.
	var/image/mob_overlay = null
	var/overlay_state = null