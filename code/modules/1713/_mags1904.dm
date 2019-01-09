/***********************************
RUSSO-JAPANESE WAR WEAPONS MAGS N AMMO
***********************************/

/obj/item/ammo_magazine/mosin
	name = "Clip (7.92x54mm)"
	icon_state = "clip"
	caliber = "a762x54"
	matter = list(DEFAULT_WALL_MATERIAL = 360)
	ammo_type = /obj/item/ammo_casing/a762x54
	max_ammo = 5
	weight = 0.04
	multiple_sprites = TRUE

/obj/item/ammo_magazine/mosinbox
	name = "magazine box (7.92x54mm)"
	icon_state = "mosin_ammo"
//	origin_tech = "combat=2"
	mag_type = MAGAZINE
	caliber = "a762x54"
	w_class = 3
	matter = list(DEFAULT_WALL_MATERIAL = 4500)
	ammo_type = /obj/item/ammo_casing/a762x54
	max_ammo = 50
	multiple_sprites = FALSE
	is_box = TRUE

/obj/item/ammo_magazine/arisaka
	name = "Clip (6.5x50mm)"
	icon_state = "kclip"
	caliber = "a65x50mm"
	matter = list(DEFAULT_WALL_MATERIAL = 360)
	ammo_type = /obj/item/ammo_casing/a65x50mm
	max_ammo = 5
	weight = 0.038
	multiple_sprites = TRUE

/obj/item/ammo_magazine/arisakabox
	name = "magazine box (6.5x50mm)"
	icon_state = "arisaka_ammo"
//	origin_tech = "combat=2"
	mag_type = MAGAZINE
	caliber = "a65x50mm"
	w_class = 3
	matter = list(DEFAULT_WALL_MATERIAL = 4500)
	ammo_type = /obj/item/ammo_casing/a65x50mm
	max_ammo = 50
	multiple_sprites = FALSE
	is_box = TRUE

/obj/item/ammo_magazine/maxim
	name = "Maxim ammo belt"
	icon_state = "maximbelt"
//	origin_tech = "combat=2"
	mag_type = MAGAZINE
	caliber = "a762x54"
	w_class = 4
	matter = list(DEFAULT_WALL_MATERIAL = 4500)
	ammo_type = /obj/item/ammo_casing/a762x38
	max_ammo = 250
	multiple_sprites = TRUE
	var/slot = "decor"
	var/obj/item/clothing/under/has_suit = null		//the suit the tie may be attached to
	var/image/inv_overlay = null	//overlay used when attached to clothing.
	var/image/mob_overlay = null
	var/overlay_state = null

/obj/item/ammo_magazine/c8mmnambu
	name = "Nambu magazine"
	icon_state = "lugermag"
//	origin_tech = "combat=2"
	mag_type = MAGAZINE
	caliber = "c8mmnambu"
	ammo_type = /obj/item/ammo_casing/c8mmnambu
	max_ammo = 8
	weight = 0.02
	multiple_sprites = TRUE

//obj/item/ammo_magazine/c9x19mm_stenmk3
	//name = "magazine (9x19mm)"
	//icon_state = "stenmag"
	//mag_type = MAGAZINE
	//ammo_type = /obj/item/ammo_casing/c9x19mm_stenmk3
	//caliber = "9x19mm"
	//max_ammo = 32
	//multiple_sprites = TRUE

////////// NAGANT REVOLVER ///////////////
/obj/item/ammo_magazine/c762x38mmR
	name = "pouch of bullets (7.62x38mmR)"
	icon_state = "7.62x38mmRPouch"
	ammo_type = /obj/item/ammo_casing/a762x38
	caliber = "7.62x38mmR"
	max_ammo = 21
	weight = 0.4
	multiple_sprites = TRUE
	mag_type = SPEEDLOADER

/obj/item/ammo_magazine/c9mm_jap_revolver
	name = "pouch of bullets (9mm)"
	icon_state = "pouch"
	ammo_type = /obj/item/ammo_casing/c9mm_jap_revolver
	caliber = "c9mm_jap_revolver"
	max_ammo = 21
	weight = 0.4
	multiple_sprites = TRUE
	mag_type = SPEEDLOADER

/obj/item/ammo_magazine/murata

/obj/item/ammo_magazine/murata
	name = "Clip (11x60mm)"
	icon_state = "kclip"
	caliber = "a11x60mm"
	matter = list(DEFAULT_WALL_MATERIAL = 360)
	ammo_type = /obj/item/ammo_casing/a11x60mm
	max_ammo = 5
	weight = 0.038
	multiple_sprites = TRUE