/***********************************
RUSSO-JAPANESE WAR WEAPONS MAGS N AMMO
***********************************/
/obj/item/ammo_magazine/mosin
	name = "clip (7.62x54mm)"
	icon_state = "clip"
	caliber = "a762x54"
	ammo_type = /obj/item/ammo_casing/a762x54
	max_ammo = 5
	weight = 0.04
	multiple_sprites = TRUE
	clip = TRUE

/obj/item/ammo_magazine/mosinbox
	name = "magazine box (7.62x54mm)"
	icon_state = "mosin_ammo"
	mag_type = MAGAZINE
	caliber = "a762x54"
	w_class = ITEM_SIZE_NORMAL
	ammo_type = /obj/item/ammo_casing/a762x54
	max_ammo = 50
	multiple_sprites = FALSE
	is_box = TRUE

/obj/item/ammo_magazine/madsen
	name = "magazine (7.62x54mm)"
	icon_state = "madsen"
	mag_type = MAGAZINE
	caliber = "a762x54"
	w_class = ITEM_SIZE_SMALL //most 30 round and 46 round mags have no wclass why give just madsen a wclass you cant fit it into a pouch anymore no reason anyways making it 2
	ammo_type = /obj/item/ammo_casing/a762x54
	max_ammo = 25
	multiple_sprites = TRUE

/obj/item/ammo_magazine/madsen/box
	name = "magazine box (7.62x54mm)"
	icon_state = "mhbox"
	mag_type = MAGAZINE
	caliber = "a762x54"
	w_class = ITEM_SIZE_NORMAL
	ammo_type = /obj/item/ammo_casing/a762x54
	max_ammo = 65
	multiple_sprites = TRUE
	is_box = TRUE
/obj/item/ammo_magazine/b762
	name = "belt (7.62x51mm)"
	icon_state = "b762"
	mag_type = MAGAZINE
	caliber = "a762x51_weak"
	w_class = ITEM_SIZE_NORMAL
	ammo_type = /obj/item/ammo_casing/a762x51/weak
	max_ammo = 100
	multiple_sprites = TRUE

/obj/item/ammo_magazine/m249
	name = "belt (5.56x45mm)"
	icon_state = "b762"
	mag_type = MAGAZINE
	caliber = "a556x45"
	w_class = ITEM_SIZE_NORMAL
	ammo_type = /obj/item/ammo_casing/a556x45
	max_ammo = 100
	multiple_sprites = TRUE

/obj/item/ammo_magazine/gewehr71
	name = "clip (7.65x53mm)"
	icon_state = "kclip"
	caliber = "a765x53"
	ammo_type = /obj/item/ammo_casing/a765x53
	max_ammo = 5
	weight = 0.04
	multiple_sprites = TRUE
	clip = TRUE


/obj/item/ammo_magazine/gewehr71box
	name = "magazine box (7.65x53mm)"
	icon_state = "ammo"
	mag_type = MAGAZINE
	caliber = "a765x53"
	w_class = ITEM_SIZE_NORMAL
	ammo_type = /obj/item/ammo_casing/a765x53
	max_ammo = 50
	multiple_sprites = FALSE
	is_box = TRUE

/obj/item/ammo_magazine/gewehr98
	name = "clip (7.92x57mm)"
	icon_state = "kclip"
	caliber = "a792x57"
	ammo_type = /obj/item/ammo_casing/a792x57
	max_ammo = 5
	weight = 0.04
	multiple_sprites = TRUE
	clip = TRUE

/obj/item/ammo_magazine/vgclip
	name = "clip (7.92x33mm)"
	icon_state = "kclip"
	caliber = "a792x33"
	ammo_type = /obj/item/ammo_casing/a792x33
	max_ammo = 5
	weight = 0.06
	multiple_sprites = TRUE
	clip = TRUE

/obj/item/ammo_magazine/mauser1893
	name = "clip (7x53mm)"
	icon_state = "kclip"
	caliber = "a7x57"
	ammo_type = /obj/item/ammo_casing/a7x57
	max_ammo = 5
	weight = 0.038
	multiple_sprites = TRUE
	clip = TRUE

/obj/item/ammo_magazine/gewehr98box
	name = "magazine box (7.92x57mm)"
	icon_state = "ammo"
	mag_type = MAGAZINE
	caliber = "a792x57"
	w_class = ITEM_SIZE_NORMAL
	ammo_type = /obj/item/ammo_casing/a792x57
	max_ammo = 50
	multiple_sprites = FALSE
	is_box = TRUE


/obj/item/ammo_magazine/mauser1893box
	name = "magazine box (7x53mm)"
	icon_state = "ammo"
	mag_type = MAGAZINE
	caliber = "a7x57"
	w_class = ITEM_SIZE_NORMAL
	ammo_type = /obj/item/ammo_casing/a7x57
	max_ammo = 50
	multiple_sprites = FALSE
	is_box = TRUE

/obj/item/ammo_magazine/sharps
	name = "ammo box (.45-70 Government)"
	icon_state = "oldbox"
	caliber = "a4570"
	w_class = ITEM_SIZE_SMALL

	ammo_type = /obj/item/ammo_casing/a4570
	max_ammo = 15
	multiple_sprites = FALSE
	is_box = TRUE

/obj/item/ammo_magazine/c577
	name = "ammo box (.577/450 Martini-Henry)"
	icon_state = "mhbox"
	caliber = "a577"
	w_class = ITEM_SIZE_NORMAL

	ammo_type = /obj/item/ammo_casing/a577
	max_ammo = 12
	multiple_sprites = FALSE
	is_box = TRUE

/obj/item/ammo_magazine/arisaka
	name = "clip (6.5x50mm)"
	icon_state = "kclip"
	caliber = "a65x50"

	ammo_type = /obj/item/ammo_casing/a65x50
	max_ammo = 5
	weight = 0.038
	multiple_sprites = TRUE
	clip = TRUE

/obj/item/ammo_magazine/arisakabox
	name = "magazine box (6.5x50mm)"
	icon_state = "arisaka_ammo"
	mag_type = MAGAZINE
	caliber = "a65x50"
	w_class = ITEM_SIZE_NORMAL

	ammo_type = /obj/item/ammo_casing/a65x50
	max_ammo = 50
	multiple_sprites = FALSE
	is_box = TRUE

/obj/item/ammo_magazine/carcano
	name = "clip (6.5x52mm)"
	icon_state = "kclip"
	caliber = "a65x52"

	ammo_type = /obj/item/ammo_casing/a65x52
	max_ammo = 5
	weight = 0.038
	multiple_sprites = TRUE
	clip = TRUE

/obj/item/ammo_magazine/carcano_box
	name = "magazine box (6.5x52mm)"
	icon_state = "ammo"
	mag_type = MAGAZINE
	caliber = "a65x52"
	w_class = ITEM_SIZE_NORMAL

	ammo_type = /obj/item/ammo_casing/a65x52
	max_ammo = 50
	multiple_sprites = FALSE
	is_box = TRUE

/obj/item/ammo_magazine/maxim
	name = "Maxim ammo belt"
	icon_state = "maximbelt"
	worn_state = "maximbelt"
	mag_type = MAGAZINE
	caliber = "a762x54_weak"
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BACK|SLOT_BELT|SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a762x54/weak
	max_ammo = 250
	multiple_sprites = TRUE
	belt = TRUE

/obj/item/ammo_magazine/mg08
	name = "MG08 ammo belt"
	icon_state = "maximbelt"
	mag_type = MAGAZINE
	caliber = "a792x57_weak"
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BACK|SLOT_BELT|SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a792x57/weak
	max_ammo = 250
	multiple_sprites = TRUE
	belt = TRUE

/obj/item/ammo_magazine/vickers
	name = "Vickers ammo belt"
	icon_state = "maximbelt"
	mag_type = MAGAZINE
	caliber = "a303_weak"
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BACK|SLOT_BELT|SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a303/weak
	max_ammo = 250
	multiple_sprites = TRUE
	belt = TRUE

/obj/item/ammo_magazine/vickers/box
	name = "magazine box (.303 British)"
	icon_state = "wood_ammobox"
	mag_type = MAGAZINE
	caliber = "a303_weak"
	w_class = ITEM_SIZE_HUGE
	ammo_type = /obj/item/ammo_casing/a303/weak
	max_ammo = 650
	multiple_sprites = TRUE
	is_box = TRUE
	slowdown = 2.0

/obj/item/ammo_magazine/hotchkiss
	name = "Hotchkiss ammo belt"
	icon_state = "maximbelt"
	mag_type = MAGAZINE
	caliber = "a8x50_weak"
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BACK|SLOT_BELT|SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a8x50/weak
	max_ammo = 250
	multiple_sprites = TRUE
	belt = TRUE


/obj/item/ammo_magazine/type3
	name = "Type 3 ammo belt"
	icon_state = "maximbelt"
	mag_type = MAGAZINE
	caliber = "a65x50_weak"
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BACK|SLOT_BELT|SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a65x50/weak
	max_ammo = 250
	multiple_sprites = TRUE
	belt = TRUE

/obj/item/ammo_magazine/mg34belt
	name = "MG 34 ammo belt"
	icon_state = "maximbelt"
	mag_type = MAGAZINE
	caliber = "a792x57_weak"
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BACK|SLOT_BELT|SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a792x57/weak
	max_ammo = 250
	multiple_sprites = TRUE
	belt = TRUE

/obj/item/ammo_magazine/mg3belt
	name = "belt (7.62x51mm)"
	icon_state = "maximbelt"
	mag_type = MAGAZINE
	caliber = "a762x51_weak"
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BACK|SLOT_BELT|SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a762x51/weak
	max_ammo = 100
	multiple_sprites = TRUE

/obj/item/ammo_magazine/c8mmnambu
	name = "Nambu magazine"
	icon_state = "lugermag"
	mag_type = MAGAZINE
	caliber = "c8mmnambu"
	ammo_type = /obj/item/ammo_casing/c8mmnambu
	max_ammo = 8
	weight = 0.02
	multiple_sprites = TRUE

/obj/item/ammo_magazine/luger
	name = "Luger magazine"
	icon_state = "lugermag"
	mag_type = MAGAZINE
	caliber = "a9x19"
	ammo_type = /obj/item/ammo_casing/a9x19
	max_ammo = 8
	weight = 0.02
	multiple_sprites = TRUE

/obj/item/ammo_magazine/walther
	name = "Walther magazine"
	icon_state = "waltherp"
	mag_type = MAGAZINE
	caliber = "a9x19"
	ammo_type = /obj/item/ammo_casing/a9x19
	max_ammo = 8
	weight = 0.02
	multiple_sprites = TRUE
/obj/item/ammo_magazine/walther/empty/New()
	..()
	stored_ammo.Cut()

/obj/item/ammo_magazine/borchardt
	name = "Borchardt magazine"
	icon_state = "borchardtmag"
	mag_type = MAGAZINE
	caliber = "a765x25"
	ammo_type = /obj/item/ammo_casing/a765x25
	max_ammo = 8
	weight = 0.02
	multiple_sprites = TRUE

/obj/item/ammo_magazine/luger/empty/New()
	..()
	stored_ammo.Cut()
/obj/item/ammo_magazine/c8mmnambu/empty/New()
	..()
	stored_ammo.Cut()
/obj/item/ammo_magazine/borchardt/empty/New()
	..()
	stored_ammo.Cut()

/obj/item/ammo_magazine/mauser
	name = "Mauser clip (7.63mm)"
	icon_state = "mauser"
	caliber = "a762x25"

	ammo_type = /obj/item/ammo_casing/a762x25
	max_ammo = 10
	weight = 0.06
	multiple_sprites = TRUE
	mag_type = SPEEDLOADER
	clip = TRUE


////////// NAGANT REVOLVER ///////////////
/obj/item/ammo_magazine/c762x38mmR
	name = "bullet pouch (7.62x38mmR)"
	icon_state = "pouch"
	ammo_type = /obj/item/ammo_casing/a762x38
	caliber = "a762x38"
	max_ammo = 21
	weight = 0.4
	multiple_sprites = TRUE

	pouch = TRUE

/obj/item/ammo_magazine/c8x27
	name = "bullet pouch (8x27mmR)"
	icon_state = "pouch"
	ammo_type = /obj/item/ammo_casing/a8x27
	caliber = "a8x27"
	max_ammo = 24
	weight = 0.5
	multiple_sprites = TRUE

	pouch = TRUE

/obj/item/ammo_magazine/c9mm_jap_revolver
	name = "bullet pouch (9mm)"
	icon_state = "pouch"
	ammo_type = /obj/item/ammo_casing/c9mm_jap_revolver
	caliber = "c9mm_jap_revolver"
	max_ammo = 18
	weight = 0.70

	multiple_sprites = TRUE

	pouch = TRUE

/obj/item/ammo_magazine/c32
	name = "bullet pouch (.32 S&W Long)"
	desc = "a pouch of 26 .32 bullets."
	icon_state = "pouch"
	ammo_type = /obj/item/ammo_casing/a32
	caliber = "a32"
	max_ammo = 26
	weight = 0.9
	multiple_sprites = TRUE

	pouch = TRUE

/obj/item/ammo_magazine/c32acp
	name = "bullet pouch (.32 ACP)"
	desc = "a pouch of 26 .32 ACP bullets."
	icon_state = "pouch"
	ammo_type = /obj/item/ammo_casing/a32acp
	caliber = "a32"
	max_ammo = 26
	weight = 0.9
	multiple_sprites = TRUE

	pouch = TRUE

/obj/item/ammo_magazine/c9mm
	name = "bullet pouch (9x19mm)"
	desc = "a pouch of 30 9x19mm Parabellum bullets."
	icon_state = "pouch"
	ammo_type = /obj/item/ammo_casing/a9x19
	caliber = "a9x19"
	max_ammo = 30
	weight = 1.1
	multiple_sprites = TRUE

	pouch = TRUE

/obj/item/ammo_magazine/c38
	name = "bullet pouch (.38 long)"
	desc = "a pouch of 26 .38 bullets."
	icon_state = "pouch"
	ammo_type = /obj/item/ammo_casing/a38
	caliber = "a38"
	max_ammo = 26
	weight = 0.9
	multiple_sprites = TRUE

	pouch = TRUE

/obj/item/ammo_magazine/c45
	name = "bullet pouch (.45 Colt)"
	desc = "a pouch of 11.43xmmR bullets."
	icon_state = "pouch"
	ammo_type = /obj/item/ammo_casing/a45
	caliber = "a45"
	max_ammo = 24
	weight = 0.9
	multiple_sprites = TRUE

	pouch = TRUE

/obj/item/ammo_magazine/c455
	name = "bullet pouch (.455 Webley)"
	desc = "a pouch of .455 Webley bullets."
	icon_state = "pouch"
	ammo_type = /obj/item/ammo_casing/a455
	caliber = "awebly455"
	max_ammo = 24
	weight = 0.95
	multiple_sprites = TRUE

	pouch = TRUE

/obj/item/ammo_magazine/c41
	name = "bullet pouch (.41 Short)"
	desc = "a pouch of .41-100 bullets, mostly used on the Derringer."
	icon_state = "pouch"
	ammo_type = /obj/item/ammo_casing/a41
	caliber = "a41"
	max_ammo = 10
	weight = 0.1
	multiple_sprites = TRUE

	pouch = TRUE

/obj/item/ammo_magazine/c43
	name = "bullet pouch (.43 Spanish)"
	desc = "a pouch of .43 Spanish bullets, mostly used on the spanish rolling block rifle."
	icon_state = "pouch"
	ammo_type = /obj/item/ammo_casing/a43
	caliber = "a43"
	max_ammo = 30
	weight = 0.1
	multiple_sprites = TRUE
	pouch = TRUE

/obj/item/ammo_magazine/webly445
	name = "bullet pouch (.445 webly)"
	desc = "a pouch of .445 webly."
	icon_state = "pouch"
	ammo_type = /obj/item/ammo_casing/webly445
	caliber = "webly445"
	max_ammo = 10
	weight = 0.1
	multiple_sprites = TRUE

	pouch = TRUE

/obj/item/ammo_magazine/c44
	name = "bullet pouch (.44-40 Winchester)"
	desc = "a pouch of .44-40 bullets."
	icon_state = "pouch"
	ammo_type = /obj/item/ammo_casing/a44
	caliber = "a44"
	max_ammo = 30
	weight = 1.1
	multiple_sprites = TRUE

	pouch = TRUE

/obj/item/ammo_magazine/c44magnum
	name = "bullet pouch (.44 magnum)"
	desc = "a pouch of .44 magnum bullets."
	icon_state = "pouch"
	ammo_type = /obj/item/ammo_casing/a44magnum
	caliber = "a44magnum"
	max_ammo = 30
	weight = 1.1
	multiple_sprites = TRUE

	pouch = TRUE

/obj/item/ammo_magazine/c8x50
	name = "bullet pouch (8x50mmR Lebel)"
	desc = "a pouch of 8x50mmR Lebel bullets."
	icon_state = "pouch"
	ammo_type = /obj/item/ammo_casing/a8x50
	caliber = "a8x50"
	max_ammo = 24
	weight = 0.95
	multiple_sprites = TRUE

	pouch = TRUE

/obj/item/ammo_magazine/murata
	name = "clip (8x53mm)"
	icon_state = "kclip"
	caliber = "a8x53"

	ammo_type = /obj/item/ammo_casing/a8x53
	max_ammo = 5
	weight = 0.048
	multiple_sprites = TRUE
	clip = TRUE

/obj/item/ammo_magazine/murata_box
	name = "magazine box (8x53mm)"
	icon_state = "arisaka_ammo"
	mag_type = MAGAZINE
	caliber = "a8x53"
	w_class = ITEM_SIZE_NORMAL

	ammo_type = /obj/item/ammo_casing/a8x53
	max_ammo = 50
	multiple_sprites = FALSE
	is_box = TRUE

/obj/item/ammo_magazine/enfield
	name = "clip (.303)"
	icon_state = "clip"
	caliber = "a303"

	ammo_type = /obj/item/ammo_casing/a303
	max_ammo = 5
	weight = 0.048
	multiple_sprites = TRUE
	clip = TRUE

/obj/item/ammo_magazine/enfield_box
	name = "magazine box (.303)"
	icon_state = "ammo"
	mag_type = MAGAZINE
	caliber = "a303"
	w_class = ITEM_SIZE_NORMAL

	ammo_type = /obj/item/ammo_casing/a303
	max_ammo = 50
	multiple_sprites = FALSE
	is_box = TRUE
/obj/item/ammo_magazine/c8x50_3clip
	name = "clip (8x50mmR Lebel, 3u)"
	icon_state = "clip"

	ammo_type = /obj/item/ammo_casing/a8x50
	caliber = "a8x50"
	max_ammo = 3
	weight = 0.035
	multiple_sprites = TRUE
	clip = TRUE
/obj/item/ammo_magazine/c8x50_5clip
	name = "clip (8x50mmR Lebel, 5u)"
	icon_state = "clip"

	ammo_type = /obj/item/ammo_casing/a8x50
	caliber = "a8x50"
	max_ammo = 5
	weight = 0.048
	multiple_sprites = TRUE
	clip = TRUE
/obj/item/ammo_magazine/c44p
	name = "bullet pouch (.44)"
	icon_state = "pouch"
	ammo_type = /obj/item/ammo_casing/a44p
	caliber = "a44p"
	max_ammo = 18
	weight = 0.4
	multiple_sprites = TRUE

	desc = "A pouch containing 18 .44 pistol rounds."

/obj/item/ammo_magazine/shellbox
	name = "shotgun buckshot box (.12 gauge)"
	icon_state = "shellbox"
	mag_type = MAGAZINE
	caliber = "12gauge"
	w_class = ITEM_SIZE_SMALL

	ammo_type = /obj/item/ammo_casing/shotgun/buckshot
	max_ammo = 12
	multiple_sprites = TRUE
	is_box = TRUE

/obj/item/ammo_magazine/shellbox/slug
	name = "shotgun slugshot box (.12 gauge)"
	icon_state = "slugbox"
	ammo_type = /obj/item/ammo_casing/shotgun/slug

/obj/item/ammo_magazine/shellbox/beanbag
	name = "shotgun beanbag box (.12 gauge)"
	icon_state = "beanbagbox"
	ammo_type = /obj/item/ammo_casing/shotgun/beanbag

/obj/item/ammo_magazine/shellbox/rubber
	name = "shotgun rubber box (.12 gauge)"
	icon_state = "beanbagbox"
	ammo_type = /obj/item/ammo_casing/shotgun/rubber
