/obj/item/weapon/gun/projectile/special
	force = 10
	throwforce = 20
	fire_sound = 'sound/weapons/guns/fire/smg.ogg'
	base_icon = "tactical"
	icon = 'icons/obj/guns/assault_rifles.dmi'
	// more accuracy than MGs, less than everything else
	load_method = MAGAZINE
	slot_flags = SLOT_SHOULDER|SLOT_BELT
	equiptimer = 13
	gun_safety = TRUE
	load_delay = 8
	gun_type = GUN_TYPE_RIFLE
	gtype = "smg"

	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 1.50
	KD_chance = KD_CHANCE_HIGH+5
	stat = "machinegun"
	w_class = ITEM_SIZE_NORMAL
	attachment_slots = ATTACH_IRONSIGHTS
	var/jammed_until = -1
	var/jamcheck = 0
	var/last_fire = -1
	barrel_x_offset = 16
	barrel_y_offset = 16
	can_tactical_reload = TRUE

/obj/item/weapon/gun/projectile/special/special_check(mob/user)
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

/obj/item/weapon/gun/projectile/special/mk18
	name = "MK-18"
	desc = "An american automatic rifle."
	icon_state = "mk18"
	item_state = "mk18"
	base_icon = "mk18"
	weight = 3.97
	caliber = "a556x45"
	fire_sound = 'sound/weapons/guns/fire/assault_rifle.ogg'
	magazine_type = /obj/item/ammo_magazine/mk18
	good_mags = list(/obj/item/ammo_magazine/mk18)
	full_auto = TRUE
	equiptimer = 12
	firemodes = list(
		list(name = "semi auto", burst=1, burst_delay=0.8),
		list(name = "burst fire", burst=3, burst_delay=1.4),
		list(name = "full auto", burst=1, burst_delay=1.3),
		)
	sel_mode = 1
	accuracy = 1
	recoil = 20
	scope_mounts = list ("picatinny")
	under_mounts = list ("picatinny")
	mag_x_offset = 4
	mag_y_offset = 2

/obj/item/weapon/gun/projectile/special/mk18/tan
	icon_state = "mk18tan"
	base_icon = "mk18tan"

/obj/item/weapon/gun/projectile/special/ak74mtactical
	name = "Tactical AK-74M"
	desc = "A russian tactical rifle used by the Spetsnaz."
	icon_state = "ak74mtactical"
	item_state = "ak74mtactical"
	base_icon = "ak74mtactical"
	weight = 3.97
	caliber = "a545x39"
	fire_sound = 'sound/weapons/guns/fire/assault_rifle.ogg'
	magazine_type = /obj/item/ammo_magazine/ak74
	good_mags = list(/obj/item/ammo_magazine/rpk74, /obj/item/ammo_magazine/rpk74/drum, /obj/item/ammo_magazine/ak74, /obj/item/ammo_magazine/ak74/ak74m)
	full_auto = TRUE
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_UNDER|ATTACH_BARREL
	equiptimer = 12
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.8),
		list(name = "burst fire",	burst=3, burst_delay=0.8),
		list(name = "full auto",	burst=1, burst_delay=0.8),
		)
	sel_mode = 1
	accuracy = 1
	recoil = 20
	scope_x_offset = -1
	scope_y_offset = -1
	scope_mounts = list ("dovetail", "picatinny")
	under_mounts = list ("picatinny", "gp25_mount")
