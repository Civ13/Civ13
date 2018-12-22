/obj/structure/fish
	name = "fish"
	desc = "There seems to be a bunch of fish here."
	icon = 'icons/mob/fish.dmi'
	icon_state = "fish2"
	var/counter = 2
	anchored = TRUE
	var/species = "fish"

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
	invisibility = 0

/obj/structure/piranha/Bumped(mob/M as mob)
	for (var/obj/covers/CV in src.loc)
		if (CV.is_cover == TRUE)
			return
	if (istype(M, /mob/living/carbon/human))
		invisibility = 101
		visible_message("<span class='notice'>The piranhas swarm to [M]!</span>")
		if (ishuman(M))
			var/mob/living/carbon/human/H = M
			var/dam_zone = pick("l_foot", "r_foot", "l_leg", "r_leg")
			var/obj/item/organ/external/affecting = H.get_organ(ran_zone(dam_zone))
			if (prob(75))
				H.apply_damage(25, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
			else
				affecting.droplimb(FALSE, DROPLIMB_EDGE)
				visible_message("The piranhas bite off [H]'s [affecting]!")
			return
	else if (istype(M, /mob/living/simple_animal))
		invisibility = 101
		var/mob/living/simple_animal/SA = M
		if (SA.mob_size <= 10) //MOB_SMALL, MOB_MINISCULE and MOB_TINY)
			visible_message("<span class='notice'>The piranhas eat the [M] whole!</span>")
			qdel(M)
			return
		else
			SA.health--
			return
	else
		return