/obj/structure/oil_spring
	name = "petroleum spring"
	desc = "A hole on the ground where petroleum reaches the surface. Sticky!"
	icon = 'icons/obj/watercloset.dmi'
	icon_state = "oil_spring"
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
			qdel(O)
			return

/obj/structure/oil_spring/proc/refill()
	if (world.time >= timeout)
		if (counter < 1)
			counter++
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
