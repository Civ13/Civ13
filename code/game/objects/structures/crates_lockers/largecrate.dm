/obj/structure/largecrate
	name = "large crate"
	desc = "A hefty wooden crate."
	icon = 'icons/obj/storage.dmi'
	icon_state = "densecrate"
	density = TRUE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
/obj/structure/largecrate/attack_hand(mob/user as mob)
	user << "<span class='notice'>You need a crowbar to pry this open!</span>"
	return

/obj/structure/largecrate/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/crowbar))
		new /obj/item/stack/material/wood(src)
		var/turf/T = get_turf(src)
		for (var/atom/movable/AM in contents)
			if (AM.simulated) AM.forceMove(T)
		user.visible_message("<span class='notice'>[user] pries \the [src] open.</span>", \
							 "<span class='notice'>You pry open \the [src].</span>", \
							 "<span class='notice'>You hear splitting wood.</span>")
		qdel(src)
	else
		return attack_hand(user)

/obj/structure/largecrate/animal
	icon_state = "mulecrate"
	var/held_count = TRUE
	var/held_type

/obj/structure/largecrate/animal/New()
	..()
	for (var/i = TRUE;i<=held_count;i++)
		new held_type(src)

/obj/structure/largecrate/animal/dog

/obj/structure/largecrate/animal/dog/german
	held_type = /mob/living/simple_animal/complex_animal/dog/german_shepherd
	name = "German Shepherd Crate"

/obj/structure/largecrate/animal/dog/pirates
	held_type = /mob/living/simple_animal/complex_animal/dog/samoyed
	name = "Samoyed Crate"