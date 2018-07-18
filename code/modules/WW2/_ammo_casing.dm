/***********************************
WW 2 WEAPONS MAGS N AMMO
***********************************/

/obj/item/ammo_casing/a145
	name = "shell casing"
	desc = "A 14.5mm shell."
	icon_state = "lcasing"
	spent_icon = "lcasing-spent"
	caliber = "14.5mm"
	projectile_type = /obj/item/projectile/bullet/rifle/a145
	matter = list(DEFAULT_WALL_MATERIAL = 1250)

/obj/item/ammo_magazine/ptrdbox
	name = "magazine box (PTRD ammo)"
	icon_state = "mosin_ammo"
//	origin_tech = "combat=2"
	mag_type = MAGAZINE
	caliber = "14.5mm"
	w_class = 3
	matter = list(DEFAULT_WALL_MATERIAL = 4500)
	ammo_type = /obj/item/ammo_casing/a145
	max_ammo = 20
	multiple_sprites = TRUE
	is_box = TRUE

/obj/item/ammo_casing/c4mm
	name = "a 4mm bullet casing"
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistol_bullet_casing"
	projectile_type = /obj/item/projectile/bullet/rifle/c4mm
	caliber = "c4mm"

/obj/item/ammo_casing/a792x33
	desc = "A 7.92x33mm bullet casing."
	caliber = "a792x33"
	weight = 0.00811
	projectile_type = /obj/item/projectile/bullet/rifle/a792x33

/obj/item/ammo_casing/a762x54
	desc = "A 7.62x54mm bullet casing."
	caliber = "a762x54"
	icon_state = "kclipe-bullet"
	spent_icon = "kclipe-casing"
	weight = 0.012
	projectile_type = /obj/item/projectile/bullet/rifle/a762x54

/obj/item/ammo_casing/a792x57
	desc = "A 7.92x57mm bullet casing."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	caliber = "a792x57"
	weight = 0.0127
	projectile_type = /obj/item/projectile/bullet/rifle/a792x57

/obj/item/ammo_casing/a77x58
	desc = "A 7.7x58mm bullet casing."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	caliber = "a77x58"
	weight = 0.0118
	projectile_type = /obj/item/projectile/bullet/rifle/a77x58

/obj/item/ammo_casing/a77x58_weaker
	desc = "A 7.7x58mm bullet casing."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	caliber = "a77x58"
	weight = 0.0118
	projectile_type = /obj/item/projectile/bullet/rifle/a77x58_weaker

/obj/item/ammo_casing/c77x58_smg
	desc = "A 7.7x58mm bullet casing."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	caliber = "c77x58_smg"
	weight = 0.0118
	projectile_type = /obj/item/projectile/bullet/rifle/c77x58_smg

/obj/item/ammo_casing/a792x57_weaker
	desc = "A 7.92x57mm bullet casing."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	caliber = "a792x57"
	weight = 0.011
	projectile_type = /obj/item/projectile/bullet/rifle/a792x57_weaker

/obj/item/ammo_casing/a762x25
	desc = "A 7.62x25mm bullet casing."
	caliber = "a762x25"
	weight = 0.0056
	projectile_type = /obj/item/projectile/bullet/rifle/a762x25

/obj/item/ammo_casing/a9_parabellum
	desc = "A 9mm parabellum bullet casing."
	caliber = "9x19mm"
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistol_bullet_casing"
	weight = 0.0095
	projectile_type = /obj/item/projectile/bullet/rifle/a9_parabellum

/obj/item/ammo_casing/a9_parabellum_luger
	desc = "A 9mm parabellum bullet casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistol_bullet_casing"
	caliber = "a9mm_para_luger"
	weight = 0.0095
	projectile_type = /obj/item/projectile/bullet/rifle/a9_parabellum_luger

/obj/item/ammo_casing/c8mmnambu
	desc = "A 8mm Nambu bullet casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistol_bullet_casing"
	caliber = "c8mmnambu"
	weight = 0.0095
	projectile_type = /obj/item/projectile/bullet/rifle/c8mmnambu

/obj/item/ammo_casing/c8mmnambu_smg
	desc = "A 8mm Nambu bullet casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistol_bullet_casing"
	caliber = "c8mmnambu_smg"
	weight = 0.0095
	projectile_type = /obj/item/projectile/bullet/rifle/c8mmnambu_smg

/obj/item/ammo_casing/c45cal
	desc = "A .45 bullet casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistol_bullet_casing"
	caliber = "c45cal"
	projectile_type = /obj/item/projectile/bullet/rifle/c45cal

/obj/item/ammo_casing/c45_smg
	desc = "A .45 bullet casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistol_bullet_casing"
	caliber = "c45_smg"
	projectile_type = /obj/item/projectile/bullet/rifle/c45_smg

/obj/item/ammo_casing/c762x63
	desc = "A 30-06 bullet casing."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	caliber = "c762x63"
	projectile_type = /obj/item/projectile/bullet/rifle/c762x63

/obj/item/ammo_casing/c762x63_smg
	desc = "A 30-06 bullet casing."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	caliber = "c762x63_smg"
	projectile_type = /obj/item/projectile/bullet/rifle/c762x63_smg


/obj/item/ammo_casing/c762mm_tokarev
	desc = "A 7.62mm pistol bullet casing."
	caliber = "7.62mm"
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistol_bullet_casing"
	weight = 0.00557
	projectile_type = /obj/item/projectile/bullet/rifle/c762mm_tokarev

/obj/item/ammo_casing/c763x25mm_mauser
	desc = "A 7.63x25mm pistol bullet casing."
	icon_state = "7.63x25m-bullet"
	spent_icon = "7.63x25m-casing"
	caliber = "7.63x25mm"
	weight = 0.0039
	projectile_type = /obj/item/projectile/bullet/rifle/c763x25mm_mauser

/obj/item/ammo_casing/c9x19mm_stenmk2
	desc = "A 9x19mm bullet casing."
	caliber = "9x19mm"
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistol_bullet_casing"
	weight = 0.0095
	projectile_type = /obj/item/projectile/bullet/rifle/c9x19mm_stenmk3

/obj/item/ammo_casing/c762x38mmR
	desc = "A 7.62x38mmR bullet casing."
	caliber = "7.62x38mmR"
	icon_state = "7.62x38mmR-1"
	spent_icon = "7.62x38mmR-casing"
	weight = 0.00635
	projectile_type = /obj/item/projectile/bullet/rifle/c762x38mmR

/obj/item/ammo_casing/c762x25mm_pps
	desc = "A 7.62x25mm bullet casing."
	caliber = "7.62x25mm"
	weight = 0.0056
	projectile_type = /obj/item/projectile/bullet/rifle/c762x25mm_pps


/obj/item/ammo_casing/c792x57_fg42
	desc = "A 7.92x57mm bullet casing."
	caliber = "7.92x57mm"
	projectile_type = /obj/item/projectile/bullet/rifle/c792x57_fg42

/obj/item/ammo_casing/c65x52mm
	desc = "A 6.5x52mm Carcano bullet casing."
	caliber = "6.5x52mm"
	weight = 0.008
	projectile_type = /obj/item/projectile/bullet/rifle/c65x52mm

/obj/item/ammo_casing/p9x19mm
	desc = "A 9x19mm Parabellum bullet casing."
	caliber = "9x19mm"
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistol_bullet_casing"
	weight = 0.00952
	projectile_type = /obj/item/projectile/bullet/rifle/p9x19mm

/obj/item/ammo_casing/s9x19mm
	desc = "A 9x19mm Parabellum bullet casing."
	caliber = "9x19mm"
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistol_bullet_casing"
	weight = 0.00952
	projectile_type = /obj/item/projectile/bullet/rifle/s9x19mm

/*
/obj/item/ammo_casing/svt
	desc = "A SVT bullet casing."
	caliber = "a792x33"
	projectile_type = /obj/item/projectile/bullet/rifle/a792x33
*/
/************************
		OTHER
************************/

/obj/item/ammo_casing/chameleon
	name = "chameleon bullets"
	desc = "A set of bullets for the Chameleon Gun."
	projectile_type = /obj/item/projectile/bullet/chameleon
	caliber = ".45"

/obj/item/ammo_casing/a762x39
	name = "a 7.62x39 bullet casing"
	projectile_type = /obj/item/projectile/bullet/rifle/a762x39
	weight = 0.0136
	caliber = "a762x39"

/obj/item/ammo_casing/a762x51
	name = "a 7.62x51 bullet casing"
	projectile_type = /obj/item/projectile/bullet/rifle/a762x51
	caliber = "a762x51"

/obj/item/ammo_casing/a556x45
	name = "a 5.56x45 bullet casing"
	projectile_type = /obj/item/projectile/bullet/rifle/a556x45
	caliber = "a556x45"

/obj/item/ammo_casing/a127x108
	name = "a 12.7x108 bullet casing"
	projectile_type = /obj/item/projectile/bullet/rifle/a127x108
	caliber = "a127x108"

/obj/item/ammo_casing/grenade
	name = "grenade"
	desc = "I hate descriptions."
	caliber = "grenade"

/obj/item/ammo_casing/grenade/he
	name = "he grenade"
	icon_state = "he_grenade"
	projectile_type = /obj/item/projectile/grenade/he
	caliber = "grenade"

/obj/item/ammo_casing/grenade/smoke
	name = "smoke grenade"
	icon_state = "smoke_grenade"
	projectile_type = /obj/item/projectile/grenade/smoke
	caliber = "grenade"

/obj/item/ammo_casing/a9x39
	desc = "a 9x39 bullet casing"
	projectile_type = /obj/item/projectile/bullet/rifle/a9x39
	caliber = "a9x39"

/**********************
		ROCKETS
**********************/

/obj/item/ammo_casing/rocket_he
	name = "a he rocket"
	desc = "High explosive rocket."
	projectile_type = /obj/item/projectile/bullet/rifle/missile/he
	caliber = "rocket"

/obj/item/ammo_casing/rocket/yuge
	projectile_type = /obj/item/projectile/bullet/rifle/missile/yuge

/obj/item/ammo_casing/rocket/yuge/lessyuge
	projectile_type = /obj/item/projectile/bullet/rifle/missile/yuge/lessyuge

/obj/item/ammo_casing/rocket/tank
	projectile_type = /obj/item/projectile/bullet/rifle/missile/tank

/////////////////////FLAREGUNS//////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////

/obj/item/ammo_casing/flare
	name = "flare shell"
	icon_state = "flare_casing"
	projectile_type = /obj/item/projectile/flare
	caliber = "flare"


/////////////////XVIII CENTURY STUFF/////////////////////////////
/obj/item/ammo_casing/musketball
	name = "musketball projectile"
	icon_state = "musketball_gunpowder"
	spent_icon = null
	projectile_type = /obj/item/projectile/bullet/rifle/musketball
	weight = 0.02
	caliber = "musketball"

/obj/item/ammo_casing/musketball_pistol
	name = "small musketball projectile"
	projectile_type = /obj/item/projectile/bullet/rifle/musketball_pistol
	weight = 0.015
	icon_state = "musketball_pistol_gunpowder"
	spent_icon = null
	caliber = "musketball_pistol"

/obj/item/ammo_casing/blunderbuss
	name = "some blunderbuss projectiles"
	icon_state = "blunderbuss_gunpowder"
	spent_icon = null
	projectile_type = /obj/item/projectile/bullet/rifle/blunderbuss
	weight = 0.035
	caliber = "blunderbuss"