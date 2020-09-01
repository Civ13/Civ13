/obj/item/weapon/flamethrower
	name = "M2 Flamethrower hoose"
	desc = "Use with a flamethrower fuel tank to set your enemies on fire."
	icon = 'icons/obj/guns/gun.dmi'
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
	var/lastfire = 0
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
		L << "<span class='danger'>You light \the [src].</span>"

/obj/item/weapon/flamethrower/proc/fire(var/mob/living/human/L,var/cdir=null)
	if (!active || !L)
		return
	if (world.time<=lastfire)
		return
	if (!cdir)
		cdir = L.dir
	var/obj/item/weapon/reagent_containers/glass/flamethrower/FM = null
	if (!L.back || !istype(L.back,/obj/item/weapon/reagent_containers/glass/flamethrower))
		L << "<span class='warning'>You need a fuel tank on your back in order to be able to use a flamethrower!</span>"
		return
	if (istype(L.back,/obj/item/weapon/reagent_containers/glass/flamethrower))
		FM = L.back
	if (!FM)
		L << "<span class='warning'>You need a fuel tank on your back in order to be able to use a flamethrower!</span>"
		return
	if (FM.reagents && FM.reagents.get_reagent_amount("gasoline") >= 5)
		process_fire(L,FM,cdir)
		return
	else
		L << "<span class='warning'>The fuel tank doesn't have enough fuel to operate the flamethrower!</span>"
		return

/obj/item/weapon/flamethrower/proc/process_fire(var/mob/living/human/L,var/obj/item/weapon/reagent_containers/glass/flamethrower/FM,var/cdir = null)
	if (!cdir || !(cdir in list(NORTH,SOUTH,EAST,WEST)))
		cdir = L.dir
	if (FM.reagents && FM.reagents.get_reagent_amount("gasoline") >= 5)
		FM.reagents.remove_reagent("gasoline",5)
		lastfire = world.time+30
		playsound(get_turf(loc), 'sound/weapons/flamethrower.ogg', 100, TRUE)
		var/turf/t1 = null
		var/turf/t2 = null
		var/turf/t3 = null
		var/turf/t4 = null
		var/turf/t5 = null
		var/turf/t6 = null
		var/turf/t7 = null
		var/turf/t8 = null
		var/turf/t9 = null
		var/turf/t10 = null
		switch(cdir)
			if(NORTH)
				t1 = get_turf(locate(L.x,L.y+1,L.z))
				t2 = get_turf(locate(L.x-1,L.y+2,L.z))
				t3 = get_turf(locate(L.x,L.y+2,L.z))
				t4 = get_turf(locate(L.x+1,L.y+2,L.z))
				t5 = get_turf(locate(L.x-1,L.y+3,L.z))
				t6 = get_turf(locate(L.x,L.y+3,L.z))
				t7 = get_turf(locate(L.x+1,L.y+3,L.z))
				t8 = get_turf(locate(L.x-1,L.y+4,L.z))
				t9 = get_turf(locate(L.x,L.y+4,L.z))
				t10 = get_turf(locate(L.x+1,L.y+4,L.z))
			if(SOUTH)
				t1 = get_turf(locate(L.x,L.y-1,L.z))
				t2 = get_turf(locate(L.x+1,L.y-2,L.z))
				t3 = get_turf(locate(L.x,L.y-2,L.z))
				t4 = get_turf(locate(L.x-1,L.y-2,L.z))
				t5 = get_turf(locate(L.x+1,L.y-3,L.z))
				t6 = get_turf(locate(L.x,L.y-3,L.z))
				t7 = get_turf(locate(L.x-1,L.y-3,L.z))
				t8 = get_turf(locate(L.x-1,L.y-4,L.z))
				t9 = get_turf(locate(L.x,L.y-4,L.z))
				t10 = get_turf(locate(L.x+1,L.y-4,L.z))
			if(EAST)
				t1 = get_turf(locate(L.x+1,L.y,L.z))
				t2 = get_turf(locate(L.x+2,L.y-1,L.z))
				t3 = get_turf(locate(L.x+2,L.y,L.z))
				t4 = get_turf(locate(L.x+2,L.y+1,L.z))
				t5 = get_turf(locate(L.x+3,L.y-1,L.z))
				t6 = get_turf(locate(L.x+3,L.y,L.z))
				t7 = get_turf(locate(L.x+3,L.y+1,L.z))
				t5 = get_turf(locate(L.x+4,L.y-1,L.z))
				t6 = get_turf(locate(L.x+4,L.y,L.z))
				t7 = get_turf(locate(L.x+4,L.y+1,L.z))
			if(WEST)
				t1 = get_turf(locate(L.x-1,L.y,L.z))
				t2 = get_turf(locate(L.x-2,L.y-1,L.z))
				t3 = get_turf(locate(L.x-2,L.y,L.z))
				t4 = get_turf(locate(L.x-2,L.y+1,L.z))
				t5 = get_turf(locate(L.x-3,L.y-1,L.z))
				t6 = get_turf(locate(L.x-3,L.y,L.z))
				t7 = get_turf(locate(L.x-3,L.y+1,L.z))
				t5 = get_turf(locate(L.x-4,L.y-1,L.z))
				t6 = get_turf(locate(L.x-4,L.y,L.z))
				t7 = get_turf(locate(L.x-4,L.y+1,L.z))
		if (t1)
			new/obj/effect/fire(t1)
			for (var/mob/living/HM in t1)
				HM.adjustFireLoss(35)
				HM.fire_stacks += rand(4,5)
				HM.IgniteMob()
		if (t2)
			new/obj/effect/fire(t2)
			for (var/mob/living/HM in t2)
				HM.adjustFireLoss(35)
				HM.fire_stacks += rand(4,5)
				HM.IgniteMob()
		if (t3)
			new/obj/effect/fire(t3)
			for (var/mob/living/HM in t3)
				HM.adjustFireLoss(35)
				HM.fire_stacks += rand(4,5)
				HM.IgniteMob()
		if (t4)
			new/obj/effect/fire(t4)
			for (var/mob/living/HM in t4)
				HM.adjustFireLoss(35)
				HM.fire_stacks += rand(4,5)
				HM.IgniteMob()
		if (t5)
			new/obj/effect/fire(t5)
			for (var/mob/living/HM in t5)
				HM.adjustFireLoss(35)
				HM.fire_stacks += rand(4,5)
				HM.IgniteMob()
		if (t6)
			new/obj/effect/fire(t6)
			for (var/mob/living/HM in t6)
				HM.adjustFireLoss(35)
				HM.fire_stacks += rand(4,5)
				HM.IgniteMob()
		if (t7)
			new/obj/effect/fire(t7)
			for (var/mob/living/HM in t7)
				HM.adjustFireLoss(35)
				HM.fire_stacks += rand(4,5)
				HM.IgniteMob()
		if (t8)
			new/obj/effect/fire(t8)
			for (var/mob/living/HM in t8)
				HM.adjustFireLoss(35)
				HM.fire_stacks += rand(4,5)
				HM.IgniteMob()
		if (t9)
			new/obj/effect/fire(t9)
			for (var/mob/living/HM in t9)
				HM.adjustFireLoss(35)
				HM.fire_stacks += rand(4,5)
				HM.IgniteMob()
		if (t10)
			new/obj/effect/fire(t10)
			for (var/mob/living/HM in t10)
				HM.adjustFireLoss(35)
				HM.fire_stacks += rand(4,5)
				HM.IgniteMob()
/obj/item/weapon/reagent_containers/glass/flamethrower
	name = "M2 Flamethrower backpack"
	desc = "A flamethrower backpack. Up to 100 liters of gasoline."
	icon = 'icons/obj/guns/gun.dmi'
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

/obj/item/weapon/reagent_containers/glass/flamethrower/flammenwerfer/filled/New()
	..()
	reagents.add_reagent("gasoline",100)

/obj/item/weapon/reagent_containers/glass/flamethrower/flammenwerfer
	name = "Flammenwerfer backpack"
	icon_state = "flammenwerfer_back"
	item_state = "flammenwerfer"

/obj/item/weapon/flamethrower/type100
	name = "Type100 Flamethrower hose"
	icon_state = "type100_flamethrower"
	item_state = "type100_flamethrower"
	base_icon = "type100_flamethrower"

/obj/item/weapon/reagent_containers/glass/flamethrower/type100/filled/New()
	..()
	reagents.add_reagent("gasoline",100)

/obj/item/weapon/reagent_containers/glass/flamethrower/type100
	name = "Type100 Flamethrower Canister"
	icon_state = "type100_flamethrower_back"
	item_state = "type100_flamethrower"