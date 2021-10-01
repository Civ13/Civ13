/obj/structure/animalspawner
	name = "Empty Cave"
	icon = 'icons/obj/animal_spawner.dmi'
	desc = "Thats a empty cave. It would look like a preferable place for animals to shelter."
	anchored = TRUE
	density = TRUE
	var/females = 0
	var/males = 0
	var/cubs = 0
	var/cub_growing = FALSE
	var/total_population = 0
	var/ticking = FALSE
	var/t_climate = null
	var/aggroed = FALSE
	var/empty = TRUE
	var/max_pop = 10
	var/procreate_holder = 27000 //45 minutes - TIMER TO PROCREATE
	var/procreate_cooldown = FALSE
	var/wanderer_holder = 18000 //30 minutes to roll the chance for the wanderer to go out
	var/wanderer_cooldown = FALSE

/obj/structure/animalspawner/attackby(obj/W as obj, mob/user as mob)
	if(istype(W,/obj/item/weapon/material/pickaxe) && empty)
		if (do_after(user,65,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			qdel(src)
	..()