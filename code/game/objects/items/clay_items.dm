//for unfired clay stuff, i.e. unusable
/obj/item/weapon/clay
	name = "unfired clay"
	desc = "unfired clay. Put it in the fire to dry it"
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "claylump"
	item_state = "claylump"
	throwforce = WEAPON_FORCE_WEAK
	force = WEAPON_FORCE_WEAK
	w_class = 2
	throw_speed = 3
	throw_range = 5
	var/result = "none"
	value = 1

/obj/item/weapon/clay/roofing
	name = "unfired clay roof tiles"
	icon_state = "unfired_clayroofing"
	result = "/obj/item/weapon/roofbuilder/clay"
/obj/item/weapon/clay/vase
	name = "unfired clay vase"
	icon_state = "unfired_clayvase"
	result = /obj/item/weapon/reagent_containers/food/drinks/clay/clayvase

/obj/item/weapon/clay/winecup
	name = "unfired clay wine cup"
	icon_state = "unfired_winecup"
	result = /obj/item/weapon/reagent_containers/food/drinks/clay/claywinecup

/obj/item/weapon/clay/claypot
	name = "unfired medium clay pot"
	icon_state = "unfired_claypot1"
	result = /obj/item/weapon/reagent_containers/food/drinks/clay/claypot
	New()
		..()
		icon_state = "unfired_claypot[pick(1,2,3)]"
/obj/item/weapon/clay/claybricks
	name = "unfired clay blocks"
	icon_state = "unfired_claybricks"
	result = /obj/item/weapon/clay/claybricks/fired

/obj/item/weapon/clay/advclaybricks
	name = "unfired bricks"
	icon_state = "unfired_advclaybricks"
	result = /obj/item/weapon/clay/advclaybricks/fired

/obj/item/weapon/clay/advclaybricks/cement
	name = "unfired cement bricks"
	icon_state = "unfired_cementbricks"
	result = /obj/item/weapon/clay/advclaybricks/fired/cement

/obj/item/weapon/clay/claybowl
	name = "unfired clay bowl"
	icon_state = "unfired_claybowl"
	result = /obj/item/weapon/reagent_containers/food/drinks/clay/claybowl

/obj/item/weapon/clay/clayjug
	name = "unfired clay jug"
	icon_state = "unfired_clayjug"
	result = /obj/item/weapon/reagent_containers/food/drinks/clay/clayjug
	New()
		..()
		icon_state = "unfired_clayjug[pick(1,2)]"
/obj/item/weapon/clay/claycup
	name = "unfired clay cup"
	icon_state = "unfired_claycup"
	result = /obj/item/weapon/reagent_containers/food/drinks/clay/claycup

/obj/item/weapon/clay/smallclaypot
	name = "unfired small clay pot"
	icon_state = "unfired_smallclaypot"
	result = /obj/item/weapon/reagent_containers/food/drinks/clay/smallclaypot
	New()
		..()
		icon_state = "unfired_smallclaypot[pick(1,2)]"
/obj/item/weapon/clay/bigclaypot
	name = "unfired big clay pot"
	icon_state = "unfired_bigclaypot"
	result = /obj/item/weapon/reagent_containers/food/drinks/clay/bigclaypot
	New()
		..()
		icon_state = "unfired_bigclaypot[pick(1,2,3)]"
/obj/item/weapon/clay/verysmallclaypot
	name = "unfired very small clay pot"
	icon_state = "unfired_verysmallclaypot"
	result = /obj/item/weapon/reagent_containers/food/drinks/clay/verysmallclaypot

/obj/item/weapon/clay/claypitcher
	name = "unfired clay picher"
	icon_state = "unfired_claypitcher"
	result = /obj/item/weapon/reagent_containers/food/drinks/clay/claypitcher

/obj/item/weapon/clay/largeclaypitcher
	name = "unfired large clay pitcher"
	icon_state = "unfired_largeclaypitcher"
	result = /obj/item/weapon/reagent_containers/food/drinks/clay/largeclaypitcher

/obj/item/weapon/clay/claybricks/fired
	name = "clay blocks"
	icon_state = "claybricks"
	desc = "clay blocks. Can be used to make clay walls."
	throwforce = WEAPON_FORCE_WEAK+2
	force = WEAPON_FORCE_WEAK+4

/obj/item/weapon/clay/advclaybricks/fired
	name = "bricks"
	icon_state = "advclaybricks"
	desc = "modern bricks. Can be used to make brick walls."
	throwforce = WEAPON_FORCE_WEAK+3
	force = WEAPON_FORCE_WEAK+5

/obj/item/weapon/clay/advclaybricks/fired/cement
	name = "cement bricks"
	icon_state = "cementbricks"
	desc = "modern bricks. Can be used to make cement walls."
	throwforce = WEAPON_FORCE_WEAK+4
	force = WEAPON_FORCE_WEAK+6


/obj/item/weapon/clay/claybricks/fired/attack_self(mob/user)
	user << "You start building the clay wall..."
	if (do_after(user, 25, src))
		user << "You finish the placement of the clay block wall foundation."
		new /obj/covers/clay_wall/incomplete(user.loc)
		qdel(src)
		return

/obj/item/weapon/clay/advclaybricks/fired/attack_self(mob/user)
	user << "You start building the brick wall..."
	if (do_after(user, 25, src))
		user << "You finish the placement of the brick wall foundation."
		new /obj/covers/brick_wall/incomplete(user.loc)
		qdel(src)
		return

/obj/item/weapon/clay/advclaybricks/fired/cement/attack_self(mob/user)
	user << "You start building the cement wall..."
	if (do_after(user, 25, src))
		user << "You finish the placement of the cement wall foundation."
		new /obj/covers/cement_wall/incomplete(user.loc)
		qdel(src)
		return

//pots
/obj/item/weapon/reagent_containers/food/drinks/clay
	name = "clay pot"
	desc = "A clay pot."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "claypot1"
	amount_per_transfer_from_this = 10
	volume = 100
	center_of_mass = list("x"=17, "y"=10)
	w_class = 2.0


/obj/item/weapon/reagent_containers/food/drinks/clay/Bump(atom/A)
	if (isliving(A) || isturf(A) || (isobj(A) && A.density))
		shatter()

/obj/item/weapon/reagent_containers/food/drinks/clay/throw_impact(atom/hit_atom, var/speed)

	..()
	if (reagents)
		hit_atom.visible_message("<span class='notice'>The contents of \the [src] splash all over [hit_atom]!</span>")
		reagents.splash(hit_atom, reagents.total_volume)
	shatter(loc, hit_atom)

/obj/item/weapon/reagent_containers/food/drinks/clay/apply_hit_effect(mob/living/target, mob/living/user, var/hit_zone)
	var/blocked = ..()

	if (user.a_intent != I_HURT)
		return


	// You are going to knock someone out for longer if they are not wearing a helmet.
	var/weaken_duration = FALSE
	if (blocked < 2)
		weaken_duration = 5 + min(0, force - target.getarmor(hit_zone, "melee") + 10)

	var/mob/living/carbon/human/H = target
	if (istype(H) && H.headcheck(hit_zone))
		var/obj/item/organ/affecting = H.get_organ(hit_zone) //headcheck should ensure that affecting is not null
		user.visible_message("<span class='danger'>[user] shatters [src] into [H]'s [affecting.name]!</span>")
		if (weaken_duration)
			target.apply_effect(min(weaken_duration, 5), WEAKEN, blocked) // Never weaken more than a flash!
	else
		user.visible_message("<span class='danger'>\The [user] shatters [src] into [target]!</span>")

	if (reagents)
		spawn (1) // wait until after our explosion, if we have one
			user.visible_message("<span class='notice'>The contents of \the [src] splash all over [target]!</span>")
			if (reagents) reagents.splash(target, reagents.total_volume)

	//Finally, shatter the bottle. This kills (qdel) the bottle.

	var/obj/item/weapon/clayshards/B = shatter(target.loc, target)
	user.put_in_active_hand(B)

/obj/item/weapon/reagent_containers/food/drinks/clay/proc/shatter(var/newloc, atom/against = null)

	if (!newloc)
		newloc = get_turf(src)


	if (src)
		if (ismob(loc))
			var/mob/M = loc
			M.drop_from_inventory(src)

		//Creates a shattering noise and replaces the bottle with a broken_bottle
		var/obj/item/weapon/clayshards/B = new/obj/item/weapon/clayshards(newloc) // Create a glass shard at the target's location!

		playsound(src,'sound/effects/drop_glass.ogg',100,1)
		transfer_fingerprints_to(B)

		qdel(src)
		return B

/obj/item/weapon/reagent_containers/food/drinks/clay/verysmallclaypot
	name = "very small clay pot"
	desc = "A very small clay pot."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "verysmallclaypot"
	amount_per_transfer_from_this = 2
	volume = 25
	w_class = 1.0

/obj/item/weapon/reagent_containers/food/drinks/clay/smallclaypot
	name = "small clay pot"
	desc = "small clay pot."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "smallclaypot"
	amount_per_transfer_from_this = 5
	volume = 55
	w_class = 1.0
	New()
		..()
		icon_state = "smallclaypot[pick(1,2)]"

/obj/item/weapon/reagent_containers/food/drinks/clay/claypot
	name = "medium clay pot"
	desc = "medium clay pot."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "claypot1"
	amount_per_transfer_from_this = 10
	volume = 90
	w_class = 2.0
	New()
		..()
		icon_state = "claypot[pick(1,2,3)]"


/obj/item/weapon/reagent_containers/food/drinks/clay/bigclaypot
	name = "big clay pot"
	desc = "big clay pot."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "bigclaypot1"
	amount_per_transfer_from_this = 10
	volume = 130
	w_class = 2.0
	New()
		..()
		icon_state = "bigclaypot[pick(1,2)]"

/obj/item/weapon/reagent_containers/food/drinks/clay/clayjug
	name = "clay jug"
	desc = "clay jug."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "clayjug1"
	amount_per_transfer_from_this = 10
	volume = 100
	w_class = 2.0
	New()
		..()
		icon_state = "clayjug[pick(1,2)]"

/obj/item/weapon/reagent_containers/food/drinks/clay/claybowl
	name = "clay bowl"
	desc = "clay bowl."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "claybowl"
	amount_per_transfer_from_this = 10
	volume = 55
	w_class = 1.0

/obj/item/weapon/reagent_containers/food/drinks/clay/claycup
	name = "clay cup"
	desc = "clay cup."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "claycup"
	amount_per_transfer_from_this = 10
	volume = 40
	w_class = 1.0

/obj/item/weapon/reagent_containers/food/drinks/clay/claywinecup
	name = "clay wine cup"
	desc = "clay wine cup."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "claywinecup"
	amount_per_transfer_from_this = 5
	volume = 30
	w_class = 1.0

/obj/item/weapon/reagent_containers/food/drinks/clay/clayvase
	name = "clay vase"
	desc = "clay vase."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "clayvase"
	amount_per_transfer_from_this = 15
	volume = 130
	w_class = 2.0

/obj/item/weapon/reagent_containers/food/drinks/clay/claypitcher
	name = "clay pitcher"
	desc = "clay pitcher."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "claypitcher"
	amount_per_transfer_from_this = 15
	volume = 80
	w_class = 2.0

/obj/item/weapon/reagent_containers/food/drinks/clay/largeclaypitcher
	name = "large clay pitcher"
	desc = "large clay pitcher."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "largeclaypitcher"
	amount_per_transfer_from_this = 20
	volume = 130
	w_class = 2.0


/obj/item/weapon/clayshards
	name = "clay shards"
	desc = "clay shards from broken clay pottery."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "clayshards"
	item_state = "clayshards"
	throwforce = WEAPON_FORCE_WEAK+1
	force = WEAPON_FORCE_WEAK+4
	w_class = 1
	throw_speed = 5
	throw_range = 8
