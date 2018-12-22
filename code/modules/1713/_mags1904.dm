/***********************************
RUSSO-JAPANESE WAR WEAPONS MAGS N AMMO
***********************************/

/obj/item/ammo_magazine/projectile/mosin
	name = "Clip (7.62x54mm)"
	icon_state = "clip"
	caliber = "a762x54"
	matter = list(DEFAULT_WALL_MATERIAL = 360)
	ammo_type = /obj/item/projectile/bullet/rifle/a762x54
	max_ammo = 5
	weight = 0.04
	multiple_sprites = FALSE

/obj/item/ammo_magazine/projectile/mosinbox
	name = "magazine box (7.62x54mm)"
	icon_state = "mosin_ammo"
//	origin_tech = "combat=2"
	mag_type = MAGAZINE
	caliber = "a762x54"
	w_class = 3
	matter = list(DEFAULT_WALL_MATERIAL = 4500)
	ammo_type = /obj/item/ammo_casing/projectile/a762x54
	max_ammo = 50
	multiple_sprites = FALSE
	is_box = TRUE

/obj/item/ammo_magazine/projectile/arisaka
	name = "Clip (6.5x50mm)"
	icon_state = "kclip"
	caliber = "a65x50mm"
	matter = list(DEFAULT_WALL_MATERIAL = 360)
	ammo_type = /obj/item/ammo_casing/projectile/a65x50mm
	max_ammo = 5
	weight = 0.038
	multiple_sprites = FALSE

/obj/item/ammo_magazine/projectile/arisakabox
	name = "magazine box (6.5x50mm)"
	icon_state = "arisaka_ammo"
	mag_type = MAGAZINE
//	origin_tech = "combat=2"
	caliber = "a65x50mm"
	w_class = 3
	matter = list(DEFAULT_WALL_MATERIAL = 360)
	ammo_type = /obj/item/ammo_casing/projectile/a65x50mm
	max_ammo = 50
	multiple_sprites = FALSE
	is_box = TRUE


/obj/item/ammo_magazine/projectile/maxim
	name = "Maxim ammo belt"
	icon_state = "maximbelt"
//	origin_tech = "combat=2"
	mag_type = MAGAZINE
	caliber = "a762x54"
	w_class = 4
	matter = list(DEFAULT_WALL_MATERIAL = 4500)
	ammo_type = /obj/item/projectile/bullet/mg/a127x108
	max_ammo = 250
	multiple_sprites = TRUE
	var/slot = "decor"
	var/obj/item/clothing/under/has_suit = null		//the suit the tie may be attached to
	var/image/inv_overlay = null	//overlay used when attached to clothing.
	var/image/mob_overlay = null
	var/overlay_state = null

/obj/item/ammo_magazine/projectile/maxim/type92_belt
	name = "Type 92 Ammo Belt"
	caliber = "a77x58"
	ammo_type = /obj/item/projectile/bullet/rifle/a762x38

/obj/item/ammo_magazine/projectile/c8mmnambu
	name = "Nambu magazine"
	icon_state = "lugermag"
//	origin_tech = "combat=2"
	mag_type = MAGAZINE
	matter = list(DEFAULT_WALL_MATERIAL = 600)
	caliber = "c8mmnambu"
	ammo_type = /obj/item/projectile/bullet/pistol/c8mmnambu
	max_ammo = 8
	weight = 0.0143
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
/obj/item/ammo_magazine/projectile/c762x38mmR
	name = "pouch of bullets (7.62x38mmR)"
	icon_state = "7.62x38mmRPouch"
	ammo_type = /obj/item/ammo_casing/projectile/a762x38
	caliber = "7.62x38mmR"
	max_ammo = 21
	weight = 0.4
	multiple_sprites = TRUE

/obj/item/ammo_magazine/projectile/c9mm_jap_revolver
	name = "pouch of bullets (9mm)"
	icon_state = "7.62x38mmRPouch"
	ammo_type = /obj/item/projectile/bullet/pistol/c9mm_jap_revolver
	caliber = "9mm"
	max_ammo = 21
	weight = 0.4
	multiple_sprites = TRUE

