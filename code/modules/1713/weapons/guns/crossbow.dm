/obj/item/weapon/gun/projectile/bow/crossbow
	name = "crossbow"
	desc = "A heavy and powerful bow."
	icon_state = "crossbow0"
	item_state = "crossbow0"
	w_class = ITEM_SIZE_LARGE
	throw_range = 4
	throw_speed = 5
	force = 8
	throwforce = 8
	max_shells = 1 //duh
	slot_flags = SLOT_SHOULDER
	caliber = "bolt"
	shake_strength = 1 //little shaking
	fire_sound = 'sound/weapons/guns/fire/Crossbow.ogg'
	handle_casings = REMOVE_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/bolt
	load_shell_sound = 'sound/weapons/pull_bow.ogg'
	bulletinsert_sound = 'sound/weapons/pull_bow.ogg'
	//+2 accuracy over the LWAP because only one shot
	gun_type = GUN_TYPE_BOW
	attachment_slots = null
	accuracy_increase_mod = 6.00
	accuracy_decrease_mod = 8.00
	KD_chance = KD_CHANCE_HIGH
	stat = "bows"
	move_delay = 1
	fire_delay = 8
	muzzle_flash = FALSE
	value = 10
	flammable = TRUE
	projtype = "bolt"
	icotype = "crossbow"
	equiptimer = 25
	load_delay = 60
	aim_miss_chance_divider = 3.00
	accuracy = 1

/obj/item/weapon/gun/projectile/bow/crossbow/New()
	..()
	if (map && !map.civilizations)
		if (map.ordinal_age == 1)
			loaded = list()
			var/obj/item/ammo_casing/C = new /obj/item/ammo_casing/bolt/bronze(src)
			loaded.Insert(1, C) //add to the head of the list
		else if (map.ordinal_age >= 2)
			loaded = list()
			var/obj/item/ammo_casing/C = new /obj/item/ammo_casing/bolt/iron(src)
			loaded.Insert(1, C) //add to the head of the list
	update_icon()