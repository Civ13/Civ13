//Melee Weapons, non edged or piercing (clubs, batons, maces)
/obj/item/weapon/melee
	edge = FALSE
	sharp = FALSE
	var/force_multiplier = 1.2
	var/force_divisor = 3
	var/weakens = 0
	var/weaken_chance = 40

/obj/item/weapon/melee/attack(mob/M as mob, mob/living/user as mob, var/target_zone)

	switch (user.a_intent) // harm intent lets us murder people, others not so much - Kachnov
		if (I_HARM)
			force *= force_multiplier
		if (I_HELP, I_GRAB, I_DISARM)
			force /= force_divisor

	var/user_last_intent = user.a_intent
	user.a_intent = I_HARM // so we actually hit people right

	..(M, user, target_zone)
	if (weakens && prob(weaken_chance))
		M.Weaken(weakens) // decent

	user.a_intent = user_last_intent

	force = initial(force)

/obj/item/weapon/melee/mace
	name = "iron mace"
	desc = "A iron mace, good for breaking bones and armor."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "mace"
	item_state = "mace"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_WEAK+2
	weakens = 1
	w_class = ITEM_SIZE_SMALL
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
	w_class = ITEM_SIZE_NORMAL
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
	w_class = ITEM_SIZE_NORMAL
	flammable = FALSE

/obj/item/weapon/melee/classic_baton
	name = "wood baton"
	desc = "A wooden truncheon for beating criminal scum."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "baton"
	item_state = "classic_baton"
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_WEAK+1
	weakens = 3
	flammable = TRUE
	flags = FALSE

/obj/item/weapon/melee/classic_baton/guard
	name = "heavy baton"
	desc = "A heavy wooden truncheon for beating criminal scum."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "baton"
	item_state = "classic_baton"
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_WEAK
	weakens = 5
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
	flags = FALSE

/obj/item/weapon/melee/nightbaton/sandman
    name = "Heavy duty"
    desc = "A baton held by the camp commander nicknamed the sandman by prisoners because of how hard it hits."
    icon = 'icons/obj/weapons.dmi'
    icon_state = "kombaton"
    item_state = "nightbaton"
    slot_flags = SLOT_BELT
    force = WEAPON_FORCE_WEAK+2
    weakens = 0
    flammable = TRUE
    var/cooldown = FALSE

/obj/item/weapon/melee/nightbaton/sandman/attack(mob/M as mob, mob/living/user as mob)
    if(!cooldown)
        M.SetWeakened(50)
        src.cooldown = TRUE
        spawn(100)
            src.cooldown = FALSE
    else
        user << "<span class='notice'>You have used this batton not long ago. Chill out!</span>"
    ..()

/obj/item/weapon/melee/classic_baton/club
	name = "wood club"
	desc = "One of the oldest weapons in the world. Good for when you need to knock people down."
	icon_state = "club"
	item_state = "club"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_WEAK
	flammable = TRUE
	weakens = 1
	weaken_chance = 20

/* 	//Commented out for the moment, as an attack proc has been made for all melee weapons
	//(see line 10)
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
*/

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

/obj/item/weapon/melee/knuckle_duster
	name = "knuckle duster"
	desc = "A peice of metal that fits around your hand. Could break some teeth."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "knuckle_duster"
	item_state = "knuckle_duster"
	slot_flags = SLOT_POCKET
	force = WEAPON_FORCE_PAINFUL
	flammable = FALSE
	weakens = FALSE

/obj/item/weapon/melee/baseball_bat
	name = "wooden baseball bat"
	desc = "A smooth wooden club used in the sport of baseball. Useful for damaging skulls."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "woodbat"
	item_state = "woodbat"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_PAINFUL
	w_class = ITEM_SIZE_NORMAL
	flammable = TRUE
	weakens = 1

/obj/item/weapon/melee/baseball_bat/aluminium
	name = "aluminium baseball bat"
	desc = "A smooth metal club used in the sport of baseball. This one's stronger than a wooden one."
	icon_state = "metalbat"
	item_state = "metalbat"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_PAINFUL+3
	flammable = FALSE
	flags = CONDUCT

/obj/item/weapon/melee/classic_baton/big_club
	name = "big wood club"
	desc = "This looks huge!"
	icon_state = "big_club"
	item_state = "big_club"
	force = WEAPON_FORCE_PAINFUL
	weakens = 3
	force_multiplier = 2.5
	force_divisor = 1.5

/* 	//Commented out for the moment, as an attack proc has been made for all melee weapons
	//(see line 10)
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
*/

/obj/item/weapon/macuahuitl
	name = "macuahuitl"
	desc = "A Mesoamerican wooden club with obsidian blades."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "macuahuitl"
	item_state = "macuahuitl"
	attack_verb = list("smacked", "hit", "bludgeoned")
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_ROBUST
	sharp = TRUE
	edge = TRUE
	sharpness = 15
	w_class = ITEM_SIZE_NORMAL
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
	w_class = ITEM_SIZE_TINY
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
			target.adjustOxyLoss(6) //Stack the chokes with additional oxyloss for quicker death
			if(prob(40))
				target.stuttering = max(target.stuttering, 3) //It will hamper your voice, being choked and all.
				target.losebreath = max(target.losebreath, 3)
		return TRUE
	else
		garroting = FALSE
		update_icon()

		return FALSE

/obj/item/weapon/melee/telebaton
	name = "telescopic baton"
	desc = "A compact yet rebalanced personal defense weapon. Can be concealed when folded."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "telebaton_0"
	item_state = "telebaton_0"
	slot_flags = SLOT_BELT
	var/on = 0
	flags = FALSE


/obj/item/weapon/melee/telebaton/attack_self(mob/user as mob)
	on = !on
	if(on)
		user.visible_message("<span class='warning'>With a flick of their wrist, [user] extends their telescopic baton.</span>",\
		"<span class='warning'>You extend the baton.</span>",\
		"You hear an ominous click.")
		force = 15//quite robust
		attack_verb = list("smacked", "struck", "slapped")
	else
		user.visible_message("<span class='notice'>\The [user] collapses their telescopic baton.</span>",\
		"<span class='notice'>You collapse the baton.</span>",\
		"You hear a click.")
		force = 3//not so robust now
		attack_verb = list("hit", "punched")

	playsound(src.loc, 'sound/weapons/empty.ogg', 50, 1)
	add_fingerprint(user)
	update_icon()
	update_held_icon()

/obj/item/weapon/melee/telebaton/update_icon()
	if(on)
		icon_state = "telebaton_1"
		item_state = "telebaton_1"
	else
		icon_state = "telebaton_0"
		item_state = "telebaton_0"
	if(length(blood_DNA))
		generate_blood_overlay(TRUE) // Force recheck.
		overlays.Cut()
		overlays += blood_overlay
