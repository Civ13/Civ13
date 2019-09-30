/obj/item/weapon/gun/projectile/crossbow
	name = "crossbow"
	desc = "A heavy and powerful bow."
	icon_state = "crossbow0"
	item_state = "crossbow0"
	w_class = 4
	throw_range = 4
	throw_speed = 5
	force = 8
	throwforce = 8
	max_shells = 1 //duh
	slot_flags = SLOT_SHOULDER
	caliber = "bolt"
	recoil = 1 //little shaking
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
	accuracy_increase_mod = 6.00
	accuracy_decrease_mod = 8.00
	KD_chance = KD_CHANCE_HIGH
	stat = "bows"
	move_delay = 6
	fire_delay = 8
	muzzle_flash = FALSE
	value = 10
	flammable = TRUE
	var/projtype = "bolt"
	var/icotype = "crossbow"
	equiptimer = 25
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 95,
			SHORT_RANGE_MOVING = 65,

			MEDIUM_RANGE_STILL = 85,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 70,
			LONG_RANGE_MOVING = 45,

			VERY_LONG_RANGE_STILL = 55,
			VERY_LONG_RANGE_MOVING = 30),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 95,
			SHORT_RANGE_MOVING = 65,

			MEDIUM_RANGE_STILL = 85,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 70,
			LONG_RANGE_MOVING = 45,

			VERY_LONG_RANGE_STILL = 55,
			VERY_LONG_RANGE_MOVING = 30),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 99,
			SHORT_RANGE_MOVING = 75,

			MEDIUM_RANGE_STILL = 90,
			MEDIUM_RANGE_MOVING = 65,

			LONG_RANGE_STILL = 70,
			LONG_RANGE_MOVING = 45,

			VERY_LONG_RANGE_STILL = 60,
			VERY_LONG_RANGE_MOVING = 45),
	)

	load_delay = 60
	aim_miss_chance_divider = 3.00

/obj/item/weapon/gun/projectile/crossbow/proc/remove_arrow_overlay()
	src.overlays = null

/obj/item/weapon/gun/projectile/crossbow/proc/load_arrow_overlay(var/obj/item/ammo_casing/arrow/A as obj)
	//remove all overlays
	remove_arrow_overlay()
	//add arrow overlay
	src.overlays += icon(A.icon,A.icon_state)

obj/item/weapon/gun/projectile/bow/Fire()
	..()
	remove_arrow_overlay()

/obj/item/weapon/gun/projectile/crossbow/New()
	..()
	if (map && map.civilizations)
		loaded = list()
		chambered = null
	else if (!(istype(loc, /mob/living)))
		loaded = list()
		chambered = null
		update_icon()

/obj/item/weapon/gun/projectile/crossbow/handle_post_fire()
	..()
	loaded = list()
	chambered = null

/obj/item/weapon/gun/projectile/crossbow/load_ammo(var/obj/item/A, mob/user)
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

/obj/item/weapon/gun/projectile/crossbow/unload_ammo(mob/user, var/allow_dump=1)
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

/obj/item/weapon/gun/projectile/crossbow/update_icon()

	if (chambered)
		icon_state = "[icotype]1"
		item_state = "[icotype]1"
		return
	else
		icon_state = "[icotype]0"
		item_state = "[icotype]0"
		return

/obj/item/weapon/gun/projectile/crossbow/handle_click_empty(mob/user)
	if (user)
		user.visible_message("", "<span class='danger'>You don't have \a [projtype] here!</span>")
	else
		visible_message("")
	return


/obj/item/weapon/gun/projectile/crossbow/special_check(mob/user)
	/*if (!istype(src, /obj/item/weapon/gun/projectile/crossbow/pistol))
		if (!(user.has_empty_hand(both = FALSE)))
			user << "<span class='warning'>You need both hands to fire the [src]!</span>"
			return FALSE
	return ..()*/
	..()