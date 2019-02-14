/obj/structure/vehicle
	name = "vehicle"
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "motorcycle"
	var/list/ontop = list()
	var/mob/living/carbon/human/driver = null
	var/lastmove = 0
	var/vehicle_m_delay = 20
/obj/structure/vehicle/proc/processmove(var/m_dir = null)
	if (!m_dir)
		return
	else
		if (do_vehicle_check() && lastmove+vehicle_m_delay <= world.time)
			do_move(m_dir)
			lastmove = world.time

/obj/structure/vehicle/proc/do_vehicle_check(var/m_dir = null)
	return TRUE

/obj/structure/vehicle/proc/do_move(var/m_dir = null)
	for (var/mob/living/ML in ontop)
		ML.forceMove(get_step(src, m_dir))
	for (var/obj/O in ontop)
		O.forceMove(get_step(src, m_dir))
	forceMove(get_step(src, m_dir))
	update_icon()
	return

/obj/structure/vehicle/update_icon()
	if (driver)
		dir = driver.dir
	..()


/obj/structure/vehicle/MouseDrop_T(mob/living/carbon/human/M, mob/living/carbon/human/user)
	if (M.anchored == FALSE && M.driver == FALSE && !(M in ontop))
		visible_message("<div class='notice'>[M] starts getting on \the [src]...</div>","<div class='notice'>You start going on \the [src]...</div>")
		if (do_after(M, 40, src))
			visible_message("<div class='notice'>[M] sucessfully climbs into \the [src].</div>","<div class='notice'>You sucessfully climb into \the [src].</div>")
			M.forceMove(get_turf(src))
			if (!driver)
				M.driver = TRUE
				M.driver_vehicle = src
				driver = M
				ontop += M
			return

/obj/structure/vehicle/attack_hand(mob/living/carbon/human/user as mob)
	if ((user in ontop))
		visible_message("<div class='notice'>[user] start leaving \the [src]...</div>","<div class='notice'>You start going on \the [src]...</div>")
		if (do_after(user, 30, src))
			visible_message("<div class='notice'>[user] sucessfully leaves \the [src].</div>","<div class='notice'>You leave \the [src].</div>")
			ontop -= user
			if (user == driver)
				user.driver = FALSE
				user.driver_vehicle = null
				driver = null
			return


/obj/structure/vehicle/raft
	name = "raft"
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "raft"
	anchored = FALSE
	density = FALSE
	opacity = FALSE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/vehicle/raft/do_vehicle_check(var/m_dir = null)
	if (istype(get_turf(get_step(src,m_dir)), /turf/floor/beach/water))
		if (driver in src.loc)
			return TRUE
		else
			driver.driver = FALSE
			driver.driver_vehicle = null
			driver << "You leave the [src]."
			ontop -= driver
			driver = null
	else
		return FALSE