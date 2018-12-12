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

/obj/structure/oil_spring/proc/refill()
	if (world.time >= timeout)
		if (counter < 1)
			counter++
			return
	else
		spawn(50)
			refill()