/////This is for the painful lmg called the type 11 that will surely be a gigantic pain in the ass to code - shinobi
/////Other coding abominations of MG's are indeed permitted to go here
/*
/obj/item/weapon/gun/projectile/automatic/hopper
	gtype = "mg"
	icon = 'icons/obj/guns/mgs.dmi'
	force = 15
	throwforce = 30
	base_icon = "automatic"
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
			SHORT_RANGE_STILL = 70,
			SHORT_RANGE_MOVING = 61,

			MEDIUM_RANGE_STILL = 51,
			MEDIUM_RANGE_MOVING = 42,

			LONG_RANGE_STILL = 30,
			LONG_RANGE_MOVING = 27,

			VERY_LONG_RANGE_STILL = 15,
			VERY_LONG_RANGE_MOVING = 14),
	)

	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 2.00
	KD_chance = KD_CHANCE_MEDIUM
	good_mags = list() //List of extra compatible mags
	bad_magazine_types = list(/obj/item/ammo_magazine) // list of magazine types that we can't use
	ammo_magazine = list() //stored magazine
	stat = "machinegun"
	w_class = ITEM_SIZE_HUGE
	heavy = TRUE
	load_method = MAGAZINE
	slot_flags = SLOT_SHOULDER
	sel_mode = 1
	full_auto = TRUE
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=0.8, move_delay=8, dispersion = list(0.7, 1.1, 1.1, 1.1, 1.3), recoil = 0),)

	jammed_until = -1
	jamcheck = 0
	last_fire = -1

/obj/item/weapon/gun/projectile/automatic/hopper/New()
	serial = "[pick(alphabet_uppercase)][pick(alphabet_uppercase)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)]"
	..()
	if (map && map.civilizations)
		loaded = list()
		chambered = null
	else if (!(istype(loc, /mob/living)))
		loaded = list()
		chambered = null
	else
		if (ispath(ammo_type) && ((load_method & (SINGLE_CASING|SPEEDLOADER)) || istype(src, /obj/item/weapon/gun/projectile/shotgun)))
			for (var/i in TRUE to max_shells)
				loaded += new ammo_type(src)
		if (ispath(magazine_type) && (load_method & MAGAZINE))
			ammo_magazine[1] = new magazine_type(src)

	update_icon()
	if (is_hmg == TRUE && has_telescopic == FALSE)
		var/obj/item/weapon/attachment/scope/iron_sights/mg/A = new /obj/item/weapon/attachment/scope/iron_sights/mg(src)
		spawn_add_attachment(A, src)
	else if (has_telescopic == TRUE)
		var/obj/item/weapon/attachment/scope/iron_sights/mg/type99/A = new /obj/item/weapon/attachment/scope/iron_sights/mg/type99(src)
		spawn_add_attachment(A, src)
	else
		var/obj/item/weapon/attachment/A = new /obj/item/weapon/attachment/scope/iron_sights(src)
		spawn_add_attachment(A, src)

/obj/item/weapon/gun/projectile/automatic/get_weight()
	. = ..()
	if (ammo_magazine[1])
		.+= ammo_magazine[1].get_weight()
	return .

/obj/item/weapon/gun/projectile/automatic/hopper/update_icon()
	if (ammo_magazine)
		icon_state = base_icon
	else
		icon_state = "[base_icon]_open"
	update_held_icon()
	return

/obj/item/weapon/gun/projectile/automatic/hopper/special_check(mob/user)
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

/obj/item/weapon/gun/projectile/automatic/hopper/has_next_projectile()

	// get the next casing
	if (loaded.len)
		return TRUE

	// get the ammo mag's next casing
	else if (ammo_magazine[1] && ammo_magazine[1].stored_ammo.len)
		return TRUE

	return FALSE


/obj/item/weapon/gun/projectile/automatic/hopper/consume_next_projectile(var/check = FALSE)
	//get the next casing
	if (loaded.len)
		chambered = loaded[1] //load next casing.
		if (handle_casings != HOLD_CASINGS)
			loaded -= chambered
			if (infinite_ammo)
				loaded += new chambered.type

	else if (ammo_magazine && ammo_magazine.stored_ammo.len)
		chambered = ammo_magazine[1].stored_ammo[1]
		if (handle_casings != HOLD_CASINGS)
			ammo_magazine[1].stored_ammo -= chambered
			if (infinite_ammo)
				ammo_magazine[1].stored_ammo += new chambered.type

	if (chambered)
		if (gibs)
			chambered.BB.gibs = TRUE
		if (crushes)
			chambered.BB.crushes = TRUE
		return chambered.BB
	return null

/obj/item/weapon/gun/projectile/automatic/hopper/process_chambered()
	if (!chambered) return

	// Aurora forensics port, gunpowder residue.
	if (chambered.leaves_residue)
		var/mob/living/human/H = loc
		if (istype(H))
			if (!H.gloves)
				H.gunshot_residue = chambered.name
			else
				var/obj/item/clothing/G = H.gloves
				G.gunshot_residue = chambered.name

	#define DISABLE_CASINGS // goodbye lag (EXPERIMENTAL) - Kachnov

	switch(handle_casings)
		if (EJECT_CASINGS) //eject casing onto ground.
			#ifndef DISABLE_CASINGS
			chambered.loc = get_turf(src)
			chambered.randomrotation()
			#endif

			playsound(loc, casing_sound, 50, TRUE)

		if (CYCLE_CASINGS) //cycle the casing back to the end.
			if (ammo_magazine[1])
				ammo_magazine[1].stored_ammo += chambered
			else
				loaded += chambered

		if (REMOVE_CASINGS) //deletes the casing (arrows, for example, where the casing is effectively the projectile)
			qdel(chambered)
			chambered = null

	if (handle_casings != HOLD_CASINGS)
		chambered = null

//Attempts to load A into src, depending on the type of thing being loaded and the load_method
//Maybe this should be broken up into separate procs for each load method?
/mob/next_load = -1
/obj/item/weapon/gun/projectile/automatic/hopper/load_ammo(var/obj/item/A, mob/user)

	if (world.time < user.next_load)
		return

	if (load_delay && !do_after(user, load_delay, src, can_move = TRUE))
		return

	user.next_load = world.time + 1

	// special scenario: A is an ammo box, src is a PTRD or something
	// turn A from the ammo magazine to the first bullet in the ammo magazine
	if (istype(A, /obj/item/ammo_magazine) && (A.vars.Find("is_box") == TRUE && A:is_box && A:ammo_type == ammo_type))
		var/obj/item/ammo_magazine/AM = A
		if (AM.stored_ammo.len)
			A = AM.stored_ammo[1]
			return load_ammo(A, user)

	else if (istype(A, /obj/item/ammo_magazine))
		var/obj/item/ammo_magazine/AM = A

		if (!(load_method & AM.mag_type) || (caliber != AM.caliber && !AM in src.good_mags))
			return // incompatible
		if (bad_magazine_types.Find(AM.type))
			return //incompatible
		else if (!(load_method & AM.mag_type != SPEEDLOADER) && !good_mags.Find(AM.type))
			return // incompatible

		switch(AM.mag_type)
			if (MAGAZINE)
				if (AM.ammo_mag != ammo_mag && ammo_mag != "default")
					user << "<span class='warning'>[src] requires another magazine.</span>" //wrong magazine
					return
				if (ammo_magazine[6])
					user << "<span class='warning'>[src] already has 6 clips loaded.</span>" //already a magazine here
					return
				user.remove_from_mob(AM)
				if (src.is_laser_mg == TRUE)
					AM.loc = user.back
					ammo_magazine = AM
				else
					AM.loc = src
					ammo_magazine = AM

				if (reload_sound) playsound(loc, reload_sound, 75, TRUE)
				cock_gun(user)
			if (SPEEDLOADER)
				if (loaded.len >= max_shells)
					user << "<span class='warning'>[src] is full!</span>"
					return
				var/count = FALSE
				for (var/obj/item/ammo_casing/C in AM.stored_ammo)
					if (loaded.len >= max_shells)
						break
					if (C.caliber == caliber)
						C.loc = src
						loaded += C
						AM.stored_ammo -= C //should probably go inside an ammo_magazine proc, but I guess less proc calls this way...
						count++
				if (count)
					user.visible_message("[user] reloads [src].", "<span class='notice'>You load [count] round\s into \the [src].</span>")
					if (reload_sound) playsound(loc, reload_sound, 75, TRUE)
					cock_gun(user)
		AM.update_icon()

	else if (istype(A, /obj/item/ammo_casing))
		var/obj/item/ammo_casing/C = A
		if (!(load_method & SINGLE_CASING))
			user << "<span class='warning'>You can't load \the [src] with a single casing!</span>"
			return
		if (caliber != C.caliber)
			user << "<span class='warning'>\The [C] is of the wrong caliber!</span>"
			return //incompatible
		if (loaded.len >= max_shells)
			user << "<span class='warning'>[src] is full.</span>"
			return

		user.remove_from_mob(C)
		C.loc = src
		loaded.Insert(1, C) //add to the head of the list
		user.visible_message("[user] inserts \a [C] into [src].", "<span class='notice'>You insert \a [C] into [src].</span>")
		if (bulletinsert_sound) playsound(loc, bulletinsert_sound, 75, TRUE)

	update_icon()

//attempts to unload  If allow_dump is set to FALSE, the speedloader unloading method will be disabled
/obj/item/weapon/gun/projectile/automatic/hopper/unload_ammo(mob/user, var/allow_dump=1)
	if (ammo_magazine[1])
		user.put_in_hands(ammo_magazine[1])

		if (unload_sound) playsound(loc, unload_sound, 75, TRUE)
		ammo_magazine[1].update_icon()
		ammo_magazine[1] = ammo_magazine[2]
	else if (loaded.len)
		//presumably, if it can be speed-loaded, it can be speed-unloaded.
		if (allow_dump && (load_method & SPEEDLOADER))
			var/count = FALSE
			var/turf/T = get_turf(user)
			if (T)
				for (var/obj/item/ammo_casing/C in loaded)
					C.loc = T
					count++
				loaded.Cut()
			if (count)
				user.visible_message("[user] unloads [src].", "<span class='notice'>You unload [count] round\s from [src].</span>")
				if (bulletinsert_sound) playsound(loc, bulletinsert_sound, 75, TRUE)
		else if (load_method & SINGLE_CASING)
			var/obj/item/ammo_casing/C = loaded[loaded.len]
			loaded.len--
			user.put_in_hands(C)
			user.visible_message("[user] removes \a [C] from [src].", "<span class='notice'>You remove \a [C] from [src].</span>")
			if (bulletinsert_sound) playsound(loc, bulletinsert_sound, 75, TRUE)
	else
		user << "<span class='warning'>[src] is empty.</span>"
	update_icon()

/obj/item/weapon/gun/projectile/automatic/hopper/afterattack(atom/A, mob/living/user)
	..()
	if (auto_eject && ammo_magazine && ammo_magazine[1].stored_ammo && !ammo_magazine[1].stored_ammo.len)
		ammo_magazine[1].loc = get_turf(loc)
		user.visible_message(
			"[ammo_magazine] falls out.",
			"<span class='notice'>[ammo_magazine] falls out.</span>"
			)
		if (auto_eject_sound)
			playsound(user, auto_eject_sound, 40, TRUE)
		ammo_magazine[1].update_icon()
		ammo_magazine[1] = ammo_magazine[2]
		update_icon() //make sure to do this after unsetting ammo_magazine

/obj/item/weapon/gun/projectile/automatic/hopper/examine(mob/user)
	..(user)
	if (ammo_magazine[1])
		user << "<span class='notice'>It has [ammo_magazine[1]] clips loaded.</span>"
	if (!magazine_based)
		user << "<span class='notice'>[inexactAmmo()]</span>"
	if (!(istype(src, /obj/item/weapon/gun/projectile/bow)))
		if (serial == "")
			user << "<span class='warning'><b>The serial number has been filed out.</b></span>"
		else
			user << "<i>Serial no. <b>[serial]</b></i>"

/obj/item/weapon/gun/projectile/automatic/hopper/getAmmo()
	var/bullets = FALSE
	if (loaded)
		bullets += loaded.len
	if (ammo_magazine[1] && ammo_magazine[1].stored_ammo)
		bullets += ammo_magazine[1].stored_ammo.len
	if (chambered)
		bullets += 1
	return bullets

///////////////////////////////////////////////////////////////////ACTUAL MGs//////////////////////////////////////////////////////
/obj/item/weapon/gun/projectile/automatic/hopper/type11
	name = "Type 11"
	desc = "A hopper fed 30 round machinegun chambered in 6.5x50SR"
	icon_state = "type99lmg"
	item_state = "type99lmg"
	base_icon = "type99lmg"
	caliber = "a65x50"
	load_delay = 5
	gun_safety = TRUE
	slowdown = 0.5
	magazine_type = /obj/item/ammo_magazine/arisaka
	good_mags = list(/obj/item/ammo_magazine/arisaka) //List of extra compatible mags
	bad_magazine_types = list() // list of magazine types that we can't use
	ammo_magazine = list() //stored magazine
	stat = "machinegun"
	w_class = ITEM_SIZE_HUGE
	heavy = TRUE
	load_method = MAGAZINE
	slot_flags = SLOT_SHOULDER
	sel_mode = 1
	full_auto = TRUE
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS
	firemodes = list(
		list(name = "full auto",	burst=1, burst_delay=0.1, move_delay=2, dispersion = list(0.4, 0.5, 0.6, 0.6, 0.7), recoil = 0),)

*/
//commented out until i get it working