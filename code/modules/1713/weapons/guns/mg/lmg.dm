
/obj/item/weapon/gun/projectile/automatic
	force = 15
	throwforce = 30
	var/base_icon = "automatic"
	equiptimer = 22
	load_delay = 12
	gun_safety = TRUE
	slowdown = 0.6
	// not accurate at all
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 30,
			SHORT_RANGE_MOVING = 27,

			MEDIUM_RANGE_STILL = 21,
			MEDIUM_RANGE_MOVING = 19,

			LONG_RANGE_STILL = 11,
			LONG_RANGE_MOVING = 10,

			VERY_LONG_RANGE_STILL = 8,
			VERY_LONG_RANGE_MOVING = 7),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 38,
			SHORT_RANGE_MOVING = 34,

			MEDIUM_RANGE_STILL = 30,
			MEDIUM_RANGE_MOVING = 27,

			LONG_RANGE_STILL = 23,
			LONG_RANGE_MOVING = 21,

			VERY_LONG_RANGE_STILL = 11,
			VERY_LONG_RANGE_MOVING = 10),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 45,
			SHORT_RANGE_MOVING = 41,

			MEDIUM_RANGE_STILL = 38,
			MEDIUM_RANGE_MOVING = 34,

			LONG_RANGE_STILL = 30,
			LONG_RANGE_MOVING = 27,

			VERY_LONG_RANGE_STILL = 15,
			VERY_LONG_RANGE_MOVING = 14),
	)

	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 2.00
	KD_chance = KD_CHANCE_MEDIUM
	stat = "mg"
	w_class = 5
	heavy = TRUE
	load_method = MAGAZINE
	slot_flags = SLOT_SHOULDER
	sel_mode = 1
	full_auto = TRUE
	attachment_slots = ATTACH_IRONSIGHTS
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=0.8, move_delay=8, dispersion = list(0.7, 1.1, 1.1, 1.1, 1.3), recoil = 1.0),)

	var/jammed_until = -1
	var/jamcheck = 0
	var/last_fire = -1

/obj/item/weapon/gun/projectile/automatic/update_icon()
	if (ammo_magazine)
		icon_state = base_icon
	else
		icon_state = "[base_icon]_open"
	update_held_icon()
	return

/obj/item/weapon/gun/projectile/automatic/special_check(mob/user)
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

/obj/item/weapon/gun/projectile/automatic/madsen
	name = "Madsen light machine gun"
	desc = "The Madsen Machine Gun, is a light machine gun (LMG) designed in Denmark in the 1896. Many countries ordered models of it in different calibers. This one is 7.62x54mmR, mosin rounds."
	icon_state = "madsen"
	item_state = "madsen"
	base_icon = "madsen"
	caliber = "a762x54"
	magazine_type = /obj/item/ammo_magazine/madsen
	weight = 9.12

	force = 20
	throwforce = 30

/obj/item/weapon/gun/projectile/automatic/type99
	name = "Type-99 light machine gun"
	desc = "The Type-99 Light Machine Gun, is a light machine gun (LMG) refitted to fit the new 7.7x58mm cartridge rather than the old 6.50x50mm rounds. This one is 7.7x58mm Arisaka rounds."
	icon_state = "type99lmg"
	item_state = "type99lmg"
	base_icon = "type99lmg"
	caliber = "a77x58"
	magazine_type = /obj/item/ammo_magazine/type99
	weight = 9.12
	force = 20
	throwforce = 30


/obj/item/weapon/gun/projectile/automatic/dp28
	name = "DP28 light machine gun"
	desc = "The DP28 Light Machine Gun, is a light machine gun (LMG) This one is 7.62x54mmR rounds."
	icon_state = "dp"
	item_state = "dp"
	base_icon = "dp"
	caliber = "a762x54_weak"
	magazine_type = /obj/item/ammo_magazine/dp
	weight = 9.12
	force = 20
	throwforce = 30

/obj/item/weapon/gun/projectile/automatic/bar
	name = "Browning Automatic Rifle"
	desc = "The BAR, is a light machine gun (LMG) This one is chambered in .30-06 rounds."
	icon_state = "bar"
	item_state = "bar"
	base_icon = "bar"
	caliber = "a3006_weak"
	magazine_type = /obj/item/ammo_magazine/bar
	weight = 9.12
	force = 20
	throwforce = 30
////////////////////////////MG34/////////////////////////////////////////
/obj/item/weapon/gun/projectile/automatic/mg34
	name = "MG 34"
	desc = "German light machinegun chambered in 7.92x57mm Mauser. An utterly devastating support weapon."
	icon_state = "mg34"
	item_state = "mg34"
	base_icon = "mg34"
	w_class = 5
	heavy = TRUE
	max_shells = 50
	caliber = "a792x57_weak"
	weight = 12.1
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a792x57/weak
	load_method = MAGAZINE
	magazine_type = /obj/item/ammo_magazine/mg34
	unload_sound 	= 'sound/weapons/guns/interact/lmg_magout.ogg'
	reload_sound 	= 'sound/weapons/guns/interact/lmg_magin.ogg'
	cocked_sound 	= 'sound/weapons/guns/interact/lmg_cock.ogg'
	fire_sound = 	'sound/weapons/guns/fire/mg34_firing.ogg'
	force = 20
	throwforce = 30
	var/cover_open = FALSE

/obj/item/weapon/gun/projectile/automatic/mg34/special_check(mob/user)
	if (cover_open)
		user << "<span class='warning'>[src]'s cover is open! Close it before firing!</span>"
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/automatic/mg34/proc/toggle_cover(mob/user)
	cover_open = !cover_open
	user << "<span class='notice'>You [cover_open ? "open" : "close"] [src]'s cover.</span>"
	update_icon()

/obj/item/weapon/gun/projectile/automatic/mg34/attack_self(mob/user as mob)
	if (cover_open)
		toggle_cover(user) //close the cover
		playsound(loc, 'sound/weapons/guns/interact/lmg_close.ogg', 100, TRUE)
	else
		return ..() //once closed, behave like normal

/obj/item/weapon/gun/projectile/automatic/mg34/attack_hand(mob/user as mob)
	if (!cover_open && user.get_inactive_hand() == src)
		toggle_cover(user) //open the cover
		playsound(loc, 'sound/weapons/guns/interact/lmg_open.ogg', 100, TRUE)
	else
		return ..() //once open, behave like normal

/obj/item/weapon/gun/projectile/automatic/mg34/update_icon()
	icon_state = "mg34[cover_open ? "_open" : "closed"][ammo_magazine ? round(ammo_magazine.stored_ammo.len, 25) : "-empty"]"

/obj/item/weapon/gun/projectile/automatic/mg34/load_ammo(var/obj/item/A, mob/user)
	if (!cover_open)
		user << "<span class='warning'>You need to open the cover to load [src].</span>"
		return
	..()

/obj/item/weapon/gun/projectile/automatic/mg34/unload_ammo(mob/user, var/allow_dump=1)
	if (!cover_open)
		user << "<span class='warning'>You need to open the cover to unload [src].</span>"
		return
	..()
///////////////////////////////////////////////////////////////////////////
/obj/item/weapon/gun/projectile/automatic/m60
	name = "M60 machine gun"
	desc = "An american machinegun chambered in 7.62x51mm NATO rounds. Heavy and handles like a pig."
	icon_state = "m60"
	item_state = "m60"
	base_icon = "m60"
	caliber = "a762x51_weak"
	magazine_type = /obj/item/ammo_magazine/b762
	weight = 10.5
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=1.3, move_delay=8, dispersion = list(0.7, 1.1, 1.3, 1.4, 1.5), recoil = 2),)
	slot_flags = 0
	force = 20
	nothrow = TRUE
	throwforce = 30
	equiptimer = 25
	load_delay = 50
	slowdown = 1

/obj/item/weapon/gun/projectile/automatic/m249
	name = "M249 machine gun"
	desc = "An american machinegun chambered in 5.56x45mm NATO rounds. Sucessor of the M60."
	icon_state = "m60"
	item_state = "m60"
	base_icon = "m60"
	caliber = "a556x45"
	magazine_type = /obj/item/ammo_magazine/m249
	weight = 10
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=1.1, move_delay=7, dispersion = list(0.6, 1, 1.2, 1.3, 1.3), recoil = 2),)
	slot_flags = 0
	force = 20
	nothrow = TRUE
	throwforce = 30
	equiptimer = 25
	load_delay = 50
	slowdown = 1

/obj/item/weapon/gun/projectile/automatic/handle_post_fire()
	..()

	if (world.time - last_fire > 50)
		jamcheck = 0
	else
		jamcheck += 0.1

	if (prob(jamcheck))
		jammed_until = max(world.time + (jamcheck * 5), 50)
		jamcheck = 0

	last_fire = world.time

/obj/item/weapon/gun/projectile/automatic/pkm
	name = "PKM machine gun"
	desc = "A soviet machinegun chambered in 7.62x54mmR rounds."
	icon_state = "pkmp"
	item_state = "pkmp"
	base_icon = "pkmp"
	caliber = "a762x54_weak"
	magazine_type = /obj/item/ammo_magazine/pkm/c100
	weight = 7.5
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=1.3, move_delay=7, dispersion = list(0.7, 1.1, 1.3, 1.4, 1.6), recoil = 1.8),)
	slot_flags = 0
	force = 20
	nothrow = TRUE
	throwforce = 30
	equiptimer = 25
	load_delay = 50
	slowdown = 0.8

/obj/item/weapon/gun/projectile/automatic/negev
	name = "IWI Negev"
	desc = "An israeli machinegun chambered in 5.56x45mm NATO rounds."
	icon_state = "negev"
	item_state = "negev"
	base_icon = "negev"
	caliber = "a556x45"
	magazine_type = /obj/item/ammo_magazine/negev
	weight = 8
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=0.9, move_delay=7, dispersion = list(0.6, 1, 1.2, 1.3, 1.3), recoil = 2),)
	slot_flags = 0
	force = 20
	nothrow = TRUE
	throwforce = 30
	equiptimer = 25
	load_delay = 50
	slowdown = 0.9