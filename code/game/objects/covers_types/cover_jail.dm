/obj/covers/jail/
	name = "jail"
	desc = "Do not use this."
	icon = 'icons/turf/walls.dmi'
	icon_state = "woodjail"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 1
	layer = 3
	health = 100000
	wall = TRUE
	explosion_resistance = 100
	material = "Wood"
	hardness = 15

/obj/covers/jail/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE

	else if (istype(mover, /obj/item/projectile))
		return TRUE
	else
		return FALSE

/obj/covers/jail/woodjail
	name = "wood jail bars"
	desc = "To keep prisoners in."
	icon = 'icons/turf/walls.dmi'
	icon_state = "woodjail"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 1
	layer = 3
	health = 200
	wall = TRUE
	explosion_resistance = 5
	buildstackamount = 8
	buildstack = /obj/item/stack/material/wood
	opacity = 0
	material = "Wood"

/obj/covers/jail/steeljail
	name = "steel jail bars"
	desc = "To keep prisoners in better."
	icon = 'icons/turf/walls.dmi'
	icon_state = "steeljail"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 1
	layer = 3
	health = 800
	wall = TRUE
	explosion_resistance = 5
	buildstackamount = 8
	buildstack = /obj/item/stack/rods
	opacity = 0
	material = "Steel"

/obj/covers/jail/attackby(var/obj/item/weapon/material/kitchen/utensil/I, var/mob/living/human/U)
	if (istype(I,/obj/item/weapon/material/kitchen/utensil/spoon) || istype(I,/obj/item/weapon/material/kitchen/utensil/fork))
		if (I.shiv < 10)
			I.shiv++
			visible_message("<span class='warning'>[U] sharpens \the [I] on \the [src]!</span>")
			if (I.shiv >= 10)
				U.drop_from_inventory(I)
				var/obj/item/weapon/material/kitchen/utensil/knife/shank/SHK = new /obj/item/weapon/material/kitchen/utensil/knife/shank(U,I.material.name)
				U.put_in_hands(SHK)
				U << "\The [I] turns into a shank."
				qdel(I)

/obj/covers/jail/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon) && !istype(W,/obj/item/weapon/wrench)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You pound the bars uselessly!"//sucker
	else if (istype(W,/obj/item/weapon/wrench))//if it is a wrench
		user << "<span class='notice'>You start disassembling the [src]...</span>"
		playsound(loc, 'sound/items/Screwdriver.ogg', 50, TRUE)
		if (do_after(user, 30, target = src))
			for (var/i = TRUE, i <= buildstackamount, i++)
				new buildstack(get_turf(src))
			qdel(src)
			return
	return TRUE

/obj/covers/jail/woodjail/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon) && !istype(W,/obj/item/weapon/wrench) && !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench or hammer since im wood..
		user << "You pound the bars uselessly!" //sucker
	else if (istype(W,/obj/item/weapon/wrench) || istype(W,/obj/item/weapon/hammer))//if it is a wrench or hammer since im wood.
		user << "<span class='notice'>You start disassembling the [src]...</span>"
		playsound(loc, 'sound/items/Screwdriver.ogg', 50, TRUE)
		if (do_after(user, 30, target = src))
			for (var/i = TRUE, i <= buildstackamount, i++)
				new buildstack(get_turf(src))
			qdel(src)
			return
	return TRUE

/obj/covers/jail/bullet_act(var/obj/item/projectile/P)
	return PROJECTILE_CONTINUE

/obj/covers/jail/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE
	else if (istype(mover, /obj/item/projectile))
		return TRUE
	..()
