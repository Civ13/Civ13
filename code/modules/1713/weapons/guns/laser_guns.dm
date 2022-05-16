/obj/item/weapon/gun/projectile/semiautomatic/dc15
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
/obj/item/weapon/gun/projectile/semiautomatic/dc15a
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

/obj/item/weapon/gun/projectile/semiautomatic/e5
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