//all bolt-action weapons

/obj/item/weapon/gun/projectile/boltaction
	name = "bolt-action rifle"
	desc = "A bolt-action rifle of true ww2 (You shouldn't be seeing this)"
	icon = 'icons/obj/rifles.dmi'
	icon_state = "mosin"
	item_state = "mosin" //placeholder
	w_class = 4
	force = 10
	throwforce = 20
	max_shells = 5
	slot_flags = SLOT_BACK
	caliber = "a792x54"
	recoil = 2 //extra kickback
	//fire_sound = 'sound/weapons/sniper.ogg'
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	ammo_type = /obj/item/ammo_casing/projectile/a792x54
	magazine_type = /obj/item/ammo_magazine/projectile/mosin
	load_shell_sound = 'sound/weapons/clip_reload.ogg'
	//+2 accuracy over the LWAP because only one shot
	accuracy = TRUE
//	scoped_accuracy = 2
	gun_type = GUN_TYPE_RIFLE
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	accuracy_increase_mod = 2.00
	accuracy_decrease_mod = 6.00
	KD_chance = KD_CHANCE_HIGH
	stat = "rifle"
	move_delay = 2
	fire_delay = 2

	// 5x as accurate as MGs for now
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 87,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 77,
			MEDIUM_RANGE_MOVING = 47,

			LONG_RANGE_STILL = 63,
			LONG_RANGE_MOVING = 37,

			VERY_LONG_RANGE_STILL = 56,
			VERY_LONG_RANGE_MOVING = 30),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 88,
			SHORT_RANGE_MOVING = 44,

			MEDIUM_RANGE_STILL = 78,
			MEDIUM_RANGE_MOVING = 39,

			LONG_RANGE_STILL = 68,
			LONG_RANGE_MOVING = 34,

			VERY_LONG_RANGE_STILL = 58,
			VERY_LONG_RANGE_MOVING = 29),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 98,
			SHORT_RANGE_MOVING = 49,

			MEDIUM_RANGE_STILL = 90,
			MEDIUM_RANGE_MOVING = 50,

			LONG_RANGE_STILL = 77,
			LONG_RANGE_MOVING = 38,

			VERY_LONG_RANGE_STILL = 69,
			VERY_LONG_RANGE_MOVING = 31),
	)

	load_delay = 4
	aim_miss_chance_divider = 3.00

	var/bolt_open = FALSE
	var/check_bolt = FALSE //Keeps the bolt from being interfered with
	var/check_bolt_lock = FALSE //For locking the bolt. Didn't put this in with check_bolt to avoid issues
	var/bolt_safety = FALSE //If true, locks the bolt when gun is empty
	var/next_reload = -1
	var/jammed_until = -1
	var/jamcheck = 0
	var/last_fire = -1

/obj/item/weapon/gun/projectile/boltaction/attack_self(mob/user)
	if (!check_bolt)//Keeps people from spamming the bolt
		check_bolt++
		if (!do_after(user, 2, src, FALSE, TRUE, INCAPACITATION_DEFAULT, TRUE))//Delays the bolt
			check_bolt--
			return
	else return
	if (check_bolt_lock)
		user << "<span class='notice'>The bolt won't move, the gun is empty!</span>"
		check_bolt--
		return
	bolt_open = !bolt_open
	if (bolt_open)
		if (chambered)
			playsound(loc, 'sound/weapons/bolt_open.ogg', 50, TRUE)
			user << "<span class='notice'>You work the bolt open, ejecting [chambered]!</span>"
			chambered.loc = get_turf(src)
			loaded -= chambered
			chambered = null
			if (bolt_safety)
				if (!loaded.len)
					check_bolt_lock++
					user << "<span class='notice'>The bolt is locked!</span>"
		else
			playsound(loc, 'sound/weapons/bolt_open.ogg', 50, TRUE)
			user << "<span class='notice'>You work the bolt open.</span>"
	else
		playsound(loc, 'sound/weapons/bolt_close.ogg', 50, TRUE)
		user << "<span class='notice'>You work the bolt closed.</span>"
		bolt_open = FALSE
	add_fingerprint(user)
	update_icon()
	check_bolt--

/obj/item/weapon/gun/projectile/boltaction/special_check(mob/user)
	if (bolt_open)
		user << "<span class='warning'>You can't fire [src] while the bolt is open!</span>"
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/boltaction/load_ammo(var/obj/item/A, mob/user)
	if (!bolt_open)
		return
	if (check_bolt_lock)
		--check_bolt_lock // preincrement is superior
	..()

/obj/item/weapon/gun/projectile/boltaction/unload_ammo(mob/user, var/allow_dump=1)
	if (!bolt_open)
		return
	..()

/obj/item/weapon/gun/projectile/boltaction/handle_post_fire()
	..()

	if (last_fire != -1)
		if (world.time - last_fire <= 7)
			jamcheck += 4
		else if (world.time - last_fire <= 10)
			jamcheck += 3
		else if (world.time - last_fire <= 20)
			jamcheck += 2
		else if (world.time - last_fire <= 30)
			++jamcheck
		else if (world.time - last_fire <= 40)
			++jamcheck
		else if (world.time - last_fire <= 50)
			++jamcheck
		else
			jamcheck = 0
	else
		++jamcheck

	if (prob(jamcheck))
		jammed_until = max(world.time + (jamcheck * 5), 50)
		jamcheck = 0

	last_fire = world.time

/obj/item/weapon/gun/projectile/boltaction/mosin
	name = "Mosin-Nagant"
	desc = "Soviet bolt-action rifle chambered in 7.92x54mmR cartridges."
	icon = 'icons/obj/rifles.dmi'
	icon_state ="mosin"
	item_state ="mosin"
	force = 12
	fire_sound = 'sound/weapons/mosin_shot.ogg'
	caliber = "a792x54"
	weight = 4.0
	effectiveness_mod = 0.97
	bolt_safety = FALSE
	value = 100
	recoil = 2
	slot_flags = SLOT_BACK
	throwforce = 20
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	ammo_type = /obj/item/ammo_casing/projectile/a792x54
	magazine_type = /obj/item/ammo_magazine/projectile/mosin
	load_shell_sound = 'sound/weapons/clip_reload.ogg'

	//This should only be temporary until more attachment icons are made, then we switch to adding/removing icon masks
/obj/item/weapon/gun/projectile/boltaction/mosin/update_icon(var/add_scope = FALSE)
	if (add_scope)
		if (bolt_open)
			icon_state = "mosin_open"
			item_state = "mosin"
			return
		else
			icon_state = "mosin"
			item_state = "mosin"
			return
	if (bolt_open)
		if (!findtext(icon_state, "_open"))
			icon_state = addtext(icon_state, "_open") //open
	else if (icon_state == "mosin_open") //closed
		icon_state = "mosin"
	else if (icon_state == "mosin")
		return
	else
		icon_state = "mosin"



/obj/item/weapon/gun/projectile/boltaction/arisaka30
	name = "Arisaka Type 30"
	desc = "Japanese bolt-action rifle chambered in 6.50x50mm Arisaka ammunition."
	icon = 'icons/obj/rifles.dmi'
	icon_state = "arisaka30"
	item_state = "arisaka30"
	caliber = "a65x50mm"
	weight = 3.8
	fire_sound = 'sound/weapons/kar_shot.ogg'
	ammo_type = /obj/item/ammo_casing/projectile/a65x50mm
	magazine_type = /obj/item/ammo_magazine/projectile/arisaka
	bolt_safety = FALSE
	effectiveness_mod = 0.96
	value = 100
	slot_flags = SLOT_BACK
	recoil = 2
	force = 12
	throwforce = 20
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/clip_reload.ogg'

/obj/item/weapon/gun/projectile/boltaction/arisaka30/update_icon(var/add_scope = FALSE)
	if (bolt_open)
		if (!findtext(icon_state, "_open"))
			icon_state = addtext(icon_state, "_open") //open
	else if (icon_state == "arisaka30_open") //closed
		icon_state = "arisaka30"
	else if (icon_state == "arisaka30")
		return
	else
		icon_state = "arisaka30"


/obj/item/weapon/gun/projectile/boltaction/arisaka35
	name = "Arisaka Type 35"
	desc = "Japanese bolt-action rifle chambered in 6.50x50mm Arisaka ammunition."
	icon = 'icons/obj/rifles.dmi'
	icon_state = "arisaka35"
	item_state = "arisaka35"
	caliber = "a65x50mm"
	weight = 3.8
	fire_sound = 'sound/weapons/kar_shot.ogg'
	ammo_type = /obj/item/ammo_casing/projectile/a65x50mm
	bolt_safety = FALSE
	effectiveness_mod = 1.00
	value = 120
	slot_flags = SLOT_BACK
	recoil = 2
	force = 12
	throwforce = 20
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	magazine_type = /obj/item/ammo_magazine/projectile/arisaka
	load_shell_sound = 'sound/weapons/clip_reload.ogg'

/obj/item/weapon/gun/projectile/boltaction/arisaka35/update_icon(var/add_scope = FALSE)
	if (bolt_open)
		if (!findtext(icon_state, "_open"))
			icon_state = addtext(icon_state, "_open") //open
	else if (icon_state == "arisaka35_open") //closed
		icon_state = "arisaka35"
	else if (icon_state == "arisaka35")
		return
	else
		icon_state = "arisaka35"


/obj/item/weapon/gun/projectile/murata
	name = "bolt-action rifle"
	desc = "A bolt-action rifle of true ww2 (You shouldn't be seeing this)"
	icon = 'icons/obj/rifles.dmi'
	icon_state = "mosin"
	item_state = "mosin" //placeholder
	w_class = 4
	force = 10
	throwforce = 20
	max_shells = 8
	slot_flags = SLOT_BACK
	caliber = "a792x54"
	recoil = 2 //extra kickback
	//fire_sound = 'sound/weapons/sniper.ogg'
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	ammo_type = /obj/item/projectile/bullet/rifle/a792x54
	magazine_type = /obj/item/ammo_magazine/projectile/mosin
	load_shell_sound = 'sound/weapons/clip_reload.ogg'
	//+2 accuracy over the LWAP because only one shot
	accuracy = TRUE
//	scoped_accuracy = 2
	gun_type = GUN_TYPE_RIFLE
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	accuracy_increase_mod = 2.00
	accuracy_decrease_mod = 6.00
	KD_chance = KD_CHANCE_HIGH
	stat = "rifle"
	move_delay = 2
	fire_delay = 2

	// 5x as accurate as MGs for now
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 87,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 77,
			MEDIUM_RANGE_MOVING = 47,

			LONG_RANGE_STILL = 63,
			LONG_RANGE_MOVING = 37,

			VERY_LONG_RANGE_STILL = 56,
			VERY_LONG_RANGE_MOVING = 30),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 88,
			SHORT_RANGE_MOVING = 44,

			MEDIUM_RANGE_STILL = 78,
			MEDIUM_RANGE_MOVING = 39,

			LONG_RANGE_STILL = 68,
			LONG_RANGE_MOVING = 34,

			VERY_LONG_RANGE_STILL = 58,
			VERY_LONG_RANGE_MOVING = 29),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 98,
			SHORT_RANGE_MOVING = 49,

			MEDIUM_RANGE_STILL = 90,
			MEDIUM_RANGE_MOVING = 50,

			LONG_RANGE_STILL = 77,
			LONG_RANGE_MOVING = 38,

			VERY_LONG_RANGE_STILL = 69,
			VERY_LONG_RANGE_MOVING = 31),
	)

	load_delay = 4
	aim_miss_chance_divider = 3.00

	var/bolt_open = FALSE
	var/check_bolt = FALSE //Keeps the bolt from being interfered with
	var/check_bolt_lock = FALSE //For locking the bolt. Didn't put this in with check_bolt to avoid issues
	var/bolt_safety = FALSE //If true, locks the bolt when gun is empty
	var/next_reload = -1
	var/jammed_until = -1
	var/jamcheck = 0
	var/last_fire = -1

/obj/item/weapon/gun/projectile/murata/attack_self(mob/user)
	if (!check_bolt)//Keeps people from spamming the bolt
		check_bolt++
		if (!do_after(user, 2, src, FALSE, TRUE, INCAPACITATION_DEFAULT, TRUE))//Delays the bolt
			check_bolt--
			return
	else return
	if (check_bolt_lock)
		user << "<span class='notice'>The bolt won't move, the gun is empty!</span>"
		check_bolt--
		return
	bolt_open = !bolt_open
	if (bolt_open)
		if (chambered)
			playsound(loc, 'sound/weapons/bolt_open.ogg', 50, TRUE)
			user << "<span class='notice'>You work the bolt open, ejecting [chambered]!</span>"
			chambered.loc = get_turf(src)
			loaded -= chambered
			chambered = null
			if (bolt_safety)
				if (!loaded.len)
					check_bolt_lock++
					user << "<span class='notice'>The bolt is locked!</span>"
		else
			playsound(loc, 'sound/weapons/bolt_open.ogg', 50, TRUE)
			user << "<span class='notice'>You work the bolt open.</span>"
	else
		playsound(loc, 'sound/weapons/bolt_close.ogg', 50, TRUE)
		user << "<span class='notice'>You work the bolt closed.</span>"
		bolt_open = FALSE
	add_fingerprint(user)
	update_icon()
	check_bolt--

/obj/item/weapon/gun/projectile/murata/special_check(mob/user)
	if (bolt_open)
		user << "<span class='warning'>You can't fire [src] while the bolt is open!</span>"
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/murata/load_ammo(var/obj/item/A, mob/user)
	if (!bolt_open)
		return
	if (check_bolt_lock)
		--check_bolt_lock // preincrement is superior
	..()

/obj/item/weapon/gun/projectile/murata/unload_ammo(mob/user, var/allow_dump=1)
	if (!bolt_open)
		return
	..()

/obj/item/weapon/gun/projectile/murata/handle_post_fire()
	..()

	if (last_fire != -1)
		if (world.time - last_fire <= 7)
			jamcheck += 4
		else if (world.time - last_fire <= 10)
			jamcheck += 3
		else if (world.time - last_fire <= 20)
			jamcheck += 2
		else if (world.time - last_fire <= 30)
			++jamcheck
		else if (world.time - last_fire <= 40)
			++jamcheck
		else if (world.time - last_fire <= 50)
			++jamcheck
		else
			jamcheck = 0
	else
		++jamcheck

	if (prob(jamcheck))
		jammed_until = max(world.time + (jamcheck * 5), 50)
		jamcheck = 0

	last_fire = world.time

/obj/item/weapon/gun/projectile/murata/murata
	name = "Type-22 Murata"
	desc = "Japanese bolt-action rifle chambered in 6.50x50mm Arisaka ammunition."
	icon = 'icons/obj/rifles.dmi'
	icon_state = "murata"
	item_state = "murata"
	caliber = "a65x50mm"
	weight = 3.8
	fire_sound = 'sound/weapons/kar_shot.ogg'
	ammo_type = /obj/item/ammo_casing/projectile/a65x50mm
	bolt_safety = FALSE
	effectiveness_mod = 0.93
	value = 120
	slot_flags = SLOT_BACK
	recoil = 2
	force = 12
	throwforce = 20
	max_shells = 8
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	magazine_type = /obj/item/ammo_magazine/projectile/arisaka
	load_shell_sound = 'sound/weapons/clip_reload.ogg'