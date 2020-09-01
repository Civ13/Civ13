//Melee Weapons, non edged or piercing (clubs, batons, maces)
/obj/item/weapon/melee
	edge = FALSE
	sharp = FALSE
	var/weakens = 0

/obj/item/weapon/melee/mace
	name = "iron mace"
	desc = "A iron mace, good for breaking bones and armor."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "mace"
	item_state = "mace"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_WEAK+2
	weakens = 1
	w_class = 2.0
	flammable = FALSE

/obj/item/weapon/melee/mace/kanabo
	name = "iron kanabo"
	desc = "A iron kanabo, this large blunt weapon of japanese origin pulps its victims under its weight & form."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "kanabo"
	item_state = "kanabo"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_WEAK+3
	weakens = 1
	w_class = 3.0
	flammable = FALSE

/obj/item/weapon/melee/mace/mauler
	name = "heavy mauler"
	desc = "A intimidatingly large morningstar, could easily pulverize any person; let alone one head to toe in armor."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "maul"
	item_state = "mauler1"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_NORMAL
	weakens = 1
	w_class = 3.0
	flammable = FALSE

/obj/item/weapon/melee/classic_baton
	name = "police baton"
	desc = "A wooden truncheon for beating criminal scum."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "baton"
	item_state = "classic_baton"
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_WEAK+1
	weakens = 3
	flammable = TRUE

/obj/item/weapon/melee/nightbaton
	name = "police baton"
	desc = "A stick used by police officers."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "nightbaton"
	item_state = "nightbaton"
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_WEAK+2
	weakens = 6
	flammable = TRUE

/obj/item/weapon/melee/classic_baton/club
	name = "wood club"
	desc = "One of the oldest weapons in the world. Good for when you need to knock people down."
	icon_state = "club"
	item_state = "club"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_WEAK
	flammable = TRUE
	weakens = FALSE

/obj/item/weapon/melee/classic_baton/whip
	name = "whip"
	desc = "A leather whip. To keep your slaves in order."
	icon = 'icons/obj/items.dmi'
	hitsound = 'sound/weapons/whipcrack.ogg'
	icon_state = "whip"
	item_state = "whip"
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_WEAK+1
	flammable = TRUE

/obj/item/weapon/melee/attack(mob/M as mob, mob/living/user as mob)

	switch (user.a_intent) // harm intent lets us murder people, others not so much - Kachnov
		if (I_HARM)
			force*=1.2
		if (I_HELP, I_GRAB, I_DISARM)
			force/=3

	var/user_last_intent = user.a_intent
	user.a_intent = I_HARM // so we actually hit people right

	..(M, user)
	if (weakens && prob(40))
		M.Weaken(weakens) // decent

	user.a_intent = user_last_intent

	force = initial(force)

/obj/item/weapon/melee/classic_baton/club/attack(mob/M as mob, mob/living/user as mob)

	switch (user.a_intent)
		if (I_HARM)
			force*=1.2
		if (I_HELP, I_GRAB, I_DISARM)
			force/=3

	var/user_last_intent = user.a_intent
	user.a_intent = I_HARM

	..(M, user)
	if (weakens && prob(20))
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
		if (I_HARM)
			force*=2.5
		if (I_HELP, I_GRAB, I_DISARM)
			force/=1.5

	var/user_last_intent = user.a_intent
	user.a_intent = I_HARM // so we actually hit people right

	..(M, user)

	if (weakens && prob(40))
		M.Weaken(weakens) // decent

	user.a_intent = user_last_intent

	force = initial(force)

/obj/item/weapon/macuahuitl
	name = "macuahuitl"
	desc = "A Mesoamerican wooden club with obsidian blades."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "macuahuitl"
	item_state = "macuahuitl"
	attack_verb = list("smacked", "hit", "bludgeoned")
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_ROBUST
	sharp = 1
	edge = 1
	sharpness = 15
	w_class = 3.0
	flammable = FALSE

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

/obj/item/garrote/attack(mob/living/human/target as mob, mob/living/human/user as mob)
	if (garroting)
		stop_garroting(user,target)
		return
	else
		start_garroting(user,target)
		return
/obj/item/garrote/proc/start_garroting(mob/living/human/user,mob/living/human/target)
	if (!user.has_empty_hand())
		user << "<span class='notice'>You need a free hand to use the garrote!</span>"
		return
	var/obj/item/weapon/grab/GR = new /obj/item/weapon/grab(user, target)
	user.put_in_hands(GR)
	GR.synch()
	target.LAssailant = user
	if (GR != null)
		playsound(target.loc, 'sound/weapons/grapple.ogg', 40, 1, -4)
		playsound(target.loc, 'sound/weapons/cablecuff.ogg', 15, 1, -5)
		garroting = TRUE
		update_icon()
		garroting_process(user,target,GR)
		next_garrote = world.time + 40
		visible_message(
			"<span class='danger'>[user] has grabbed \the [target] with \the [src]!</span>",\
			"<span class='danger'>You grab \the [target] with \the [src]!</span>",\
			"You hear some struggling and muffled cries of surprise")
		return
/obj/item/garrote/proc/stop_garroting(mob/living/human/user,mob/living/human/target)
	garroting = FALSE
	user << "<span class='notice'>You release the garrote on your victim.</span>" //Not the grab, though. Only the garrote.
	update_icon()
	return
/obj/item/garrote/attack_self(mob/living/human/user)
	if(world.time <= next_garrote) 	return
	if(garroting)
		stop_garroting(user)
		return

/obj/item/garrote/proc/garroting_process(mob/living/human/user,mob/living/human/target,obj/item/weapon/grab/GB)
	if (!ishuman(user) || !ishuman(target) || !GB)
		return FALSE
	if(ishuman(user))
		if(!(user.l_hand == src || user.r_hand == src)) //THE GARROTE IS NOT IN HANDS, ABORT
			stop_garroting(user,target)
			return FALSE

		if(!(user.l_hand == GB || user.r_hand == GB)) //THE GRAB IS NOT IN HANDS, ABORT
			stop_garroting(user,target)
			return FALSE

		if (garroting == FALSE)
			stop_garroting(user,target)
			return FALSE

		spawn(25)
			garroting_process(user,target,GB)

		if(istype(target))
			target.canmove = FALSE
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
