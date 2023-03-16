var/list/obj/effect/area_teleporter/AREA_TELEPORTERS = list()

/obj/structure/teleporter_controller1
	name = "SHIP - Send to Island"
	desc = "Sends the ship back and forth to deliver supplies."
	icon = 'icons/obj/decals.dmi'
	icon_state = "n1"
	anchored = TRUE
	opacity = FALSE
	density = TRUE
	layer = 3.5
	w_class = ITEM_SIZE_NORMAL
	invisibility = 0
	var/do_once = FALSE


/obj/structure/teleporter_controller1/attackby(obj/item/C, mob/user)
	if (do_once == FALSE)
		for (var/obj/effect/area_teleporter/AT)
			world << "<big>A ship will arrive at the island in 1 minute!</big>"
			do_once = TRUE
			spawn(600)
				AT.Simple_Down()
				do_once = FALSE
				return TRUE
	else
		return FALSE


/obj/structure/teleporter_controller2
	name = "SHIP - Depart from Island"
	desc = "Sends the ship back and forth to deliver supplies."
	icon = 'icons/obj/decals.dmi'
	icon_state = "n2"
	anchored = TRUE
	opacity = FALSE
	density = TRUE
	layer = 3.5
	w_class = ITEM_SIZE_NORMAL
	invisibility = 0
	var/do_once = FALSE

/obj/structure/teleporter_controller2/attackby(obj/item/C, mob/user)
	if (do_once == FALSE)
		for (var/obj/effect/area_teleporter/AT)
			world << "<big>A ship will arrive at the island in 1 minute!</big>"
			do_once = TRUE
			spawn(600)
				AT.Simple_Up()
				do_once = FALSE
				return TRUE
	else
		return FALSE

/obj/effect/area_teleporter
	name = "area-teleporter"
	icon = 'icons/mob/screen/effects.dmi'
	icon_state = "x2"
	var/id = null			//id of this bump_teleporter.
	var/id_target = null	//id of bump_teleporter which this moves you to.
	invisibility = 101 		//nope, can't see this
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	var/active = TRUE
	is_teleporter = TRUE
	var/timer = 0			//immediate by default
	var/movement_location = "UP" //so it can only move 1 time down and 1 time up. Default start is up.

/obj/effect/area_teleporter/New()
	..()
	AREA_TELEPORTERS += src
/obj/effect/area_teleporter/Destroy()
	AREA_TELEPORTERS -= src
	return ..()

/obj/effect/area_teleporter/proc/Activated()
	if (!id_target)
		//user.loc = loc	//Stop at teleporter location, there is nowhere to teleport to.
		return
	spawn(20)
		for (var/obj/effect/area_teleporter/BT)
			if (BT.id == id_target)
				for(var/obj/O in get_area(src))
					if (!O.is_teleporter)
						O.z = BT.z	//Teleport to destination's z level.
						if (O.is_cover == TRUE)
							O.updateturf()
				for(var/mob/M in get_area(src))
					M.z = BT.z	//Teleport to destination's z level.
				return

/obj/effect/area_teleporter/proc/Simple_Up()
	if (movement_location == "UP")
		return
	else
		spawn(20)
			for(var/obj/O in get_area(src))
				O.z = O.z+1	//Teleport to destination's z level.
				if (O.is_cover == TRUE)
					O.updateturf()
			for(var/mob/M in get_area(src))
				M.z = M.z+1	//Teleport to destination's z level.
		return

/obj/effect/area_teleporter/proc/Simple_Down()
	if (movement_location == "DOWN")
		return
	else
		spawn(20)
			for(var/obj/O in get_area(src))
				O.z = O.z-1	//Teleport to destination's z level.
				if (O.is_cover == TRUE)
					O.updateturf()
			for(var/mob/M in get_area(src))
				M.z = M.z-1	//Teleport to destination's z level.
		return