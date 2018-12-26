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

/obj/item/ammo_casing/projectile/a792x54
	desc = "A 7.92x54mm bullet casing."
	caliber = "a792x54"
	icon_state = "clip-bullet"
	spent_icon = "clip-casing"
	weight = 0.012
	projectile_type = /obj/item/projectile/bullet/rifle/a792x54

/obj/item/ammo_casing/projectile/a65x50mm
	desc = "A 65x50mm bullet casing."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	caliber = "a65x50mm"
	weight = 0.0127
	projectile_type = /obj/item/projectile/bullet/rifle/a65x50mm

/obj/item/ammo_casing/projectile/a762x38
	desc = "A 7.62x38mmR bullet casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistol_bullet_casing"
	caliber = "7.62x38mmR"
	weight = 0.0056
	projectile_type = /obj/item/projectile/bullet/rifle/a762x38



/obj/item/ammo_casing/projectile/c9mm_jap_revolver
	desc = "A 9mm revolver bullet casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistol_bullet_casing"
	caliber = "c9mm_jap_revolver"
	weight = 0.0095
	projectile_type = /obj/item/projectile/bullet/pistol/c9mm_jap_revolver

/obj/item/ammo_casing/c8mmnambu
	desc = "A 8mm Nambu bullet casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistol_bullet_casing"
	caliber = "c8mmnambu"
	weight = 0.0095
	projectile_type = /obj/item/projectile/bullet/pistol/c8mmnambu

/************************
		OTHER
************************/

/obj/item/ammo_casing/projectile/a65x50mm
	name = "a 65x50mm bullet casing"
	projectile_type = /obj/item/projectile/bullet/rifle/a65x50mm
	weight = 0.0136
	caliber = "a65x50mm"

/obj/item/ammo_casing/a792x54
	name = "a 7.62x54 bullet casing"
	projectile_type = /obj/item/projectile/bullet/rifle/a792x54
	caliber = "a792x54"

/obj/item/ammo_casing/projectile/a127x108
	name = "a 1.27x108 bullet casing"
	projectile_type = /obj/item/projectile/bullet/rifle/a792x54
	caliber = "a127x108"