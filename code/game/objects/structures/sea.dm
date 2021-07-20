/turf/floor/Entered(atom/movable/O)
	..()
	if (istype(O, /obj/structure/buoy) || istype(O, /obj/structure/fishing_cage))
		var/obj/structure/S = O
		S.update_icon()
		if (istype(src, /turf/floor/beach/water))
			if (istype(O, /obj/structure/fishing_cage))
				var/obj/structure/fishing_cage/FC = O
				if (!FC.found && !FC.generating)
					FC.generate_fish()

/obj/structure/buoy
	name = "buoy"
	desc = "A colorful buoy, marking something."
	icon = 'icons/mob/fish.dmi'
	icon_state = "buoy_rw0"
	var/base_icon_state = "buoy_rw"
	anchored = FALSE
	density = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/message = ""
/obj/structure/buoy/update_icon()
	if (istype(loc, /turf/floor/beach/water))
		icon_state = "[base_icon_state]1"
		anchored = TRUE
	else
		icon_state = "[base_icon_state]0"

/obj/structure/buoy/red_white
	name = "red and white buoy"

/obj/structure/buoy/yellow
	name = "yellow buoy"
	icon_state = "buoy_y0"
	base_icon_state = "buoy_y"

/obj/structure/buoy/orange
	name = "orange buoy"
	icon_state = "buoy_o0"
	base_icon_state = "buoy_o"

/obj/structure/buoy/examine(mob/user)
	..()
	if (message != "")
		user << "It has a sign that says: <b>[message]</b>"

/obj/structure/buoy/attackby(obj/item/I as obj, mob/user as mob)
	if (istype(I, /obj/item/weapon/pen))
		message = input(usr, "What do you want the buoy to say?") as text
	else
		..()

//////////////////Crab Cage//////////////////////////////////
/obj/structure/fishing_cage
	name = "fishing cage"
	desc = "A wooden fishing cage trap, used to get deep-sea lobsters, crabs, fish, etc."
	icon = 'icons/mob/fish.dmi'
	icon_state = "crabcage0"
	var/base_icon_state = "crabcage"
	anchored = FALSE
	density = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/found = null
	var/generating = FALSE //so it doesnt run twice
/obj/structure/fishing_cage/update_icon()
	if (istype(loc, /turf/floor/beach/water))
		icon_state = "[base_icon_state]1"
	else
		icon_state = "[base_icon_state]0"

/obj/structure/fishing_cage/attack_hand(mob/user as mob)
	if (found)
		var/atom/FD = new found(loc)
		user << "You open the cage and find there is [FD] inside!"
		if (isitem(FD))
			user.put_in_hands(FD)
		found = null
		generate_fish()
		return
	else
		user << "There is nothing in the cage."
		return

/obj/structure/fishing_cage/proc/generate_fish()
	if (generating)
		return
	generating = TRUE
	found = null
	if (istype(loc, /turf/floor/beach/water))
		spawn(rand(18000,24000))
			generating = FALSE
			if (istype(loc, /turf/floor/beach/water) && !found)
				if (istype(loc, /turf/floor/beach/water/deep/saltwater))
					if (prob(25))
						found = /obj/item/weapon/reagent_containers/food/snacks/octopus
					else if (prob(50))
						found = /obj/item/weapon/reagent_containers/food/snacks/rawlobster
					else
						found = /obj/item/weapon/reagent_containers/food/snacks/rawfish/cod
					if (prob(25))
						found = /obj/item/weapon/reagent_containers/food/snacks/pink_squid

				else if (istype(loc, /turf/floor/beach/water/shallowsaltwater))
					if (prob(50))
						found = /obj/item/weapon/reagent_containers/food/snacks/rawfish
					else if (prob(50))
						found =/obj/item/shellfish
					else
						found = /mob/living/simple_animal/crab/small/dead
				else if (istype(loc, /turf/floor/beach/water/jungle) || istype(loc, /turf/floor/beach/water/deep/jungle) || istype(loc, /turf/floor/beach/water/flooded))
					found = /obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon

				else if (istype(loc, /turf/floor/beach/water/deep/swamp) || istype(loc, /turf/floor/beach/water/swamp) || istype(loc, /turf/floor/beach/water/ice))
					found = null
					return
				else
					if (prob(50))
						found =/obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon
					else
						found =/obj/item/shellfish
					return
			else
				return
	else
		generating = FALSE
		return