/* Surgery Tools
 * Contains:
 *		Retractor
 *		Hemostat
 *		Cautery
 *		Scalpel
 *		Bone Saw
 */

/*
 * Retractor
 */
/obj/item/weapon/surgery/retractor
	name = "retractor"
	desc = "Retracts stuff."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "retractor"
	matter = list(DEFAULT_WALL_MATERIAL = 10000, "glass" = 5000)
	flags = CONDUCT
	w_class = 2.0

/obj/item/weapon/surgery/retractor/bronze
	name = "bronze retractor"
	desc = "Retracts stuff."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "bronze_retractor"
	matter = list(DEFAULT_WALL_MATERIAL = 10000, "glass" = 5000)
	flags = CONDUCT
	w_class = 2.0
/*
 * Hemostat
 */
/obj/item/weapon/surgery/hemostat
	name = "hemostat"
	desc = "Pinches veins. Prevents bleeding."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "hemostat"
	matter = list(DEFAULT_WALL_MATERIAL = 5000, "glass" = 2500)
	flags = CONDUCT
	w_class = 2.0
	attack_verb = list("attacked", "pinched")

/obj/item/weapon/surgery/hemostat/bronze
	name = "bronze hemostat"
	desc = "Pinches veins. Prevents bleeding."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "bronze_hemostat"
	matter = list(DEFAULT_WALL_MATERIAL = 5000, "glass" = 2500)
	flags = CONDUCT
	w_class = 2.0
	attack_verb = list("attacked", "pinched")
/*
 * Cautery
 */
/obj/item/weapon/surgery/cautery
	name = "cautery"
	desc = "A hot iron. Closes wounds and stops bleeding."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "cautery"
	matter = list(DEFAULT_WALL_MATERIAL = 5000, "glass" = 2500)
	flags = CONDUCT
	w_class = 2.0
	attack_verb = list("burnt")

/obj/item/weapon/surgery/cautery/bronze
	name = "bronze cautery"
	desc = "A hot bronze clamp. Closes wounds and stops bleeding."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "bronze_cautery"
	matter = list(DEFAULT_WALL_MATERIAL = 5000, "glass" = 2500)
	flags = CONDUCT
	w_class = 2.0
	attack_verb = list("burnt")
/*
 * Scalpel
 */
/obj/item/weapon/surgery/scalpel
	name = "scalpel"
	desc = "Cut, cut, and once more cut."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "scalpel"
	flags = CONDUCT
	force = WEAPON_FORCE_DANGEROUS
	sharp = TRUE
	edge = TRUE
	w_class = TRUE
	slot_flags = SLOT_EARS
	throwforce = 5.0
	throw_speed = WEAPON_FORCE_WEAK
	throw_range = 5
	matter = list(DEFAULT_WALL_MATERIAL = 10000, "glass" = 5000)
	attack_verb = list("attacked", "slashed", "stabbed", "sliced", "torn", "ripped", "diced", "cut")

/obj/item/weapon/surgery/scalpel/bronze
	name = "bronze scalpel"
	desc = "Cut, cut, and once more cut."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "bronze_scalpel"
	flags = CONDUCT
	force = WEAPON_FORCE_DANGEROUS
	sharp = TRUE
	edge = TRUE
	w_class = TRUE
	slot_flags = SLOT_EARS
	throwforce = 5.0
	throw_speed = WEAPON_FORCE_WEAK
	throw_range = 5
	matter = list(DEFAULT_WALL_MATERIAL = 10000, "glass" = 5000)
	attack_verb = list("attacked", "slashed", "stabbed", "sliced", "torn", "ripped", "diced", "cut")
/*
 * Circular Saw
 */
/obj/item/weapon/surgery/bone_saw
	name = "bone saw"
	desc = "For heavy duty cutting."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "saw"
	hitsound = 'sound/weapons/circsawhit.ogg'
	flags = CONDUCT
	force = WEAPON_FORCE_ROBUST
	w_class = 3
	throwforce = WEAPON_FORCE_WEAK
	throw_speed = 3
	throw_range = 5
	matter = list(DEFAULT_WALL_MATERIAL = 20000,"glass" = 10000)
	attack_verb = list("attacked", "slashed", "sawed", "cut")
	sharp = TRUE
	edge = TRUE

/obj/item/weapon/surgery/bone_saw/bronze
	name = "bronze bone saw"
	desc = "For heavy duty cutting."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "bronze_bonesaw"
	hitsound = 'sound/weapons/circsawhit.ogg'
	flags = CONDUCT
	force = WEAPON_FORCE_ROBUST
	w_class = 3
	throwforce = WEAPON_FORCE_WEAK
	throw_speed = 3
	throw_range = 5
	matter = list(DEFAULT_WALL_MATERIAL = 20000,"glass" = 10000)
	attack_verb = list("attacked", "slashed", "sawed", "cut")
	sharp = TRUE
	edge = TRUE
//misc, formerly from code/defines/weapons.dm


/obj/item/weapon/surgery/bonesetter
	name = "bone setter"
	desc = "To set bones in place."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "bone setter"
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = 3
	throw_range = 5
	w_class = 2.0
	attack_verb = list("attacked", "hit", "bludgeoned")

/obj/item/weapon/surgery/bonesetter/bronze
	name = "bronze bone setter"
	desc = "To set bones in place."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "bronze_bonesetter"
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = 3
	throw_range = 5
	w_class = 2.0
	attack_verb = list("attacked", "hit", "bludgeoned")
