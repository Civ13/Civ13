/obj/item/weapon/gun/projectile/shotgun
	gun_type = GUN_TYPE_SHOTGUN
	fire_sound = 'sound/weapons/guns/fire/shotgun_fire.ogg'
	// 15% more accurate than SMGs
	equiptimer = 17
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 56,
			SHORT_RANGE_MOVING = 45,

			MEDIUM_RANGE_STILL = 45,
			MEDIUM_RANGE_MOVING = 36,

			LONG_RANGE_STILL = 16,
			LONG_RANGE_MOVING = 13,

			VERY_LONG_RANGE_STILL = 8,
			VERY_LONG_RANGE_MOVING = 7),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 68,
			SHORT_RANGE_MOVING = 54,

			MEDIUM_RANGE_STILL = 45,
			MEDIUM_RANGE_MOVING = 36,

			LONG_RANGE_STILL = 18,
			LONG_RANGE_MOVING = 15,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 8),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 91,
			SHORT_RANGE_MOVING = 72,

			MEDIUM_RANGE_STILL = 68,
			MEDIUM_RANGE_MOVING = 54,

			LONG_RANGE_STILL = 45,
			LONG_RANGE_MOVING = 36,

			VERY_LONG_RANGE_STILL = 18,
			VERY_LONG_RANGE_MOVING = 15),
	)

	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 1.00
	KD_chance = KD_CHANCE_HIGH
	stat = "rifle"

/obj/item/weapon/gun/projectile/shotgun/pump
	name = "pump-action shotgun"
	desc = "A pump-action shotgun chambered in 12 gauge rounds."
	icon_state = "shotgun"
	item_state = "shotgun"
	max_shells = 6
	w_class = 4.0
	force = 10
	flags =  CONDUCT
	slot_flags = SLOT_SHOULDER
	caliber = "12gauge"
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/shotgun
	handle_casings = HOLD_CASINGS
	stat = "rifle"
	move_delay = 4
	var/recentpump = FALSE // to prevent spammage
	load_delay = 5

/obj/item/weapon/gun/projectile/shotgun/pump/consume_next_projectile()
	if (chambered)
		return chambered.BB
	return null

/obj/item/weapon/gun/projectile/shotgun/pump/attack_self(mob/living/user as mob)
	if (world.time >= recentpump + 10)
		pump(user)
		recentpump = world.time

/obj/item/weapon/gun/projectile/shotgun/pump/proc/pump(mob/M as mob)
	playsound(M, 'sound/weapons/shotgunpump.ogg', 60, TRUE)

	if (chambered)//We have a shell in the chamber
		chambered.loc = get_turf(src)//Eject casing
		chambered.randomrotation()
		chambered = null

	if (loaded.len)
		var/obj/item/ammo_casing/AC = loaded[1] //load next casing.
		loaded -= AC //Remove casing from loaded list.
		chambered = AC

	update_icon()

/obj/item/weapon/gun/projectile/shotgun/coachgun
	name = "coach gun"
	desc = "a double-barreled shotgun, commonly used by messengers and on stagecoaches."
	icon_state = "doublebarreled"
	item_state = "shotgun"
	max_shells = 2
	w_class = 4.0
	force = 10
	flags =  CONDUCT
	slot_flags = SLOT_SHOULDER
	caliber = "12gauge"
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/shotgun
	handle_casings = HOLD_CASINGS
	stat = "rifle"
	move_delay = 4
	var/open = FALSE
	var/recentpump = FALSE // to prevent spammage
	load_delay = 5
	blackpowder = TRUE
/obj/item/weapon/gun/projectile/shotgun/coachgun/consume_next_projectile()
	if (chambered)
		return chambered.BB
	return null
/obj/item/weapon/gun/projectile/shotgun/coachgun/update_icon()
	..()
	if (open)
		icon_state = "doublebarreled_open"
	else
		icon_state = "doublebarreled"

/obj/item/weapon/gun/projectile/shotgun/coachgun/attack_self(mob/living/user as mob)
	if (world.time >= recentpump + 10)
		if (open)
			open = FALSE
			user << "<span class='notice'>You close \the [src].</span>"
			icon_state = "doublebarreled"
			if (loaded.len)
				var/obj/item/ammo_casing/AC = loaded[1] //load next casing.
				loaded -= AC //Remove casing from loaded list.
				chambered = AC
		else
			open = TRUE
			user << "<span class='notice'>You break open \the [src].</span>"
			icon_state = "doublebarreled_open"
		recentpump = world.time

/obj/item/weapon/gun/projectile/shotgun/coachgun/load_ammo(var/obj/item/A, mob/user)
	if (!open)
		user << "<span class='notice'>You need to open \the [src] first!</span>"
		return
	..()

/obj/item/weapon/gun/projectile/shotgun/coachgun/unload_ammo(mob/user, var/allow_dump=1)
	if (!open)
		user << "<span class='notice'>You need to open \the [src] first!</span>"
		return
	..()

/obj/item/weapon/gun/projectile/shotgun/coachgun/special_check(mob/user)
	if (open)
		user << "<span class='warning'>You can't fire \the [src] while it is break open!</span>"
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/shotgun/coachgun/handle_post_fire()
	..()
	if (loaded.len)
		var/obj/item/ammo_casing/AC = loaded[1] //load next casing.
		loaded -= AC //Remove casing from loaded list.
		chambered = AC
	if (blackpowder)
		spawn (1)
			new/obj/effect/effect/smoke/chem(get_step(src, dir))
		spawn (6)
			new/obj/effect/effect/smoke/chem(get_step(src, dir))