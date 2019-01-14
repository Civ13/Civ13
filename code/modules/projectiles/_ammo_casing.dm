/////////////////XVIII CENTURY STUFF/////////////////////////////
/obj/item/ammo_casing/musketball
	name = "musketball cartridge"
	icon_state = "musketball_gunpowder"
	spent_icon = null
	projectile_type = /obj/item/projectile/bullet/rifle/musketball
	weight = 0.02
	caliber = "musketball"
	value = 3

/obj/item/ammo_casing/musketball_pistol
	name = "pistol cartridge"
	projectile_type = /obj/item/projectile/bullet/rifle/musketball_pistol
	weight = 0.015
	icon_state = "musketball_pistol_gunpowder"
	spent_icon = null
	caliber = "musketball_pistol"
	value = 2

/obj/item/ammo_casing/blunderbuss
	name = "blunderbuss cartridge"
	icon_state = "blunderbuss_gunpowder"
	spent_icon = null
	projectile_type = /obj/item/projectile/bullet/rifle/blunderbuss
	weight = 0.035
	caliber = "blunderbuss"
	value = 3

/obj/item/ammo_casing/arrow
	name = "arrow"
	desc = "Use a bow to fire it."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "arrow"
	spent_icon = null
	projectile_type = /obj/item/projectile/arrow/arrow
	weight = 0.15
	caliber = "arrow"
	slot_flags = SLOT_BELT
	value = 2

///////TO MAKE AMMO WITH GUNPOWDER
/obj/item/stack/ammopart
	var/resultpath = /obj/item/ammo_casing/musketball
	amount = 1
	max_amount = 20
	singular_name = "projectile"

/obj/item/stack/ammopart/musketball
	name = "musketball projectiles"
	desc = "A round musketball, to be used in flintlock muskets."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "musketball"
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	resultpath = /obj/item/ammo_casing/musketball
	value = 2
	weight = 0.08

/obj/item/stack/ammopart/musketball_pistol
	name = "pistol projectiles"
	desc = "A small, round musketball, to be used in flintlock pistols."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "musketball_pistol"
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	resultpath = /obj/item/ammo_casing/musketball_pistol
	value = 1
	weight = 0.05

/obj/item/stack/ammopart/blunderbuss
	name = "blunderbuss projectiles"
	desc = "A bunch of small iron projectiles. Can fill blunderbusses."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "blunderbuss"
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	resultpath = /obj/item/ammo_casing/blunderbuss
	value = 2
	weight = 0.1

/obj/item/stack/ammopart/attack_self(mob/user)
	if (istype(user.l_hand, /obj/item/weapon/reagent_containers))
		if (!user.l_hand.reagents.has_reagent("gunpowder",1))
			user << "<span class = 'warning'>You need to a gunpowder container in your hands to make a cartridge.</span>"
			return
		else if (user.l_hand.reagents.has_reagent("gunpowder",1))
			user.l_hand.reagents.remove_reagent("gunpowder",1)
			user << "You make a paper cartridge with the gunpowder and projectile."
			if (user.r_hand.amount>1)
				user.r_hand.amount -= 1
			else
				qdel(user.r_hand)
			new resultpath(user.loc)
			return

	else if (istype(user.r_hand, /obj/item/weapon/reagent_containers))
		if (!user.r_hand.reagents.has_reagent("gunpowder",1))
			user << "<span class = 'warning'>You need to a gunpowder container in your hands to make a cartridge.</span>"
			return
		else if (user.r_hand.reagents.has_reagent("gunpowder",1))
			user.r_hand.reagents.remove_reagent("gunpowder",1)
			user << "You make a paper cartridge with the gunpowder and projectile."
			if (user.l_hand.amount>1)
				user.l_hand.amount -= 1
			else
				qdel(user.l_hand)
			new resultpath(user.loc)
			return

	else
		user << "<span class = 'warning'>You need to a gunpowder container in your hands to make a cartridge.</span>"
		return


/obj/item/ammo_casing/a65x50mm
	name = "6.5x50mm ammo casing"
	desc = "A brass casing containing powder and a lead bullet."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a65x50mm
	caliber = "a65x50mm"
	value = 5

/obj/item/ammo_casing/a11x60mm
	name = "11x60mm ammo casing"
	desc = "A brass casing containing powder and a lead bullet."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a11x60mm
	caliber = "a11x60mm"
	value = 5

/obj/item/ammo_casing/c9mm_jap_revolver
	name = "9mm bullet casing"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = null
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/c9mm_jap_revolver
	caliber = "c9mm_jap_revolver"
	value = 5

/obj/item/ammo_casing/a762x54
	name = "7.62x54mm ammo casing"
	desc = "A brass casing."
	icon_state = "clip-bullet"
	spent_icon = "clip-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a762x54
	caliber = "a762x54"
	value = 2

/obj/item/ammo_casing/a762x38
	name = "7.62x38mmR bullet casing"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = null
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a762x38
	caliber = "7.62x38mmR"
	value = 2

/obj/item/ammo_casing/c8mmnambu
	name = "8mm bullet casing"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = null
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/c8mmnambu
	caliber = "c8mmnambu"
	value = 2

/obj/item/ammo_casing/colt
	name = ".45 bullet casing"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = null
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/colt
	caliber = "colt"
	value = 2

/obj/item/ammo_casing/fourtyfour
	name = ".44 bullet casing"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = null
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/fortyfour
	caliber = "44"
	value = 2

/obj/item/ammo_casing/thirtyeight
	name = ".38 bullet casing"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = null
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/thrityeight
	caliber = "38"
	value = 2

/obj/item/ammo_casing/shotgun
	name = "shotgun shell"
	desc = "A shotgun shell casing."
	icon_state = "shell-bullet"
	spent_icon = "shell-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/shotgun/buckshot
	caliber = "12gauge"
	value = 2