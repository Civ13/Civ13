/obj/item/weapon/gun/projectile/submachinegun
	force = 10
	throwforce = 20
	fire_sound = 'sound/weapons/smg.ogg'
	var/base_icon = "smg"
	// more accuracy than MGs, less than everything else
	load_method = MAGAZINE
	slot_flags = SLOT_BACK|SLOT_BELT
	equiptimer = 12
	gun_safety = TRUE
	load_delay = 8
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 49,
			SHORT_RANGE_MOVING = 39,

			MEDIUM_RANGE_STILL = 39,
			MEDIUM_RANGE_MOVING = 31,

			LONG_RANGE_STILL = 14,
			LONG_RANGE_MOVING = 11,

			VERY_LONG_RANGE_STILL = 7,
			VERY_LONG_RANGE_MOVING = 6),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 59,
			SHORT_RANGE_MOVING = 47,

			MEDIUM_RANGE_STILL = 39,
			MEDIUM_RANGE_MOVING = 31,

			LONG_RANGE_STILL = 16,
			LONG_RANGE_MOVING = 13,

			VERY_LONG_RANGE_STILL = 9,
			VERY_LONG_RANGE_MOVING = 7),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 79,
			SHORT_RANGE_MOVING = 63,

			MEDIUM_RANGE_STILL = 59,
			MEDIUM_RANGE_MOVING = 47,

			LONG_RANGE_STILL = 39,
			LONG_RANGE_MOVING = 31,

			VERY_LONG_RANGE_STILL = 16,
			VERY_LONG_RANGE_MOVING = 13),
	)

	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 2.00
	KD_chance = KD_CHANCE_VERY_LOW
	stat = "mg"
	w_class = 3
	attachment_slots = ATTACH_IRONSIGHTS
	var/jammed_until = -1
	var/jamcheck = 0
	var/last_fire = -1

/obj/item/weapon/gun/projectile/submachinegun/special_check(mob/user)
	if (!user.has_empty_hand(both = FALSE))
		user << "<span class='warning'>You need both hands to fire \the [src]!</span>"
		return FALSE
	if (jammed_until > world.time)
		user << "<span class = 'danger'>\The [src] has jammed! You can't fire it until it has unjammed.</span>"
		return FALSE
	return TRUE

/obj/item/weapon/gun/projectile/submachinegun/handle_post_fire()
	..()

	if (world.time - last_fire > 50)
		jamcheck = 0
	else
		++jamcheck

	if (prob(jamcheck/2))
		jammed_until = max(world.time + (jamcheck * 5), 50)
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

/obj/item/weapon/gun/projectile/submachinegun/New()
	..()
	loaded = list()
	chambered = null

/obj/item/weapon/gun/projectile/submachinegun/mp40
	name = "MP40"
	desc = "German submachinegun chambered in 9x19 Parabellum, with a 32 magazine magazine layout. Standard issue amongst most troops."
	icon_state = "mp40"
	item_state = "mp40"
	base_icon = "mp40"
	weight = 3.97
	caliber = "a9x19"
	fire_sound = 'sound/weapons/mp40.ogg'
	magazine_type = /obj/item/ammo_magazine/mp40
	full_auto = TRUE
	equiptimer = 12
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=1.4, recoil=1, move_delay=5, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1
	effectiveness_mod = 1.05

/obj/item/weapon/gun/projectile/submachinegun/greasegun
	name = "M3A1 \"grease gun\""
	desc = "An american light SMG, used by support troops."
	icon_state = "greasegun"
	item_state = "greasegun"
	base_icon = "greasegun"
	weight = 3.6
	caliber = "a45acp"
	fire_sound = 'sound/weapons/mp40.ogg'
	magazine_type = /obj/item/ammo_magazine/greasegun
	full_auto = TRUE
	slot_flags = SLOT_BELT
	equiptimer = 7
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=1.6, recoil=1, move_delay=5, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1
	effectiveness_mod = 1.05

/obj/item/weapon/gun/projectile/submachinegun/ppsh
	name = "PPSh-41"
	desc = "Soviet submachinegun with a very large drum magazine. Chambered in 7.62x25mm Tokarev."
	icon_state = "ppsh"
	item_state = "ppsh"
	base_icon = "ppsh"
	caliber = "a762x25"
	magazine_type = /obj/item/ammo_magazine/c762x25_ppsh
	weight = 3.63
	equiptimer = 14
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.7, recoil=0.4, move_delay=2, dispersion = list(0.5, 0.7, 0.7, 0.7, 0.9)),
		list(name="full auto",	burst=1, burst_delay=1.2, recoil=1, move_delay=5, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/pps
	name = "PPS-43"
	desc = "Soviet submachine gun chambered in 7.62x25mm Tokarev."
	icon_state = "pps"
	item_state = "pps"
	base_icon = "pps"
	caliber = "a762x25"
	full_auto = TRUE
	magazine_type = /obj/item/ammo_magazine/c762x25_pps
	weight = 3.04
	equiptimer = 10
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=1, recoil=1, move_delay=5, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/ak47
	name = "AK-47"
	desc = "Soviet assault rifle chambered in 7.62x39mm."
	icon_state = "ak47"
	item_state = "ak47"
	base_icon = "ak47"
	caliber = "a762x39"
	fire_sound = 'sound/weapons/mosin_shot.ogg'
	magazine_type = /obj/item/ammo_magazine/ak47
	weight = 3.47
	equiptimer = 15
	slot_flags = SLOT_BACK
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.8, recoil=0.7, move_delay=2, dispersion = list(0.3, 0.4, 0.5, 0.6, 0.7)),
		list(name="burst fire",	burst=3, burst_delay=1.4, recoil=0.9, move_delay=3, dispersion = list(1, 1.1, 1.1, 1.3, 1.5)),
		list(name="full auto",	burst=1, burst_delay=1.3, recoil=1.3, move_delay=4, dispersion = list(1.2, 1.2, 1.3, 1.4, 1.8)),
		)
	effectiveness_mod = 1
	sel_mode = 1
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL

/obj/item/weapon/gun/projectile/submachinegun/ak74
	name = "AK-74"
	desc = "Soviet assault rifle chambered in 5.45x39mm."
	icon_state = "ak74"
	item_state = "ak74"
	base_icon = "ak74"
	caliber = "a545x39"
	fire_sound = 'sound/weapons/mosin_shot.ogg'
	magazine_type = /obj/item/ammo_magazine/ak74
	weight = 3.07
	equiptimer = 15
	slot_flags = SLOT_BACK
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.7, recoil=0.5, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.5, 0.6)),
		list(name="burst fire",	burst=3, burst_delay=1.4, recoil=0.9, move_delay=3, dispersion = list(0.8, 1, 1.1, 1.1, 1.2)),
		list(name="full auto",	burst=1, burst_delay=1.2, recoil=1, move_delay=4, dispersion = list(1.1, 1.2, 1.3, 1.3, 1.5)),
		)
	effectiveness_mod = 1.07
	sel_mode = 1
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL

/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74
	name = "AKS-74"
	desc = "Soviet assault rifle chambered in 5.45x39mm, with a folding stock."
	slot_flags = SLOT_BACK
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
	..()

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
		slot_flags = SLOT_BACK|SLOT_BELT
		effectiveness_mod = 0.87
	else
		slot_flags = SLOT_BACK
		effectiveness_mod = 1.05

/obj/item/weapon/gun/projectile/submachinegun/m16
	name = "M16"
	desc = "An american assault rifle, chambered in 5.56x45mm."
	icon_state = "m16"
	item_state = "m16"
	base_icon = "m16"
	caliber = "a556x45"
	fire_sound = 'sound/weapons/mosin_shot.ogg'
	magazine_type = /obj/item/ammo_magazine/m16
	weight = 3.07
	equiptimer = 15
	slot_flags = SLOT_BACK
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.5, recoil=0.5, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.5, 0.6)),
		list(name="burst fire",	burst=3, burst_delay=1.4, recoil=0.9, move_delay=3, dispersion = list(0.8, 1, 1.1, 1.1, 1.2)),
		)
	effectiveness_mod = 1.07
	sel_mode = 1
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL

/obj/item/weapon/gun/projectile/submachinegun/m14
	name = "M14"
	desc = "An american assault rifle, chambered in 7.62x51mm."
	icon_state = "m14"
	item_state = "m14"
	base_icon = "m14"
	caliber = "a762x51"
	fire_sound = 'sound/weapons/kar_shot.ogg'
	magazine_type = /obj/item/ammo_magazine/m14
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	weight = 3.6
	equiptimer = 15
	slot_flags = SLOT_BACK
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.6, recoil=0.7, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.5, 0.6)),
		list(name="full auto",	burst=1, burst_delay=1.2, recoil=1.3, move_delay=3, dispersion = list(1, 1.3, 1.5, 1.8, 1.9)),
		)
	effectiveness_mod = 1.07
	sel_mode = 1