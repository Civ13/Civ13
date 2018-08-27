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
	w_class = 3
	invisibility = 0


/obj/structure/teleporter_controller1/attackby(obj/item/C, mob/user)
	for (var/obj/effect/area_teleporter/AT)
		if (AT.id == "one")
			AT.Activated()
			world << "<big>The ship is arriving!</big>"
			return TRUE


/obj/structure/teleporter_controller2
	name = "SHIP - Depart from Island"
	desc = "Sends the ship back and forth to deliver supplies."
	icon = 'icons/obj/decals.dmi'
	icon_state = "n2"
	anchored = TRUE
	opacity = FALSE
	density = TRUE
	layer = 3.5
	w_class = 3
	invisibility = 0

/obj/structure/teleporter_controller2/attackby(obj/item/C, mob/user)
	for (var/obj/effect/area_teleporter/AT)
		if (AT.id == "one")
			AT.Activated()
			world << "<big>The ship is departing!</big>"
			return TRUE

/obj/effect/area_teleporter
	name = "area-teleporter"
	icon = 'icons/mob/screen/1713Style.dmi'
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

/obj/effect/area_teleporter/proc/Reverse_Activated()
	if (!id)
		//user.loc = loc	//Stop at teleporter location, there is nowhere to teleport to.
		return
	spawn(20)
		for (var/obj/effect/area_teleporter/BT)
			if (BT.id_target == id)
				for(var/obj/O in get_area(src))
					if (!O.is_teleporter)
						O.z = BT.z	//Teleport to destination's z level.
						if (O.is_cover == TRUE)
							O.updateturf()
				for(var/mob/M in get_area(src))
					M.z = BT.z	//Teleport to destination's z level.
				return