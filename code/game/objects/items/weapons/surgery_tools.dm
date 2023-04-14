/* Surgery Tools
 * Contains:
 *		Retractor
 *		Hemostat
 *		Cautery
 *		Scalpel
 *		Bone Saw
 */


/obj/item/weapon/surgery
	name = "surgery tool (do not use)"
	desc = "This object shouldn't be here. Contact a developer."
	icon = 'icons/obj/surgery.dmi'
	flags = CONDUCT
	w_class = ITEM_SIZE_SMALL

/obj/item/weapon/surgery/attack(mob/M as mob, mob/living/user as mob)
	if	(user.a_intent == I_HELP)	//A tad messy, but this should stop people from smacking their patients in surgery
		return FALSE
	..()
/*
 * Retractor
 */
/obj/item/weapon/surgery/retractor
	name = "retractor"
	desc = "Retracts stuff."
	icon_state = "retractor"

/obj/item/weapon/surgery/retractor/bronze
	name = "bronze retractor"
	icon_state = "bronze_retractor"

/*
 * Hemostat
 */
/obj/item/weapon/surgery/hemostat
	name = "hemostat"
	desc = "Pinches veins. Prevents bleeding."
	icon_state = "hemostat"
	attack_verb = list("attacked", "pinched")

/obj/item/weapon/surgery/hemostat/bronze
	name = "bronze hemostat"
	icon_state = "bronze_hemostat"
	attack_verb = list("attacked", "pinched")
/*
 * Cautery
 */
/obj/item/weapon/surgery/cautery
	name = "cautery"
	desc = "A hot iron. Closes wounds and stops bleeding."
	icon_state = "cautery"
	attack_verb = list("burnt")

/obj/item/weapon/surgery/cautery/bronze
	name = "bronze cautery"
	desc = "A hot bronze clamp. Closes wounds and stops bleeding."
	icon_state = "bronze_cautery"
	attack_verb = list("burnt")
/*
 * Scalpel
 */
/obj/item/weapon/surgery/scalpel
	name = "scalpel"
	desc = "Cut, cut, and once more cut."
	icon_state = "scalpel"
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
	icon_state = "bronze_scalpel"
/*
 * Circular Saw
 */
/obj/item/weapon/surgery/bone_saw
	name = "bone saw"
	desc = "For heavy duty cutting."
	icon_state = "saw"
	hitsound = 'sound/weapons/circsawhit.ogg'
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
	icon_state = "bronze_bonesaw"

//misc, formerly from code/defines/weapons.dm

/obj/item/weapon/surgery/surgicaldrill
	name = "surgical drill"
	desc = "You can drill using this item. You dig?"
	icon_state = "drill"
	hitsound = 'sound/weapons/circsawhit.ogg'
	force = WEAPON_FORCE_DANGEROUS
	w_class = ITEM_SIZE_NORMAL
	attack_verb = list("drilled")

/obj/item/weapon/surgery/bonesetter
	name = "bone setter"
	desc = "To set bones in place."
	icon_state = "bone setter"
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = 3
	throw_range = 5
	attack_verb = list("attacked", "hit", "bludgeoned")

/obj/item/weapon/surgery/bonesetter/bronze
	name = "bronze bone setter"
	icon_state = "bronze_bonesetter"
