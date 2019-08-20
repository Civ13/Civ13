/obj/item/weapon/gun/projectile/pistol
	// less accurate than rifles against still targets, but better against moving targets
	// less accurate than semiautos but with the same ratios
	move_delay = 1
	fire_delay = 3
	item_state = "pistol"
	equiptimer = 5
	gun_safety = TRUE
	gun_type = GUN_TYPE_PISTOL
	accuracy_list = list(
		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 40,

			MEDIUM_RANGE_STILL = 53,
			MEDIUM_RANGE_MOVING = 35,

			LONG_RANGE_STILL = 45,
			LONG_RANGE_MOVING = 30,

			VERY_LONG_RANGE_STILL = 38,
			VERY_LONG_RANGE_MOVING = 25),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 64,
			SHORT_RANGE_MOVING = 42,

			MEDIUM_RANGE_STILL = 56,
			MEDIUM_RANGE_MOVING = 38,

			LONG_RANGE_STILL = 49,
			LONG_RANGE_MOVING = 32,

			VERY_LONG_RANGE_STILL = 41,
			VERY_LONG_RANGE_MOVING = 27),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 68,
			SHORT_RANGE_MOVING = 44,

			MEDIUM_RANGE_STILL = 60,
			MEDIUM_RANGE_MOVING = 40,

			LONG_RANGE_STILL = 53,
			LONG_RANGE_MOVING = 35,

			VERY_LONG_RANGE_STILL = 45,
			VERY_LONG_RANGE_MOVING = 30),
	)

	accuracy_increase_mod = 1.50
	accuracy_decrease_mod = 2.00
	KD_chance = KD_CHANCE_LOW
	stat = "pistol"
	aim_miss_chance_divider = 2.00

/obj/item/weapon/gun/projectile/pistol/attackby(obj/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/attachment/bayonet))
		user << "<span class = 'danger'>That won't fit on there.</span>"
		return FALSE
	else
		return ..()

/obj/item/weapon/gun/projectile/pistol/nambu
	name = "Nambu Pistol"
	desc = "Standard issue Japanese pistol. Chambered in 8mm nambu ammunition."
	icon_state = "nambu"
	w_class = 2
	caliber = "c8mmnambu"
	fire_sound = 'sound/weapons/guns/fire/pistol_fire.ogg'
	magazine_type = /obj/item/ammo_magazine/c8mmnambu
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/c8mmnambu
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.94
/obj/item/weapon/gun/projectile/pistol/nambu/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "nambu"
	else
		icon_state = "nambu0"
	return

/obj/item/weapon/gun/projectile/pistol/ww2/nambu
	name = "Nambu Type 14"
	desc = "Standard issue Japanese pistol. Chambered in 8mm nambu ammunition."
	icon_state = "nambu_ww2"
	w_class = 2
	caliber = "c8mmnambu"
	fire_sound = 'sound/weapons/guns/fire/pistol_fire.ogg'
	magazine_type = /obj/item/ammo_magazine/c8mmnambu
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/c8mmnambu
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.94
/obj/item/weapon/gun/projectile/pistol/ww2/nambu/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "nambu_ww2"
	else
		icon_state = "nambu_ww20"
	return

/obj/item/weapon/gun/projectile/pistol/luger
	name = "Luger P08"
	desc = "A Luger P08 chambered in 9x19mm parabellum, german design."
	icon_state = "luger"
	w_class = 2
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/pistol_fire.ogg'
	magazine_type = /obj/item/ammo_magazine/luger
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a9x19
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.96
/obj/item/weapon/gun/projectile/pistol/luger/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "luger"
	else
		icon_state = "luger0"
	return

/obj/item/weapon/gun/projectile/pistol/waltherp38
	name = "Walther P38"
	desc = "A Walther P38 chambered in 9x19mm parabellum, german design."
	icon_state = "waltherp38"
	w_class = 2
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/pistol_fire.ogg'
	magazine_type = /obj/item/ammo_magazine/walther
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a9x19
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.96
/obj/item/weapon/gun/projectile/pistol/waltherp38/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "waltherp38"
	else
		icon_state = "waltherp380"
	return

/obj/item/weapon/gun/projectile/pistol/mauser
	name = "Mauser c96"
	desc = "A Mauser c96 chambered in 9x19mm parabellum, german design."
	icon_state = "mauser"
	w_class = 2
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/pistol_fire.ogg'
	magazine_type = /obj/item/ammo_magazine/mauser
	weight = 0.794
	max_shells = 10
	ammo_type = /obj/item/ammo_casing/a9x19
	load_method = SINGLE_CASING | SPEEDLOADER
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.9
/obj/item/weapon/gun/projectile/pistol/mauser/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "mauser"
	else
		icon_state = "mauser0"
	return

/obj/item/weapon/gun/projectile/pistol/borchardt
	name = "Borchardt c93"
	desc = "A Borchardt c93 semi-automatic pistol chambered in 7.65x25mm parabellum, german design."
	icon_state = "borchardt"
	w_class = 2
	caliber = "a765x25"
	fire_sound = 'sound/weapons/guns/fire/pistol_fire.ogg'
	magazine_type = /obj/item/ammo_magazine/borchardt
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a765x25
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.9
/obj/item/weapon/gun/projectile/pistol/borchardt/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "borchardt"
	else
		icon_state = "borchardt0"
	return


/obj/item/weapon/gun/projectile/pistol/m1911
	name = "Colt M1911"
	desc = "The standard issue pistol of the US Army. Chambered in .45 ACP."
	icon_state = "colt"
	w_class = 2
	caliber = "a45acp"
	fire_sound = 'sound/weapons/guns/fire/pistol_fire.ogg'
	magazine_type = /obj/item/ammo_magazine/m1911
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a45acp
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 1.02

/obj/item/weapon/gun/projectile/pistol/tt30
	name = "TT-30"
	desc = "The standard issue pistol of the Soviet Union. Chambered in 7.62x25mm Tokarev."
	icon_state = "tt30"
	w_class = 2
	caliber = "a765x25"
	fire_sound = 'sound/weapons/guns/fire/pistol_fire.ogg'
	magazine_type = /obj/item/ammo_magazine/tt30
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a765x25
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.98

/obj/item/weapon/gun/projectile/pistol/m9beretta
	name = "M9 Beretta"
	desc = "The standard issue pistol of the US Army of the late 20th century. Chambered in 9mm Parabellum."
	icon_state = "m9beretta"
	w_class = 2
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/pistol_fire.ogg'
	magazine_type = /obj/item/ammo_magazine/m9beretta
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a9x19
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 1.12

/obj/item/weapon/gun/projectile/pistol/jericho941
	name = "Jericho 941"
	desc = "The standard issue pistol of the IDF of the late 20th century. Chambered in 9mm Parabellum."
	icon_state = "jericho941"
	w_class = 2
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/pistol_fire.ogg'
	magazine_type = /obj/item/ammo_magazine/jericho
	weight = 0.85
	ammo_type = /obj/item/ammo_casing/a9x19
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 1.12