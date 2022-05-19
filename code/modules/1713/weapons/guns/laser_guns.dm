/obj/item/weapon/gun/projectile/semiautomatic/laser
	name = "DC-15"
	desc = "Standard issue carbine of the Grand Army of the Republic"
	icon_state = "DC-15A"
	item_state = "DC-15A"
	base_icon = "DC-15A"
	fire_sound = 'sound/weapons/guns/fire/blasterdc2.ogg'
	w_class = 4
	load_method = MAGAZINE
	max_shells = 200
	caliber = "laserb"
	ammo_type = /obj/item/ammo_casing/laser/b
	damage_modifier = 1.2
	slot_flags = SLOT_SHOULDER
	magazine_type = /obj/item/ammo_magazine/tibannagas/dc15
	good_mags = list(/obj/item/ammo_magazine/tibannagas/dc15)
	weight = 3.85
	firemodes = list(
		list(name="single shot",burst=1, move_delay=0, fire_delay=2)
		)

	gun_type = GUN_TYPE_RIFLE
	force = 10
	throwforce = 20
	effectiveness_mod = 1.10
	attachment_slots = null
	handle_casings = REMOVE_CASINGS

/obj/item/weapon/gun/projectile/semiautomatic/laser/consume_next_projectile(var/check = FALSE)
	//get the next casing
	if (loaded.len)
		chambered = loaded[1] //load next casing.
		if (handle_casings != HOLD_CASINGS)
			loaded -= chambered
			if (infinite_ammo)
				loaded += new chambered.type

	else if (ammo_magazine && ammo_magazine.stored_ammo.len)
		chambered = ammo_magazine.stored_ammo[1]
		if (handle_casings != HOLD_CASINGS)
			ammo_magazine.stored_ammo -= chambered
			if (infinite_ammo)
				ammo_magazine.stored_ammo += new chambered.type

	if (chambered)
		if (gibs)
			chambered.BB.gibs = TRUE
		if (crushes)
			chambered.BB.crushes = TRUE
		return chambered.BB
	return null

/obj/item/weapon/gun/projectile/semiautomatic/laser/handle_post_fire()
	..()
	jamcheck = 0
	last_fire = world.time

/obj/item/weapon/gun/projectile/semiautomatic/laser/dc15
	name = "DC-15"
	desc = "Standard issue carbine of the Grand Army of the Republic"
	icon_state = "DC-15"
	item_state = "DC-15"
	base_icon = "DC-15"
	fire_sound = 'sound/weapons/guns/fire/blasterdc2.ogg'
	w_class = 4
	load_method = MAGAZINE
	max_shells = 200
	caliber = "laserb"
	ammo_type = /obj/item/ammo_casing/laser/b
	damage_modifier = 1.2
	slot_flags = SLOT_SHOULDER
	magazine_type = /obj/item/ammo_magazine/tibannagas/dc15
	good_mags = list(/obj/item/ammo_magazine/tibannagas/dc15)
	weight = 3.85
	firemodes = list(
		list(name="single shot",burst=1, move_delay=0, fire_delay=2)
		)

	gun_type = GUN_TYPE_RIFLE
	force = 10
	throwforce = 20
	effectiveness_mod = 1.10
	attachment_slots = null
	handle_casings = REMOVE_CASINGS

/obj/item/weapon/gun/projectile/semiautomatic/laser/dc15a
	name = "DC-15A"
	desc = "Standard issue rifle of the Grand Army of the Republic"
	icon_state = "DC-15A"
	item_state = "DC-15A"
	base_icon = "DC-15A"
	fire_sound = 'sound/weapons/guns/fire/blasterdc1.ogg'
	w_class = 4
	load_method = MAGAZINE
	max_shells = 500
	caliber = "laserb"
	ammo_type = /obj/item/ammo_casing/laser/b
	damage_modifier = 1.2
	slot_flags = SLOT_SHOULDER
	magazine_type = /obj/item/ammo_magazine/tibannagas/dc15a
	good_mags = list(/obj/item/ammo_magazine/tibannagas/dc15a, /obj/item/ammo_magazine/tibannagas/dc15)
	weight = 3.85
	firemodes = list(
		list(name="single shot",burst=1, move_delay=0, fire_delay=2)
		)

	gun_type = GUN_TYPE_RIFLE
	force = 20
	throwforce = 25
	effectiveness_mod = 1.25
	attachment_slots = null
	handle_casings = REMOVE_CASINGS

/obj/item/weapon/gun/projectile/semiautomatic/laser/e5
	name = "E-5"
	desc = "Standard issue rifle of the Confederacy of Independant Systems"
	icon_state = "E-5"
	item_state = "E-5"
	base_icon = "E-5"
	fire_sound = 'sound/weapons/guns/fire/blasterimperial.ogg'
	w_class = 4
	load_method = MAGAZINE
	max_shells = 100
	caliber = "laserb"
	ammo_type = /obj/item/ammo_casing/laser
	damage_modifier = 1.2
	slot_flags = SLOT_SHOULDER
	magazine_type = /obj/item/ammo_magazine/tibannagas/e5
	good_mags = list(/obj/item/ammo_magazine/tibannagas/e5)
	weight = 3.85
	firemodes = list(
		list(name="single shot",burst=1, move_delay=0, fire_delay=2)
		)

	gun_type = GUN_TYPE_RIFLE
	force = 10
	throwforce = 15
	effectiveness_mod = 1.10
	attachment_slots = null
	handle_casings = REMOVE_CASINGS

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////PISTOLS/////////////////////////////////////////////
/obj/item/weapon/gun/projectile/pistol/laser
	name = "Laser pistol"
	desc = "A generic laser shooter"
	icon_state = "DC-17"
	w_class = 2
	caliber = "laserb"
	fire_sound = 'sound/weapons/guns/fire/blasterdc2.ogg'
	magazine_type = /obj/item/ammo_magazine/tibannagas/dc17
	good_mags = list(/obj/item/ammo_magazine/tibannagas/dc17)
	weight = 0.5
	ammo_type = /obj/item/ammo_casing/laser/b
	load_method = MAGAZINE
	handle_casings = REMOVE_CASINGS
	effectiveness_mod = 1.02

/obj/item/weapon/gun/projectile/pistol/laser/dc17
	name = "DC-17 blaster"
	desc = "A DC-17 blaster pistol most commonly used by the Grand Army of the Republic."
	icon_state = "DC-17"

/obj/item/weapon/gun/projectile/pistol/laser/dl44
	name = "DL-44 blaster"
	desc = "A DL-44 blaster pistol used by various organizations throughout the galaxy."
	icon_state = "DL-44"
	w_class = 2
	caliber = "laser"
	fire_sound = 'sound/weapons/guns/fire/blasterdl44.ogg'
	magazine_type = /obj/item/ammo_magazine/tibannagas/dl44
	good_mags = list(/obj/item/ammo_magazine/tibannagas/dl44)
	weight = 0.5
	ammo_type = /obj/item/ammo_casing/laser/pistol
	load_method = MAGAZINE
	handle_casings = REMOVE_CASINGS
	effectiveness_mod = 1.02
/////////////////////////////STAT MG'S/////////////////////////////////////////
/obj/item/weapon/gun/projectile/automatic/stationary/modern/laser
	name = "laser MG"
	desc = "shouldnt be viewing this"
	icon_state = "repeating_blaster"
	base_icon = "repeating_blaster"
	caliber = "laser"
	fire_sound = 'sound/weapons/guns/fire/blastere5sniper.ogg'
	magazine_type = /obj/item/ammo_magazine/tibannagas/repeating_blaster
	good_mags = list(/obj/item/ammo_magazine/tibannagas/repeating_blaster)
	firemodes = list(
		list(name="full auto", burst=3, burst_delay=1.8, fire_delay=1.8, dispersion=list(0.9, 0.9, 1.1, 1.1, 1), accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/laser
	is_hmg = TRUE
/obj/item/weapon/gun/projectile/automatic/stationary/modern/laser/update_icon()
	if (ammo_magazine)
		icon_state = base_icon
	else
		icon_state = "[base_icon]_open"
	update_held_icon()
	return
/obj/item/weapon/gun/projectile/automatic/stationary/modern/laser/handle_post_fire()
	..()
	jamcheck = 0
	last_fire = world.time

/obj/item/weapon/gun/projectile/automatic/stationary/modern/laser/repeating_laser
	name = "repreating laser"
	desc = "A stationary repeating laser, a turret firing tibanna gas cartridge lasers."
	icon_state = "repeating_blaster"
	base_icon = "repeating_blaster"
	caliber = "laser"
	fire_sound = 'sound/weapons/guns/fire/blastere5sniper.ogg'
	magazine_type = /obj/item/ammo_magazine/tibannagas/repeating_blaster
	good_mags = list(/obj/item/ammo_magazine/tibannagas/repeating_blaster)
	firemodes = list(
		list(name="full auto", burst=5, burst_delay=1.8, fire_delay=1.8, dispersion=list(0.9, 0.9, 1.1, 1.1, 1), accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/laser
	is_hmg = TRUE

/obj/item/weapon/gun/projectile/automatic/laser
	name = "laser minigun"
	desc = "shouldnt be using this m8"
	icon_state = "Z-6"
	item_state = "Z-6"
	base_icon = "Z-6"
	caliber = "laser"
	fire_sound = 'sound/weapons/guns/fire/blasterimperial.ogg'
	ammo_type = /obj/item/ammo_casing/laser
	magazine_type = /obj/item/ammo_magazine/tibannagas/blaster_power_pack
	good_mags = list(/obj/item/ammo_magazine/tibannagas/blaster_power_pack, /obj/item/ammo_magazine/tibannagas/blaster_power_pack)
	weight = 9.12
	force = 20
	throwforce = 30
	attachment_slots = null
	slowdown = 0.2
	has_telescopic = FALSE
	slot_flags = SLOT_SHOULDER
	is_laser_mg = TRUE

/obj/item/weapon/gun/projectile/automatic/laser/update_icon()
	if (ammo_magazine)
		icon_state = base_icon
	else
		icon_state = "[base_icon]_open"
	update_held_icon()
	return
/obj/item/weapon/gun/projectile/automatic/laser/handle_post_fire()
	..()
	jamcheck = 0
	last_fire = world.time

/obj/item/weapon/gun/projectile/automatic/laser/z6
	name = "Z-6 blaster"
	desc = "The standard Z-6 blaster heavy rotary blaster used commonly in the Grand Army of the Republic."
	icon_state = "Z-6"
	item_state = "Z-6"
	base_icon = "Z-6"
	caliber = "laserb"
	fire_sound = 'sound/weapons/guns/fire/blasterdc1.ogg'
	ammo_type = /obj/item/ammo_casing/laser/b
	magazine_type = /obj/item/ammo_magazine/tibannagas/blaster_power_pack
	good_mags = list(/obj/item/ammo_magazine/tibannagas/blaster_power_pack)
	weight = 9.12
	force = 20
	throwforce = 30
	attachment_slots = null
	slowdown = 0.2
	has_telescopic = FALSE
	slot_flags = SLOT_SHOULDER
	is_laser_mg = TRUE