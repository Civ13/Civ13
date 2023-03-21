//lever-action guns (i.e., winchester repeater)
//All the leveraction weapons

/obj/item/weapon/gun/projectile/leveraction
	name = "leveraction rifle"
	icon = 'icons/obj/guns/rifles.dmi'
	desc = "A simple rifle using a lever-action mechanism."
	icon_state = "winchester"
	item_state = "shotgun"
	w_class = ITEM_SIZE_LARGE
	throw_range = 4
	throw_speed = 2
	force = 10
	throwforce = 10
	max_shells = 15
	slot_flags = SLOT_SHOULDER
	caliber = "a44"
	recoil = 0 //extra kickback
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/a44
//	magazine_type = /obj/item/ammo_magazine/musketball
	load_shell_sound = 'sound/weapons/guns/interact/shotgun_insert.ogg'
	cocked_sound = 'sound/weapons/guns/interact/shotgun_pump.ogg'
	//+2 accuracy over the LWAP because only one shot
	accuracy = TRUE
//	scoped_accuracy = 2
	gun_type = GUN_TYPE_RIFLE
	attachment_slots = ATTACH_IRONSIGHTS | ATTACH_BARREL
	accuracy_increase_mod = 2.00
	accuracy_decrease_mod = 6.00
	KD_chance = KD_CHANCE_HIGH
	stat = "rifle"
	move_delay = 2
	fire_delay = 2
	blackpowder = FALSE
	handle_casings = HOLD_CASINGS
	equiptimer = 15
	gtype = "rifle"
	// 5x as accurate as MGs for now
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 83,
			SHORT_RANGE_MOVING = 42,

			MEDIUM_RANGE_STILL = 73,
			MEDIUM_RANGE_MOVING = 37,

			LONG_RANGE_STILL = 53,
			LONG_RANGE_MOVING = 27,

			VERY_LONG_RANGE_STILL = 43,
			VERY_LONG_RANGE_MOVING = 23),

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
			SHORT_RANGE_STILL = 93,
			SHORT_RANGE_MOVING = 47,

			MEDIUM_RANGE_STILL = 83,
			MEDIUM_RANGE_MOVING = 42,

			LONG_RANGE_STILL = 73,
			LONG_RANGE_MOVING = 37,

			VERY_LONG_RANGE_STILL = 63,
			VERY_LONG_RANGE_MOVING = 32),
	)

	load_delay = 8
	aim_miss_chance_divider = 2.50

	var/recentpump = FALSE


/obj/item/weapon/gun/projectile/leveraction/attack_hand(mob/user as mob)
	if (user.get_inactive_hand() == src)
		unload_ammo(user, allow_dump=0)
	else
		return ..()
	/*
/obj/item/weapon/gun/projectile/leveraction/attack_self(mob/user)
	if (empty_casing && !cocked)
		playsound(loc, cocked_sound, 50, TRUE)
		visible_message("<span class='warning'>[user] cycles the [src]!</span>","<span class='warning'>You cycle the [src]!</span>")
		empty_casing = FALSE
		cocked = TRUE
	else if (!empty_casing && !cocked && loaded.len > 0)
		playsound(loc, cocked_sound, 50, TRUE)
		visible_message("<span class='warning'>[user] cycles the [src], ejecting an unused casing!</span>","<span class='warning'>You cycle the [src], ejecting an unused casing!</span>")
		empty_casing = FALSE
		cocked = TRUE
*/
/obj/item/weapon/gun/projectile/leveraction/special_check(mob/user)
//	var/mob/living/human/H = user
	if (gun_safety && safetyon)
		user << "<span class='warning'>You can't fire \the [src] while the safety is on!</span>"
		return FALSE
/*
	if (loaded.len <= 0)
		user << "<span class='warning'>\the [src] is empty.</span>"
		return FALSE
	if (empty_casing)
		user << "<span class='warning'>You can't fire \the [src] without cycling it first!</span>"
		return FALSE
	if (!cocked)
		user << "<span class='warning'>You can't fire \the [src] while the chamber is empty!</span>"
		return FALSE
*/
	if (!(user.has_empty_hand(both = FALSE)))
		user << "<span class='warning'>You need both hands to fire \the [src]!</span>"
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/leveraction/consume_next_projectile()
	if (chambered)
		return chambered.BB
	return null

/obj/item/weapon/gun/projectile/leveraction/attack_self(mob/living/user as mob)
	if (world.time >= recentpump + 8)
		pump(user)
		recentpump = world.time
		return
	else
		return

/obj/item/weapon/gun/projectile/leveraction/handle_post_fire()
	..()
	if (blackpowder)
		spawn (1)
			new/obj/effect/effect/smoke/chem(get_step(src, dir))

/obj/item/weapon/gun/projectile/leveraction/proc/pump(mob/M as mob)
	playsound(M, cocked_sound, 60, TRUE)
	if (!chambered)
		visible_message("<span class='warning'>[M] cycles the [src]!</span>","<span class='warning'>You cycle the [src]!</span>")
	else if (chambered && chambered.BB == null)
		visible_message("<span class='warning'>[M] cycles the [src], ejecting a spent casing!</span>","<span class='warning'>You cycle the [src], ejecting a spent casing!</span>")
	else
		visible_message("<span class='warning'>[M] cycles the [src], ejecting an unused casing!</span>","<span class='warning'>You cycle the [src], ejecting an unused casing!</span>")

	if (chambered)//We have a shell in the chamber
		chambered.loc = get_turf(src)//Eject casing
		chambered.randomrotation()
		chambered = null

	if (loaded.len)
		var/obj/item/ammo_casing/AC = loaded[1] //load next casing.
		loaded -= AC //Remove casing from loaded list.
		chambered = AC

	update_icon()
/*
/obj/item/weapon/gun/projectile/leveraction/unload_ammo(var/mob/living/human/user, allow_dump=0)
	if (loaded.len)
		if (load_method & SINGLE_CASING)
			var/obj/item/ammo_casing/C = loaded[loaded.len]
			loaded.len--
			user.put_in_hands(C)
			visible_message("[user] removes \a [C] from [src].", "<span class='notice'>You remove \a [C] from [src].</span>")
			if (load_shell_sound) playsound(loc, load_shell_sound, 75, TRUE)
	else
		user << "<span class='warning'>\the [src] is empty.</span>"
	update_icon()

*/
/obj/item/weapon/gun/projectile/leveraction/winchester
	name = "Winchester M1873"
	desc = "A lever-action rifle with a 15-round tube, chambered in .44-40 rounds."
	force = 9
	fire_sound = 'sound/weapons/guns/fire/shotgun.ogg'
	icon_state = "winchester1873"
	caliber = "a44"
	max_shells = 15
	weight = 5.0
	effectiveness_mod = 0.96
	ammo_type = /obj/item/ammo_casing/a44
	value = 150
	blackpowder = TRUE
	load_delay = 4

/obj/item/weapon/gun/projectile/leveraction/winchesterm1876
	name = "Winchester M1876"
	desc = "A lever-action rifle with a 15-round tube, chambered in .44-40 rounds."
	force = 9
	fire_sound = 'sound/weapons/guns/fire/shotgun.ogg'
	icon_state = "winchester1876"
	caliber = "a44"
	max_shells = 15
	weight = 6.0
	effectiveness_mod = 0.97
	ammo_type = /obj/item/ammo_casing/a44
	value = 150
	blackpowder = TRUE
	load_delay = 4.2

/obj/item/weapon/gun/projectile/leveraction/winchesterm1886
	name = "Winchester M1886"
	desc = "A lever-action rifle with a 15-round tube, chambered in .45-70 rounds."
	force = 9
	fire_sound = 'sound/weapons/guns/fire/shotgun.ogg'
	icon_state = "winchester1886"
	caliber = "a4570"
	max_shells = 15
	weight = 6.1
	effectiveness_mod = 0.99
	ammo_type = /obj/item/ammo_casing/a4570
	value = 150
	blackpowder = TRUE
	load_delay = 4.4

/obj/item/weapon/gun/projectile/leveraction/winchesterm1892
	name = "Winchester M1892"
	desc = "A lever-action rifle with a 15-round tube, chambered in .44-40 rounds."
	force = 9
	fire_sound = 'sound/weapons/guns/fire/shotgun.ogg'
	icon_state = "winchester1886"
	caliber = "a44"
	max_shells = 15
	weight = 5.6
	effectiveness_mod = 0.97
	ammo_type = /obj/item/ammo_casing/a44
	value = 150
	blackpowder = TRUE
	load_delay = 4.1

/obj/item/weapon/gun/projectile/leveraction/goldchester
	name = "Golden Winchester M1873"
	desc = "A lever-action rifle with a 15-round tube, chambered in .44-40 rounds."
	force = 9
	fire_sound = 'sound/weapons/guns/fire/shotgun.ogg'
	icon_state = "goldwinchester"
	caliber = "a44"
	max_shells = 15
	weight = 5.0
	effectiveness_mod = 0.96
	ammo_type = /obj/item/ammo_casing/a44
	value = 150
	blackpowder = TRUE
	load_delay = 4

/obj/item/weapon/gun/projectile/leveraction/evansrepeater
	name = "Evans repeating rifle"
	desc = "A lever-action rifle with a 28-round tube, chambered in .44-40 rounds."
	force = 9
	fire_sound = 'sound/weapons/guns/fire/shotgun.ogg'
	icon_state = "evans_repeating_rifle"
	caliber = "a44"
	max_shells = 28
	weight = 5.9
	effectiveness_mod = 0.87
	ammo_type = /obj/item/ammo_casing/a44
	value = 150
	blackpowder = TRUE
	load_delay = 4.2

/obj/item/weapon/gun/projectile/leveraction/henryrepeater
	name = "Henry repeating rifle"
	desc = "A lever-action rifle with a 16-round tube, chambered in .44-40 rounds."
	force = 8
	fire_sound = 'sound/weapons/guns/fire/shotgun.ogg'
	icon_state = "henry_rifle"
	caliber = "a44"
	max_shells = 16
	weight = 5.5
	effectiveness_mod = 0.94
	ammo_type = /obj/item/ammo_casing/a44
	value = 150
	blackpowder = TRUE
	load_delay = 3.5