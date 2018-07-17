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

	if (istype(I, /obj/item/weapon/silencer))
		if (user.l_hand != src && user.r_hand != src)	//if we're not in his hands
			user << "<span class='notice'>You'll need [src] in your hands to do that.</span>"
			return
		user.drop_item()
		user << "<span class='notice'>You screw [I] onto [src].</span>"
		silenced = I	//dodgy?
		w_class = 3
		I.loc = src		//put the silencer into the gun
		update_icon()
		return
	..()

/obj/item/weapon/gun/projectile/pistol/update_icon()
	..()
	if (silenced)
		icon_state = "[initial(icon_state)]-silencer"
	else
		icon_state = "[initial(icon_state)]"

/obj/item/weapon/silencer
	name = "silencer"
	desc = "a silencer"
	icon = 'icons/obj/gun.dmi'
	icon_state = "silencer"
	w_class = 2