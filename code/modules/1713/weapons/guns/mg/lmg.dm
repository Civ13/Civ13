
/obj/item/weapon/gun/projectile/automatic
	gtype = "mg"
	icon = 'icons/obj/guns/mgs.dmi'
	force = 15
	throwforce = 30
	base_icon = "automatic"
	equiptimer = 28
	load_delay = 12
	gun_safety = TRUE
	slowdown = 0.5

	accuracy = 3
	recoil = 50

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
	attachment_slots = ATTACH_BARREL|ATTACH_IRONSIGHTS
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=0.8),
	)
	var/jammed_until = -1
	var/jamcheck = 0
	var/last_fire = -1

	var/obj/structure/bed/chair/mgunner/mount = null

	can_tactical_reload = TRUE

/obj/item/weapon/gun/projectile/automatic/Fire(atom/target, mob/living/user, clickparams=null, pointblank=0, reflex=0, forceburst = -1, force = FALSE, accuracy_mod = 1)
	if (mount)
		var/turf/firing_turf = get_turf(mount)
		var/turf/target_turf = get_turf(target)
		var/dx = target_turf.x - firing_turf.x
		var/dy = target_turf.y - firing_turf.y
		var/shot_angle = Atan2(dx, dy)
		if (shot_angle < 0)
			shot_angle = 180 + (180 - abs(shot_angle))
		var/shot_dir = EAST
		if(shot_angle >= 45 && shot_angle < 135)
			shot_dir = NORTH
		else if(shot_angle >= 135 && shot_angle < 225)
			shot_dir = WEST
		else if(shot_angle >= 225 && shot_angle < 315)
			shot_dir = SOUTH
		if(mount.dir != shot_dir)
			return
	..()

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
	weight = 9.12
	force = 20
	throwforce = 30
	slot_flags = SLOT_SHOULDER
	recoil = 40
	accuracy = 3

/obj/item/weapon/gun/projectile/automatic/type99
	name = "Type 99 light machinegun"
	desc = "The Type 99 light machine Gun, is a Japanese light machine gun refitted to fit the new 7.7x58mm cartridge rather than the old 6.50x50mm rounds."
	icon_state = "type99lmg"
	item_state = "type99lmg"
	base_icon = "type99lmg"
	caliber = "a77x58"
	magazine_type = /obj/item/ammo_magazine/type99
	good_mags = list(/obj/item/ammo_magazine/type99)
	weight = 9.12
	force = 20
	throwforce = 30
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	slowdown = 0.2
	scope_mounts = list("type99_cronstein")
//	has_telescopic = TRUE
	slot_flags = SLOT_SHOULDER
/obj/item/weapon/gun/projectile/automatic/type99/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/type99/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope/type99(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/automatic/type99/type97tank
	name = "Type 97 tank machinegun"
	desc = "The Type 97 tank machine Gun, is a Japanese machine gun based on the ZB26 designed specifically for tank use."
	scope_mounts = list("type97_tank")
	magazine_type = /obj/item/ammo_magazine/type99/type97
	good_mags = list(/obj/item/ammo_magazine/type99/type97)
	icon_state = "type97lmg"
	item_state = "type99lmg"
	base_icon = "type97lmg"

/obj/item/weapon/gun/projectile/automatic/type99/type97tank/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/type97tank/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope/type97tank(src)
	SP.attached(null,src,TRUE)

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
	weight = 9.0
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	slowdown = 0.2
//	has_telescopic = TRUE
	scope_mounts = list("type99_cronstein")
	slot_flags = SLOT_SHOULDER
	firemodes = list(
		list(name = "automatic",	burst=1, burst_delay=0.4, move_delay=4, dispersion = list(0.2, 0.1, 0.4, 0.6, 0.2), recoil = 0))

/obj/item/weapon/gun/projectile/automatic/type96/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/type99/type96/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope/type99/type96(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/automatic/dp28
	name = "DP-28"
	desc = "The DP-28 light machinegun. This one is in 7.62x54mmR."
	icon_state = "dp"
	item_state = "dp"
	base_icon = "dp"
	caliber = "a762x54_weak"
	fire_sound = 'sound/weapons/guns/fire/DP28.ogg'
	magazine_type = /obj/item/ammo_magazine/dp
	good_mags = list(/obj/item/ammo_magazine/dp, /obj/item/ammo_magazine/dp/dt)
	slot_flags = SLOT_SHOULDER
	weight = 9.12
	force = 20
	throwforce = 30
	bad_magazine_types = list(/obj/item/ammo_magazine/maxim)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1.3),
	)
	recoil = 40
	accuracy = 3
	var/folded = FALSE

/obj/item/weapon/gun/projectile/automatic/dp28/dt28
	name = "DT-28"
	desc = "The DT-28 light machinegun. Designed to be places in vehicles. This one is in 7.62x54mmR."
	icon_state = "dt"
	item_state = "dt"
	base_icon = "dt"

/obj/item/weapon/gun/projectile/automatic/dp28/dt28/update_icon()
	..()
	if (folded)
		icon_state = "[base_icon]_folded"
	else
		icon_state = "[base_icon]"

/obj/item/weapon/gun/projectile/automatic/dp28/dt28/verb/fold()
	set name = "Toggle Stock"
	set category = null
	set src in usr
	if (folded)
		folded = FALSE
		recoil *= 1.5
		icon_state = "[base_icon]_folded"
		usr << "You extend the stock on \the [src]."
		equiptimer = 15
		set_stock()
		update_icon()
	else
		recoil /= 1.5
		folded = TRUE
		icon_state = "[base_icon]"
		usr << "You collapse the stock on \the [src]."
		equiptimer = 7
		set_stock()
		update_icon()

/obj/item/weapon/gun/projectile/automatic/dp28/dt28/proc/set_stock()
	if (folded)
		slot_flags = SLOT_SHOULDER|SLOT_BELT
	else
		slot_flags = SLOT_SHOULDER

/obj/item/weapon/gun/projectile/automatic/dp28/dt28/dtm28
	name = "DTM-28"
	desc = "The DTM-28 light machinegun. Designed to be places in vehicles. This one is in 7.62x54mmR."
	icon_state = "dtm"
	base_icon = "dtm"
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE
	scope_mounts = list("dt_mount")
	New()
		..()
		var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pu/ppu8/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pu/ppu8(src)
		SP.attached(null,src,TRUE)
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
	weight = 9.12
	force = 20
	throwforce = 30
	bad_magazine_types = list(/obj/item/ammo_magazine/browning)
	recoil = 40
	accuracy = 3

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
	weight = 12.50 //heavy piece of shit
	force = 20
	throwforce = 30

/obj/item/weapon/gun/projectile/automatic/browning_lmg/update_icon()
	..()
	if (!ammo_magazine)
		return
	overlays -= mag_image
	mag_image = image(icon = 'icons/obj/guns/parts.dmi', loc = src, icon_state = ammo_magazine.attached_icon_state + "[round(ammo_magazine.stored_ammo.len, 25)]", pixel_x = mag_x_offset, pixel_y = mag_y_offset)
	overlays += mag_image

////////////////////////////Manual Machine guns/////////////////////////////////////////
/obj/item/weapon/gun/projectile/automatic/manual
	var/cover_open = FALSE
	var/cover_toggle_time = 2
	var/cover_open_sound = 'sound/weapons/guns/interact/lmg_open.ogg'
	var/cover_close_sound = 'sound/weapons/guns/interact/lmg_close.ogg'

/obj/item/weapon/gun/projectile/automatic/manual/special_check(mob/user)
	if (cover_open && !istype(loc, /obj/structure/turret))
		to_chat(user, SPAN_WARNING("\The [src]'s cover is open! Close it before firing!"))
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/automatic/manual/proc/toggle_cover(mob/user)
	if (do_after(user, cover_toggle_time, src, can_move = TRUE, needhand = FALSE))
		cover_open ? playsound(loc, cover_close_sound, 100, TRUE) : playsound(loc, cover_open_sound, 100, TRUE)
		cover_open = !cover_open
		to_chat(user, SPAN_NOTICE("You [cover_open ? "open" : "close"] \the [src]'s cover."))
	update_icon()

/obj/item/weapon/gun/projectile/automatic/manual/attack_self(mob/user as mob)
	toggle_cover(user) //close the cover

/obj/item/weapon/gun/projectile/automatic/manual/attack_hand(mob/user as mob)
	if (!cover_open && user.get_inactive_hand() == src)
		toggle_cover(user) //open the cover
	else
		return ..() //once open, behave like normal

/obj/item/weapon/gun/projectile/automatic/manual/update_icon()
	..()
	if (cover_open)
		icon_state = "[base_icon]_open"
	else
		icon_state = "[base_icon]"
	if (!ammo_magazine || !istype(ammo_magazine, /obj/item/ammo_magazine/mg34belt) || !istype(ammo_magazine, /obj/item/ammo_magazine/mg3belt))
		return
	overlays -= mag_image
	mag_image = image(icon = 'icons/obj/guns/parts.dmi', loc = src, icon_state = ammo_magazine.attached_icon_state + "[round(ammo_magazine.stored_ammo.len, 25)]", pixel_x = mag_x_offset, pixel_y = mag_y_offset)
	overlays += mag_image

/obj/item/weapon/gun/projectile/automatic/manual/load_ammo(var/obj/item/A, mob/user)
	if (!cover_open && !istype(loc, /obj/structure/turret))
		to_chat(user, SPAN_WARNING("You need to open the cover to load \the [src]."))
		return
	..()

/obj/item/weapon/gun/projectile/automatic/manual/unload_ammo(mob/user, var/allow_dump=1)
	if (!cover_open && !istype(loc, /obj/structure/turret))
		to_chat(user, SPAN_WARNING("You need to open the cover to unload \the [src]."))
		return
	..()

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
	ammo_type = /obj/item/ammo_casing/a792x57/weak
	load_method = MAGAZINE
	magazine_type = /obj/item/ammo_magazine/mg34
	good_mags = list(/obj/item/ammo_magazine/mg34, /obj/item/ammo_magazine/mg34belt)
	unload_sound 	= 'sound/weapons/guns/interact/lmg_magout.ogg'
	reload_sound 	= 'sound/weapons/guns/interact/lmg_magin.ogg'
	cocked_sound 	= 'sound/weapons/guns/interact/lmg_cock.ogg'
	fire_sound = 	'sound/weapons/guns/fire/mg34.ogg'
	load_delay = 12
	force = 20
	throwforce = 30
	recoil = 40
	accuracy = 3
	mag_x_offset = -5
	mag_y_offset = -3

/obj/item/weapon/gun/projectile/automatic/manual/m249
	name = "M249 SAW"
	desc = "An American variant of the Belgian FN Minimi machinegun chambered in 5.56x45mm NATO rounds. Sucessor of the M60."
	icon_state = "m249"
	item_state = "m249"
	base_icon = "m249"
	caliber = "a556x45"
	fire_sound = 'sound/weapons/guns/fire/minimi.ogg'
	magazine_type = /obj/item/ammo_magazine/m249
	good_mags = list(/obj/item/ammo_magazine/m249)
	slot_flags = SLOT_SHOULDER
	weight = 10
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1.1),
	)
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_UNDER
	force = 20
	nothrow = TRUE
	throwforce = 30
	equiptimer = 25
	load_delay = 10
	slowdown = 1
	recoil = 30
	accuracy = 1
	scope_mounts = list ("picatinny")
	scope_y_offset = -1

/obj/item/weapon/gun/projectile/automatic/manual/m249/acog/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/acog/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope/acog(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/automatic/manual/m249/suppressor/New()
	..()
	if(prob(50))
		var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/acog/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope/acog(src)
		SP.attached(null,src,TRUE)
	else
		var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/elcan/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope/elcan(src)
		SP.attached(null,src,TRUE)

	if(prob(50))
		var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
		FP.attached(null,src,TRUE)
	else
		var/obj/item/weapon/attachment/under/laser/LS = new/obj/item/weapon/attachment/under/laser(src)
		LS.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/automatic/manual/mg34/mg3
	name = "MG3"
	desc = "Modern German light machinegun chambered in 7.62x51mm. An utterly devastating support weapon."
	icon_state = "mg3"
	base_icon = "mg3"
	caliber = "a762x51_weak"
	ammo_type = /obj/item/ammo_casing/a762x51/weak
	magazine_type = /obj/item/ammo_magazine/mg3belt
	good_mags = list(/obj/item/ammo_magazine/mg3belt)
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE
	load_delay = 12
	recoil = 30
	scope_mounts = list ("picatinny")
	scope_x_offset = 7
	scope_y_offset = 4
	under_mounts = list ("picatinny")
	under_x_offset = 7
	under_y_offset = 4

/obj/item/weapon/gun/projectile/automatic/manual/mg34/mg3/tactical/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/acog/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope/acog(src)
	SP.attached(null,src,TRUE)

	if (prob(50))
		var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
		FP.attached(null,src,TRUE)
	else
		var/obj/item/weapon/attachment/under/laser/LS = new/obj/item/weapon/attachment/under/laser(src)
		LS.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/automatic/manual/rpd
	name = "RPD machine gun"
	desc = "A soviet machinegun chambered in 7.62x39 rounds."
	icon_state = "rpd"
	item_state = "rpd"
	base_icon = "rpd"
	caliber = "a762x39"
	magazine_type = /obj/item/ammo_magazine/rpd
	good_mags = list(/obj/item/ammo_magazine/rpd)
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	weight = 7.4
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1.3),
	)
	slot_flags = SLOT_SHOULDER
	force = 20
	nothrow = TRUE
	throwforce = 30
	equiptimer = 22
	load_delay = 40
	slowdown = 0.6
	recoil = 30
	accuracy = 2
	scope_x_offset = -4
	scope_y_offset = -5
	barrel_x_offset = 14
	barrel_y_offset = 17
	scope_mounts = list ("dovetail")

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
	equiptimer = 20
	slot_flags = SLOT_SHOULDER
	load_method = SINGLE_CASING | SPEEDLOADER
	magazine_type = /obj/item/ammo_magazine/breda30
	good_mags = list(/obj/item/ammo_magazine/breda30)
	ammo_type = /obj/item/ammo_casing/a65x52
	unload_sound 	= 'sound/weapons/guns/interact/lmg_magout.ogg'
	reload_sound 	= 'sound/weapons/guns/interact/breda30_clip.ogg'
	cocked_sound 	= 'sound/weapons/guns/interact/lmg_cock.ogg'
	fire_sound 		= 'sound/weapons/guns/fire/Type92.ogg'
	load_delay = 12
	recoil = 40
	accuracy = 3
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=3.0, move_delay=8, dispersion = list(0.2, 0.3, 0.5, 0.8, 0.6), recoil = 0))
	var/cover_open = FALSE
	var/cover_open_sound = 'sound/weapons/guns/interact/breda30_open.ogg'
	var/cover_close_sound = 'sound/weapons/guns/interact/breda30_close.ogg'

/obj/item/weapon/gun/projectile/automatic/breda30/special_check(mob/user)
	if (cover_open)
		user << SPAN_WARNING("\The [src]'s magazine latch is open! Close it before firing!")
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/automatic/breda30/proc/toggle_cover(mob/user)
	if (do_after(user, 12, src, can_move = TRUE))
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
	slot_flags = SLOT_SHOULDER
	weight = 10.5
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1.3),
	)
	force = 20
	nothrow = TRUE
	throwforce = 30
	equiptimer = 25
	load_delay = 50
	slowdown = 1
	recoil = 40
	accuracy = 3

/obj/item/weapon/gun/projectile/automatic/pkm
	name = "PKM machine gun"
	desc = "A soviet machinegun chambered in 7.62x54mmR rounds."
	icon_state = "pkmp"
	item_state = "pkmp"
	base_icon = "pkmp"
	caliber = "a762x54_weak"
	magazine_type = /obj/item/ammo_magazine/pkm/c100
	good_mags = list(/obj/item/ammo_magazine/pkm/c100, /obj/item/ammo_magazine/maxim, /obj/item/ammo_magazine/pkm)
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	weight = 7.5
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1.3),
	)
	slot_flags = SLOT_SHOULDER
	force = 20
	nothrow = TRUE
	throwforce = 30
	equiptimer = 25
	load_delay = 50
	slowdown = 0.8
	recoil = 40
	accuracy = 3
	mag_x_offset = -3
	mag_y_offset = 1
	barrel_y_offset = 17
	scope_x_offset = -1
	scope_y_offset = -3
	scope_mounts = list ("dovetail")

/obj/item/weapon/gun/projectile/automatic/pkm/update_icon()
	..()
	if (!ammo_magazine)
		icon_state = "[base_icon]_open"
	else
		icon_state = "[base_icon]"

/obj/item/weapon/gun/projectile/automatic/pkm/pkp
	name = "PKP machine gun"
	desc = "A modernized soviet PKM machinegun chambered in 7.62x54mmR rounds."
	icon_state = "pkp"
	base_icon = "pkp"
	recoil = 25
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_UNDER|ATTACH_SCOPE|ATTACH_BARREL
	scope_mounts = list ("dovetail", "picatinny")
	under_mounts = list ("picatinny")
	under_x_offset = 3
	under_y_offset = 2

/obj/item/weapon/gun/projectile/automatic/pkm/pkp/devastator/New()
	..()
	if (prob(50))
		var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pso4/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pso4(src)
		SP.attached(null,src,TRUE)

	if (prob(50))
		var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
		FP.attached(null,src,TRUE)
	else
		var/obj/item/weapon/attachment/under/laser/LS = new/obj/item/weapon/attachment/under/laser(src)
		LS.attached(null,src,TRUE)



/obj/item/weapon/gun/projectile/automatic/rpk74
	name = "RPK-74 machine gun"
	desc = "A soviet machinegun chambered in 5.45x39 rounds."
	icon_state = "rpk74"
	item_state = "rpk74"
	base_icon = "rpk74"
	caliber = "a545x39"
	magazine_type = /obj/item/ammo_magazine/rpk74
	good_mags = list(/obj/item/ammo_magazine/rpk74, /obj/item/ammo_magazine/rpk74/drum, /obj/item/ammo_magazine/ak74, /obj/item/ammo_magazine/ak74/ak74m)
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	weight = 5.1
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1.3),
	)
	slot_flags = SLOT_SHOULDER
	force = 20
	nothrow = TRUE
	throwforce = 30
	equiptimer = 20
	load_delay = 8
	slowdown = 0.5
	recoil = 25
	accuracy = 2
	scope_x_offset = -1
	scope_y_offset = -1
	scope_mounts = list ("dovetail")

/obj/item/weapon/gun/projectile/automatic/rpk74/rpk16
	name = "RPK-16 machine gun"
	desc = "A modernized russian RPK-74 machinegun chambered in 5.45x39 rounds."
	icon_state = "rpk16"
	base_icon = "rpk16"
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_UNDER|ATTACH_SCOPE|ATTACH_BARREL
	recoil = 20
	accuracy = 2
	scope_mounts = list ("dovetail", "picatinny")
	under_mounts = list ("picatinny")
	mag_y_offset = -1
	under_x_offset = 1
	under_y_offset = 1

/obj/item/weapon/gun/projectile/automatic/rpk74/rpk16/suppressor/New()
	..()
	if (prob(50))
		var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pso4/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pso4(src)
		SP.attached(null,src,TRUE)
	else
		var/obj/item/weapon/attachment/scope/adjustable/advanced/holographic/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/holographic(src)
		SP.attached(null,src,TRUE)

	if (prob(50))
		var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
		FP.attached(null,src,TRUE)
	else
		var/obj/item/weapon/attachment/under/laser/LS = new/obj/item/weapon/attachment/under/laser(src)
		LS.attached(null,src,TRUE)

	var/obj/item/weapon/attachment/silencer/rifle/pbs4/SL = new/obj/item/weapon/attachment/silencer/rifle/pbs4(src)
	SL.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/automatic/rpk47
	name = "RPK-47 machine gun"
	desc = "A soviet machinegun chambered in 7.62x39 rounds."
	icon_state = "rpk47"
	item_state = "rpk47"
	base_icon = "rpk47"
	caliber = "a762x39"
	magazine_type = /obj/item/ammo_magazine/rpk47
	good_mags = list(/obj/item/ammo_magazine/rpk47, /obj/item/ammo_magazine/rpk47/drum, /obj/item/ammo_magazine/ak47)
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	weight = 5.7
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1.3),
	)
	slot_flags = SLOT_SHOULDER
	force = 20
	nothrow = TRUE
	throwforce = 30
	equiptimer = 21
	load_delay = 8
	slowdown = 0.4
	recoil = 35
	accuracy = 3
	scope_x_offset = -1
	scope_y_offset = -1
	scope_mounts = list ("dovetail")

/obj/item/weapon/gun/projectile/automatic/rpk47/modern
	slowdown = 0.3
	equiptimer = 18
	load_delay = 19
	weight = 4.7
	name = "RPK-47M machine gun"
	desc = "A modernized Soviet machinegun chambered in 7.62x39 rounds."
	recoil = 30
	accuracy = 3

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
		list(name = "automatic", burst=1, burst_delay=0.9),
	)
	slot_flags = SLOT_SHOULDER
	force = 20
	nothrow = TRUE
	throwforce = 30
	equiptimer = 25
	load_delay = 50
	slowdown = 0.9
	recoil = 40
	accuracy = 3
	scope_mounts = list ("picatinny")

/obj/item/weapon/gun/projectile/automatic/negev/update_icon()
	..()
	if (!ammo_magazine)
		icon_state = "[base_icon]_open"
	else
		icon_state = "[base_icon]"

///NSVT//////////////

/obj/item/weapon/gun/projectile/automatic/nsv_utes
	name = "NSV Utes"
	desc = "A Soviet heavy machinegun, can also be as anti vehicle gun against some lightly armored vehicles. Uses 12.7x108mm rounds."
	fire_sound = 'sound/weapons/guns/fire/ptrd.ogg'
	icon_state = "nsvth"
	item_state = "nsvth"
	base_icon = "nsvth"
	caliber = "a127"
	magazine_type = /obj/item/ammo_magazine/ammo127
	good_mags = list(/obj/item/ammo_magazine/ammo127)
	weight = 12.5
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1.8),
	)
	shake_strength = 1
	slot_flags = SLOT_SHOULDER
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE
	force = 20
	nothrow = TRUE
	throwforce = 25
	equiptimer = 25
	load_delay = 55
	slowdown = 0.8
	recoil = 60
	accuracy = 1
	scope_mounts = list ("dovetail")
	scope_x_offset = -1
	scope_y_offset = -4
	mag_x_offset = -5
	mag_y_offset = -2
	New()
		..()
		var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pso4/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pso4(src)
		SP.attached(null,src,TRUE)
////////////////////////MG13////////////////////////////////

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
		list(name = "automatic", burst=1, burst_delay=1.3),
	)
	slot_flags = SLOT_SHOULDER
	force = 20
	nothrow = TRUE
	throwforce = 30
	equiptimer = 21
	load_delay = 21
	slowdown = 0.5
	recoil = 40
	accuracy = 3
	mag_x_offset = -5
	mag_x_offset = -3

/obj/item/weapon/gun/projectile/automatic/mg13/update_icon()
	..()
	if (!ammo_magazine || !istype(ammo_magazine, /obj/item/ammo_magazine/mg08))
		return
	overlays -= mag_image
	mag_image = image(icon = 'icons/obj/guns/parts.dmi', loc = src, icon_state = ammo_magazine.attached_icon_state + "[round(ammo_magazine.stored_ammo.len, 25)]", pixel_x = mag_x_offset, pixel_y = mag_y_offset)
	overlays += mag_image

////////////////////////C6 GPMG/////////////////////////////

/obj/item/weapon/gun/projectile/automatic/manual/c6
	name = "C6 GPMG"
	desc = "A Canadian License Produced FN MAG called the C6 GPMG, the main squad support weapon of the CAF."
	icon_state = "c6"
	item_state = "c6"
	base_icon = "c6"
	max_shells = 220
	caliber = "a762x51"
	weight = 8.1
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a762x51
	load_method = MAGAZINE
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	magazine_type = /obj/item/ammo_magazine/c6belt
	good_mags = list(/obj/item/ammo_magazine/c6belt, /obj/item/ammo_magazine/c6can)
	unload_sound 	= 'sound/weapons/guns/interact/lmg_magout.ogg'
	reload_sound 	= 'sound/weapons/guns/interact/lmg_magin.ogg'
	cocked_sound 	= 'sound/weapons/guns/interact/lmg_cock.ogg'
	fire_sound = 'sound/weapons/guns/fire/M60.ogg'
	force = 20
	throwforce = 30
	recoil = 40
	accuracy = 1
	scope_mounts = list ("picatinny")
	mag_x_offset = -4
	mag_y_offset = -2
	equiptimer = 25
	load_delay = 10
	slowdown = 1

/obj/item/weapon/gun/projectile/automatic/manual/c6/update_icon()
	..()
	if (!ammo_magazine || !istype(ammo_magazine, /obj/item/ammo_magazine/c6belt))
		return
	overlays -= mag_image
	mag_image = image(icon = 'icons/obj/guns/parts.dmi', loc = src, icon_state = ammo_magazine.attached_icon_state + "[round(ammo_magazine.stored_ammo.len, 25)]", pixel_x = mag_x_offset, pixel_y = mag_y_offset)
	overlays += mag_image