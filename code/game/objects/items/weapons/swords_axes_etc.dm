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
/obj/item/weapon/garrote
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
	processing_objects.Remove(src)
	return ..()

/obj/item/weapon/garrote/update_icon()
    icon_state = "garrote[garroting ? "_w" : ""]"

/obj/item/weapon/garrote/proc/start_garroting(mob/user)
	var/mob/living/M = user.pulling
	M.LAssailant = user
	playsound(M.loc, 'sound/weapons/grapple.ogg', 40, 1, -4)
	playsound(M.loc, 'sound/weapons/cablecuff.ogg', 15, 1, -5)
	garroting = TRUE
	update_icon()
	processing_objects.Add(src)
	next_garrote = world.time + 40
	visible_message(
		"<span class='danger'>[user] has grabbed \the [user.pulling] with \the [src]!</span>",\
		"<span class='danger'>You grab \the [user.pulling] with \the [src]!</span>",\
		"You hear some struggling and muffled cries of surprise")

/obj/item/weapon/garrote/proc/stop_garroting()
	garroting = FALSE
	processing_objects.Remove(src)
	update_icon()

/obj/item/weapon/garrote/attack_self(mob/user)
	if(garroting)
		user << "<span class='notice'>You release the garrote on your victim.</span>" //Not the grab, though. Only the garrote.
		garroting = FALSE
		processing_objects.Remove(src)
		update_icon()
		return
	if(world.time <= next_garrote) 	return

	if(ishuman(user))
		if(!user.pulling || !ishuman(user.pulling))
			user << "<span class='warning'>You must be grabbing someone to garrote them!</span>"
			return

		start_garroting(user)

/obj/item/weapon/garrote/afterattack(atom/A, mob/living/carbon/human/user as mob, proximity, click_parameters)
	var/obj/item/weapon/grab/G = null
	for (var/obj/item/weapon/grab/GR in user)
		G = GR
	if (!G)
		return
	if(!proximity) return
	if(ishuman(A))
		var/mob/living/carbon/human/C = A
		if(user != C)
			if(user.targeted_organ != "mouth" && user.targeted_organ != "eyes" && user.targeted_organ != "head")
				user << "<span class='notice'>You must target head for garroting to work!</span>"
				return
			if(!garroting)
				G.state = GRAB_PASSIVE
				//Autograb. The trick is to switch to grab intent and reinforce it for quick chokehold.
				// N E V E R  autograb into Aggressive. Passive autograb is good enough.
				C.grabbed_by += user
				start_garroting(user)
			else
				if(G.state == GRAB_KILL)
					return
				visible_message("<span class='danger'>[user] starts to tighten the garrote on [src]!</span>", \
				"<span class='userdanger'>[user] starts to tighten the garrote on you!</span>")
				if(!do_mob(user, C, 30))
					return 0
				playsound(C.loc, 'sound/weapons/grapple.ogg', 40, 1, -4)
				playsound(C.loc, 'sound/weapons/cablecuff.ogg', 15, 1, -5)
				G.state++
				switch(G.state)
					if(GRAB_AGGRESSIVE)
						visible_message("<span class='danger'>[user] has tightend the garrote around [src]!</span>", \
								"<span class='userdanger'>[user] has grabbed [src] aggressively!</span>")
					if(GRAB_NECK)
						visible_message("<span class='danger'>[C] looks like they're struggling to breath!</span>",\
								"<span class='userdanger'>You can't breath!</span>")
						C.Move(user.loc)
					if(GRAB_KILL)
						visible_message("<span class='danger'>[C] looks like they're fighting for their life!</span>", \
								"<span class='userdanger'>You feel like these might be your last few moments!</span>")
						C.Move(user.loc)
	return

/obj/item/weapon/garrote/process()
	var/obj/item/weapon/grab/G = null
	for (var/obj/item/weapon/grab/GR in loc)
		G = GR
	if (!G)
		return
	if(ishuman(loc))
		var/mob/living/carbon/human/C = loc
		if(!(C.l_hand == src || C.r_hand == src)) //THE GARROTE IS NOT IN HANDS, ABORT
			processing_objects.Remove(src)
			G.state = GRAB_PASSIVE
			return

		if(!C.pulling || !ishuman(C.pulling))
			processing_objects.Remove(src)
			G.state = GRAB_PASSIVE
			return

		var/mob/living/carbon/human/H = C.pulling
		if(istype(H))
			if(H.mouth_covered)
				return
			H.forcesay(list("-hrk!", "-hrgh!", "-urgh!", "-kh!", "-hrnk!"))

		var/mob/living/M = C.pulling
		if(G.state >= GRAB_NECK) //Only do oxyloss if in neck grab to prevent passive grab choking or something.
			if(G.state >= GRAB_KILL)
				M.adjustOxyLoss(3) //Stack the chokes with additional oxyloss for quicker death
			else
				if(prob(40))
					M.stuttering = max(M.stuttering, 3) //It will hamper your voice, being choked and all.
	else
		processing_objects.Remove(src)