
/obj/item/weapon/gun/projectile/automatic
	gtype = "mg"
	icon = 'icons/obj/guns/mgs.dmi'
	force = 20
	throwforce = 30
	nothrow = TRUE
	var/base_icon = "automatic"
	equiptimer = 28
	load_delay = 12
	gun_safety = TRUE
	slowdown = 0.5

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
			SHORT_RANGE_STILL = 78,
			SHORT_RANGE_MOVING = 66,

			MEDIUM_RANGE_STILL = 55,
			MEDIUM_RANGE_MOVING = 45,

			LONG_RANGE_STILL = 33,
			LONG_RANGE_MOVING = 30,

			VERY_LONG_RANGE_STILL = 19,
			VERY_LONG_RANGE_MOVING = 15),
	)

	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 2.00
	KD_chance = KD_CHANCE_MEDIUM
	stat = "machinegun"
	w_class = ITEM_SIZE_HUGE
	heavy = TRUE
	load_method = MAGAZINE
	slot_flags = SLOT_SHOULDER
	sel_mode = 1
	full_auto = TRUE
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=0.8, move_delay=8, dispersion = list(0.7, 1.1, 1.1, 1.1, 1.2), recoil = 0),)

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
		user << SPAN_WARNING("You can't fire \the [src] while the safety is on!")
		return FALSE
	if (!user.has_empty_hand(both = FALSE))
		user << SPAN_WARNING(">You need both hands to fire \the [src]!")
		return FALSE
	if (jammed_until > world.time)
		user << SPAN_DANGER("\The [src] has jammed! You can't fire it until it has unjammed.")
		return FALSE
	return TRUE

/obj/item/weapon/gun/projectile/automatic/handle_post_fire()
	..()
	var/reverse_health_percentage = (1-(health/maxhealth)+0.25)*100
	if (world.time - last_fire > 50)
		jamcheck = 0
	else
		jamcheck += 0.1

	if (prob(jamcheck*reverse_health_percentage))
		jammed_until = max(world.time + (jamcheck * 5), 50)
		jamcheck = 0

	last_fire = world.time

/obj/item/weapon/gun/projectile/automatic/madsen
	name = "Madsen light machine gun"
	desc = "The Madsen Machine Gun, is a light machine gun designed in Denmark in the 1896. Many countries ordered models of it in different calibers. This one is 7.62x54mmR, mosin rounds."
	icon_state = "madsen"
	item_state = "madsen"
	base_icon = "madsen"
	caliber = "a762x54"
	magazine_type = /obj/item/ammo_magazine/madsen
	good_mags = list(/obj/item/ammo_magazine/madsen)
	ammo_type = /obj/item/ammo_casing/a762x54
	weight = 9.12
	effectiveness_mod = 1.01
	slot_flags = SLOT_SHOULDER

/obj/item/weapon/gun/projectile/automatic/type99
	name = "Type 99 light machinegun"
	desc = "The Type 99 light machine Gun, is a Japanese light machine gun refitted to fit the new 7.7x58mm cartridge rather than the old 6.50x50mm rounds."
	icon_state = "type99lmg"
	item_state = "type99lmg"
	base_icon = "type99lmg"
	caliber = "a77x58"
	magazine_type = /obj/item/ammo_magazine/type99
	good_mags = list(/obj/item/ammo_magazine/type99, /obj/item/ammo_magazine/type92)
	ammo_type = /obj/item/ammo_casing/a77x58
	weight = 9.12
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	slowdown = 0.2
	effectiveness_mod = 1.00
	has_telescopic = TRUE
	slot_flags = SLOT_SHOULDER

/obj/item/weapon/gun/projectile/automatic/type96
	name = "Type 96 light machinegun"
	desc = "The Type 96 light machine Gun, is a Japanese light machine gun chambered in 6.50x50mm rounds."
	icon_state = "type96lmg"
	item_state = "type96lmg"
	base_icon = "type96lmg"
	caliber = "a65x50"
	magazine_type = /obj/item/ammo_magazine/type96
	good_mags = list(/obj/item/ammo_magazine/type96)
	ammo_type = /obj/item/ammo_casing/a65x50
	weight = 9.12
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	slowdown = 0.2
	effectiveness_mod = 1.13
	has_telescopic = TRUE
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=0.4, move_delay=4, dispersion = list(0.2, 0.1, 0.4, 0.6, 0.2), recoil = 0),)

/obj/item/weapon/gun/projectile/automatic/dp28
	name = "DP-28"
	desc = "The DP-28 light machinegun. This one is in 7.62x54mmR."
	icon_state = "dp"
	item_state = "dp"
	base_icon = "dp"
	caliber = "a762x54_weak"
	fire_sound = 'sound/weapons/guns/fire/DP28.ogg'
	magazine_type = /obj/item/ammo_magazine/dp
	good_mags = list(/obj/item/ammo_magazine/dp)
	ammo_type = /obj/item/ammo_casing/a762x54/weak
	slot_flags = SLOT_SHOULDER
	weight = 9.12
	effectiveness_mod = 1.05
	bad_magazine_types = list(/obj/item/ammo_magazine/maxim)

/obj/item/weapon/gun/projectile/automatic/bar
	name = "M1918A2 BAR"
	desc = "The BAR, is a light machine gun (LMG) This one is chambered in .30-06 rounds."
	icon_state = "bar"
	item_state = "bar"
	base_icon = "bar"
	slot_flags = SLOT_SHOULDER
	caliber = "a3006_weak"
	fire_sound = 'sound/weapons/guns/fire/M1918A2.ogg'
	magazine_type = /obj/item/ammo_magazine/bar
	good_mags = list(/obj/item/ammo_magazine/bar)
	ammo_type = /obj/item/ammo_casing/a3006/weak
	weight = 9.12
	effectiveness_mod = 1.02
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.1, move_delay=3, dispersion = list(0.6, 1, 1.2, 1.3, 1.3), recoil = 0),)
	bad_magazine_types = list(/obj/item/ammo_magazine/browning)

///////////////////////////M1919A6//////////////////////
/obj/item/weapon/gun/projectile/automatic/browning_lmg
	name = "M1919A6 Browning LMG"
	desc = "An American squad support machinegun. Uses 30-06 rounds. Very heavy to carry around."
	icon_state = "browlmg"
	item_state = "browlmg"
	base_icon = "browlmg"
	heavy = TRUE
	w_class = ITEM_SIZE_HUGE
	slot_flags = SLOT_SHOULDER
	caliber = "a3006"
	fire_sound = 'sound/weapons/guns/fire/M1919.ogg'
	magazine_type = /obj/item/ammo_magazine/browning
	good_mags = list(/obj/item/ammo_magazine/browning)
	ammo_type = /obj/item/ammo_casing/a3006
	weight = 12.50 //heavy piece of shit
	effectiveness_mod = 1.01
/obj/item/weapon/gun/projectile/automatic/browning_lmg/update_icon()
	icon_state = "browlmg[ammo_magazine ? round(ammo_magazine.stored_ammo.len, 50) : "_empty"]"

////////////////////////////Manual Machine guns/////////////////////////////////////////
/obj/item/weapon/gun/projectile/automatic/manual
	var/cover_open = FALSE
	var/cover_toggle_time = 1.5 SECONDS
	var/cover_open_sound = 'sound/weapons/guns/interact/lmg_open.ogg'
	var/cover_close_sound = 'sound/weapons/guns/interact/lmg_close.ogg'

/obj/item/weapon/gun/projectile/automatic/manual/special_check(mob/user)
	if (cover_open)
		user << SPAN_WARNING("\The [src]'s cover is open! Close it before firing!")
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/automatic/manual/proc/toggle_cover(mob/user)
	if (do_after(user, cover_toggle_time, src, can_move = TRUE))
		cover_open ? playsound(loc, cover_close_sound, 100, TRUE) : playsound(loc, cover_open_sound, 100, TRUE)
		cover_open = !cover_open
		user << SPAN_NOTICE("You [cover_open ? "open" : "close"] \the [src]'s cover.")
	update_icon()

/obj/item/weapon/gun/projectile/automatic/manual/attack_self(mob/user as mob)
	if (cover_open)
		toggle_cover(user) //close the cover
	else
		return ..() //once closed, behave like normal

/obj/item/weapon/gun/projectile/automatic/manual/attack_hand(mob/user as mob)
	if (!cover_open && user.get_inactive_hand() == src)
		toggle_cover(user) //open the cover
	else
		return ..() //once open, behave like normal

/obj/item/weapon/gun/projectile/automatic/manual/update_icon()
	icon_state = "[initial(icon_state)][cover_open ? "_open" : "closed"][ammo_magazine ? round(ammo_magazine.stored_ammo.len, 25) : "-empty"]"

/obj/item/weapon/gun/projectile/automatic/manual/load_ammo(var/obj/item/A, mob/user)
	if (!cover_open)
		user << SPAN_WARNING("You need to open the cover to load \the [src].")
		return
	..()

/obj/item/weapon/gun/projectile/automatic/manual/unload_ammo(mob/user, var/allow_dump=1)
	if (!cover_open)
		user << SPAN_WARNING("You need to open the cover to unload \the [src].")
		return
	..()

////////////////////////////MG34/////////////////////////////////////////
/obj/item/weapon/gun/projectile/automatic/manual/mg34
	name = "MG34"
	desc = "German light machinegun chambered in 7.92x57mm Mauser. An utterly devastating support weapon."
	icon_state = "mg34"
	item_state = "mg34"
	base_icon = "mg34"
	max_shells = 50
	caliber = "a792x57_weak"
	weight = 12.1
	slot_flags = SLOT_SHOULDER
	load_method = MAGAZINE
	magazine_type = /obj/item/ammo_magazine/mg34
	good_mags = list(/obj/item/ammo_magazine/mg34, /obj/item/ammo_magazine/mg34belt)
	ammo_type = /obj/item/ammo_casing/a792x57/weak
	unload_sound 	= 'sound/weapons/guns/interact/lmg_magout.ogg'
	reload_sound 	= 'sound/weapons/guns/interact/lmg_magin.ogg'
	cocked_sound 	= 'sound/weapons/guns/interact/lmg_cock.ogg'
	fire_sound = 	'sound/weapons/guns/fire/mg34.ogg'
	effectiveness_mod = 1.01

////////////////////////////Breda 30/////////////////////////////////////////
/obj/item/weapon/gun/projectile/automatic/breda30
	name = "Breda 30"
	desc = "The Fucile Mitragliatore Breda modello 30 is a Italian light machinegun that entered service in 1930. The design of the gun is rather impractical and often makes for long reload times. Chambered in 6.5x52mm Carcano."
	icon_state = "breda30"
	item_state = "mg34"
	base_icon = "breda30"
	max_shells = 20
	caliber = "a65x52"
	weight = 10.6
	slot_flags = SLOT_SHOULDER
	load_method = SINGLE_CASING | SPEEDLOADER
	magazine_type = /obj/item/ammo_magazine/breda30
	good_mags = list(/obj/item/ammo_magazine/breda30)
	ammo_type = /obj/item/ammo_casing/a65x52
	unload_sound 	= 'sound/weapons/guns/interact/lmg_magout.ogg'
	reload_sound 	= 'sound/weapons/guns/interact/breda30_clip.ogg'
	cocked_sound 	= 'sound/weapons/guns/interact/lmg_cock.ogg'
	fire_sound 		= 'sound/weapons/guns/fire/Type92.ogg'
	effectiveness_mod = 1.0
	load_delay = 2.5 SECONDS
	firemodes = list(
		list(name = "full auto", burst=1, burst_delay=3.5, move_delay=8, dispersion = list(0.7, 0.8, 1.0, 1.2, 1.4), recoil = 0),)
	var/cover_open = FALSE
	var/cover_open_sound = 'sound/weapons/guns/interact/breda30_open.ogg'
	var/cover_close_sound = 'sound/weapons/guns/interact/breda30_close.ogg'

/obj/item/weapon/gun/projectile/automatic/breda30/special_check(mob/user)
	if (cover_open)
		user << SPAN_WARNING("\The [src]'s magazine latch is open! Close it before firing!")
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/automatic/breda30/proc/toggle_cover(mob/user)
	if (do_after(user, 15, src, can_move = TRUE))
		cover_open ? playsound(loc, cover_close_sound, 100, TRUE) : playsound(loc, cover_open_sound, 100, TRUE)
		cover_open = !cover_open
		user << SPAN_NOTICE("You [cover_open ? "open" : "close"] \the [src]'s magazine latch.")
	update_icon()

/obj/item/weapon/gun/projectile/automatic/breda30/attack_self(mob/user as mob)
	toggle_cover(user)

/obj/item/weapon/gun/projectile/automatic/breda30/attack_hand(mob/user as mob)
	if (!cover_open && user.get_inactive_hand() == src)
		toggle_cover(user) //open the cover
	else
		return ..() //once open, behave like normal

/obj/item/weapon/gun/projectile/automatic/breda30/update_icon()
	icon_state = "[initial(icon_state)][cover_open ? "_open" : ""]"

/obj/item/weapon/gun/projectile/automatic/breda30/load_ammo(var/obj/item/A, mob/user)
	if (!cover_open)
		user << SPAN_WARNING("You need to open the cover to load \the [src].")
		return
	..()

/obj/item/weapon/gun/projectile/automatic/breda30/unload_ammo(mob/user, var/allow_dump=1)
	if (!cover_open)
		user << SPAN_WARNING("You need to open the magazine latch to unload \the [src].")
		return
	..()

///////////////////////////////////////////////////////////////////////////
/obj/item/weapon/gun/projectile/automatic/m60
	name = "M60"
	desc = "An american machinegun chambered in 7.62x51mm NATO rounds. Heavy and handles like a pig."
	icon_state = "m60"
	item_state = "m60"
	base_icon = "m60"
	caliber = "a762x51_weak"
	fire_sound = 'sound/weapons/guns/fire/M60.ogg'
	magazine_type = /obj/item/ammo_magazine/b762
	good_mags = list(/obj/item/ammo_magazine/b762)
	ammo_type = /obj/item/ammo_casing/a762x51/weak
	slot_flags = SLOT_SHOULDER
	weight = 10.5
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.3, move_delay=8, dispersion = list(0.7, 1.1, 1.3, 1.4, 1.5), recoil = 0),)
	equiptimer = 25
	load_delay = 50
	slowdown = 1
	effectiveness_mod = 1.04

/obj/item/weapon/gun/projectile/automatic/minimi
	name = "FN Minimi"
	desc = "A Belgian 5.56x45mm NATO light machine gun. It was developed by Ernest Vervier for FN Herstaland Introduced in the late 1970s."
	icon_state = "m249"
	item_state = "m249"
	base_icon = "m249"
	caliber = "a556x45"
	fire_sound = 'sound/weapons/guns/fire/minimi.ogg'
	magazine_type = /obj/item/ammo_magazine/m249
	good_mags = list(/obj/item/ammo_magazine/m249)
	ammo_type = /obj/item/ammo_casing/a556x45
	slot_flags = SLOT_SHOULDER
	weight = 7.1
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.1, move_delay=7, dispersion = list(0.6, 1, 1.2, 1.3, 1.3), recoil = 0),)
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE
	equiptimer = 25
	load_delay = 50
	slowdown = 1
	effectiveness_mod = 1.07

/obj/item/weapon/gun/projectile/automatic/m249
	name = "M249 SAW"
	desc = "An American variant of the Belgian FN Minimi machinegun chambered in 5.56x45mm NATO rounds. Sucessor of the M60."
	icon_state = "m249"
	item_state = "m249"
	base_icon = "m249"
	caliber = "a556x45"
	fire_sound = 'sound/weapons/guns/fire/minimi.ogg'
	magazine_type = /obj/item/ammo_magazine/m249
	good_mags = list(/obj/item/ammo_magazine/m249)
	ammo_type = /obj/item/ammo_casing/a556x45
	slot_flags = SLOT_SHOULDER
	weight = 7.47
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.1, move_delay=7, dispersion = list(0.6, 1, 1.2, 1.3, 1.3), recoil = 0),)
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE
	equiptimer = 25
	load_delay = 50
	slowdown = 1
	effectiveness_mod = 1.07

/obj/item/weapon/gun/projectile/automatic/m249/acog/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/advanced/acog/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/acog(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/automatic/pkm
	name = "PKM machine gun"
	desc = "A soviet machinegun chambered in 7.62x54mmR rounds."
	icon_state = "pkmp"
	item_state = "pkmp"
	base_icon = "pkmp"
	caliber = "a762x54_weak"
	magazine_type = /obj/item/ammo_magazine/pkm/c100
	good_mags = list(/obj/item/ammo_magazine/pkm/c100, /obj/item/ammo_magazine/maxim, /obj/item/ammo_magazine/pkm)
	ammo_type = /obj/item/ammo_casing/a762x54/weak
	weight = 7.5
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.3, move_delay=7, dispersion = list(0.7, 1.1, 1.3, 1.4, 1.6), recoil = 0),)
	slot_flags = SLOT_SHOULDER
	equiptimer = 25
	load_delay = 50
	slowdown = 0.8
	effectiveness_mod = 1.07

/obj/item/weapon/gun/projectile/automatic/rpd
	name = "RPD machine gun"
	desc = "A soviet machinegun chambered in 7.62x39 rounds."
	icon_state = "rpd"
	item_state = "rpd"
	base_icon = "rpd"
	caliber = "a762x39"
	magazine_type = /obj/item/ammo_magazine/rpd
	good_mags = list(/obj/item/ammo_magazine/rpd)
	ammo_type = /obj/item/ammo_casing/a762x39
	weight = 7.4
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.3, move_delay=6, dispersion = list(0.7, 1.1, 1.3, 1.4, 1.6), recoil = 0),)
	slot_flags = SLOT_SHOULDER
	equiptimer = 22
	load_delay = 40
	slowdown = 0.6
	effectiveness_mod = 1.05

/obj/item/weapon/gun/projectile/automatic/rpk74
	name = "RPK-74 machine gun"
	desc = "A soviet machinegun chambered in 5.45x39 rounds."
	icon_state = "rpk74"
	item_state = "rpk74"
	base_icon = "rpk74"
	caliber = "a545x39"
	magazine_type = /obj/item/ammo_magazine/rpk74
	good_mags = list(/obj/item/ammo_magazine/rpk74, /obj/item/ammo_magazine/rpk74/drum, /obj/item/ammo_magazine/ak74)
	weight = 5.1
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.3, move_delay=5, dispersion = list(0.7, 1.1, 1.3, 1.4, 1.6), recoil = 0),)
	slot_flags = SLOT_SHOULDER
	equiptimer = 20
	load_delay = 30
	slowdown = 0.5
	effectiveness_mod = 1.07

/obj/item/weapon/gun/projectile/automatic/rpk74/update_icon()
	if (ammo_magazine)
		if (istype(ammo_magazine, /obj/item/ammo_magazine/rpk74))
			item_state = "rpk74"
			icon_state = "rpk74"
		if (istype(ammo_magazine, /obj/item/ammo_magazine/rpk74/drum))
			icon_state = "rpk74_drum"
			item_state = "rpk74_drum"
			base_icon = "rpk74_drum"
		if (istype(ammo_magazine, /obj/item/ammo_magazine/ak74))
			icon_state = "rpk74_magak"
	else
		icon_state = "rpk74_open"
		item_state = "rpk74_open"
	update_held_icon()
	return

/obj/item/weapon/gun/projectile/automatic/rpk47
	name = "RPK-47 machine gun"
	desc = "A soviet machinegun chambered in 7.62x39 rounds."
	icon_state = "rpk47"
	item_state = "rpk47"
	base_icon = "rpk47"
	caliber = "a762x39"
	magazine_type = /obj/item/ammo_magazine/rpk47
	good_mags = list(/obj/item/ammo_magazine/rpk47, /obj/item/ammo_magazine/rpk47/drum, /obj/item/ammo_magazine/ak47)
	weight = 5.7
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.3, move_delay=4, dispersion = list(0.7, 1.1, 1.3, 1.4, 1.5), recoil = 0),)
	slot_flags = SLOT_SHOULDER
	equiptimer = 21
	load_delay = 26
	slowdown = 0.4
	effectiveness_mod = 1.03

/obj/item/weapon/gun/projectile/automatic/rpk47/update_icon()
	if (ammo_magazine)
		if (istype(ammo_magazine, /obj/item/ammo_magazine/rpk47))
			item_state = "rpk47"
			icon_state = "rpk47"
		if (istype(ammo_magazine, /obj/item/ammo_magazine/rpk47/drum))
			icon_state = "rpk47_drum"
		if (istype(ammo_magazine, /obj/item/ammo_magazine/ak47))
			icon_state = "rpk47_magak"
	else
		icon_state = "rpk47_open"
		item_state = "rpk47_open"
	update_held_icon()
	return

/obj/item/weapon/gun/projectile/automatic/rpk47/modern //too lazy to add in a new icon for now, will do it later
	effectiveness_mod = 1.07
	slowdown = 0.3
	equiptimer = 18
	load_delay = 19
	weight = 4.7
	name = "RPK-47M machine gun"
	desc = "A modernized Soviet machinegun chambered in 7.62x39 rounds."

/obj/item/weapon/gun/projectile/automatic/negev
	name = "IWI Negev"
	desc = "An israeli machinegun chambered in 5.56x45mm NATO rounds."
	icon_state = "negev"
	item_state = "negev"
	base_icon = "negev"
	caliber = "a556x45"
	magazine_type = /obj/item/ammo_magazine/negev
	good_mags = list(/obj/item/ammo_magazine/negev)
	slot_flags = SLOT_SHOULDER
	weight = 8
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=0.9, move_delay=7, dispersion = list(0.6, 1, 1.2, 1.3, 1.3), recoil = 0),)
	slot_flags = SLOT_SHOULDER
	equiptimer = 25
	load_delay = 50
	slowdown = 0.9
	effectiveness_mod = 1.01

/obj/item/weapon/gun/projectile/automatic/kord
	name = "Kord 6P50"
	desc = "A Soviet heavy machinegun, can also be as anti vehicle gun against some lightly armored vehicles. Uses 12.7x108mm rounds."
	icon_state = "nsvth"
	item_state = "nsvth"
	base_icon = "nsvth"
	caliber = "a127"
	magazine_type = /obj/item/ammo_magazine/ammo127
	good_mags = list(/obj/item/ammo_magazine/ammo127)
	weight = 12.5
	firemodes = list(
		list(name = "controlled burst",	burst=5, burst_delay=1.0, move_delay=4, recoil = 1, dispersion = list(0.9, 1.1, 1.2, 1.3, 1.3)),
		list(name = "semi",	burst=1, burst_delay=1.5, move_delay=3, recoil = 1,  dispersion = list(0.4, 1.1, 1.2, 1.3, 1.1)),
		)
	slot_flags = SLOT_SHOULDER
	equiptimer = 25
	load_delay = 55
	slowdown = 0.8
	effectiveness_mod = 0.85

/obj/item/weapon/gun/projectile/automatic/mg13
	name = "Maschinengewehr 13"
	desc = "German light machine chambered in 7.92x57mm rounds."
	icon_state = "mg13"
	item_state = "mg13"
	base_icon = "mg13"
	caliber = "a792x57_weak"
	magazine_type = /obj/item/ammo_magazine/mg13
	good_mags = list(/obj/item/ammo_magazine/mg13, /obj/item/ammo_magazine/mg08)
	weight = 9
	heavy = TRUE
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=1.3, move_delay=4, dispersion = list(0.7, 1.1, 1.3, 1.4, 1.5), recoil = 0),)
	slot_flags = SLOT_SHOULDER
	equiptimer = 21
	load_delay = 21
	slowdown = 0.5
	effectiveness_mod = 1.01

/obj/item/weapon/gun/projectile/automatic/mg13/update_icon()
	if (ammo_magazine)
		if (istype(ammo_magazine, /obj/item/ammo_magazine/mg08))
			item_state = "mg13_b"
			icon_state = "mg13_b"
		if (istype(ammo_magazine, /obj/item/ammo_magazine/mg13))
			item_state = "mg13"
			icon_state = "mg13"
	else
		icon_state = "mg13_open"
		item_state = "mg13_open"
	update_held_icon()
	return

/obj/item/weapon/gun/projectile/automatic/c6
	name = "C6 GPMG"
	desc = "A Canadian License Produced FN MAG called the C6 GPMG, the main squad support weapon of the CAF."
	icon_state = "c6"
	item_state = "c6"
	base_icon = "c6"
	max_shells = 220
	caliber = "a762x51"
	weight = 11.8
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a762x51
	load_method = MAGAZINE
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	magazine_type = /obj/item/ammo_magazine/c6belt
	good_mags = list(/obj/item/ammo_magazine/c6belt, /obj/item/ammo_magazine/c6can)
	unload_sound 	= 'sound/weapons/guns/interact/lmg_magout.ogg'
	reload_sound 	= 'sound/weapons/guns/interact/lmg_magin.ogg'
	cocked_sound 	= 'sound/weapons/guns/interact/lmg_cock.ogg'
	fire_sound = 'sound/weapons/guns/fire/M60.ogg'
	effectiveness_mod = 1.07

/obj/item/weapon/gun/projectile/automatic/c6/update_icon()
	if (ammo_magazine)
		icon_state = "[base_icon]_can[ammo_magazine ? round(ammo_magazine.stored_ammo.len, 25) : "0"]"
		item_state = base_icon
	else
		icon_state = "[base_icon]_open"
		item_state = "[base_icon]_open"
	update_held_icon()
