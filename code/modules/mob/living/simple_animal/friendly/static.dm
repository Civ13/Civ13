/obj/structure/fish
	name = "fish"
	desc = "There seems to be a bunch of fish here."
	icon = 'icons/mob/fish.dmi'
	icon_state = "fish2"
	var/counter = 2
	anchored = TRUE
	var/species = "fish"
	not_movable = TRUE
	not_disassemblable = TRUE
/obj/structure/fish/salmon
	name = "salmon"
	desc = "Salmons. Don't let bears get near!"
	icon = 'icons/mob/fish.dmi'
	icon_state = "salmon"
	counter = 2
	anchored = TRUE
	species = "salmon"

/obj/structure/fish/attackby(var/obj/item/stack/W as obj, var/mob/living/carbon/human/H as mob)
	if (istype(W, /obj/item/weapon/fishing) && counter > 0)
		H.visible_message("[H] starts fishing.")
		if (do_after(H, 150, src))
			if (prob(30))
				H << "You got a fish!"
				counter = (counter-1)
				if (species == "salmon")
					new/obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon(H.loc)
				else
					new/obj/item/weapon/reagent_containers/food/snacks/rawfish(H.loc)
				if (counter <= 0)
					invisibility = 101
				get_fish()
				return
			else
				H << "You can't seem to get anything to bite..."
				return

/obj/structure/fish/proc/get_fish()
	if (counter < 2)
		spawn(rand(3000,3600))
			counter = (counter+1)
			if (invisibility == 101)
				invisibility = 0
				update_icon()

/obj/structure/piranha
	name = "piranha"
	desc = "Dangerous carnivorous fish, they look hungry!"
	icon = 'icons/mob/fish.dmi'
	icon_state = "piranhas"
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
/obj/structure/piranha/New()
	..()
	invisibility = 101

/obj/structure/piranha/Crossed(mob/M as mob)
	for (var/obj/covers/CV in src.loc)
		if (CV.is_cover == TRUE)
			return
	if (!istype(get_turf(src), /turf/floor/beach/water))
		return
	if (istype(M, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = M
		if (!H.driver_vehicle)
			return
		invisibility = 0
		visible_message("<span class='notice'>The piranhas swarm [M]!</span>")
		if (ishuman(H))
			var/dam_zone = pick("l_foot", "r_foot", "l_leg", "r_leg")
			var/obj/item/organ/external/affecting = H.get_organ(dam_zone)
			if (prob(25))
				H.apply_damage(25, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
			else
				affecting.droplimb(FALSE, DROPLIMB_EDGE)
				visible_message("The piranhas bite off [H]'s [affecting]!")
				qdel(affecting)
				for(var/mob/living/carbon/human/NB in view(6,src))
					NB.mood -= 10
					NB.ptsd += 1
			spawn(300)
				invisibility = 101
			return
	else if (istype(M, /mob/living/simple_animal))
		invisibility = 0
		var/mob/living/simple_animal/SA = M
		if (SA.mob_size <= 10 && !istype(SA, /mob/living/simple_animal/mosquito)) //MOB_SMALL, MOB_MINISCULE and MOB_TINY)
			visible_message("<span class='notice'>The piranhas eat the [M] whole!</span>")
			qdel(M)
			spawn(300)
				invisibility = 101
			return
		else
			invisibility = 0
			SA.health--
			spawn(300)
				invisibility = 101
			return
	else
		return

/obj/structure/anthill
	name = "anthill"
	desc = "A anthill of giant red ants. Keep your food away!"
	icon = 'icons/mob/animal.dmi'
	icon_state = "anthill"
	anchored = TRUE

/obj/structure/anthill/New()
	..()
	check_food()

/obj/structure/anthill/proc/check_food()
	var/done = FALSE
	for (var/obj/item/weapon/reagent_containers/food/FD in range(6, src))
		if (done == FALSE)
			new/obj/structure/ants(FD.loc)
			done = TRUE
	spawn(600)
		check_food()

/obj/structure/ants
	name = "red ants"
	desc = "A bunch of red ants."
	icon = 'icons/mob/animal.dmi'
	icon_state = "ants"
	anchored = FALSE
	layer = 4

/obj/structure/ants/New()
	..()
	check_food()


/obj/structure/ants/proc/check_food()
	spawn(400)
		var/done = FALSE
		var/msg_sent = FALSE
		for (var/obj/item/weapon/reagent_containers/food/FD in src.loc)
			if (msg_sent == FALSE)
				visible_message("The ants eat \the [FD]!")
				msg_sent = TRUE
			done = TRUE
			qdel(FD)
		if (done == TRUE)
			qdel(src)
		else
			check_food()
