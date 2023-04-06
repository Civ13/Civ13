/obj/item/weapon/gun/projectile/submachinegun
	force = 10
	throwforce = 20
	fire_sound = 'sound/weapons/guns/fire/smg.ogg'
	silencer_fire_sound = 'sound/weapons/guns/fire/Gyrza-SD.ogg'
	icon = 'icons/obj/guns/automatic.dmi'
	var/base_icon = "smg"
	// more accuracy than MGs, less than everything else
	load_method = MAGAZINE
	slot_flags = SLOT_SHOULDER|SLOT_BELT
	equiptimer = 12
	gun_safety = TRUE
	load_delay = 8
	gun_type = GUN_TYPE_RIFLE
	gtype = "smg"
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 55,

			MEDIUM_RANGE_STILL = 44,
			MEDIUM_RANGE_MOVING = 39,

			LONG_RANGE_STILL = 22,
			LONG_RANGE_MOVING = 15,

			VERY_LONG_RANGE_STILL = 7,
			VERY_LONG_RANGE_MOVING = 6),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 72,
			SHORT_RANGE_MOVING = 62,

			MEDIUM_RANGE_STILL = 54,
			MEDIUM_RANGE_MOVING = 45,

			LONG_RANGE_STILL = 34,
			LONG_RANGE_MOVING = 21,

			VERY_LONG_RANGE_STILL = 9,
			VERY_LONG_RANGE_MOVING = 7),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 91,
			SHORT_RANGE_MOVING = 81,

			MEDIUM_RANGE_STILL = 66,
			MEDIUM_RANGE_MOVING = 57,

			LONG_RANGE_STILL = 45,
			LONG_RANGE_MOVING = 33,

			VERY_LONG_RANGE_STILL = 16,
			VERY_LONG_RANGE_MOVING = 13),
	)

	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 1.50
	KD_chance = KD_CHANCE_HIGH+3
	stat = "machinegun"
	w_class = ITEM_SIZE_NORMAL
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS
	var/jammed_until = -1
	var/jamcheck = 0
	var/last_fire = -1
	var/one_handed = FALSE
	reload_sound = 'sound/weapons/guns/interact/AR15Reload.ogg'
	unload_sound = 'sound/weapons/guns/interact/AR15Unload.ogg'

/obj/item/weapon/gun/projectile/submachinegun/special_check(mob/user)
	if (gun_safety && safetyon)
		user << "<span class='warning'>You can't fire \the [src] while the safety is on!</span>"
		return FALSE
	if (!user.has_empty_hand(both = FALSE) && one_handed == FALSE)
		user << "<span class='warning'>You need both hands to fire \the [src]!</span>"
		return FALSE
	if (jammed_until > world.time)
		user << "<span class = 'danger'>\The [src] has jammed! You can't fire it until it has unjammed.</span>"
		return FALSE
	return TRUE

/obj/item/weapon/gun/projectile/submachinegun/stg
	name = "StG-44"
	desc = "German assault rifle chambered in 7.92x33mm Kurz, 30 round magazine."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "stg"
	item_state = "stg"
	base_icon = "stg"
	load_method = MAGAZINE
	slot_flags = SLOT_SHOULDER|SLOT_BELT
	w_class = ITEM_SIZE_LARGE
	caliber = "a792x33"

	fire_sound = 'sound/weapons/guns/fire/stg.ogg'
	reload_sound = 'sound/weapons/guns/interact/stg_reload.ogg'
	magazine_type = /obj/item/ammo_magazine/stg
	good_mags = list(/obj/item/ammo_magazine/stg)
	weight = 4.6
	load_delay = 8
	equiptimer = 15
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.8, move_delay=2, dispersion = list(0.2, 0.3, 0.3, 0.4, 0.5)),
		list(name = "full auto",	burst=1, burst_delay=1.5, move_delay=4, dispersion = list(1.2, 1.4, 1.4, 1.4, 1.7)),
		)

	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/handle_post_fire()
	..()
	var/reverse_health_percentage = (1-(health/maxhealth)+0.25)*100
	if (world.time - last_fire > 50)
		jamcheck = 0
	else
		jamcheck += 0.12

	if (prob(jamcheck*reverse_health_percentage))
		jammed_until = max(world.time + (jamcheck * 4), 45)
		jamcheck = 0

	last_fire = world.time

/obj/item/weapon/gun/projectile/submachinegun/update_icon()
	if (sniper_scope)
		if (!ammo_magazine)
			icon_state = "[base_icon]_scope_open"
			return
		else
			icon_state = "[base_icon]_scope"
			return
	else
		if (ammo_magazine)
			icon_state = base_icon
			item_state = base_icon
		else
			icon_state = "[base_icon]_open"
			item_state = "[base_icon]_open"
	update_held_icon()

	return
/obj/item/weapon/gun/projectile/submachinegun/spas
	name = "Spas-12"
	icon_state = "spas12"
	item_state = "spas12"
	base_icon = "spas12"
	desc = "A dual mode shotgun designed in Italy by the Franchi Firearms Company with an 8 round capacity."
	max_shells = 8 //match the ammo box capacity, also it can hold a round in the chamber anyways, for a total of 8.
	caliber = "12gauge"
	handle_casings = EJECT_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/shotgun/buckshot
	force = 15
	throwforce = 30
	weight = 3.4
	fire_sound = 'sound/weapons/guns/fire/shotgun.ogg'
	firemodes = list(
		list(name = "semi auto",    burst=1, burst_delay=0.7, recoil=0, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.5, 0.6)),
		list(name = "full auto",    burst=1, burst_delay=1.2, recoil=0, move_delay=4, dispersion = list(1.1, 1.2, 1.3, 1.3, 1.5)),
		)

/obj/item/weapon/gun/projectile/submachinegun/spas/secondary_attack_self(mob/living/human/user)
	switch_firemodes(user)

/obj/item/weapon/gun/projectile/submachinegun/saiga12
	name = "Saiga-12K"
	icon_state = "saiga12"
	item_state = "saiga12"
	base_icon = "saiga12"
	desc = "A 12 gauge semi-automatic, gas-operated combat shotgun used by Russian Armed Forces."
	magazine_type = /obj/item/ammo_magazine/saiga12
	weight = 3.5
	equiptimer = 11
	effectiveness_mod = 1.46
	caliber = "12gauge"
	slot_flags = SLOT_SHOULDER
	handle_casings = EJECT_CASINGS
	load_method = MAGAZINE
	good_mags = list(/obj/item/ammo_magazine/saiga12, /obj/item/ammo_magazine/saiga12/slug)
	recoil = 1
	force = 15
	throwforce = 30
	weight = 3.4
	attachment_slots = ATTACH_BARREL
	fire_sound = 'sound/weapons/guns/fire/shotgun.ogg'
	firemodes = list(
		list(name = "semi auto",    burst=1, burst_delay=0.7, recoil=0, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.5, 0.6)),
		)

	sel_mode = 1
	gun_type = GUN_TYPE_RIFLE

/obj/item/weapon/gun/projectile/submachinegun/mp40
	name = "MP40"
	desc = "Iconic German submachinegun with an underfolding stock, chambered in 9mm Luger."
	icon_state = "mp40"
	item_state = "mp40"
	base_icon = "mp40"
	weight = 3.97
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/mp40.ogg'
	magazine_type = /obj/item/ammo_magazine/mp40
	good_mags = list(/obj/item/ammo_magazine/mp40)
	full_auto = TRUE
	equiptimer = 12
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.1, recoil=0, move_delay=3, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1
	effectiveness_mod = 1.05

/obj/item/weapon/gun/projectile/submachinegun/mp40/mp38
	name = "MP38"
	desc = "Early German submachinegun with an underfolding stock, chambered in 9mm Luger."
	weight = 4.10
	full_auto = TRUE
	equiptimer = 13
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.1, recoil=0, move_delay=3, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1
	effectiveness_mod = 0.95

/obj/item/weapon/gun/projectile/submachinegun/ermaemp
	name = "Erma-Emp"
	desc = "A very early German submachinegun produced by the ERMA factory with an wooden stock, chambered in 9mm Luger."
	icon_state = "ermaemp"
	item_state = "ermaemp"
	base_icon = "ermaemp"
	weight = 4.25
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/mp40.ogg'
	magazine_type = /obj/item/ammo_magazine/mp40/erma
	good_mags = list(/obj/item/ammo_magazine/mp40,/obj/item/ammo_magazine/mp40/erma)
	full_auto = TRUE
	equiptimer = 14
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.1, recoil=0, move_delay=3, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1
	effectiveness_mod = 1.01

/obj/item/weapon/gun/projectile/submachinegun/mp40/blyskawica
	name = "Blyskawica"
	desc = "Polish Underground State submachine gun, chambered in 9mm Luger."
	icon_state = "blyskawica"
	item_state = "blyskawica"
	base_icon = "blyskawica"
	weight = 4.12
	equiptimer = 10
	firemodes = list(
		list(name = "full auto",    burst=1.2, burst_delay=1.4, recoil=0, move_delay=4, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.6)),
		)
	sel_mode = 1
	effectiveness_mod = 0.95

/obj/item/weapon/gun/projectile/submachinegun/mp40/mp5
	name = "H&K MP5"
	desc = "German submachinegun chambered in 9mm Parabellum."
	icon_state = "mp5"
	item_state = "mp5"
	base_icon = "mp5"
	weight = 2.9
	equiptimer = 8
	fire_sound = 'sound/weapons/guns/fire/MP5.ogg'
	magazine_type = /obj/item/ammo_magazine/mp40/mp5
	good_mags = list(/obj/item/ammo_magazine/mp40/mp5)
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.08, recoil=0, move_delay=0.5, dispersion = list(0.1, 0.2, 0.1, 0.2, 0)),
		list(name = "full auto",	burst=1, burst_delay=1, recoil=0, move_delay=3, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)
	sel_mode = 1
	effectiveness_mod = 1.2

/obj/item/weapon/gun/projectile/submachinegun/fg42
	name = "FG42"
	desc = "A German automatic rifle that was developed specifically for the use of the Fallschirmjäger airborne infantry, it is chambered in 7.92x57 Mauser."
	icon_state = "fg42"
	item_state = "fg42"
	base_icon = "fg42"
	weight = 4.2
	caliber = "a792x57"
	fire_sound = 'sound/weapons/guns/fire/mg34.ogg'
	magazine_type = /obj/item/ammo_magazine/fg42
	good_mags = list(/obj/item/ammo_magazine/fg42,/obj/item/ammo_magazine/fg42/small)
	full_auto = TRUE
	equiptimer = 12
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.3, recoil=0, move_delay=1, dispersion = list(0.2, 0.4, 0.4, 0.4, 0.5)),
		list(name = "full auto",	burst=1, burst_delay=0.4, recoil=0, move_delay=3, dispersion = list(0.8, 1.3, 1.3, 1.4, 1.6)),
		)
	sel_mode = 1
	effectiveness_mod = 0.95
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_ADV_SCOPE

/obj/item/weapon/gun/projectile/submachinegun/fg42/scope/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/advanced/fg42/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/fg42(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/submachinegun/uzi
	name = "Uzi"
	desc = "An Israeli submachinegun chambered in 9mm Parabellum."
	icon_state = "uzi"
	item_state = "uzi"
	base_icon = "uzi"
	caliber = "a9x19"
	weight = 2.1
	equiptimer = 5
	fire_sound = 'sound/weapons/guns/fire/9mm.ogg'
	magazine_type = /obj/item/ammo_magazine/uzi
	good_mags = list(/obj/item/ammo_magazine/uzi)
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.4, recoil=0, move_delay=1, dispersion = list(0.2, 0.4, 0.4, 0.4, 0.5)),
		list(name = "full auto",	burst=1, burst_delay=0.9, recoil=0, move_delay=3, dispersion = list(1.3, 1.4, 1.5, 1.6, 1.7)),
		)
	sel_mode = 1
	effectiveness_mod = 1.05
	one_handed = TRUE

/obj/item/weapon/gun/projectile/submachinegun/mac10
	name = "MAC-10"
	desc = "An American compact blowback operated submachinegun chambered in 9mm Parabellum."
	icon_state = "mac10"
	item_state = "mac10"
	base_icon = "mac10"
	weight = 1.7
	equiptimer = 7
	caliber = "a45acp"
	fire_sound = 'sound/weapons/guns/fire/45ACP.ogg'
	magazine_type = /obj/item/ammo_magazine/mac10
	good_mags = list(/obj/item/ammo_magazine/mac10)
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.3, recoil=0, move_delay=1, dispersion = list(0.2, 0.4, 0.4, 0.4, 0.5)),
		list(name = "full auto",	burst=1, burst_delay=0.5, recoil=0, move_delay=3, dispersion = list(1.5, 1.6, 1.7, 1.8, 1.9)),
		)
	sel_mode = 1
	effectiveness_mod = 0.9
	one_handed = TRUE

/obj/item/weapon/gun/projectile/submachinegun/tec9
	name = "TEC-9"
	desc = "A blowback-operated semi-automatic pistol."
	icon = 'icons/obj/guns/automatic.dmi'
	icon_state = "tec-9"
	item_state = "tec-9"
	base_icon = "tec-9"
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/tec9.ogg'
	magazine_type = /obj/item/ammo_magazine/tec9
	good_mags = list(/obj/item/ammo_magazine/tec9)
	weight = 1.3
	equiptimer = 8
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.2, move_delay=2, dispersion = list(0.6, 0.6, 0.7, 0.8, 0.9)),
		list(name = "full auto",	burst=1, burst_delay=0.3, move_delay=4, dispersion = list(1.6, 1.7, 1.8, 1.9, 2.0)),
		)
	effectiveness_mod = 0.8
	sel_mode = 1
	attachment_slots = ATTACH_IRONSIGHTS
	one_handed = TRUE

/obj/item/weapon/gun/projectile/submachinegun/skorpion
	name = "Skorpion"
	desc = "An Czechoslovak machinepistol chambered in 9mm Parabellum."
	icon_state = "skorpion"
	item_state = "skorpion"
	base_icon = "skorpion"
	caliber = "a9x19"
	weight = 1.1
	equiptimer = 6
	fire_sound = 'sound/weapons/guns/fire/9mm.ogg'
	magazine_type = /obj/item/ammo_magazine/skorpion
	good_mags = list(/obj/item/ammo_magazine/skorpion)
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.4, recoil=0, move_delay=1, dispersion = list(0.2, 0.4, 0.4, 0.4, 0.5)),
		list(name = "full auto",	burst=1, burst_delay=0.8, recoil=0, move_delay=3, dispersion = list(1.2, 1.3, 1.4, 1.5, 1.6)),
		)
	sel_mode = 1
	effectiveness_mod = 0.95
	one_handed = TRUE

/obj/item/weapon/gun/projectile/submachinegun/greasegun
	name = "M3A1 SMG"
	desc = "A simplistic American submachinegun, chambered in .45 ACP."
	icon_state = "greasegun"
	item_state = "greasegun"
	base_icon = "greasegun"
	weight = 3.6
	caliber = "a45acp"
	fire_sound = 'sound/weapons/guns/fire/M3A1.ogg'
	magazine_type = /obj/item/ammo_magazine/greasegun
	good_mags = list(/obj/item/ammo_magazine/greasegun)
	full_auto = TRUE
	slot_flags = SLOT_BELT|SLOT_SHOULDER
	equiptimer = 7
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.4, recoil=0, move_delay=3, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1
	effectiveness_mod = 1.05

/obj/item/weapon/gun/projectile/submachinegun/thompson
	name = "Thompson M1A1"
	desc = "An American submachinegun, chambered in .45 ACP."
	icon_state = "thompson"
	item_state = "thompson"
	base_icon = "thompson"
	weight = 3.6
	caliber = "a45acp"
	fire_sound = 'sound/weapons/guns/fire/Thompson.ogg'
	magazine_type = /obj/item/ammo_magazine/thompson
	good_mags = list(/obj/item/ammo_magazine/thompson, /obj/item/ammo_magazine/tommy)
	full_auto = TRUE
	slot_flags = SLOT_BELT|SLOT_SHOULDER
	equiptimer = 8
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.2, recoil=0, move_delay=3, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1
	effectiveness_mod = 1.06

/obj/item/weapon/gun/projectile/submachinegun/tommy
	name = "Thompson M1928"
	desc = "An American submachinegun, chambered in .45 ACP."
	icon_state = "tommygun"
	item_state = "thompson"
	base_icon = "tommygun"
	weight = 3.6
	caliber = "a45acp"
	fire_sound = 'sound/weapons/guns/fire/Thompson.ogg'
	magazine_type = /obj/item/ammo_magazine/tommy
	good_mags = list(/obj/item/ammo_magazine/thompson, /obj/item/ammo_magazine/tommy)
	full_auto = TRUE
	slot_flags = SLOT_BELT|SLOT_SHOULDER
	equiptimer = 8
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.0, recoil=0, move_delay=3, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1
	effectiveness_mod = 1.03

/obj/item/weapon/gun/projectile/submachinegun/type100
	name = "Type-100"
	desc = "A Japanese submachinegun, chambered in 8x22mm Nambu."
	icon_state = "type100"
	item_state = "type100"
	base_icon = "type100"
	weight = 3.97
	attachment_slots = ATTACH_BARREL
	caliber = "c8mmnambu"
	fire_sound = 'sound/weapons/guns/fire/Type100.ogg'
	magazine_type = /obj/item/ammo_magazine/type100
	good_mags = list(/obj/item/ammo_magazine/type100)
	full_auto = TRUE
	equiptimer = 12
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.3, recoil=0, move_delay=3, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1
	effectiveness_mod = 1.04


/obj/item/weapon/gun/projectile/submachinegun/sten
	name = "Sten MK II"
	desc = "A British submachinegun, chambered in 9x19 Parabellum."
	icon_state = "sten2"
	item_state = "sten2"
	base_icon = "sten2"
	weight = 3.2
	attachment_slots = ATTACH_BARREL
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/Thompson.ogg'
	magazine_type = /obj/item/ammo_magazine/sten2
	good_mags = list(/obj/item/ammo_magazine/sten2)
	full_auto = TRUE
	slot_flags = SLOT_SHOULDER
	equiptimer = 8
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.25, recoil=0, move_delay=2, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.4)),
		)

	sel_mode = 1
	effectiveness_mod = 0.85

/obj/item/weapon/gun/projectile/submachinegun/ppsh
	name = "PPSh-41"
	desc = "Soviet submachinegun typically equipped with drum magazines. Chambered in 7.62x25mm Tokarev."
	icon_state = "ppsh"
	item_state = "ppsh"
	base_icon = "ppsh"
	caliber = "a762x25"
	fire_sound = 'sound/weapons/guns/fire/762x25.ogg'
	full_auto = TRUE
	magazine_type = /obj/item/ammo_magazine/c762x25_ppsh
	good_mags = list(/obj/item/ammo_magazine/c762x25_ppsh, /obj/item/ammo_magazine/c762x25_pps)
	weight = 3.63
	equiptimer = 14
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.5, recoil=0, move_delay=1, dispersion = list(0.2, 0.4, 0.4, 0.4, 0.5)),
		list(name = "full auto",	burst=1, burst_delay=1.2, recoil=0, move_delay=3, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/ppsh/chinese
	name = "Type 50"
	desc = "Chinese Variant of the Iconic Soviet submachinegun. Chambered in 7.62x25mm Tokarev."
	weight = 3.61
	equiptimer = 11

/obj/item/weapon/gun/projectile/submachinegun/pps
	name = "PPS-43"
	desc = "A simplistic Soviet submachinegun. Chambered in 7.62x25mm Tokarev."
	icon_state = "pps"
	item_state = "pps"
	base_icon = "pps"
	caliber = "a762x25"
	fire_sound = 'sound/weapons/guns/fire/762x25.ogg'
	full_auto = TRUE
	magazine_type = /obj/item/ammo_magazine/c762x25_pps
	good_mags = list(/obj/item/ammo_magazine/c762x25_ppsh, /obj/item/ammo_magazine/c762x25_pps)
	weight = 3.04
	equiptimer = 10
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.1, recoil=0, move_delay=3, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/ppd
	name = "PPD-40"
	desc = "Early Soviet submachinegun. Chambered in 7.62x25mm Tokarev."
	icon_state = "ppd"
	item_state = "ppd"
	base_icon = "ppd"
	caliber = "a762x25"
	fire_sound = 'sound/weapons/guns/fire/762x25.ogg'
	full_auto = TRUE
	magazine_type = /obj/item/ammo_magazine/c762x25_ppsh
	good_mags = list(/obj/item/ammo_magazine/c762x25_ppsh, /obj/item/ammo_magazine/c762x25_pps)
	weight = 3.7
	equiptimer = 15
	effectiveness_mod = 0.84
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.5, recoil=0, move_delay=1, dispersion = list(0.3, 0.4, 0.5, 0.5, 0.6)),
		list(name = "full auto",	burst=1, burst_delay=1.3, recoil=0, move_delay=4, dispersion = list(0.8, 1.3, 1.4, 1.5, 1.6)),
		)

	sel_mode = 1
///obj/item/weapon/gun/projectile/submachinegun/ppd/update_icon() //doesnt work, loading in a mag/drum makes the gun inhand sprite have no mag/drum, keeping it here though.
//	if (ammo_magazine)
//		if (istype(ammo_magazine, /obj/item/ammo_magazine/c762x25_ppsh))
//			icon_state = "[base_icon]"
//			item_state = "ppd"
//			return
//		else
//			icon_state = "[base_icon]_mag"
//			item_state = "ppd"
//			return
//	else
//		icon_state = "[base_icon]_open"
//		item_state = "ppd_open"
//	update_held_icon()
//	return

/obj/item/weapon/gun/projectile/submachinegun/ak47
	name = "AKM"
	desc = "Iconic Soviet assault rifle, chambered in 7.62x39mm."
	icon_state = "ak47"
	icon = 'icons/obj/guns/assault_rifles.dmi'
	item_state = "ak47"
	base_icon = "ak47"
	caliber = "a762x39"
	fire_sound = 'sound/weapons/guns/fire/AKM.ogg'
	magazine_type = /obj/item/ammo_magazine/ak47
	good_mags = list(/obj/item/ammo_magazine/ak47, /obj/item/ammo_magazine/ak47/drum, /obj/item/ammo_magazine/ak47/makeshift)
	weight = 3.47
	equiptimer = 15
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.2, recoil=0, move_delay=0.5, dispersion = list(0.1, 0.2, 0.1, 0, 0.1)),
		list(name = "full auto",	burst=1, burst_delay=1.3, recoil=0, move_delay=4, dispersion = list(1.2, 1.2, 1.3, 1.4, 1.8)),
		)
	stat = "rifle"
	effectiveness_mod = 1
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 50,
			MEDIUM_RANGE_MOVING = 40,

			LONG_RANGE_STILL = 30,
			LONG_RANGE_MOVING = 15,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 82,
			SHORT_RANGE_MOVING = 72,

			MEDIUM_RANGE_STILL = 64,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 44,
			LONG_RANGE_MOVING = 31,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 91,
			SHORT_RANGE_MOVING = 81,

			MEDIUM_RANGE_STILL = 76,
			MEDIUM_RANGE_MOVING = 67,

			LONG_RANGE_STILL = 55,
			LONG_RANGE_MOVING = 43,

			VERY_LONG_RANGE_STILL = 36,
			VERY_LONG_RANGE_MOVING = 23),
	)

/obj/item/weapon/gun/projectile/submachinegun/ak47/gold
	name = "gold-plated AKM"
	desc = "Iconic Soviet assault rifle, chambered in 7.62x39mm. This one is plated in gold. It looks very expensive."
	icon_state = "ak47gold"
	item_state = "ak47gold"
	base_icon = "ak47gold"

/obj/item/weapon/gun/projectile/submachinegun/ak47/chinese
	name = "Type 56 Assault Rifle"
	desc = "Chinese 7.62x39mm rifle. It is a variant of the Soviet-designed AK-47."
/obj/item/weapon/gun/projectile/submachinegun/ak47/akms
	name = "AKMS"
	desc = "Iconic Soviet assault rifle, chambered in 7.62x39mm. This one has a wire underfolding stock."
	slot_flags = SLOT_SHOULDER
	icon_state = "akms"
	item_state = "akms"
	base_icon = "akms"
	var/folded = FALSE
	weight = 3

/obj/item/weapon/gun/projectile/submachinegun/ak47/akms/update_icon()
	if (folded)
		base_icon = "akms_folded"
	else
		base_icon = "akms"
	if (ammo_magazine)
		icon_state = base_icon
		item_state = base_icon
	else
		icon_state = "[base_icon]_open"
		item_state = "[base_icon]_open"
	update_held_icon()

	return

/obj/item/weapon/gun/projectile/submachinegun/ak47/akms/verb/fold()
	set name = "Toggle Stock"
	set category = null
	set src in usr
	if (folded)
		folded = FALSE
		base_icon = "akms"
		usr << "You extend the stock on \the [src]."
		equiptimer = 15
		set_stock()
		update_icon()
	else
		folded = TRUE
		base_icon = "akms_folded"
		usr << "You collapse the stock on \the [src]."
		equiptimer = 7
		set_stock()
		update_icon()

/obj/item/weapon/gun/projectile/submachinegun/ak47/akms/proc/set_stock()
	if (folded)
		slot_flags = SLOT_SHOULDER|SLOT_BELT
		effectiveness_mod = 0.84
	else
		slot_flags = SLOT_SHOULDER
		effectiveness_mod = 1

/obj/item/weapon/gun/projectile/submachinegun/ak74
	name = "AK-74"
	desc = "Soviet assault rifle, chambered in 5.45x39mm."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "ak74"
	item_state = "ak74"
	base_icon = "ak74"
	caliber = "a545x39"
	fire_sound = 'sound/weapons/guns/fire/AK74.ogg'
	magazine_type = /obj/item/ammo_magazine/ak74
	good_mags = list(/obj/item/ammo_magazine/ak74, /obj/item/ammo_magazine/ak74/drum,/obj/item/ammo_magazine/ak74/rubber)
	weight = 3.07
	equiptimer = 15
	slot_flags = SLOT_SHOULDER
	stat = "rifle"
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.1, recoil=0, move_delay=0.2, dispersion = list(0.1, 0, 0.2, 0, 0.1)),
		list(name = "full auto",	burst=1, burst_delay=1.2, recoil=0, move_delay=4, dispersion = list(1.1, 1.2, 1.3, 1.3, 1.5)),
		)
	effectiveness_mod = 1.07
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 50,
			MEDIUM_RANGE_MOVING = 40,

			LONG_RANGE_STILL = 30,
			LONG_RANGE_MOVING = 15,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 82,
			SHORT_RANGE_MOVING = 72,

			MEDIUM_RANGE_STILL = 64,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 44,
			LONG_RANGE_MOVING = 31,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 91,
			SHORT_RANGE_MOVING = 81,

			MEDIUM_RANGE_STILL = 76,
			MEDIUM_RANGE_MOVING = 67,

			LONG_RANGE_STILL = 55,
			LONG_RANGE_MOVING = 43,

			VERY_LONG_RANGE_STILL = 36,
			VERY_LONG_RANGE_MOVING = 23),
	)
/obj/item/weapon/gun/projectile/submachinegun/ak74/pso1/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/advanced/pso1/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/pso1(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74
	name = "AKS-74"
	desc = "Soviet assault rifle chambered in 5.45x39mm, with a folding stock."
	slot_flags = SLOT_SHOULDER
	icon_state = "aks74"
	item_state = "aks74"
	base_icon = "aks74"
	var/folded = FALSE
	weight = 2.95
	effectiveness_mod = 1.05

/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/update_icon()
	if (folded)
		base_icon = "aks74_folded"
	else
		base_icon = "aks74"
	if (sniper_scope)
		if (!ammo_magazine)
			icon_state = "[base_icon]_scope_open"
			return
		else
			icon_state = "[base_icon]_scope"
			return
	else
		if (ammo_magazine)
			icon_state = base_icon
			item_state = base_icon
		else
			icon_state = "[base_icon]_open"
			item_state = "[base_icon]_open"
	update_held_icon()

	return

/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/verb/fold()
	set name = "Toggle Stock"
	set category = null
	set src in usr
	if (folded)
		folded = FALSE
		base_icon = "aks74"
		usr << "You extend the stock on \the [src]."
		equiptimer = 15
		set_stock()
		update_icon()
	else
		folded = TRUE
		base_icon = "aks74_folded"
		usr << "You collapse the stock on \the [src]."
		equiptimer = 7
		set_stock()
		update_icon()

/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/proc/set_stock()
	if (folded)
		slot_flags = SLOT_SHOULDER|SLOT_BELT
		effectiveness_mod = 0.87
	else
		slot_flags = SLOT_SHOULDER
		effectiveness_mod = 1.05

/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u
	name = "AKS-74U"
	desc = "Soviet compact assault rifle, chambered in 5.45x39mm, with a folding stock."
	slot_flags = SLOT_SHOULDER
	icon_state = "aks74u"
	item_state = "aks74u"
	base_icon = "aks74u"
	folded = FALSE
	weight = 2.7
	effectiveness_mod = 1.02
	damage_modifier = 0.95
	equiptimer = 12

/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/update_icon()
	if (folded)
		base_icon = "aks74u_folded"
	else
		base_icon = "aks74u"
	if (sniper_scope)
		if (!ammo_magazine)
			icon_state = "[base_icon]_scope_open"
			return
		else
			icon_state = "[base_icon]_scope"
			return
	else
		if (ammo_magazine)
			icon_state = base_icon
			item_state = base_icon
		else
			icon_state = "[base_icon]_open"
			item_state = "[base_icon]_open"
	update_held_icon()

	return

/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/fold()
	set name = "Toggle Stock"
	set category = null
	set src in usr
	if (folded)
		folded = FALSE
		base_icon = "aks74u"
		usr << "You extend the stock on \the [src]."
		equiptimer = 12
		set_stock()
		update_icon()
	else
		folded = TRUE
		base_icon = "aks74u_folded"
		usr << "You collapse the stock on \the [src]."
		equiptimer = 6
		set_stock()
		update_icon()

/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/set_stock()
	if (folded)
		slot_flags = SLOT_SHOULDER|SLOT_BELT
		effectiveness_mod = 0.84
	else
		slot_flags = SLOT_SHOULDER
		effectiveness_mod = 1.02

/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/aks74uso
	name = "AKS-74U SpecOps"
	desc = "Soviet assault carbine version of the AK-74, chambered in 5.45x39mm, with a folding stock. This one has picatinny rails for attachments."
	slot_flags = SLOT_SHOULDER
	icon_state = "aks74uso"
	item_state = "aks74uso"
	base_icon = "aks74uso"
	folded = FALSE
	weight = 2.65
	effectiveness_mod = 1.02
	damage_modifier = 0.95
	equiptimer = 12
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_ADV_SCOPE|ATTACH_UNDER|ATTACH_BARREL

/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/aks74uso/update_icon()
	if (folded)
		base_icon = "aks74uso_folded"
	else
		base_icon = "aks74uso"
	if (sniper_scope)
		if (!ammo_magazine)
			icon_state = "[base_icon]_scope_open"
			return
		else
			icon_state = "[base_icon]_scope"
			return
	else
		if (ammo_magazine)
			icon_state = base_icon
			item_state = base_icon
		else
			icon_state = "[base_icon]_open"
			item_state = "[base_icon]_open"
	update_held_icon()

	return

/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/aks74uso/kgb
	folded = TRUE
	weight = 2.6
	effectiveness_mod = 1.07
	damage_modifier = 0.98
	equiptimer = 10


/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/aks74uso/kgb/New()
	..()

	var/obj/item/weapon/attachment/scope/adjustable/advanced/holographic/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/holographic(src)
	SP.attached(null,src,TRUE)


	var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
	FP.attached(null,src,TRUE)

	var/obj/item/weapon/attachment/silencer/SL = new/obj/item/weapon/attachment/silencer(src)
	SL.attached(null,src,TRUE)


/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/aks74uso/fold()
	set name = "Toggle Stock"
	set category = null
	set src in usr
	if (folded)
		folded = FALSE
		base_icon = "aks74uso"
		usr << "You extend the stock on \the [src]."
		equiptimer = 12
		set_stock()
		update_icon()
	else
		folded = TRUE
		base_icon = "aks74uso_folded"
		usr << "You collapse the stock on \the [src]."
		equiptimer = 5
		set_stock()
		update_icon()


/obj/item/weapon/gun/projectile/submachinegun/ak74m
	name = "AK-74M"
	desc = "Russian assault rifle, chambered in 5.45x39mm."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "ak74m"
	item_state = "ak74m"
	base_icon = "ak74m"
	caliber = "a545x39"
	fire_sound = 'sound/weapons/guns/fire/AK74.ogg'
	magazine_type = /obj/item/ammo_magazine/ak74/ak74m
	good_mags = list(/obj/item/ammo_magazine/ak74/ak74m, /obj/item/ammo_magazine/ak74, /obj/item/ammo_magazine/ak74/drum, /obj/item/ammo_magazine/ak74/ak74m/drum)
	weight = 3.07
	equiptimer = 15
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.7, recoil=0, move_delay=2, dispersion = list(0.1, 0.2, 0.15, 0.2, 0.1)),
		list(name = "full auto",	burst=1, burst_delay=1.2, recoil=0, move_delay=4, dispersion = list(1.1, 1.15, 1.2, 1.15, 1.1)),
		)
	effectiveness_mod = 1.08
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
	stat = "rifle"
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 50,
			MEDIUM_RANGE_MOVING = 40,

			LONG_RANGE_STILL = 30,
			LONG_RANGE_MOVING = 15,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 82,
			SHORT_RANGE_MOVING = 72,

			MEDIUM_RANGE_STILL = 64,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 44,
			LONG_RANGE_MOVING = 31,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 91,
			SHORT_RANGE_MOVING = 81,

			MEDIUM_RANGE_STILL = 76,
			MEDIUM_RANGE_MOVING = 67,

			LONG_RANGE_STILL = 55,
			LONG_RANGE_MOVING = 43,

			VERY_LONG_RANGE_STILL = 36,
			VERY_LONG_RANGE_MOVING = 23),
	)
/obj/item/weapon/gun/projectile/submachinegun/ak74m/ak12
	name = "AK-12"
	desc = "A fifth generation Modern AK variant, chambered in 5.45x39mm."
	icon_state = "ak12"
	item_state = "ak12"
	base_icon = "ak12"
	caliber = "a545x39"
	weight = 3.05
	effectiveness_mod = 1.13
	equiptimer = 12
	magazine_type = /obj/item/ammo_magazine/ak74
	good_mags = list(/obj/item/ammo_magazine/ak74/ak74m, /obj/item/ammo_magazine/ak74, /obj/item/ammo_magazine/ak74/drum, /obj/item/ammo_magazine/ak74/ak74m/drum)
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
	equiptimer = 12
	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/ak74m/ak12/ak15
	name = "AK-15"
	desc = "A fifth generation Modern AK variant, chambered in 7.62×39mm."
	icon_state = "ak12"
	item_state = "ak12"
	base_icon = "ak12"
	caliber = "a762x39"
	weight = 3.07
	effectiveness_mod = 1.13
	equiptimer = 12
	fire_sound = 'sound/weapons/guns/fire/AKM.ogg'
	magazine_type = /obj/item/ammo_magazine/ak47
	good_mags = list(/obj/item/ammo_magazine/ak47, /obj/item/ammo_magazine/ak47/drum, /obj/item/ammo_magazine/ak47/makeshift)
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
	equiptimer = 12
	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/m16
	name = "M16A1"
	desc = "An American assault rifle, chambered in 5.56x45mm."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "m16"
	item_state = "m16"
	base_icon = "m16"
	caliber = "a556x45"
	fire_sound = 'sound/weapons/guns/fire/M4A1.ogg'
	magazine_type = /obj/item/ammo_magazine/m16
	good_mags = list(/obj/item/ammo_magazine/m16)
	weight = 3.07
	equiptimer = 15
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.3, recoil=0, move_delay=2, dispersion = list(0.2, 0.1, 0.3, 0.1, 0.2)),
		list(name = "full auto",	burst=1, burst_delay=1.1, recoil=0, move_delay=4, dispersion = list(1, 1.3, 1.5, 1.7, 1.8)),
		)
	effectiveness_mod = 1.07
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 50,
			MEDIUM_RANGE_MOVING = 40,

			LONG_RANGE_STILL = 30,
			LONG_RANGE_MOVING = 15,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 82,
			SHORT_RANGE_MOVING = 72,

			MEDIUM_RANGE_STILL = 64,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 44,
			LONG_RANGE_MOVING = 31,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 91,
			SHORT_RANGE_MOVING = 81,

			MEDIUM_RANGE_STILL = 76,
			MEDIUM_RANGE_MOVING = 67,

			LONG_RANGE_STILL = 55,
			LONG_RANGE_MOVING = 43,

			VERY_LONG_RANGE_STILL = 36,
			VERY_LONG_RANGE_MOVING = 23),
	)
/obj/item/weapon/gun/projectile/submachinegun/m16/ar15
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL|ATTACH_ADV_SCOPE|ATTACH_UNDER
	name = "AR-15"
	desc = "A civilian market version of ArmaLite's AR-15, single-fire only. Has railings for several attachments."
	base_icon = "ar15"
	icon_state = "ar15"
	item_state = "ar15"
	full_auto = FALSE
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.3, recoil=0, move_delay=2, dispersion = list(0.1, 0, 0.2, 0, 0.1)),
		)
/obj/item/weapon/gun/projectile/submachinegun/ar10
	name = "AR-10"
	desc = "An ArmaLite battle rifle, chambered in 7.62x51mm."
	icon_state = "ar10"
	icon = 'icons/obj/guns/assault_rifles.dmi'
	item_state = "m16"
	base_icon = "ar10"
	caliber = "a762x51"
	fire_sound = 'sound/weapons/guns/fire/battle_rifle.ogg'
	reload_sound = 'sound/weapons/guns/interact/AR15Reload.ogg'
	unload_sound = 'sound/weapons/guns/interact/AR15Unload.ogg'
	magazine_type = /obj/item/ammo_magazine/ar10
	good_mags = list(/obj/item/ammo_magazine/ar10)
	weight = 3.07
	equiptimer = 15
	slot_flags = SLOT_SHOULDER
	full_auto = FALSE
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.5, recoil=0, move_delay=2, dispersion = list(0.1, 0.2, 0.1, 0.2, 0.1)),
		)
	effectiveness_mod = 1.03
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 50,
			MEDIUM_RANGE_MOVING = 40,

			LONG_RANGE_STILL = 30,
			LONG_RANGE_MOVING = 15,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 82,
			SHORT_RANGE_MOVING = 72,

			MEDIUM_RANGE_STILL = 64,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 44,
			LONG_RANGE_MOVING = 31,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 91,
			SHORT_RANGE_MOVING = 81,

			MEDIUM_RANGE_STILL = 76,
			MEDIUM_RANGE_MOVING = 67,

			LONG_RANGE_STILL = 55,
			LONG_RANGE_MOVING = 43,

			VERY_LONG_RANGE_STILL = 36,
			VERY_LONG_RANGE_MOVING = 23),
	)
/obj/item/weapon/gun/projectile/submachinegun/m16/commando
	name = "XM177E2"
	desc = "A carbine version of the AR-15/M16, chambered in 5.56x45mm."
	icon_state = "m4"
	item_state = "m4"
	base_icon = "m4"
	caliber = "a556x45"
	fire_sound = 'sound/weapons/guns/fire/M4A1.ogg'
	reload_sound = 'sound/weapons/guns/interact/AR15Reload.ogg'
	unload_sound = 'sound/weapons/guns/interact/AR15Unload.ogg'
	magazine_type = /obj/item/ammo_magazine/m16
	good_mags = list(/obj/item/ammo_magazine/m16)
	weight = 3.07
	equiptimer = 9
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.3, recoil=0, move_delay=2, dispersion = list(0, 0.1, 0, 0.1, 0.2)),
		list(name = "full auto",	burst=1, burst_delay=1.1, recoil=0, move_delay=4, dispersion = list(1, 1.3, 1.5, 1.7, 1.8)),
		)
	effectiveness_mod = 1.08
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS
/obj/item/weapon/gun/projectile/submachinegun/m16/m16a2
	name = "M16A2"
	base_icon = "m16"
	icon_state = "m16"
	desc = "A modernized version of the M16, with burst fire instead of full auto."
	full_auto = FALSE
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.3, recoil=0, move_delay=2, dispersion = list(0.1, 0.3, 0.2, 0.1, 0.1)),
		list(name = "burst fire",	burst=3, burst_delay=1.5, recoil=0, move_delay=3, dispersion = list(0.9, 1.1, 1.2, 1.3, 1.3)),
		)
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS

/obj/item/weapon/gun/projectile/submachinegun/m16/m16a4
	name = "M16A4"
	base_icon = "m16a4"
	icon_state = "m16a4"
	desc = "A modernized version of the M16, with a railed upper receiver and handguard."
	full_auto = FALSE
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.3, recoil=0, move_delay=2, dispersion = list(0.1, 0.2, 0.1, 0, 0.1)),
		list(name = "burst fire",	burst=3, burst_delay=1.5, recoil=0, move_delay=3, dispersion = list(0.9, 1.1, 1.2, 1.3, 1.3)),
		)
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL|ATTACH_ADV_SCOPE|ATTACH_UNDER

/obj/item/weapon/gun/projectile/submachinegun/m16/m16a4/att/New()
	..()
	if (prob(50))
		var/obj/item/weapon/attachment/scope/adjustable/advanced/holographic/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/holographic(src)
		SP.attached(null,src,TRUE)
	else
		var/obj/item/weapon/attachment/scope/adjustable/advanced/acog/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/acog(src)
		SP.attached(null,src,TRUE)
		var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
		FP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4
	name = "M4 Carbine"
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL|ATTACH_UNDER

/obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4mws
	name = "M4 MWS"
	base_icon = "m4mws"
	icon_state = "m4mws"
	desc = "A version of the M4 carbine made to fit the Modular Weapon System."
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_ADV_SCOPE|ATTACH_UNDER|ATTACH_BARREL


/obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4mws/att/New()
	..()
	if (prob(50))
		var/obj/item/weapon/attachment/scope/adjustable/advanced/holographic/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/holographic(src)
		SP.attached(null,src,TRUE)
	else
		var/obj/item/weapon/attachment/scope/adjustable/advanced/acog/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/acog(src)
		SP.attached(null,src,TRUE)
		var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
		FP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4mws/fbi/New()
	..()

	var/obj/item/weapon/attachment/scope/adjustable/advanced/holographic/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/holographic(src)
	SP.attached(null,src,TRUE)


	var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
	FP.attached(null,src,TRUE)

	var/obj/item/weapon/attachment/silencer/SL = new/obj/item/weapon/attachment/silencer(src)
	SL.attached(null,src,TRUE)
/obj/item/weapon/gun/projectile/submachinegun/m14
	name = "M14"
	desc = "An American battle rifle, chambered in 7.62x51mm."
	icon = 'icons/obj/guns/rifles.dmi'
	icon_state = "m14"
	item_state = "m14"
	base_icon = "m14"
	caliber = "a762x51"
	fire_sound = 'sound/weapons/guns/fire/M14Alt.ogg'
	magazine_type = /obj/item/ammo_magazine/m14
	good_mags = list(/obj/item/ammo_magazine/m14)
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	weight = 3.6
	equiptimer = 15
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.6, move_delay=2, dispersion = list(0.1, 0, 0, 0.1, 0.2)),
		list(name = "full auto",	burst=1, burst_delay=1.2, move_delay=4, dispersion = list(1, 1.3, 1.5, 1.8, 1.9)),
		)
	effectiveness_mod = 1.07
	sel_mode = 1
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 63,
			SHORT_RANGE_MOVING = 38,

			MEDIUM_RANGE_STILL = 53,
			MEDIUM_RANGE_MOVING = 32,

			LONG_RANGE_STILL = 43,
			LONG_RANGE_MOVING = 25,

			VERY_LONG_RANGE_STILL = 33,
			VERY_LONG_RANGE_MOVING = 18),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 78,
			SHORT_RANGE_MOVING = 51,

			MEDIUM_RANGE_STILL = 68,
			MEDIUM_RANGE_MOVING = 45,

			LONG_RANGE_STILL = 58,
			LONG_RANGE_MOVING = 38,

			VERY_LONG_RANGE_STILL = 48,
			VERY_LONG_RANGE_MOVING = 32),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 83,
			SHORT_RANGE_MOVING = 55,

			MEDIUM_RANGE_STILL = 73,
			MEDIUM_RANGE_MOVING = 48,

			LONG_RANGE_STILL = 63,
			LONG_RANGE_MOVING = 42,

			VERY_LONG_RANGE_STILL = 53,
			VERY_LONG_RANGE_MOVING = 35),
	)

	accuracy_increase_mod = 2.00
	accuracy_decrease_mod = 6.00

/obj/item/weapon/gun/projectile/submachinegun/m14/sniper/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/submachinegun/m14/sniper/m21
	name = "M21 SWS"
	desc = "An American sniper rifle, chambered in 7.62x51mm."
	effectiveness_mod = 1.12
	sel_mode = 0
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.6, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.5, 0.6)),
		)

/obj/item/weapon/gun/projectile/submachinegun/g3
	name = "H&K G3"
	desc = "A German battle rifle, chambered in 7.62x51mm."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "g3"
	item_state = "g3"
	base_icon = "g3"
	caliber = "a762x51"
	fire_sound = 'sound/weapons/guns/fire/battle_rifle.ogg'
	magazine_type = /obj/item/ammo_magazine/hk
	good_mags = list(/obj/item/ammo_magazine/hk)
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
	weight = 4.2
	equiptimer = 15
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.9, move_delay=2, dispersion = list(0.1, 0.2, 0.1, 0, 0.1)),
		list(name = "full auto",	burst=1, burst_delay=1.2, move_delay=4, dispersion = list(1, 1.3, 1.5, 1.7, 1.7)),
		)
	effectiveness_mod = 1.03
	sel_mode = 1
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 50,
			MEDIUM_RANGE_MOVING = 40,

			LONG_RANGE_STILL = 30,
			LONG_RANGE_MOVING = 15,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 82,
			SHORT_RANGE_MOVING = 72,

			MEDIUM_RANGE_STILL = 64,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 44,
			LONG_RANGE_MOVING = 31,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 91,
			SHORT_RANGE_MOVING = 81,

			MEDIUM_RANGE_STILL = 76,
			MEDIUM_RANGE_MOVING = 67,

			LONG_RANGE_STILL = 55,
			LONG_RANGE_MOVING = 43,

			VERY_LONG_RANGE_STILL = 36,
			VERY_LONG_RANGE_MOVING = 23),
	)
/obj/item/weapon/gun/projectile/submachinegun/fal
	name = "FN Fal"
	desc = "A Belgian battle rifle, chambered in 7.62×51mm."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "fal"
	item_state = "fal"
	base_icon = "fal"
	caliber = "a762x51"
	fire_sound = 'sound/weapons/guns/fire/fnfal.ogg'
	magazine_type = /obj/item/ammo_magazine/fal
	good_mags = list(/obj/item/ammo_magazine/fal)
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
	weight = 3.8
	equiptimer = 12
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.9, move_delay=2, dispersion = list(0.1, 0.2, 0.1, 0, 0.2)),
		list(name = "full auto",	burst=1, burst_delay=1.2, move_delay=4, dispersion = list(1, 1.3, 1.5, 1.8, 1.8)),
		)
	effectiveness_mod = 1.07
	sel_mode = 1
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 50,
			MEDIUM_RANGE_MOVING = 40,

			LONG_RANGE_STILL = 30,
			LONG_RANGE_MOVING = 15,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 82,
			SHORT_RANGE_MOVING = 72,

			MEDIUM_RANGE_STILL = 64,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 44,
			LONG_RANGE_MOVING = 31,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 91,
			SHORT_RANGE_MOVING = 81,

			MEDIUM_RANGE_STILL = 76,
			MEDIUM_RANGE_MOVING = 67,

			LONG_RANGE_STILL = 55,
			LONG_RANGE_MOVING = 43,

			VERY_LONG_RANGE_STILL = 36,
			VERY_LONG_RANGE_MOVING = 23),
	)
/obj/item/weapon/gun/projectile/submachinegun/scarl
	name = "FN SCAR-L"
	desc = "A Belgian assault rifle, chambered in 5.56x45mm."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "scarl"
	item_state = "scarl"
	base_icon = "scarl"
	caliber = "a556x45"
	fire_sound = 'sound/weapons/guns/fire/M4A1.ogg'
	reload_sound = 'sound/weapons/guns/interact/AR15Reload.ogg'
	unload_sound = 'sound/weapons/guns/interact/AR15Unload.ogg'
	magazine_type = /obj/item/ammo_magazine/m16
	good_mags = list(/obj/item/ammo_magazine/m16)
	weight = 3
	equiptimer = 10
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.2, move_delay=2, dispersion = list(0.2, 0.1, 0.2, 0.3, 0.1)),
		list(name = "full auto",	burst=1, burst_delay=1.3, move_delay=3, dispersion = list(0.8, 1, 1.1, 1.1, 1.2)),
		)
	effectiveness_mod = 1.08
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_ADV_SCOPE|ATTACH_UNDER
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 50,
			MEDIUM_RANGE_MOVING = 40,

			LONG_RANGE_STILL = 30,
			LONG_RANGE_MOVING = 15,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 82,
			SHORT_RANGE_MOVING = 72,

			MEDIUM_RANGE_STILL = 64,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 44,
			LONG_RANGE_MOVING = 31,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 91,
			SHORT_RANGE_MOVING = 81,

			MEDIUM_RANGE_STILL = 76,
			MEDIUM_RANGE_MOVING = 67,

			LONG_RANGE_STILL = 55,
			LONG_RANGE_MOVING = 43,

			VERY_LONG_RANGE_STILL = 36,
			VERY_LONG_RANGE_MOVING = 23),
	)
/obj/item/weapon/gun/projectile/submachinegun/scarh
	name = "FN SCAR-H"
	icon_state = "scarh"
	item_state = "scarh"
	base_icon = "scarh"
	desc = "A Belgian-designed automatic rifle, chambered in 7.62x51mm."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	caliber = "a762x51"
	fire_sound = 'sound/weapons/guns/fire/M14.ogg'
	reload_sound = 'sound/weapons/guns/interact/AR15Reload.ogg'
	unload_sound = 'sound/weapons/guns/interact/AR15Unload.ogg'
	magazine_type = /obj/item/ammo_magazine/scarh
	good_mags = list(/obj/item/ammo_magazine/scarh)
	weight = 3.5
	equiptimer = 11
	effectiveness_mod = 1.05
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.2, move_delay=2, dispersion = list(0.2, 0.1, 0.3, 0.2, 0.3)),
		list(name = "full auto",	burst=1, burst_delay=1.2, move_delay=4, dispersion = list(1, 1.2, 1.5, 1.6, 1.7)),
		)
	effectiveness_mod = 1.06
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_ADV_SCOPE|ATTACH_UNDER
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 50,
			MEDIUM_RANGE_MOVING = 40,

			LONG_RANGE_STILL = 30,
			LONG_RANGE_MOVING = 15,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 82,
			SHORT_RANGE_MOVING = 72,

			MEDIUM_RANGE_STILL = 64,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 44,
			LONG_RANGE_MOVING = 31,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 91,
			SHORT_RANGE_MOVING = 81,

			MEDIUM_RANGE_STILL = 76,
			MEDIUM_RANGE_MOVING = 67,

			LONG_RANGE_STILL = 55,
			LONG_RANGE_MOVING = 43,

			VERY_LONG_RANGE_STILL = 36,
			VERY_LONG_RANGE_MOVING = 23),
	)
/obj/item/weapon/gun/projectile/submachinegun/ar12
	name = "AR-12"
	icon_state = "ar12"
	item_state = "ar12"
	base_icon = "ar12"
	desc = "An AR-15 style magazine fed shotgun in 12 gauge."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	caliber = "12gauge"
	fire_sound = 'sound/weapons/guns/fire/assault_rifle.ogg'
	magazine_type = /obj/item/ammo_magazine/ar12
	good_mags = list(/obj/item/ammo_magazine/ar12)
	weight = 3.5
	equiptimer = 11
	effectiveness_mod = 1.46
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.6, move_delay=2, dispersion = list(0.2, 0.1, 0.2, 0.3, 0.2)),
		list(name = "burst fire",	burst=3, burst_delay=1.5, move_delay=3, dispersion = list(0.9, 1.1, 1.2, 1.3, 1.3)),
		list(name = "full auto",	burst=1, burst_delay=1.2, move_delay=4, dispersion = list(1, 1.2, 1.5, 1.6, 1.7)),
		)
	effectiveness_mod = 1.60
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_ADV_SCOPE|ATTACH_UNDER
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 50,
			MEDIUM_RANGE_MOVING = 40,

			LONG_RANGE_STILL = 30,
			LONG_RANGE_MOVING = 15,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 82,
			SHORT_RANGE_MOVING = 72,

			MEDIUM_RANGE_STILL = 64,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 44,
			LONG_RANGE_MOVING = 31,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 91,
			SHORT_RANGE_MOVING = 81,

			MEDIUM_RANGE_STILL = 76,
			MEDIUM_RANGE_MOVING = 67,

			LONG_RANGE_STILL = 55,
			LONG_RANGE_MOVING = 43,

			VERY_LONG_RANGE_STILL = 36,
			VERY_LONG_RANGE_MOVING = 23),
	)
/obj/item/weapon/gun/projectile/submachinegun/hk417
	name = "HK417"
	desc = "A modern German battle rifle, chambered in 7.62x51mm."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "hk417"
	item_state = "hk417"
	base_icon = "hk417"
	caliber = "a762x51"
	fire_sound = 'sound/weapons/guns/fire/battle_rifle.ogg'
	magazine_type = /obj/item/ammo_magazine/scarh
	good_mags = list(/obj/item/ammo_magazine/scarh)
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL|ATTACH_ADV_SCOPE|ATTACH_UNDER
	weight = 3.8
	equiptimer = 13
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.6, move_delay=2, dispersion = list(0.1, 0.2, 0.1, 0.2, 0.3)),
		list(name = "burst fire",	burst=3, burst_delay=1.5, move_delay=3, dispersion = list(0.9, 1.2, 1.2, 1.3, 1.4)),
		list(name = "full auto",	burst=1, burst_delay=1.2, move_delay=4, dispersion = list(1, 1.3, 1.5, 1.8, 1.9)),
		)
	effectiveness_mod = 1.08
	sel_mode = 1
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 50,
			MEDIUM_RANGE_MOVING = 40,

			LONG_RANGE_STILL = 30,
			LONG_RANGE_MOVING = 15,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 82,
			SHORT_RANGE_MOVING = 72,

			MEDIUM_RANGE_STILL = 64,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 44,
			LONG_RANGE_MOVING = 31,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 91,
			SHORT_RANGE_MOVING = 81,

			MEDIUM_RANGE_STILL = 76,
			MEDIUM_RANGE_MOVING = 67,

			LONG_RANGE_STILL = 55,
			LONG_RANGE_MOVING = 43,

			VERY_LONG_RANGE_STILL = 36,
			VERY_LONG_RANGE_MOVING = 23),
	)
/obj/item/weapon/gun/projectile/submachinegun/p90
	name = "P90"
	desc = "A compact, rapid-fire defensive weapon, chambered in 5.7x28mm."
	icon_state = "p90"
	item_state = "p90"
	base_icon = "p90"
	caliber = "a57x28"
	fire_sound = 'sound/weapons/guns/fire/PDW.ogg'
	magazine_type = /obj/item/ammo_magazine/p90
	good_mags = list(/obj/item/ammo_magazine/p90)
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_ADV_SCOPE
	weight = 2.3
	equiptimer = 8
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.4, move_delay=1, dispersion = list(0.1, 0.3, 0.2, 0.2, 0.1)),
		list(name = "full auto",	burst=1, burst_delay=1.0, move_delay=3, dispersion = list(1, 1.2, 1.4, 1.6, 1.8)),
		)
	effectiveness_mod = 1.15
	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/victor
	name = "Kriss Vector"
	desc = "A compact gun using an unconventional delayed blowback system combined with in-line design to reduce perceived recoil and muzzle climb. It's chambered in 9mm"
	icon_state = "victor"
	item_state = "victor"
	base_icon = "victor"
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/pistol.ogg'
	magazine_type = /obj/item/ammo_magazine/glock17
	good_mags = list(/obj/item/ammo_magazine/glock17)
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_ADV_SCOPE
	weight = 3
	equiptimer = 4
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.4, move_delay=1, dispersion = list(0.1, 0.2, 0.3, 0.3, 0.2)),
		list(name = "burst fire",	burst=3, burst_delay=1.5, move_delay=2, dispersion = list(0.9, 1.2, 1.2, 1.3, 1.4)),
		list(name = "full auto",	burst=1, burst_delay=1.0, move_delay=3, dispersion = list(1, 1.2, 1.4, 1.6, 1.8)),
		)
	effectiveness_mod = 1.15
	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/qbz95
	name = "QBZ-95"
	icon_state = "qbz95"
	item_state = "qbz95"
	base_icon = "qbz95"
	desc = "A Chinese-designed bullup assault rifle, chambered in 5.8x42mm."
	icon = 'icons/obj/guns/wip.dmi'
	caliber = "a58x42"
	fire_sound = 'sound/weapons/guns/fire/M14.ogg'
	reload_sound = 'sound/weapons/guns/interact/AR15Reload.ogg'
	unload_sound = 'sound/weapons/guns/interact/AR15Unload.ogg'
	magazine_type = /obj/item/ammo_magazine/qbz95
	good_mags = list(/obj/item/ammo_magazine/qbz95)
	weight = 3.5
	equiptimer = 11
	effectiveness_mod = 1.05
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.6, move_delay=2, dispersion = list(0.1, 0.2, 0.3, 0.2, 0.2)),
		list(name = "full auto",	burst=1, burst_delay=1.2, move_delay=4, dispersion = list(1, 1.2, 1.5, 1.6, 1.7)),
		)
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_ADV_SCOPE|ATTACH_UNDER
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 50,
			MEDIUM_RANGE_MOVING = 40,

			LONG_RANGE_STILL = 30,
			LONG_RANGE_MOVING = 15,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 82,
			SHORT_RANGE_MOVING = 72,

			MEDIUM_RANGE_STILL = 64,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 44,
			LONG_RANGE_MOVING = 31,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 5),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 91,
			SHORT_RANGE_MOVING = 81,

			MEDIUM_RANGE_STILL = 76,
			MEDIUM_RANGE_MOVING = 67,

			LONG_RANGE_STILL = 55,
			LONG_RANGE_MOVING = 43,

			VERY_LONG_RANGE_STILL = 36,
			VERY_LONG_RANGE_MOVING = 23),
	)

/obj/item/weapon/gun/projectile/submachinegun/makeshiftak47
	name = "Makeshift AK-47"
	desc = "Looks like someone did a really bad job at \"UpGRaDinG\" their AK."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "makeshiftak"
	item_state = "makeshiftak"
	base_icon = "makeshiftak"
	caliber = "a762x39"
	fire_sound = 'sound/weapons/guns/fire/AKM.ogg'
	magazine_type = /obj/item/ammo_magazine/ak47/makeshift
	good_mags = list(/obj/item/ammo_magazine/ak47, /obj/item/ammo_magazine/ak47/makeshift)
	weight = 3.8
	equiptimer = 15
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.7, move_delay=4, dispersion = list(1.2, 1.2, 1.3, 1.4, 1.8)),
		)
	effectiveness_mod = 0.85
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL

/obj/item/weapon/gun/projectile/submachinegun/vz58
	name = "VZ-58"
	desc = "Czechoslovakian assault rifle chambered in 7.62x39mm."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "vz58"
	item_state = "vz58"
	base_icon = "vz58"
	caliber = "a762x39"
	fire_sound = 'sound/weapons/guns/fire/AKM.ogg'
	reload_sound = 'sound/weapons/guns/interact/AKReload.ogg'
	unload_sound = 'sound/weapons/guns/interact/AKUnload.ogg'
	magazine_type = /obj/item/ammo_magazine/ak47
	good_mags = list(/obj/item/ammo_magazine/ak47)
	weight = 2.93
	equiptimer = 12
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.8, move_delay=2, dispersion = list(0.2, 0.1, 0.2, 0.3, 0.1)),
		list(name = "full auto",	burst=1, burst_delay=1.3, move_delay=4, dispersion = list(1.2, 1.2, 1.3, 1.4, 1.8)),
		)
	effectiveness_mod = 1.20
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL

/obj/item/weapon/gun/projectile/submachinegun/vz58/white
	name = "White VZ-58"
	desc = "Czechoslovakian assault rifle chambered in 7.62x39mm. This model has a birch stock and handguard."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "white_vz58"
	item_state = "white_vz58"
	base_icon = "white_vz58"

/obj/item/weapon/gun/projectile/submachinegun/vz58/black
	name = "Black VZ-58"
	desc = "Czechoslovakian assault rifle chambered in 7.62x39mm. This model has a black stock and handguard."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "black_vz58"
	item_state = "black_vz58"
	base_icon = "black_vz58"

/obj/item/weapon/gun/projectile/submachinegun/c7
	name = "C7"
	desc = "A Canadian Colt C7 assault rifle, chambered in 5.56x45mm."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "c7"
	item_state = "c7"
	base_icon = "c7"
	caliber = "a556x45"
	fire_sound = 'sound/weapons/guns/fire/M4A1.ogg'
	magazine_type = /obj/item/ammo_magazine/m16
	good_mags = list(/obj/item/ammo_magazine/m16)
	weight = 2.98
	equiptimer = 13
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.1, recoil=0, move_delay=2, dispersion = list(0.1, 0, 0.1, 0.2, 0)),
		list(name = "full auto",	burst=1, burst_delay=1.1, recoil=0, move_delay=4, dispersion = list(1, 1.1, 1, 1, 0.9)),
		)
	effectiveness_mod = 1.20
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL|ATTACH_ADV_SCOPE|ATTACH_UNDER

/obj/item/weapon/gun/projectile/submachinegun/c7/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/advanced/elcan/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/elcan(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/submachinegun/c7/grenade_launcher/New()
	..()
	var/obj/item/weapon/gun/launcher/grenade/underslung/m203/GL = new/obj/item/weapon/gun/launcher/grenade/underslung/m203(src)
	GL.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/submachinegun/c7/c8
	name = "C8"
	desc = "A Canadian Colt C8 assault rifle, chambered in 5.56x45mm."
	equiptimer = 11
	effectiveness_mod = 1.23

/obj/item/weapon/gun/projectile/submachinegun/m2carbine
	name = "M2 carbine"
	desc = "An American Selective fire carbine using 7.62×33mm (Rimless.30 Carbine) ammunition in a external magazine."
	icon = 'icons/obj/guns/rifles.dmi'
	icon_state = "mcar"
	item_state = "mcar"
	base_icon = "mcar"
	caliber = "a762x33"
	fire_sound = 'sound/weapons/guns/fire/Garand.ogg'
	ammo_type = /obj/item/ammo_casing/a762x33
	magazine_type = /obj/item/ammo_magazine/m1carbine
	good_mags = list(/obj/item/ammo_magazine/m1carbine, /obj/item/ammo_magazine/m1carbine/big)
	weight = 3.4
	equiptimer = 11
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=1, recoil=0, move_delay=3, dispersion = list(0.2, 0.4, 0.4, 0.3, 0.2)),
		list(name = "full auto",	burst=1, burst_delay=2, recoil=0, move_delay=4, dispersion = list(1, 1.3, 1.5, 1.7, 1.8)),
		)
	effectiveness_mod = 1.07
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL

/obj/item/weapon/gun/projectile/submachinegun/srm
	name = "SR-3"
	desc = "Russian Compact Carbine chambered in 9x39mm,comes with a compact stock."
	slot_flags = SLOT_SHOULDER
	icon_state = "srm"
	item_state = "srm"
	base_icon = "srm"
	icon = 'icons/obj/guns/assault_rifles.dmi'
	caliber = "a9x39"
	ammo_type = /obj/item/ammo_casing/a9x39
	magazine_type = /obj/item/ammo_magazine/srm
	good_mags = list(/obj/item/ammo_magazine/srm,/obj/item/ammo_magazine/srm/srms,/obj/item/ammo_magazine/vintorez)
	equiptimer = 12
	var/folded = FALSE
	weight = 2
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=1, recoil=0, move_delay=2, dispersion = list(0.2, 0.3, 0.3, 0.4, 0.4)),
		list(name = "full auto",	burst=1, burst_delay=2, recoil=0, move_delay=3, dispersion = list(1, 1.2, 1.3, 1.4, 1.4)),
		)
	effectiveness_mod = 1.09
	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/srm/update_icon()
	if (folded)
		base_icon = "srm_folded"
	else
		base_icon = "srm"
	if (ammo_magazine)
		icon_state = base_icon
		item_state = base_icon
	else
		icon_state = "[base_icon]_open"
		item_state = "[base_icon]_open"
	update_held_icon()

	return

/obj/item/weapon/gun/projectile/submachinegun/srm/verb/fold()
	set name = "Toggle Stock"
	set category = null
	set src in usr
	if (folded)
		folded = FALSE
		base_icon = "srm"
		usr << "You extend the stock on \the [src]."
		equiptimer = 12
		set_stock()
		update_icon()
	else
		folded = TRUE
		base_icon = "srm_folded"
		usr << "You collapse the stock on \the [src]."
		equiptimer = 5
		set_stock()
		update_icon()

/obj/item/weapon/gun/projectile/submachinegun/srm/proc/set_stock()
	if (folded)
		slot_flags = SLOT_SHOULDER|SLOT_BELT
		effectiveness_mod = 0.95
	else
		slot_flags = SLOT_SHOULDER
		effectiveness_mod = 1.09