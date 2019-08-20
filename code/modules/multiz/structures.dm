//////////////////////////////
//Contents: Ladders, Stairs.//
//////////////////////////////

/hook/roundstart/proc/assign_ladder_ids()

	var/list/top_ladders = list()
	var/list/bottom_ladders = list()

	for (var/obj/structure/multiz/ladder/ww2/ladder in ladder_list)
		if (ladder.istop)
			if (!top_ladders[ladder.area_id])
				top_ladders[ladder.area_id] = 0
			++top_ladders[ladder.area_id]
			ladder.ladder_id = "ww2-l-[ladder.area_id]-[top_ladders[ladder.area_id]]"
		else
			if (!bottom_ladders[ladder.area_id])
				bottom_ladders[ladder.area_id] = 0
			++bottom_ladders[ladder.area_id]
			ladder.ladder_id = "ww2-l-[ladder.area_id]-[bottom_ladders[ladder.area_id]]"

	for (var/obj/structure/multiz/ladder/ww2/ladder in ladder_list)
		ladder.target = ladder.find_target()
	return TRUE

/obj/structure/multiz
	name = "ladder"
	density = FALSE
	opacity = FALSE
	anchored = TRUE
	icon = 'icons/obj/stairs.dmi'
	var/istop = TRUE
	var/obj/structure/multiz/target
	not_movable = TRUE
	not_disassemblable = TRUE
	New()
		. = ..()
		for (var/obj/structure/multiz/M in loc)
			if (M != src)
				spawn(1)
					world.log << "##MAP_ERROR: Multiple [initial(name)] at ([x],[y],[z])"
					qdel(src)
				return .

	CanPass(obj/mover, turf/source, height, airflow)
		return airflow || !density

	proc/find_target()
		return

	initialize()
		find_target()
/*
	attack_tk(mob/user)
		return*/

	attack_ghost(mob/user)
		. = ..()
		user.Move(get_turf(target))

	attackby(obj/item/C, mob/user)
		. = ..()
		attack_hand(user)
		return



////LADDER////

/obj/structure/multiz/ladder
	name = "ladder"
	desc = "A ladder.  You can climb it up and down."
	icon_state = "ladderdown"
	layer = 2.99 // below crates

/obj/structure/multiz/ladder/New()
	..()
	ladder_list += src

/obj/structure/multiz/ladder/Destroy()
	ladder_list -= src
	..()

/obj/structure/multiz/ladder/find_target()
	var/turf/targetTurf = istop ? GetBelow(src) : GetAbove(src)
	target = locate(/obj/structure/multiz/ladder) in targetTurf

/obj/structure/multiz/ladder/up
	icon_state = "ladderup"
	istop = FALSE

/obj/structure/multiz/ladder/Destroy()
	if (target && istop)
		qdel(target)
	return ..()

/obj/structure/multiz/ladder/attack_hand(var/mob/M)

	if (M.restrained())
		M << "<span class='warning'>You can't use \the [src] while you're restrained.</span>"
		return

	if (!target || !istype(target.loc, /turf))
		if (!istype(src, /obj/structure/multiz/ladder/ww2/tunneltop) && !istype(src, /obj/structure/multiz/ladder/ww2/tunnelbottom) && !istype(src, /obj/structure/multiz/ladder/ww2) && !istype(src, /obj/structure/multiz/ladder/ww2/up) && !istype(src, /obj/structure/multiz/ladder/ww2/stairsdown) && !istype(src, /obj/structure/multiz/ladder/ww2/stairsup))
			M << "<span class='notice'>\The [src] is incomplete and can't be climbed.</span>"
			return

	M.visible_message(
		"<span class='notice'>\A [M] starts to climb [istop ? "down" : "up"] \a [src].</span>",
		"<span class='notice'>You start to climb [istop ? "down" : "up"] \the [src].</span>",
		"You hear the grunting and clanging of a metal ladder being used."
	)

	if (do_after(M, 10, src))
		playsound(loc, 'sound/effects/ladder.ogg', 50, TRUE, -1)
		// pulling/grabbing people with you
		if (istop)
			if (M.pulling != null)
				M.pulling.z = M.pulling.z-1
				M.pulling.x = src.x
				M.pulling.y = src.y
			M.z = M.z-1
			M.x = src.x
			M.y = src.y
			return
		else
			if (M.pulling != null)
				M.pulling.z = M.pulling.z+1
				M.pulling.x = src.x
				M.pulling.y = src.y
			M.z = M.z+1
			M.x = src.x
			M.y = src.y
			return
		M.visible_message(
			"<span class='notice'>\A [M] climbs [istop ? "down" : "up"] \a [src].</span>",
			"<span class='notice'>You climb [istop ? "down" : "up"] \the [src].</span>",
			"You hear the grunting and clanging of a metal ladder being used."
		)

/mob/living/carbon/human/var/laddervision = null

/obj/structure/multiz/ladder/MouseDrop_T(var/mob/living/carbon/human/user as mob)
	if (!user || !istype(user))
		return
	if (user.laddervision == src)
		return
	if (!target)
		return
	if (user.laddervision)
		user.update_laddervision(target) // stop looking up/down
		return

	visible_message("<span class = 'notice'>[user] starts to look [target.laddervision_direction()] \the [src].</span>")
	if (do_after(user, 12, src))
		user.update_laddervision(target)
		visible_message("<span class = 'notice'>[user] looks [user.laddervision_direction()] \the [src].</span>")

/mob/living/carbon/human/proc/update_laddervision(var/obj/structure/multiz/ladder/ladder)
	if (ladder && istype(ladder))
		client.perspective = EYE_PERSPECTIVE
		laddervision = ladder
		client.eye = laddervision
	else if (!ladder && laddervision)
		client.perspective = MOB_PERSPECTIVE
		client.eye = src
		laddervision = null

/obj/structure/multiz/proc/laddervision_direction()
	if (istop)
		return "up"
	else
		return "down"

/mob/living/carbon/human/proc/laddervision_direction()
	if (!laddervision)
		return ""
	var/obj/structure/multiz/ladder = laddervision
	if (ladder.istop)
		return "up"
	return "down"

/* 1 Z LEVEL LADDERS - Kachnov */

/obj/structure/multiz/ladder/ww2
	var/ladder_id = null
	var/area_id = "defaultareaid"

/obj/structure/multiz/ladder/ww2/stairsdown
	icon_state = "rampbottom"
	name = "stairs"

/obj/structure/multiz/ladder/ww2/Crossed(var/atom/movable/AM)
	if (find_target() && istop)
		if (!AM.pulledby && isitem(AM) && !istype(AM, /obj/item/projectile))
			var/obj/item/I = AM
			if (I.w_class <= 2.0) // fixes maxim bug and probably some others - Kachnov
				I.z = I.z-1
				visible_message("\The [I] falls down the ladder.")
		else if (!AM.pulledby && istype(AM, /obj/structure/closet))
			visible_message("\The [AM] falls down the ladder.")
			AM.z = AM.z-1

/obj/structure/multiz/ladder/ww2/find_target()
	for (var/obj/structure/multiz/ladder/ww2/ladder in ladder_list)
		if (ladder_id == ladder.ladder_id && ladder != src)
			return ladder

/obj/structure/multiz/ladder/ww2/ex_act(severity)
	return

/obj/structure/multiz/ladder/ww2/up
	icon_state = "ladderup"
	istop = FALSE

/obj/structure/multiz/ladder/ww2/stairsup
	icon_state = "rampup"
	name = "stairs"
	istop = FALSE

/obj/structure/multiz/ladder/ww2/Destroy()
	if (target && istop)
		qdel(target)
	return ..()

/obj/structure/multiz/ladder/ww2/tunneltop
	name = "tunnel entrance"
	desc = "A hole dug in the floor, leads to an underground tunnel."
	icon_state = "hole_top"
	istop = TRUE

/obj/structure/multiz/ladder/ww2/tunneltop/vietcong
	icon_state = "pine_closed"

/obj/structure/multiz/ladder/ww2/tunneltop/vietcong/attack_hand(var/mob/M)
	if (istype(M, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = M
		if (H.faction_text != "VIETNAMESE" && H.original_job_title != "US Commando")
			H << "This tunnel is too small for you!"
			return
		else
			..()
	else
		..()

/obj/structure/multiz/ladder/ww2/tunnelbottom
	name = "tunnel exit"
	desc = "A makeshift stairway, leads to the surface."
	icon_state = "hole_bottom"
	istop = FALSE
/obj/structure/multiz/ladder/ww2/tunnelbottom/vietcong

/obj/structure/multiz/ladder/ww2/teleporter
	name = "ladder"
	desc = "A ladder.  You can climb it up and down."
	icon_state = "ladderdown"
	layer = 2.99 // below crates
/obj/structure/multiz/ladder/ww2/teleporter/up
	icon_state = "ladderup"
	istop = FALSE
/obj/structure/multiz/ladder/ww2/teleporter/New()
	..()
	for (var/obj/structure/multiz/ladder/ww2/teleporter/ladder in ladder_list)
		if (ladder_id == ladder.ladder_id && ladder != src)
			target = ladder
			continue
/obj/structure/multiz/ladder/ww2/teleporter/find_target()
	for (var/obj/structure/multiz/ladder/ww2/teleporter/ladder in ladder_list)
		if (ladder_id == ladder.ladder_id && ladder != src)
			return ladder
	return FALSE
/obj/structure/multiz/ladder/ww2/teleporter/Crossed(var/atom/movable/AM)
	if (target && istop)
		if (!AM.pulledby && isitem(AM) && !istype(AM, /obj/item/projectile))
			var/obj/item/I = AM
			if (I.w_class <= 2.0) // fixes maxim bug and probably some others - Kachnov
				I.loc = target.loc
				visible_message("\The [I] falls down the ladder.")
		else if (!AM.pulledby && istype(AM, /obj/structure/closet))
			visible_message("\The [AM] falls down the ladder.")
			AM.loc = target.loc
/obj/structure/multiz/ladder/ww2/teleporter/attack_hand(var/mob/M)

	if (M.restrained())
		M << "<span class='warning'>You can't use \the [src] while you're restrained.</span>"
		return

	if (!target || !istype(target.loc, /turf))
		if (!istype(src, /obj/structure/multiz/ladder/ww2/tunneltop) && !istype(src, /obj/structure/multiz/ladder/ww2/tunnelbottom) && !istype(src, /obj/structure/multiz/ladder/ww2) && !istype(src, /obj/structure/multiz/ladder/ww2/up) && !istype(src, /obj/structure/multiz/ladder/ww2/stairsdown) && !istype(src, /obj/structure/multiz/ladder/ww2/stairsup))
			M << "<span class='notice'>\The [src] is incomplete and can't be climbed.</span>"
			return

	M.visible_message(
		"<span class='notice'>\A [M] starts to climb [istop ? "down" : "up"] \a [src].</span>",
		"<span class='notice'>You start to climb [istop ? "down" : "up"] \the [src].</span>",
		"You hear the grunting and clanging of a metal ladder being used."
	)

	if (do_after(M, 10, src))
		playsound(loc, 'sound/effects/ladder.ogg', 50, TRUE, -1)
		// pulling/grabbing people with you
		if (M.pulling != null)
			M.pulling.loc = target.loc
		M.loc = target.loc
		return

		M.visible_message(
			"<span class='notice'>\A [M] climbs [istop ? "down" : "up"] \a [src].</span>",
			"<span class='notice'>You climb [istop ? "down" : "up"] \the [src].</span>",
			"You hear the grunting and clanging of a metal ladder being used."
		)

/obj/structure/multiz/ladder/ww2/teleporter/one
	ladder_id = "1"
/obj/structure/multiz/ladder/ww2/teleporter/up/one
	ladder_id = "1"
/obj/structure/multiz/ladder/ww2/teleporter/two
	ladder_id = "2"
/obj/structure/multiz/ladder/ww2/teleporter/up/two
	ladder_id = "2"
/obj/structure/multiz/ladder/ww2/teleporter/three
	ladder_id = "3"
/obj/structure/multiz/ladder/ww2/teleporter/up/three
	ladder_id = "3"
/obj/structure/multiz/ladder/ww2/teleporter/four
	ladder_id = "4"
/obj/structure/multiz/ladder/ww2/teleporter/up/four
	ladder_id = "4"
/obj/structure/multiz/ladder/ww2/teleporter/five
	ladder_id = "5"
/obj/structure/multiz/ladder/ww2/teleporter/up/five
	ladder_id = "5"


/obj/structure/multiz/stairs
	name = "Stairs"
	icon_state = "rampup"
	layer = 2.4

/obj/structure/multiz/stairs_wood
	name = "Wood Stairs"
	icon_state = "wood2_stairs"
	layer = 2.4


/obj/structure/multiz/stairs/enter
	icon_state = "ramptop"

/obj/structure/multiz/stairs/enter/bottom
	icon_state = "rampbottom"
	istop = FALSE

/obj/structure/multiz/stairs/active
	density = TRUE

/obj/structure/multiz/stairs/active/find_target()
	var/turf/targetTurf = istop ? GetBelow(src) : GetAbove(src)
	target = locate(/obj/structure/multiz/stairs/enter) in targetTurf

/obj/structure/multiz/stairs/active/Bumped(var/atom/movable/M)
	if (isnull(M))
		return

	if (ismob(M) && usr.client)
		usr.client.moving = TRUE
		usr.Move(get_turf(target))
		usr.client.moving = FALSE
	else
		M.Move(get_turf(target))
/obj/structure/stairs
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/stairs/active/attack_hand(mob/user)
	. = ..()
	if (Adjacent(user))
		Bumped(user)

/obj/structure/multiz/stairs/active/bottom
	icon_state = "rampdark"
	istop = FALSE

/obj/structure/multiz/stairs/active/bottom/Bumped(var/atom/movable/M)
	//If on bottom, only let them go up stairs if they've moved to the entry tile first.
	if (!locate(/obj/structure/multiz/stairs/enter) in M.loc)
		return
	return ..()
