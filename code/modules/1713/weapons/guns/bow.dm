/obj/item/weapon/gun/projectile/bow
	name = "primitive bow"
	icon = 'icons/obj/guns/bows.dmi'
	desc = "A simple and crude bow."
	icon_state = "bow0"
	item_state = "bow0"
	w_class = ITEM_SIZE_LARGE
	throw_range = 5
	throw_speed = 5
	force = 6
	throwforce = 6
	max_shells = 1 //duh
	slot_flags = SLOT_SHOULDER
	caliber = "arrow"
	recoil = 0 //no shaking
	fire_sound = 'sound/weapons/arrow_fly.ogg'
	handle_casings = REMOVE_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/arrow
	load_shell_sound = 'sound/weapons/pull_bow.ogg'
	bulletinsert_sound = 'sound/weapons/pull_bow.ogg'
	//+2 accuracy over the LWAP because only one shot
	accuracy = TRUE
	gun_type = GUN_TYPE_BOW
	attachment_slots = null
	accuracy_increase_mod = 3.00
	accuracy_decrease_mod = 7.00
	KD_chance = KD_CHANCE_HIGH
	stat = "bows"
	move_delay = 5
	fire_delay = 5
	muzzle_flash = FALSE
	value = 10
	flammable = TRUE
	var/projtype = "arrow"
	var/icotype = "bow"
	equiptimer = 20
	gtype = "none"
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 90,
			SHORT_RANGE_MOVING = 55,

			MEDIUM_RANGE_STILL = 80,
			MEDIUM_RANGE_MOVING = 40,

			LONG_RANGE_STILL = 63,
			LONG_RANGE_MOVING = 32,

			VERY_LONG_RANGE_STILL = 50,
			VERY_LONG_RANGE_MOVING = 25),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 95,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 79,
			MEDIUM_RANGE_MOVING = 39,

			LONG_RANGE_STILL = 68,
			LONG_RANGE_MOVING = 34,

			VERY_LONG_RANGE_STILL = 58,
			VERY_LONG_RANGE_MOVING = 29),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 99,
			SHORT_RANGE_MOVING = 54,

			MEDIUM_RANGE_STILL = 83,
			MEDIUM_RANGE_MOVING = 42,

			LONG_RANGE_STILL = 73,
			LONG_RANGE_MOVING = 37,

			VERY_LONG_RANGE_STILL = 63,
			VERY_LONG_RANGE_MOVING = 32),
	)

	load_delay = 30
	aim_miss_chance_divider = 3.00

/obj/item/weapon/gun/projectile/bow/shortbow
	name = "shortbow"
	desc = "A short bow with a light draw weight."
	icon_state = "shortbow0"
	item_state = "shortbow0"
	icotype = "shortbow"
	throw_range = 6
	throw_speed = 2
	force = 6
	throwforce = 6
	max_shells = 1 //duh
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	caliber = "arrow"
	ammo_type = /obj/item/ammo_casing/arrow
	accuracy = TRUE
	gun_type = GUN_TYPE_BOW
	attachment_slots = null
	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 1.00
	stat = "bow"
	move_delay = 5
	fire_delay = 8
	muzzle_flash = FALSE
	value = 15
	flammable = TRUE
	load_delay = 10
	projtype = "arrow"
	w_class = ITEM_SIZE_NORMAL


/obj/item/weapon/gun/projectile/bow/longbow
	name = "longbow"
	desc = "A long bow with a heavy draw weight."
	icon_state = "longbow0"
	item_state = "longbow0"
	icotype = "longbow"
	throw_range = 6
	throw_speed = 2
	force = 8
	throwforce = 6
	max_shells = 1 //duh
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	caliber = "arrow"
	ammo_type = /obj/item/ammo_casing/arrow
	accuracy = TRUE
	gun_type = GUN_TYPE_BOW
	attachment_slots = null
	accuracy_increase_mod = 1.25
	accuracy_decrease_mod = 1.00
	stat = "bow"
	move_delay = 7
	fire_delay = 10
	muzzle_flash = FALSE
	value = 15
	flammable = TRUE
	load_delay = 12
	projtype = "arrow"

/obj/item/weapon/gun/projectile/bow/compoundbow
	name = "compound bow"
	desc = "A compound bow with a decent draw weight."
	icon_state = "compoundbow0"
	item_state = "compoundbow0"
	icotype = "compoundbow"
	throw_range = 6
	throw_speed = 2
	force = 12
	throwforce = 6
	max_shells = 1 //duh
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	caliber = "arrow"
	ammo_type = /obj/item/ammo_casing/arrow
	accuracy = TRUE
	gun_type = GUN_TYPE_BOW
	attachment_slots = null
	accuracy_increase_mod = 1.35
	accuracy_decrease_mod = 0.85
	stat = "bow"
	move_delay = 5
	fire_delay = 7
	muzzle_flash = FALSE
	value = 15
	flammable = TRUE
	load_delay = 8
	projtype = "arrow"

/obj/item/weapon/gun/projectile/bow/proc/remove_arrow_overlay()
	src.overlays = null

/obj/item/weapon/gun/projectile/bow/proc/load_arrow_overlay(var/obj/item/ammo_casing/arrow/A as obj)
	//remove all overlays
	remove_arrow_overlay()
	//add arrow overlay
	src.overlays += icon(A.icon,A.icon_state)

obj/item/weapon/gun/projectile/bow/Fire()
	..()
	remove_arrow_overlay()

/obj/item/weapon/gun/projectile/bow/sling
	name = "sling"
	desc = "A simple leather sling."
	icon_state = "sling0"
	item_state = "sling0"
	icotype = "sling"
	w_class = ITEM_SIZE_TINY
	throw_range = 6
	throw_speed = 2
	force = 6
	throwforce = 6
	max_shells = 1 //duh
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	caliber = "stone"
	ammo_type = /obj/item/ammo_casing/stone
	accuracy = TRUE
	gun_type = GUN_TYPE_BOW
	attachment_slots = null
	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 1.00
	stat = "strength"
	move_delay = 5
	fire_delay = 8
	muzzle_flash = FALSE
	value = 15
	flammable = TRUE
	load_delay = 10
	projtype = "stone"

/obj/item/weapon/gun/projectile/bow/New()
	..()
	if (map && map.civilizations)
		loaded = list()
		chambered = null
	else if (map && !map.civilizations)
		if (map.ordinal_age == 1)
			loaded = list(
			new /obj/item/ammo_casing/arrow/bronze,
			)
			chambered = loaded[1]
			update_icon()
			src.overlays += image("icon" = 'icons/obj/weapons.dmi', "icon_state" = "arrow_bronze")
		else if (map.ordinal_age >= 2)
			loaded = list(
			new /obj/item/ammo_casing/arrow/iron,
			)
			chambered = loaded[1]
			update_icon()
			src.overlays += image("icon" = 'icons/obj/weapons.dmi', "icon_state" = "arrow_iron")
	else if (!(istype(loc, /mob/living)))
		loaded = list()
		chambered = null
		update_icon()

/obj/item/weapon/gun/projectile/bow/handle_post_fire()
	..()
	loaded = list()
	chambered = null

/obj/item/weapon/gun/projectile/bow/load_ammo(var/obj/item/A, mob/user)
	if (world.time < user.next_load)
		return

	if (load_delay && !do_after(user, load_delay, src, can_move = TRUE))
		return

	user.next_load = world.time + 1
	if (istype(A, /obj/item/ammo_casing))
		var/obj/item/ammo_casing/C = A
		if (caliber != C.caliber)
			return //incompatible
		if (loaded.len >= max_shells)
			user << "<span class='warning'>the [src] already has \a [projtype] ready!</span>"
			return

		user.remove_from_mob(C)
		C.loc = src
		loaded.Insert(1, C) //add to the head of the list
		user.visible_message("[user] inserts \a [C] into the [src].", "<span class='notice'>You insert \a [C] into the [src].</span>")
		icon_state = "[icotype]1"
		load_arrow_overlay(C)
		if (bulletinsert_sound) playsound(loc, bulletinsert_sound, 75, TRUE)

/obj/item/weapon/gun/projectile/bow/unload_ammo(mob/user, var/allow_dump=1)
	if (ammo_magazine)
		user.put_in_hands(ammo_magazine)

		if (unload_sound) playsound(loc, unload_sound, 75, TRUE)
		ammo_magazine.update_icon()
		ammo_magazine = null
	else if (loaded.len)
		if (load_method & SINGLE_CASING)
			var/obj/item/ammo_casing/C = loaded[loaded.len]
			loaded.len--
			user.put_in_hands(C)
			user.visible_message("[user] removes \a [C] from the [src].", "<span class='notice'>You remove \a [C] from the [src].</span>")
			icon_state = "[icotype]0"
			remove_arrow_overlay()
			if (bulletinsert_sound) playsound(loc, bulletinsert_sound, 75, TRUE)
	else
		user << "<span class='warning'>[src] is empty.</span>"
	update_icon()

/obj/item/weapon/gun/projectile/bow/update_icon()

	if (chambered)
		icon_state = "[icotype]1"
		item_state = "[icotype]1"
		return
	else
		icon_state = "[icotype]0"
		item_state = "[icotype]0"
		return

/obj/item/weapon/gun/projectile/bow/handle_click_empty(mob/user)
	if (user)
		user.visible_message("", "<span class='danger'>You don't have \a [projtype] here!</span>")
	else
		visible_message("")
	return


/obj/item/weapon/gun/projectile/bow/special_check(mob/user)
	if (!istype(src, /obj/item/weapon/gun/projectile/bow/sling))
		if (!(user.has_empty_hand(both = FALSE)))
			user << "<span class='warning'>You need both hands to fire the [src]!</span>"
			return FALSE
	return ..()

/obj/item/weapon/gun/projectile/bow/attackby(obj/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/attachment/bayonet))
		user << "<span class = 'danger'>That won't fit on there.</span>"
		return FALSE
	else
		return ..()