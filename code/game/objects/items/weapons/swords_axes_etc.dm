/* Weapons
 * Contains:
 *		Sword
 *		Classic Baton
 */

/*
 * Classic Baton
 */
/obj/item/weapon/melee/classic_baton
	name = "police baton"
	desc = "A wooden truncheon for beating criminal scum."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "baton"
	item_state = "classic_baton"
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_PAINFUL

/obj/item/weapon/melee/classic_baton/attack(mob/M as mob, mob/living/user as mob)
	if ((CLUMSY in user.mutations) && prob(50))
		user << "<span class='warning'>You club yourself over the head.</span>"
		user.Weaken(3 * force)
		if (ishuman(user))
			var/mob/living/carbon/human/H = user
			H.apply_damage(2*force, BRUTE, "head")
		else
			user.take_organ_damage(2*force)
		return
	return ..()