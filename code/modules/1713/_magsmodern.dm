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
	name = "STANAG magazine (5.56x45mm)"
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

/obj/item/ammo_magazine/hk
	name = "H&K magazine (7.62x51mm)"
	icon_state = "hk"
	mag_type = MAGAZINE
	caliber = "a762x51"
	ammo_type = /obj/item/ammo_casing/a762x51
	max_ammo = 20
	weight = 0.45
	multiple_sprites = TRUE

/obj/item/ammo_magazine/scarh
	name = "SCAR-H magazine (7.62x51mm)"
	icon_state = "scarh"
	mag_type = MAGAZINE
	caliber = "a762x51"
	ammo_type = /obj/item/ammo_casing/a762x51
	max_ammo = 30
	weight = 0.75
	multiple_sprites = TRUE

/obj/item/ammo_magazine/pkm
	name = "PKM ammo belt (7.62x54mmR)"
	icon_state = "maximbelt"
	mag_type = MAGAZINE
	caliber = "a762x54_weak"
	w_class = 4
	matter = list(DEFAULT_WALL_MATERIAL = 4500)
	ammo_type = /obj/item/ammo_casing/a762x54/weak
	max_ammo = 250
	multiple_sprites = TRUE
	belt = TRUE


/obj/item/ammo_magazine/pkm/c100
	name = "PKM ammo belt (7.62x54mmR)"
	icon_state = "b762x54"
	mag_type = MAGAZINE
	caliber = "a762x54_weak"
	w_class = 3
	matter = list(DEFAULT_WALL_MATERIAL = 4500)
	ammo_type = /obj/item/ammo_casing/a762x54/weak
	max_ammo = 100
	multiple_sprites = TRUE

/obj/item/ammo_magazine/m9beretta
	name = "M9 Beretta magazine (9x19mm)"
	icon_state = "m9beretta"
	mag_type = MAGAZINE
	caliber = "a9x19"
	ammo_type = /obj/item/ammo_casing/a9x19
	max_ammo = 15
	weight = 0.33
	multiple_sprites = TRUE


/obj/item/ammo_magazine/jericho
	name = "Jericho 941 magazine (9x19mm)"
	icon_state = "m9beretta"
	mag_type = MAGAZINE
	caliber = "a9x19"
	ammo_type = /obj/item/ammo_casing/a9x19
	max_ammo = 16
	weight = 0.35
	multiple_sprites = TRUE

/obj/item/ammo_magazine/negev
	name = "Negev belt (5.56x45mm)"
	icon_state = "b762"
	mag_type = MAGAZINE
	caliber = "a556x45"
	w_class = 3
	matter = list(DEFAULT_WALL_MATERIAL = 1440)
	ammo_type = /obj/item/ammo_casing/a556x45
	max_ammo = 150
	multiple_sprites = TRUE

/obj/item/ammo_magazine/m24
	name = "clip (7.62x51mm)"
	icon_state = "clip"
	matter = list(DEFAULT_WALL_MATERIAL = 360)
	ammo_type = /obj/item/ammo_casing/a762x51
	caliber = "a762x51"
	max_ammo = 5
	weight = 0.045
	multiple_sprites = TRUE
	clip = TRUE