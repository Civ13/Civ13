/obj/item/weapon/gun/projectile/pistol
	gun_type = GUN_TYPE_PISTOL
	name = "holdout pistol"
	desc = "The Lumoco Arms P3 Whisper. A small, easily concealable gun. Uses 9mm rounds."
	icon_state = "luger"
	item_state = null
	w_class = 2
	caliber = "9mm"
	silenced = FALSE
	fire_sound = 'sound/weapons/guns/fire/pistol_fire.ogg'
	load_method = MAGAZINE
	magazine_type = /obj/item/ammo_magazine/mc9mm

/obj/item/weapon/gun/projectile/pistol/attack_hand(mob/user as mob)
	if (user.get_inactive_hand() == src)
		if (silenced)
			if (user.l_hand != src && user.r_hand != src)
				..()
				return
			user << "<span class='notice'>You unscrew [silenced] from [src].</span>"
			user.put_in_hands(silenced)
			silenced = FALSE
			w_class = 2
			update_icon()
			return
	..()

/obj/item/weapon/gun/projectile/pistol/attackby(obj/item/I as obj, mob/user as mob)
	if (..()) // handle attachments
		return TRUE

	..()
