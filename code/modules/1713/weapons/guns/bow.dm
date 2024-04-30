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
	shake_strength = 0 //no shaking
	fire_sound = 'sound/weapons/arrow_fly.ogg'
	handle_casings = REMOVE_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/arrow
	load_shell_sound = 'sound/weapons/pull_bow.ogg'
	bulletinsert_sound = 'sound/weapons/pull_bow.ogg'
	//+2 accuracy over the LWAP because only one shot
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
	load_delay = 30
	aim_miss_chance_divider = 3.00
	accuracy = 4

/obj/item/weapon/gun/projectile/bow/New()
	..()
	if (map && !map.civilizations)
		if (map.ordinal_age == 1)
			loaded = list()
			var/obj/item/ammo_casing/C = new /obj/item/ammo_casing/arrow/bronze(src)
			loaded.Insert(1, C) //add to the head of the list
		else if (map.ordinal_age >= 2)
			loaded = list()
			var/obj/item/ammo_casing/C = new /obj/item/ammo_casing/arrow/iron(src)
			loaded.Insert(1, C) //add to the head of the list
	update_icon()

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
			to_chat(user, SPAN_WARNING("\The [src] already has \a [projtype] ready!"))
			return

		user.remove_from_mob(C)
		C.loc = src
		loaded.Insert(1, C) //add to the head of the list
		user.visible_message("[user] inserts \a [C] into \the [src].", "<span class='notice'>You insert \a [C] into \the [src].</span>")
		update_icon()
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
			user.visible_message("[user] removes \a [C] from the [src].", SPAN_NOTICE("You remove \a [C] from the [src]."))
			if (bulletinsert_sound) playsound(loc, bulletinsert_sound, 75, TRUE)
	else
		to_chat(user, SPAN_WARNING("[src] is empty."))
	update_icon()

/obj/item/weapon/gun/projectile/bow/update_icon()
	if (loaded.len)
		icon_state = "[icotype]1"
		item_state = "[icotype]1"
	else
		icon_state = "[icotype]0"
		item_state = "[icotype]0"
	update_arrow_overlay()
	return

/obj/item/weapon/gun/projectile/bow/proc/update_arrow_overlay()
	src.overlays = null
	if (loaded.len)
		src.overlays += icon(loaded[loaded.len].icon, loaded[loaded.len].icon_state)

/obj/item/weapon/gun/projectile/bow/handle_click_empty(mob/user)
	if (user)
		user.visible_message("", "<span class='danger'>You don't have \a [projtype] here!</span>")
	else
		visible_message("")
	return

/obj/item/weapon/gun/projectile/bow/special_check(mob/user)
	if (!istype(src, /obj/item/weapon/gun/projectile/bow/sling))
		if (!(user.has_empty_hand(both = FALSE)))
			to_chat(user, SPAN_WARNING("You need both hands to fire \the [src]!"))
			return FALSE
	return ..()

/obj/item/weapon/gun/projectile/bow/attackby(obj/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/attachment/bayonet))
		to_chat(user, SPAN_WARNING("That won't fit on there."))
		return FALSE
	else
		return ..()

/obj/item/weapon/gun/projectile/bow/handle_post_fire()
	..()
	loaded = list()
	update_icon()

/obj/item/weapon/gun/projectile/bow/Fire()
	..()
	update_icon()

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
	accuracy = 6

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
	recoil = 1
	accuracy = 4

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
	accuracy = 1

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
	accuracy = 10
