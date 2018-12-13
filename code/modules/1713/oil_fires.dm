/obj/structure/oil_spring
	name = "petroleum spring"
	desc = "A hole on the ground where petroleum reaches the surface. Sticky!"
	icon = 'icons/obj/watercloset.dmi'
	icon_state = "oil_spring1"
	anchored = TRUE
	var/counter = 1
	var/timeout = 0

/obj/structure/oil_spring/attackby(obj/item/O as obj, mob/living/user as mob)
	if (counter <= 0)
		user << "<span class='warning'>\The [src] is dry!</span>"
		if (counter < 0)
			counter = 0
		return
	if (istype(O, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/RG = O
		if (istype(RG) && RG.is_open_container() && do_after(user, 15, src, check_for_repeats = FALSE) && !(istype(src, /obj/structure/sink/puddle)))
			RG.reagents.add_reagent("petroleum", 10)
			user.visible_message("<span class='notice'>[user] fills \the [RG] using \the [src].</span>","<span class='notice'>You fill \the [RG] using \the [src].</span>")
			playsound(loc, 'sound/effects/watersplash.ogg', 100, TRUE)
			user.setClickCooldown(20)
			counter--
			update_icon()
			timeout = world.time + 600
			refill()
			return
	else if (istype(O, /obj/item/flashlight))
		var/obj/item/flashlight/OO = O
		if (counter > 0 && OO.on)
			visible_message("[user] sets the [src] on fire!","You set the [src] on fire!")
			counter = 0
			timeout = world.time + 1800
			refill()
			oil_explode()
			update_icon()
			qdel(O)
			return

/obj/structure/oil_spring/update_icon()
	..()
	if (counter > 0)
		icon_state = "oil_spring1"
	else
		icon_state = "oil_spring0"

/obj/structure/oil_spring/proc/refill()
	if (world.time >= timeout)
		if (counter < 1)
			counter++
			update_icon()
			return
	else
		spawn(50)
			refill()

/obj/structure/oil_spring/proc/oil_explode()
	playsound(loc, 'sound/effects/Explosion2.ogg', 100, FALSE, 12)
	for (var/mob/living/LS1 in locate(x,y,z))
		LS1.adjustFireLoss(35)
		LS1.fire_stacks += rand(8,10)
		LS1.IgniteMob()
	new/obj/effect/burning_oil(locate(x,y,z))

	for (var/mob/living/LS2 in locate(x-1,y,z))
		LS2.adjustFireLoss(35)
		LS2.fire_stacks += rand(5,7)
		LS2.IgniteMob()
	new/obj/effect/burning_oil(locate(x-1,y,z))

	for (var/mob/living/LS3 in locate(x+1,y,z))
		LS3.adjustFireLoss(35)
		LS3.fire_stacks += rand(5,7)
		LS3.IgniteMob()
	new/obj/effect/burning_oil(locate(x+1,y,z))

	for (var/mob/living/LS21 in locate(x,y+1,z))
		LS21.adjustFireLoss(35)
		LS21.fire_stacks += rand(8,10)
		LS21.IgniteMob()
	new/obj/effect/burning_oil(locate(x,y+1,z))

	for (var/mob/living/LS22 in locate(x-1,y+1,z))
		LS22.adjustFireLoss(35)
		LS22.fire_stacks += rand(5,7)
		LS22.IgniteMob()
	new/obj/effect/burning_oil(locate(x-1,y+1,z))

	for (var/mob/living/LS23 in locate(x+1,y+1,z))
		LS23.adjustFireLoss(35)
		LS23.fire_stacks += rand(5,7)
		LS23.IgniteMob()
	new/obj/effect/burning_oil(locate(x+1,y+1,z))

	for (var/mob/living/LS31 in locate(x,y-1,z))
		LS31.adjustFireLoss(35)
		LS31.fire_stacks += rand(8,10)
		LS31.IgniteMob()
	new/obj/effect/burning_oil(locate(x,y-1,z))

	for (var/mob/living/LS32 in locate(x-1,y-1,z))
		LS32.adjustFireLoss(35)
		LS32.fire_stacks += rand(5,7)
		LS32.IgniteMob()
	new/obj/effect/burning_oil(locate(x-1,y-1,z))

	for (var/mob/living/LS33 in locate(x+1,y-1,z))
		LS33.adjustFireLoss(35)
		LS33.fire_stacks += rand(5,7)
		LS33.IgniteMob()
	new/obj/effect/burning_oil(locate(x+1,y-1,z))
	return


/obj/effect/burning_oil
	name = "fire"
	icon = 'icons/effects/effects.dmi'
	icon_state = "burning_fire2"
	layer = TURF_LAYER+2.2
	anchored = TRUE
	density = FALSE

/obj/effect/burning_oil/New()
	..()
	icon = 'icons/effects/effects.dmi'
	icon_state = "burning_fire2"
	alpha = 230
	burningproc()
	set_light(2)
	spawn(230)
		set_light(0)
		qdel(src)

/obj/effect/burning_oil/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/CT = W
		for (var/datum/reagent/R in CT.reagents.reagent_list)
			if (istype(R, /datum/reagent/water))
				visible_message("[user] empties \the [CT] into the fire!")
				if (prob(max(R.volume, 100)))
					qdel(src)
					visible_message("The fire is put out!")
				CT.reagents.clear_reagents()

/obj/effect/burning_oil/proc/burningproc()
	spawn(35)
//this tile
		for (var/mob/living/L in src.loc)
			L.IgniteMob()
			L.adjustFireLoss(rand(15,20))

		for (var/obj/effect/decal/cleanable/blood/O in src.loc)
			spawn(50)
				qdel(O)

		for (var/obj/OB in src.loc)
			if (prob(35) && !istype(OB, /obj/effect/decal/cleanable/blood/oil) && OB.flammable)
				OB.fire_act(900)

		for (var/obj/effect/burning_oil/OTH in src.loc)
			if (OTH != src)
				qdel(OTH)
//burn floors
		if (istype(get_turf(src), /turf/floor/plating/grass))
			var/turf/T = get_turf(src)
			T.ChangeTurf(/turf/floor/dirt/burned)
		else if (istype(get_turf(src), /turf/floor/wood))
			var/turf/T = get_turf(src)
			T.ChangeTurf(/turf/floor/wood_broken)
//bordering tiles
		for (var/obj/effect/decal/cleanable/blood/OL in range(1, get_turf(src)))
			var/dont = FALSE
			for (var/obj/effect/burning_oil/BOI in OL.loc)
				dont = TRUE
			if (!dont)
				if (istype(OL, /obj/effect/decal/cleanable/blood/oil))
					if (prob(15))
						new/obj/effect/burning_oil(OL.loc)
				if (istype(OL, /obj/effect/decal/cleanable/blood/tracks) && OL.color == "#030303")
					if (prob(15))
						new/obj/effect/burning_oil(OL.loc)

		for (var/turf/floor/plating/grass/GR in range(1, get_turf(src)))
			var/dont = FALSE
			for (var/obj/effect/burning_oil/BOI in GR.loc)
				dont = TRUE
			if (!dont)
				if (prob(5))
					var/obj/effect/burning_oil/NB = new/obj/effect/burning_oil(GR)
					spawn(80)
						qdel(src)
						qdel(NB)
		for (var/turf/floor/wood/WF in range(1, get_turf(src)))
			var/dont = FALSE
			for (var/obj/effect/burning_oil/BOI in WF.loc)
				dont = TRUE
			if (!dont)
				if (prob(15))
					var/obj/effect/burning_oil/NB = new/obj/effect/burning_oil(WF)
					spawn(80)
						qdel(src)
						qdel(NB)
//remove duplicates
		for (var/obj/effect/burning_oil/OTH in src.loc)
			if (OTH != src)
				qdel(OTH)

		burningproc()

/obj/effect/decal/cleanable/blood/oil
	name = "oil"
	desc = "It's black and greasy."
	basecolor="#030303"

/obj/effect/decal/cleanable/blood/oil/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/flashlight))
		var/obj/item/flashlight/OO = W
		if (OO.on)
			visible_message("[user] sets the [src] on fire!","You set the [src] on fire!")
			new/obj/effect/burning_oil(src.loc)
			return
/obj/effect/decal/cleanable/blood/oil/dry()
	return

/obj/effect/decal/cleanable/blood/oil/streak
	random_icon_states = list("mgibbl1", "mgibbl2", "mgibbl3", "mgibbl4", "mgibbl5")
	amount = 2