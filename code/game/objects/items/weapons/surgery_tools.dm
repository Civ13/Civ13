/* Surgery Tools
 * Contains:
 *		Retractor
 *		Hemostat
 *		Cautery
 *		Surgical Drill
 *		Scalpel
 *		Circular Saw
 */

/*
 * Retractor
 */
/obj/item/weapon/retractor
	name = "retractor"
	desc = "Retracts stuff."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "retractor"
	matter = list(DEFAULT_WALL_MATERIAL = 10000, "glass" = 5000)
	flags = CONDUCT
	w_class = 2.0
/*
 * Hemostat
 */
/obj/item/weapon/hemostat
	name = "hemostat"
	desc = "Pinches veins. Prevents bleeding."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "hemostat"
	matter = list(DEFAULT_WALL_MATERIAL = 5000, "glass" = 2500)
	flags = CONDUCT
	w_class = 2.0
//	origin_tech = list(TECH_MATERIAL = TRUE, TECH_BIO = TRUE)
	attack_verb = list("attacked", "pinched")
/*
 * Cautery
 */
/obj/item/weapon/cautery
	name = "cautery"
	desc = "A hot iron. Closes wounds and stops bleeding."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "cautery"
	matter = list(DEFAULT_WALL_MATERIAL = 5000, "glass" = 2500)
	flags = CONDUCT
	w_class = 2.0
//	origin_tech = list(TECH_MATERIAL = TRUE, TECH_BIO = TRUE)
	attack_verb = list("burnt")
/*
 * Surgical Drill
 */
/obj/item/weapon/surgicaldrill
	name = "surgical drill"
	desc = "You can drill using this item. You dig?"
	icon = 'icons/obj/surgery.dmi'
	icon_state = "drill"
	hitsound = 'sound/weapons/circsawhit.ogg'
	matter = list(DEFAULT_WALL_MATERIAL = 15000, "glass" = 10000)
	flags = CONDUCT
	force = WEAPON_FORCE_DANGEROUS
	w_class = 3
//	origin_tech = list(TECH_MATERIAL = TRUE, TECH_BIO = TRUE)
	attack_verb = list("drilled")
/*
 * Scalpel
 */
/obj/item/weapon/scalpel
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
//	origin_tech = list(TECH_MATERIAL = TRUE, TECH_BIO = TRUE)
	matter = list(DEFAULT_WALL_MATERIAL = 10000, "glass" = 5000)
	attack_verb = list("attacked", "slashed", "stabbed", "sliced", "torn", "ripped", "diced", "cut")

/*
 * Circular Saw
 */
/obj/item/weapon/bone_saw
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
//	origin_tech = list(TECH_MATERIAL = TRUE, TECH_BIO = TRUE)
	matter = list(DEFAULT_WALL_MATERIAL = 20000,"glass" = 10000)
	attack_verb = list("attacked", "slashed", "sawed", "cut")
	sharp = TRUE
	edge = TRUE

//misc, formerly from code/defines/weapons.dm


/obj/item/weapon/bonesetter
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
