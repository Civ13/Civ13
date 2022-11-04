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
	layer = 2.4 // below crates and tables

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
			for (var/obj/item/I in M)
				I.update_light()
			return
		else
			if (M.pulling != null)
				M.pulling.z = M.pulling.z+1
				M.pulling.x = src.x
				M.pulling.y = src.y
			M.z = M.z+1
			M.x = src.x
			M.y = src.y
			for (var/obj/item/I in M)
				I.update_light()
			return
		M.visible_message(
			"<span class='notice'>\A [M] climbs [istop ? "down" : "up"] \a [src].</span>",
			"<span class='notice'>You climb [istop ? "down" : "up"] \the [src].</span>",
			"You hear the grunting and clanging of a metal ladder being used."
		)

/mob/living/human/var/laddervision = null

/obj/structure/multiz/ladder/MouseDrop_T(var/mob/living/human/user as mob)
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

/mob/living/human/proc/update_laddervision(var/obj/structure/multiz/ladder/ladder)
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

/mob/living/human/proc/laddervision_direction()
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
	name = "ladder downward"
	desc = "A ladder.  You can climb down it but you'll have to look closer to see more."

/obj/structure/multiz/ladder/ww2/stairsdown
	icon_state = "rampbottom"
	name = "stairs down"
	desc = "A stairway leading downward. You'll have to look closer to see more."

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
	name = "ladder upward"
	desc = "A ladder.  You can climb up it but you'll have to look closer to see more."

/obj/structure/multiz/ladder/ww2/up/manhole
	icon_state = "ladderup"
	istop = FALSE
	name = "ladder upwards"
	desc = "A ladder. Leads upwards to a heavy cover."

/obj/structure/multiz/ladder/ww2/up/manhole/chech/attack_hand(var/mob/M)
	if (istype(M, /mob/living/human))
		var/mob/living/human/H = M
		if (H.faction_text != "CHECHEN")
			H << "You can't figure out the hatch!"
			return
		else
			..()
	else
		..()

/obj/structure/multiz/ladder/ww2/manhole
	icon_state = "manhole"
	istop = TRUE
	name = "manhole cover"
	desc = "A heavy cover bars access to an underground tunnel."

/obj/structure/multiz/ladder/ww2/manhole/chech/attack_hand(var/mob/M)
	if (istype(M, /mob/living/human))
		var/mob/living/human/H = M
		if (H.faction_text != "CHECHEN")
			H << "You can't figure out the hatch!"
			return
		else
			..()
	else
		..()

/obj/structure/multiz/ladder/ww2/stairsup
	icon_state = "rampup"
	name = "stairs up"
	istop = FALSE
	desc = "A stairway leading upward.  You'll have to look closer to see more."

/obj/structure/multiz/ladder/ww2/Destroy()
	if (target && istop)
		qdel(target)
	return ..()

/obj/structure/multiz/ladder/ww2/tunneltop
	name = "tunnel entrance"
	desc = "A hole dug in the floor, leads to an underground tunnel."
	icon_state = "hole_top"
	istop = TRUE
	var/filled = 0

/obj/structure/multiz/ladder/ww2/tunneltop/vietcong
	icon_state = "pine_closed"
	name = "bush"
	desc = "A hole is dug underneath and leads underground."

/obj/structure/multiz/ladder/ww2/tunneltop/vietcong/attack_hand(var/mob/M)
	if (istype(M, /mob/living/human))
		var/mob/living/human/H = M
		if (H.faction_text != "VIETNAMESE" && H.original_job_title != "US Commando" && H.faction_text != "JAPANESE")
			if (map.ID == MAP_RETREAT && H.faction_text != "CHINESE")
				H << "This tunnel is too small for you!"
				return
			else
				..()
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

/obj/structure/multiz/ladder/ww2/tunnelbottom/vietcong/attack_hand(var/mob/M)
	if (istype(M, /mob/living/human))
		var/mob/living/human/H = M
		if (H.faction_text != "VIETNAMESE" && H.original_job_title != "US Commando" && H.faction_text != "JAPANESE")
			if (map.ID == MAP_RETREAT && H.faction_text != "CHINESE")
				H << "This tunnel is too small for you!"
				return
			else
				..()
		else
			..()
	else
		..()

/obj/structure/multiz/ladder/ww2/teleporter
	name = "ladder downwards"
	desc = "A ladder.  You can climb down it but you'll have to look closer to see more."
	icon_state = "ladderdown"
	layer = 2.4 // below crates and tables
/obj/structure/multiz/ladder/ww2/teleporter/up
	icon_state = "ladderup"
	istop = FALSE
	name = "ladder upwards"
	desc = "A ladder.  You can climb up it but you'll have to look closer to see more."
/obj/structure/multiz/ladder/ww2/teleporter/New()
	..()
	spawn(100)
		for (var/obj/structure/multiz/ladder/ww2/teleporter/ladder in world)
			if (!(ladder in ladder_list))
				ladder_list += ladder
			if (!(src in ladder_list))
				ladder_list += src
			if (area_id == ladder.area_id && ladder != src)
				target = ladder
				continue
/obj/structure/multiz/ladder/ww2/teleporter/find_target()
	for (var/obj/structure/multiz/ladder/ww2/teleporter/ladder in ladder_list)
		if (area_id == ladder.area_id && ladder != src && ((ladder.istop && !src.istop) || (!ladder.istop && src.istop)))
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
	area_id = "1"
/obj/structure/multiz/ladder/ww2/teleporter/up/one
	area_id = "1"
/obj/structure/multiz/ladder/ww2/teleporter/two
	area_id = "2"
/obj/structure/multiz/ladder/ww2/teleporter/up/two
	area_id = "2"
/obj/structure/multiz/ladder/ww2/teleporter/three
	area_id = "3"
/obj/structure/multiz/ladder/ww2/teleporter/up/three
	area_id = "3"
/obj/structure/multiz/ladder/ww2/teleporter/four
	area_id = "4"
/obj/structure/multiz/ladder/ww2/teleporter/up/four
	area_id = "4"
/obj/structure/multiz/ladder/ww2/teleporter/five
	area_id = "5"
/obj/structure/multiz/ladder/ww2/teleporter/up/five
	area_id = "5"


/obj/structure/multiz/ladder/ww2/tunneltop/attackby(obj/item/I as obj, mob/user as mob)
	if (istype(I, /obj/item/weapon/barrier))
		visible_message("[user] throws the dirt into \the [src].", "You throw the dirt into \the [src].")
		filled++
		qdel(I)
		if (filled >= 4)
			visible_message("The hole gets covered.")
			for (var/obj/structure/multiz/ladder/ww2/tunnelbottom/TB in locate(src.x, src.y, src.z-1))
				qdel(TB)
			qdel(src)
	else
		..()
/obj/structure/multiz/stairs
	name = "stairs"
	icon_state = "rampup"
	layer = 2.4

/obj/structure/multiz/stairs_wood
	name = "wood stairs"
	icon_state = "wood2_stairs"
	layer = 2.4


/////////////////Active/////////////////
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
