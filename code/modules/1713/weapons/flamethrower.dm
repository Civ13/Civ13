/obj/item/weapon/flamethrower
	name = "M2 Flamethrower hoose"
	desc = "Use with a flamethrower fuel tank to set your enemies on fire."
	icon = 'icons/obj/gun.dmi'
	icon_state = "m2_flamethrower"
	item_state = "m2_flamethrower"
	var/base_icon = "m2_flamethrower"
	flags = CONDUCT
	sharp = FALSE
	edge = FALSE
	attack_verb = list("bashed", "hit")
	force = WEAPON_FORCE_WEAK+2
	throwforce = WEAPON_FORCE_WEAK
	flammable = FALSE
	w_class = 3
	slot_flags = SLOT_BELT
	var/active = FALSE

/obj/item/weapon/flamethrower/update_icon()
	if (active)
		icon_state = "[base_icon]_on"
	else
		icon_state = base_icon

/obj/item/weapon/flamethrower/attack_self(var/mob/living/L)
	if (active)
		active=FALSE
		update_icon()
		L << "<span class='danger'>You put off \the [src].</span>"
	else
		active=TRUE
		update_icon()
		L << "<span class='danger'>You light \the [src].</span>)"

/obj/item/weapon/flamethrower/proc/fire(var/mob/living/carbon/human/L,var/cdir)
	var/obj/item/weapon/reagent_containers/glass/flamethrower/FM = null
	if (!L.back || !istype(L.back,/obj/item/weapon/reagent_containers/glass/flamethrower))
		L << "<span class='warning'>You need a fuel tank on your back in order to be able to use a flamethrower!</span>"
		return
	if (istype(L.back,/obj/item/weapon/reagent_containers/glass/flamethrower))
		FM = L.back
	if (!FM)
		L << "<span class='warning'>You need a fuel tank on your back in order to be able to use a flamethrower!</span>"
		return
	if (FM.reagents && FM.reagents.get_reagent_amount("gasoline") >= 2)
		process_fire(L,FM,cdir)
		return
	else
		L << "<span class='warning'>The fuel tank doesn't have enough fuel to operate the flamethrower!</span>"
		return

/obj/item/weapon/flamethrower/proc/process_fire(var/mob/living/carbon/human/L,var/obj/item/weapon/reagent_containers/glass/flamethrower/FM,var/cdir)
	if (FM.reagents && FM.reagents.get_reagent_amount("gasoline") >= 2)
		FM.reagents.remove_reagent("gasoline",2)
		playsound(get_turf(loc), 'sound/weapons/flamethrower.ogg', 100, TRUE)
		var/list/targetturfs = list(null, null, null, null, null, null, null)
		switch(cdir)
			if(NORTH)
				targetturfs[1] = locate(x,y+1,z)
				targetturfs[2] = locate(x-1,y+2,z)
				targetturfs[3] = locate(x,y+2,z)
				targetturfs[4] = locate(x+1,y+2,z)
				targetturfs[5] = locate(x-1,y+3,z)
				targetturfs[6] = locate(x,y+3,z)
				targetturfs[7] = locate(x+1,y+3,z)
			if(SOUTH)
				targetturfs[1] = locate(x,y-1,z)
				targetturfs[2] = locate(x+1,y-2,z)
				targetturfs[3] = locate(x,y-2,z)
				targetturfs[4] = locate(x-1,y-2,z)
				targetturfs[5] = locate(x+1,y-3,z)
				targetturfs[6] = locate(x,y-3,z)
				targetturfs[7] = locate(x-1,y-3,z)
			if(EAST)
				targetturfs[1] = locate(x+1,y,z)
				targetturfs[2] = locate(x+2,y-1,z)
				targetturfs[3] = locate(x+2,y,z)
				targetturfs[4] = locate(x+2,y+1,z)
				targetturfs[5] = locate(x+3,y-1,z)
				targetturfs[6] = locate(x+3,y,z)
				targetturfs[7] = locate(x+3,y+1,z)
			if(WEST)
				targetturfs[1] = locate(x-1,y,z)
				targetturfs[2] = locate(x-2,y-1,z)
				targetturfs[3] = locate(x-2,y,z)
				targetturfs[4] = locate(x-2,y+1,z)
				targetturfs[5] = locate(x-3,y-1,z)
				targetturfs[6] = locate(x-3,y,z)
				targetturfs[7] = locate(x-3,y+1,z)
		for (var/i=1, i<=7, i++)
			if (targetturfs[i])
				new/obj/effect/fire(targetturfs[i])
				for (var/mob/living/HM in targetturfs[i])
					HM.adjustFireLoss(35)
					HM.fire_stacks += rand(4,5)
					HM.IgniteMob()

/obj/item/weapon/reagent_containers/glass/flamethrower
	name = "M2 Flamethrower backpack"
	desc = "A flamethrower backpack. Up to 100 liters of gasoline."
	icon = 'icons/obj/gun.dmi'
	icon_state = "m2_flamethrower_back"
	item_state = "m2_flamethrower"
	flags = CONDUCT
	sharp = FALSE
	edge = FALSE
	nothrow = TRUE
	attack_verb = list("bashed", "hit")
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	flammable = TRUE
	w_class = 10
	slot_flags = SLOT_BACK
	throw_speed = 1
	throw_range = 1
	amount_per_transfer_from_this = 25
	volume = 100
	density = TRUE

/obj/item/weapon/reagent_containers/glass/flamethrower/filled/New()
	..()
	reagents.add_reagent("gasoline",100)

/obj/item/weapon/flamethrower/flammenwerfer
	name = "Flammenwerfer hoose"
	icon_state = "flammenwerfer"
	item_state = "flammenwerfer"
	base_icon = "flammenwerfer"

/obj/item/weapon/flamethrower/flammenwerfer/filled/New()
	..()
	reagents.add_reagent("gasoline",100)

/obj/item/weapon/reagent_containers/glass/flamethrower/flammenwerfer
	name = "Flammenwerfer backpack"
	icon_state = "flammenwerfer_back"
	item_state = "flammenwerfer"