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
	w_class = 3
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS
	var/jammed_until = -1
	var/jamcheck = 0
	var/last_fire = -1
	reload_sound = 'sound/weapons/guns/interact/AR15Reload.ogg'
	unload_sound = 'sound/weapons/guns/interact/AR15Unload.ogg'

/obj/item/weapon/gun/projectile/submachinegun/special_check(mob/user)
	if (gun_safety && safetyon)
		user << "<span class='warning'>You can't fire \the [src] while the safety is on!</span>"
		return FALSE
	if (!user.has_empty_hand(both = FALSE))
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
	w_class = 4
	caliber = "a792x33"

	fire_sound = 'sound/weapons/guns/fire/stg.ogg'
	reload_sound = 'sound/weapons/guns/interact/stg_reload.ogg'
	magazine_type = /obj/item/ammo_magazine/stg
	weight = 4.6
	load_delay = 8
	equiptimer = 15
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.8, move_delay=2, dispersion = list(0.2, 0.3, 0.3, 0.4, 0.5)),
		list(name="full auto",	burst=1, burst_delay=1.5, move_delay=4, dispersion = list(1.2, 1.4, 1.4, 1.4, 1.7)),
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
	full_auto = TRUE
	equiptimer = 12
	firemodes = list(
		list(name="full auto",	burst=1.2, burst_delay=1.4, recoil=0, move_delay=5, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1
	effectiveness_mod = 1.05

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
	full_auto = TRUE
	slot_flags = SLOT_BELT|SLOT_SHOULDER
	equiptimer = 7
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=1.6, recoil=0, move_delay=5, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
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
	full_auto = TRUE
	slot_flags = SLOT_BELT|SLOT_SHOULDER
	equiptimer = 8
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=1.6, recoil=0, move_delay=5, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
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
	full_auto = TRUE
	slot_flags = SLOT_BELT|SLOT_SHOULDER
	equiptimer = 8
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=0.4, recoil=0, move_delay=3, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1
	effectiveness_mod = 3.03

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
	full_auto = TRUE
	equiptimer = 12
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=1.4, recoil=0, move_delay=5, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1
	effectiveness_mod = 1.04

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
	weight = 3.63
	equiptimer = 14
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.4, recoil=0, move_delay=1, dispersion = list(0.2, 0.4, 0.4, 0.4, 0.5)),
		list(name="full auto",	burst=1, burst_delay=1, recoil=0, move_delay=5, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1

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
	weight = 3.04
	equiptimer = 10
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=1, recoil=0, move_delay=5, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1

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
	weight = 3.47
	equiptimer = 15
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.8, recoil=0, move_delay=2, dispersion = list(0.3, 0.4, 0.5, 0.6, 0.7)),
		list(name="full auto",	burst=1, burst_delay=1.3, recoil=0, move_delay=4, dispersion = list(1.2, 1.2, 1.3, 1.4, 1.8)),
		)
	effectiveness_mod = 1
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL

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
	weight = 3.07
	equiptimer = 15
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.7, recoil=0, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.5, 0.6)),
		list(name="full auto",	burst=1, burst_delay=1.2, recoil=0, move_delay=4, dispersion = list(1.1, 1.2, 1.3, 1.3, 1.5)),
		)
	effectiveness_mod = 1.07
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL

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
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS

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
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_ADV_SCOPE|ATTACH_UNDER

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
	weight = 3.07
	equiptimer = 15
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.5, recoil=0, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.5, 0.6)),
		list(name="full auto",	burst=1, burst_delay=1.1, recoil=0, move_delay=4, dispersion = list(1, 1.3, 1.5, 1.7, 1.8)),
		)
	effectiveness_mod = 1.07
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL

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
	weight = 3.07
	equiptimer = 15
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.5, recoil=0, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.5, 0.6)),
		)
	effectiveness_mod = 1.12
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL

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
	weight = 3.07
	equiptimer = 9
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.5, recoil=0, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.5, 0.6)),
		list(name="full auto",	burst=1, burst_delay=1.1, recoil=0, move_delay=4, dispersion = list(1, 1.3, 1.5, 1.7, 1.8)),
		)
	effectiveness_mod = 1.08
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS

/obj/item/weapon/gun/projectile/submachinegun/m16/m16a4
	name = "M16A4"
	base_icon = "m16a4"
	icon_state = "m16a4"
	desc = "A modernized version of the M16, with a railed upper receiver and handguard."
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.5, recoil=0, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.5, 0.6)),
		list(name="burst fire",	burst=3, burst_delay=1.5, recoil=0, move_delay=3, dispersion = list(0.9, 1.1, 1.2, 1.3, 1.3)),
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
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_ADV_SCOPE|ATTACH_UNDER


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
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	weight = 3.6
	equiptimer = 15
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.6, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.5, 0.6)),
		list(name="full auto",	burst=1, burst_delay=1.2, move_delay=4, dispersion = list(1, 1.3, 1.5, 1.8, 1.9)),
		)
	effectiveness_mod = 1.07
	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/m14/sniper/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope(src)
	SP.attached(null,src,TRUE)

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
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
	weight = 4.2
	equiptimer = 15
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.6, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.4, 0.5)),
		list(name="full auto",	burst=1, burst_delay=1.2, move_delay=4, dispersion = list(1, 1.3, 1.5, 1.7, 1.7)),
		)
	effectiveness_mod = 1.07
	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/scarl
	name = "FN SCAR-L"
	desc = "A belgian assault rifle, chambered in 5.56x45mm."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "scarl"
	item_state = "scarl"
	base_icon = "scarl"
	caliber = "a556x45"
	fire_sound = 'sound/weapons/guns/fire/M4A1.ogg'
	reload_sound = 'sound/weapons/guns/interact/AR15Reload.ogg'
	unload_sound = 'sound/weapons/guns/interact/AR15Unload.ogg'
	magazine_type = /obj/item/ammo_magazine/m16
	weight = 3
	equiptimer = 10
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.5, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.5, 0.6)),
		list(name="full auto",	burst=1, burst_delay=1.3, move_delay=3, dispersion = list(0.8, 1, 1.1, 1.1, 1.2)),
		)
	effectiveness_mod = 1.08
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_ADV_SCOPE|ATTACH_UNDER

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
	weight = 3.5
	equiptimer = 11
	effectiveness_mod = 1.05
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.6, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.5, 0.6)),
		list(name="full auto",	burst=1, burst_delay=1.2, move_delay=4, dispersion = list(1, 1.2, 1.5, 1.6, 1.7)),
		)
	effectiveness_mod = 1.06
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_ADV_SCOPE|ATTACH_UNDER

/obj/item/weapon/gun/projectile/submachinegun/ar12
	name = "AR-12"
	icon_state = "ar12"
	item_state = "m16old"
	base_icon = "ar12"
	desc = "Something retarded that doesn't exist."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	caliber = "a762x51"
	fire_sound = 'sound/weapons/guns/fire/assault_rifle.ogg'
	magazine_type = /obj/item/ammo_magazine/scarh
	weight = 3.5
	equiptimer = 11
	effectiveness_mod = 1.46
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.6, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.5, 0.6)),
		list(name="burst fire",	burst=3, burst_delay=1.5, move_delay=3, dispersion = list(0.9, 1.1, 1.2, 1.3, 1.3)),
		list(name="full auto",	burst=1, burst_delay=1.2, move_delay=4, dispersion = list(1, 1.2, 1.5, 1.6, 1.7)),
		)
	effectiveness_mod = 1.60
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_ADV_SCOPE|ATTACH_UNDER

/obj/item/weapon/gun/projectile/submachinegun/hk417
	name = "HK417"
	desc = "A Modern German battle rifle, chambered in 7.62x51mm."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "hk417"
	item_state = "hk417"
	base_icon = "hk417"
	caliber = "a762x51"
	fire_sound = 'sound/weapons/guns/fire/battle_rifle.ogg'
	magazine_type = /obj/item/ammo_magazine/scarh
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL|ATTACH_ADV_SCOPE|ATTACH_UNDER
	weight = 3.8
	equiptimer = 13
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.6, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.4, 0.5)),
		list(name="burst fire",	burst=3, burst_delay=1.5, move_delay=3, dispersion = list(0.9, 1.2, 1.2, 1.3, 1.4)),
		list(name="full auto",	burst=1, burst_delay=1.2, move_delay=4, dispersion = list(1, 1.3, 1.5, 1.8, 1.9)),
		)
	effectiveness_mod = 1.08
	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/p90
	name = "P90"
	desc = "A compact, rapid-fire defensive weapon, chambered in 5.7x28mm."
	icon_state = "p90"
	item_state = "p90"
	base_icon = "p90"
	caliber = "a57x28"
	fire_sound = 'sound/weapons/guns/fire/PDW.ogg'
	magazine_type = /obj/item/ammo_magazine/p90
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_ADV_SCOPE
	weight = 2.3
	equiptimer = 8
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.4, move_delay=1, dispersion = list(0.2, 0.4, 0.4, 0.4, 0.5)),
		list(name="full auto",	burst=1, burst_delay=1.0, move_delay=3, dispersion = list(1, 1.2, 1.4, 1.6, 1.8)),
		)
	effectiveness_mod = 1.15
	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/victor
	name = "Kriss Vector"
	desc = "Placeholder description."
	icon_state = "victor"
	item_state = "victor"
	base_icon = "victor"
	caliber = "a9x19"
	fire_sound = 'sound/weapons/guns/fire/pistol.ogg'
	magazine_type = /obj/item/ammo_magazine/glock17
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_ADV_SCOPE
	weight = 3
	equiptimer = 4
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.4, move_delay=1, dispersion = list(0.2, 0.4, 0.4, 0.4, 0.5)),
		list(name="burst fire",	burst=3, burst_delay=1.5, move_delay=3, dispersion = list(0.9, 1.2, 1.2, 1.3, 1.4)),
		list(name="full auto",	burst=1, burst_delay=1.0, move_delay=3, dispersion = list(1, 1.2, 1.4, 1.6, 1.8)),
		)
	effectiveness_mod = 1.15
	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/makeshiftak47
	name = "Makeshift AK-47"
	desc = "Something retarded that doesn't exist."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "makeshiftak"
	item_state = "makeshiftak"
	base_icon = "makeshiftak"
	caliber = "a762x39"
	fire_sound = 'sound/weapons/guns/fire/AKM.ogg'
	magazine_type = /obj/item/ammo_magazine/ak47/makeshift
	weight = 3.8
	equiptimer = 15
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=1.7, move_delay=4, dispersion = list(1.2, 1.2, 1.3, 1.4, 1.8)),
		)
	effectiveness_mod = 0.85
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL

/obj/item/weapon/gun/projectile/submachinegun/bx7
	name = "BX-7 Rifle"
	desc = "Something retarded that doesn't exist. Also extremely overpowered."
	icon_state = "bx7"
	item_state = "bx7"
	base_icon = "bx7"
	caliber = "a50cal"
	fire_sound = 'sound/weapons/guns/fire/heavy_rifle.ogg'
	magazine_type = /obj/item/ammo_magazine/bx7
	weight = 4.0
	equiptimer = 10
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.8, move_delay=2, dispersion = list(0.3, 0.4, 0.5, 0.6, 0.7)),
		list(name="burst fire",	burst=3, burst_delay=1.4, move_delay=3, dispersion = list(1, 1.1, 1.1, 1.3, 1.5)),
		list(name="full auto",	burst=1, burst_delay=1.3, move_delay=4, dispersion = list(1.2, 1.2, 1.3, 1.4, 1.8)),
		)
	effectiveness_mod = 1
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL

/obj/item/weapon/gun/projectile/submachinegun/vz58
	name = "VZ-58"
	desc = "Czechoslovakian assault rifle chambered in 7.62x39mm."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "az58"
	item_state = "vz58"
	base_icon = "az58"
	caliber = "a762x39"
	fire_sound = 'sound/weapons/guns/fire/AKM.ogg'
	reload_sound = 'sound/weapons/guns/interact/AKReload.ogg'
	unload_sound = 'sound/weapons/guns/interact/AKUnload.ogg'
	magazine_type = /obj/item/ammo_magazine/ak47
	weight = 2.93
	equiptimer = 12
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.8, move_delay=2, dispersion = list(0.3, 0.4, 0.5, 0.6, 0.7)),
		list(name="full auto",	burst=1, burst_delay=1.3, move_delay=4, dispersion = list(1.2, 1.2, 1.3, 1.4, 1.8)),
		)
	effectiveness_mod = 1.20
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
