//lever-action guns (i.e., winchester repeater)
//All the leveraction weapons

/obj/item/weapon/gun/projectile/leveraction
	name = "leveraction rifle"
	icon = 'icons/obj/guns/rifles.dmi'
	desc = "A simple rifle using a lever-action mechanism."
	icon_state = "winchester"
	item_state = "shotgun"
	base_icon = "shotgun"
	w_class = ITEM_SIZE_LARGE
	throw_range = 4
	throw_speed = 2
	force = 10
	throwforce = 10
	max_shells = 15
	slot_flags = SLOT_SHOULDER
	caliber = "a44"
	shake_strength = 0 //extra kickback
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/a44
//	magazine_type = /obj/item/ammo_magazine/musketball
	fire_sound = 'sound/weapons/guns/fire/winchester.ogg'
	load_shell_sound = 'sound/weapons/guns/interact/shotgun_insert.ogg'
	cocked_sound = 'sound/weapons/guns/interact/lever_action.ogg'
	//+2 accuracy over the LWAP because only one shot
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
	load_delay = 8
	aim_miss_chance_divider = 2.50

	var/recentpump = FALSE


/obj/item/weapon/gun/projectile/leveraction/attack_hand(mob/user as mob)
	if (user.get_inactive_hand() == src)
		unload_ammo(user, allow_dump=0)
	else
		return ..()

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
		M.visible_message("<span class='warning'>[M] cycles the [src]!</span>","<span class='warning'>You cycle the [src]!</span>")
	else if (chambered && chambered.BB == null)
		M.visible_message("<span class='warning'>[M] cycles the [src], ejecting a spent casing!</span>","<span class='warning'>You cycle the [src], ejecting a spent casing!</span>")
	else
		M.visible_message("<span class='warning'>[M] cycles the [src], ejecting an unused casing!</span>","<span class='warning'>You cycle the [src], ejecting an unused casing!</span>")

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
/obj/item/weapon/gun/projectile/leveraction/winchesterm1873
	name = "Winchester M1873"
	desc = "A lever-action rifle with a 14-round tube, chambered in .44-40 rounds."
	force = 9
	icon_state = "winchester1873"
	caliber = "a44"
	max_shells = 14
	weight = 5.0
	ammo_type = /obj/item/ammo_casing/a44
	value = 150
	blackpowder = TRUE
	load_delay = 4
	accuracy = 4

/obj/item/weapon/gun/projectile/leveraction/winchesterm1876
	name = "Winchester M1876"
	desc = "A lever-action rifle with a 13-round tube, chambered in .44-40 rounds."
	force = 9
	icon_state = "winchester1876"
	caliber = "a44"
	max_shells = 13
	weight = 6.0
	ammo_type = /obj/item/ammo_casing/a44
	value = 150
	blackpowder = TRUE
	load_delay = 4.2
	accuracy = 4

/obj/item/weapon/gun/projectile/leveraction/winchesterm1886
	name = "Winchester M1886"
	desc = "A lever-action rifle with a 9-round tube, chambered in .45-70 rounds."
	force = 9
	icon_state = "winchester1886"
	caliber = "a4570"
	max_shells = 9
	weight = 6.1
	ammo_type = /obj/item/ammo_casing/a4570
	value = 150
	blackpowder = TRUE
	load_delay = 4.4
	accuracy = 4

/obj/item/weapon/gun/projectile/leveraction/winchesterm1892
	name = "Winchester M1892"
	desc = "A lever-action rifle with a 12-round tube, chambered in .44-40 rounds."
	force = 9
	icon_state = "winchester1886"
	caliber = "a44"
	max_shells = 12
	weight = 5.6
	ammo_type = /obj/item/ammo_casing/a44
	value = 150
	blackpowder = TRUE
	load_delay = 4.1
	accuracy = 4

/obj/item/weapon/gun/projectile/leveraction/winchesterm1873/gold
	name = "Golden Winchester M1873"
	desc = "A lever-action rifle with a 14-round tube, chambered in .44-40 rounds."
	force = 9
	icon_state = "goldwinchester"
	caliber = "a44"
	max_shells = 14
	weight = 5.0
	ammo_type = /obj/item/ammo_casing/a44
	value = 150
	blackpowder = TRUE
	load_delay = 4
	accuracy = 4

/obj/item/weapon/gun/projectile/leveraction/evansrepeater
	name = "Evans repeating rifle"
	desc = "A lever-action rifle with a 28-round tube, chambered in .44-40 rounds."
	force = 9
	icon_state = "evans_repeating_rifle"
	caliber = "a44"
	max_shells = 28
	weight = 5.9
	ammo_type = /obj/item/ammo_casing/a44
	value = 150
	blackpowder = TRUE
	load_delay = 4.2
	accuracy = 5

/obj/item/weapon/gun/projectile/leveraction/henryrepeater
	name = "Henry repeating rifle"
	desc = "A lever-action rifle with a 15-round tube, chambered in .44-40 rounds."
	force = 8
	icon_state = "henry_rifle"
	caliber = "a44"
	max_shells = 15
	weight = 5.5
	ammo_type = /obj/item/ammo_casing/a44
	value = 150
	blackpowder = TRUE
	load_delay = 3.5
	accuracy = 4

/obj/item/weapon/gun/projectile/leveraction/cowboy_repeater
	name = "Cowboy Repeater"
	desc = "A lever-action rifle with a 7-round tube, chambered in .357 Magnum rounds."
	force = 9
	icon_state = "cowboy_repeater"
	caliber = "a357"
	max_shells = 7
	weight = 5.0
	ammo_type = /obj/item/ammo_casing/a357
	value = 150
	blackpowder = TRUE
	load_delay = 4
	accuracy = 4