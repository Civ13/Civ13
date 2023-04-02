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
	icon_state = "musketball_pistol_gunpowder"
	spent_icon = null
	projectile_type = /obj/item/projectile/bullet/rifle/musketball_pistol
	weight = 0.015
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

//Arrows

/obj/item/ammo_casing/arrow
	name = "arrow shaft"
	desc = "A headless arrow, not very effective."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "arrow"
	spent_icon = null
	projectile_type = /obj/item/projectile/arrow/arrow
	weight = 0.15
	caliber = "arrow"
	slot_flags = SLOT_BELT
	value = 2
	var/volume = 5

/obj/item/ammo_casing/arrow/gods
	name = "gods finger"
	desc = "A arrow that radiates holy wrath."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "arrow_god"
	projectile_type = /obj/item/projectile/arrow/arrow/fire/gods
	weight = 0.18

/obj/item/ammo_casing/arrow/flint
	name = "flint arrow"
	desc = "An arrow with a flint tip."
	icon_state = "arrow_flint"
	projectile_type = /obj/item/projectile/arrow/arrow/flint
	weight = 0.14

/obj/item/ammo_casing/arrow/stone
	name = "stone arrow"
	desc = "An arrow with a stone tip."
	icon_state = "arrow_stone"
	projectile_type = /obj/item/projectile/arrow/arrow/stone
	weight = 0.17

/obj/item/ammo_casing/arrow/sandstone
	name = "sandstone arrow"
	desc = "An arrow with a sandstone tip."
	icon_state = "arrow_sandstone"
	projectile_type = /obj/item/projectile/arrow/arrow/sandstone
	weight = 0.17

/obj/item/ammo_casing/arrow/copper
	name = "copper arrow"
	desc = "An arrow with a copper tip."
	icon_state = "arrow_copper"
	projectile_type = /obj/item/projectile/arrow/arrow/copper
	weight = 0.16

/obj/item/ammo_casing/arrow/iron
	name = "iron arrow"
	desc = "An arrow with a iron tip."
	icon_state = "arrow_iron"
	projectile_type = /obj/item/projectile/arrow/arrow/iron
	weight = 0.16

/obj/item/ammo_casing/arrow/bronze
	name = "bronze arrow"
	desc = "An arrow with a bronze tip."
	icon_state = "arrow_bronze"
	projectile_type = /obj/item/projectile/arrow/arrow/bronze
	weight = 0.16

/obj/item/ammo_casing/arrow/steel
	name = "steel arrow"
	desc = "An arrow with a steel tip."
	icon_state = "arrow_steel"
	projectile_type = /obj/item/projectile/arrow/arrow/steel
	weight = 0.17

/obj/item/ammo_casing/arrow/modern
	name = "fiberglass arrow"
	desc = "A modern, high-velocity arrow."
	icon_state = "arrow_modern"
	projectile_type = /obj/item/projectile/arrow/arrow/modern
	weight = 0.15

/obj/item/ammo_casing/arrow/vial
	name = "vial arrow"
	desc = "An iron-tipped arrow with a glass vial attached to the tip."
	icon_state = "arrow_vial"
	projectile_type = /obj/item/projectile/arrow/arrow/vial
	weight = 0.18
	volume = 15

/obj/item/ammo_casing/arrow/vial/poisonous
	name = "poison arrow"
	desc = "An arrow with a poison tip."
	icon_state = "arrow_vial"
	projectile_type = /obj/item/projectile/arrow/arrow/vial/poisonous

//Crossbow

/obj/item/ammo_casing/bolt
	name = "bolt shaft"
	desc = "A tipless crossbow bolt, not very effective."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "bolt"
	spent_icon = null
	projectile_type = /obj/item/projectile/arrow/bolt
	weight = 0.17
	caliber = "bolt"
	slot_flags = SLOT_BELT
	value = 2
	var/volume = 5

/obj/item/ammo_casing/bolt/flint
	name = "flint bolt"
	desc = "An bolt with a flint tip."
	icon_state = "bolt_flint"
	projectile_type = /obj/item/projectile/arrow/bolt/flint
	weight = 0.15

/obj/item/ammo_casing/bolt/stone
	name = "stone bolt"
	desc = "An bolt with a stone tip."
	icon_state = "bolt_stone"
	projectile_type = /obj/item/projectile/arrow/bolt/stone
	weight = 0.17

/obj/item/ammo_casing/bolt/sandstone
	name = "sandstone bolt"
	desc = "An bolt with a sandstone tip."
	icon_state = "bolt_sandstone"
	projectile_type = /obj/item/projectile/arrow/bolt/sandstone
	weight = 0.17

/obj/item/ammo_casing/bolt/copper
	name = "copper bolt"
	desc = "An bolt with a copper tip."
	icon_state = "bolt_copper"
	projectile_type = /obj/item/projectile/arrow/bolt/copper
	weight = 0.16
/obj/item/ammo_casing/bolt/gods
	name = "gods finger"
	desc = "A bolt that radiates holy wrath."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "bolt_god"
	projectile_type = /obj/item/projectile/arrow/bolt/fire/gods
	weight = 0.18

/obj/item/ammo_casing/bolt/iron
	name = "iron bolt"
	desc = "A crossbow bolt with a iron tip."
	icon_state = "bolt_iron"
	projectile_type = /obj/item/projectile/arrow/bolt/iron
	weight = 0.17

/obj/item/ammo_casing/bolt/bronze
	name = "bronze bolt"
	desc = "A crossbow bolt with a bronze tip."
	icon_state = "bolt_bronze"
	projectile_type = /obj/item/projectile/arrow/bolt/bronze
	weight = 0.17

/obj/item/ammo_casing/bolt/steel
	name = "steel bolt"
	desc = "A crossbow bolt with a steel tip."
	icon_state = "bolt_steel"
	projectile_type = /obj/item/projectile/arrow/bolt/steel
	weight = 0.18

/obj/item/ammo_casing/bolt/modern
	name = "fiberglass bolt"
	desc = "A modern, high-velocity crossbow bolt."
	icon_state = "bolt_modern"
	projectile_type = /obj/item/projectile/arrow/bolt/modern
	weight = 0.16
/obj/item/ammo_casing/bolt/vial
	name = "vial arrow"
	desc = "An iron-tipped bolt with a glass vial attached to the tip."
	icon_state = "bolt_vial"
	projectile_type = /obj/item/projectile/arrow/bolt/vial
	weight = 0.18
	volume = 15

//Sling

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

//Arrowheads

/obj/item/ammo_casing/arrow/attackby(obj/item/W as obj, mob/user as mob)
	if(istype(W, /obj/item/weapon/flint))
		var/obj/item/weapon/flint/F = W
		if (F.sharpened)
			new/obj/item/ammo_casing/arrow/flint(user.loc)
			qdel(F)
			playsound(loc, 'sound/machines/click.ogg', 25, TRUE)
			user << "<span class = 'notice'>You attach the [F] to the [src]</span>"
			qdel(src)

	if(istype(W, /obj/item/stack/arrowhead))
		var/obj/item/stack/arrowhead/AH = W
		if(istype(W, /obj/item/stack/arrowhead/stone))
			new/obj/item/ammo_casing/arrow/stone(user.loc)
		else if(istype(W, /obj/item/stack/arrowhead/copper))
			new/obj/item/ammo_casing/arrow/copper(user.loc)
		else if(istype(W, /obj/item/stack/arrowhead/iron))
			new/obj/item/ammo_casing/arrow/iron(user.loc)
		else if(istype(W, /obj/item/stack/arrowhead/bronze))
			new/obj/item/ammo_casing/arrow/bronze(user.loc)
		else if(istype(W, /obj/item/stack/arrowhead/steel))
			new/obj/item/ammo_casing/arrow/steel(user.loc)
		else if(istype(W, /obj/item/stack/arrowhead/vial))
			new/obj/item/ammo_casing/arrow/vial(user.loc)
		else
			new/obj/item/ammo_casing/arrow/gods(user.loc)
		AH.amount--
		if (AH.amount<1)
			qdel(AH)
		playsound(loc, 'sound/machines/click.ogg', 25, TRUE)
		user << "<span class = 'notice'>You attach the [W] to the [src]</span>"
		qdel(src)
	if (istype(W, /obj/item/weapon/reagent_containers))
		return //do nothing if not reagent container
	else
		if(volume < src.reagents)
			user << "<span class = 'notice'>You dip the [W] into the [src]</span>"
			W.reagents.trans_to_obj(src, volume - src.reagents)
	..()

/obj/item/ammo_casing/bolt/attackby(obj/item/W as obj, mob/user as mob)
	if(istype(W, /obj/item/weapon/flint))
		var/obj/item/weapon/flint/F = W
		if (F.sharpened)
			new/obj/item/ammo_casing/bolt/flint(user.loc)
			qdel(F)
		playsound(loc, 'sound/machines/click.ogg', 25, TRUE)
		user << "<span class = 'notice'>You attach the [W] to the [src]</span>"
		qdel(src)

	if(istype(W, /obj/item/stack/arrowhead))
		var/obj/item/stack/arrowhead/AH = W
		if(istype(W, /obj/item/stack/arrowhead/stone))
			new/obj/item/ammo_casing/bolt/stone(user.loc)
		else if(istype(W, /obj/item/stack/arrowhead/copper))
			new/obj/item/ammo_casing/bolt/copper(user.loc)
		else if(istype(W, /obj/item/stack/arrowhead/iron))
			new/obj/item/ammo_casing/bolt/iron(user.loc)
		else if(istype(W, /obj/item/stack/arrowhead/bronze))
			new/obj/item/ammo_casing/bolt/bronze(user.loc)
		else if(istype(W, /obj/item/stack/arrowhead/steel))
			new/obj/item/ammo_casing/bolt/steel(user.loc)
		else if(istype(W, /obj/item/stack/arrowhead/vial))
			new/obj/item/ammo_casing/bolt/vial(user.loc)
		else
			new/obj/item/ammo_casing/bolt/gods(user.loc)
		AH.amount--
		if (AH.amount<1)
			qdel(AH)
		playsound(loc, 'sound/machines/click.ogg', 25, TRUE)
		user << "<span class = 'notice'>You attach the [W] to the [src]</span>"
		qdel(src)
	if (istype(W, /obj/item/weapon/reagent_containers))
		return //do nothing if not reagent container
	else
		if(volume < src.reagents)
			user << "<span class = 'notice'>You dip the [W] into the [src]</span>"
			W.reagents.trans_to_obj(src, volume - src.reagents)
	..()


/obj/item/stack/arrowhead
	name = "god's finger"
	desc = "Radiates holy wrath, attach it to an arrow shaft."
	icon = 'icons/obj/items.dmi'
	icon_state = "gods_arrowhead"

/obj/item/stack/arrowhead/stone
	name = "stone arrowhead"
	desc = "Attach it to a arrow shaft."
	icon_state = "stone_arrowhead"

/obj/item/stack/arrowhead/copper
	name = "copper arrowhead"
	desc = "Attach it to a arrow shaft."
	icon_state = "copper_arrowhead"

/obj/item/stack/arrowhead/iron
	name = "iron arrowhead"
	desc = "Attach it to a arrow shaft."
	icon_state = "iron_arrowhead"

/obj/item/stack/arrowhead/bronze
	name = "bronze arrowhead"
	desc = "Attach it to a arrow shaft."
	icon_state = "bronze_arrowhead"

/obj/item/stack/arrowhead/steel
	name = "steel arrowhead"
	desc = "Attach it to a arrow shaft."
	icon_state = "steel_arrowhead"

/obj/item/stack/arrowhead/vial
	name = "vial arrowhead"
	desc = "Attach it to a arrow shaft."
	icon_state = "vial_arrowhead"

//Ammo with gunpoweder

/obj/item/stack/ammopart
	var/resultpath = /obj/item/ammo_casing/musketball
	amount = 1
	max_amount = 20
	singular_name = "projectile"
	value = 0
	flags = CONDUCT

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
	w_class = ITEM_SIZE_NORMAL
	flags = FALSE

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

/obj/item/stack/ammopart/casing/tank
	name = "empty cannon casing"
	desc = "A large empty brass casing."
	icon = 'icons/obj/cannon_ball.dmi'
	icon_state = "shell_tank_casing"
	force = WEAPON_FORCE_HARMLESS+1
	throwforce = WEAPON_FORCE_HARMLESS+2
	resultpath = null
	gunpowder_max = 5
	max_amount = 1
	value = 4
	var/caliber = 75

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

/obj/item/stack/ammopart/casing/artillery/wired
	name = "wired empty artillery casing"
	desc = "A large empty brass casing. Has some wired crudely attached"
	icon = 'icons/obj/cannon_ball.dmi'
	icon_state = "casing_wired"
	force = WEAPON_FORCE_HARMLESS+1
	throwforce = WEAPON_FORCE_HARMLESS+2
	resultpath = null
	gunpowder_max = 5
	max_amount = 1
	value = 4

/obj/item/stack/ammopart/casing/artillery/wired/advanced
	name = "advanced empty artillery casing"
	desc = "A large empty brass casing. Some electronics are wired to it."
	icon = 'icons/obj/cannon_ball.dmi'
	icon_state = "casing_advanced"
	force = WEAPON_FORCE_HARMLESS+1
	throwforce = WEAPON_FORCE_HARMLESS+2
	resultpath = null
	gunpowder_max = 5
	max_amount = 1
	value = 4

/obj/item/stack/ammopart/casing/artillery/wired/advanced/filled
	name = "uranium filled artillery casing"
	desc = "A large brass casing. Wired up to some uranium and electronics."
	icon = 'icons/obj/cannon_ball.dmi'
	icon_state = "casing"
	force = WEAPON_FORCE_HARMLESS+1
	throwforce = WEAPON_FORCE_HARMLESS+2
	resultpath = null
	gunpowder_max = 5
	max_amount = 1
	value = 4

/obj/item/stack/ammopart/casing/grenade
	name = "empty grenade casing"
	desc = "An empty grenade casing."
	icon = 'icons/obj/grenade.dmi'
	icon_state = "casing"
	force = WEAPON_FORCE_HARMLESS+4
	throwforce = WEAPON_FORCE_HARMLESS+7
	resultpath = null
	gunpowder_max = 2
	max_amount = 1
	value = 4
	var/finished = FALSE
	var/stype = "explosive"

/obj/item/stack/ammopart/casing/booster
	name = "empty rocket booster"
	desc = "A large empty rocket booster."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "rocketcasing_booster"
	force = WEAPON_FORCE_HARMLESS+5
	throwforce = WEAPON_FORCE_HARMLESS+7
	resultpath = null
	gunpowder_max = 15
	max_amount = 1
	value = 10

/obj/item/stack/ammopart/warhead
	name = "empty rocket warhead"
	desc = "A large empty rocket warhead."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "rocketcasing_warhead"
	force = WEAPON_FORCE_HARMLESS+3
	throwforce = WEAPON_FORCE_HARMLESS+6
	value = 20

/obj/item/ammo_casing/a65x50
	name = "6.5x50mm Arisaka cartridge"
	desc = "A brass casing containing powder and a lead bullet."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a65x50
	caliber = "a65x50"
	value = 5

/obj/item/ammo_casing/a50cal
	name = ".50 BMG cartridge"
	desc = "A big heavy brass casing designed to take out unarmored targets."
	icon_state = "big-bullet"
	spent_icon = "big-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a50cal
	caliber = "a50cal"
	value = 7

/obj/item/ammo_casing/a50cal/weak
	name = ".50 BMG cartridge"
	desc = "A big heavy brass casing designed to take out unarmored targets."
	icon_state = "big-bullet"
	spent_icon = "big-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a50cal/weak
	caliber = "a50cal"
	value = 7

/obj/item/ammo_casing/a50cal_ap
	name = ".50 BMG AP cartridge"
	desc = "A big heavy brass casing designed to penetrate armor."
	icon_state = "big-bullet"
	spent_icon = "big-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a50cal_ap
	caliber = "a50cal"
	value = 7

/obj/item/ammo_casing/a50cal_he
	name = ".50 BMG HE cartridge"
	desc = "A big heavy brass casing designed to explode on impact."
	icon_state = "big-bullet"
	spent_icon = "big-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a50cal_he
	caliber = "a50cal"
	value = 7

/obj/item/ammo_casing/a145
	name = "14.5x114 cartridge"
	desc = "A big heavy brass casing designed to penetrate armor."
	icon_state = "big-bullet"
	spent_icon = "big-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a145
	caliber = "a145"
	value = 7

/obj/item/ammo_casing/a145_ap
	name = "14.5x114 AP cartridge"
	desc = "A big heavy brass casing designed to penetrate armor."
	icon_state = "big-bullet"
	spent_icon = "big-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a145_ap
	caliber = "a145"
	value = 7

/obj/item/ammo_casing/a15115
	name = "15x115 cartridge"
	desc = "A big heavy brass casing designed to penetrate armor."
	icon_state = "big-bullet"
	spent_icon = "big-casing"
	weight = 0.10
	projectile_type = /obj/item/projectile/bullet/rifle/a15115
	caliber = "a15115"
	value = 25

/obj/item/ammo_casing/a15115_ap
	name = "15x115 AP cartridge"
	desc = "A big heavy brass casing designed to penetrate armor."
	icon_state = "big-bullet"
	spent_icon = "big-casing"
	weight = 0.10
	projectile_type = /obj/item/projectile/bullet/rifle/a15115_ap
	caliber = "a15115"
	value = 30

/obj/item/ammo_casing/a15115_aphe
	name = "15x115 APHE cartridge"
	desc = "A big heavy brass casing designed to explode after penetrating armor."
	icon_state = "big-bullet"
	spent_icon = "big-casing"
	weight = 0.12
	projectile_type = /obj/item/projectile/bullet/rifle/a15115_aphe
	caliber = "a15115"
	value = 35

/obj/item/ammo_casing/a792x94
	name = "7.92x94mm cartridge"
	desc = "A big heavy brass casing designed to penetrate armor."
	icon_state = "big-bullet"
	spent_icon = "big-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a792x94
	caliber = "a792x94"
	value = 7

/obj/item/ammo_casing/a792x94_ap
	name = "7.92x94mm AP cartridge"
	desc = "A big heavy brass casing designed to penetrate armor."
	icon_state = "big-bullet"
	spent_icon = "big-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a792x94_ap
	caliber = "a792x94"
	value = 12

/obj/item/ammo_casing/a65x50/weak
	projectile_type = /obj/item/projectile/bullet/rifle/a65x50/weak
	caliber = "a65x50_weak"

/obj/item/ammo_casing/a65x52
	name = "6.5x52mm Carcano cartridge"
	desc = "A brass casing containing powder and a lead bullet."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a65x52
	caliber = "a65x52"
	value = 5

/obj/item/ammo_casing/a8x53
	name = "8x53mm Murata cartridge"
	desc = "A brass casing containing powder and a lead bullet."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a8x53
	caliber = "a8x53"
	value = 5

/obj/item/ammo_casing/a8x50
	name = "8x50mmR Lebel cartridge"
	desc = "A brass casing containing powder and a lead bullet."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a8x50
	caliber = "a8x50"
	value = 5

/obj/item/ammo_casing/a8x50/weak
	projectile_type = /obj/item/projectile/bullet/rifle/a8x50/weak
	caliber = "a8x50_weak"

/obj/item/ammo_casing/c9mm_jap_revolver
	name = "9x22mm Type 26 cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/c9mm_jap_revolver
	caliber = "c9mm_jap_revolver"
	value = 5

/obj/item/ammo_casing/a41
	name = ".41 Short cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.04
	projectile_type = /obj/item/projectile/bullet/pistol/a41
	caliber = "a41"
	value = 7

/obj/item/ammo_casing/a43
	name = ".43 Spanish cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.04
	projectile_type = /obj/item/projectile/bullet/pistol/a43
	caliber = "a43"
	value = 7

/obj/item/ammo_casing/a32
	name = ".32 S&W cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.04
	projectile_type = /obj/item/projectile/bullet/pistol/a32
	caliber = "a32"
	value = 5

/obj/item/ammo_casing/a38
	name = ".38 cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.04
	projectile_type = /obj/item/projectile/bullet/pistol/a38
	caliber = "a38"
	value = 5
/obj/item/ammo_casing/a380acp
    name = ".380 ACP Cartridge"
    desc = "A short but medium sized pistol cartridge."
    icon_state = "pistol-bullet"
    spent_icon = "pistol-casing"
    weight = 0.05
    projectile_type = /obj/item/projectile/bullet/pistol/a380acp
    caliber = "a380acp"
    value = 5

/obj/item/ammo_casing/a45
	name = ".45 Long Colt cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a45
	caliber = "a45"
	value = 7

/obj/item/ammo_casing/a45acp
	name = ".45 ACP cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a45
	caliber = "a45acp"
	value = 7

/obj/item/ammo_casing/a455
	name = ".455 Webley cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a455
	caliber = "a455"
	value = 7

/obj/item/ammo_casing/a44
	name = ".44-40 Winchester cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a44
	caliber = "a44"
	value = 8

/obj/item/ammo_casing/a44magnum
	name = ".44 Magnum cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a44magnum
	caliber = "a44magnum"
	value = 8

/obj/item/ammo_casing/a4570
	name = ".45-70 Government cartridge"
	desc = "A brass casing."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a4570
	caliber = "a4570"
	value = 8

/obj/item/ammo_casing/a792x57
	name = "7.92x57mm Mauser cartridge"
	desc = "A brass casing."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a792x57
	caliber = "a792x57"
	value = 8

/obj/item/ammo_casing/a792x57/weak
	projectile_type = /obj/item/projectile/bullet/rifle/a792x57/weak
	caliber = "a792x57_weak"

/obj/item/ammo_casing/a765x53
	name = "7.65x53mm Mauser cartridge"
	desc = "A brass casing."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a765x53
	caliber = "a765x53"
	value = 8

/obj/item/ammo_casing/a765x25
	name = "7.65x25mm Borchardt cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.08
	projectile_type = /obj/item/projectile/bullet/rifle/a765x25
	caliber = "a765x25"
	value = 8

/obj/item/ammo_casing/a7x57
	name = "7x57mm Mauser cartridge"
	desc = "A brass casing."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.076
	projectile_type = /obj/item/projectile/bullet/rifle/a7x57
	caliber = "a7x57"
	value = 8

/obj/item/ammo_casing/a77x58
	name = "7.7x58mm Arisaka cartridge"
	desc = "A brass casing."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.076
	projectile_type = /obj/item/projectile/bullet/rifle/a77x58
	caliber = "a77x58"
	value = 8

/obj/item/ammo_casing/a77x58_wood
	name = "7.7x58mm bullet"
	desc = "A brass casing."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.076
	projectile_type = /obj/item/projectile/bullet/rifle/a77x58_wood
	caliber = "a77x58_wood"
	value = 6

/obj/item/ammo_casing/a577
	name = ".577/450 Martini-Henry cartridge"
	desc = "A brass casing."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.11
	projectile_type = /obj/item/projectile/bullet/rifle/a577
	caliber = "a577"
	value = 8


/obj/item/ammo_casing/a762x54
	name = "7.62x54mmR cartridge"
	desc = "A brass casing."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a762x54
	caliber = "a762x54"
	value = 2

/obj/item/ammo_casing/a762x54/weak
	projectile_type = /obj/item/projectile/bullet/rifle/a762x54/weak
	caliber = "a762x54_weak"

/obj/item/ammo_casing/a303
	name = ".303 british cartridge"
	desc = "A brass casing."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a303
	caliber = "a303"
	value = 2

/obj/item/ammo_casing/a303/weak
	projectile_type = /obj/item/projectile/bullet/rifle/a303/weak
	caliber = "a303_weak"

/obj/item/ammo_casing/a3006
	name = ".30-06 cartridge"
	desc = "A brass casing."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a3006
	caliber = "a3006"
	value = 2

/obj/item/ammo_casing/a3006/weak
	projectile_type = /obj/item/projectile/bullet/rifle/a3006/weak
	caliber = "a3006_weak"

/obj/item/ammo_casing/a762x38
	name = "7.62x38mmR cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a762x38
	caliber = "a762x38"
	value = 5

/obj/item/ammo_casing/a8x27
	name = "8x27mmR french ordnance cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a8x27
	caliber = "a8x27"
	value = 5

/obj/item/ammo_casing/c8mmnambu
	name = "8x22mm Nambu Cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/c8mmnambu
	caliber = "c8mmnambu"
	value = 2

/obj/item/ammo_casing/a9x19
	name = "9x19mm cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a9x19
	caliber = "a9x19"
	value = 2

/obj/item/ammo_casing/a9x18
	name = "9x18mm Makarov cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a9x18
	caliber = "a9x18"
	value = 2

/obj/item/ammo_casing/a765x25
	name = "7.65x25 Borchardt cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a765x25
	caliber = "a765x25"
	value = 2

/obj/item/ammo_casing/a762x25
	name = "7.62x25mm TT cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a762x25
	caliber = "a762x25"
	value = 2

/obj/item/ammo_casing/a762x25/rubber
	name = "7.62x25mm rubber cartridge"
	desc = "A wooden casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/rubber/a762x25
	caliber = "a762x25"
	value = 2

/obj/item/ammo_casing/a792x33
	name = "7.92x33mm cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a792x33
	caliber = "a792x33"
	value = 2

/obj/item/ammo_casing/a545x39
	name = "5.45x39mm cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.04
	projectile_type = /obj/item/projectile/bullet/rifle/a545x39
	caliber = "a545x39"
	value = 2
/obj/item/ammo_casing/a545x39/rubber
	name = "5.45x39mm cartridge Rubber"
	desc = "A rubbery brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.04
	projectile_type = /obj/item/projectile/bullet/pistol/rubber/a54x39
	caliber = "a545x39"
	value = 2

/obj/item/ammo_casing/a32acp
	name = ".32 ACP cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.03
	projectile_type = /obj/item/projectile/bullet/pistol/a32acp
	caliber = "a32acp"
	value = 2

/obj/item/ammo_casing/webly445
	name = "Bugged bullet"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.03
	projectile_type = /obj/item/projectile/bullet/pistol/webly445
	caliber = "webly445"
	value = 2

/obj/item/ammo_casing/a556x45
	name = "5.56x45mm NATO cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.04
	projectile_type = /obj/item/projectile/bullet/rifle/a556x45
	caliber = "a556x45"
	value = 2
/obj/item/ammo_casing/a762x51
	name = "7.62x51mm NATO cartridge"
	desc = "A brass casing."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.06
	projectile_type = /obj/item/projectile/bullet/rifle/a762x51
	caliber = "a762x51"
	value = 2

/obj/item/ammo_casing/a762x51/weak
	projectile_type = /obj/item/projectile/bullet/rifle/a762x51/weak
	caliber = "a762x51_weak"

/obj/item/ammo_casing/a762x39
	name = "7.62x39mm cartridge"
	desc = "A brass casing."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.06
	projectile_type = /obj/item/projectile/bullet/rifle/a762x39
	caliber = "a762x39"
	value = 2

/obj/item/ammo_casing/a762x33
	name = "7.62x33mm cartridge"
	desc = "A brass casing."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/rifle/a762x33
	caliber = "a762x33"
	value = 2

/obj/item/ammo_casing/a9x39
	name = "9x39mm cartridge"
	desc = "A brass soviet rifle casing."
	icon_state = "rifle-bullet"
	spent_icon = "rifle-casing"
	weight = 0.09
	projectile_type = /obj/item/projectile/bullet/rifle/a9x39
	caliber = "a9x39"
	value = 2

/obj/item/ammo_casing/a44p
	name = "Bugged bullet"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a44p
	caliber = "a44p"
	value = 2

/obj/item/ammo_casing/a57x28
	name = "57x28mm cartridge"
	desc = "A brass casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.05
	projectile_type = /obj/item/projectile/bullet/pistol/a57x28
	caliber = "a57x28"
	value = 2

/obj/item/ammo_casing/a58x42
	name = "5.8x42mm cartridge"
	desc = "A rimless bottlenecked casing."
	icon_state = "pistol-bullet"
	spent_icon = "pistol-casing"
	weight = 0.04
	projectile_type = /obj/item/projectile/bullet/rifle/a58x42
	caliber = "a58x42"
	value = 2

/obj/item/ammo_casing/a30mm_ap
	name = "3UBR6 AP"
	desc = "A VERY big brass casing."
	icon_state = "huge-bullet"
	spent_icon = "huge-casing"
	weight = 1
	projectile_type = /obj/item/projectile/bullet/autocannon/a30mm_ap
	caliber = "a30"
	value = 2

/obj/item/ammo_casing/frag/a30mm_he
	name = "3UOR6 HE"
	desc = "A VERY big brass casing."
	icon_state = "huge-bullet"
	spent_icon = "huge-casing"
	weight = 1
	projectile_type = /obj/item/projectile/bullet/autocannon/frag/a30mm_he
	caliber = "a30"
	value = 2

// Shotguns

/obj/item/ammo_casing/shotgun
	caliber = "12gauge"
	weight = 0.12
	value = 2
/obj/item/ammo_casing/shotgun/buckshot
	name = "buckshot shell"
	desc = "A 12 gauge buckshot."
	icon_state = "shell-shell"
	spent_icon = "shell-casing"
	projectile_type = /obj/item/projectile/bullet/pellet/buckshot

/obj/item/ammo_casing/shotgun/slug
	name = "shotgun slug"
	desc = "A 12 gauge slug."
	icon_state = "slug-shell"
	spent_icon = "slug-spent"
	projectile_type = /obj/item/projectile/bullet/shotgun/slug

/obj/item/ammo_casing/shotgun/beanbag
	name = "beanbag shell"
	desc = "A beanbag shell."
	icon_state = "beanbag-shell"
	spent_icon = "beanbag-spent"
	projectile_type = /obj/item/projectile/bullet/shotgun/beanbag

/obj/item/ammo_casing/shotgun/rubber
	name = "rubber shot"
	desc = "A rubber shell."
	icon_state = "rubbershot-shell"
	spent_icon = "rubbershot-spent"
	projectile_type = /obj/item/projectile/bullet/pellet/rubber


/obj/item/ammo_casing/shotgun/incendiary
	name = "incendiary shotgun slug"
	desc = "A 12 gauge incendiary slug."
	icon_state = "dragons-breath-shell"
	spent_icon = "dragons-breath-spent"
	projectile_type = /obj/item/projectile/bullet/shotgun/incendiary

/obj/item/ammo_casing/flare
	name = "flare shell"
	desc = "A flare shell."
	icon_state = "flaregun-shell"
	spent_icon = "flaregun-spent"
	projectile_type = /obj/item/projectile/flare

// Lasers

/obj/item/ammo_casing/laser
	name = "laser bolt"
	desc = "you shouldnt be seeing this"
	caliber = "laser"
	icon_state = "darts"
	spent_icon = "darts-0"
	projectile_type = /obj/item/projectile/laser
	leaves_residue = FALSE

/obj/item/ammo_casing/laser/b
	projectile_type = /obj/item/projectile/laser/b
	caliber = "laserb"
/obj/item/ammo_casing/laser/g
	projectile_type = /obj/item/projectile/laser/g
	caliber = "laserg"
/obj/item/ammo_casing/laser/pistol
	name = "pistol laser bolt"
	projectile_type = /obj/item/projectile/laser/pistol
	caliber = "laser_pistol"

/obj/item/ammo_casing/laser/pistol/b
	name = "pistol laser bolt"
	projectile_type = /obj/item/projectile/laser/pistol/b
	caliber = "laser_pistolb"
/obj/item/ammo_casing/laser/pistol/g
	name = "pistol laser bolt"
	projectile_type = /obj/item/projectile/laser/pistol/g
	caliber = "laser_pistolg"

/obj/item/ammo_casing/laser/repeating
	name = "laser bolt"
	desc = "you shouldnt be seeing this"
	caliber = "laser"
	icon_state = "darts"
	spent_icon = "darts-0"
	projectile_type = /obj/item/projectile/laser/repeating
	leaves_residue = FALSE