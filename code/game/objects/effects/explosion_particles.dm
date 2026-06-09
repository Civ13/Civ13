
/obj/effect/expl_particles
	name = "explosive particles"
	icon = 'icons/effects/effects.dmi'
	icon_state = "explosion_particle"
	opacity = TRUE
	anchored = TRUE
	mouse_opacity = FALSE

/obj/effect/expl_particles/New()
	..()
	// No callproc timer - lifecycle is fully managed by datum/effect/system/expl_particles/start()
	return

/obj/effect/expl_particles/Move()
	..()
	return

/datum/effect/system/expl_particles
	var/number = 10
	var/turf/location

/datum/effect/system/expl_particles/proc/set_up(n = 10, loca)
	number = n
	if (istype(loca, /turf/)) location = loca
	else location = get_turf(loca)

/datum/effect/system/expl_particles/proc/start()
	var/i = FALSE
	for (i=0, i<number, i++)
		var/obj/effect/expl_particles/expl = new /obj/effect/expl_particles(location)
		var/direct = pick(alldirs)
		walk(expl, direct, 1)
		schedule_task_in(pick(1;25,2;50,3,4;200), /proc/qdel, list(expl))


/obj/effect/explosion
	name = "explosive particles"
	icon = 'icons/effects/96x96.dmi'
	icon_state = "explosion"
	opacity = FALSE
	anchored = TRUE
	mouse_opacity = FALSE
	pixel_x = -32
	pixel_y = -32

/obj/effect/explosion/New()
	..()
	if (processes.callproc)
		processes.callproc.queue(src, /datum/proc/qdeleted, null, 10)
	else
		spawn(10) qdel(src)
	return

/datum/effect/system/explosion
	var/turf/location

/datum/effect/system/explosion/proc/set_up(loca)
	if (istype(loca, /turf/)) location = loca
	else location = get_turf(loca)

/datum/effect/system/explosion/proc/start(var/create_smoke)
	new/obj/effect/explosion( location )
	var/datum/effect/system/expl_particles/P = new/datum/effect/system/expl_particles()
	P.set_up(10,location)
	P.start()
	if(create_smoke)
		spawn(5)
			var/datum/effect/effect/system/smoke_spread/S = new/datum/effect/effect/system/smoke_spread()
			S.set_up(5,0,location,null)
			S.start()