/////////////////XVIII CENTURY STUFF/////////////////////////////
/obj/item/ammo_casing/musketball
	name = "musketball cartridge"
	icon_state = "musketball_gunpowder"
	spent_icon = null
	projectile_type = /obj/item/projectile/bullet/rifle/musketball
	weight = 0.02
	caliber = "musketball"
	value = 3

/obj/item/ammo_casing/stoneball
	name = "stone ball projectile"
	icon_state = "stoneball"
	spent_icon = null
	projectile_type = /obj/item/projectile/bullet/rifle/stoneball
	weight = 0.03
	caliber = "stoneball"
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

/obj/item/ammo_casing/stone
	name = "rock"
	desc = "Use a sling to launch it."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "rock"
	spent_icon = null
	projectile_type = /obj/item/projectile/arrow/stone
	weight = 0.22
	caliber = "stone"
	value = 1

///////TO MAKE AMMO WITH GUNPOWDER
/obj/item/stack/ammopart
	var/resultpath = /obj/item/ammo_casing/musketball
	amount = 1
	max_amount = 20
	singular_name = "projectile"
	value = 0

/obj/item/stack/ammopart/stoneball
	name = "stone projectile"
	desc = "A round stone ball, to be used in handcannons, arquebuses and matchlock muskets."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "stoneball"
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_WEAK
	resultpath = null
	value = 1
	weight = 0.15
	max_amount = 5

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
/obj/item/stack/ammopart/casing
	max_amount = 40
	singular_name = "casing"
	value = 1
	weight = 0.05
	var/gunpowder = 0
	var/gunpowder_max = 2
	var/bulletn = FALSE

/obj/item/stack/ammopart/casing/rifle
	name = "empty rifle casing"
	desc = "An empty brass casing."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "riflecasing_empty"
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	resultpath = null
	gunpowder_max = 1.5
	var/inputbtype = "normal"

/obj/item/stack/ammopart/casing/pistol
	name = "empty pistol casing"
	desc = "A small empty brass casing."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "pistolcasing_empty"
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	resultpath = null
	gunpowder_max = 1

/obj/item/stack/ammopart/casing/artillery
	name = "empty artillery casing"
	desc = "A large empty brass casing."
	icon = 'icons/obj/cannon_ball.dmi'
	icon_state = "casing"
	force = WEAPON_FORCE_HARMLESS+1
	throwforce = WEAPON_FORCE_HARMLESS+2
	resultpath = null
	gunpowder_max = 5
	max_amount = 1
	value = 4

/obj/item/stack/ammopart/bullet
	name = "iron bullet"
	desc = "A molded iron bullet, made to fit in a casing."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "ironbullet"
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	resultpath = null
	max_amount = 60
	singular_name = "bullet"
	value = 1
	weight = 0.08
/obj/item/stack/ammopart/casing/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers) && gunpowder < gunpowder_max*amount)
		if (istype(user.l_hand, /obj/item/weapon/reagent_containers))
			if (!user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user << "<span class = 'notice'>You need enough gunpowder in a gunpowder container in your hands to fill the casing.</span>"
				return
			else if (user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user.l_hand.reagents.remove_reagent("gunpowder",gunpowder_max*amount)
				user << "You fill the casings with gunpowder."
				gunpowder = gunpowder_max*amount
				return
		else if (istype(user.r_hand, /obj/item/weapon/reagent_containers))
			if (!user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max))
				user << "<span class = 'notice'>You need enough gunpowder in a gunpowder container in your hands to fill the casing.</span>"
				return
			else if (user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max))
				user.r_hand.reagents.remove_reagent("gunpowder",gunpowder_max)
				user << "You fill the casings with gunpowder."
				gunpowder = gunpowder_max*amount
				return
	if (istype(W, /obj/item/stack/ammopart/bullet))
		if (!(gunpowder >= gunpowder_max*amount))
			user << "<span class = 'notice'>You need to fill the casings with gunpowder before putting the bullet.</span>"
			return
		else if (W.amount < amount)
			user << "<span class = 'notice'>Not enough bullets. reduce the casings stack or add more bullets.</span>"
		else if (W.amount >= amount)
			bulletn = amount
			W.amount -= amount
			if (W.amount <= 0)
				qdel(W)
	if (gunpowder >= gunpowder_max*amount && bulletn >= amount)
		attack_self(user)
		return

	else
		return
/obj/item/stack/ammopart/casing/artillery/attack_self(mob/user)
	if (gunpowder >= gunpowder_max && bulletn >= amount)
		for(var/i=1;i<=amount;i++)
			new/obj/item/cannon_ball/shell(user.loc)
		qdel(src)
		return
	else
		user << "<span class = 'notice'>The casing is not complete yet.</span>"
		return
/obj/item/stack/ammopart/casing/pistol/attack_self(mob/user)
	if (gunpowder >= gunpowder_max && bulletn >= amount)
		var/list/listing = list("Cancel")
		if (map.ordinal_age == 4)
			listing = list(".45 Colt", ".44-40 Winchester", ".41 Short", "Cancel")
		else if (map.ordinal_age == 5)
			listing = list("9mm pistol",".45 pistol", "Cancel")
		else if (map.ordinal_age >= 6)
			listing = list("9mm pistol",".45 pistol", "Cancel")
		var/input = WWinput(user, "What caliber do you want to make?", "Bullet Making", "Cancel", listing)
		if (input == "Cancel")
			return
		else if (input == ".41 Short")
			resultpath = /obj/item/ammo_casing/a41
		else if (input == ".45 Colt")
			resultpath = /obj/item/ammo_casing/a45
		else if (input == ".44-40 Winchester")
			resultpath = /obj/item/ammo_casing/a44
		else if (input == ".45 pistol")
			resultpath = /obj/item/ammo_casing/pistol45
		else if (input == "9mm pistol")
			resultpath = /obj/item/ammo_casing/pistol9
		if (resultpath != null)
			for(var/i=1;i<=amount;i++)
				new resultpath(user.loc)
			qdel(src)
			return
		else
			return
	else
		user << "<span class = 'notice'>The casing is not complete yet.</span>"
		return

/obj/item/stack/ammopart/casing/rifle/attack_self(mob/user)
	if (gunpowder >= gunpowder_max && bulletn >= amount)
		var/list/listing = list("Cancel")
		if (map.ordinal_age == 4)
			listing = list(".44-70 Government", "12 Gauge (Buckshot)", "12 Gauge (Slugshot)", "12 Gauge (Beanbag)",  ".577/450 Martini-Henry","7.65x53 Mauser", "Cancel")
		else if (map.ordinal_age == 5)
			listing = list("8mm large rifle","6.5mm small rifle","7.5mm intermediate rifle","5.5mm intermediate rifle","Cancel")
		else if (map.ordinal_age >= 6)
			listing = list("8mm large rifle","6.5mm small rifle","7.5mm intermediate rifle","5.5mm intermediate rifle","Cancel")

		var/input = WWinput(user, "What caliber do you want to make?", "Bullet Making", "Cancel", listing)
		if (input == "Cancel")
			return
		else if (input == ".44-70 Government")
			resultpath = /obj/item/ammo_casing/a4570
		else if (input == ".577/450 Martini-Henry")
			resultpath = /obj/item/ammo_casing/a577
		else if (input == "12 Gauge (Buckshot)")
			resultpath = /obj/item/ammo_casing/shotgun
		else if (input == "12 Gauge (Slugshot)")
			resultpath = /obj/item/ammo_casing/shotgun/slug
		else if (input == "12 Gauge (Beanbag)")
			resultpath = /obj/item/ammo_casing/shotgun/beanbag
		else if (input == "7.65x53 Mauser")
			resultpath = /obj/item/ammo_casing/a765x53
			inputbtype = WWinput(user, "Normal, Hollow Point or Armor Piercing?", "Bullet Making", "Normal", list("normal","AP","HP"))
		else if (input == "8mm large rifle")
			resultpath = /obj/item/ammo_casing/largerifle
			inputbtype = WWinput(user, "Normal, Hollow Point or Armor Piercing?", "Bullet Making", "Normal", list("normal","AP","HP"))
		else if (input == "6.5mm small rifle")
			resultpath = /obj/item/ammo_casing/smallrifle
			inputbtype = WWinput(user, "Normal, Hollow Point or Armor Piercing?", "Bullet Making", "Normal", list("normal","AP","HP"))
		else if (input == "7.5mm intermediate rifle")
			resultpath = /obj/item/ammo_casing/intermediumrifle
			inputbtype = WWinput(user, "Normal, Hollow Point or Armor Piercing?", "Bullet Making", "Normal", list("normal","AP","HP"))
		else if (input == "5.5mm intermediate rifle")
			resultpath = /obj/item/ammo_casing/smallintermediumrifle
			inputbtype = WWinput(user, "Normal, Hollow Point or Armor Piercing?", "Bullet Making", "Normal", list("normal","AP","HP"))
		if (resultpath != null)
			for(var/i=1;i<=amount;i++)
				var/obj/item/ammo_casing/NC = new resultpath(user.loc)
				NC.btype = inputbtype
				NC.checktype()
			qdel(src)
			return
		else
			return
	else
		user << "<span class = 'notice'>The casing is not complete yet.</span>"
		return
/obj/item/stack/ammopart/attack_self(mob/user)
	if (istype(src, /obj/item/stack/ammopart/bullet) || istype(src, /obj/item/stack/ammopart/casing/pistol) || istype(src, /obj/item/stack/ammopart/casing/rifle))
		return
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


/obj/item/ammo_casing/a65x50
	name = "6.5x50mm bullet"
	desc = "A brass casing containing powder and a lead bullet."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a65x50
	caliber = "a65x50"
	value = 5

/obj/item/ammo_casing/a65x50/weak
	projectile_type = /obj/item/projectile/bullet/rifle/a65x50/weak
	caliber = "a65x50_weak"

/obj/item/ammo_casing/a65x52
	name = "6.5x52mm bullet"
	desc = "A brass casing containing powder and a lead bullet."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a65x52
	caliber = "a65x52"
	value = 5

/obj/item/ammo_casing/a8x53
	name = "8x53mm bullet"
	desc = "A brass casing containing powder and a lead bullet."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a8x53
	caliber = "a8x53"
	value = 5

/obj/item/ammo_casing/a8x50
	name = "8x50mmR bullet"
	desc = "A brass casing containing powder and a lead bullet."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a8x50
	caliber = "a8x50"
	value = 5

/obj/item/ammo_casing/a8x50/weak
	projectile_type = /obj/item/projectile/bullet/rifle/a8x50/weak
	caliber = "a8x50_weak"

/obj/item/ammo_casing/c9mm_jap_revolver
	name = "9mm bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/c9mm_jap_revolver
	caliber = "c9mm_jap_revolver"
	value = 5

/obj/item/ammo_casing/a41
	name = ".41 Short bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.04
	projectile_type = /obj/item/projectile/bullet/pistol/a41
	caliber = "a41"
	value = 7

/obj/item/ammo_casing/a45
	name = ".45 Colt bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a45
	caliber = "a45"
	value = 7

/obj/item/ammo_casing/a45acp
	name = ".45 ACP bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a45
	caliber = "a45acp"
	value = 7

/obj/item/ammo_casing/a455
	name = ".455 Webley bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a455
	caliber = "a455"
	value = 7

/obj/item/ammo_casing/a44
	name = ".44-40 Winchester bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a44
	caliber = "a44"
	value = 8

/obj/item/ammo_casing/a4570
	name = ".45-70 Government bullet"
	desc = "A brass casing."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a4570
	caliber = "a4570"
	value = 8

/obj/item/ammo_casing/a792x57
	name = "7.92x57mm bullet"
	desc = "A brass casing."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a792x57
	caliber = "a792x57"
	value = 8

/obj/item/ammo_casing/a792x57/weak
	projectile_type = /obj/item/projectile/bullet/rifle/a792x57/weak
	caliber = "a792x57_weak"

/obj/item/ammo_casing/a765x53
	name = "7.65x53mm bullet"
	desc = "A brass casing."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a765x53
	caliber = "a765x53"
	value = 8

/obj/item/ammo_casing/a765x25
	name = "7.65x25mm bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a765x25
	caliber = "a765x25"
	value = 8

/obj/item/ammo_casing/a7x57
	name = "7x53mm bullet"
	desc = "A brass casing."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	weight = 0.076
	projectile_type = /obj/item/projectile/bullet/rifle/a7x57
	caliber = "a7x57"
	value = 8

/obj/item/ammo_casing/a77x58
	name = "7.7x58mm bullet"
	desc = "A brass casing."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	weight = 0.076
	projectile_type = /obj/item/projectile/bullet/rifle/a77x58
	caliber = "a77x58"
	value = 8

/obj/item/ammo_casing/a77x58/weak
	projectile_type = /obj/item/projectile/bullet/rifle/a77x58/weak
	caliber = "a77x58_weak"

/obj/item/ammo_casing/a577
	name = ".577/450 Martini-Henry bullet"
	desc = "A brass casing."
	icon_state = "clip-bullet"
	spent_icon = "clip-casing"
	weight = 0.11
	projectile_type = /obj/item/projectile/bullet/rifle/a577
	caliber = "a577"
	value = 8


/obj/item/ammo_casing/a762x54
	name = "7.62x54mm bullet"
	desc = "A brass casing."
	icon_state = "clip-bullet"
	spent_icon = "clip-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a762x54
	caliber = "a762x54"
	value = 2

/obj/item/ammo_casing/a762x54/weak
	projectile_type = /obj/item/projectile/bullet/rifle/a762x54/weak
	caliber = "a762x54_weak"

/obj/item/ammo_casing/a303
	name = ".303 bullet"
	desc = "A brass casing."
	icon_state = "clip-bullet"
	spent_icon = "clip-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a303
	caliber = "a303"
	value = 2

/obj/item/ammo_casing/a303/weak
	projectile_type = /obj/item/projectile/bullet/rifle/a303/weak
	caliber = "a303_weak"

/obj/item/ammo_casing/a3006
	name = ".30-06 bullet"
	desc = "A brass casing."
	icon_state = "clip-bullet"
	spent_icon = "clip-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a3006
	caliber = "a3006"
	value = 2

/obj/item/ammo_casing/a3006/weak
	projectile_type = /obj/item/projectile/bullet/rifle/a3006/weak
	caliber = "a3006_weak"

/obj/item/ammo_casing/a762x38
	name = "7.62x38mmR bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a762x38
	caliber = "a762x38"
	value = 5

/obj/item/ammo_casing/a8x27
	name = "8x27mmR bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a8x27
	caliber = "a8x27"
	value = 5

/obj/item/ammo_casing/c8mmnambu
	name = "8mm bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/c8mmnambu
	caliber = "c8mmnambu"
	value = 2

/obj/item/ammo_casing/a9x19
	name = "9x19mm bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a9x19
	caliber = "a9x19"
	value = 2

/obj/item/ammo_casing/a765x25
	name = "7.65x25mm bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a765x25
	caliber = "a765x25"
	value = 2

/obj/item/ammo_casing/a762x25
	name = "7.62x25mm bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a762x25
	caliber = "a762x25"
	value = 2

/obj/item/ammo_casing/a792x33
	name = "7.92x33mm bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a792x33
	caliber = "a792x33"
	value = 2

/obj/item/ammo_casing/a545x39
	name = "5.45x39mm bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.04
	projectile_type = /obj/item/projectile/bullet/rifle/a545x39
	caliber = "a545x39"
	value = 2

/obj/item/ammo_casing/a556x45
	name = "5.56x45mm bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.04
	projectile_type = /obj/item/projectile/bullet/rifle/a556x45
	caliber = "a556x45"
	value = 2
/obj/item/ammo_casing/a762x51
	name = "7.62x51mm bullet"
	desc = "A brass casing."
	icon_state = "clip-bullet"
	spent_icon = "clip-casing"
	weight = 0.06
	projectile_type = /obj/item/projectile/bullet/rifle/a762x51
	caliber = "a762x51"
	value = 2

/obj/item/ammo_casing/a762x51/weak
	projectile_type = /obj/item/projectile/bullet/rifle/a762x51/weak
	caliber = "a762x51_weak"

/obj/item/ammo_casing/a762x39
	name = "7.62x39mm bullet"
	desc = "A brass casing."
	icon_state = "clip-bullet"
	spent_icon = "clip-casing"
	weight = 0.06
	projectile_type = /obj/item/projectile/bullet/rifle/a762x39
	caliber = "a762x39"
	value = 2

/obj/item/ammo_casing/a44p
	name = ".44 bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a44p
	caliber = "a44p"
	value = 2

/obj/item/ammo_casing/shotgun
	name = "buckshot shell"
	desc = "A 12 gauge buckshot."
	icon_state = "shell-bullet"
	spent_icon = "shell-casing"
	weight = 0.12
	projectile_type = /obj/item/projectile/bullet/shotgun/buckshot
	caliber = "12gauge"
	value = 2

/obj/item/ammo_casing/shotgun/slug
	name = "shotgun slug"
	desc = "A 12 gauge slug."
	icon_state = "slshell"
	spent_icon = "slshell_casing"
	projectile_type = /obj/item/projectile/bullet/shotgun/slug

/obj/item/ammo_casing/shotgun/beanbag
	name = "beanbag shell"
	desc = "A beanbag shell."
	icon_state = "bshell"
	spent_icon = "bshell_casing"
	projectile_type = /obj/item/projectile/bullet/shotgun/beanbag

//generic calibers for custom weapons
/obj/item/ammo_casing/largerifle
	name = "8mm bullet"
	desc = "A brass casing."
	icon_state = "kclip-bullet"
	spent_icon = "kclip-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/largerifle
	caliber = "largerifle"
	value = 8

/obj/item/ammo_casing/smallrifle
	name = "6.5mm bullet"
	desc = "A brass casing."
	icon_state = "clip-bullet"
	spent_icon = "clip-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/smallrifle
	caliber = "smallrifle"
	value = 8

/obj/item/ammo_casing/pistol45
	name = ".45 bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/pistol45
	caliber = "pistol45"
	value = 2
/obj/item/ammo_casing/pistol9
	name = "9mm bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/pistol9
	caliber = "pistol9"
	value = 2

/obj/item/ammo_casing/intermediumrifle
	name = "7.5mm bullet"
	desc = "A brass casing."
	icon_state = "clip-bullet"
	spent_icon = "clip-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/intermediumrifle
	caliber = "intermediumrifle"
	value = 8

/obj/item/ammo_casing/smallintermediumrifle
	name = "5.5mm bullet"
	desc = "A brass casing."
	icon_state = "pistol_bullet_anykind"
	spent_icon = "pistolcasing"
	weight = 0.04
	projectile_type = /obj/item/projectile/bullet/rifle/smallintermediumrifle
	caliber = "smallintermediumrifle"
	value = 2