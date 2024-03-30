/obj/structure/oil_spring
	name = "petroleum spring"
	desc = "A hole on the ground where petroleum reaches the surface. Sticky!"
	icon = 'icons/obj/watercloset.dmi'
	icon_state = "oil_spring1"
	anchored = TRUE
	var/counter = 1
	var/timeout = 0
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/oil_spring/attackby(obj/item/O as obj, mob/living/user as mob)
	if (counter <= 0)
		user << "<span class='warning'>\The [src] is dry!</span>"
		if (counter < 0)
			counter = 0
		return

	if (istype(O, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/RG = O
		if (istype(RG) && RG.is_open_container() && do_after(user, 15, src, check_for_repeats = FALSE))
			if (counter > 0)
				RG.reagents.add_reagent("petroleum", min(RG.volume - RG.reagents.total_volume, 10))
				user.visible_message("<span class='notice'>[user] fills \the [RG] using \the [src].</span>", "<span class='notice'>You fill \the [RG] using \the [src].</span>")
				playsound(loc, 'sound/effects/watersplash.ogg', 100, TRUE)
				user.setClickCooldown(20)
				counter--
				update_icon()
				timeout = world.time + 600
				refill()
				return

	else if (istype(O, /obj/item/flashlight/torch))
		var/obj/item/flashlight/torch/OO = O
		if (counter > 0 && OO.on)
			user.visible_message("<span class = 'red'>[user.name] sets \the [src] on fire!</span>", "<span class = 'red'>You set \the [src] on fire!</span>")
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
		LS1.adjustBurnLoss(35)
		LS1.fire_stacks += rand(8,10)
		LS1.IgniteMob()
	new/obj/effect/fire(locate(x,y,z))

	for (var/mob/living/LS2 in locate(x-1,y,z))
		LS2.adjustBurnLoss(35)
		LS2.fire_stacks += rand(5,7)
		LS2.IgniteMob()
	new/obj/effect/fire(locate(x-1,y,z))

	for (var/mob/living/LS3 in locate(x+1,y,z))
		LS3.adjustBurnLoss(35)
		LS3.fire_stacks += rand(5,7)
		LS3.IgniteMob()
	new/obj/effect/fire(locate(x+1,y,z))

	for (var/mob/living/LS21 in locate(x,y+1,z))
		LS21.adjustBurnLoss(35)
		LS21.fire_stacks += rand(8,10)
		LS21.IgniteMob()
	new/obj/effect/fire(locate(x,y+1,z))

	for (var/mob/living/LS22 in locate(x-1,y+1,z))
		LS22.adjustBurnLoss(35)
		LS22.fire_stacks += rand(5,7)
		LS22.IgniteMob()
	new/obj/effect/fire(locate(x-1,y+1,z))

	for (var/mob/living/LS23 in locate(x+1,y+1,z))
		LS23.adjustBurnLoss(35)
		LS23.fire_stacks += rand(5,7)
		LS23.IgniteMob()
	new/obj/effect/fire(locate(x+1,y+1,z))

	for (var/mob/living/LS31 in locate(x,y-1,z))
		LS31.adjustBurnLoss(35)
		LS31.fire_stacks += rand(8,10)
		LS31.IgniteMob()
	new/obj/effect/fire(locate(x,y-1,z))

	for (var/mob/living/LS32 in locate(x-1,y-1,z))
		LS32.adjustBurnLoss(35)
		LS32.fire_stacks += rand(5,7)
		LS32.IgniteMob()
	new/obj/effect/fire(locate(x-1,y-1,z))

	for (var/mob/living/LS33 in locate(x+1,y-1,z))
		LS33.adjustBurnLoss(35)
		LS33.fire_stacks += rand(5,7)
		LS33.IgniteMob()
	new/obj/effect/fire(locate(x+1,y-1,z))
	return


/obj/effect/fire
	name = "fire"
	icon = 'icons/effects/effects.dmi'
	icon_state = "burning_fire2"
	layer = TURF_LAYER+2.2
	anchored = TRUE
	density = FALSE
	var/timer = 180
	var/runonce = FALSE
/obj/effect/fire/New()
	..()
	icon = 'icons/effects/effects.dmi'
	icon_state = "burning_fire2"
	alpha = 230
	spawn(30)
		if (runonce == FALSE)
			burningproc()
			runonce = TRUE
	set_light(3)
	light_color = "#FF9900"
	spawn(timer)
		set_light(0)
		qdel(src)

/obj/effect/fire/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/CT = W
		for (var/datum/reagent/R in CT.reagents.reagent_list)
			if (istype(R, /datum/reagent/water))
				user.visible_message("[user] empties \the [CT] into the fire!", "You empty \the [CT] into the fire!")
				if (prob(max(R.volume, 100)))
					qdel(src)
					visible_message("The fire is extinguished!")
				CT.reagents.clear_reagents()

/obj/effect/fire/proc/burningproc()
//this tile
	if (prob(3))
		new/obj/effect/effect/smoke(loc)
	var/area/A = get_area(get_turf(src))
	if (!A)
		return
	if (A.weather == WEATHER_WET)
		if (A.climate != "semiarid" || A.climate != "jungle" || A.climate != "desert" || A.climate != "savanna" || season == "WINTER" || season == "SPRING")
			if (prob(30))
				qdel(src)
	if (A.weather == WEATHER_EXTREME)
		qdel(src)

	for (var/mob/living/L in src.loc)
		L.adjustBurnLoss(rand(20, 40))
		if (prob(40))
			L.fire_stacks += rand(1,2)
		L.IgniteMob()

	for (var/obj/effect/decal/cleanable/blood/O in src.loc)
		spawn(50)
			qdel(O)

	for (var/obj/OB in src.loc)
		if (prob(35) && !istype(OB, /obj/effect/decal/cleanable/blood) && OB.flammable)
			OB.fire_act(1200)

	for (var/obj/effect/fire/OTH in src.loc)
		if (OTH != src)
			qdel(OTH)

	for (var/obj/structure/oil_spring/OS in src.loc)
		if (OS.counter > 0)
			OS.oil_explode()
			OS.counter = 0

//burn floors
	if (istype(get_turf(src), /turf/floor/grass))
		var/turf/T = get_turf(src)
		T.ChangeTurf(/turf/floor/dirt/burned)
	else if (istype(get_turf(src), /turf/floor/wood))
		var/turf/T = get_turf(src)
		T.ChangeTurf(/turf/floor/wood_broken)

//bordering tiles
	for (var/obj/effect/decal/cleanable/blood/OL in orange(1, src))
		if (istype(OL, /obj/effect/decal/cleanable/blood/oil))
			if (prob(35))
				new/obj/effect/fire(OL.loc)
		if (istype(OL, /obj/effect/decal/cleanable/blood/tracks) && OL.color == "#030303")
			if (prob(35))
				new/obj/effect/fire(OL.loc)

	for (var/turf/floor/grass/GR in orange(1, src))
		var/blocked = 0
		for (var/obj/covers/CV in GR)
			if (CV.flammable == 0)
				blocked = 1
		for (var/obj/structure/vehicleparts/frame/F in GR)
			var/found = FALSE
			for (var/obj/structure/vehicleparts/frame/F2 in src.loc)
				found = TRUE
			if (!found)
				blocked = 1
		if (prob(10) && !blocked)
			new/obj/effect/fire(GR)

	for (var/turf/floor/wood/WF in orange(1, src))
		if (prob(21))
			new/obj/effect/fire(WF)
	for (var/obj/covers/repairedfloor/RF in orange(1, src))
		if (prob(12))
			new/obj/effect/fire(RF)

//remove duplicates
	for (var/obj/effect/fire/OTH in src.loc)
		if (OTH != src)
			qdel(OTH)
	spawn(50)
		burningproc()
	return

/obj/effect/decal/cleanable/blood/oil
	name = "oil"
	desc = "It's black and greasy."
	basecolor="#030303"

/obj/effect/decal/cleanable/blood/oil/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/flashlight/torch))
		var/obj/item/flashlight/torch/OO = W
		if (OO.on)
			user.visible_message("<span class = 'red'>[user.name] sets \the [src] on fire!</span>", "<span class = 'red'>You set \the [src] on fire!</span>")
			ignite_turf(src.loc, 18, 20)
			return

/obj/effect/decal/cleanable/blood/oil/dry()
	return

/obj/effect/decal/cleanable/blood/oil/streak
	random_icon_states = list("mgibbl1", "mgibbl2", "mgibbl3", "mgibbl4", "mgibbl5")
	amount = 2