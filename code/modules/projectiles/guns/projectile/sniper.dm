/obj/item/weapon/gun/projectile/heavy
	name = "anti-materiel rifle"
	desc = "A portable anti-armour rifle fitted with a scope, the HI PTR-7 Rifle was originally designed to used against armoured exosuits. It is capable of punching through windows and non-reinforced walls with ease. Fires armor piercing 14.5mm shells."
	icon_state = "heavysniper"
	item_state = "l6closednomag" //placeholder
	w_class = 4
	force = WEAPON_FORCE_PAINFUL
	slot_flags = SLOT_BACK
//	origin_tech = list(TECH_COMBAT = 8, TECH_MATERIAL = 2, TECH_ILLEGAL = 8)
	caliber = "14.5mm"
	recoil = 2 //extra kickback
	//fire_sound = 'sound/weapons/sniper.ogg'
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING
	max_shells = TRUE
	ammo_type = /obj/item/ammo_casing/a145
	//+2 accuracy over the LWAP because only one shot
	accuracy = -1
//	scoped_accuracy = 2
	fire_sound = 'sound/weapons/guns/fire/sniper_fire.ogg'
	reload_sound 	= 'sound/weapons/guns/interact/rifle_load.ogg'
	var/bolt_open = FALSE

/obj/item/weapon/gun/projectile/heavy/update_icon()
	if (bolt_open)
		icon_state = "heavysniper-open"
	else
		icon_state = "heavysniper"

/obj/item/weapon/gun/projectile/heavy/attack_self(mob/user as mob)
	playsound(loc, 'sound/weapons/guns/interact/rifle_boltback.ogg', 75, TRUE)
	bolt_open = !bolt_open
	if (bolt_open)
		if (chambered)
			user << "<span class='notice'>You work the bolt open, ejecting [chambered]!</span>"
			chambered.loc = get_turf(src)
			loaded -= chambered
			chambered = null
		else
			user << "<span class='notice'>You work the bolt open.</span>"
	else
		user << "<span class='notice'>You work the bolt closed.</span>"
		playsound(loc, 'sound/weapons/guns/interact/rifle_boltforward.ogg', 75, TRUE)
		bolt_open = FALSE
	add_fingerprint(user)
	update_icon()

/obj/item/weapon/gun/projectile/heavy/special_check(mob/user)
	if (bolt_open)
		user << "<span class='warning'>You can't fire [src] while the bolt is open!</span>"
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/heavy/load_ammo(var/obj/item/A, mob/user)
	if (!bolt_open)
		return
	..()

/obj/item/weapon/gun/projectile/heavy/unload_ammo(mob/user, var/allow_dump=1)
	if (!bolt_open)
		return
	..()
