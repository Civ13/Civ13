/obj/structure/animalspawner
	name = "Empty Cave"
	icon = 'icons/obj/animal_spawner.dmi'
	desc = "That's a empty cave. It would look like a preferable place for animals to shelter."
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
	var/procreate_holder = 27000 //45 minutes - TIMER TO PROCREATE
	var/procreate_cooldown = FALSE
	var/wanderer_holder = 18000 //30 minutes to roll the chance for the wanderer to go out
	var/wanderer_cooldown = FALSE

// Runtime-only ownership of the yielding dismantling action.
/obj/structure/animalspawner/var/tmp/dismantling = FALSE

/obj/structure/animalspawner/persistence_runtime_var(key)
	return key == "dismantling" || ..()

/obj/structure/animalspawner/proc/can_dismantle()
	return !QDELETED(src) && empty && !total_population && !males && !females && !cubs

/obj/structure/animalspawner/attackby(obj/W as obj, mob/user as mob)
	if(!istype(W, /obj/item/weapon/material/pickaxe) || !can_dismantle())
		return ..()
	if(dismantling)
		return
	dismantling = TRUE
	var/completed = do_after(user, 65, src)
	if(QDELETED(src))
		return
	if(!completed || !can_dismantle())
		dismantling = FALSE
		return
	// Keep ownership until deletion: another miner cannot award a second yield.
	to_chat(user, "<span class='notice'>You break apart \the [src].</span>")
	for(var/i = 1, i <= 10, i++)
		new /obj/item/stack/material/stone(loc)
	qdel(src)
