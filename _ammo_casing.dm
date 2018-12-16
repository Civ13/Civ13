/***********************************
RJW Ammo
***********************************/
/obj/item/ammo_magazine/projectile/arisakabox
	name = "arisaka ammo"
	icon_state = "arisaka_ammo"
//	origin_tech = "combat=2"
	mag_type = MAGAZINE
	caliber = "65x50mm"
	w_class = 2
	matter = list(DEFAULT_WALL_MATERIAL = 4500)
	ammo_type = /obj/item/ammo_casing/projectile/a65x50mm
	max_ammo = 50
	multiple_sprites = TRUE
	is_box = TRUE

/obj/item/ammo_casing/projectile/a762x54
	desc = "A 7.62x54mm bullet casing."
	caliber = "a762x54"
	icon_state = "clip-bullet"
	spent_icon = "clip-casing"
	weight = 0.012
	projectile_type = /obj/item/projectile/bullet/rifle/a762x54

/obj/item/ammo_casing/projectile/a65x50mm
	desc = "A 65x50mm bullet casing."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	caliber = "a65x50mm"
	weight = 0.0127
	projectile_type = /obj/item/projectile/bullet/rifle/a65x50mm

/obj/item/ammo_casing/projectile/a762x38
	desc = "A 7.62x38mmR bullet casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistol_bullet_casing"
	caliber = "a762x38"
	weight = 0.0056
	projectile_type = /obj/item/projectile/bullet/rifle/a762x38



/obj/item/ammo_casing/projectile/c9mm_jap_revolver
	desc = "A 9mm revolver bullet casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistol_bullet_casing"
	caliber = "c9mm_jap_revolver"
	weight = 0.0095
	projectile_type = /obj/item/projectile/bullet/pistol/c9mm_jap_revolver

/************************
		OTHER
************************/

/obj/item/ammo_casing/projectile/a65x50mm
	name = "a 65x50mm bullet casing"
	projectile_type = /obj/item/projectile/bullet/rifle/a65x50mm
	weight = 0.0136
	caliber = "a65x50mm"

/obj/item/ammo_casing/projectile/a762x54
	name = "a 7.62x54 bullet casing"
	projectile_type = /obj/item/projectile/bullet/rifle/a762x54
	caliber = "a762x54"

/obj/item/ammo_casing/projectile/a127x108
	name = "a 1.27x108 bullet casing"
	projectile_type = /obj/item/projectile/bullet/mg/a127x108
	caliber = "a127x108"