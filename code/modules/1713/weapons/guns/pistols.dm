/obj/item/weapon/gun/projectile/pistol
	// less accurate than rifles against still targets, but better against moving targets
	// less accurate than semiautos but with the same ratios
	icon = 'icons/obj/guns/pistols.dmi'
	move_delay = 1
	fire_delay = 3
	item_state = "pistol"
	equiptimer = 5
	gun_safety = TRUE
	gun_type = GUN_TYPE_PISTOL
	handle_casings = EJECT_CASINGS
	silencer_fire_sound = 'sound/weapons/guns/fire/Glock17-SD.ogg'
	maxhealth = 45
	gtype = "pistol"

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
	KD_chance = KD_CHANCE_MEDIUM
	stat = "pistol"
	aim_miss_chance_divider = 2.00

/obj/item/weapon/gun/projectile/pistol/attackby(obj/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/attachment/bayonet))
		user << "<span class = 'danger'>That won't fit on there.</span>"
		return FALSE
	else
		return ..()

/obj/item/weapon/gun/projectile/pistol/nambu
	name = "Type A Nambu"
	desc = "Standard issue Japanese pistol. Chambered in 8x22mm Nambu."
	icon_state = "nambu"
	w_class = ITEM_SIZE_SMALL
	caliber = "c8mmnambu"
	fire_sound = 'sound/weapons/guns/fire/Nambu.ogg'
	magazine_type = /obj/item/ammo_magazine/c8mmnambu
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/c8mmnambu
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.94
	good_mags = list(/obj/item/ammo_magazine/c8mmnambu, /obj/item/ammo_magazine/c8mmnambu/empty)
	bad_magazine_types = list(/obj/item/weapon/gun/projectile/submachinegun/type100)
/obj/item/weapon/gun/projectile/pistol/nambu/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "nambu"
	else
		icon_state = "nambu_open"
	return

/obj/item/weapon/gun/projectile/pistol/ww2/nambu
	name = "Type 14 Nambu"
	desc = "Standard issue Japanese pistol. Chambered in 8x22mm Nambu."
	icon_state = "nambu_ww2"
	w_class = ITEM_SIZE_SMALL
	caliber = "c8mmnambu"
	fire_sound = 'sound/weapons/guns/fire/Nambu.ogg'
	magazine_type = /obj/item/ammo_magazine/c8mmnambu
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/c8mmnambu
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.94
	good_mags = list(/obj/item/ammo_magazine/c8mmnambu, /obj/item/ammo_magazine/c8mmnambu/empty)
	bad_magazine_types = list(/obj/item/weapon/gun/projectile/submachinegun/type100)
/obj/item/weapon/gun/projectile/pistol/ww2/nambu/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "nambu_ww2"
	else
		icon_state = "nambu_ww2_open"
	return

/obj/item/weapon/gun/projectile/pistol/luger
	name = "Luger P08"
	desc = "A Luger P08 chambered in 9x19mm parabellum, german design."
	icon_state = "luger"
	w_class = ITEM_SIZE_SMALL
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/9mm.ogg'
	magazine_type = /obj/item/ammo_magazine/luger
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a9x19
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.96
	good_mags = list(/obj/item/ammo_magazine/luger, /obj/item/ammo_magazine/luger/empty)
	bad_magazine_types = list(/obj/item/ammo_magazine/mp40)
/obj/item/weapon/gun/projectile/pistol/luger/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "luger"
	else
		icon_state = "luger_open"
	return

/obj/item/weapon/gun/projectile/pistol/waltherp38
	name = "Walther P38"
	desc = "A Walther P38 chambered in 9x19mm parabellum, german design."
	icon_state = "waltherp38"
	w_class = ITEM_SIZE_SMALL
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/9mm.ogg'
	magazine_type = /obj/item/ammo_magazine/walther
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a9x19
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.96
	good_mags = list(/obj/item/ammo_magazine/walther)
	bad_magazine_types = list(/obj/item/ammo_magazine/mp40)

/obj/item/weapon/gun/projectile/pistol/waltherp38/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "waltherp38"
	else
		icon_state = "waltherp38_open"
	return

/obj/item/weapon/gun/projectile/pistol/waltherp38/silenced/New()
	..()

	var/obj/item/weapon/attachment/silencer/pistol/SP = new/obj/item/weapon/attachment/silencer/pistol(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/pistol/glock17
	name = "Glock 17"
	desc = "A modern pistol, loaded on 9x19mm, reliable and fast."
	icon_state = "glock17"
	fire_delay = 2.3
	w_class = ITEM_SIZE_SMALL
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/9mm.ogg'
	magazine_type = /obj/item/ammo_magazine/glock17
	weight = 0.594
	max_shells = 17 //Glock 17 real capacity
	ammo_type = /obj/item/ammo_casing/a9x19
	good_mags = list(/obj/item/ammo_magazine/glock17)
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.9

/obj/item/weapon/gun/projectile/pistol/glock17/standardized
	magazine_type = /obj/item/ammo_magazine/emptymagazine/pistol


/obj/item/weapon/gun/projectile/pistol/glock17/silenced/New()
	..()

	var/obj/item/weapon/attachment/silencer/pistol/SP = new/obj/item/weapon/attachment/silencer/pistol(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/pistol/glock17/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "glock17"
	else
		icon_state = "glock17_open"
	return

/obj/item/weapon/gun/projectile/pistol/sig250
	name = "SIG 250"
	desc = "A modern pistol, loaded on 9x19mm, reliable and fast."
	icon_state = "sig250"
	item_state = "sig250"
	fire_delay = 2.3
	w_class = ITEM_SIZE_SMALL
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/pistol.ogg'
	magazine_type = /obj/item/ammo_magazine/sig250
	weight = 0.594
	max_shells = 17
	ammo_type = /obj/item/ammo_casing/a9x19
	good_mags = list(/obj/item/ammo_magazine/sig250)
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.99
/obj/item/weapon/gun/projectile/pistol/sig250/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "sig250"
	else
		icon_state = "sig250_open"
	return

/obj/item/weapon/gun/projectile/pistol/pl14
	name = "PL-14"
	desc = "A modern experimental pistol made by Kalashnikov (chambered in 9x19mm)."
	icon_state = "pl14"
	fire_delay = 1.8
	w_class = ITEM_SIZE_SMALL
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/pistol.ogg'
	magazine_type = /obj/item/ammo_magazine/pl14
	good_mags = list(/obj/item/ammo_magazine/pl14)
	weight = 0.594
	max_shells = 16
	ammo_type = /obj/item/ammo_casing/a9x19
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.15

/obj/item/weapon/gun/projectile/pistol/pl14/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "pl14"
	else
		icon_state = "pl14_open"
	return

/obj/item/weapon/gun/projectile/pistol/mp443
	name = "MP-443 Grach"
	desc = "A Russian made pistol firing loaded on 9x19mm."
	icon_state = "mp443"
	fire_delay = 3.15
	w_class = ITEM_SIZE_SMALL
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/pistol.ogg'
	magazine_type = /obj/item/ammo_magazine/mp443
	good_mags = list(/obj/item/ammo_magazine/mp443)
	weight = 0.594
	max_shells = 17
	ammo_type = /obj/item/ammo_casing/a9x19
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 1.05
/obj/item/weapon/gun/projectile/pistol/mp443/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "mp443"
	else
		icon_state = "mp443_open"
	return

/obj/item/weapon/gun/projectile/pistol/tarus
	name = "Tarus G3"
	desc = "A modern pistol, loaded on 9x19mm, reliable and fast."
	icon_state = "tarusg3"
	fire_delay = 2.3
	w_class = ITEM_SIZE_SMALL
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/pistol.ogg'
	magazine_type = /obj/item/ammo_magazine/glock17
	good_mags = list(/obj/item/ammo_magazine/glock17)
	weight = 0.594
	max_shells = 17
	ammo_type = /obj/item/ammo_casing/a9x19
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.95
/obj/item/weapon/gun/projectile/pistol/tarus/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "tarusg3"
	else
		icon_state = "tarusg3_open"
	return

/obj/item/weapon/gun/projectile/pistol/p220
	name = "SIG Sauer P220"
	desc = "The SIG Sauer P220 is a semi-automatic pistol. Designed in 1975."
	icon_state = "p220"
	fire_delay = 3.7
	w_class = ITEM_SIZE_SMALL
	caliber = "a45"
	fire_sound = 'sound/weapons/guns/fire/45ACP.ogg'
	magazine_type = /obj/item/ammo_magazine/p220
	good_mags = list(/obj/item/ammo_magazine/p220)
	weight = 0.594
	max_shells = 7
	ammo_type = /obj/item/ammo_casing/a45
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 1.40

/obj/item/weapon/gun/projectile/pistol/p220/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "p220"
	else
		icon_state = "p220_open"
	return

/obj/item/weapon/gun/projectile/pistol/p220/silenced/New()
	..()

	var/obj/item/weapon/attachment/silencer/pistol/SP = new/obj/item/weapon/attachment/silencer/pistol(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/pistol/iogb7
	name = "IOQ B-72"
	desc = "Some fake shit invented by Re1taz."
	icon_state = "iogb7"
	fire_delay = 1.1
	w_class = ITEM_SIZE_SMALL
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/pistol.ogg'
	magazine_type = /obj/item/ammo_magazine/glock17
	good_mags = list(/obj/item/ammo_magazine/glock17)
	weight = 0.594
	max_shells = 17
	ammo_type = /obj/item/ammo_casing/a9x19
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 1.6
/obj/item/weapon/gun/projectile/pistol/iogb7/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "iogb7"
	else
		icon_state = "iogb7_open"
	return

/obj/item/weapon/gun/projectile/pistol/mauser
	name = "Mauser C96"
	desc = "An early German pistol that can chamber 7.62x25mm TT."
	icon_state = "mauser"
	w_class = ITEM_SIZE_SMALL
	caliber = "a762x25"
	fire_sound = 'sound/weapons/guns/fire/762x25.ogg'
	magazine_type = /obj/item/ammo_magazine/mauser
	good_mags = list(/obj/item/ammo_magazine/mauser)
	weight = 0.794
	max_shells = 10
	ammo_type = /obj/item/ammo_casing/a762x25
	damage_modifier = 0.98
	load_method = SINGLE_CASING | SPEEDLOADER
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.95
/obj/item/weapon/gun/projectile/pistol/mauser/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "mauser"
	else
		icon_state = "mauser_open"
	return

/obj/item/weapon/gun/projectile/pistol/borchardt
	name = "Borchardt C93"
	desc = "A German semi-automatic pistol chambered in 7.65x25mm Borchardt."
	icon_state = "borchardt"
	w_class = ITEM_SIZE_SMALL
	caliber = "a765x25"
	fire_sound = 'sound/weapons/guns/fire/762x25.ogg'
	magazine_type = /obj/item/ammo_magazine/borchardt
	good_mags = list(/obj/item/ammo_magazine/borchardt, /obj/item/ammo_magazine/borchardt/empty)
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a765x25
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.93
/obj/item/weapon/gun/projectile/pistol/borchardt/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "borchardt"
	else
		icon_state = "borchardt_open"
	return

/obj/item/weapon/gun/projectile/pistol/colthammerless
	name = "Colt M1903 Pocket Hammerless"
	desc = "An early, compact Colt pistol chambered in .32 ACP."
	icon_state = "coltpockethammerless"
	w_class = ITEM_SIZE_SMALL
	equiptimer = 4
	caliber = "a32acp"
	fire_sound = 'sound/weapons/guns/fire/32ACP.ogg'
	magazine_type = /obj/item/ammo_magazine/colthammerless
	good_mags = list(/obj/item/ammo_magazine/colthammerless)
	weight = 0.680
	ammo_type = /obj/item/ammo_casing/a32acp
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.95
	pocket = TRUE

/obj/item/weapon/gun/projectile/pistol/colthammerless/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "coltpockethammerless"
	else
		icon_state = "coltpockethammerless_open"
	return

/obj/item/weapon/gun/projectile/pistol/colthammerless/m1908
	name = "Colt M1908 Pocket Hammerless"
	desc = "A later version of the compact Colt pistol, chambered in .380 ACP."
	icon_state = "coltpockethammerless"
	w_class = ITEM_SIZE_SMALL
	caliber = "a380acp"
	fire_sound = 'sound/weapons/guns/fire/9mm.ogg'
	magazine_type = /obj/item/ammo_magazine/colthammerless/a380acp
	good_mags = list(/obj/item/ammo_magazine/colthammerless/a380acp)
	weight = 0.720
	ammo_type = /obj/item/ammo_casing/a380acp
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.9

/obj/item/weapon/gun/projectile/pistol/bergmann
	name = "Bergmann No.2"
	desc = "A particularly unique-in-appearance early German semi-automatic pistol."
	icon_state = "bergmann"
	w_class = ITEM_SIZE_SMALL
	caliber = "c8mmnambu"
	fire_sound = 'sound/weapons/guns/fire/Nambu.ogg'
	magazine_type = /obj/item/ammo_magazine/bergmann
	good_mags = list(/obj/item/ammo_magazine/bergmann)
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/c8mmnambu
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.9


/obj/item/weapon/gun/projectile/pistol/bergmann/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "bergmann"
	else
		icon_state = "bergmann"
	return

/obj/item/weapon/gun/projectile/pistol/m1911
	name = "M1911A1"
	desc = "The standard issue pistol of the US Armed forces from 1911 to 1985. Chambered in .45 ACP."
	icon_state = "colt"
	w_class = ITEM_SIZE_SMALL
	caliber = "a45acp"
	fire_sound = 'sound/weapons/guns/fire/45ACP.ogg'
	magazine_type = /obj/item/ammo_magazine/m1911
	good_mags = list(/obj/item/ammo_magazine/m1911, /obj/item/ammo_magazine/m1911/empty)
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a45acp
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 1.02
	bad_magazine_types = list(/obj/item/ammo_magazine/thompson)

/obj/item/weapon/gun/projectile/pistol/m1911/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "colt"
	else
		icon_state = "colt_open"
	return

/obj/item/weapon/gun/projectile/pistol/blackm1911
	name = "Colt Mark IV"
	desc = "A slightly upgraded model of the M1911A1. Chambered in .45 ACP."
	icon_state = "colt"
	w_class = ITEM_SIZE_SMALL
	caliber = "a45acp"
	fire_sound = 'sound/weapons/guns/fire/45ACP.ogg'
	magazine_type = /obj/item/ammo_magazine/m1911
	good_mags = list(/obj/item/ammo_magazine/m1911)
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a45acp
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 1.02

/obj/item/weapon/gun/projectile/pistol/blackm1911/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "colt"
	else
		icon_state = "colt_open"
	return


/obj/item/weapon/gun/projectile/pistol/blackm1911/silenced/New()
	..()

	var/obj/item/weapon/attachment/silencer/pistol/SP = new/obj/item/weapon/attachment/silencer/pistol(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/pistol/tt30
	name = "TT-33"
	desc = "The standard issue pistol of the Soviet Union before the 1950's. Chambered in 7.62x25mm Tokarev."
	icon_state = "tt30"
	w_class = ITEM_SIZE_SMALL
	caliber = "a762x25"
	fire_sound = 'sound/weapons/guns/fire/762x25.ogg'
	magazine_type = /obj/item/ammo_magazine/tt30
	good_mags = list(/obj/item/ammo_magazine/tt30, /obj/item/ammo_magazine/tt30ll, /obj/item/ammo_magazine/tt30/empty,/obj/item/ammo_magazine/tt30ll/rubber)
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a762x25
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.98
	bad_magazine_types = list(/obj/item/ammo_magazine/c762x25_ppsh, /obj/item/ammo_magazine/c762x25_pps)

/obj/item/weapon/gun/projectile/pistol/tt30/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "tt30"
	else
		icon_state = "tt30_open"
	return

/obj/item/weapon/gun/projectile/pistol/tt30/silenced/New()
	..()

	var/obj/item/weapon/attachment/silencer/pistol/SP = new/obj/item/weapon/attachment/silencer/pistol(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/pistol/tt30/silenced/New()
	..()

	var/obj/item/weapon/attachment/silencer/pistol/SP = new/obj/item/weapon/attachment/silencer/pistol(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/pistol/makarov
	name = "Makarov PM"
	desc = "The standard issue pistol of the Soviet Union and Russian Federation after the 1950's. Chambered in 9x18mm Makarov."
	icon_state = "makarov"
	w_class = ITEM_SIZE_SMALL
	caliber = "a9x18"
	fire_sound = 'sound/weapons/guns/fire/762x25.ogg'
	magazine_type = /obj/item/ammo_magazine/makarov
	good_mags = list(/obj/item/ammo_magazine/makarov, /obj/item/ammo_magazine/makarov/empty)
	weight = 0.704
	ammo_type = /obj/item/ammo_casing/a9x18
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 0.98
	bad_magazine_types = list(/obj/item/ammo_magazine/c762x25_ppsh, /obj/item/ammo_magazine/c762x25_pps)

/obj/item/weapon/gun/projectile/pistol/makarov/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "makarov"
	else
		icon_state = "makarov_open"
	return

/obj/item/weapon/gun/projectile/pistol/makarov/silenced/New()
	..()

	var/obj/item/weapon/attachment/silencer/pistol/SP = new/obj/item/weapon/attachment/silencer/pistol(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/pistol/m9beretta
	name = "Beretta M9"
	desc = "The standard issue pistol of US Armed Forces from 1985 to 2017. Chambered in 9mm Luger."
	icon_state = "m9beretta"
	w_class = ITEM_SIZE_SMALL
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/9mm.ogg'
	magazine_type = /obj/item/ammo_magazine/m9beretta
	good_mags = list(/obj/item/ammo_magazine/m9beretta)
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a9x19
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 1.12

/obj/item/weapon/gun/projectile/pistol/m9beretta/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "m9beretta"
	else
		icon_state = "m9beretta_open"
	return

/obj/item/weapon/gun/projectile/pistol/m9beretta/silenced/New()
	..()

	var/obj/item/weapon/attachment/silencer/pistol/SP = new/obj/item/weapon/attachment/silencer/pistol(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/pistol/m9beretta/tan
	name = "Beretta M9"
	desc = "The standard issue pistol of US Armed Forces from 1985 to 2017. Chambered in 9mm Luger. This one blends in with the desert"
	icon_state = "tanm9"
	w_class = ITEM_SIZE_SMALL
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/9mm.ogg'
	magazine_type = /obj/item/ammo_magazine/m9beretta
	good_mags = list(/obj/item/ammo_magazine/m9beretta)
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a9x19
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 1.12

/obj/item/weapon/gun/projectile/pistol/m9beretta/tan/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "tanm9"
	else
		icon_state = "tanm9_open"

/obj/item/weapon/gun/projectile/pistol/jericho941
	name = "Jericho 941"
	desc = "The standard issue pistol of the IDF of the late 20th century. Chambered in 9mm Parabellum."
	icon_state = "jericho941"
	w_class = ITEM_SIZE_SMALL
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/9mm.ogg'
	magazine_type = /obj/item/ammo_magazine/jericho
	good_mags = list(/obj/item/ammo_magazine/jericho)
	weight = 0.85
	ammo_type = /obj/item/ammo_casing/a9x19
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 1.12

/obj/item/weapon/gun/projectile/pistol/jericho941/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "jericho941"
	else
		icon_state = "jericho941_open"
	return
/obj/item/weapon/gun/projectile/pistol/deagle
	name = "Desert Eagle"
	desc = "Designed and developed by Magnum Research Inc. Chambered in 50cal."
	icon_state = "deagle"
	w_class = ITEM_SIZE_SMALL
	caliber = "a50cal"
	fire_sound = 'sound/weapons/guns/fire/deagle.ogg'
	magazine_type = /obj/item/ammo_magazine/deagle
	good_mags = list(/obj/item/ammo_magazine/deagle)
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a50cal
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 1.02
	bad_magazine_types = list(/obj/item/ammo_magazine/thompson)

/obj/item/weapon/gun/projectile/pistol/deagle/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "deagle"
	else
		icon_state = "deagle_open"
	return

/obj/item/weapon/gun/projectile/pistol/deaglemagnum
	name = "Desert Eagle (44.magnum)"
	desc = "Designed and developed by Magnum Research Inc. Chambered in 44.magnum."
	icon_state = "deagle"
	w_class = ITEM_SIZE_SMALL
	caliber = "a44magnum"
	fire_sound = 'sound/weapons/guns/fire/deagle.ogg'
	magazine_type = /obj/item/ammo_magazine/deagle
	good_mags = list(/obj/item/ammo_magazine/deaglemagnum)
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a44magnum
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 1.02
	bad_magazine_types = list(/obj/item/ammo_magazine/thompson)

/obj/item/weapon/gun/projectile/pistol/deaglemagnum/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "deagle"
	else
		icon_state = "deagle_open"
	return

/obj/item/weapon/gun/projectile/pistol/browninghp
	name = "Browning hi-power"
	desc = "Produced by Fabrique Nationale of Belgium, This old handgun is chambered in 9mm Parabellum."
	icon_state = "browning_hp"
	w_class = ITEM_SIZE_SMALL
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/9mm.ogg'
	magazine_type = /obj/item/ammo_magazine/browninghp
	good_mags = list(/obj/item/ammo_magazine/browninghp)
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a9x19
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 1.02
	bad_magazine_types = list(/obj/item/ammo_magazine/thompson)

/obj/item/weapon/gun/projectile/pistol/browninghp/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "browning_hp"
	else
		icon_state = "browning_hp_open"
	return

/obj/item/weapon/gun/projectile/pistol/sti2011
	name = "STI 2011"
	desc = "A high end specialized version of a m1911 made by the request of the US marshal service chambered .45 S&W."
	icon_state = "sti2011"
	w_class = ITEM_SIZE_SMALL
	caliber = "a45acp"
	fire_sound = 'sound/weapons/guns/fire/45ACP.ogg'
	magazine_type = /obj/item/ammo_magazine/sti2011
	good_mags = list(/obj/item/ammo_magazine/sti2011)
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/a45acp
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	effectiveness_mod = 1.12
	bad_magazine_types = list(/obj/item/ammo_magazine/thompson)

/obj/item/weapon/gun/projectile/pistol/sti2011/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "sti2011"
	else
		icon_state = "sti2011_open"
	return