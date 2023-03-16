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
	flags = CONDUCT
	w_class = ITEM_SIZE_SMALL

/obj/item/weapon/surgery/retractor/bronze
	name = "bronze retractor"
	desc = "Retracts stuff."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "bronze_retractor"
	flags = CONDUCT
	w_class = ITEM_SIZE_SMALL
/*
 * Hemostat
 */
/obj/item/weapon/surgery/hemostat
	name = "hemostat"
	desc = "Pinches veins. Prevents bleeding."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "hemostat"
	flags = CONDUCT
	w_class = ITEM_SIZE_SMALL
	attack_verb = list("attacked", "pinched")

/obj/item/weapon/surgery/hemostat/bronze
	name = "bronze hemostat"
	desc = "Pinches veins. Prevents bleeding."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "bronze_hemostat"
	flags = CONDUCT
	w_class = ITEM_SIZE_SMALL
	attack_verb = list("attacked", "pinched")
/*
 * Cautery
 */
/obj/item/weapon/surgery/cautery
	name = "cautery"
	desc = "A hot iron. Closes wounds and stops bleeding."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "cautery"
	flags = CONDUCT
	w_class = ITEM_SIZE_SMALL
	attack_verb = list("burnt")

/obj/item/weapon/surgery/cautery/bronze
	name = "bronze cautery"
	desc = "A hot bronze clamp. Closes wounds and stops bleeding."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "bronze_cautery"
	flags = CONDUCT
	w_class = ITEM_SIZE_SMALL
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
	w_class = ITEM_SIZE_TINY
	slot_flags = SLOT_EARS
	throwforce = 5.0
	throw_speed = WEAPON_FORCE_WEAK
	throw_range = 5
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
	w_class = ITEM_SIZE_TINY
	slot_flags = SLOT_EARS
	throwforce = 5.0
	throw_speed = WEAPON_FORCE_WEAK
	throw_range = 5
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
	w_class = ITEM_SIZE_NORMAL
	throwforce = WEAPON_FORCE_WEAK
	throw_speed = 3
	throw_range = 5
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
	w_class = ITEM_SIZE_NORMAL
	throwforce = WEAPON_FORCE_WEAK
	throw_speed = 3
	throw_range = 5
	attack_verb = list("attacked", "slashed", "sawed", "cut")
	sharp = TRUE
	edge = TRUE
//misc, formerly from code/defines/weapons.dm

/obj/item/weapon/surgery/surgicaldrill
	name = "surgical drill"
	desc = "You can drill using this item. You dig?"
	icon = 'icons/obj/surgery.dmi'
	icon_state = "drill"
	hitsound = 'sound/weapons/circsawhit.ogg'
	flags = CONDUCT
	force = WEAPON_FORCE_DANGEROUS
	w_class = ITEM_SIZE_NORMAL
	attack_verb = list("drilled")

/obj/item/weapon/surgery/bonesetter
	name = "bone setter"
	desc = "To set bones in place."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "bone setter"
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = 3
	throw_range = 5
	w_class = ITEM_SIZE_SMALL
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
	w_class = ITEM_SIZE_SMALL
	attack_verb = list("attacked", "hit", "bludgeoned")
