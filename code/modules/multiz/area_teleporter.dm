var/list/obj/effect/area_teleporter/AREA_TELEPORTERS = list()

/obj/effect/area_teleporter
	name = "area-teleporter"
	icon = 'icons/mob/screen1.dmi'
	icon_state = "x2"
	var/id = null			//id of this bump_teleporter.
	var/id_target = null	//id of bump_teleporter which this moves you to.
	invisibility = 101 		//nope, can't see this
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	var/active = TRUE
	is_teleporter = TRUE
	var/timer = 600			//immediate by default

/obj/effect/area_teleporter/New()
	..()
	AREA_TELEPORTERS += src
	spawn(20)
		Activated()
		return

/obj/effect/area_teleporter/Destroy()
	AREA_TELEPORTERS -= src
	return ..()

/obj/effect/area_teleporter/proc/Activated()
	if (!id_target)
		//user.loc = loc	//Stop at teleporter location, there is nowhere to teleport to.
		return
	spawn(6000)
		for (var/obj/effect/area_teleporter/BT)
			if (BT.id == id_target)
				for(var/obj/O in get_area(src))
					if (!O.is_teleporter)
						O.z = BT.z	//Teleport to destination's y level.
	//					O.invisibility = 0
						if (O.is_cover == TRUE)
							O.updateturf()
				for(var/mob/M in get_area(src))
					M.z = BT.z	//Teleport to destination's y level.
	/*			for(var/turf/T in get_area(BT))
					for(var/turf/TD in BT)
						TD.ChangeTurf(T)*/

				return