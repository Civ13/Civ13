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
	force = WEAPON_FORCE_WEAK
	var/weakens = 1
	flammable = TRUE

/obj/item/weapon/melee/classic_baton/club
	name = "wood club"
	desc = "One of the oldest weapons in the world. Good for when you need to knock people down."
	icon_state = "club"
	item_state = "club"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_NORMAL

/obj/item/weapon/melee/classic_baton/whip
	name = "whip"
	desc = "A leather wip. To keep your slaves in order."
	icon = 'icons/obj/items.dmi'
	icon_state = "whip"
	item_state = "whip"
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_WEAK+3
	flammable = TRUE

/obj/item/weapon/melee/classic_baton/attack(mob/M as mob, mob/living/user as mob)

	switch (user.a_intent) // harm intent lets us murder people, others not so much - Kachnov
		if (I_HURT)
			force*=1.2
		if (I_HELP, I_GRAB, I_DISARM)
			force/=3

	var/user_last_intent = user.a_intent
	user.a_intent = I_HURT // so we actually hit people right

	..(M, user)

	M.Weaken(weakens) // decent

	user.a_intent = user_last_intent

	force = initial(force)


/obj/item/weapon/melee/classic_baton/big_club
	name = "big wood club"
	desc = "This looks huge!"
	icon_state = "big_club"
	item_state = "big_club"
	force = WEAPON_FORCE_PAINFUL
	weakens = 2

/obj/item/weapon/melee/classic_baton/big_club/attack(mob/M as mob, mob/living/user as mob)

	switch (user.a_intent) // harm intent lets us murder people, others not so much - Kachnov
		if (I_HURT)
			force*=2.5
		if (I_HELP, I_GRAB, I_DISARM)
			force/=1.5

	var/user_last_intent = user.a_intent
	user.a_intent = I_HURT // so we actually hit people right

	..(M, user)

	M.Weaken(weakens) // decent

	user.a_intent = user_last_intent

	force = initial(force)


////////////////GARROTE/////////////////////
/obj/item/garrote
	name = "garrote"
	desc = "A handheld ligature of rope, used to strangle a person."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "garrote"
	item_state = "zippo"
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_WEAK
	flammable = TRUE
	slot_flags = SLOT_BELT | SLOT_POCKET
	force = WEAPON_FORCE_WEAK
	w_class = 1.0
	throwforce = WEAPON_FORCE_WEAK
	throw_speed = 5
	throw_range = 8
	var/next_garrote = 0
	var/garroting = FALSE

/obj/item/garrote/Destroy()
	garroting = FALSE
	update_icon()
	return ..()

/obj/item/garrote/update_icon()
    icon_state = "garrote[garroting ? "_w" : ""]"

/obj/item/garrote/attack(mob/living/carbon/human/target as mob, mob/living/carbon/human/user as mob)
	if (garroting)
		stop_garroting(user)
		return
	else
		start_garroting(user,target)
		return
/obj/item/garrote/proc/start_garroting(mob/living/carbon/human/user,mob/living/carbon/human/target)
	playsound(target.loc, 'sound/weapons/grapple.ogg', 40, 1, -4)
	playsound(target.loc, 'sound/weapons/cablecuff.ogg', 15, 1, -5)
	garroting = TRUE
	update_icon()
	garroting_process(user,target)
	next_garrote = world.time + 10
	visible_message(
		"<span class='danger'>[user] has grabbed \the [target] with \the [src]!</span>",\
		"<span class='danger'>You grab \the [target] with \the [src]!</span>",\
		"You hear some struggling and muffled cries of surprise")

/obj/item/garrote/proc/stop_garroting(mob/living/carbon/human/user)
	garroting = FALSE
	update_icon()
/obj/item/garrote/attack_self(mob/living/carbon/human/user)
	if(garroting)
		user << "<span class='notice'>You release the garrote on your victim.</span>" //Not the grab, though. Only the garrote.
		garroting = FALSE
		update_icon()
		return
	if(world.time <= next_garrote) 	return

/obj/item/garrote/proc/garroting_process(mob/living/carbon/human/user,mob/living/carbon/human/target)
	if (!user)
		return FALSE
	if(ishuman(user))
		if(!(user.l_hand == src || user.r_hand == src)) //THE GARROTE IS NOT IN HANDS, ABORT
			garroting = FALSE
			user << "You loosen the garrote."
			update_icon()
			return FALSE

		if (garroting == FALSE)
			user << "You loosen the garrote."
			update_icon()
			return FALSE
		else
			spawn(25)
				garroting_process(user)

		if(istype(target))
			if(!target.mouth_covered)
				target.forcesay(list("-hrk!", "-hrgh!", "-urgh!", "-kh!", "-hrnk!"))

		if (garroting) //Only do oxyloss if in agreesive grab to prevent passive grab choking or something.
			target.adjustOxyLoss(3) //Stack the chokes with additional oxyloss for quicker death
			if(prob(40))
				target.stuttering = max(target.stuttering, 3) //It will hamper your voice, being choked and all.
				target.losebreath = max(target.losebreath, 3)
		return TRUE
	else
		garroting = FALSE
		update_icon()

		return FALSE