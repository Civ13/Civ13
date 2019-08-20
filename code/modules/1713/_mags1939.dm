/obj/item/ammo_magazine/arisaka99
	name = "clip (7.7x58mm)"
	icon_state = "kclip"
	caliber = "a77x58"
	matter = list(DEFAULT_WALL_MATERIAL = 360)
	ammo_type = /obj/item/ammo_casing/a77x58
	max_ammo = 5
	weight = 0.038
	multiple_sprites = TRUE
	clip = TRUE

/obj/item/ammo_magazine/arisakabox99
	name = "magazine box (7.7x58mm)"
	icon_state = "arisaka_ammo"
	mag_type = MAGAZINE
	caliber = "a77x58"
	w_class = 3
	matter = list(DEFAULT_WALL_MATERIAL = 4500)
	ammo_type = /obj/item/ammo_casing/a77x58
	max_ammo = 50
	multiple_sprites = FALSE
	is_box = TRUE

obj/item/ammo_magazine/type100
	name = "Type-100 magazine"
	icon_state = "madsen"
	mag_type = MAGAZINE
	caliber = "c8mmnambu"
	ammo_type = /obj/item/ammo_casing/c8mmnambu
	max_ammo = 30
	weight = 0.38
	multiple_sprites = TRUE

obj/item/ammo_magazine/type99
	name = "Type-99 magazine"
	icon_state = "type99"
	mag_type = MAGAZINE
	caliber = "a77x58"
	ammo_type = /obj/item/ammo_casing/a77x58
	max_ammo = 32
	weight = 0.40
	multiple_sprites = TRUE

/obj/item/ammo_magazine/type92
	name = "Type 92 ammo belt"
	icon_state = "maximbelt"
	mag_type = MAGAZINE
	caliber = "a77x58_weak"
	w_class = 4
	matter = list(DEFAULT_WALL_MATERIAL = 4500)
	ammo_type = /obj/item/ammo_casing/a77x58/weak
	max_ammo = 250
	multiple_sprites = TRUE
	var/slot = "decor"
	var/obj/item/clothing/under/has_suit = null		//the suit the tie may be attached to
	var/image/inv_overlay = null	//overlay used when attached to clothing.
	var/image/mob_overlay = null
	var/overlay_state = null

/obj/item/ammo_magazine/mp40
	name = "MP40 magazine (9x19mm)"
	icon_state = "mp40"
	mag_type = MAGAZINE
	caliber = "a9x19"
	ammo_type = /obj/item/ammo_casing/a9x19
	max_ammo = 32
	weight = 0.34
	multiple_sprites = TRUE

/obj/item/ammo_magazine/mg34
	name = "MG34 magazine (7.92x57mm)"
	icon_state = "mg34"
	mag_type = MAGAZINE
	caliber = "a792x57_weak"
	ammo_type = /obj/item/ammo_casing/a792x57/weak
	max_ammo = 50
	weight = 0.34
	multiple_sprites = TRUE

/obj/item/ammo_magazine/greasegun
	name = "M3A1 magazine (.45 ACP)"
	icon_state = "greasegun"
	mag_type = MAGAZINE
	caliber = "a45acp"
	ammo_type = /obj/item/ammo_casing/a45acp
	max_ammo = 30
	weight = 0.4
	multiple_sprites = TRUE

/obj/item/ammo_magazine/c762x25_pps
	name = "PPS-43 magazine (7.62x25mm)"
	icon_state = "pps"
	mag_type = MAGAZINE
	caliber = "a762x25"
	ammo_type = /obj/item/ammo_casing/a762x25
	max_ammo = 35
	weight = 0.56
	multiple_sprites = TRUE

/obj/item/ammo_magazine/c762x25_ppsh
	name = "PPSh-41 drum magazine (7.62x25mm)"
	icon_state = "ppsh"
	mag_type = MAGAZINE
	caliber = "a762x25"
	ammo_type = /obj/item/ammo_casing/a762x25
	max_ammo = 71
	weight = 1.3
	multiple_sprites = TRUE

obj/item/ammo_magazine/dp
	name = "DP disk (7.62x54mmR)"
	icon_state = "dpdisk"
	mag_type = MAGAZINE
	caliber = "a762x54_weak"
	ammo_type = /obj/item/ammo_casing/a762x54/weak
	max_ammo = 60
	weight = 0.40
	multiple_sprites = FALSE

/obj/item/ammo_magazine/stg
	name = "StG 44 magazine (7.92x33mm)"
	icon_state = "stg"
	mag_type = MAGAZINE
	caliber = "a792x33"
	ammo_type = /obj/item/ammo_casing/a792x33
	max_ammo = 30
	weight = 0.32
	multiple_sprites = TRUE

/obj/item/ammo_magazine/g43
	name = "G43 magazine (7.92x57mm)"
	icon_state = "g43"
	caliber = "a792x57"
	mag_type = MAGAZINE
	matter = list(DEFAULT_WALL_MATERIAL = 360)
	ammo_type = /obj/item/ammo_casing/a792x57
	max_ammo = 10
	weight = 0.32
	multiple_sprites = TRUE

/obj/item/ammo_magazine/svt
	name = "SVT-40 magazine (7.62x54mm)"
	icon_state = "svt"
	caliber = "a762x54"
	mag_type = MAGAZINE
	matter = list(DEFAULT_WALL_MATERIAL = 360)
	ammo_type = /obj/item/ammo_casing/a762x54
	max_ammo = 10
	weight = 0.3
	multiple_sprites = TRUE

/obj/item/ammo_magazine/m1911
	name = "M1911 magazine (.45)"
	icon_state = "m1911"
	mag_type = MAGAZINE
	ammo_type = /obj/item/ammo_casing/a45acp
	matter = list(DEFAULT_WALL_MATERIAL = 525) //metal costs are very roughly based around TRUE .45 casing = 75 metal
	caliber = "a45acp"
	max_ammo = 7
	multiple_sprites = TRUE
/obj/item/ammo_magazine/m1911/empty/New()
	..()
	stored_ammo.Cut()

/obj/item/ammo_magazine/tt30
	name = "TT30 magazine (7.62x25mm)"
	icon_state = "m1911"
	mag_type = MAGAZINE
	ammo_type = /obj/item/ammo_casing/a765x25
	matter = list(DEFAULT_WALL_MATERIAL = 525) //metal costs are very roughly based around TRUE .45 casing = 75 metal
	caliber = "a765x25"
	max_ammo = 8
	multiple_sprites = TRUE
/obj/item/ammo_magazine/tt30/empty/New()
	..()
	stored_ammo.Cut()


/obj/item/ammo_magazine/garand
	name = "clip (30-06) 8 rounds"
	icon_state = "clip"
	caliber = "a3006"
	matter = list(DEFAULT_WALL_MATERIAL = 360)
	ammo_type = /obj/item/ammo_casing/a3006
	max_ammo = 8
	weight = 0.038
	multiple_sprites = TRUE
	clip = TRUE

/obj/item/ammo_magazine/springfield
	name = "clip (30-06)"
	icon_state = "clip"
	caliber = "a3006"
	matter = list(DEFAULT_WALL_MATERIAL = 360)
	ammo_type = /obj/item/ammo_casing/a3006
	max_ammo = 5
	weight = 0.038
	multiple_sprites = TRUE
	clip = TRUE

/obj/item/ammo_magazine/bar
	name = "magazine (30-06)"
	icon_state = "bar"
	caliber = "a3006_weak"
	matter = list(DEFAULT_WALL_MATERIAL = 360)
	ammo_type = /obj/item/ammo_casing/a3006/weak
	max_ammo = 20
	weight = 0.038
	mag_type = MAGAZINE
	multiple_sprites = TRUE

/obj/item/ammo_magazine/thompson
	name = "Thomspon magazine (.45)"
	icon_state = "thompson"
	mag_type = MAGAZINE
	ammo_type = /obj/item/ammo_casing/a45acp
	matter = list(DEFAULT_WALL_MATERIAL = 525) //metal costs are very roughly based around TRUE .45 casing = 75 metal
	caliber = "a45acp"
	max_ammo = 20
	multiple_sprites = TRUE