/mob/ClickOn(var/atom/A, var/params)
	if (ishuman(src)) //src is user who is click and human
		var/mob/living/human/H = src
		if (istype(H.get_active_hand(), /obj/item/weapon/flamethrower)) //TO DO TODO: move it to flamethrower.dm
			var/obj/item/weapon/flamethrower/FL = H.get_active_hand()
			var/cdir = get_dir(H,A)
			FL.fire(H,cdir)

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
	var/max_range = 4
/obj/item/weapon/flamethrower/update_icon()
	if (active)
		icon_state = "[base_icon]_on"
	else
		icon_state = base_icon

/obj/item/weapon/flamethrower/attack_self(var/mob/living/H)
	if (active)
		active=FALSE
		update_icon()
		H << "<span class='danger'>You extinguish \the [src].</span>"
	else
		active=TRUE
		update_icon()
		H << "<span class='danger'>You light \the [src].</span>"

/obj/item/weapon/flamethrower/proc/fire(var/mob/living/human/H,var/cdir=null)
	if (!active || !H)
		return
	if (world.time<=lastfire)
		return
	if (!cdir)
		cdir = H.dir
	var/obj/item/weapon/reagent_containers/glass/flamethrower/FM = null
	if (!H.back || !istype(H.back,/obj/item/weapon/reagent_containers/glass/flamethrower))
		H << "<span class='warning'>You need a fuel tank on your back in order to be able to use a flamethrower!</span>"
		return
	if (istype(H.back,/obj/item/weapon/reagent_containers/glass/flamethrower))
		FM = H.back
	if (!FM)
		H << "<span class='warning'>You need a fuel tank on your back in order to be able to use a flamethrower!</span>"
		return
	if (FM.reagents && FM.reagents.get_reagent_amount("gasoline") < 5)
		H << "<span class='warning'>The fuel tank doesn't have enough fuel to operate the flamethrower!</span>"
		return
	else
		process_fire(H,FM,cdir)
		return

/obj/item/weapon/flamethrower/proc/process_fire(var/mob/living/human/H,var/obj/item/weapon/reagent_containers/glass/flamethrower/FM,var/cdir = null,atom/target)
	if (!cdir || !(cdir in list(NORTH,SOUTH,EAST,WEST)))
		cdir = H.dir
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
				t1 = get_turf(locate(H.x,H.y+1,H.z))
				t2 = get_turf(locate(H.x-1,H.y+2,H.z))
				t3 = get_turf(locate(H.x,H.y+2,H.z))
				t4 = get_turf(locate(H.x+1,H.y+2,H.z))
				t5 = get_turf(locate(H.x-1,H.y+3,H.z))
				t6 = get_turf(locate(H.x,H.y+3,H.z))
				t7 = get_turf(locate(H.x+1,H.y+3,H.z))
				t8 = get_turf(locate(H.x-1,H.y+4,H.z))
				t9 = get_turf(locate(H.x,H.y+4,H.z))
				t10 = get_turf(locate(H.x+1,H.y+4,H.z))
			if(SOUTH)
				t1 = get_turf(locate(H.x,H.y-1,H.z))
				t2 = get_turf(locate(H.x+1,H.y-2,H.z))
				t3 = get_turf(locate(H.x,H.y-2,H.z))
				t4 = get_turf(locate(H.x-1,H.y-2,H.z))
				t5 = get_turf(locate(H.x+1,H.y-3,H.z))
				t6 = get_turf(locate(H.x,H.y-3,H.z))
				t7 = get_turf(locate(H.x-1,H.y-3,H.z))
				t8 = get_turf(locate(H.x-1,H.y-4,H.z))
				t9 = get_turf(locate(H.x,H.y-4,H.z))
				t10 = get_turf(locate(H.x+1,H.y-4,H.z))
			if(EAST)
				t1 = get_turf(locate(H.x+1,H.y,H.z))
				t2 = get_turf(locate(H.x+2,H.y-1,H.z))
				t3 = get_turf(locate(H.x+2,H.y,H.z))
				t4 = get_turf(locate(H.x+2,H.y+1,H.z))
				t5 = get_turf(locate(H.x+3,H.y-1,H.z))
				t6 = get_turf(locate(H.x+3,H.y,H.z))
				t7 = get_turf(locate(H.x+3,H.y+1,H.z))
				t5 = get_turf(locate(H.x+4,H.y-1,H.z))
				t6 = get_turf(locate(H.x+4,H.y,H.z))
				t7 = get_turf(locate(H.x+4,H.y+1,H.z))
			if(WEST)
				t1 = get_turf(locate(H.x-1,H.y,H.z))
				t2 = get_turf(locate(H.x-2,H.y-1,H.z))
				t3 = get_turf(locate(H.x-2,H.y,H.z))
				t4 = get_turf(locate(H.x-2,H.y+1,H.z))
				t5 = get_turf(locate(H.x-3,H.y-1,H.z))
				t6 = get_turf(locate(H.x-3,H.y,H.z))
				t7 = get_turf(locate(H.x-3,H.y+1,H.z))
				t5 = get_turf(locate(H.x-4,H.y-1,H.z))
				t6 = get_turf(locate(H.x-4,H.y,H.z))
				t7 = get_turf(locate(H.x-4,H.y+1,H.z))
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
	flags = CONDUCT
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

/obj/item/weapon/reagent_containers/glass/flamethrower/flammenwerfer
	name = "Flammenwerfer backpack"
	icon_state = "flammenwerfer_back"
	item_state = "flammenwerfer"

/obj/item/weapon/reagent_containers/glass/flamethrower/flammenwerfer/filled/New()
	..()
	reagents.add_reagent("gasoline",100)

/obj/item/weapon/flamethrower/type100
	name = "Type100 Flamethrower hose"
	icon_state = "type100_flamethrower"
	item_state = "type100_flamethrower"
	base_icon = "type100_flamethrower"

/obj/item/weapon/reagent_containers/glass/flamethrower/type100
	name = "Type100 Flamethrower Canister"
	icon_state = "type100_flamethrower_back"
	item_state = "type100_flamethrower"

/obj/item/weapon/reagent_containers/glass/flamethrower/type100/filled/New()
	..()
	reagents.add_reagent("gasoline",100)


/*
var/turf/current_loc = get_turf(H)
	var/turf/current_loc = get_turf(H)
	var/turf/target_loc = get_turf(target)
	if (!cdir || !(cdir in list(NORTH,SOUTH,EAST,WEST)))
		cdir = H.dir
	if (FM.reagents && FM.reagents.get_reagent_amount("gasoline") >= 5)
		FM.reagents.remove_reagent("gasoline",5)
		lastfire = world.time+30
		playsound(get_turf(loc), 'sound/weapons/flamethrower.ogg', 100, TRUE)
		var/turf/t1
		var/turf/t2
		var/turf/t3
		var/turf/t4
		var/turf/t5
		var/turf/t6
		var/turf/t7
		var/turf/t8
		var/turf/t9
		var/turf/t10
		switch (cdir)
			if (NORTH)
				var/turf = 1
				if ((target_loc.y - current_loc.y) > max_range)
					for (var/i = current_loc.y + 1, i <= (current_loc.y + max_range), i++)
						t[turf] = get_turf(locate(H.x, H.[i], H.z))
						turf++
				else
					for (var/i = current_loc.y + 1, i <= target_loc.y, i++)
						t[turf] = get_turf(locate(H.x, H.[i], H.z))
						turf++
			if (SOUTH)
				var/turf = 1
				if ((current_loc.y - target_loc.y) > max_range)
					for (var/i = current_loc.y - 1, i <= (current_loc.y - max_range), i--)
						t[turf] = get_turf(locate(H.x, H.[i], H.z))
						turf++
				else
					for (var/i = current_loc.y - 1, i <= target_loc.y, i--)
						t[turf] = get_turf(locate(H.x, H.[i], H.z))
						turf++
			if (EAST)
				var/turf = 1
				if ((target_loc.x - current_loc.x) > max_range)
					for (var/i = current_loc.x + 1, i <= (current_loc.x + max_range), i++)
						t[turf] = get_turf(locate(H.x, H.[i], H.z))
						turf++
				else
					for (var/i = current_loc.x + 1, i <= target_loc.x, i++)
						t[turf] = get_turf(locate(H.x, H.[i], H.z))
						turf++
			if (WEST)
				var/turf = 1
				if ((current_loc.x - target_loc.x) > max_range)
					for (var/i = current_loc.x - 1, i <= (current_loc.x - max_range), i--)
						t[turf] = get_turf(locate(H.x, H.[i], H.z))
						turf++
				else
					for (var/i = current_loc.x - 1, i <= target_loc.x, i--)
						t[turf] = get_turf(locate(H.x, H.[i], H.z))
						turf++
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
*/