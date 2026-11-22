/turf/floor/Entered(atom/movable/O)
	..()
	if (!isobj(O))
		return
	if (istype(O, /obj/structure/buoy) || istype(O, /obj/structure/fishing_cage))
		var/obj/structure/S = O
		S.update_icon()
		if (istype(src, /turf/floor/beach/water))
			if (istype(O, /obj/structure/fishing_cage))
				var/obj/structure/fishing_cage/FC = O
				// Entered can run before /atom/New marks an imported cage as restoring.
				if (!persistence_saved_atom_construction && !FC.restoring && !FC.found && !FC.generating)
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
		to_chat(user, "It has a sign that says: <b>[message]</b>")

/obj/structure/buoy/attackby(obj/item/I as obj, mob/user as mob)
	if (istype(I, /obj/item/weapon/pen))
		message = player_input(usr, "What do you want the buoy to say?", null, null, "text", null, FALSE)
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
	var/generating = FALSE //so it doesn't run twice

/obj/structure/fishing_cage/persistence_runtime_var(key)
	return key == "generating" || ..()

/obj/structure/fishing_cage/after_load()
	..()
	// A pending spawn is process-local. Keep a saved catch, or start a fresh wait.
	generating = FALSE
	update_icon()
	if (!found && istype(loc, /turf/floor/beach/water))
		generate_fish()

/obj/structure/fishing_cage/update_icon()
	if (istype(loc, /turf/floor/beach/water))
		icon_state = "[base_icon_state]1"
	else
		icon_state = "[base_icon_state]0"

/obj/structure/fishing_cage/attack_hand(mob/user as mob)
	if (found)
		var/atom/FD = new found(loc)
		to_chat(user, "You open the cage and find there is [FD] inside!")
		if (isitem(FD))
			user.put_in_hands(FD)
		found = null
		generate_fish()
		return
	else
		to_chat(user, "There is nothing in the cage.")
		var/datum/fishing_ground/G = fishing_ground_at(loc, FALSE)
		if (G && G.available() < 1)
			to_chat(user, SPAN_WARNING("Nothing stirs in the water around it. This stretch is fished out for now."))
		return

// What the water at T puts in a cage, or null for nothing. Fish come out of
// the fishing ground the cage sits in (fishing_grounds.dm), so a cage in a
// fished-out stretch comes up empty; shellfish, crabs and the like do not.
/obj/structure/fishing_cage/proc/barren_water(turf/T)
	return istype(T, /turf/floor/beach/water/deep/swamp) || istype(T, /turf/floor/beach/water/swamp) || istype(T, /turf/floor/beach/water/ice)

/obj/structure/fishing_cage/proc/pick_catch(turf/T)
	if (barren_water(T))
		return null
	var/picked
	if (istype(T, /turf/floor/beach/water/deep/saltwater))
		if (prob(25))
			picked = /obj/item/weapon/reagent_containers/food/snacks/octopus
		else if (prob(50))
			picked = /obj/item/weapon/reagent_containers/food/snacks/rawlobster
		else
			picked = /obj/item/weapon/reagent_containers/food/snacks/rawfish/cod
		if (prob(25))
			picked = /obj/item/weapon/reagent_containers/food/snacks/pink_squid
	else if (istype(T, /turf/floor/beach/water/shallowsaltwater))
		if (prob(50))
			picked = /obj/item/weapon/reagent_containers/food/snacks/rawfish
		else if (prob(50))
			picked = /obj/item/shellfish
		else
			picked = /mob/living/simple_animal/crab/small/dead
	else if (istype(T, /turf/floor/beach/water/jungle) || istype(T, /turf/floor/beach/water/deep/jungle) || istype(T, /turf/floor/beach/water/flooded))
		picked = /obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon
	else if (prob(50))
		picked = /obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon
	else
		picked = /obj/item/shellfish
	if (ispath(picked, /obj/item/weapon/reagent_containers/food/snacks/rawfish) && !fish_ground_trap_catch(T))
		return null
	return picked

/obj/structure/fishing_cage/proc/generate_fish()
	if (generating)
		return
	generating = TRUE
	found = null
	if (!istype(loc, /turf/floor/beach/water))
		generating = FALSE
		return
	spawn(rand(18000,24000))
		generating = FALSE
		if (QDELETED(src) || found || !istype(loc, /turf/floor/beach/water))
			return
		found = pick_catch(loc)
		if (!found && !barren_water(loc))
			generate_fish() // nothing this time; leave it down and wait again
