/obj/item/ammo_magazine/arisaka99
	name = "clip (7.7x58mm)"
	icon_state = "kclip"
	caliber = "a77x58"

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

	ammo_type = /obj/item/ammo_casing/a77x58
	max_ammo = 50
	multiple_sprites = FALSE
	is_box = TRUE

/obj/item/ammo_magazine/arisaka99_training
	name = "clip (7.7x58mm)"
	icon_state = "kclip"
	caliber = "a77x58_wood"

	ammo_type = /obj/item/ammo_casing/a77x58_wood
	max_ammo = 5
	weight = 0.038
	multiple_sprites = TRUE
	clip = TRUE

/obj/item/ammo_magazine/type100
	name = "Type 100 Magazine"
	icon_state = "type100"
	mag_type = MAGAZINE
	caliber = "c8mmnambu"
	ammo_type = /obj/item/ammo_casing/c8mmnambu
	max_ammo = 30
	weight = 0.38
	multiple_sprites = TRUE

/obj/item/ammo_magazine/type99
	name = "Type-99 Magazine"
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
	caliber = "a77x58"
	w_class = 4

	ammo_type = /obj/item/ammo_casing/a77x58
	max_ammo = 30
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

/obj/item/ammo_magazine/mp40/mp5
	name = "MP5 magazine (9x19mm)"
	icon_state = "mp5"

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
	max_ammo = 65
	weight = 1.3
	multiple_sprites = TRUE

obj/item/ammo_magazine/dp
	name = "DP pan (7.62x54mmR)"
	icon_state = "dpdisk"
	mag_type = MAGAZINE
	caliber = "a762x54_weak"
	ammo_type = /obj/item/ammo_casing/a762x54/weak
	max_ammo = 47
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

	ammo_type = /obj/item/ammo_casing/a792x57
	max_ammo = 10
	weight = 0.32
	multiple_sprites = TRUE

/obj/item/ammo_magazine/svd
	name = "SVD magazine (7.62x54mmR)"
	icon_state = "g43"
	caliber = "a762x54"
	mag_type = MAGAZINE

	ammo_type = /obj/item/ammo_casing/a762x54
	max_ammo = 10
	weight = 0.32
	multiple_sprites = TRUE

/obj/item/ammo_magazine/avtomat
	name = "avtomat magazine (6.5x50mm)"
	icon_state = "g43"
	caliber = "a65x50"
	mag_type = MAGAZINE

	ammo_type = /obj/item/ammo_casing/a65x50
	max_ammo = 25
	weight = 0.44
	multiple_sprites = TRUE

/obj/item/ammo_magazine/svt
	name = "SVT-40 magazine (7.62x54mm)"
	icon_state = "svt"
	caliber = "a762x54"
	mag_type = MAGAZINE

	ammo_type = /obj/item/ammo_casing/a762x54
	max_ammo = 10
	weight = 0.3
	multiple_sprites = TRUE

/obj/item/ammo_magazine/m1911
	name = "M1911 magazine (.45)"
	icon_state = "m1911"
	mag_type = MAGAZINE
	ammo_type = /obj/item/ammo_casing/a45acp
	caliber = "a45acp"
	max_ammo = 7
	multiple_sprites = TRUE
/obj/item/ammo_magazine/m1911/empty/New()
	..()
	stored_ammo.Cut()

/obj/item/ammo_magazine/a45acpbox
	name = "magazine box (.45)"
	icon_state = "oldbox"
	mag_type = MAGAZINE
	ammo_type = /obj/item/ammo_casing/a45acp
	caliber = "a45acp"
	w_class = 3
	max_ammo = 30
	multiple_sprites = FALSE
	is_box = TRUE

/obj/item/ammo_magazine/tt30
	name = "TT-33 magazine (7.62x25mm)"
	icon_state = "m1911"
	mag_type = MAGAZINE
	ammo_type = /obj/item/ammo_casing/a762x25
	caliber = "a762x25"
	max_ammo = 8
	multiple_sprites = TRUE
/obj/item/ammo_magazine/tt30/empty/New()
	..()
	stored_ammo.Cut()

/obj/item/ammo_magazine/tt30ll
	name = "TT-33 magazine (rubber)"
	icon_state = "m1911"
	mag_type = MAGAZINE
	ammo_type =  /obj/item/ammo_casing/l762x25
	caliber = "l762x25"
	max_ammo = 8
	multiple_sprites = TRUE
/obj/item/ammo_magazine/tt30/empty/New()
	..()
	stored_ammo.Cut()

/obj/item/ammo_magazine/makarov
	name = "PM Makarov magazine (9x18mm)"
	icon_state = "m1911"
	mag_type = MAGAZINE
	ammo_type = /obj/item/ammo_casing/a9x18
	caliber = "a9x18"
	max_ammo = 8
	multiple_sprites = TRUE
/obj/item/ammo_magazine/makarov/empty/New()
	..()
	stored_ammo.Cut()


/obj/item/ammo_magazine/garand
	name = "clip (30-06) 8 rounds"
	icon_state = "g-clip"
	caliber = "a3006"

	ammo_type = /obj/item/ammo_casing/a3006
	max_ammo = 8
	weight = 0.038
	multiple_sprites = TRUE
	clip = TRUE

/obj/item/ammo_magazine/m3006box
	name = "magazine box (30-06)"
	icon_state = "ammo"
	mag_type = MAGAZINE
	caliber = "a3006"
	w_class = 3
	ammo_type = /obj/item/ammo_casing/a3006
	max_ammo = 50
	multiple_sprites = FALSE
	is_box = TRUE

/obj/item/ammo_magazine/springfield
	name = "clip (30-06)"
	icon_state = "clip"
	caliber = "a3006"

	ammo_type = /obj/item/ammo_casing/a3006
	max_ammo = 5
	weight = 0.038
	multiple_sprites = TRUE
	clip = TRUE

/obj/item/ammo_magazine/browning
	name = "browning ammo belt"
	icon_state = "maximbelt"
	mag_type = MAGAZINE
	caliber = "a3006"
	w_class = 4

	ammo_type = /obj/item/ammo_casing/a3006
	max_ammo = 250
	multiple_sprites = TRUE
	var/slot = "decor"
	var/obj/item/clothing/under/has_suit = null		//the suit the tie may be attached to
	var/image/inv_overlay = null	//overlay used when attached to clothing.
	var/image/mob_overlay = null
	var/overlay_state = null

/obj/item/ammo_magazine/bar
	name = "BAR magazine (30-06)"
	icon_state = "bar"
	caliber = "a3006_weak"

	ammo_type = /obj/item/ammo_casing/a3006/weak
	max_ammo = 20
	weight = 0.038
	mag_type = MAGAZINE
	multiple_sprites = TRUE

/obj/item/ammo_magazine/thompson
	name = "Thompson magazine (.45)"
	icon_state = "thompson"
	caliber = "a45acp"
	mag_type = MAGAZINE
	ammo_type = /obj/item/ammo_casing/a45acp
	max_ammo = 20
	multiple_sprites = TRUE