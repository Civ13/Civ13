/obj/item/weapon/gun/projectile/shotgun
	maxhealth = 45
	gun_type = GUN_TYPE_SHOTGUN
	fire_sound = 'sound/weapons/guns/fire/shotgun.ogg'
	icon = 'icons/obj/guns/rifles.dmi'
	// 15% more accurate than SMGs
	equiptimer = 17
	magazine_type = /obj/item/ammo_magazine/shellbox

	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 1.00
	KD_chance = KD_CHANCE_HIGH
	stat = "rifle"

	gtype = "shotgun"

/obj/item/weapon/gun/projectile/shotgun/pump
	name = "Pump-Action Shotgun"
	desc = "A placeholder shotgun chambered in 12 gauge rounds."
	icon_state = "shotgun"
	item_state = "shotgun"
	max_shells = 6
	w_class = ITEM_SIZE_LARGE
	force = 10
	flags =  CONDUCT
	slot_flags = SLOT_SHOULDER
	caliber = "12gauge"
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/shotgun/buckshot
	handle_casings = HOLD_CASINGS
	stat = "rifle"
	var/recentpump = FALSE // to prevent spammage
	load_delay = 1

/obj/item/weapon/gun/projectile/shotgun/pump/consume_next_projectile()
	if (chambered)
		return chambered.BB
	return null

/obj/item/weapon/gun/projectile/shotgun/pump/attack_self(mob/living/user as mob)
	if (world.time >= recentpump + 10)
		pump(user)
		recentpump = world.time

/obj/item/weapon/gun/projectile/shotgun/pump/update_icon()
	..()
	item_state = initial(item_state)

/obj/item/weapon/gun/projectile/shotgun/pump/proc/pump(mob/M as mob)
	playsound(M, 'sound/weapons/guns/interact/shotgun_pump.ogg', 60, TRUE)

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
	name = "Coach Gun"
	desc = "A double-barreled shotgun, commonly used by messengers and on stagecoaches."
	icon_state = "doublebarreled"
	item_state = "shotgun"
	max_shells = 2
	w_class = ITEM_SIZE_LARGE
	force = 10
	flags =  CONDUCT
	slot_flags = SLOT_SHOULDER
	caliber = "12gauge"
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/shotgun/buckshot
	handle_casings = HOLD_CASINGS
	stat = "rifle"
	var/open = FALSE
	var/recentpump = FALSE // to prevent spammage
	load_delay = 1
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


/obj/item/weapon/gun/projectile/shotgun/pump/remington870
	name = "Remington 870 Express"
	desc = "A pump-action shotgun with a 3in 12 gauge chamber."
	icon_state = "remington870"
	item_state = "remington"
	max_shells = 7
	slot_flags = SLOT_SHOULDER
	caliber = "12gauge"
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/shotgun/buckshot
	handle_casings = HOLD_CASINGS
	load_delay = 1

/obj/item/weapon/gun/projectile/shotgun/pump/remington870/brown
	icon_state = "remington870_brown"
	item_state = "remington_brown"

/obj/item/weapon/gun/projectile/shotgun/pump/ks23
	name = "KS-23"
	desc = "A Soviet pump-action shotgun with a 23mm caliber."
	icon_state = "ks23"
	item_state = "ks23"
	max_shells = 4
	slot_flags = SLOT_SHOULDER
	caliber = "12gauge" // To be converted to 23mm when proper shotgun ammo is added
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/shotgun/buckshot
	handle_casings = HOLD_CASINGS
	load_delay = 1

/obj/item/weapon/gun/projectile/shotgun/mts225
	name = "MTS-225"
	desc = "A Russian 6-cylinder revolver shotgun, used by Russian hunters."
	icon_state = "mts225"
	item_state = "shotgun"
	base_icon = "shotgun"
	max_shells = 5
	w_class = ITEM_SIZE_LARGE
	force = 10
	flags =  CONDUCT
	slot_flags = SLOT_SHOULDER
	caliber = "12gauge"
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/shotgun/buckshot
	handle_casings = HOLD_CASINGS
	stat = "rifle"
	var/open = FALSE
	var/recentpump = FALSE // to prevent spammage
	load_delay = 3

/obj/item/weapon/gun/projectile/shotgun/mts225/consume_next_projectile()
	if (chambered)
		return chambered.BB
	return null
/obj/item/weapon/gun/projectile/shotgun/mts225/update_icon()
	..()
	if (open)
		icon_state = "mts225_open"
	else
		icon_state = "mts225"

/obj/item/weapon/gun/projectile/shotgun/mts225/attack_self(mob/living/user as mob)
	if (world.time >= recentpump + 10)
		if (open)
			open = FALSE
			user << "<span class='notice'>You put the cylinder back into \the [src].</span>"
			icon_state = "mts225"
			if (loaded.len)
				var/obj/item/ammo_casing/AC = loaded[1] //load next casing.
				loaded -= AC //Remove casing from loaded list.
				chambered = AC
		else
			open = TRUE
			user << "<span class='notice'>You release the cylinder of \the [src].</span>"
			icon_state = "mts225_open"
		recentpump = world.time

/obj/item/weapon/gun/projectile/shotgun/mts225/load_ammo(var/obj/item/A, mob/user)
	if (!open)
		user << "<span class='notice'>You need release the cylinder of \the [src] first!</span>"
		return
	..()

/obj/item/weapon/gun/projectile/shotgun/coachgun/unload_ammo(mob/user, var/allow_dump=1)
	if (!open)
		user << "<span class='notice'>You need to release the cylinder of \the [src] first!</span>"
		return
	..()

/obj/item/weapon/gun/projectile/shotgun/mts225/special_check(mob/user)
	if (open)
		user << "<span class='warning'>You can't fire \the [src] while the cylinder is not in the gun!</span>"
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/shotgun/mts225/handle_post_fire()
	..()
	if (loaded.len)
		var/obj/item/ammo_casing/AC = loaded[1] //load next casing.
		loaded -= AC //Remove casing from loaded list.
		chambered = AC
